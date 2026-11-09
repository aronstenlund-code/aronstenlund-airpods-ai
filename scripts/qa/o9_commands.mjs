// Oscar QA, O9: independent test of Kevin's K9 command table (backend/supabase/functions/answer/commands.ts) with
// my own phrasings: 3 new ones per task (none of them in k9_test.ts or the live eval) and 15 ordinary sentences with
// command words. The expected task is taken from docs/COMMANDS.md (what the phrase means), not from the regexes.
// Node 24 runs the .ts file directly (type stripping), so this is the deployed matcher, offline and free.
//   node scripts/qa/o9_commands.mjs > reports/qa/data/<stamp>-o9-offline.json
import { commandTask, detectRule } from "../../backend/supabase/functions/answer/commands.ts";

const P = [ // [task, scope, phrase]
  ["example", "study", "Lumen, kan jag få ett exempel?"], ["example", "study", "ge mig ett annat exempel"], ["example", "study", "visa ett exempel på det"],
  ["summary", "study", "sammanfatta kort"], ["summary", "study", "Lumen, ge mig det viktigaste"], ["summary", "study", "kan du summera det här"],
  ["a_level", "study", "säg det på A-nivå"], ["a_level", "study", "ge mig ett A-svar"], ["a_level", "study", "hur får jag ett A"],
  ["harder_question", "study", "fråga mig något svårare"], ["harder_question", "study", "ge mig en klurig fråga"], ["harder_question", "study", "Lumen, ställ en svårare fråga"],
  ["quick_quiz", "study", "snabbförhör mig"], ["quick_quiz", "study", "kör fem korta frågor"], ["quick_quiz", "study", "Lumen, snabbquiz"],
  ["yes_no_quiz", "study", "ge mig ja eller nej frågor"], ["yes_no_quiz", "study", "kör ja-nej-frågor"], ["yes_no_quiz", "study", "ja nej förhör"],
  ["quiz_topic", "study", "förhör mig om fotosyntesen"], ["quiz_topic", "study", "Lumen, testa mig på andra världskriget"], ["quiz_topic", "study", "quizza mig i ekvationer"],
  ["weak_areas", "study", "öva på mina svaga delar"], ["weak_areas", "study", "vad är jag sämst på"], ["weak_areas", "study", "förhör mig på mina sämsta begrepp"],
  ["self_assessment", "study", "hur går det för mig"], ["self_assessment", "study", "hur bra kan jag ämnet"], ["self_assessment", "study", "Lumen, kan jag det här"],
  ["careful", "study", "kolla noga"], ["careful", "study", "dubbelkolla svaret"], ["careful", "study", "är du säker på det där"],
  ["catch_up", "study", "vad sa hon"], ["catch_up", "study", "sammanfatta vad som sades"], ["catch_up", "study", "vad pratade de om"],
  ["brief_style", "study", "svara diskret"], ["brief_style", "study", "svara med bara en mening"], ["brief_style", "study", "en mening tack"],
  ["interview_help:professional", "interview", "vad säger jag"], ["interview_help:professional", "interview", "hjälp mig att svara professionellt"], ["interview_help:professional", "interview", "Lumen, hjälp mig svara"],
  ["interview_help:better", "interview", "säg ett bättre svar"], ["interview_help:better", "interview", "förbättra svaret"], ["interview_help:better", "interview", "gör det bättre"],
  ["interview_help:confident", "interview", "mer säker"], ["interview_help:confident", "interview", "säkrare"], ["interview_help:confident", "interview", "låt säker"],
  ["interview_help:counter_question", "interview", "motfråga"], ["interview_help:counter_question", "interview", "vad kan jag fråga dem"], ["interview_help:counter_question", "interview", "Lumen, ge mig en motfråga tack"],
  ["interview_help:stuck", "interview", "hjälp"], ["interview_help:stuck", "interview", "jag kommer inte på något"], ["interview_help:stuck", "interview", "jag fastnar"],
  ["social:reply", "social", "vad bör jag svara"], ["social:reply", "social", "vad ska jag säga"], ["social:reply", "social", "Lumen, vad svarar jag"],
  ["social:funnier", "social", "mer skämt"], ["social:funnier", "social", "Lumen, roligare tack"], ["social:funnier", "social", "kan du göra det roligare"],
  ["social:natural", "social", "mer avslappnat"], ["social:natural", "social", "naturligare tack"], ["social:natural", "social", "mindre stelt snälla"],
  ["social:change_topic", "social", "nytt ämne"], ["social:change_topic", "social", "Lumen, byt ämne"], ["social:change_topic", "social", "något annat att prata om tack"],
  ["social:follow_up", "social", "följdfråga"], ["social:follow_up", "social", "ge mig en smart följdfråga"], ["social:follow_up", "social", "en bra följdfråga"],
  ["social:what_meant", "social", "vad menade de"], ["social:what_meant", "social", "vad menade hen med det"], ["social:what_meant", "social", "Lumen, vad menade hon"],
  ["rizz:more", "social", "lite rizz"], ["rizz:more", "social", "ge mig mer rizz"], ["rizz:more", "social", "Lumen, rizz"],
  ["rizz:confident", "social", "mer självsäkert tack"], ["rizz:confident", "social", "Lumen, säkrare"], ["rizz:confident", "social", "mer självsäker"],
  ["rizz:flirty", "social", "flörtigare"], ["rizz:flirty", "social", "mer flörtig tack"], ["rizz:flirty", "social", "Lumen, flirtigare"],
  ["rizz:subtle", "social", "mer diskret"], ["rizz:subtle", "social", "lugnare tack"], ["rizz:subtle", "social", "Lumen, subtilare"],
  ["rizz:cocky", "social", "mer kaxig"], ["rizz:cocky", "social", "kaxigare tack"], ["rizz:cocky", "social", "Lumen, mer kaxigt"],
  ["rizz:rescue", "social", "hjälp det går dåligt"], ["rizz:rescue", "social", "rädda situationen tack"], ["rizz:rescue", "social", "Lumen, rädda mig"],
  ["rizz:less_cringe", "social", "mindre pinsam"], ["rizz:less_cringe", "social", "mindre pinsamt tack"], ["rizz:less_cringe", "social", "Lumen, mindre cringe"],
  ["alternatives:3", "social", "tre repliker"], ["alternatives:3", "social", "ge mig tre varianter"], ["alternatives:3", "social", "Lumen, tre alternativ"],
];
// ordinary sentences (questions or statements) with command words: must give NO task (and no standing rule)
const N = [
  ["study", "vad är ett bra exempel på en näringskedja"], ["study", "sammanfatta andra världskriget för mig"], ["study", "hur bra kan en hund höra"],
  ["study", "vad sa Martin Luther King i sitt tal"], ["study", "förklara på enkel svenska vad en atom är"], ["study", "vad missade jag på provet om cellen"],
  ["study", "ge mig fem exempel på adjektiv"], ["study", "jag fastnar alltid på bråktal, varför"], ["study", "vad betyder diskret i matematik"],
  ["study", "är du säker på att jorden är 4,5 miljarder år"], ["study", "en mening om fotosyntes"], ["study", "testa mig"],
  ["interview", "vad säger jag om min största svaghet"], ["social", "det går dåligt i skolan för mig just nu"], ["social", "vad menade du med att du skulle åka bort"],
];
const pos = P.map(([task, scope, p]) => { const r = commandTask(p, scope); return { p, scope, expect: task, got: r?.task ?? null, arg: r?.arg, ok: r?.task === task }; });
const neg = N.map(([scope, p]) => { const r = commandTask(p, scope); const rule = detectRule ? detectRule(p) : null; return { p, scope, got: r?.task ?? null, arg: r?.arg, rule: rule ?? null, ok: !r && !rule }; });
const out = { positives: { n: pos.length, ok: pos.filter((x) => x.ok).length, misses: pos.filter((x) => !x.ok) }, negatives: { n: neg.length, ok: neg.filter((x) => x.ok).length, false_hits: neg.filter((x) => !x.ok) }, pos, neg };
console.log(JSON.stringify(out, null, 1));
