// K108 (D238, Oscar O89 del 2): a question about the present always searches (so its answer has a source).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import type { LLMChunk, LLMRequest } from "./llm/types.ts";
import { mustSearch, WEB_PROMPT } from "./web.ts";

async function first(fragment: string): Promise<LLMRequest> {
  const seen: LLMRequest[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "claude-haiku-5-5", stream(r: LLMRequest): AsyncIterable<LLMChunk> { seen.push(r); return (async function* () { yield { type: "text", text: "Svar. källa: regeringen.se" } as LLMChunk; })(); } },
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, webSplitFromMs: 0 },
  });
  await (await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode: "text", language: "sv", context: {} }) }))).text();
  return seen[0];
}

Deno.test("K108: the present, 'sök/kolla', a link and a price must search; history and definitions do not", () => {
  for (const q of ["vem är Sveriges statsminister just nu", "vad är vädret idag i Stockholm", "kolla scb.se hur många bor i Sverige", "vad kostar en iPhone 17", "sök efter senaste nytt om valet"]) assert(mustSearch(q), q);
  for (const q of ["hur byter man däck", "vad betyder ambivalent", "när föll Berlinmuren", "sjung helan går"]) assertEquals(mustSearch(q), false, q);
});

Deno.test("K108: the answer engine is made to search (tool_choice any) for the present; not for an instruction or a song", async () => {
  const pm = await first("vem är Sveriges statsminister just nu");
  assertEquals(pm.toolChoice, { type: "any" });
  assert((pm.tools ?? []).length > 0);
  const tyre = await first("hur byter man däck");
  assertEquals(tyre.toolChoice, undefined, "an instruction may answer from knowledge");
  const song = await first("sjung helan går");
  assertEquals(song.toolChoice, undefined);
});

Deno.test("K108: the web prompt never lets a present-day answer guess, and keeps an instruction to five steps and 70 words", () => {
  assert(WEB_PROMPT.includes('never "cirka det senaste jag vet"'));
  assert(WEB_PROMPT.includes("at most five, and the whole answer at most 70 words (D238)"));
});
