// Oscar QA, O39: K37 "Mina svar" code matching offline (backend/supabase/functions/answer/savedanswers.ts rankSaved),
// on my own cases in scripts/qa/o39_k37_cases.json (written before reading Kevin's code). For each case the exam's
// saved list is what the app would send; "other_user" sends the other user's list (the server cannot mix users: the
// app sends only its own). Shows per case: sure in code (no model check, the dangerous path), maybe (goes to the Haiku
// check, decided live), or none. 0 USD.
//   node --experimental-strip-types scripts/qa/o39_k37_offline.mjs > reports/qa/data/<stamp>-o39-offline.json
import { readFileSync } from "node:fs";
import { rankSaved } from "../../backend/supabase/functions/answer/savedanswers.ts";

const C = JSON.parse(readFileSync(new URL("./o39_k37_cases.json", import.meta.url), "utf8"));
const rows = [];
for (const c of C.cases) {
  const list = c.group === "other_user" ? C.other_user_saved[c.exam] : C.saved[c.exam];
  const r = rankSaved(c.ask, list, true); // Provläge = mode tutor -> requireQuestion
  const top = r[0];
  const path = !top ? "none" : top.sure ? "sure" : "maybe";
  const sureId = top?.sure ? top.item.id : null;
  // code verdict: a sure hit must be the expected one; for expect=null a sure hit is a FALSE HIT in code
  const codeFalse = sureId !== null && sureId !== c.expect;
  const codeMissed = c.expect !== null && !r.some((x) => x.item.id === c.expect); // never reaches the check
  rows.push({ ...c, path, top: top ? { id: top.item.id, score: +top.score.toFixed(3) } : null,
    cands: r.slice(0, 3).map((x) => x.item.id), codeFalse, codeMissed });
}
const g = {};
for (const r of rows) {
  const k = (g[r.group] ??= { n: 0, sure: 0, maybe: 0, none: 0, codeFalse: 0, codeMissed: 0 });
  k.n++; k[r.path]++; if (r.codeFalse) k.codeFalse++; if (r.codeMissed) k.codeMissed++;
}
console.log(JSON.stringify({ groups: g, codeFalse: rows.filter((r) => r.codeFalse).map((r) => [r.id, r.ask, r.top]),
  codeMissed: rows.filter((r) => r.codeMissed).map((r) => [r.id, r.ask]), rows }, null, 1));
