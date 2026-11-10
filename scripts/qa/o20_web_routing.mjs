// Oscar QA, O20: which questions does /answer send to the web (K16, D98), and to which domains? Offline, free:
// the deployed answer/web.ts runs in Node 24. Explains O13 part 1 (SVT advice for "hitta min iphone", pasta without
// search) and checks new everyday questions a student asks. Expected values are mine (what a careful answer needs).
//   node scripts/qa/o20_web_routing.mjs > reports/qa/data/<stamp>-o20-web-routing.json
import { needsWeb, lookupKind, isFollowUp, webTools } from "../../backend/supabase/functions/answer/web.ts";

const C = [ // [fragment, expected lookup kind or null (= no search needed), note]
  ["hur stänger man av hitta min iphone", "howto", "O13: got SVT"],
  ["hur sätter man på mörkt läge på en iphone", "howto", ""],
  ["hur kokar man pasta", "recipe", "O13: no search"],
  ["hur kokar man ris", "recipe", ""],
  ["hur länge ska potatis koka", "recipe", ""],
  ["hur gör man en pizzadeg", "recipe", "O13: searched"],
  ["recept på chokladbollar", "recipe", "O13: searched"],
  ["hur mycket socker i en sockerkaka", "recipe", ""],
  ["hur tar man en skärmdump på en mac", "howto", "O13: no search, right answer"],
  ["hur laddar man ner spotify på datorn", "howto", ""],
  ["hur byter man lösenord på instagram", "howto", ""],
  ["är det lagligt att köra moped utan hjälm", "rule", ""],
  ["vilken åldersgräns gäller för solarium", "rule", ""],
  ["får man cykla på trottoaren", "rule", ""],
  ["hur många invånare har Kiruna", "fact", ""],
  ["vem är rektor på Uppsala universitet", "fact", ""],
  ["vad kostar ett SL-kort för ungdomar", "price", ""],
  ["vad är fotosyntes", null, "school knowledge, no search"],
  ["vem var Gustav Vasa", null, ""],
  ["vad är 15 procent av 80", null, ""],
];
const rows = C.map(([f, expect, note]) => {
  let need = null, kind = null, domains = null, err = null;
  try {
    need = needsWeb(f);
    kind = lookupKind(f);
    if (need) {
      const tools = webTools(need);
      domains = tools.map((t) => t.allowed_domains ?? t.blocked_domains ?? null).filter(Boolean);
    }
  } catch (e) { err = String(e); }
  const got = need ? (need.lookup ?? need.kind ?? "web") : null;
  return { f, expect, note, needsWeb: need, lookupKind: kind, domains, followUp: isFollowUp(f), err,
           ok: expect === null ? !need : !!need };
});
console.log(JSON.stringify({ n: rows.length, ok: rows.filter((r) => r.ok).length, rows }, null, 1));
