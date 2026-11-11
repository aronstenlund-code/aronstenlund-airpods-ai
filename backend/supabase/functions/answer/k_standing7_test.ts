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
