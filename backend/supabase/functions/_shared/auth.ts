import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";
import { HttpError } from "./errors.ts";

export interface AuthedUser {
  id: string;
  isAnonymous: boolean;
  /** D79: when the session signed in (JWT `amr` timestamp, unchanged by refreshes); unknown = undefined. */
  sessionStartSec?: number;
  /** K30: the email claim (email sign-in only) and the sign-in methods (`amr[].method`, e.g. "otp"). */
  email?: string;
  amr?: string[];
}

/** Earliest `amr[].timestamp` of a Supabase JWT payload (seconds), or undefined. */
export function sessionStart(payload: Record<string, unknown>): number | undefined {
  const amr = Array.isArray(payload.amr) ? payload.amr : [];
  const ts = amr
    .map((a) => Number((a as { timestamp?: unknown } | null)?.timestamp))
    .filter((t) => Number.isFinite(t) && t > 0);
  return ts.length ? Math.min(...ts) : undefined;
}

/** Resolves the caller from the request or throws HttpError(401). */
export type Authenticator = (req: Request) => Promise<AuthedUser>;

export function bearerToken(req: Request): string | null {
  const h = req.headers.get("authorization") ?? "";
  const m = /^Bearer\s+(\S+)$/i.exec(h);
  return m ? m[1] : null;
}

/**
 * Verifies a Supabase Auth JWT (anonymous sign-in produces role=authenticated, is_anonymous=true).
 * - Asymmetric signing keys (default for new projects): verified against the project's JWKS.
 * - Legacy HS256 projects: set SUPABASE_JWT_SECRET.
 * The project anon/publishable key is rejected: it has role=anon and no `sub`.
 * The Supabase gateway also checks the JWT (verify_jwt = true); this is defence in depth.
 */
export function createJwtAuthenticator(opts: {
  supabaseUrl: string;
  hs256Secret?: string;
}): Authenticator {
  const base = opts.supabaseUrl.replace(/\/+$/, "");
  const issuer = `${base}/auth/v1`;
  const jwks = createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`));
  const secret = opts.hs256Secret ? new TextEncoder().encode(opts.hs256Secret) : null;

  return async (req) => {
    const token = bearerToken(req);
    if (!token) throw new HttpError(401, "unauthorized", "Missing bearer token");
    try {
      const alg = JSON.parse(atob(token.split(".")[0].replace(/-/g, "+").replace(/_/g, "/"))).alg;
      const { payload } = alg === "HS256" && secret
        ? await jwtVerify(token, secret, { issuer, audience: "authenticated" })
        : await jwtVerify(token, jwks, { issuer, audience: "authenticated" });
      if (payload.role !== "authenticated" || typeof payload.sub !== "string" || !payload.sub) {
        throw new Error("not an authenticated user token");
      }
      return {
        id: payload.sub,
        isAnonymous: payload.is_anonymous === true,
        sessionStartSec: sessionStart(payload as Record<string, unknown>),
        ...(typeof payload.email === "string" && payload.email ? { email: payload.email } : {}),
        amr: (Array.isArray(payload.amr) ? payload.amr : [])
          .map((x) => String((x as { method?: unknown } | null)?.method ?? "")).filter(Boolean),
      };
    } catch (_e) {
      throw new HttpError(401, "unauthorized", "Invalid or expired token");
    }
  };
}
