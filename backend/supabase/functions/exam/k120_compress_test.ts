// K120 (A163, D259): Komprimera in Säg i AirPods. POST /exam {"action":"compress","text":"<≤12 000>","lang"} ->
// {"text"}: shorter, the same content, about half, in the text's own language. provider_* as the other actions; the
// model call is limited and logged as the other actions. A pretend model only (no real calls, D258).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { LLMProviderError, type LLMChunk, type LLMProvider, type LLMRequest } from "../answer/llm/types.ts";
import { createExamHandler } from "./handler.ts";

function world(reply: string | Error) {
  const seen: LLMRequest[] = [];
  const usage: Record<string, unknown>[] = [];
  const provider: LLMProvider = {
    name: "fake", model: "claude-haiku-5-5",
    stream(r: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(r);
      return (async function* () {
        if (reply instanceof Error) throw reply;
        yield { type: "text", text: reply } as LLMChunk;
        yield { type: "usage", inputTokens: 300, outputTokens: 120 } as LLMChunk;
      })();
    },
  };
  const h = createExamHandler({ authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(), provider, recordUsage: (r) => void usage.push(r) });
  const call = async (b: unknown) => {
    const res = await h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" }, body: JSON.stringify(b) }));
    return { status: res.status, body: await res.json() };
  };
  return { call, seen, usage };
}
const SV = "Fotosyntesen är den process där växter tar upp ljus. Med hjälp av ljuset, vatten och koldioxid bildar växten glukos och syre. Glukosen används som energi och byggmaterial, och syret släpps ut i luften genom klyvöppningarna.";

Deno.test("K120: compress returns the shorter text, from a prompt that keeps the text's own language and content", async () => {
  const w = world("Växter gör glukos och syre av ljus, vatten och koldioxid. Glukosen ger energi; syret släpps ut.");
  const r = await w.call({ action: "compress", text: SV, lang: "en" });
  assertEquals(r.status, 200);
  assertEquals(r.body.text, "Växter gör glukos och syre av ljus, vatten och koldioxid. Glukosen ger energi; syret släpps ut.");
  assert(w.seen[0].system.includes("same language as the text"), w.seen[0].system);
  assert(w.seen[0].user.includes(SV));
  assertEquals(w.usage[0].endpoint, "exam-compress");
});

Deno.test("K120: a reply with a lead-in, quotes or markdown is cleaned to the text itself", async () => {
  const r = await world('Här är den kortare texten:\n\n"**Växter gör glukos av ljus.**"').call({ action: "compress", text: SV });
  assertEquals(r.body.text, "Växter gör glukos av ljus.");
});

Deno.test("K120: no text, or more than 12 000 characters, is 400; the model is not called", async () => {
  const w = world("x");
  assertEquals((await w.call({ action: "compress", text: "  " })).status, 400);
  assertEquals((await w.call({ action: "compress", text: "a".repeat(12_001) })).status, 400);
  assertEquals(w.seen.length, 0);
});

Deno.test("K120: the model's credits gone is 503 provider_quota (fallback), as the other actions; an empty reply is provider_error", async () => {
  const q = await world(new LLMProviderError("quota", "credits exhausted", 400)).call({ action: "compress", text: SV });
  assertEquals([q.status, q.body.error.code, q.body.error.fallback], [503, "provider_quota", true]);
  const e = await world("   ").call({ action: "compress", text: SV });
  assertEquals([e.status, e.body.error.code], [502, "provider_error"]);
});
