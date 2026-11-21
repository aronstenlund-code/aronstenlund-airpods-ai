import type { Clock, Press, Sound } from './sound';

/// One part of a text (a paragraph or a heading): its sound, and where each sentence starts and ends in it.
export interface TextPart {
  url: string | null;
  texts: string[];
  /// [start_ms, end_ms] per sentence, same order and length as `texts` (K70).
  times: [number, number][];
}

export type TextPhase = 'idle' | 'playing' | 'waiting' | 'done';

export interface TextPosition {
  part: number;
  sentence: number;
}

/// The sentence that is being read at `ms` in a part (the last one that has started).
export function sentenceAt(times: [number, number][], ms: number): number {
  let found = 0;
  for (let i = 0; i < times.length; i += 1) {
    if (ms >= times[i][0]) found = i;
  }
  return found;
}

/// The sentence after `at`: the next one in the part, else the first of the next part; null after the last.
export function nextSentence(parts: TextPart[], at: TextPosition): TextPosition | null {
  const count = Math.max(1, parts[at.part]?.times.length ?? 1);
  if (at.sentence + 1 < count) return { part: at.part, sentence: at.sentence + 1 };
  if (at.part + 1 < parts.length) return { part: at.part + 1, sentence: 0 };
  return null;
}

/// The sentence before `at`: the one before in the part, else the last of the part before; the very first stays.
export function previousSentence(parts: TextPart[], at: TextPosition): TextPosition {
  if (at.sentence > 0) return { part: at.part, sentence: at.sentence - 1 };
  if (at.part > 0) {
    const before = parts[at.part - 1];
    return { part: at.part - 1, sentence: Math.max(0, (before?.times.length ?? 1) - 1) };
  }
  return { part: 0, sentence: 0 };
}

/// "Säg i AirPods" and a text exam while they play (the app's ReadingPlayer): the parts in order, round and round
/// until the chosen minutes are over. One press pauses and goes on, two is the next sentence, three the previous.
/// A part whose sound the server has not made yet is waited for in silence.
export class TextPlayer {
  phase: TextPhase = 'idle';
  paused = false;
  position: TextPosition = { part: 0, sentence: 0 };
  lap = 0;
  onChange: (() => void) | null = null;

  static readonly retryMs = 2_000;

  private endsAt: number | null = null;
  private pausedAt: number | null = null;
  private cancelRetry: (() => void) | null = null;

  constructor(
    private readonly parts: () => TextPart[],
    private readonly sound: Sound,
    private readonly clock: Clock,
    /// Minutes to go round; null plays the text once.
    private readonly repeatMinutes: number | null,
  ) {}

  get isRunning(): boolean {
    return this.phase === 'playing' || this.phase === 'waiting';
  }

  /// Seconds left of the chosen time (it stands still while paused); null when the text plays once.
  secondsLeft(): number | null {
    if (this.endsAt === null) return null;
    const now = this.pausedAt ?? this.clock.now();
    return Math.max(0, Math.round((this.endsAt - now) / 1000));
  }

  start(): void {
    this.stopQuietly();
    this.lap = 0;
    this.paused = false;
    this.pausedAt = null;
    this.endsAt = this.repeatMinutes === null ? null : this.clock.now() + this.repeatMinutes * 60_000;
    this.sound.onEnded = () => this.partEnded();
    this.playFrom({ part: 0, sentence: 0 });
  }

  stop(): void {
    this.stopQuietly();
    this.phase = 'idle';
    this.changed();
  }

  press(press: Press): void {
    if (this.phase === 'done') {
      if (press === 1) this.start(); // "Börja om"
      return;
    }
    if (!this.isRunning) return;
    if (press === 1) this.togglePause();
    else if (press === 2) this.next();
    else this.previous();
  }

  togglePause(): void {
    if (!this.isRunning) return;
    if (this.paused) {
      this.paused = false;
      if (this.endsAt !== null && this.pausedAt !== null) this.endsAt += this.clock.now() - this.pausedAt;
      this.pausedAt = null;
      if (this.phase === 'waiting') this.wait();
      else this.sound.resume();
    } else {
      this.paused = true;
      this.pausedAt = this.clock.now();
      this.cancelRetry?.();
      this.cancelRetry = null;
      this.sound.pause();
    }
    this.changed();
  }

  next(): void {
    if (!this.isRunning) return;
    const to = nextSentence(this.parts(), this.current());
    if (to === null) {
      this.partEnded(true);
      return;
    }
    this.resumeIfPaused();
    this.playFrom(to);
  }

  previous(): void {
    if (!this.isRunning) return;
    this.resumeIfPaused();
    this.playFrom(previousSentence(this.parts(), this.current()));
  }

  /// Called while the sound moves (the screen's tick): keeps the sentence that is being read.
  tick(): void {
    if (this.phase !== 'playing') return;
    const part = this.parts()[this.position.part];
    if (part === undefined || part.times.length === 0) return;
    const sentence = sentenceAt(part.times, this.sound.positionMs());
    if (sentence !== this.position.sentence) {
      this.position = { part: this.position.part, sentence };
      this.changed();
    }
  }

  private current(): TextPosition {
    this.tick();
    return this.position;
  }

  private resumeIfPaused(): void {
    if (!this.paused) return;
    this.paused = false;
    if (this.endsAt !== null && this.pausedAt !== null) this.endsAt += this.clock.now() - this.pausedAt;
    this.pausedAt = null;
  }

  private playFrom(at: TextPosition): void {
    this.cancelRetry?.();
    this.cancelRetry = null;
    this.position = at;
    const part = this.parts()[at.part];
    if (part === undefined) {
      this.finish();
      return;
    }
    if (part.url === null) {
      this.phase = 'waiting';
      this.wait();
      this.changed();
      return;
    }
    this.phase = 'playing';
    this.sound.play(part.url, part.times[at.sentence]?.[0] ?? 0, null);
    this.changed();
  }

  private wait(): void {
    this.sound.silence();
    this.cancelRetry = this.clock.after(TextPlayer.retryMs, () => {
      this.cancelRetry = null;
      if (this.phase === 'waiting' && !this.paused) this.playFrom(this.position);
    });
  }

  private partEnded(skipped = false): void {
    if (!this.isRunning || (this.paused && !skipped)) return;
    const parts = this.parts();
    if (this.position.part + 1 < parts.length) {
      this.resumeIfPaused();
      this.playFrom({ part: this.position.part + 1, sentence: 0 });
      return;
    }
    // The last part: once more while the chosen time lasts, else the text is done.
    if (this.endsAt !== null && this.clock.now() < this.endsAt) {
      this.lap += 1;
      this.resumeIfPaused();
      this.playFrom({ part: 0, sentence: 0 });
    } else {
      this.finish();
    }
  }

  private finish(): void {
    this.stopQuietly();
    this.phase = 'done';
    this.changed();
  }

  private stopQuietly(): void {
    this.cancelRetry?.();
    this.cancelRetry = null;
    this.sound.onEnded = null;
    this.sound.stop();
  }

  private changed(): void {
    this.onChange?.();
  }
}
