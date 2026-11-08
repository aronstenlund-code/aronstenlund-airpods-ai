import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createEvalHandler } from "./handler.ts";

class Fake implements LLMProvider {
  readonly name = "fake";
  readonly model = "claude-haiku-5-5";
  calls: LLMRequest[] = [];
  constructor(private reply: (r: LLMRequest) => string) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.reply(req) };
    yield { type: "usage", inputTokens: 100, outputTokens: 20 };
  }
}
const post = (b: unknown) => new Request("http://x/provlage-eval", { method: "POST", headers: { "x-forwarded-for": "1.2.3.4" }, body: JSON.stringify(b) });

Deno.test("D87 eval: Provläge answers on the chosen model, grading by the judge model", async () => {
  const llm = new Fake((r) => r.system.includes("You grade one answer")
    ? '{"correct":1,"a_level":1,"sufficient":0,"natural":1,"length_ok":1,"note":"missing why"}'
    : "Fotosyntes är när växter bygger socker av ljus.");
  const h = createEvalHandler({ authenticate: () => Promise.resolve({ id: "e1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm });
  const res = await h(post({ action: "answer", model: "sonnet", request: { fragment: "fotosyntes", mode: "tutor", language: "sv", context: {} } }));
  assertEquals(res.status, 200);
  assert((await res.text()).includes("Fotosyntes"));
  assertEquals(llm.calls[0].model, "claude-sonnet-5-5");
  assertEquals(llm.calls[0].noThinking, true);
  assertEquals((await h(post({ action: "answer", model: "sonnet", request: { fragment: "x", mode: "text", language: "sv", context: {} } }))).status, 400);
  const g = await (await h(post({ action: "grade", judge: "opus", case: { q: "fotosyntes", grade: "Åk 7" }, answer: "Fotosyntes är …" }))).json();
  assertEquals(g.scores.sufficient, 0);
  assertEquals(g.first_answer_suffices, 0);
  assertEquals(llm.calls.at(-1)!.model, "claude-opus-5-5");
  assertEquals((await h(post({ action: "grade", judge: "haiku", case: {}, answer: "" }))).status, 400);
});
