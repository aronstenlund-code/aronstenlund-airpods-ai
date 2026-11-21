import type { BackendConfig } from '../config';

/// The server said no, with words for the user where it has them (`{"error":{"code","message"}}`).
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly body: Record<string, unknown> = {},
  ) {
    super(message);
  }

  get isOutOfCredits(): boolean {
    return this.status === 402 || this.code === 'quota_exceeded';
  }
}

/// No answer at all: no network, or the browser refused the call.
export class OfflineError extends Error {}

export interface Session {
  accessToken: string;
  refreshToken: string;
  /// Milliseconds since 1970.
  expiresAt: number;
}

export interface KeyValue {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export type Fetch = (url: string, init: RequestInit) => Promise<Response>;

interface TokenReply {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  expires_at?: number;
}

/// Signs in anonymously and calls the functions, as the app does (backend/README.md, "Connect the app"):
/// `POST /auth/v1/signup` with `{}` gives an account for this browser; the token is renewed with the refresh token.
/// The account lives in the browser's storage: clearing the site's data is a new account with no exams.
export class Client {
  static readonly storageKey = 'earmind.session';
  /// Renewed this long before it runs out.
  static readonly marginMs = 60_000;

  private session: Session | null;
  private renewing: Promise<Session> | null = null;

  constructor(
    private readonly config: BackendConfig,
    private readonly fetchFn: Fetch,
    private readonly storage: KeyValue,
    private readonly now: () => number,
    /// D180: set for test traffic (what `x-earmind-test` carries); the server then makes silent audio and counts it
    /// apart. Null for users.
    private readonly testTraffic: string | null = null,
    /// D251: `en` or `sv`, sent with what the server answers in words.
    readonly lang: 'en' | 'sv' = 'en',
  ) {
    this.session = Client.read(storage);
  }

  get hasAccount(): boolean {
    return this.session !== null;
  }

  private static read(storage: KeyValue): Session | null {
    try {
      const raw = storage.getItem(Client.storageKey);
      if (raw === null) return null;
      const s = JSON.parse(raw) as Partial<Session>;
      if (typeof s.accessToken !== 'string' || typeof s.refreshToken !== 'string' || typeof s.expiresAt !== 'number') return null;
      return { accessToken: s.accessToken, refreshToken: s.refreshToken, expiresAt: s.expiresAt };
    } catch {
      return null;
    }
  }

  private keep(reply: TokenReply): Session {
    if (typeof reply.access_token !== 'string') throw new ApiError(500, 'bad_token', 'The sign-in gave no token.');
    const expiresAt = typeof reply.expires_at === 'number' ? reply.expires_at * 1000 : this.now() + (reply.expires_in ?? 3600) * 1000;
    const session: Session = { accessToken: reply.access_token, refreshToken: reply.refresh_token ?? '', expiresAt };
    this.session = session;
    this.storage.setItem(Client.storageKey, JSON.stringify(session));
    return session;
  }

  private async auth(path: string, body: unknown): Promise<Session> {
    const response = await this.send(`${this.config.projectURL}/auth/v1/${path}`, {
      method: 'POST',
      headers: { apikey: this.config.publishableKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      const code = String(data.error_code ?? data.code ?? `http_${response.status}`);
      throw new ApiError(response.status, code, String(data.msg ?? data.message ?? ''), data);
    }
    return this.keep(data as TokenReply);
  }

  /// A token that is good now: the one kept, a renewed one, or a new anonymous account.
  async token(): Promise<string> {
    const current = this.session;
    if (current !== null && current.expiresAt - this.now() > Client.marginMs) return current.accessToken;
    return (await this.renew()).accessToken;
  }

  private renew(): Promise<Session> {
    if (this.renewing !== null) return this.renewing; // two calls at once share one sign-in
    const work = (async () => {
      const current = this.session;
      if (current !== null && current.refreshToken !== '') {
        try {
          return await this.auth('token?grant_type=refresh_token', { refresh_token: current.refreshToken });
        } catch (error) {
          // Only a real no ends the account in this browser; a server fault or no network keeps it for the next try.
          const refused = error instanceof ApiError && [400, 401, 403, 404].includes(error.status);
          if (!refused) throw error;
          this.session = null;
          this.storage.removeItem(Client.storageKey);
        }
      }
      return this.auth('signup', {});
    })();
    this.renewing = work.finally(() => {
      this.renewing = null;
    });
    return this.renewing;
  }

  private async send(url: string, init: RequestInit): Promise<Response> {
    try {
      return await this.fetchFn(url, init);
    } catch (error) {
      throw new OfflineError(error instanceof Error ? error.message : 'offline');
    }
  }

  /// `POST` (or `GET` without a body) to a function with the user's token. A 401 renews the token and asks once more.
  async call<T>(fn: string, body?: Record<string, unknown>, query = ''): Promise<T> {
    const once = async (): Promise<Response> => {
      const headers: Record<string, string> = {
        Authorization: `Bearer ${await this.token()}`,
        apikey: this.config.publishableKey,
      };
      if (body !== undefined) headers['Content-Type'] = 'application/json';
      // K114: the web's own language choice, for the server's words to the user.
      headers['x-earmind-lang'] = this.lang;
      if (this.testTraffic !== null) headers['x-earmind-test'] = this.testTraffic;
      return this.send(`${this.config.projectURL}/functions/v1/${fn}${query}`, {
        method: body === undefined ? 'GET' : 'POST',
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    };
    let response = await once();
    if (response.status === 401) {
      if (this.session !== null) this.session = { ...this.session, expiresAt: 0 };
      response = await once();
    }
    const data = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      const error = (data.error ?? {}) as { code?: string; message?: string };
      throw new ApiError(response.status, error.code ?? `http_${response.status}`, error.message ?? '', data);
    }
    return data as T;
  }
}
