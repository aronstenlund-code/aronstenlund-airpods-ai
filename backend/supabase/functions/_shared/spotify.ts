import type { TokenCrypto } from "./crypto.ts";

/**
 * K36 (D125): Spotify through the Web API with OAuth (authorization code flow; the client secret stays on the
 * server). Verified in Spotify's docs 2026-11-11 (February 2026 migration guide, quota modes): a Development Mode app
 * allows at most 5 authorised users, needs the app owner to have Premium, and search returns at most 10 results;
 * playback control (play, pause, next) works only for Premium accounts. Extended quota is for organisations
 * (~250k monthly users). So this is a pilot for Aron and a few testers, not for every student.
 */
export const SPOTIFY_ACCOUNTS = "https://accounts.spotify.com";
export const SPOTIFY_API = "https://api.spotify.com/v1";
export const SPOTIFY_SCOPES = ["user-read-playback-state", "user-modify-playback-state", "playlist-read-private", "user-read-private"];

export interface ConnectionRow {
  user_id: string;
  provider: "spotify";
  access_enc: string;
  refresh_enc: string | null;
  expires_at: string;
  scope: string | null;
  premium: boolean | null;
}
export interface ConnectionStore {
  get(userId: string, provider: "spotify"): Promise<ConnectionRow | null>;
  upsert(row: ConnectionRow): Promise<void>;
  remove(userId: string, provider: "spotify"): Promise<number>;
  list(userId: string): Promise<{ provider: string; premium: boolean | null; updated_at?: string }[]>;
}

export interface SpotifyApp {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
}

export function authorizeUrl(app: SpotifyApp, state: string): string {
  const q = new URLSearchParams({
    client_id: app.clientId,
    response_type: "code",
    redirect_uri: app.redirectUri,
    scope: SPOTIFY_SCOPES.join(" "),
    state,
    show_dialog: "true",
  });
  return `${SPOTIFY_ACCOUNTS}/authorize?${q}`;
}

export interface TokenSet {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  scope?: string;
}

async function tokenCall(app: SpotifyApp, form: Record<string, string>, fetchImpl: typeof fetch): Promise<TokenSet> {
  const r = await fetchImpl(`${SPOTIFY_ACCOUNTS}/api/token`, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      authorization: `Basic ${btoa(`${app.clientId}:${app.clientSecret}`)}`,
    },
    body: new URLSearchParams(form).toString(),
    signal: AbortSignal.timeout(8000),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || typeof j?.access_token !== "string") throw new Error(`spotify token ${r.status} ${String(j?.error ?? "")}`.trim());
  return j as TokenSet;
}

export const exchangeCode = (app: SpotifyApp, code: string, fetchImpl: typeof fetch = fetch) =>
  tokenCall(app, { grant_type: "authorization_code", code, redirect_uri: app.redirectUri }, fetchImpl);

export async function isPremium(accessToken: string, fetchImpl: typeof fetch = fetch): Promise<boolean | null> {
  const r = await fetchImpl(`${SPOTIFY_API}/me`, { headers: { authorization: `Bearer ${accessToken}` }, signal: AbortSignal.timeout(6000) });
  if (!r.ok) {
    await r.body?.cancel();
    return null;
  }
  const j = await r.json().catch(() => ({}));
  return typeof j?.product === "string" ? j.product === "premium" : null;
}

export async function rowFromTokens(userId: string, t: TokenSet, tc: TokenCrypto, premium: boolean | null, now: number, oldRefresh?: string | null): Promise<ConnectionRow> {
  return {
    user_id: userId,
    provider: "spotify",
    access_enc: await tc.seal(t.access_token),
    refresh_enc: t.refresh_token ? await tc.seal(t.refresh_token) : oldRefresh ?? null,
    expires_at: new Date(now + Math.max(60, t.expires_in - 60) * 1000).toISOString(),
    scope: t.scope?.slice(0, 500) ?? null,
    premium,
  };
}

/** A valid access token for the user (refreshed when it has expired), or null when not connected / revoked. */
export async function accessToken(
  userId: string,
  deps: { store: ConnectionStore; crypto: TokenCrypto; app: SpotifyApp; fetchImpl?: typeof fetch; now?: () => number },
): Promise<{ token: string; premium: boolean | null } | null> {
  const row = await deps.store.get(userId, "spotify");
  if (!row) return null;
  const now = deps.now?.() ?? Date.now();
  if (Date.parse(row.expires_at) > now) return { token: await deps.crypto.open(row.access_enc), premium: row.premium };
  if (!row.refresh_enc) return null;
  try {
    const t = await tokenCall(deps.app, { grant_type: "refresh_token", refresh_token: await deps.crypto.open(row.refresh_enc) }, deps.fetchImpl ?? fetch);
    await deps.store.upsert(await rowFromTokens(userId, t, deps.crypto, row.premium, now, row.refresh_enc));
    return { token: t.access_token, premium: row.premium };
  } catch (e) {
    console.warn("spotify_refresh_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
    return null;
  }
}
