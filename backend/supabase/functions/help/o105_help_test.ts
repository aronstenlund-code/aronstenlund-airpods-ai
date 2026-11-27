// O105-1 (Oscar + Deangelo): the help's knowledge covers what the app does today (Säg i AirPods, Komprimera, "Hur ska det
// låta?", the voice list, credits and the launch discount, the activation words, Spela in själv – helt gratis, the
// phone's model and voice when the server cannot, the locked screen). O105-2: the help answers in the app's language.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { HJALP } from "../_shared/hjalp.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHelpHandler, OUT_OF_SCOPE, OUT_OF_SCOPE_EN, PRESSES_EN, SYSTEM_PROMPT_HELP, UNKNOWN_EN } from "./handler.ts";

Deno.test("O105-1: the help text covers today's app and no longer says three voices, 15 questions or nothing to buy", () => {
  for (const must of ["Säg i AirPods", "Komprimera", "Hur ska det låta?", "Skriv i takt", "Välj röst", "Provlyssna", "1 kredit", "1 500", "Fyll på", "Veckokort", "lanseringsveckan",
    "Fråga du inte är beredd på?", "Spela in själv", "Helt gratis", "Telefonens röst läser just nu", "Telefonens modell", "låst"]) {
    assert(HJALP.includes(must), must);
  }
  for (const gone of ["tre röster", "15 frågor", "det går inte att köpa", "en egen röst till svaren"]) assert(!HJALP.includes(gone), gone);
  assert(!/coming later, no prices yet/.test(SYSTEM_PROMPT_HELP), "prices: what <hjalp> says now");
});

function world(reply: string) {
  const seen: { user: string }[] = [];
  const h = createHelpHandler({
    authenticate: () => Promise.resolve({ id: "u-o105", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: (r) => (seen.push(r), (async function* () { yield { type: "text" as const, text: reply }; })()) },
    useQuota: () => Promise.resolve({ ok: true, used: 0, lim: 1500 }),
  });
  const ask = (question: string, lang?: string) =>
    h(new Request("http://x/help", { method: "POST", headers: { "content-type": "application/json", ...(lang ? { "x-earmind-lang": lang } : {}) }, body: JSON.stringify({ question }) })).then((r) => r.json());
  return { ask, seen };
}

Deno.test("O105-2: an English app gets the help in English (the model is told, and the fixed texts are English)", async () => {
  const w = world('{"in_scope": true, "answer": "Tap Share at the top right of the quiz."}');
  const j = await w.ask("how do I share a quiz with my class", "en");
  assertEquals(j.answer, "Tap Share at the top right of the quiz.");
  assert(w.seen[0].user.includes("<language>en</language>"), w.seen[0].user);
  const out = await world('{"in_scope": false, "answer": ""}').ask("what is the capital of France", "en");
  assertEquals(out.answer, OUT_OF_SCOPE_EN);
  const broken = await world("not json").ask("how does it work", "en");
  assertEquals(broken.answer, UNKNOWN_EN);
  const press = await world('{"in_scope": true, "answer": "x"}').ask("how do the presses on my AirPods work", "en");
  assertEquals(press.answer, PRESSES_EN);
});

Deno.test("O105-2: Swedish (asked so, or no language and a Swedish question) is as before", async () => {
  const w = world('{"in_scope": false, "answer": ""}');
  assertEquals((await w.ask("vad är huvudstaden i frankrike", "sv")).answer, OUT_OF_SCOPE);
  assert(w.seen[0].user.includes("<language>sv</language>"));
  const n = world('{"in_scope": false, "answer": ""}');
  assertEquals((await n.ask("vad är huvudstaden i frankrike")).answer, OUT_OF_SCOPE, "no language, Swedish words: Swedish");
});

Deno.test("O105 omtest (Oscar): Dela and Publicera prov have their English names in brackets, as the other buttons", () => {
  for (const pair of ["**Dela** (Share)", "**Publicera prov** (Publish quiz)", "**Nytt prov** (New quiz)", "**Skapa frågor** (Create questions)", "**Starta prov** (Start quiz)", "**Prov från din skola** (Quizzes from your school)"]) {
    assert(HJALP.includes(pair), pair);
  }
});
