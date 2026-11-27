// O105 (Oscar moln, 2026-11-27): Säg i AirPods på servern, de delar som har en modell och K122 inte täcker: stilen
// ("Hur ska det låta?", haikuStyler + checkTagged + codeStyle) och röstvalet (haikuVoicePicker), plus talformatet för
// Säg-texten (voiceText). Modellsvaren är mina (jag spelar Haiku); en låtsasleverantör ger dem och sparar prompten.
// Inga nätanrop, 0 ElevenLabs. Kör: cd backend && deno run --no-lock --allow-read ../scripts/qa/o105/style_voice.ts
import { haikuStyler, haikuVoicePicker, SYSTEM_PROMPT_STYLE, SYSTEM_PROMPT_VOICE_PICK } from "../../../backend/supabase/functions/drill/style.ts";
import { voiceText } from "../../../backend/supabase/functions/drill/handler.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../../../backend/supabase/functions/answer/llm/types.ts";

function fake(reply: string | Error): { p: LLMProvider; seen: LLMRequest[] } {
  const seen: LLMRequest[] = [];
  return { seen, p: { name: "fake", model: "claude-haiku-5-5", stream(r: LLMRequest): AsyncIterable<LLMChunk> {
    seen.push(r);
    return (async function* () { if (reply instanceof Error) throw reply; yield { type: "text", text: reply } as LLMChunk; })();
  } } };
}
const out: Record<string, unknown>[] = [];
const SV = "Fotosyntesen sker i bladen. Växten gör socker av ljus, vatten och koldioxid. Syre släpps ut.";
const EN = "Photosynthesis happens in the leaves. The plant makes sugar from light, water and carbon dioxide.";
const style: [string, string, string, string | Error][] = [
  ["ST1", SV, "lugnt och tydligt, som en lärare", "[calm] Fotosyntesen sker i bladen. [pause] Växten gör socker av ljus, vatten och koldioxid. [pause] Syre släpps ut."],
  ["ST2", SV, "glatt", "[cheerful] Fotosyntesen sker i löven. Växten gör socker av ljus, vatten och koldioxid. Syre släpps ut."],
  ["ST3", EN, "slow, with pauses so I can write", "[slowly] Photosynthesis happens in the leaves. [long pause] The plant makes sugar from light, water and carbon dioxide."],
  ["ST4", SV, "viska lite", new Error("Provider refused the request")],
  ["ST5", "Glosor: hund dog, katt cat, häst horse.", "med pauser så jag hinner skriva", "[pause] Glosor: [pause] hund dog, [pause] katt cat, [pause] häst horse. [pause]"],
];
for (const [id, text, st, reply] of style) {
  const f = fake(reply);
  const r = await haikuStyler(f.p)(text, st);
  out.push({ id, kind: "stil", style: st, reply: reply instanceof Error ? `fel: ${reply.message}` : reply, result: r, user: f.seen[0]?.user?.slice(0, 200) });
}
const CAT = [
  { voice_id: "v_jonas", name: "Jonas", description: "Lugn, tydlig svensk mansröst, passar för uppläsning", accent: "standard svenska", gender: "male", age: "middle_aged" },
  { voice_id: "v_saga", name: "Saga", description: "Varm och glad ung kvinnoröst", accent: "standard svenska", gender: "female", age: "young" },
  { voice_id: "v_bertil", name: "Bertil", description: "Äldre man, långsam och berättande", accent: "skånska", gender: "male", age: "old" },
  { voice_id: "v_alyssa", name: "Alyssa", description: "Clear American English, friendly", accent: "american", gender: "female", age: "young" },
];
const voice: [string, string, string][] = [
  ["VO1", "lugnt, som en lärare", '{"voice_id": "v_jonas", "reason": "Jonas är lugn och tydlig, som en lärare."}'],
  ["VO2", "med kinesisk brytning", '{"voice_id": "v_jonas", "reason": "Ingen röst med kinesisk brytning finns ännu, så en lugn och tydlig röst."}'],
  ["VO3", "på skånska", '{"voice_id": "v_bertil", "reason": "Bertil talar skånska och berättar lugnt."}'],
  ["VO4", "glatt", '{"voice_id": "v_lisa", "reason": "Lisa är glad."}'],
  ["VO5", "on English, friendly", '{"voice_id": "v_alyssa", "reason": "Alyssa talar tydlig amerikansk engelska och låter vänlig."}'],
];
for (const [id, st, reply] of voice) {
  const f = fake(reply);
  const r = await haikuVoicePicker(f.p)(st, CAT);
  out.push({ id, kind: "röstval", style: st, reply, result: r });
}
const TTS: [string, string, string][] = [
  ["TT1", "Mötet är kl. 14.30 den 3 maj, t.ex. i sal 2B. Ta med ca 50 kr.", ""],
  ["TT2", "Vattnet kokar vid 100 °C och fryser vid 0 °C. Skolan har 1 250 elever, 12 % fler än 2019.", ""],
  ["TT3", "Läs s. 45–47 och kap. 3. pH 7 är neutralt, H2O är vatten och CO2 koldioxid.", ""],
  ["TT4", "The meeting is at 2.30 pm on 3 May, e.g. in room 2B. Bring about $5.", "en"],
  ["TT5", "Ring 112 vid nödläge, 1177 för vård. Karl XII dog 1718, och Gustav II Adolf 1632.", ""],
];
for (const [id, s, lang] of TTS) out.push({ id, kind: "talformat", in: s, lang: lang || "sv", rules4: voiceText(s, lang, 4) });
console.log(JSON.stringify({ prompts: { style: SYSTEM_PROMPT_STYLE.slice(0, 80), voice: SYSTEM_PROMPT_VOICE_PICK.slice(0, 80) }, out }, null, 1));
