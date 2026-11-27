// O107 del 3 (Oscar moln, 2026-11-27): minnet (/memory), studieprofilen (/study-profile) och studieplanen (/study-plan)
// med serverns egna handlers. Modellsvaren är mina (jag spelar Haiku) och ges av en låtsasleverantör som sparar prompten;
// /study-plan är bara kod. Testet är serverns eget skydd: vad sparas när modellen ändå skriver något den inte borde?
// Inga nätanrop, 0 ElevenLabs. Kör: cd backend && deno run --no-lock --no-check --allow-read --allow-env ../scripts/qa/o107/memory_plan.ts
import { MemoryRateLimiter } from "../../../backend/supabase/functions/_shared/ratelimit.ts";
import { createMemoryHandler } from "../../../backend/supabase/functions/memory/handler.ts";
import { createProfileHandler } from "../../../backend/supabase/functions/study-profile/handler.ts";
import { createPlanHandler } from "../../../backend/supabase/functions/study-plan/handler.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../../../backend/supabase/functions/answer/llm/types.ts";

const NOW = new Date("2026-11-27T09:00:00+01:00");
function fake(reply: string | null): { p: LLMProvider; seen: LLMRequest[] } {
  const seen: LLMRequest[] = [];
  return { seen, p: { name: "fake", model: "claude-haiku-5-5", stream(r: LLMRequest): AsyncIterable<LLMChunk> {
    seen.push(r);
    return (async function* () { yield { type: "text", text: reply ?? "{}" } as LLMChunk; yield { type: "usage", inputTokens: 300, outputTokens: 40 } as LLMChunk; })();
  } } };
}
const auth = () => Promise.resolve({ id: "u1", isAnonymous: true });
async function post(h: (r: Request) => Promise<Response>, body: unknown) {
  const r = await h(new Request("http://x/", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" }, body: JSON.stringify(body) }));
  return { status: r.status, body: await r.json() };
}
const out: Record<string, unknown>[] = [];
// [id, what the wearer said, existing memories, my reply as the model]
const MEM: [string, string, string[], string][] = [
  ["M1", "jag har prov i kemi på fredag", [], '{"add":["Har prov i kemi fredag 28 november 2026."],"update":[],"remove":[]}'],
  ["M2", "provet i kemi är flyttat till nästa onsdag", ["Har prov i kemi fredag 28 november 2026."], '{"add":[],"update":[{"old":"Har prov i kemi fredag 28 november 2026.","new":"Har prov i kemi onsdag 3 december 2026."}],"remove":[]}'],
  ["M3", "svara alltid kortare till mig", [], '{"add":["Vill ha kortare svar."],"update":[],"remove":[]}'],
  ["M4", "jag har dyslexi så läs långsamt", [], '{"add":["Har dyslexi.","Vill att texten läses långsamt."],"update":[],"remove":[]}'],
  ["M5", "jag tar penicillin den här veckan", [], '{"add":["Tar penicillin den här veckan."],"update":[],"remove":[]}'],
  ["M6", "jag har hörselnedsättning på vänster öra", [], '{"add":["Har hörselnedsättning på vänster öra."],"update":[],"remove":[]}'],
  ["M7", "jag går på KBT varje tisdag", [], '{"add":["Går på KBT varje tisdag."],"update":[],"remove":[]}'],
  ["M8", "mitt mobilnummer är 070-123 45 67", [], '{"add":["Mobilnummer 070-123 45 67."],"update":[],"remove":[]}'],
  ["M9", "jag bor på Storgatan 12 i Uppsala", [], '{"add":["Bor på Storgatan 12 i Uppsala."],"update":[],"remove":[]}'],
  ["M10", "min mejl är elev.test@example.com", [], '{"add":["Mejladress elev.test@example.com."],"update":[],"remove":[]}'],
  ["M11", "min pappa heter Johan och är arbetslös", [], '{"add":["Pappan heter Johan och är arbetslös."],"update":[],"remove":[]}'],
  ["M12", "jag orkar inte leva längre", [], '{"add":["Orkar inte leva längre."],"update":[],"remove":[]}'],
  ["M13", "I have an English test on Monday", [], '{"add":["Har prov i engelska måndag 30 november 2026."],"update":[],"remove":[]}'],
  ["M14", "vad är fotosyntes", [], '{"add":["Undrar vad fotosyntes är."],"update":[],"remove":[]}'],
  ["M15", "jag har glutenallergi", [], '{"add":["Har glutenallergi."],"update":[],"remove":[]}'],
  ["M16", "mitt nummer är 0701234567", [], '{"add":["Mobilnummer 0701234567."],"update":[],"remove":[]}'],
  ["M17", "ring mig på +46 70 123 45 67", [], '{"add":["Nås på +46 70 123 45 67."],"update":[],"remove":[]}'],
  ["M18", "mitt nummer är noll sju noll ett två tre fyra fem sex sju", [], '{"add":["Telefonnummer noll sju noll ett två tre fyra fem sex sju."],"update":[],"remove":[]}'],
  ["M19", "min mejl är elev at example dot com", [], '{"add":["Mejl elev at example dot com."],"update":[],"remove":[]}'],
  ["M20", "jag bor på Kungsgatan 3B, lgh 1101, 752 37 Uppsala", [], '{"add":["Bor på Kungsgatan 3B, lgh 1101, 752 37 Uppsala."],"update":[],"remove":[]}'],
  ["M21", "my number is 07012 34567 and I live at 5 Baker Street", [], '{"add":["Telefon 07012 34567.","Bor på 5 Baker Street."],"update":[],"remove":[]}'],
  ["M22", "min bror heter Elias", [], '{"add":["Brodern heter Elias."],"update":[],"remove":[]}'],
  ["M23", "min mamma heter Anna och är sjuk", [], '{"add":["Mamman heter Anna och är sjuk."],"update":[],"remove":[]}'],
  ["M24", "min kompis Elias är arbetslös", [], '{"add":["Elias är arbetslös."],"update":[],"remove":[]}'],
  ["M25", "min bästa vän Sara har ADHD", [], '{"add":["Bästa vännen Sara har ADHD."],"update":[],"remove":[]}'],
  ["M26", "min kompis Leo bor på Ringvägen 5", [], '{"add":["Kompisen Leo bor på Ringvägen 5."],"update":[],"remove":[]}'],
  ["M27", "jag bor i Uppsala och går på Katedralskolan", [], '{"add":["Bor i Uppsala.","Går på Katedralskolan."],"update":[],"remove":[]}'],
];
for (const [id, q, mem, reply] of MEM) {
  const f = fake(reply);
  const r = await post(createMemoryHandler({ authenticate: auth as never, rateLimiter: new MemoryRateLimiter(), provider: f.p, now: () => NOW }), { turn: { question: q }, memories: mem, language: "sv" });
  out.push({ id, kind: "minne", said: q, model_called: f.seen.length > 0, reply: JSON.parse(reply), saved: r.body, status: r.status });
}
const PROF: [string, string, string][] = [
  ["SP1", "jag går i nian och har prov i biologi om cellen på fredag", '{"profile":{"grade":"y9","course":null,"subject":"Biologi","exam_date":"2026-11-28","no_exam":false,"topic":"cellen"},"terms":["cell","cellkärna","mitokondrie","cellmembran","cellvägg","kloroplast","DNA","ribosom"]}'],
  ["SP2", "jag läser Matematik 2c på gymnasiet, inget prov just nu", '{"profile":{"grade":"gy2","course":"Matematik 2c","subject":"Matematik","exam_date":null,"no_exam":true,"topic":null},"terms":["andragradsekvation","logaritm","derivata","linjär funktion"]}'],
  ["SP3", "jag har ADHD och går i åttan", '{"profile":{"grade":"y8","course":null,"subject":null,"exam_date":null,"no_exam":false,"topic":null,"diagnosis":"ADHD"},"terms":[]}'],
  ["SP4", "geografiprov nästa vecka om Europas floder", '{"profile":{"grade":null,"course":null,"subject":"Geografi","exam_date":"2026-11-30","no_exam":false,"topic":"Europas floder"},"terms":["Donau","Rhen","Volga","Seine","Loire","Elbe","Po","Themsen"]}'],
  ["SP5", "jag går i fjärde klass", '{"profile":{"grade":"y4","course":null,"subject":null,"exam_date":null,"no_exam":false,"topic":null},"terms":[]}'],
];
for (const [id, said, reply] of PROF) {
  const f = fake(reply);
  const r = await post(createProfileHandler({ authenticate: auth as never, rateLimiter: new MemoryRateLimiter(), provider: f.p, now: () => NOW }), { text: said, language: "sv" });
  out.push({ id, kind: "profil", said, reply: JSON.parse(reply), result: r.body, status: r.status, user: f.seen[0]?.user?.slice(0, 160) });
}
const plan = createPlanHandler({ authenticate: auth as never, clock: () => NOW } as never);
const PLAN: [string, unknown][] = [
  ["PL1", { today: "2026-11-27", exams: [{ name: "Biologiprovet", date: "2026-11-28", concepts: [{ concept: "cellandning", history: [{ date: "2026-11-26", ok: false }] }, { concept: "fotosyntes", history: [{ date: "2026-11-26", ok: true }] }] }] }],
  ["PL2", { today: "2026-11-27", exams: [{ name: "Historia", date: "2026-12-10", concepts: [] }] }],
  ["PL3", { today: "2026-11-27", exams: [{ name: "Gammalt prov", date: "2026-11-20", concepts: [{ concept: "x", history: [] }] }] }],
  ["PL4", { today: "2026-11-27", quiz_days: ["2026-11-25", "2026-11-26"], exams: [{ name: "Kemi", date: "2026-12-03", concepts: [{ concept: "syror", history: [{ date: "2026-11-25", ok: false }, { date: "2026-11-26", ok: false }] }, { concept: "baser", history: [{ date: "2026-11-25", ok: true }, { date: "2026-11-26", ok: true }] }] }] }],
  ["PL5", { today: "2026-11-27", exams: [{ name: "<script>alert(1)</script>", date: "2026-11-30", concepts: [{ concept: "a".repeat(500), history: [{ date: "2027-01-01", ok: true }] }] }] }],
];
for (const [id, body] of PLAN) {
  const r = await post(plan, body);
  out.push({ id, kind: "plan", status: r.status, result: r.body });
}
console.log(JSON.stringify(out, null, 1));
