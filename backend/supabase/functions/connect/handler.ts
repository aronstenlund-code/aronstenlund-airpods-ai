import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import type { TokenCrypto } from "../_shared/crypto.ts";
import { authorizeUrl, type ConnectionStore, exchangeCode, isPremium, rowFromTokens, type SpotifyApp, type TokenSet } from "../_shared/spotify.ts";

/**
 * K36 (D122, D125): connections to outside services (first: Spotify). Tokens never reach the app or the repo: they are
 * encrypted (AES-GCM, CONNECTIONS_KEY) and stored in `connections` (service role only).
 *   POST   /connect {"provider": "spotify"}  (user JWT) -> {"url"}: open it in ASWebAuthenticationSession
 *   GET    /connect/callback?code&state      (Spotify redirects here) -> 302 to RETURN_URL?provider=spotify&status=…
 *          status: ok | premium_required (connected, but playback needs Premium) | denied | error
 *   GET    /connect                          (user JWT) -> {"connections": [{"provider", "premium"}], "available": {...}}
 *   DELETE /connect?provider=spotify         (user JWT) -> {"removed"}: disconnect, the row is deleted
 * The state is signed (HMAC) with the user id and expires after 10 minutes, so a callback cannot connect another
 * user's account. Without SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET / CONNECTIONS_KEY the endpoint says so (503).
 */
export const STATE_TTL_MS = 10 * 60 * 1000;
export const DEFAULT_RETURN_URL = "lumen://connect";

export interface ConnectDeps {
  authenticate: Authenticator;
  store: ConnectionStore | null;
  crypto: TokenCrypto | null;
  spotify: SpotifyApp | null;
  returnUrl?: string;
  fetchImpl?: typeof fetch;
  now?: () => number;
  /** For tests: the token exchange (default: Spotify's token endpoint). */
  exchange?: (code: string) => Promise<TokenSet>;
}

export function createConnectHandler(deps: ConnectDeps) {
  const now = () => deps.now?.() ?? Date.now();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  const back = (status: string) => {
    const u = new URL(deps.returnUrl || DEFAULT_RETURN_URL);
    u.searchParams.set("provider", "spotify");
    u.searchParams.set("status", status);
    return new Response(null, { status: 302, headers: { location: u.toString(), "cache-control": "no-store" } });
  };
  const ready = () => !!(deps.store && deps.crypto && deps.spotify);
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    const url = new URL(req.url);
    try {
      if (url.pathname.endsWith("/callback")) {
        if (req.method !== "GET") throw new HttpError(405, "method_not_allowed", "Use GET");
        if (!ready()) return back("error");
        if (url.searchParams.get("error")) return back("denied"); // the user said no on Spotify's page
        const st = await deps.crypto!.verifyState(url.searchParams.get("state") ?? "", now());
        const code = url.searchParams.get("code") ?? "";
        if (!st || typeof st.u !== "string" || st.p !== "spotify" || !code || code.length > 2000) return back("error");
        try {
          const t = await (deps.exchange ?? ((c) => exchangeCode(deps.spotify!, c, deps.fetchImpl ?? fetch)))(code);
          const premium = await isPremium(t.access_token, deps.fetchImpl ?? fetch);
          await deps.store!.upsert(await rowFromTokens(st.u, t, deps.crypto!, premium, now()));
          console.log(JSON.stringify({ event: "connected", provider: "spotify", premium }));
          return back(premium === false ? "premium_required" : "ok");
        } catch (e) {
          console.warn("connect_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
          return back("error");
        }
      }
      const user = await deps.authenticate(req);
      if (req.method === "GET") {
        const rows = deps.store ? await deps.store.list(user.id) : [];
        return json({ connections: rows.map((r) => ({ provider: r.provider, premium: r.premium })), available: { spotify: ready() } });
      }
      if (req.method === "DELETE") {
        if (url.searchParams.get("provider") !== "spotify") throw new HttpError(400, "invalid_request", "provider=spotify");
        return json({ removed: deps.store ? await deps.store.remove(user.id, "spotify") : 0 });
      }
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use GET, POST or DELETE");
      const b = await req.json().catch(() => ({}));
      if (b?.provider !== "spotify") throw new HttpError(400, "invalid_request", 'Send {"provider": "spotify"}');
      if (!ready()) throw new HttpError(503, "unconfigured", "Spotify is not set up on the server yet");
      const state = await deps.crypto!.signState({ u: user.id, p: "spotify", exp: now() + STATE_TTL_MS, n: crypto.randomUUID() });
      return json({ url: authorizeUrl(deps.spotify!, state) });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
