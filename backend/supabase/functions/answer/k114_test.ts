// Oscar O91 N5 (nightly eval 2026-11-20): searched answers with an instruction or a recipe ran over 80 words
// (praktiskt-03 däckbyte, praktiskt-04 köttbullar) although the web prompt says at most 70. A searched answer is now
// cut in code after the last whole sentence within 80 words, as an asked length (K42.3); songs and quotes never.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import type { LLMChunk, LLMRequest } from "./llm/types.ts";

const SENT = "Lossa hjulmuttrarna ett halvt varv med fälgkorset medan bilen står på marken."; // 13 words
async function spoken(fragment: string, searched: boolean, sentences = 10): Promise<{ text: string; done: Record<string, unknown> }> {
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "f", model: "claude-sonnet-5-5",
      stream(_r: LLMRequest): AsyncIterable<LLMChunk> {
        return (async function* () {
          if (searched) yield { type: "searching", tool: "web_search" } as LLMChunk;
          for (let i = 0; i < sentences; i++) yield { type: "text", text: (i ? " " : "") + SENT } as LLMChunk;
          yield { type: "text", text: " Källa: clasohlson.com." } as LLMChunk;
          yield { type: "usage", inputTokens: 100, outputTokens: 200, webSearches: searched ? 1 : 0 } as LLMChunk;
        })();
      },
    },
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, webSplitFromMs: 0 },
  });
  const raw = await (await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode: "text", language: "sv", context: {} }) }))).text();
  let text = "", done: Record<string, unknown> = {}, ev = "";
  for (const line of raw.split("\n")) {
    if (line.startsWith("event: ")) ev = line.slice(7);
    else if (line.startsWith("data: ")) {
      const d = JSON.parse(line.slice(6));
      if (ev === "delta") text += d.text ?? "";
      if (ev === "done") done = d;
    }
  }
  return { text, done };
}
const wordsOf = (t: string) => t.trim().split(/\s+/).filter(Boolean).length;

Deno.test("O91 N5: a searched answer is cut after the last whole sentence within 80 words; its source is kept", async () => {
  const r = await spoken("hur byter man däck", true);
  const spokenOnly = r.text.replace(/\s*Källa:[^.]*\.?\s*$/u, "");
  assert(wordsOf(spokenOnly) <= 80, `${wordsOf(spokenOnly)} words`);
  assert(wordsOf(spokenOnly) >= 70, "whole sentences up to the cap stay");
  assert(/[.!?]$/.test(spokenOnly.trim()));
  assertEquals(r.done.source, "clasohlson.com");
});

Deno.test("O91 N5: an answer that did not search is not cut by this cap", async () => {
  const r = await spoken("berätta om fotosyntesen", false, 7); // 91 words, no search
  assert(wordsOf(r.text.replace(/\s*Källa:[^.]*\.?\s*$/u, "")) > 80);
});

Deno.test("O91 N5: a song (textOn) is never cut by the web cap, also when it searched", async () => {
  const r = await spoken("sjung helan går", true);
  assert(wordsOf(r.text.replace(/\s*Källa:[^.]*\.?\s*$/u, "")) > 80);
});

Deno.test("O92/N5: an instruction starts with its first step (no summary of the steps first); a recipe names only the main ingredients so the steps fit", async () => {
  const { WEB_PROMPT } = await import("./web.ts");
  assert(WEB_PROMPT.includes("the first sentence is already the first step, never a sentence that sums the steps up"), "däckbyte said the steps twice");
  assert(WEB_PROMPT.includes("only the main ingredients in one sentence, then the steps in order to the end"), "köttbullar ended before the frying");
  assert(WEB_PROMPT.includes("at most five, and the whole answer at most 70 words (D238)"), "K108's rule kept");
});

Deno.test("O92 (live 16:05): a sentence about which source the steps follow is meta and goes; a real disagreement stays (K103)", async () => {
  const { isSearchMeta } = await import("./speech.ts");
  assert(isSearchMeta("Källorna är inte helt samstämmiga om ordningen, så jag håller mig till de steg som Clas Ohlson beskriver."));
  assert(isSearchMeta("Jag följer det recept som Ica skriver."));
  assert(!isSearchMeta("Nilen räknas oftast som världens längsta flod, men vissa mätningar ger Amazonas."));
  assert(!isSearchMeta("Lossa sedan bultarna ett kvarts varv med hjulmuttern medan hjulet står på marken."));
});

Deno.test("O93: a searched answer without a källa line is marked source_missing (never given a source it did not use)", async () => {
  const { createHandler: mk, DEFAULT_CONFIG: cfg } = await import("./handler.ts");
  const h = mk({
    authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "claude-sonnet-5-5", stream(_r: LLMRequest): AsyncIterable<LLMChunk> {
      return (async function* () {
        yield { type: "searching", tool: "web_search" } as LLMChunk;
        // K116 (D254): a recipe without its source line now gets a fixed sentence (k116_held_test.ts); an ordinary
        // searched answer is still marked
        yield { type: "text", text: "Sverige har cirka tio och en halv miljon invånare." } as LLMChunk;
        yield { type: "usage", inputTokens: 100, outputTokens: 40, webSearches: 1 } as LLMChunk;
      })();
    } },
    recordUsage: () => {},
    config: { ...cfg, webSplitFromMs: 0 },
  });
  const raw = await (await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment: "hur många bor i sverige just nu", mode: "text", language: "sv", context: {} }) }))).text();
  const done = JSON.parse(raw.split("event: done\ndata: ")[1].split("\n")[0]);
  assertEquals(done.source ?? null, null, "never a source the answer did not name");
  assertEquals(done.source_missing, true);
  const { WEB_PROMPT } = await import("./web.ts");
  assert(WEB_PROMPT.includes("a searched answer is built on the page you found and always ends with the källa line"));
});
