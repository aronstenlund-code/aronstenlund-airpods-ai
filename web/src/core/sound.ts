/// What the players need of the browser: one sound at a time, and time. The real ones are in platform/, the tests
/// use fakes, so the rules below run without a browser and without any audio (D180: no ElevenLabs in tests).

export interface Sound {
  /// Plays `url` from `fromMs`; stops by itself at `toMs` (the short answer is the start of the long file).
  play(url: string, fromMs: number, toMs: number | null): void;
  pause(): void;
  resume(): void;
  stop(): void;
  /// Nothing to hear, but the page stays the one the AirPods' presses go to (thinking time, waiting for sound).
  silence(): void;
  positionMs(): number;
  /// The sound that was asked for has played to its end (never fired for `silence`).
  onEnded: (() => void) | null;
}

export interface Clock {
  now(): number;
  /// Runs `fn` after `ms`; the returned function calls it off.
  after(ms: number, fn: () => void): () => void;
}

/// AirPods presses as the browser reports them (Media Session): one press is play or pause, two is the next
/// track, three is the previous one. The app's own meaning of 1, 2 and 3 presses is kept.
export type Press = 1 | 2 | 3;

export function pressFor(action: string): Press | null {
  switch (action) {
    case 'play':
    case 'pause':
      return 1;
    case 'nexttrack':
      return 2;
    case 'previoustrack':
      return 3;
    default:
      return null;
  }
}
