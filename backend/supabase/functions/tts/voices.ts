export interface Voice {
  name: string;
  id: string;
}

export const VOICE_ID_RE = /^[A-Za-z0-9]{10,40}$/;
const NAME_RE = /^[\p{L}\p{N} _.'-]{1,40}$/u;
export const MAX_VOICES = 10;

/**
 * Parses the secret ELEVENLABS_VOICES: `Name1:voiceId1,Name2:voiceId2,Name3:voiceId3`.
 * - entries separated by commas (whitespace/newlines around entries are ignored)
 * - name and id separated by the FIRST colon; name = letters/digits/space/_.'- (Swedish letters ok), no comma/colon
 * - id = 10-40 letters/digits (ElevenLabs voice id)
 * Invalid or duplicate entries are skipped and reported in `errors` (never throws; the id is not echoed).
 */
export function parseVoices(raw: string | null | undefined): { voices: Voice[]; errors: string[] } {
  const voices: Voice[] = [];
  const errors: string[] = [];
  if (!raw || !raw.trim()) return { voices, errors };
  const parts = raw.split(",").map((p) => p.trim()).filter(Boolean);
  parts.forEach((part, i) => {
    const k = part.indexOf(":");
    if (k < 1) {
      errors.push(`entry ${i + 1}: expected Name:voiceId`);
      return;
    }
    const name = part.slice(0, k).trim();
    const id = part.slice(k + 1).trim();
    if (!NAME_RE.test(name)) errors.push(`entry ${i + 1}: invalid name`);
    else if (!VOICE_ID_RE.test(id)) errors.push(`entry ${i + 1} (${name}): invalid voice id`);
    else if (voices.some((v) => v.id === id || v.name.toLowerCase() === name.toLowerCase())) {
      errors.push(`entry ${i + 1} (${name}): duplicate`);
    } else if (voices.length >= MAX_VOICES) {
      errors.push(`entry ${i + 1}: more than ${MAX_VOICES} voices`);
    } else voices.push({ name, id });
  });
  return { voices, errors };
}
