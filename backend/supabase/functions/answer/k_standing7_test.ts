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
