/**
 * D62: browsers may call the functions from the GitHub Pages demo and from localhost (for development) only.
 * Native apps send no Origin header and are unaffected. Extra origins (e.g. a custom domain) go in the
 * secret/env `CORS_ORIGINS` (comma separated). The functions' own responses carry `*`; this wrapper
 * replaces it with the caller's origin when allowed and removes it otherwise (the browser then blocks).
 */
export const DEFAULT_ORIGINS = ["https://aronstenlund-code.github.io"];
const LOCAL = /^https?:\/\/(?:localhost|127\.0\.0\.1|\[::1\])(?::\d{1,5})?$/;

export function originAllowed(origin: string, extra: string[] = []): boolean {
  return DEFAULT_ORIGINS.includes(origin) || extra.includes(origin) || LOCAL.test(origin);
}

export function extraOriginsFromEnv(
  env: { get(k: string): string | undefined } = Deno.env,
): string[] {
  return (env.get("CORS_ORIGINS") ?? "").split(",").map((s) => s.trim().replace(/\/+$/, "")).filter(
    Boolean,
  );
}

const ALLOW_HEADERS = "authorization, apikey, content-type, x-client-info, x-warm";
const ALLOW_METHODS = "GET, POST, DELETE, OPTIONS";

export function withCors(
  handler: (req: Request) => Promise<Response>,
  extra: string[] = [],
): (req: Request) => Promise<Response> {
  return async (req) => {
    const origin = req.headers.get("origin");
    if (req.method === "OPTIONS") {
      if (origin && !originAllowed(origin, extra)) return new Response(null, { status: 403 });
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": origin ?? "*",
          "access-control-allow-headers": ALLOW_HEADERS,
          "access-control-allow-methods": ALLOW_METHODS,
          "access-control-max-age": "86400",
          vary: "Origin",
        },
      });
    }
    const res = await handler(req);
    if (!origin) return res;
    const h = new Headers(res.headers);
    if (originAllowed(origin, extra)) {
      h.set("access-control-allow-origin", origin);
      h.set("access-control-allow-headers", ALLOW_HEADERS);
      h.set("access-control-allow-methods", ALLOW_METHODS);
      h.set("access-control-expose-headers", "retry-after");
    } else {
      h.delete("access-control-allow-origin");
    }
    h.append("vary", "Origin");
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers: h });
  };
}
