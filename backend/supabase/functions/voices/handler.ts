import { type Authenticator } from "../_shared/auth.ts";
import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";
import { enforceLimits, type Limits, type RateLimiter } from "../_shared/ratelimit.ts";
import { activeVoiceId, isRetired, type Voice } from "../tts/voices.ts";

export const VOICES_LIMITS: Limits = { perMinute: 30, perDay: 1000, globalPerDay: 20000 };

/** K96 (D220): a voice the app may offer, with ElevenLabs' free preview (playing it costs no credits). */
export interface CatalogVoice {
  voice_id: string;
  name: string;
  gender?: string | null;
  age?: string | null;
  accent?: string | null;
  language?: string | null;
  preview_url?: string | null;
  description?: string | null;
  /** K99 (D223): a voice under review (caricatures): shown only to admin until Aron approves it */
  review?: boolean | null;
}

export interface VoicesDeps {
  authenticate: Authenticator;
  rateLimiter: RateLimiter;
  voices: Voice[];
  defaultVoiceId: string | null;
  /** K96: the curated list (voice_catalog, 12–20 voices that read Swedish); empty until filled */
  catalog?: () => Promise<CatalogVoice[]>;
  /** K99: admin (credit_admins) also sees voices under review */
  isAdmin?: (userId: string) => Promise<boolean>;
  /** K96: ElevenLabs' voice library (GET /v1/shared-voices, language sv): no credits */
  searchLibrary?: (q: { search?: string; accent?: string; gender?: string; page?: number; anyLanguage?: boolean; language?: string }) => Promise<CatalogVoice[]>;
}

const clip = (v: string | null, n: number) => (v ?? "").replace(/[^\p{L}\p{N} _.'-]/gu, "").slice(0, n);

/** GET /voices -> { voices: [{name,id}], default_id }. Names and ids only; no secrets, no API calls. */
export function createVoicesHandler(deps: VoicesDeps): (req: Request) => Promise<Response> {
  return async (req) => {
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: { ...CORS_HEADERS, "access-control-allow-methods": "GET, OPTIONS" },
      });
    }
    try {
      if (req.method !== "GET") throw new HttpError(405, "method_not_allowed", "Use GET");
      const user = await deps.authenticate(req);
      const rl = await enforceLimits(deps.rateLimiter, "voices", user.id, VOICES_LIMITS);
      if (!rl.allowed) {
        throw new HttpError(429, "rate_limited", "Too many requests", {
          retryAfterSec: rl.retryAfterSec,
        });
      }
      // K114 (D252): a retired voice (Marlon) is never listed, accepted or the default
      const listed = deps.voices.filter((v) => !isRetired(v.id));
      const def = activeVoiceId(deps.defaultVoiceId) ?? listed[0]?.id ?? null;
      const url = new URL(req.url);
      if (url.searchParams.get("library") === "1") {
        // K96: search ElevenLabs' library (Swedish); a voice found here is not usable before it is in the catalog
        const lr = await enforceLimits(deps.rateLimiter, "voices_library", user.id, { perMinute: 10, perDay: 100, globalPerDay: 10_000 });
        if (!lr.allowed) throw new HttpError(429, "rate_limited", "Too many requests", { retryAfterSec: lr.retryAfterSec });
        const found = deps.searchLibrary
          ? await deps.searchLibrary({
            search: clip(url.searchParams.get("search"), 40) || undefined,
            accent: clip(url.searchParams.get("accent"), 30) || undefined,
            gender: clip(url.searchParams.get("gender"), 10) || undefined,
            page: Math.max(0, Math.min(20, Number(url.searchParams.get("page")) || 0)),
            // K99: accents (a Chinese or Indian voice) are found among voices of other languages too
            ...(url.searchParams.get("lang") === "any" ? { anyLanguage: true } : {}),
            // K114 (D252): native English voices for English users
            ...(url.searchParams.get("lang") === "en" ? { language: "en" } : {}),
          }).then((l) => l.filter((v) => !isRetired(v.voice_id)))
            .catch((e) => (console.warn("voice_library_failed", String(e).slice(0, 120)), [] as CatalogVoice[]))
          : [];
        return new Response(JSON.stringify({ library: found, selectable: false }), {
          status: 200, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "private, max-age=300", ...CORS_HEADERS },
        });
      }
      const all = (deps.catalog ? await deps.catalog().catch(() => [] as CatalogVoice[]) : []).filter((v) => !isRetired(v.voice_id));
      const admin = all.some((v) => v.review) && deps.isAdmin ? await deps.isAdmin(user.id).catch(() => false) : false;
      const catalog = all.filter((v) => !v.review || admin);
      return new Response(
        JSON.stringify({
          voices: listed.map((v) => ({ name: v.name, id: v.id })),
          default_id: def,
          // Angela Fable (A140): the voice a text gets when none is chosen, with a name the app can show
          ...(def ? { default_voice: { voice_id: def, name: all.find((v) => v.voice_id === def)?.name ?? listed.find((v) => v.id === def)?.name ?? "Standard", in_catalog: all.some((v) => v.voice_id === def) } } : {}),
          // K96 (D220): choose one with save's drill.voice_id; it is locked for that text (D151)
          ...(deps.catalog ? { catalog } : {}),
        }),
        {
          status: 200,
          headers: {
            "content-type": "application/json; charset=utf-8",
            "cache-control": "private, max-age=300",
            ...CORS_HEADERS,
          },
        },
      );
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
