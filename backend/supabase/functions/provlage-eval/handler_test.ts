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

Deno.test("K2 judge v2: length and the closing question in code, covers apart from sufficient, empty counted", async () => {
  const { lengthCheck, closingCheck, wantsChecks } = await import("./handler.ts");
  const mid = "Förklaringar: mellanlånga förklaringar.";
  const long = Array.from({ length: 7 }, (_, i) => `Mening nummer ${i + 1} är kort.`).join(" ");
  assertEquals(lengthCheck(long, mid).ok, 0, "seven sentences");
  assertEquals(lengthCheck("Ett två tre. Fyra fem sex.", mid).ok, 1);
  assertEquals(lengthCheck(("ord ".repeat(120)).trim() + ".", mid).ok, 0, "120 words");
  assertEquals(lengthCheck(("ord ".repeat(120)).trim() + ".", "Förklaringar: utförliga förklaringar.").ok, 1);
  assertEquals(lengthCheck("A. B. C. D.", "Förklaringar: korta förklaringar.").ok, 0);
  assertEquals(lengthCheck("", mid).ok, 0);
  const q = "Kontrollfrågor: Korta frågor.";
  assertEquals(lengthCheck("A. B. C. D. E. F. Vad är G?", `${mid} ${q}`).sentences, 6, "an asked-for check question is not counted");
  assert(wantsChecks(q) && !wantsChecks("Kontrollfrågor: Inga kontrollfrågor.") && !wantsChecks(mid));
  assertEquals(closingCheck("Bra. Vad är mitos?", mid), 0);
  assertEquals(closingCheck("Bra. Vad är mitos?", q), 1);
  assertEquals(closingCheck("Bra.", mid), 1);

  const llm = new Fake(() => '{"correct":1,"a_level":1,"sufficient":1,"covers":0,"natural":1,"note":""}');
  const h = createEvalHandler({ authenticate: () => Promise.resolve({ id: "e2", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider: llm });
  const g = await (await h(post({ action: "grade", judge: "opus", case: { q: "mitos", profile: mid }, answer: "Mitos är celldelning. Vad är meios?" }))).json();
  assertEquals(g.rubric, 2);
  assertEquals(g.first_answer_suffices, 1);
  assertEquals(g.strict, 0, "covers 0");
  assertEquals(g.scores.closing_ok, 0);
  assertEquals(g.scores.length_ok, 1);
  const e = await (await h(post({ action: "grade", judge: "opus", case: { q: "pyt a goras", profile: mid }, answer: "" }))).json();
  assertEquals(e.empty, 1);
  assertEquals(e.first_answer_suffices, 0, "silence is never enough, whatever the judge says");
});

Deno.test("K7 judge: level talk and Danish/Norwegian words are checked in code", async () => {
  const { levelCheck, languageCheck } = await import("./handler.ts");
  assertEquals(levelCheck("Det här är Åk åtta, så jag förklarar idén. Derivatan är lutningen."), 0);
  assertEquals(levelCheck("Derivatan är hur snabbt något ändras. Havsnivån stiger."), 1);
  assertEquals(languageCheck("Ja, det har jeg."), 0);
  assertEquals(languageCheck("Ja, det har jag. På engelska säger man \"I have\"."), 1);
  assertEquals(languageCheck("På norska heter det \"ikke\"."), 1);
});
