import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { guardPhoneNumbers, PHONE_PLACEHOLDER } from "./speechsym.ts";
import { needsText } from "./web.ts";

Deno.test("K13 (O10 #6) large numbers are never taken for phone numbers; real ones still are", () => {
  for (const t of [
    "På cirka hundra dagar dödades omkring 800 000 människor.",
    "Efter larmet evakuerades 12 000 personer.",
    "Under jourtiden kom 25 000 besökare.",
    "Det såldes 1 000 000 telefoner.",
  ]) assertEquals(guardPhoneNumbers(t), t, t);
  assert(guardPhoneNumbers("Ring kundtjänsten på 0771-23 45 67.").includes(PHONE_PLACEHOLDER));
  assert(guardPhoneNumbers("Numret är 08 123 456 78.").includes(PHONE_PLACEHOLDER));
});

Deno.test("K13 (O10 #8) 'första raden' goes to the text path", () => {
  for (const f of ["vad är första raden i Du gamla du fria", "citera första raden", "första raden i Imagine"]) assert(needsText(f), f);
});

import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";

function two(text: string) {
  const seen: LLMRequest[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-two", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "s",
      stream: (r) => {
        seen.push(r);
        return (async function* (): AsyncGenerator<LLMChunk> {
          for (let k = 0; k < text.length; k += 4) yield { type: "text", text: text.slice(k, k + 4) };
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { h, seen };
}
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({
    event: /^event: (.*)$/m.exec(f)![1],
    data: JSON.parse(/^data: (.*)$/m.exec(f)![1]),
  }));
}
const tutorBody = (o: Record<string, unknown> = {}) => ({
  fragment: "vad är fotosyntes",
  mode: "tutor",
  language: "sv",
  persona: "tutor",
  persona_setup: "Prov i Biologi på fredag (om 1 dag). Årskurs: Åk 9. Ämne: Biologi.",
  context: {},
  ...o,
});
const post = (b: unknown) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(b) });

Deno.test("K13.1 two levels: the short answer is spoken, the developed one comes as more_delta and in done.more", async () => {
  const { h, seen } = two(
    "Fotosyntes är när växter gör socker av ljus. [[MER]]\nDet sker i kloroplasterna, där klorofyll fångar ljuset. Till exempel växer en solros mot ljuset.",
  );
  const ev = await events(await h(post(tutorBody({ two_level: true }))));
  const spoken = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  const more = ev.filter((e) => e.event === "more_delta").map((e) => e.data.text).join("");
  assert(spoken.includes("Fotosyntes är när växter"), spoken);
  assert(!spoken.includes("kloroplasterna") && !spoken.includes("MER"), spoken);
  assert(more.includes("kloroplasterna") && !more.includes("MER"), more);
  const done = ev.find((e) => e.event === "done")!.data;
  assert(String(done.more).includes("solros"));
  assert(seen[0].system.includes("TWO LEVELS (K13"));
  assert(seen[0].user.includes("<situation"), "the situation travels with the request");
  assert(seen[0].user.includes("provet om 1 dag"));
});

Deno.test("K13.1 without two_level, or with the learned long default, there is one answer as before", async () => {
  const a = two("Fotosyntes är när växter gör socker av ljus.");
  await events(await a.h(post(tutorBody())));
  assert(!a.seen[0].system.includes("TWO LEVELS"));
  const b = two("Fotosyntes är när växter gör socker av ljus.");
  await events(await b.h(post(tutorBody({
    two_level: true,
    preferences: [{ key: "length", value: "longer", scope: { mode: "prov", subject: "Biologi" } }],
    pref_context: { subject: "Biologi" },
  }))));
  assert(!b.seen[0].system.includes("TWO LEVELS"), "2 of 3 'ja' made the long answer the default");
});

Deno.test("K13.3 others talking reaches the model", async () => {
  const { h, seen } = two("Kort.");
  await events(await h(post(tutorBody({ situation: { others_talking: true } }))));
  assert(seen[0].user.includes("andra pratar"));
});
