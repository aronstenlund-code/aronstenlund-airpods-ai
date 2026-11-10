// K29 (D115 T1): short fact questions in Provläge go to the cheaper default model; everything else stays on Sonnet.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { isShortFactQuestion } from "./length.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";

Deno.test("K29 classifier: short fact questions only; terms, explanations, several questions, numbers and rules stay", () => {
  for (const t of [
    "när började franska revolutionen",
    "vem skrev Röda rummet",
    "vad heter cellens kraftverk",
    "vilket år föll Berlinmuren",
    "var ligger Mesopotamien",
    "hur många kromosomer har en människa",
    "vad står DNA för",
    "vad är det kemiska tecknet för natrium",
    "och när föll muren",
    "Lumen, vem upptäckte penicillinet",
  ]) assert(isShortFactQuestion(t), t);
  for (const t of [
    "fotosyntes",
    "förklara varför antibiotika inte hjälper mot virus",
    "vilka var orsakerna till första världskriget",
    "vem skrev Ett dockhem och vad handlar den om",
    "hur många mol är tjugo gram natriumhydroxid",
    "när använder man some och any",
    "vem var Gregor Mendel",
    "vad heter det när atomer delar elektroner",
    "när man löser ekvationer ska man",
    "vad är en derivata",
    "hur fungerar ett vaccin",
    "när började franska revolutionen och varför",
  ]) assert(!isShortFactQuestion(t), t);
});

function setup(cfg = {}) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k29", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "claude-haiku-5-5",
      stream: (r) => {
        seen.push(r);
        return (async function* (): AsyncGenerator<LLMChunk> {
          yield { type: "text", text: "Den började 1789." };
        })();
      },
    },
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, ...cfg },
  });
  return { handler, seen };
}
const prov = (fragment: string) =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ fragment, mode: "tutor", persona: "tutor", persona_setup: "Prov i Historia. Årskurs: Åk 9.", language: "sv", context: {} }),
  });

Deno.test("K29 routing (off by default, TUTOR_FACT_ROUTE=1): a fact question runs on the default model, an explanation on tutorModel", async () => {
  const a = setup({ tutorFactRoute: true });
  await (await a.handler(prov("när började franska revolutionen"))).text();
  const answer = a.seen.filter((r) => !r.system.startsWith("You check ONE utterance"));
  assertEquals(answer.at(-1)?.model, undefined, "default model (Haiku)");
  const b = setup({ tutorFactRoute: true });
  await (await b.handler(prov("förklara varför franska revolutionen började"))).text();
  assertEquals(b.seen.at(-1)?.model, "claude-sonnet-5-5");
  const c = setup();
  await (await c.handler(prov("när började franska revolutionen"))).text();
  assertEquals(c.seen.at(-1)?.model, "claude-sonnet-5-5", "off by default (K29 measurement)");
});
