import type { Clock, Press, Sound } from './sound';

/// A question's sound: the question, the long answer, and where the short answer ends in the long file (D145).
export interface QuestionTrack {
  question: string;
  long: string;
  shortEndMs: number;
}

export type AnswerKind = 'long' | 'short';

export type QuestionPhase =
  | { kind: 'idle' }
  | { kind: 'question'; index: number }
  | { kind: 'thinking'; index: number }
  | { kind: 'answer'; index: number; answer: AnswerKind }
  | { kind: 'waiting'; index: number };

/// The thinking time after a question (the app's `ThinkingTime`): 6 s up to 20 questions, 4 s from 40.
export function thinkingSeconds(questions: number): number {
  if (questions <= 20) return 6;
  if (questions >= 40) return 4;
  return 6 - (2 * (questions - 20)) / 20;
}

/// The exam player (the app's RepetitionPlayer, D142). No microphone: only files and presses.
///
/// Question, thinking time, next question. A press during a question or its thinking time plays the chosen answer
/// (1 = the long one, 2 = the short one) and then the next question. A press during an answer starts that kind of
/// answer again. Three presses pause; while paused every press goes on from the same word (D143). After the last
/// question the list starts again in the same order. It never ends by itself: only `stop()`.
export class QuestionPlayer {
  phase: QuestionPhase = { kind: 'idle' };
  paused = false;
  index = 0;
  lap = 0;
  thinkingStarted: number | null = null;
  onChange: (() => void) | null = null;

  static readonly retryMs = 2_000;

  private cancelTimer: (() => void) | null = null;
  private thinkingLeftMs: number | null = null;

  constructor(
    readonly count: number,
    private readonly track: (index: number) => QuestionTrack | null,
    private readonly sound: Sound,
    private readonly clock: Clock,
    readonly thinkingMs: number,
  ) {}

  get isRunning(): boolean {
    return this.phase.kind !== 'idle';
  }

  start(at = 0): void {
    if (this.count <= 0) return;
    this.stopQuietly();
    this.lap = 0;
    this.paused = false;
    this.sound.onEnded = () => this.soundEnded();
    this.ask(Math.min(Math.max(at, 0), this.count - 1));
  }

  stop(): void {
    this.stopQuietly();
    this.phase = { kind: 'idle' };
    this.changed();
  }

  press(press: Press): void {
    if (!this.isRunning) return;
    if (this.paused) {
      this.resume();
      return;
    }
    if (this.phase.kind === 'waiting') {
      if (press === 3) this.pause(); // nothing to answer yet: only a pause means something
      return;
    }
    if (press === 3) this.pause();
    else this.answer(press === 1 ? 'long' : 'short');
  }

  private ask(index: number): void {
    this.cancel();
    this.index = index;
    const track = this.track(index);
    if (track === null) {
      this.phase = { kind: 'waiting', index };
      this.sound.silence();
      this.cancelTimer = this.clock.after(QuestionPlayer.retryMs, () => {
        this.cancelTimer = null;
        if (this.phase.kind === 'waiting' && !this.paused) this.ask(index);
      });
      this.changed();
      return;
    }
    this.phase = { kind: 'question', index };
    this.sound.play(track.question, 0, null);
    this.changed();
  }

  private answer(kind: AnswerKind): void {
    const track = this.track(this.index);
    if (track === null) return;
    this.cancel();
    this.thinkingStarted = null;
    this.phase = { kind: 'answer', index: this.index, answer: kind };
    this.sound.play(track.long, 0, kind === 'short' ? track.shortEndMs : null);
    this.changed();
  }

  private think(leftMs: number): void {
    this.phase = { kind: 'thinking', index: this.index };
    this.thinkingStarted = this.clock.now() - (this.thinkingMs - leftMs);
    this.sound.silence();
    this.cancelTimer = this.clock.after(leftMs, () => {
      this.cancelTimer = null;
      this.thinkingStarted = null;
      this.nextQuestion();
    });
    this.changed();
  }

  private soundEnded(): void {
    if (this.paused) return;
    if (this.phase.kind === 'question') this.think(this.thinkingMs);
    else if (this.phase.kind === 'answer') this.nextQuestion();
  }

  private nextQuestion(): void {
    if (this.index + 1 < this.count) {
      this.ask(this.index + 1);
    } else {
      this.lap += 1;
      this.ask(0);
    }
  }

  private pause(): void {
    this.paused = true;
    if (this.phase.kind === 'thinking' && this.thinkingStarted !== null) {
      this.thinkingLeftMs = Math.max(0, this.thinkingMs - (this.clock.now() - this.thinkingStarted));
    }
    this.cancel();
    this.sound.pause();
    this.changed();
  }

  private resume(): void {
    this.paused = false;
    if (this.phase.kind === 'thinking') {
      const left = this.thinkingLeftMs ?? this.thinkingMs;
      this.thinkingLeftMs = null;
      this.think(left);
      return;
    }
    if (this.phase.kind === 'waiting') {
      this.ask(this.index);
      return;
    }
    this.sound.resume();
    this.changed();
  }

  private cancel(): void {
    this.cancelTimer?.();
    this.cancelTimer = null;
  }

  private stopQuietly(): void {
    this.cancel();
    this.thinkingStarted = null;
    this.thinkingLeftMs = null;
    this.sound.onEnded = null;
    this.sound.stop();
  }

  private changed(): void {
    this.onChange?.();
  }
}
