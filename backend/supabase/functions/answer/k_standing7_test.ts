// Stående omgång 7 (live eval 2026-11-11): zone clocks and temperatures are spoken by code; "sextiotta" is fixed.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { computeFragment, spokenComputed } from "./calc.ts";
import { zoneClock } from "./timezone.ts";
import { NumberStream } from "./speech.ts";
import { beforeNumbers } from "./speechsym.ts";

const say = (t: string) => {
  const n = new NumberStream();
  return n.push(t) + n.finish();
};
const now = new Date("2026-11-11T10:00:00Z");

Deno.test("Standing 7: Delhi 18:30 and 68 °F are said by code, right", () => {
  assertEquals(say(spokenComputed(zoneClock("vad är klockan i delhi när den är 14 här", now)!)!),
    "Klockan fjorton i Sverige är klockan arton och trettio i Delhi. Delhi är fyra och en halv timme före Sverige.");
  assertEquals(say(spokenComputed(computeFragment("20 grader celsius i fahrenheit", now)!)!), "tjugo grader Celsius är sextioåtta grader Fahrenheit.");
  assertEquals(spokenComputed(computeFragment("100 fahrenheit i celsius", now)!), "100 grader Fahrenheit är ungefär 37,8 grader Celsius.");
  assertEquals(spokenComputed(zoneClock("vad är tidsskillnaden mellan sverige och tokyo", now)!), null, "a difference only keeps the model");
  assertEquals(beforeNumbers("sextiotta grader och åttiotta"), "sextioåtta grader och åttioåtta");
});

Deno.test("Standing 7: 'just nu' reads naturally", () => {
  assertEquals(say(spokenComputed(zoneClock("vad är klockan i tokyo", now)!)!),
    "Just nu är klockan elva i Sverige och nitton i Tokyo. Tokyo är åtta timmar före Sverige.");
});

Deno.test("Standing 7: '(M)' after a name is the party; 'Also,' is dropped; other parentheses stay", () => {
  assertEquals(beforeNumbers("Sveriges statsminister är Ulf Kristersson (M)."), "Sveriges statsminister är Ulf Kristersson, Moderaterna.");
  assertEquals(beforeNumbers("Publicerad idag. Also, SMHI har utfärdat gula varningar."), "Publicerad idag. SMHI har utfärdat gula varningar.");
  assertEquals(beforeNumbers("Storleken (M) på tröjan"), "Storleken (M) på tröjan");
});

Deno.test("Standing 10 (live eval klocka-01): a yes/no follow-up that quotes the last answer keeps its words", async () => {
  const { stripEcho } = await import("./echo.ts");
  const a = "Klockan tjugo och tjugo är tjugo över åtta på kvällen.";
  assertEquals(stripEcho("är det samma som tjugo över åtta på kvällen", a).quoted, true);
  assertEquals(stripEcho("tjugo över åtta på kvällen", a).rest, "", "a bare echo is still removed");
});

Deno.test("Toby T14: a cut-off question is silence (the app waits for the rest); a complete one is not", async () => {
  const { isCutOff } = await import("./handler.ts");
  for (const f of ["Hur många invånare har", "Vad är skillnaden mellan", "vad är skillnaden mellan katter och", "hur många ben har en"]) assertEquals(isCutOff(f), true, f);
  for (const f of ["Vad är skillnaden mellan ett virus", "Och hur många bor där?", "hur många bor där", "vad är det", "Vilka är de största?",
    "vem skrev Röda rummet", "Lumen, sätt en timer på", "är det sant", "vad ska jag plugga på", "vad handlar boken om"]) assertEquals(isCutOff(f), false, f);
});

Deno.test("Toby T14: the cut-off rule is for Auto only; Provläge still answers a half question (D87 'half')", async () => {
  const { createHandler, DEFAULT_CONFIG } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const calls: unknown[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-t14", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "m", stream: (r) => { calls.push(r); return (async function* () { yield { type: "text" as const, text: "Riksdagen stiftar lagar." }; })(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  const req = (mode: string) => new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment: "vad är skillnaden mellan riksdag och", mode, language: "sv", context: {} }) });
  const auto = await (await h(req("auto"))).text();
  assertEquals(calls.length, 0, "Auto: silence without a model call");
  assertEquals(/"cut_off":true/.test(auto), true);
  await (await h(req("tutor"))).text();
  assertEquals(calls.length, 1, "Provläge: answered");
});
