// Oscar QA, O19: independent offline test of Kevin's K12 matcher changes (O9 #1-#3) with NEW phrasings, plus
// ordinary sentences that use the same words ("för mig", "mina", "göra") and must give no task. The deployed
// commands.ts runs directly in Node 24 (type stripping): free, no randomness.
//   node scripts/qa/o19_k12_offline.mjs > reports/qa/data/<stamp>-o19-k12-offline.json
import { commandTask, detectRule } from "../../backend/supabase/functions/answer/commands.ts";

const P = [ // [expected task, scope, phrase]
  ["self_assessment", "study", "hur går det för mig nu"],
  ["self_assessment", "study", "Lumen, hur går det för mig?"],
  ["self_assessment", "study", "hur ligger jag till"],
  ["self_assessment", "study", "hur har det gått för mig idag"],
  ["self_assessment", "study", "hur bra kan jag det här nu"],
  ["weak_areas", "study", "förhör mig på mina svaga områden"],
  ["weak_areas", "study", "fråga mig om mina sämsta delar"],
  ["weak_areas", "study", "öva på det jag är sämst på"],
  ["weak_areas", "study", "förhör mig på mina svagaste begrepp"],
  ["weak_areas", "study", "Lumen, förhör mig på det jag kan sämst"],
  ["social:funnier", "social", "kan du göra det roligare tack"],
  ["social:funnier", "social", "göra det roligare"],
  ["interview_help:better", "interview", "kan du göra svaret bättre"],
  ["interview_help:better", "interview", "Lumen, göra det bättre"],
  ["interview_help:better", "interview", "kan du göra det bättre tack"],
];
const N = [ // [scope, sentence] -> no task, no standing rule
  ["study", "det gick bra för mig på provet"],
  ["study", "vad betyder det här för mig"],
  ["study", "hur gick det för mig på provet i fredags"],
  ["study", "mina föräldrar vill att jag pluggar mer"],
  ["study", "jag glömde mina anteckningar hemma"],
  ["study", "vad ska jag göra i helgen"],
  ["study", "hur gör man en pizzadeg"],
  ["study", "kan du göra mina läxor"],
  ["study", "jag ska göra en presentation om Gustav Vasa"],
  ["study", "varför är det svårt för mig att koncentrera mig"],
  ["social", "det är roligare att göra det själv"],
  ["social", "han sa att det skulle bli bättre för mig"],
  ["interview", "vad ska jag göra om jag inte får jobbet"],
  ["interview", "kan du göra en lista med mina styrkor"],
  ["study", "förhör mig om mina anteckningar"],
];
const pos = P.map(([task, scope, p]) => { const r = commandTask(p, scope); return { p, scope, expect: task, got: r?.task ?? null, arg: r?.arg ?? null, ok: r?.task === task }; });
const neg = N.map(([scope, p]) => { const r = commandTask(p, scope); const rule = detectRule(p); return { p, scope, got: r?.task ?? null, arg: r?.arg ?? null, rule: rule?.rule ?? null, ok: !r && !rule }; });
console.log(JSON.stringify({ positives: { n: pos.length, ok: pos.filter((x) => x.ok).length }, negatives: { n: neg.length, ok: neg.filter((x) => x.ok).length }, pos, neg }, null, 1));
