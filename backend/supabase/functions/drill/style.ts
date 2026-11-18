/**
 * K95 (D220): "Hur ska det låta?" A free style (at most 80 characters) on a Säg text or an exam. With a style,
 * Haiku adds ElevenLabs v3 audio tags and pauses to the voice text (after the D196 rules), and the audio is made with
 * eleven_v3. The words never change: the code removes the tags and checks that the text is identical, else the
 * untagged text is used. Only tags from the allow-list are kept (tone, pace, pauses, whisper).
 *
 * The style is part of the audio's hash (`styledKey`), not the tagged text, so the same text and style is reused
 * (and costs 0) without asking Haiku again; Haiku is only asked for files that are made new.
 */
import type { LLMProvider } from "../answer/llm/types.ts";
import { sanitizeTagged } from "../answer/prompt.ts";

export const STYLE_MODEL = "eleven_v3";
export const STYLE_MAX = 80;
export const STYLE_VERSION = 1;

/**
 * v3 tags we allow. [whispers], [excited], [curious], [sighs], [laughs] are in ElevenLabs' own v3 pages (verified
 * by search, 2026-11-17); the calm/pace/pause words are tags in the same style that v3 reads as free direction
 * (untested assumption: not on a page we could open). Accent and dialect tags are left out (D220 point 3).
 */
export const STYLE_TAGS = [
  "calm", "slowly", "quickly", "clearly", "warm", "cheerful", "excited", "curious", "serious", "softly",
  "whispers", "sighs", "laughs", "short pause", "pause", "long pause", "emphasized",
] as const;
const ALLOWED = new Set<string>(STYLE_TAGS);

/** The style as stored and hashed: one line, trimmed, at most 80 characters; "" = none. */
export function cleanStyle(s: unknown): string {
  return typeof s === "string" ? s.replace(/[\u0000-\u001f]/g, " ").replace(/\s+/g, " ").trim().slice(0, STYLE_MAX) : "";
}

/** What the hash is made from: the untagged voice text and the style (and its version). */
export const styledKey = (spoken: string, style: string) => `${spoken}\u0001style:v${STYLE_VERSION}:${style.toLowerCase()}`;

/** The text with its tags removed, and for each character of it the position in the tagged text. */
export function stripTags(tagged: string): { plain: string; at: number[] } {
  let plain = "";
  const at: number[] = [];
  for (let i = 0; i < tagged.length;) {
    if (tagged[i] === "[") {
      const j = tagged.indexOf("]", i);
      if (j > i) {
        i = j + 1;
        // the space a tag leaves is folded into one
        while (tagged[i] === " " && (plain.endsWith(" ") || plain === "")) i++;
        continue;
      }
    }
    if (tagged[i] === " " && (plain === "" || plain.endsWith(" "))) {
      i++;
      continue;
    }
    plain += tagged[i];
    at.push(i);
    i++;
  }
  while (plain.endsWith(" ")) (plain = plain.slice(0, -1), at.pop());
  return { plain, at };
}

const norm = (s: string) => s.replace(/\s+/g, " ").trim();

/**
 * Keeps only allowed tags (lower case, no other brackets), and returns the tagged text only when its words are
 * exactly the voice text's; else null (the caller then uses the untagged text).
 */
export function checkTagged(spoken: string, tagged: string): string | null {
  if (typeof tagged !== "string" || tagged.length > spoken.length * 2 + 400) return null;
  const kept = tagged.replace(/\[([^\]\n]{1,30})\]/g, (_m, t: string) => ALLOWED.has(t.trim().toLowerCase()) ? `[${t.trim().toLowerCase()}]` : "")
    .replace(/[ \t]+/g, " ").trim();
  if (/[\[\]]/.test(kept.replace(/\[[a-z ]{1,30}\]/g, ""))) return null; // a bracket that is not a whole allowed tag
  return norm(stripTags(kept).plain) === norm(spoken) ? kept : null;
}

/** A character offset in the voice text to the same place in the tagged text (sentence ends, the short answer). */
export function mapOffset(tagged: string, offset: number): number {
  const { at } = stripTags(tagged);
  if (offset <= 0) return 0;
  if (offset >= at.length) return tagged.length;
  return at[offset - 1] + 1;
}

export const SYSTEM_PROMPT_STYLE = `You add ElevenLabs Eleven v3 audio tags to a text that will be read aloud.
Rules:
- Never change, add, remove or reorder a single word or punctuation mark of the text. Only insert tags.
- Use only these tags, in square brackets, lower case: ${STYLE_TAGS.map((t) => `[${t}]`).join(" ")}.
- Follow the listener's wish for how it should sound (in <style>). Put a tag at the start, and pauses where a person would breathe or where the listener needs time (for example to write while listening). Use few tags: at most one per sentence plus pauses.
- No accents, dialects or voices other than the speaker's own.
Return only the text with the tags, nothing else.`;

export type Styler = (spoken: string, style: string) => Promise<string | null>;

/** Haiku as the styler; a failure or a changed word gives null (the untagged text is used). */
export function haikuStyler(provider: LLMProvider, model = "claude-haiku-5-5"): Styler {
  return async (spoken, style) => {
    let text = "";
    try {
      for await (const c of provider.stream({
        system: SYSTEM_PROMPT_STYLE,
        user: `<style>${sanitizeTagged(style)}</style>\n<text>\n${sanitizeTagged(spoken)}\n</text>`,
        maxTokens: Math.min(4000, 200 + Math.ceil(spoken.length / 2)),
        cacheSystem: true,
        model,
        timeoutMs: 30_000,
      })) if (c.type === "text") text += c.text;
    } catch (e) {
      console.warn("style_failed", e instanceof Error ? e.message.slice(0, 120) : String(e));
      return null;
    }
    const out = checkTagged(spoken, text.replace(/^<text>\s*|\s*<\/text>$/g, "").trim());
    if (!out) console.warn("style_words_changed");
    return out;
  };
}

// ---------- K99 (D223): the AI picks a voice ----------
export interface CatalogVoiceLite { voice_id: string; name: string; description?: string | null; accent?: string | null; gender?: string | null; age?: string | null }

export const SYSTEM_PROMPT_VOICE_PICK = `You choose the voice that best fits how a listener wants a Swedish text to sound. You get <style> (the listener's wish, e.g. "lugnt", "glatt", "med skånsk dialekt") and <voices> (JSON: id, name, description, accent, gender, age). Return ONLY {"voice_id": "<one id from the list>", "reason": "<one short Swedish sentence, at most 12 words, why>"}. Choose only from the list; when nothing fits better, choose the calmest clear voice.`;

/** Haiku as the voice picker; anything not on the list gives null (the default voice is used). */
export function haikuVoicePicker(provider: LLMProvider, model = "claude-haiku-5-5") {
  return async (style: string, voices: CatalogVoiceLite[]): Promise<{ voice_id: string; reason: string } | null> => {
    let text = "";
    const list = voices.slice(0, 30).map((v) => ({ id: v.voice_id, name: v.name, description: (v.description ?? "").slice(0, 160), accent: v.accent ?? "", gender: v.gender ?? "", age: v.age ?? "" }));
    try {
      for await (const c of provider.stream({
        system: SYSTEM_PROMPT_VOICE_PICK, user: `<style>${sanitizeTagged(style)}</style>\n<voices>${sanitizeTagged(JSON.stringify(list))}</voices>`,
        maxTokens: 120, cacheSystem: true, model, timeoutMs: 15_000,
      })) if (c.type === "text") text += c.text;
      const j = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1)) as { voice_id?: string; reason?: string };
      const id = String(j.voice_id ?? "");
      if (!voices.some((v) => v.voice_id === id)) return null;
      return { voice_id: id, reason: String(j.reason ?? "").replace(/\s+/g, " ").trim().slice(0, 120) };
    } catch {
      return null;
    }
  };
}
