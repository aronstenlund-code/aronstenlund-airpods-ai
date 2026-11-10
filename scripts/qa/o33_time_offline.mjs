// Oscar QA, O33: clock times, time zones and dates computed in code (calc.ts computeFragment: clockTime, zoneClock,
// dateCalc). Fixed clock: tuesday 2026-11-10 11:00 Swedish time (10:00 UTC, CET, no summer time). Offline, free.
// Graded by hand from the printed text (expected facts in the third column); null = left to the model.
//   node scripts/qa/o33_time_offline.mjs > reports/qa/data/<stamp>-o33-time.json
import { computeFragment } from "../../backend/supabase/functions/answer/calc.ts";
const NOW = new Date("2026-11-10T10:00:00Z");
const C = [ // [utterance, a string the computed text must contain, or null = must not compute]
  ["vad är klockan", "11:00"], ["vad är klockan i Tokyo", "19:00"], ["vad är klockan i New York", "05:00"],
  ["vad är klockan i London", "10:00"], ["vad är klockan i Sydney", "21:00"], ["vad är klockan i Kalifornien", "02:00"],
  ["hur många timmar skiljer det mellan Sverige och Thailand", "6"], ["vad är klockan i Indien", "15:30"],
  ["hur många dagar är det till nyårsafton", "51"], ["vilken vecka är det", "46"], ["vilket datum är det på fredag", "13"],
  ["vilken dag är det imorgon", "onsdag"], ["vad är klockan om 3 timmar", "14:00"], ["vad är klockan om 90 minuter", "12:30"],
  ["hur lång tid är det kvar till klockan 15", "4"], ["hur många dagar är det till midsommarafton", "227"],
  ["hur gammal är man om man är född 2010", "15|16"], ["vilken veckodag var den 1 januari 2000", "lördag"],
  ["hur många dagar är det mellan 1 mars och 1 april", "31"], ["vilket år är det om 5 år", "2031"],
  ["hur många veckor är det kvar till sportlovet", null], ["när är det påsk nästa år", "5 april|april"],
];
const rows = C.map(([t, must]) => {
  let c = null, err = null;
  try { c = computeFragment(t, NOW); } catch (e) { err = String(e); }
  const text = c?.text ?? null;
  const ok = err ? false : must === null ? text === null : text === null ? null : must.split("|").some((m) => text.includes(m));
  return { t, must, text, err, ok };
});
console.log(JSON.stringify({ n: rows.length, computed: rows.filter((r) => r.text).length, right: rows.filter((r) => r.ok === true).length,
  wrong: rows.filter((r) => r.ok === false).length, left_to_model: rows.filter((r) => r.ok === null).map((r) => r.t), rows }, null, 1));
