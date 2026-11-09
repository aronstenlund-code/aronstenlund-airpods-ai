// Oscar QA, O10 offline: independent test of Kevin's K10 matchers with my own phrasings (none of them in
// scripts/k10-appcommand-cases.json, k10_test.ts or scripts/k10-learning.py).
//   (a) app commands in own words, in all modes (20) + 15 ordinary sentences that must not become commands
//   (b1) corrections in own words (20) + 5 ordinary sentences that must not become corrections
//   (b2) scope and widening: sequences of corrections through applyCorrection, checked with applicable()
// Node 24 runs the .ts files directly (type stripping), so this is the deployed code, offline and free.
//   node scripts/qa/o10_offline.mjs > reports/qa/data/<stamp>-o10-offline.json
import { APP_COMMAND_SURE, detectAppCommand } from "../../backend/supabase/functions/answer/appcommand.ts";
import { applicable, applyCorrection, describe, detectCorrection } from "../../backend/supabase/functions/memory/settings.ts";

// [current mode, utterance, expected action, expected mode]
const CMD = [
  ["fragor", "kan vi byta till provläget nu", "switch_mode", "prov"],
  ["prov", "jag vill köra frågeläget igen", "switch_mode", "fragor"],
  ["prov", "okej Lumen, gå över till intervjuläget", "switch_mode", "intervju"],
  ["fragor", "sätt på provläget", "switch_mode", "prov"],
  ["prov", "pausa en stund", "pause", null],
  ["intervju", "Lumen, pausa", "pause", null],
  ["socialt", "Lumen, vi är klara nu", "stop", null],
  ["fragor", "kan du sluta lyssna", "pause", null],
  ["prov", "fortsätt lyssna", "resume", null],
  ["fragor", "kan vi plugga till provet istället", "switch_mode", "prov"],
  ["fragor", "kan vi öva på min jobbintervju", "switch_mode", "intervju"],
  ["rizz", "Lumen, tillbaka till provläget", "switch_mode", "prov"],
  ["socialt", "Lumen, byt till vanliga frågor", "switch_mode", "fragor"],
  ["fragor", "nu tar vi rizzläget", "switch_mode", "rizz"],
  ["prov", "starta socialt läge", "switch_mode", "socialt"],
  ["fragor", "dags för intervjuträning", "switch_mode", "intervju"],
  ["prov", "ta en kort paus", "pause", null],
  ["fragor", "nu räcker det för idag", "stop", null],
  ["socialt", "Lumen, börja lyssna igen", "resume", null],
  ["prov", "inget mer förhör nu", "switch_mode", "fragor"],
];
// [current mode, ordinary sentence]: no command (a false hit = any command with confidence >= APP_COMMAND_SURE)
const NOT_CMD = [
  ["prov", "kan vi köra en fråga till"],
  ["prov", "jag vill öva mer på provfrågor"],
  ["fragor", "hur pausar man en video på youtube"],
  ["fragor", "min hund lyssnar aldrig på mig"],
  ["prov", "vi är klara med kapitel tre, vad kommer sen"],
  ["fragor", "ska vi ta en paus från sociala medier"],
  ["intervju", "pausa"],
  ["socialt", "vi är klara nu"],
  ["fragor", "stäng av spisen"],
  ["prov", "börja med provläget i matte, vad är en derivata"],
  ["fragor", "kör vi intervjun imorgon eller på fredag"],
  ["fragor", "tyst en stund i klassrummet är skönt"],
  ["fragor", "testa provläget en gång, sa min lärare"],
  ["rizz", "vi tar intervjun sen"],
  ["fragor", "jag har inte tid att plugga nu"],
];
// [correction in own words, expected "key:value"]
const CORR = [
  ["kan du korta ner det", "length:shorter"], ["det blev för långt", "length:shorter"], ["lite kortare", "length:shorter"],
  ["svara kortare nästa gång", "length:shorter"], ["kortare i fortsättningen", "length:shorter"], ["du pratar för mycket", "length:shorter"],
  ["Lumen, för långt", "length:shorter"],
  ["kan du förklara mer", "length:longer"], ["lite längre svar tack", "length:longer"], ["det var för kort, utveckla", "length:longer"],
  ["förklara som för en tioåring", "simplicity:simpler"], ["jag fattar inte", "simplicity:simpler"], ["för svåra ord", "simplicity:simpler"],
  ["säg det enklare", "simplicity:simpler"], ["enklare tack", "simplicity:simpler"],
  ["ge ett exempel", "examples:more"], ["kan du ta ett exempel", "examples:more"], ["exempel hade hjälpt", "examples:more"],
  ["det stämmer inte alls", "accuracy:careful"], ["nej det är inte sant", "accuracy:careful"],
];
const NOT_CORR = ["vad är kortare, en mil eller en kilometer", "ge exempel på däggdjur", "är det fel att ljuga",
  "jag förstår inte varför himlen är blå", "kortare än en meter, vad heter det"];

const cmd = CMD.map(([cur, t, action, mode]) => {
  const r = detectAppCommand(t, cur);
  const sure = !!r && r.confidence >= APP_COMMAND_SURE;
  return { cur, t, expect: mode ? `${action}:${mode}` : action, got: r ? (r.mode ? `${r.action}:${r.mode}` : r.action) : null, confidence: r?.confidence ?? null,
    ok: sure && r.action === action && (r.mode ?? null) === mode };
});
const notCmd = NOT_CMD.map(([cur, t]) => {
  const r = detectAppCommand(t, cur);
  return { cur, t, got: r ? (r.mode ? `${r.action}:${r.mode}` : r.action) : null, confidence: r?.confidence ?? null, false_hit: !!r && r.confidence >= APP_COMMAND_SURE };
});
const corr = CORR.map(([t, want]) => { const r = detectCorrection(t); const got = r ? `${r.key}:${r.value}` : null; return { t, want, got, ok: got === want }; });
const notCorr = NOT_CORR.map((t) => { const r = detectCorrection(t); return { t, got: r ? `${r.key}:${r.value}` : null, false_hit: !!r }; });

// (b2) scope: [name, corrections [[text, context]...], probe context, should the setting apply there?]
const P = (subject) => ({ mode: "prov", subject, answer_type: subject === "Matematik" ? "math" : "explanation" });
const F = { mode: "fragor", answer_type: "fact" };
const SEQ = [
  ["same subject", [["kortare", P("Biologi")]], P("Biologi"), true],
  ["other subject, same mode (one correction)", [["kortare", P("Biologi")]], P("Kemi"), false],
  ["two subjects in Provläge widen to the mode", [["kortare", P("Biologi")], ["kortare", P("Kemi")]], P("Historia"), true],
  ["Frågor setting stays in Frågor", [["kortare", F]], P("Biologi"), false],
  ["Frågor then Provläge widen to global (probe Provläge, third subject)", [["kortare", F], ["kortare", P("Biologi")]], P("Fysik"), true],
  ["Frågor then Provläge widen to global (probe the Provläge subject itself)", [["kortare", F], ["kortare", P("Biologi")]], P("Biologi"), true],
  ["Provläge then Frågor widen to global (probe Frågor)", [["kortare", P("Biologi")], ["kortare", F]], F, true],
  ["Provläge then Frågor widen to global (probe Provläge, other subject)", [["kortare", P("Biologi")], ["kortare", F]], P("Kemi"), true],
  ["math by answer type", [["kortare", P("Matematik")]], P("Matematik"), true],
  ["math setting not in Biologi", [["enklare", P("Matematik")]], P("Biologi"), false],
  ["opposite replaces (Frågor kortare then längre)", [["kortare", F], ["längre", F]], F, "longer only"],
  ["opposite replaces (Biologi kortare then längre)", [["kortare", P("Biologi")], ["längre", P("Biologi")]], P("Biologi"), "longer only"],
];
const seq = SEQ.map(([name, steps, probe, want]) => {
  let settings = [];
  const trace = [];
  for (const [text, ctx] of steps) {
    const c = detectCorrection(text);
    const r = applyCorrection(settings, c, ctx);
    settings = r.settings;
    trace.push({ text, ctx, changed: describe(r.changed), scope: r.changed.scope, widened: r.widened });
  }
  const app = applicable(settings, probe);
  const got = want === "longer only"
    ? app.filter((s) => s.key === "length").map((s) => s.value).join(",") === "longer"
    : app.some((s) => s.key === detectCorrection(steps[0][0]).key);
  return { name, probe, expect: want, applies: app.map(describe), settings: settings.map((s) => ({ ...s, text: describe(s) })), trace,
    ok: want === "longer only" ? got : got === want };
});

const out = {
  app_commands: { n: cmd.length, ok: cmd.filter((x) => x.ok).length, misses: cmd.filter((x) => !x.ok) },
  app_command_negatives: { n: notCmd.length, false_hits: notCmd.filter((x) => x.false_hit), unsure_hits: notCmd.filter((x) => x.got && !x.false_hit) },
  corrections: { n: corr.length, ok: corr.filter((x) => x.ok).length, misses: corr.filter((x) => !x.ok) },
  correction_negatives: { n: notCorr.length, false_hits: notCorr.filter((x) => x.false_hit) },
  scope: { n: seq.length, ok: seq.filter((x) => x.ok).length, wrong: seq.filter((x) => !x.ok) },
  cmd, notCmd, corr, notCorr, seq,
};
console.log(JSON.stringify(out, null, 1));
