import { CORS_HEADERS, errorResponse, HttpError, toHttpError } from "../_shared/errors.ts";

/**
 * K6 (fun voices, owner: never a real person's voice, name or traits): `POST /voice-lab` - service role only
 * (the owner's key, used from the "Credits ready" workflow, never from the app). One action:
 *   {"action": "previews", "voice_description": "...", "text": "100-1000 characters"}
 *   -> ElevenLabs Voice Design previews (POST /v1/text-to-voice/design): {"previews": [{generated_voice_id,
 *      audio_base_64, media_type, duration_secs}], "text"}.
 * Previews cost credits but add NO voice to the account; saving one (POST /v1/text-to-voice) is an account change
 * the owner approves first, so it is not here.
 */
export interface VoiceLabDeps {
  serviceKey: string | null;
  elevenLabsKey: string | null;
  fetchImpl?: typeof fetch;
  baseUrl?: string;
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

/** Never a real person: names of public figures or "som X / like X" in a description are refused. */
const REAL_PERSON = /\b(?:imitat\w*|impersonat\w*|sounds? like|voice of|in the style of|låter som|härma\w*|trump|obama|belfort|biden|musk|swift|beckham|zlatan|greta|kungen|prins|prinsessa|statsminister|president)\b/i;

export function createVoiceLabHandler(deps: VoiceLabDeps) {
  const doFetch = deps.fetchImpl ?? fetch;
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...CORS_HEADERS } });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST");
      const m = /^Bearer\s+(\S+)$/i.exec(req.headers.get("authorization") ?? "");
      if (!deps.serviceKey || !m || !safeEqual(m[1], deps.serviceKey)) throw new HttpError(401, "unauthorized", "Service role only");
      if (!deps.elevenLabsKey) throw new HttpError(503, "provider_unconfigured", "ElevenLabs key not configured");
      const b = (await req.json().catch(() => null)) as Record<string, unknown> | null;
      if (b?.action !== "previews") throw new HttpError(400, "invalid_request", "action must be previews");
      const description = typeof b.voice_description === "string" ? b.voice_description.trim() : "";
      const text = typeof b.text === "string" ? b.text.trim() : "";
      if (description.length < 20 || description.length > 1000) throw new HttpError(400, "invalid_request", "voice_description: 20-1000 characters");
      if (text.length < 100 || text.length > 1000) throw new HttpError(400, "invalid_request", "text: 100-1000 characters");
      if (REAL_PERSON.test(description)) throw new HttpError(400, "real_person", "Never a real person's voice, name or traits (owner decision)");
      const r = await doFetch(`${deps.baseUrl ?? "https://api.elevenlabs.io"}/v1/text-to-voice/design?output_format=mp3_44100_64`, {
        method: "POST",
        headers: { "xi-api-key": deps.elevenLabsKey, "content-type": "application/json" },
        body: JSON.stringify({ voice_description: description, text, model_id: "eleven_multilingual_ttv_v2" }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) {
        const quota = r.status === 401 || r.status === 402 || /quota|credit/i.test(JSON.stringify(j));
        throw new HttpError(quota ? 503 : 502, quota ? "provider_quota" : "provider_error", `ElevenLabs answered ${r.status}`);
      }
      const previews = (Array.isArray(j.previews) ? j.previews : []).map((p: Record<string, unknown>) => ({
        generated_voice_id: p.generated_voice_id,
        audio_base_64: p.audio_base_64,
        media_type: p.media_type,
        duration_secs: p.duration_secs,
      }));
      return json({ previews, text: j.text ?? text });
    } catch (e) {
      return errorResponse(toHttpError(e));
    }
  };
}
