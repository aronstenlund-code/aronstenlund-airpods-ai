import type { LLMChunk, LLMProvider, LLMRequest } from "./types.ts";

/** Deterministic offline provider used for tests, local dev and "no key yet" runs. It follows the
 *  same wire protocol as the real model (JSON header, then answer text), reading the tagged prompt. */
export class MockProvider implements LLMProvider {
  readonly name = "mock";
  readonly model = "mock-1";
  constructor(private opts: { delayMs?: number; chunkSize?: number } = {}) {}

  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    const tag = (n: string) =>
      new RegExp(`<${n}>([\\s\\S]*?)</${n}>`).exec(req.user)?.[1]?.trim() ?? "";
    const mode = tag("mode");
    const lang = tag("language");
    const fragment = tag("fragment");
    const lower = fragment.toLowerCase();

    const questionish =
      /^(vad|vem|vilket|vilken|vilka|när|hur|varför|var|kan|what|who|when|how|why|where|can)\b/
        .test(lower) ||
      /\b(plus|minus|gånger|delat|roten|kvadrat|procent|derivatan)\b/.test(lower) ||
      /^[a-zåäö-]+$/i.test(lower) && lower.length > 4 || /\b(förklara|explain)\b/.test(lower);
    const isQ = mode === "auto" ? questionish : true;
    const confidence = fragment.length < 3 ? 0.2 : 0.9;
    const header = JSON.stringify({
      is_question: isQ,
      reconstructed_question: fragment,
      confidence,
    });

    const answer = !isQ
      ? ""
      : confidence < 0.6
      ? (lang === "en" ? "Did you mean that?" : "Menar du det?")
      : (lang === "en" ? `Mock answer to: ${fragment}.` : `Mocksvar på: ${fragment}.`);

    // Direct prompts carry no <mode> tag and expect plain text without a JSON header.
    const direct = !req.user.includes("<mode>");
    const text = direct ? answer : answer ? `${header}\n${answer}` : header;
    const size = this.opts.chunkSize ?? 6;
    yield { type: "usage", inputTokens: Math.ceil(req.user.length / 4) + 400, outputTokens: 0 };
    for (let i = 0; i < text.length; i += size) {
      if (req.signal?.aborted) return;
      if (this.opts.delayMs) await new Promise((r) => setTimeout(r, this.opts.delayMs));
      yield { type: "text", text: text.slice(i, i + size) };
    }
    yield { type: "usage", outputTokens: Math.ceil(text.length / 3) };
  }
}
