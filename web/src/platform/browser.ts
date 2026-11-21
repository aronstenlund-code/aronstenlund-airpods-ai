import type { Clock, Press, Sound } from '../core/sound';
import { pressFor } from '../core/sound';

/// One second of silence as a WAV file in the page itself (8 kHz, 8 bit, mono). Looped while nothing should be
/// heard, so the page stays the one "now playing" and the AirPods' presses keep coming to it.
function silentWav(): string {
  const samples = 8000;
  const bytes = new Uint8Array(44 + samples);
  const view = new DataView(bytes.buffer);
  const ascii = (at: number, text: string): void => {
    for (let i = 0; i < text.length; i += 1) bytes[at + i] = text.charCodeAt(i);
  };
  ascii(0, 'RIFF');
  view.setUint32(4, 36 + samples, true);
  ascii(8, 'WAVEfmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, 8000, true);
  view.setUint32(28, 8000, true);
  view.setUint16(32, 1, true);
  view.setUint16(34, 8, true);
  ascii(36, 'data');
  view.setUint32(40, samples, true);
  bytes.fill(128, 44);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return `data:audio/wav;base64,${btoa(binary)}`;
}

/// The page's one `<audio>` element as the players' `Sound`. One element for everything: a browser lets a page play
/// by itself only on an element the user has started once, so every sound goes through the one that Play unlocked.
export class BrowserSound implements Sound {
  onEnded: (() => void) | null = null;
  /// The browser refused to play (no tap yet): the screen says so.
  onBlocked: (() => void) | null = null;

  /// The sound stopped though nobody asked it to (the screen went dark, a call, the AirPods came out).
  onInterrupted: (() => void) | null = null;

  private readonly silent = silentWav();
  /// What the page wants: true from a play until a pause or a stop.
  private wanted = false;
  private real = false;
  private stopAt: number | null = null;
  private current: string | null = null;

  static readonly settleMs = 400;

  constructor(private readonly audio: HTMLAudioElement) {
    audio.preload = 'auto';
    audio.addEventListener('ended', () => {
      if (this.real) this.onEnded?.();
    });
    audio.addEventListener('timeupdate', () => {
      if (this.real && this.stopAt !== null && audio.currentTime * 1000 >= this.stopAt) {
        this.stopAt = null;
        this.onEnded?.(); // what comes next starts on the same element
      }
    });
    // A pause the page did not ask for. Looked at a moment later: a file that ends, or one being changed for the
    // next, also pauses for an instant.
    audio.addEventListener('pause', () => {
      window.setTimeout(() => {
        if (this.wanted && audio.paused && !audio.ended) {
          this.wanted = false;
          this.onInterrupted?.();
        }
      }, BrowserSound.settleMs);
    });
  }

  /// Called straight from a tap, before any waiting: starts the element, so sound that comes later may play.
  unlock(): void {
    this.silence();
  }

  play(url: string, fromMs: number, toMs: number | null): void {
    const audio = this.audio;
    this.real = true;
    this.stopAt = toMs;
    audio.loop = false;
    const seek = (): void => {
      try {
        audio.currentTime = fromMs / 1000;
      } catch {
        /* not seekable yet: it plays from the start */
      }
    };
    if (this.current !== url) {
      this.current = url;
      audio.src = url;
      if (fromMs > 0) audio.addEventListener('loadedmetadata', seek, { once: true });
    } else {
      seek();
    }
    this.start();
  }

  silence(): void {
    this.real = false;
    this.stopAt = null;
    if (this.current !== this.silent) {
      this.current = this.silent;
      this.audio.src = this.silent;
    }
    this.audio.loop = true;
    this.start();
  }

  pause(): void {
    this.wanted = false;
    this.audio.pause();
  }

  resume(): void {
    this.start();
  }

  stop(): void {
    this.wanted = false;
    this.real = false;
    this.stopAt = null;
    this.audio.pause();
  }

  positionMs(): number {
    return this.real ? this.audio.currentTime * 1000 : 0;
  }

  private start(): void {
    this.wanted = true;
    const played = this.audio.play();
    if (played === undefined) return;
    played.catch((error: unknown) => {
      // AbortError: the file was changed for the next one before this one began. Not a no.
      if (error instanceof DOMException && error.name === 'AbortError') return;
      if (!this.wanted) return;
      this.wanted = false;
      this.onBlocked?.();
    });
  }
}

export const browserClock: Clock = {
  now: () => Date.now(),
  after: (ms, fn) => {
    const id = window.setTimeout(fn, ms);
    return () => window.clearTimeout(id);
  },
};

/// The AirPods' presses and the lock screen's buttons (Media Session). Without it (an old browser) the buttons on
/// the page still work.
export function listenForPresses(onPress: (press: Press) => void, onStop: () => void): void {
  const session = navigator.mediaSession;
  if (session === undefined) return;
  try {
    session.setActionHandler('stop', onStop);
  } catch {
    /* this browser does not know the action */
  }
  for (const action of ['play', 'pause', 'nexttrack', 'previoustrack'] as const) {
    try {
      session.setActionHandler(action, () => {
        const press = pressFor(action);
        if (press !== null) onPress(press);
      });
    } catch {
      /* this browser does not know the action */
    }
  }
}

/// What the lock screen and the AirPods' owner see: the text's first line, "EarMind", and where it comes from (Ke86 §7).
export function showNowPlaying(title: string, album: string, playing: boolean): void {
  if (navigator.mediaSession === undefined) return;
  if (typeof MediaMetadata !== 'undefined') navigator.mediaSession.metadata = new MediaMetadata({ title, artist: 'EarMind', album });
  navigator.mediaSession.playbackState = playing ? 'playing' : 'paused';
}

export function showNothingPlaying(): void {
  if (navigator.mediaSession === undefined) return;
  navigator.mediaSession.metadata = null;
  navigator.mediaSession.playbackState = 'none';
}

interface WakeLockLike {
  request(type: 'screen'): Promise<{ release(): Promise<void>; addEventListener(type: 'release', fn: () => void): void }>;
}

/// D250: the beta needs the screen on. Screen Wake Lock keeps it awake where the browser has it; the lock is lost
/// when the page is hidden and is asked for again when it comes back.
export class ScreenAwake {
  onChange: (() => void) | null = null;
  held = false;
  private wanted = false;
  private sentinel: { release(): Promise<void> } | null = null;
  private readonly api: WakeLockLike | undefined;

  constructor(nav: Navigator = navigator, doc: Document = document) {
    this.api = (nav as unknown as { wakeLock?: WakeLockLike }).wakeLock;
    doc.addEventListener('visibilitychange', () => {
      if (this.wanted && doc.visibilityState === 'visible') void this.keep();
    });
  }

  get supported(): boolean {
    return this.api !== undefined;
  }

  async keep(): Promise<void> {
    this.wanted = true;
    if (this.api === undefined || this.sentinel !== null) return;
    try {
      const sentinel = await this.api.request('screen');
      this.sentinel = sentinel;
      this.held = true;
      sentinel.addEventListener('release', () => {
        this.sentinel = null;
        this.held = false;
        this.onChange?.();
      });
    } catch {
      this.held = false; // low battery, or the page is not visible
    }
    this.onChange?.();
  }

  async release(): Promise<void> {
    this.wanted = false;
    const sentinel = this.sentinel;
    this.sentinel = null;
    this.held = false;
    if (sentinel !== null) await sentinel.release().catch(() => undefined);
    this.onChange?.();
  }
}
