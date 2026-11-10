// Oscar QA, O22: corrections in a student's own words (K10/K13 detectCorrection) and app commands (detectAppCommand),
// with NEW phrasings (none in o10_offline.mjs, k10/k13 tests), offline and free with the deployed .ts files in Node 24.
//   node scripts/qa/o22_corrections_offline.mjs > reports/qa/data/<stamp>-o22-corrections.json
import { detectAppCommand } from "../../backend/supabase/functions/answer/appcommand.ts";
import { detectCorrection } from "../../backend/supabase/functions/memory/settings.ts";

const CORR = [ // [utterance, expected key:value]
  ["asså det där var alldeles för långt", "length:shorter"], ["kortare tack", "length:shorter"], ["orka lyssna på så långa svar", "length:shorter"],
  ["säg det på typ en mening", "length:shorter"], ["Lumen, du snackar för mycket", "length:shorter"], ["mindre prat", "length:shorter"],
  ["kan du förklara lite mer", "length:longer"], ["det där var för lite", "length:longer"], ["gå in mer på djupet", "length:longer"],
  ["jag hänger inte med", "simplicity:simpler"], ["förklara som om jag var tio", "simplicity:simpler"], ["med enklare ord tack", "simplicity:simpler"],
  ["fattar ingenting", "simplicity:simpler"], ["det var för avancerat", "simplicity:simpler"],
  ["kan du ge ett exempel nästa gång", "examples:more"], ["exempel hade varit nice", "examples:more"],
  ["nej det där är fel", "accuracy:careful"], ["det stämmer inte", "accuracy:careful"], ["du sa fel", "accuracy:careful"], ["det är ju inte sant", "accuracy:careful"],
];
const NOT_CORR = [
  "vilken är längst, Nilen eller Amazonas", "vad är ett bra exempel på en metafor", "hur kan jag förklara det för min lillebror",
  "jag fattar inte varför hon är sur", "är det fel att fuska", "det var för långt att cykla till skolan", "kan du säga det på engelska",
  "hur långt är det till månen", "mindre än eller lika med", "det stämmer inte att jorden är platt, eller hur",
  "jag hänger inte med i matten i skolan, vad ska jag göra", "säg ett exempel på ett däggdjur", "du har fel strumpor på dig",
  "för kort kjol enligt mamma", "det där var ett bra svar",
];
const CMD = [ // [current mode, utterance, expected action, expected mode or null]
  ["fragor", "Lumen, kör provläget", "switch_mode", "prov"], ["prov", "byt till frågor", "switch_mode", "fragor"],
  ["fragor", "nu ska jag plugga", "switch_mode", "prov"], ["prov", "vänta lite", "pause", null], ["prov", "Lumen, tyst en stund", "pause", null],
  ["fragor", "du kan sluta nu", "stop", null], ["prov", "lyssna igen", "resume", null], ["fragor", "jag ska på intervju, kan vi öva", "switch_mode", "intervju"],
  ["socialt", "stäng av", "stop", null], ["prov", "paus", "pause", null],
];
const NOT_CMD = [
  ["fragor", "vad betyder paus i musik"], ["prov", "vad hände när Sverige bytte till högertrafik"], ["fragor", "när stänger affären"],
  ["prov", "provet är på fredag"], ["fragor", "jag ska plugga till provet imorgon, vad är fotosyntes"], ["prov", "vänta, var det tre eller fyra"],
  ["fragor", "kan man sluta röka själv"], ["prov", "lyssna på den här frågan: vad är DNA"], ["socialt", "han sa stäng av musiken"], ["fragor", "hur länge varar en paus i fotboll"],
];
const corr = CORR.map(([t, want]) => { const r = detectCorrection(t); const got = r ? `${r.key}:${r.value}` : null; return { t, want, got, ok: got === want }; });
const notCorr = NOT_CORR.map((t) => { const r = detectCorrection(t); return { t, got: r ? `${r.key}:${r.value}` : null, ok: !r }; });
const cmd = CMD.map(([m, t, a, mode]) => { const r = detectAppCommand(t, m); return { m, t, want: `${a}${mode ? ":" + mode : ""}`, got: r ? `${r.action}${r.mode ? ":" + r.mode : ""}` : null, conf: r?.confidence ?? null, ok: !!r && r.action === a && (mode === null || r.mode === mode) }; });
const notCmd = NOT_CMD.map(([m, t]) => { const r = detectAppCommand(t, m); return { m, t, got: r ? `${r.action}${r.mode ? ":" + r.mode : ""}` : null, conf: r?.confidence ?? null, ok: !r }; });
const s = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ corrections: s(corr), not_corrections: s(notCorr), commands: s(cmd), not_commands: s(notCmd),
  fails: [...corr, ...notCorr, ...cmd, ...notCmd].filter((x) => !x.ok), corr, notCorr, cmd, notCmd }, null, 1));
