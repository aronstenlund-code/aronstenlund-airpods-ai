import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createCardsHandler, parseCards } from "./handler.ts";

class FakeLLM implements LLMProvider {
  readonly name = "fake";
  readonly model = "fake-1";
  calls: LLMRequest[] = [];
  constructor(private reply: string) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.reply };
    yield { type: "usage", inputTokens: 900, outputTokens: 500 };
  }
}
const post = (b: unknown) =>
  new Request("http://x/study-cards", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify(b),
  });
const REPLY = JSON.stringify({
  cards: [{ q: "Var sker fotosyntesen?", a: "I kloroplasterna." }, { q: "Vad bildas?", a: "Socker och syre." }],
  test: Array.from({ length: 6 }, (_, i) => ({ q: `Testfråga ${i + 1}?`, a: `Svar ${i + 1}.` })),
});

Deno.test("D81 study cards: cards + five test questions, nothing of the text logged", async () => {
  const logged: Record<string, unknown>[] = [];
  const llm = new FakeLLM(REPLY);
  const h = createCardsHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: llm,
    recordUsage: (r) => void logged.push(r),
  });
  const r = await h(post({ summary: "Vi gick igenom fotosyntesen i kloroplasterna.", profile: "Årskurs: Åk 7.", cards: 2 }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.cards.length, 2);
  assertEquals(j.test.length, 5);
  assert(llm.calls[0].user.includes("<count>3</count>"), "at least 3 cards are asked for");
  assert(!JSON.stringify(logged).includes("fotosyntes"), "the summary is never logged");
  assertEquals((await h(post({}))).status, 400);
  assertEquals((await h(post({ summary: "x".repeat(6001) }))).status, 413);
});

Deno.test("D81 study cards: malformed model output gives nothing, not garbage", () => {
  assertEquals(parseCards("inget json", 8), { cards: [], test: [] });
  const r = parseCards('{"cards":[{"q":"a?","a":"b"},{"q":"a?","a":"c"},{"q":"","a":"x"}],"test":[]}', 8);
  assertEquals(r.cards, [{ q: "a?", a: "b" }]);
});
