import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";
import { isQuizRequest } from "./prompt.ts";
import { parseCards } from "../study-cards/handler.ts";

class Spy implements LLMProvider {
  readonly name = "spy";
  readonly model = "spy-1";
  calls: LLMRequest[] = [];
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: "Var sker fotosyntesen?" };
    yield { type: "usage", inputTokens: 10, outputTokens: 5 };
  }
}
const run = async (body: Record<string, unknown>) => {
  const spy = new Spy();
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: spy,
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  const res = await h(new Request("http://x/answer", { method: "POST", body: JSON.stringify(body) }));
  const text = await res.text();
  return { spy, text };
};
const BIO = "Prov i Biologi fredag 13 november 2026 (om 5 dagar). Årskurs: Åk 9. På provet: fotosyntes, cellandning. Kontrollfrågor: Inga kontrollfrågor.";

Deno.test("D86 'förhör mig' asks for one check question, kept even with 'inga kontrollfrågor'", async () => {
  assert(isQuizRequest("Förhör mig: ställ en kontrollfråga på det vi just pratat om"));
  assert(isQuizRequest("Lumen, förhör mig"));
  assert(!isQuizRequest("vad är förhör"));
  const { spy, text } = await run({ fragment: "förhör mig", mode: "tutor", language: "sv", persona: "tutor", persona_setup: BIO, context: {} });
  assertStringIncludes(spy.calls[0].user, "reply with ONE check question");
  assertStringIncludes(text, "Var sker fotosyntesen?", "the question is not trimmed away");
});

Deno.test("D86 the reply to the last check question is graded first", async () => {
  const { spy } = await run({
    fragment: "i mitokondrierna", mode: "tutor", language: "sv", persona: "tutor", persona_setup: BIO,
    context: { recent_qa: [{ q: "förhör mig", a: "Var sker fotosyntesen?" }] },
  });
  assertStringIncludes(spy.calls[0].user, "Start with the verdict");
  const plain = await run({ fragment: "vad är osmos", mode: "tutor", language: "sv", context: { recent_qa: [{ q: "a", a: "Bra." }] } });
  assert(!plain.spy.calls[0].user.includes("Start with the verdict"));
});

Deno.test("D86 several exams: the profile is this exam, other exams in memories are kept apart", async () => {
  const { spy } = await run({
    fragment: "vad ska jag plugga på", mode: "tutor", language: "sv", persona: "tutor", persona_setup: BIO,
    memories: ["Provprofil: prov i Kemi tisdag 17 november 2026"], context: {},
  });
  const u = spy.calls[0].user;
  assertStringIncludes(u, `<profile>${BIO}</profile>`);
  assertStringIncludes(u, "never mix their subject, date or content into this one");
});

Deno.test("D86 'Öva mer på': 1-3 practice areas from the study-cards call", () => {
  const r = parseCards('{"cards":[{"q":"a?","a":"b"}],"test":[],"practice":["cellandningens steg","Cellandningens steg","klyvöppningar","ljusreaktionen","extra"]}', 8);
  assertEquals(r.practice, ["cellandningens steg", "klyvöppningar", "ljusreaktionen"]);
});
