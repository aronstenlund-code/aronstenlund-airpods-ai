import type { Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type RateLimiter } from "../_shared/ratelimit.ts";
import { BlockedUrl, checkResolved, checkUrl, FETCH_LIMITS, type Resolver } from "./guard.ts";
import { htmlToText, pageTitle } from "./html.ts";

/**
 * K81 (D204): `POST /fetch-url {"url"}` (signed in) -> {"url": <final>, "title", "text", "chars", "truncated"?}
 * Reads a web page's text for the material flow: the app then sends `text` to /exam drill or /exam read exactly as
 * a document's text (the cost follows the text, D176). Only http/https on the default ports; private, internal and
 * cloud-metadata addresses are refused, also after each of at most 3 redirects (SSRF); at most 2 MB and 10 s; no
 * JavaScript is run. HTML and plain text only. Nothing is stored. Errors (all 422 unless said):
 *   url_blocked (400, with "reason"), url_unreachable, url_too_large (413), url_not_text (415), url_empty.
 */
export interface FetchUrlDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  resolve: Resolver;
  fetchImpl?: typeof fetch;
  /** our own hosts (the Supabase project), never fetched */
  ownHosts?: string[];
  now?: () => number;
}

const MSG: Record<string, string> = {
  url_blocked: "Den adressen går inte att hämta. Kontrollera länken.",
  url_unreachable: "Sidan gick inte att nå. Kontrollera länken eller försök igen senare.",
  url_too_large: "Sidan är för stor att hämta (högst 2 MB).",
  url_not_text: "Länken leder inte till en vanlig webbsida. Ladda ner filen och lägg till den som fil i stället.",
  url_empty: "Sidan har ingen text som går att läsa (den kan kräva inloggning eller JavaScript). Kopiera texten och klistra in den i stället.",
};

export function createFetchUrlHandler(deps: FetchUrlDeps) {
  const fetchFn = deps.fetchImpl ?? fetch;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  const fail = (code: string, status = 422, extra: Record<string, unknown> = {}) =>
    json({ error: { code, message: MSG[code] ?? code, fallback: false }, ...extra }, status);

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const user = await deps.authenticate(req);
      const b = await req.json().catch(() => null) as { url?: unknown } | null;
      const raw = typeof b?.url === "string" ? b.url : "";
      if (!raw) throw new HttpError(400, "invalid_request", "url is required");
      const rl = await enforceLimits(deps.rateLimiter, "fetch_url", user.id, { perMinute: 10, perDay: 100, globalPerDay: 50_000 }, 1);
      if (!rl.allowed) throw new HttpError(429, "rate_limited", "För många länkar just nu. Vänta en stund.", { retryAfterSec: rl.retryAfterSec });

      const deadline = AbortSignal.timeout(FETCH_LIMITS.timeoutMs);
      let url: URL;
      let res: Response | null = null;
      try {
        url = checkUrl(raw, deps.ownHosts);
        for (let hop = 0; ; hop++) {
          await checkResolved(url, deps.resolve, deadline);
          res = await fetchFn(url.toString(), {
            redirect: "manual",
            signal: deadline,
            headers: { "user-agent": "EarMind/1 (+https://earmind.vercel.app) reads text for a student's study material", accept: "text/html,text/plain;q=0.9" },
          });
          if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
            await res.body?.cancel();
            if (hop >= FETCH_LIMITS.maxRedirects) return fail("url_unreachable", 422, { reason: "too_many_redirects" });
            // every hop is checked again: a public page may not send us to an internal address
            url = checkUrl(new URL(res.headers.get("location")!, url).toString(), deps.ownHosts);
            continue;
          }
          break;
        }
      } catch (e) {
        if (e instanceof BlockedUrl) return fail("url_blocked", 400, { reason: e.reason });
        console.warn("fetch_url_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
        return fail("url_unreachable");
      }
      if (!res || !res.ok) {
        await res?.body?.cancel();
        return fail("url_unreachable", 422, { status: res?.status ?? null });
      }
      const type = (res.headers.get("content-type") ?? "").toLowerCase();
      const html = /text\/html|application\/xhtml/.test(type);
      if (!html && !/text\/plain/.test(type)) {
        await res.body?.cancel();
        return fail("url_not_text", 415, { content_type: type.slice(0, 60) });
      }
      const len = Number(res.headers.get("content-length"));
      if (Number.isFinite(len) && len > FETCH_LIMITS.maxBytes) {
        await res.body?.cancel();
        return fail("url_too_large", 413);
      }
      // read at most 2 MB, whatever the server says
      const reader = res.body!.getReader();
      const parts: Uint8Array[] = [];
      let total = 0;
      try {
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          total += value.length;
          if (total > FETCH_LIMITS.maxBytes) {
            await reader.cancel();
            return fail("url_too_large", 413);
          }
          parts.push(value);
        }
      } catch (e) {
        console.warn("fetch_url_read_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
        return fail("url_unreachable");
      }
      const bytes = new Uint8Array(total);
      let off = 0;
      for (const p of parts) (bytes.set(p, off), off += p.length);
      const charset = /charset=([\w-]+)/i.exec(type)?.[1] ?? (/<meta[^>]+charset=["']?([\w-]+)/i.exec(new TextDecoder("latin1").decode(bytes.slice(0, 4096)))?.[1]) ?? "utf-8";
      let body: string;
      try {
        body = new TextDecoder(charset.toLowerCase(), { fatal: false }).decode(bytes);
      } catch {
        body = new TextDecoder("utf-8").decode(bytes);
      }
      const title = html ? pageTitle(body) : "";
      let text = html ? htmlToText(body) : body.replace(/\r/g, "").trim();
      if (text.replace(/\s+/g, "").length < 40) return fail("url_empty");
      const truncated = text.length > FETCH_LIMITS.textChars;
      if (truncated) text = text.slice(0, text.lastIndexOf("\n", FETCH_LIMITS.textChars) > 0 ? text.lastIndexOf("\n", FETCH_LIMITS.textChars) : FETCH_LIMITS.textChars);
      return json({ url: url.toString(), title, text, chars: text.length, ...(truncated ? { truncated: true } : {}) });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
