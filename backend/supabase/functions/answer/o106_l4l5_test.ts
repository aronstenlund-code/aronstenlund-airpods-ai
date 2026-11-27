// O106 L4/L5 (Oscar): a rhetorical "varför … mig" got the study hint; done.breakdown.answer_type gave only the
// server's hint; the prompt's "och ...?" example contradicted the refines definition, "ONLY the translation" clashed
// with "vad betyder X", and a lone "Ottawa?" was in no rule.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { classifyAnswerType } from "./length.ts";
import { SYSTEM_PROMPT } from "./prompt.ts";

Deno.test("O106 L4: a rhetorical 'why me' is not a study question; a real why still is", () => {
  for (const f of ["varför händer alltid sånt här mig", "varför ska det alltid vara jag", "varför just jag", "why does this always happen to me", "varför är jag alltid så otur"]) {
    assertEquals(classifyAnswerType(f, "adaptive", null), "fact", f);
  }
  for (const f of ["varför har jordens medeltemperatur stigit", "varför blir jag trött efter maten", "varför är himlen blå"]) {
    assertEquals(classifyAnswerType(f, "adaptive", null), "study", f);
  }
});

Deno.test("O106 L4: done.breakdown says the model's answer type next to the server's hint", async () => {
  const { createHandler, DEFAULT_CONFIG } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-l4", isAnonymous: false }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: () => (async function* () { yield { type: "text" as const, text: '{"is_question":true,"answer_type":"fact","reconstructed_question":"x","confidence":0.9}\nEtt svar.' }; })() },
    recordUsage: () => {}, config: DEFAULT_CONFIG,
  });
  const done = async (mode: string) => {
    const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.10" }, body: JSON.stringify({ fragment: "förklara fotosyntesen", mode, language: "sv", context: {} }) }));
    return JSON.parse((await res.text()).split("event: done\ndata: ")[1].split("\n")[0]).breakdown;
  };
  const auto = await done("auto");
  assertEquals([auto.answer_type, auto.answer_type_model], ["study", "fact"]);
  const ptt = await done("push_to_talk"); // direct mode: the model writes no meta, so it says no type
  assertEquals([ptt.answer_type, ptt.answer_type_model], ["study", null]);
});

Deno.test("O106 L5: the prompt's examples follow its own definitions", () => {
  assert(!SYSTEM_PROMPT.includes('"och ...?"'), "a new concept after och is refines, not continues");
  assert(/"och sen\?"/.test(SYSTEM_PROMPT) && /"och cellandning då" after photosynthesis: a new concept, so refines/.test(SYSTEM_PROMPT));
  assert(/"vad betyder X"[^.]*is not a translation request/.test(SYSTEM_PROMPT));
  assert(/A bare name or term with a question mark \("Ottawa\?"\)/.test(SYSTEM_PROMPT));
});
