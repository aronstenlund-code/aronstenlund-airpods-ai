import { ApiError } from '../api/client';
import type { AnswerRequest } from '../api/listen';
import type { Clock, Sound } from '../core/sound';
import type { Translate } from '../texts';
import { base64 } from './pcm';
import { audioMessage, keepAliveMs, keepAliveSamples, readScribe, scribeUrl, streamedSeconds, type SttToken } from './scribe';
import { takeSentences } from './sentences';
import type { ServerEvent } from './sse';

/// The microphone: blocks of 16 kHz sound and how loud each is. Nothing is kept.
export interface Mic {
  start(onBlock: (samples: Int16Array, level: number) => void): Promise<void>;
  stop(): void;
}

/// The Scribe socket.
export interface Line {
  send(text: string): void;
  close(): void;
  onMessage: ((raw: string) => void) | null;
  onClose: (() => void) | null;
}

export interface ListenDeps {
  api: {
    token(): Promise<SttToken>;
    report(seconds: number): Promise<unknown>;
    answer(request: AnswerRequest, onEvent: (event: ServerEvent) => void, signal: AbortSignal): Promise<void>;
    speak(text: string, voiceID: string | null, signal: AbortSignal): Promise<Uint8Array>;
  };
  mic: Mic;
  open(url: string): Line;
  sound: Sound;
  files: { link(bytes: Uint8Array, name: string): string; forget(url: string): void };
  clock: Clock;
  awake: { keep(): Promise<void>; release(): Promise<void> };
  lang: 'en' | 'sv';
  voiceID(): string | null;
  t: Translate;
  /// Whatever else plays (a text, a quiz) is stopped first: one thing at a time.
  stopOthers(): void;
}

export type ListenPhase = 'off' | 'starting' | 'listening' | 'answering';

/// Words that show a sentence is not finished ("the difference between…"): the turn waits a little longer.
const unfinished = /\b(?:en|ett|och|eller|men|att|som|samt|både|mellan|a|an|the|and|or|but|between)$/i;

/// The ordinary listening mode on the web (the app's "Frågor"): the microphone is transcribed by Scribe; when the
/// speaker has paused, the turn goes to the server, which answers if it was a question; the answer is read sentence
/// by sentence. Half duplex: while an answer is read nothing is sent from the microphone, so the page never answers
/// its own voice from a loudspeaker. Nothing is stored: not the sound, not the words.
export class ListenSession {
  onChange: (() => void) | null = null;

  phase: ListenPhase = 'off';
  /// What is being heard right now, the question that was sent, and the answer as it comes.
  heard = '';
  question: string | null = null;
  answer = '';
  error: string | null = null;
  level = 0;

  static readonly turnWaitMs = 400;
  static readonly unfinishedWaitMs = 3_000;
  static readonly fakeAfterMs = 1_000;
  static readonly reopenAfterMs = 20_000;
  static readonly maxReopens = 3;

  private line: Line | null = null;
  private opened = 0;
  private reopens = 0;
  private streamed = 0;
  private lastSent = 0;
  private pending = '';
  private recent: { q: string; a: string }[] = [];
  private cancelTurn: (() => void) | null = null;
  private cancelAlive: (() => void) | null = null;
  private cancelFake: (() => void) | null = null;
  private abort: AbortController | null = null;
  private queue: Promise<string | null>[] = [];
  private speaking: string | null = null;
  /// Each time what was to be said is dropped, the sound still being fetched for it is no longer wanted.
  private speech = 0;
  private streamDone = true;
  private buffer = '';
  private silent = false;
  /// Each start is a new run: what belongs to an older one is thrown away.
  private run = 0;

  constructor(private readonly deps: ListenDeps) {}

  get isOn(): boolean {
    return this.phase !== 'off';
  }

  /// Start listening. Called straight from the tap (after the consent screen): the page's audio starts at once, so
  /// the answers may be played later.
  async start(): Promise<void> {
    if (this.phase !== 'off') return;
    const { sound, awake, mic, t } = this.deps;
    this.deps.stopOthers();
    const mine = (this.run += 1);
    sound.silence();
    void awake.keep();
    this.phase = 'starting';
    this.error = null;
    this.heard = '';
    this.question = null;
    this.answer = '';
    this.recent = [];
    this.streamed = 0;
    this.reopens = 0;
    this.changed();
    try {
      await mic.start((samples, level) => this.block(samples, level));
    } catch {
      if (mine === this.run) this.fail(t('listenMicDenied'));
      return;
    }
    if (mine !== this.run) {
      mic.stop(); // stopped while the browser was asking
      return;
    }
    await this.connect(mine);
  }

  /// Stop: the microphone is off, nothing more is sent or played, the screen may sleep.
  stop(): void {
    if (this.phase === 'off') return;
    const seconds = streamedSeconds(this.streamed);
    this.end();
    this.error = null;
    this.heard = '';
    this.changed();
    if (seconds > 0) void this.deps.api.report(seconds).catch(() => undefined);
  }

  /// The page was hidden or the screen went dark: the browser closes the microphone, and the page never listens
  /// where it cannot be seen. It says why when the user comes back.
  halt(message: string): void {
    if (this.phase !== 'off') this.fail(message);
  }

  /// One press on the AirPods, or a tap on the answer: the answer stops and the page listens again.
  press(): void {
    if (this.phase === 'answering') this.backToListening(false);
  }

  private end(): void {
    this.run += 1;
    this.cancelTurn?.();
    this.cancelAlive?.();
    this.cancelFake?.();
    this.cancelTurn = this.cancelAlive = this.cancelFake = null;
    this.abort?.abort();
    this.abort = null;
    this.dropSpeech();
    const line = this.line;
    this.line = null;
    if (line !== null) {
      line.onClose = null;
      line.onMessage = null;
      line.close();
    }
    this.deps.mic.stop();
    this.deps.sound.stop();
    void this.deps.awake.release();
    this.phase = 'off';
    this.pending = '';
    this.level = 0;
  }

  private fail(message: string): void {
    const seconds = streamedSeconds(this.streamed);
    this.end();
    this.error = message;
    this.changed();
    if (seconds > 0) void this.deps.api.report(seconds).catch(() => undefined);
  }

  /// A token, then the socket. Test traffic gets no socket, only one sentence (D180).
  private async connect(mine: number): Promise<void> {
    const { api, clock, lang, t } = this.deps;
    let token: SttToken;
    try {
      token = await api.token();
    } catch (error) {
      if (mine !== this.run) return;
      // The server's own words when it has some (the web's daily cap, too many tries); else ours.
      this.fail(error instanceof ApiError && error.message.trim().length > 0 && error.status === 429 ? error.message : t('listenFailed'));
      return;
    }
    if (mine !== this.run) return;
    if (token.fake === true) {
      const sentence = token.transcript ?? '';
      this.cancelFake = clock.after(ListenSession.fakeAfterMs, () => {
        if (mine === this.run && this.phase === 'listening') this.said({ kind: 'final', text: sentence });
      });
    } else {
      const url = scribeUrl(token, lang);
      if (url === null) {
        this.fail(t('listenFailed'));
        return;
      }
      const line = this.deps.open(url);
      line.onMessage = (raw) => {
        if (mine === this.run) this.said(readScribe(raw));
      };
      line.onClose = () => {
        if (mine === this.run) this.closed(mine);
      };
      this.line = line;
      this.opened = clock.now();
      this.lastSent = clock.now();
      this.alive(mine);
    }
    if (this.phase === 'starting') this.phase = 'listening';
    this.changed();
  }

  /// Scribe ends a session by itself now and then. One that has run a while is opened again with a new token; one
  /// that ends at once is a fault, and the page says so instead of asking for token after token.
  private closed(mine: number): void {
    this.line = null;
    this.cancelAlive?.();
    const ran = this.deps.clock.now() - this.opened;
    if (ran >= ListenSession.reopenAfterMs && this.reopens < ListenSession.maxReopens) {
      this.reopens += 1;
      void this.connect(mine);
    } else {
      this.fail(this.deps.t('listenFailed'));
    }
  }

  private alive(mine: number): void {
    this.cancelAlive = this.deps.clock.after(keepAliveMs, () => {
      if (mine !== this.run || this.line === null) return;
      if (this.deps.clock.now() - this.lastSent >= keepAliveMs) this.sendSound(new Int16Array(keepAliveSamples));
      this.alive(mine);
    });
  }

  private sendSound(samples: Int16Array): void {
    if (this.line === null) return;
    this.line.send(audioMessage(base64(samples)));
    this.streamed += samples.length;
    this.lastSent = this.deps.clock.now();
  }

  private block(samples: Int16Array, level: number): void {
    if (this.phase === 'off') return;
    const shown = Math.round(level * 20) / 20;
    if (shown !== this.level) {
      this.level = shown;
      this.changed();
    }
    if (this.phase === 'listening') this.sendSound(samples);
  }

  private said(event: ReturnType<typeof readScribe>): void {
    if (event.kind === 'error') {
      this.fail(this.deps.t('listenFailed'));
      return;
    }
    if (event.kind === 'other' || this.phase !== 'listening') return;
    this.cancelTurn?.();
    this.cancelTurn = null;
    if (event.kind === 'partial') {
      this.heard = [this.pending, event.text].filter(Boolean).join(' ');
      this.changed();
      return;
    }
    if (event.text.length === 0) return;
    this.pending = [this.pending, event.text].filter(Boolean).join(' ');
    this.heard = this.pending;
    const wait = unfinished.test(this.pending.replace(/[.,!?…\s]+$/, '')) ? ListenSession.unfinishedWaitMs : ListenSession.turnWaitMs;
    const mine = this.run;
    this.cancelTurn = this.deps.clock.after(wait, () => {
      this.cancelTurn = null;
      if (mine !== this.run || this.phase !== 'listening') return;
      const turn = this.pending;
      this.pending = '';
      void this.ask(turn);
    });
    this.changed();
  }

  /// The turn goes to the server. It answers when it was a question, and says nothing when it was not.
  private async ask(turn: string): Promise<void> {
    if (turn.trim().length < 2) return;
    const mine = this.run;
    const abort = new AbortController();
    this.abort = abort;
    this.phase = 'answering';
    this.question = turn;
    this.answer = '';
    this.buffer = '';
    this.silent = false;
    this.streamDone = false;
    this.error = null;
    this.changed();
    try {
      await this.deps.api.answer({ fragment: turn, recent: this.recent }, (event) => (mine === this.run && this.abort === abort ? this.answered(event) : undefined), abort.signal);
    } catch (error) {
      if (mine !== this.run || this.abort !== abort) return;
      this.error = error instanceof ApiError && error.message.trim().length > 0 ? error.message : this.deps.t('listenAnswerFailed');
      this.silent = true;
    }
    if (mine !== this.run || this.abort !== abort) return;
    this.finishStream();
  }

  private answered(event: ServerEvent): void {
    const data = (event.data ?? {}) as Record<string, unknown>;
    if (event.event === 'meta') {
      if (data.is_question === false) this.silent = true; // not a question: nothing is shown or said
    } else if (event.event === 'delta' && !this.silent && typeof data.text === 'string') {
      this.answer += data.text;
      this.buffer += data.text;
      const { sentences, rest } = takeSentences(this.buffer, false);
      this.buffer = rest;
      for (const sentence of sentences) this.enqueue(sentence);
      this.changed();
    } else if (event.event === 'error') {
      this.error = typeof data.message === 'string' && data.message.length > 0 ? data.message : this.deps.t('listenAnswerFailed');
    } else if (event.event === 'done' && data.retract === true) {
      // The server takes the answer back: what was shown goes, what was to be said is not said.
      this.silent = true;
      this.answer = '';
      this.buffer = '';
      this.dropSpeech();
      this.deps.sound.silence();
    }
  }

  private finishStream(): void {
    if (!this.silent) for (const sentence of takeSentences(this.buffer, true).sentences) this.enqueue(sentence);
    this.buffer = '';
    this.streamDone = true;
    if (this.silent && this.error === null) this.question = null;
    this.pump();
  }

  /// The sentence's sound is asked for at once, so the next one is ready when this one has been read.
  private enqueue(sentence: string): void {
    const abort = this.abort;
    if (abort === null) return;
    const { api, files, t } = this.deps;
    this.queue.push(
      api.speak(sentence, this.deps.voiceID(), abort.signal).then(
        (bytes) => files.link(bytes, 'answer.mp3'),
        (error: unknown) => {
          // The text stays on the screen; the server's words when it has some (the web's daily cap).
          if (!abort.signal.aborted && this.error === null) this.error = error instanceof ApiError && error.status === 429 && error.message.trim().length > 0 ? error.message : t('listenNoSpeech');
          return null;
        },
      ),
    );
    this.pump();
  }

  private pump(): void {
    if (this.phase !== 'answering' || this.speaking !== null) return;
    const next = this.queue.shift();
    if (next === undefined) {
      if (this.streamDone) this.backToListening(true);
      return;
    }
    const mine = this.run;
    const abort = this.abort;
    const wanted = this.speech;
    this.speaking = 'fetching';
    void next.then((url) => {
      if (mine !== this.run || this.abort !== abort || wanted !== this.speech) {
        if (url !== null) this.deps.files.forget(url);
        return;
      }
      if (url === null) {
        this.speaking = null;
        this.changed();
        this.pump();
        return;
      }
      this.speaking = url;
      this.deps.sound.onEnded = () => {
        if (this.speaking !== url) return;
        this.deps.files.forget(url);
        this.speaking = null;
        this.pump();
      };
      this.deps.sound.play(url, 0, null);
    });
  }

  private dropSpeech(): void {
    for (const waiting of this.queue) void waiting.then((url) => (url === null ? undefined : this.deps.files.forget(url)));
    this.queue = [];
    if (this.speaking !== null && this.speaking !== 'fetching') this.deps.files.forget(this.speaking);
    this.speaking = null;
    this.speech += 1;
  }

  /// The answer is over (read to the end, or stopped by a press): the microphone's sound is sent again.
  private backToListening(finished: boolean): void {
    if (this.phase !== 'answering') return;
    if (finished && this.question !== null && this.answer.length > 0) this.recent = [...this.recent, { q: this.question, a: this.answer }].slice(-3);
    this.abort?.abort();
    this.abort = null;
    this.dropSpeech();
    this.streamDone = true;
    this.phase = 'listening';
    this.heard = '';
    this.pending = '';
    this.deps.sound.silence(); // the page stays the one that plays, so the AirPods' presses keep coming
    this.lastSent = this.deps.clock.now();
    this.changed();
  }

  private changed(): void {
    this.onChange?.();
  }
}
