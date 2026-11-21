import type { Clock, Sound } from '../src/core/sound';

/// A sound that only remembers what it was asked to do. `end()` is the file reaching its end.
export class FakeSound implements Sound {
  onEnded: (() => void) | null = null;
  log: string[] = [];
  position = 0;

  play(url: string, fromMs: number, toMs: number | null): void {
    this.position = fromMs;
    this.log.push(`play ${url} ${fromMs}${toMs === null ? '' : `-${toMs}`}`);
  }
  pause(): void {
    this.log.push('pause');
  }
  resume(): void {
    this.log.push('resume');
  }
  stop(): void {
    this.log.push('stop');
  }
  silence(): void {
    this.log.push('silence');
  }
  positionMs(): number {
    return this.position;
  }
  end(): void {
    this.onEnded?.();
  }
  get last(): string {
    return this.log[this.log.length - 1] ?? '';
  }
}

/// Time by hand: `advance` runs what is due.
export class FakeClock implements Clock {
  time = 1_000_000;
  private timers: { at: number; fn: () => void; live: boolean }[] = [];

  now(): number {
    return this.time;
  }
  after(ms: number, fn: () => void): () => void {
    const timer = { at: this.time + ms, fn, live: true };
    this.timers.push(timer);
    return () => {
      timer.live = false;
    };
  }
  advance(ms: number): void {
    const until = this.time + ms;
    for (;;) {
      const due = this.timers.filter((t) => t.live && t.at <= until).sort((a, b) => a.at - b.at)[0];
      if (due === undefined) break;
      due.live = false;
      this.time = due.at;
      due.fn();
    }
    this.time = until;
  }
}

export class MemoryStorage {
  private data = new Map<string, string>();
  getItem(key: string): string | null {
    return this.data.get(key) ?? null;
  }
  setItem(key: string, value: string): void {
    this.data.set(key, value);
  }
  removeItem(key: string): void {
    this.data.delete(key);
  }
}

export interface Scripted {
  status: number;
  body: unknown;
  /// RoutedServer only: the answer is held until this resolves (a slow server).
  wait?: Promise<unknown>;
}

/// A scripted server: answers in order and remembers every request.
export class FakeServer {
  requests: { url: string; method: string; headers: Record<string, string>; body: Record<string, unknown> | null }[] = [];
  constructor(private readonly replies: Scripted[]) {}

  fetch = async (url: string, init: RequestInit): Promise<Response> => {
    this.requests.push({
      url,
      method: String(init.method ?? 'GET'),
      headers: (init.headers ?? {}) as Record<string, string>,
      body: typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : null,
    });
    const reply = this.replies.shift();
    if (reply === undefined) throw new Error(`FakeServer: no scripted reply for ${url}`);
    return new Response(JSON.stringify(reply.body), { status: reply.status });
  };

  paths(): string[] {
    return this.requests.map((r) => new URL(r.url).pathname + new URL(r.url).search);
  }
}

export const token = (access: string, refresh: string, expiresIn = 3600): Scripted => ({
  status: 200,
  body: { access_token: access, refresh_token: refresh, expires_in: expiresIn },
});

/// A server that answers by what is asked (function + action), for flows where the order is not the point.
export class RoutedServer {
  calls: { fn: string; action: string; body: Record<string, unknown> }[] = [];
  constructor(private readonly answer: (fn: string, action: string, body: Record<string, unknown>, nth: number) => Scripted) {}

  fetch = async (url: string, init: RequestInit): Promise<Response> => {
    const path = new URL(url).pathname;
    if (path.startsWith('/auth/')) return new Response(JSON.stringify(token('jwt', 'r').body), { status: 200 });
    const fn = path.replace('/functions/v1/', '');
    const body = typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : {};
    const action = String(body.action ?? '');
    const nth = this.calls.filter((c) => c.fn === fn && c.action === action).length;
    this.calls.push({ fn, action, body });
    const reply = this.answer(fn, action, body, nth);
    if (reply.wait) await reply.wait;
    return new Response(JSON.stringify(reply.body), { status: reply.status });
  };

  names(): string[] {
    return this.calls.map((c) => (c.action ? `${c.fn}:${c.action}` : c.fn));
  }
}
