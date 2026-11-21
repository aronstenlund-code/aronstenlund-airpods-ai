// K116 (D254): a searched recipe or instruction is said only when the whole answer is there. Without the source line
// the answer is made once more from the page the search found; without a source then either: a fixed sentence.
// Other answers stream as before.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps } from "./handler.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";

type Turn = LLMChunk[];
function run(turns: Turn[], fragment: string, language = "sv") {
  const reqs: LLMRequest[] = [];
  let n = 0;
  const provider: LLMProvider = {
    name: "fake", model: "claude-haiku-5-5",
    stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      reqs.push(req);
      const t = turns[Math.min(n++, turns.length - 1)];
      return (async function* () { for (const c of t) yield c; })();
    },
  };
  const deps: Deps = {
    authenticate: () => Promise.resolve({ id: "user-1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(), provider, recordUsage: () => {}, config: DEFAULT_CONFIG,
  };
  return createHandler(deps)(new Request("http://x/answer", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ fragment, mode: "push_to_talk", language, context: {} }),
  })).then(async (res) => {
    const ev = (await res.text()).split("\n\n").filter(Boolean).map((f) => ({
      event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) as Record<string, unknown>,
    }));
    return { ev, reqs, said: ev.filter((e) => e.event === "delta").map((e) => e.data.text as string).join(""), done: ev.find((e) => e.event === "done")!.data };
  });
}
const searching: LLMChunk = { type: "searching", tool: "web_search" };
const page: LLMChunk = { type: "source", url: "https://www.ica.se/recept/kottbullar-722/", title: "Köttbullar" };
const usage: LLMChunk = { type: "usage", inputTokens: 10, outputTokens: 5, webSearches: 1 };
const RECIPE = "Blanda färs, ägg och ströbröd. Rulla bullar och stek dem i smör. ";

Deno.test("K116: a searched recipe with its source line is said whole, in one go, after the answer is complete", async () => {
  const r = await run([[searching, page, { type: "text", text: "Blanda färs, ägg " }, { type: "text", text: "och ströbröd. Rulla bullar och stek dem i smör. " }, { type: "text", text: "källa: ica.se" }, usage]], "recept på köttbullar");
  assertEquals(r.ev.filter((e) => e.event === "delta").length, 1, "one delta, not streamed");
  assert(r.said.startsWith("Blanda färs"), r.said);
  assertEquals(r.done.source, "ica.se");
  assertEquals(r.reqs.length, 1);
  assertEquals(r.reqs[0].wantSources, true);
});

Deno.test("K116: no source line: made once more from the page the search found (web_fetch), and that is said", async () => {
  const r = await run([
    [searching, page, { type: "text", text: RECIPE }, usage],
    [{ type: "searching", tool: "web_fetch" }, { type: "text", text: "Blanda 500 g färs med ett ägg. Stek bullarna. " }, { type: "text", text: "källa: ica.se" }, usage],
  ], "recept på köttbullar");
  assertEquals(r.reqs.length, 2);
  assert(r.reqs[1].user.includes("https://www.ica.se/recept/kottbullar-722/"), "the found page is named");
  assert(JSON.stringify(r.reqs[1].tools).includes("web_fetch"));
  assert(r.said.startsWith("Blanda femhundra gram") && !r.said.includes("ströbröd"), r.said);
  assertEquals(r.done.source, "ica.se");
});

Deno.test("K116: still no source: the fixed sentence (sv and en), never the recipe from memory", async () => {
  const noSrc: Turn = [searching, page, { type: "text", text: RECIPE }, usage];
  const sv = await run([noSrc, noSrc], "recept på köttbullar");
  assertEquals(sv.said.trim(), "Jag hittade inget recept med en säker källa.");
  assertEquals(sv.done.source_missing, undefined);
  assertEquals(sv.done.source_fallback, true);
  const en = await run([noSrc, noSrc], "recept på köttbullar", "en");
  assertEquals(en.said.trim(), "I couldn't find a recipe with a reliable source.");
});

Deno.test("K116: an ordinary searched answer still streams (not held)", async () => {
  const r = await run([[searching, { type: "text", text: "Riksdagen har 349 ledamöter. " }, { type: "text", text: "De väljs vart fjärde år. " }, { type: "text", text: "källa: riksdagen.se" }, usage]], "hur många ledamöter har riksdagen just nu");
  assert(r.ev.filter((e) => e.event === "delta").length >= 2, "streamed");
  assertEquals(r.reqs[0].wantSources, undefined);
});
