import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMRequest } from "../answer/llm/types.ts";
import { createMyAnswersHandler, onlySpelling } from "./handler.ts";

function setup(reply: string) {
  const seen: LLMRequest[] = [];
  const usage: { endpoint?: unknown; model?: unknown }[] = [];
  const h = createMyAnswersHandler({
    authenticate: () => Promise.resolve({ id: "u-k37", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "claude-haiku-5-5",
      stream: (r) => {
        seen.push(r);
        return (async function* () {
          yield { type: "text" as const, text: reply };
          yield { type: "usage" as const, inputTokens: 100, outputTokens: 50 };
        })();
      },
    },
    recordUsage: (r) => {
      usage.push(r);
    },
  });
  return { h, seen, usage };
}
const post = (b: unknown) => new Request("http://x/my-answers", { method: "POST", body: JSON.stringify(b) });

Deno.test("K37 proofread guard: spelling yes, new content no", () => {
  assert(onlySpelling("Vad är fotosyntes", "Vad är fotosyntes?"));
  assert(onlySpelling("fotosyntes är när växter gör glukos av solljus vatten och kodioxid", "Fotosyntes är när växter gör glukos av solljus, vatten och koldioxid."));
  assert(onlySpelling("mitokondrierna är cellens kraft verk", "Mitokondrierna är cellens kraftverk."), "a joined compound");
  assert(!onlySpelling("Kriget började 1914.", "Kriget började 1915."), "a number is content");
  assert(!onlySpelling("Det sker i kloroplasterna.", "Det sker i mitokondrierna."), "another word");
  assert(!onlySpelling("Det sker i kloroplasterna.", "Det sker i kloroplasterna, som finns i bladens celler."), "added content");
  assert(!onlySpelling("Det sker i kloroplasterna.", ""));
});

Deno.test("K37 suggest: Sonnet writes the answer; the question stays the student's own unless only spelling changed", async () => {
  const { h, seen, usage } = setup('{"q": "Vad är fotosyntes?", "answer": "Fotosyntes är när växter bildar glukos och syre av koldioxid och vatten med hjälp av solljus."}');
  const r = await (await h(post({ action: "suggest", q: "vad är fotosyntes", subject: "Biologi", terms: ["kloroplast", "glukos"] }))).json();
  assertEquals(r.q, "Vad är fotosyntes?");
  assert(r.answer.startsWith("Fotosyntes är"));
  assertEquals(seen[0].model, "claude-sonnet-5-5");
  assert(seen[0].user.includes("Ämnesord: kloroplast, glukos"));
  assertEquals(usage[0].endpoint, "my-answers-suggest");
  const r2 = await (await setup('{"q": "Förklara fotosyntesens betydelse för ekosystemet", "answer": "x"}').h(post({ action: "suggest", q: "vad är fotosyntes" }))).json();
  assertEquals(r2.q, "vad är fotosyntes", "a rephrased question is not used");
});

Deno.test("K37 proofread: a fix that changes content is dropped field by field", async () => {
  const { h, seen } = setup('{"q": "Vad är cellandning?", "a": "Cellandning sker i mitokondrierna och ger energi, och det är viktigt för alla djur."}');
  const r = await (await h(post({ action: "proofread", q: "vad är celandning", a: "Cellandning sker i mitokondrierna och ger energi." }))).json();
  assertEquals(r.q, "Vad är cellandning?");
  assertEquals(r.a, "Cellandning sker i mitokondrierna och ger energi.");
  assertEquals(r.changed, { q: true, a: false });
  assertEquals(seen[0].model, undefined, "the default (small) model");
});

Deno.test("K37 compress: transcript in, one answer out; the student's own question kept; bad requests 400", async () => {
  const { h, seen } = setup('{"q": "Vad är cellandning?", "answer": "Cellandning är när cellerna bryter ner glukos med syre och får energi."}');
  const r = await (await h(post({ action: "compress", transcript: "okej så cellandning det är alltså när cellerna bryter ner glukos med hjälp av syre och då får de energi" }))).json();
  assertEquals(r.q, "Vad är cellandning?");
  assert(r.answer.includes("glukos"));
  assert(seen[0].user.includes("<transcript>"));
  for (const bad of [{}, { action: "nope" }, { action: "suggest" }, { action: "proofread", q: "x" }, { action: "compress", transcript: "kort" }]) {
    assertEquals((await setup("{}").h(post(bad))).status, 400, JSON.stringify(bad));
  }
});

Deno.test("K37 O39: a suggested answer is speakable (no arrows, plus signs, parentheses)", async () => {
  const { speakable } = await import("./handler.ts");
  assertEquals(speakable("Koldioxid + vatten → glukos (druvsocker) och syre."), "Koldioxid och vatten blir glukos, druvsocker, och syre.");
  assertEquals(speakable("Det sker i kloroplasterna (i bladen)."), "Det sker i kloroplasterna, i bladen.");
  assertEquals(speakable("3 + 4 = 7"), "3 + 4 = 7", "a sum between numbers is left");
});
