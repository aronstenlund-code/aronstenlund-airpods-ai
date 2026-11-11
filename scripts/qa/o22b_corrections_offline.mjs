// Oscar QA, O22b: NEW independent phrasings for corrections (memory/settings.ts detectCorrection) and app commands
// (answer/appcommand.ts detectAppCommand), written 2026-11-11 15:35 after Kevin put O22's cases into his tests
// (standing round 11). None of these are in o22_corrections_offline.mjs. Offline, free.
//   node --experimental-strip-types --no-warnings scripts/qa/o22b_corrections_offline.mjs > reports/qa/data/<stamp>-o22b.json
import { detectAppCommand } from "../../backend/supabase/functions/answer/appcommand.ts";
import { detectCorrection } from "../../backend/supabase/functions/memory/settings.ts";

const CORR = [ // [utterance, expected key:value]
  ["kan du korta ner svaren lite", "length:shorter"], ["för långa svar, seriöst", "length:shorter"], ["snabbare, bara det viktigaste", "length:shorter"],
  ["bara svaret, inget mer", "length:shorter"], ["jag orkar inte höra hela föreläsningen", "length:shorter"],
  ["mer detaljer tack", "length:longer"], ["utveckla gärna mer", "length:longer"], ["kan du ta det lite längre nästa gång", "length:longer"],
  ["säg det enklare", "simplicity:simpler"], ["för svåra ord", "simplicity:simpler"], ["kan du förklara det mer basic", "simplicity:simpler"],
  ["jag förstår inte vad du menar", "simplicity:simpler"], ["förenkla", "simplicity:simpler"],
  ["ge alltid ett exempel", "examples:more"], ["fler exempel tack", "examples:more"], ["typ ett exempel från verkligheten skulle hjälpa", "examples:more"],
  ["det där stämde inte alls", "accuracy:careful"], ["fel svar", "accuracy:careful"], ["nej nej, det var helt galet", "accuracy:careful"],
  ["är du säker? det låter fel", "accuracy:careful"],
];
const NOT_CORR = [
  "vad är det längsta ordet på svenska", "kan du ge exempel på ädelgaser", "varför är det fel att plagiera",
  "jag förstår inte vad tyska verb är för något, kan du förklara", "hur långt hoppar en känguru", "korta ner en text, hur gör man en sammanfattning",
  "är det enklare att lära sig spanska eller franska", "mer eller mindre än hälften", "fel på bussen idag, vi kom sent",
  "är du säker på att du vill veta", "det stämde inte med vad läraren sa om Gustav Vasa, vem hade rätt",
  "exempel på en dikt av Karin Boye", "vad betyder detaljer", "det var ett galet bra svar", "förenkla bråket tolv sextondelar",
];
const CMD = [ // [current mode, utterance, expected action, expected mode or null]
  ["fragor", "Lumen, provläge", "switch_mode", "prov"], ["prov", "tillbaka till vanliga läget", "switch_mode", "fragor"],
  ["fragor", "dags att plugga inför provet nu", "switch_mode", "prov"], ["prov", "pausa en sekund", "pause", null],
  ["fragor", "Lumen, håll tyst lite", "pause", null], ["prov", "sluta lyssna nu", "stop", null], ["fragor", "fortsätt lyssna", "resume", null],
  ["prov", "jag har anställningsintervju imorgon, öva med mig", "switch_mode", "intervju"], ["fragor", "stopp", "stop", null],
  ["socialt", "Lumen, stäng av dig", "stop", null],
];
const NOT_CMD = [
  ["fragor", "vad betyder paus på engelska"], ["prov", "när stängde Berlinmuren gränsen"], ["fragor", "vad är en intervjustudie"],
  ["prov", "provläget i matte, vad kommer på provet"], ["fragor", "fortsätt med samma ämne, vad är cellandning"], ["prov", "stopp i blodet, vad heter det"],
  ["fragor", "varför håller man tyst en minut vid sorg"], ["prov", "läraren sa att vi ska sluta lyssna på musik när vi pluggar"],
  ["socialt", "hon stängde av telefonen"], ["fragor", "hur länge ska man pausa mellan träningspassen"],
];
const corr = CORR.map(([t, want]) => { const r = detectCorrection(t); const got = r ? `${r.key}:${r.value}` : null; return { t, want, got, ok: got === want }; });
const notCorr = NOT_CORR.map((t) => { const r = detectCorrection(t); return { t, got: r ? `${r.key}:${r.value}` : null, ok: !r }; });
const cmd = CMD.map(([m, t, a, mode]) => { const r = detectAppCommand(t, m); return { m, t, want: `${a}${mode ? ":" + mode : ""}`, got: r ? `${r.action}${r.mode ? ":" + r.mode : ""}` : null, conf: r?.confidence ?? null, ok: !!r && r.action === a && (mode === null || r.mode === mode) }; });
const notCmd = NOT_CMD.map(([m, t]) => { const r = detectAppCommand(t, m); return { m, t, got: r ? `${r.action}${r.mode ? ":" + r.mode : ""}` : null, conf: r?.confidence ?? null, ok: !r }; });
const s = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ corrections: s(corr), not_corrections: s(notCorr), commands: s(cmd), not_commands: s(notCmd),
  fails: [...corr, ...notCorr, ...cmd, ...notCmd].filter((x) => !x.ok), corr, notCorr, cmd, notCmd }, null, 1));
