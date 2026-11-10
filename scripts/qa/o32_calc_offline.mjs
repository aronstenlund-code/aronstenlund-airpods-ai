// Oscar QA, O32: numbers computed in code (D46, answer/calc.ts computeFragment + spokenComputed, datecalc, timezone):
// when code computes, the result is spoken without the model, so a wrong value is said with full confidence.
// How students actually say maths and conversions; fixed clock 2026-11-10 11:00 Swedish time. Offline, free.
// Graded: value right (when code computes) or code leaves it to the model (null = "model"); a wrong value = fail.
//   node scripts/qa/o32_calc_offline.mjs > reports/qa/data/<stamp>-o32-calc.json
import { computeFragment, spokenComputed } from "../../backend/supabase/functions/answer/calc.ts";

const NOW = new Date("2026-11-10T10:00:00Z"); // 11:00 in Stockholm, tuesday
const C = [ // [utterance, expected value or null (= must not compute)]
  ["vad är 15 procent av 240", 36], ["hur mycket är tjugo procent av femhundra", 100], ["vad blir 499 med 20 procent rabatt", 399.2],
  ["vad är 7 gånger 8", 56], ["vad är sjutton gånger tjugofyra", 408], ["hur mycket är 270 gånger 270", 72900],
  ["vad är 100 delat med 3", 33.333], ["vad är roten ur 144", 12], ["vad är 2 upphöjt till 10", 1024],
  ["vad är minus fem plus tre", -2], ["vad är hälften av 37", 18.5], ["vad är 3/4 av 60", 45],
  ["hur många minuter är 2,5 timmar", 150], ["hur många sekunder är ett dygn", 86400],
  ["vad är 100 fahrenheit i celsius", 37.778], ["hur många kilometer är 5 miles", 8.047], ["vad är 1 kilo i pund", 2.205],
  ["hur många dagar är det kvar till julafton", 44], ["vilken veckodag är den 24 december 2026", null],
  ["vad är 12 + 8 * 2", 28], ["vad är (12 + 8) * 2", 40], ["vad är 10 minus 2 minus 3", 5],
  ["vad är 0,1 plus 0,2", 0.3], ["vad är en tredjedel av nittio", 30],
  ["moms 25 procent på 800 kronor", 200], ["vad är 1,5 miljoner gånger 2", 3000000],
  ["jag fick 18 av 24 rätt, hur många procent är det", 75], ["vad är tjugofem procent av hundratjugo", 30],
  ["vad är 5 procent av 1 000 000", 50000], ["vad är 9 minus 12", -3],
];
const rows = C.map(([t, want]) => {
  let c = null, err = null;
  try { c = computeFragment(t, NOW); } catch (e) { err = String(e); }
  const got = c ? c.value : null;
  const spoken = c ? spokenComputed(c) : null;
  const close = (a, b) => Math.abs(a - b) <= Math.max(0.01, Math.abs(b) * 0.001);
  const ok = err ? false : got === null ? true : want !== null && close(got, want); // null = left to the model (not wrong)
  return { t, want, got, text: c?.text ?? null, spoken, err, ok, computed: got !== null };
});
console.log(JSON.stringify({ n: rows.length, computed: rows.filter((r) => r.computed).length, wrong: rows.filter((r) => !r.ok).length,
  fails: rows.filter((r) => !r.ok), left_to_model: rows.filter((r) => !r.computed).map((r) => r.t), rows }, null, 1));
