// Oscar QA, O21: independent offline test of Kevin's K15 practice-exam navigation (exam/practice.ts practiceNav),
// the deployed file in Node 24, free. 40 own utterances: how a student actually talks during a practice exam (filler
// words, "Lumen", Scribe writing digits, "trean", "nästa fråga tack", answers that look like commands, commands that
// look like answers). Task list like a maths exam: 1, 2, 3a, 3b, 4 … 12. Current task = index 4 ("5").
//   node scripts/qa/o21_k15_nav_offline.mjs > reports/qa/data/<stamp>-o21-k15-nav.json
import { practiceNav } from "../../backend/supabase/functions/exam/practice.ts";

const NOS = ["1", "2", "3a", "3b", "4", "5", "6", "7", "8", "9", "10", "11", "12"];
const CUR = 5; // "5"
const C = [ // [utterance, expected action, expected task no or null]
  ["nästa", "next", "6"], ["asså nästa fråga", "next", "6"], ["Lumen nästa", "next", "6"], ["kan vi ta nästa", "next", "6"],
  ["okej nästa tack", "next", "6"], ["nästa uppgift", "next", "6"], ["vi går vidare", "next", "6"],
  ["förra frågan", "prev", "4"], ["gå tillbaka en", "prev", "4"], ["kan vi gå tillbaka", "prev", "4"],
  ["hoppa över", "skip", "6"], ["jag vet inte, hoppa över", "skip", "6"], ["skippa den här", "skip", "6"], ["pass", "skip", "6"],
  ["upprepa", "repeat", "5"], ["kan du upprepa frågan", "repeat", "5"], ["vad sa du", "repeat", "5"], ["säg det igen", "repeat", "5"],
  ["fråga sju", "goto", "7"], ["fråga 7", "goto", "7"], ["ta fråga tolv", "goto", "12"], ["uppgift 3b", "goto", "3b"],
  ["uppgift tre b", "goto", "3b"], ["fråga trean", "goto", "3a"], ["kan vi ta fråga nio", "goto", "9"], ["gå till uppgift två", "goto", "2"],
  ["jag vill göra fråga elva", "goto", "11"], ["fråga 15", "answer", null],
  ["sluta", "stop", null], ["jag orkar inte mer, vi slutar", "stop", null], ["avsluta provet", "stop", null],
  ["hur många rätt har jag", "results", null], ["hur går det för mig", "results", null], ["vad har jag för poäng", "results", null],
  ["sju", "answer", null], ["x är lika med sju", "answer", null], ["nästa är väl fyrtio", "answer", null],
  ["fråga mig om Pythagoras", "answer", null], ["svaret är tillbaka till noll", "answer", null], ["det blir hundratjugo kronor", "answer", null],
];
const rows = C.map(([u, exp, no]) => {
  const r = practiceNav(u, CUR, NOS);
  const gotNo = r.index !== undefined ? NOS[r.index] : null;
  return { u, expect: exp, expect_no: no, got: r.action, got_no: gotNo, ok: r.action === exp && (no === null || gotNo === no) };
});
console.log(JSON.stringify({ n: rows.length, ok: rows.filter((r) => r.ok).length, fails: rows.filter((r) => !r.ok), rows }, null, 1));
