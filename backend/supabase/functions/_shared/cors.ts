/**
 * D62: browsers may call the functions from the GitHub Pages demo and from localhost (for development) only.
 * Native apps send no Origin header and are unaffected. Extra origins go in the secret/env `CORS_ORIGINS` (comma
 * separated, exact origins such as `https://earmind-xxx.vercel.app`, never a pattern): D202 moves the demo page and
 * the waitlist to Vercel (https://earmind.vercel.app, in DEFAULT_ORIGINS since it is public, K80); GitHub Pages stays
 * allowed until Vercel is live. The functions' own responses carry `*`; this wrapper
 * replaces it with the caller's origin when allowed and removes it otherwise (the browser then blocks).
 */
// K80 (D202): the demo page and waitlist on Vercel. A public address, so it is in code next to GitHub Pages (which
// stays until Vercel is verified); other or private origins still go in the CORS_ORIGINS secret.
export const DEFAULT_ORIGINS = ["https://aronstenlund-code.github.io", "https://earmind.vercel.app"];
const LOCAL = /^https?:\/\/(?:localhost|127\.0\.0\.1|\[::1\])(?::\d{1,5})?$/;
/** K114 (D249): the earmind project's own Vercel previews (team aron-cfdc): earmind-<hash>-aron-cfdc.vercel.app and
 *  earmind-git-<branch>-aron-cfdc.vercel.app. Another team's project can never end in -aron-cfdc.vercel.app. */
const PREVIEW = /^https:\/\/earmind-[a-z0-9]+(?:-[a-z0-9]+)*-aron-cfdc\.vercel\.app$/;

export function originAllowed(origin: string, extra: string[] = []): boolean {
  return DEFAULT_ORIGINS.includes(origin) || extra.includes(origin) || LOCAL.test(origin) || PREVIEW.test(origin);
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
