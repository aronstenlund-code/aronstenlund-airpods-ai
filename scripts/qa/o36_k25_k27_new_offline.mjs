// Oscar QA, O36: independent offline retest of Kevin's K25 (numbers aloud, calc), K26 (memory: per D113/D114 only
// health, crisis and ID numbers are a restriction, B5) and K27 (questions about Lumen, echo, resource requests) with
// NEW cases (none in O24/O26/O28/O30/O31/O32). The Rizz filter (K26 part 1) is not tested: D113 A1 removes it.
// Free, deployed files.  node --experimental-transform-types scripts/qa/o36_k25_k27_new_offline.mjs > reports/qa/data/<stamp>-o36.json
import { readFileSync } from "node:fs";
import { toSpeech } from "../../backend/supabase/functions/answer/speech.ts";
import { computeFragment } from "../../backend/supabase/functions/answer/calc.ts";
import { selfAnswer } from "../../backend/supabase/functions/answer/self.ts";
import { stripEcho } from "../../backend/supabase/functions/answer/echo.ts";
import { isResourceRequest, resourceTopic } from "../../backend/supabase/functions/answer/resource.ts";

const NUM = [ // [model text, accepted (|), forbidden (|)]
  ["Skolavslutningen är 12/6.", "tolfte juni", "/"], ["Mors dag firas den 31 maj.", "trettioförsta maj", "trettioett maj"],
  ["Den 1/12 tänds adventsljusen.", "första december", "/"], ["Matchen slutade 2–0.", "två mot noll|två–noll|två noll", "till"],
  ["Mjölken kostar 7,90 kr.", "sju kronor och nittio öre|sju och nittio", "komma"], ["Jag har 1 katt.", "en katt", "ett katt"],
  ["Hon köpte 1 banan och 1 äpple.", "en banan", "ett banan"], ["Ta buss nr 4.", "nummer fyra", "nr"],
  ["Mötet börjar kl. 8.15.", "klockan åtta och femton|klockan åtta femton|klockan kvart över åtta", "kl."],
  ["5/9 av klassen kom.", "fem niondelar", "/"], ["Han kom 3:a i tävlingen.", "kom trea|kom på tredje", ""],
  ["Hon fick 13 poäng och Karl 15 poäng.", "femton poäng", "den femtonde"], ["Biljetten kostade 120,50 kr.", "hundratjugo kronor och femtio öre|hundratjugo och femtio", "komma"],
  ["Läs s. 23.", "sidan tjugotre", "s."], ["Det var 1 000 personer där.", "tusen personer", ""],
];
const CALC = [ // [utterance, expected value or null (= must be left to the model)]
  ["vad är 3 * (2 + 2)", null], ["vad är 5 procent av 80", 4], ["vad är 2,5 gånger 4", 10], ["vad är 1000 delat med 8", 125],
  ["vad är (7)", null], ["vad är 4 upphöjt till 3", 64], ["vad är 13 gånger 13", 169], ["vad är 99 plus 1 gånger 0", 99],
];
const SELF = [ // [utterance, topic or null]
  ["hör du vad min lärare säger", "listen"], ["sparar ni allt jag frågar", "save"], ["är du typ en bot", "robot"],
  ["vem programmerade dig", "robot"], ["kan någon annan läsa det här", "save"], ["tar du upp ljud i bakgrunden", "listen"],
  ["vilket år föddes Alan Turing", null], ["sparar du energi på natten", null], ["hör du hur dum frågan är", null],
];
const ECHO_A = "Vulkaner bildas där jordskorpans plattor möts eller glider isär, och magma tränger upp.";
const ECHO = [ // [fragment, words the rest must contain (all, |) or "echo"]
  ["där jordskorpans plattor möts eller glider isär", "echo"], ["vad betyder glider isär och magma tränger upp", "betyder|magma"],
  ["så vulkaner bildas där jordskorpans plattor möts?", "vulkaner|plattor"], ["och magma tränger upp, varför gör den det", "magma|varför"],
];
const RES = [ // [utterance, is a request, topic must contain]
  ["har du typ en video om Newtons lagar", true, "newton"], ["kan jag få en länk till något om ekosystem", true, "ekosystem"],
  ["finns det något klipp på Khan om bråk", true, "bråk"], ["vad är en länk i kemi", false, ""], ["jag tittade på en film om rymden igår", false, ""],
  ["tips på någon sida där jag kan öva glosor", true, "glosor"],
];
// memory (K26/B5): health, crisis and ID numbers must be dropped; per D113 A5 other categories are no restriction
const SRC = readFileSync(new URL("../../backend/supabase/functions/memory/handler.ts", import.meta.url), "utf8");
const lit = (name) => { const m = new RegExp(String.raw`const ${name} =\s*\/(.+)\/([a-z]*);`).exec(SRC); return m ? new RegExp(m[1], m[2]) : null; };
const SR = lit("SENSITIVE_RAW"), SW = lit("STUDY_WORDS");
const MEM_DROP = ["Har migrän ofta", "Tar insulin", "Har psoriasis", "Har en hjärtfel sedan födseln", "Har tänkt på att ta sitt liv",
  "Brukar rispa sig", "Personnummer 090314-1234", "Samordningsnummer 091314-1234", "Har hörapparat", "Går på BUP varje vecka"];
const MEM_KEEP = ["Har prov i biologi om hjärtat", "Läser om migration i samhällskunskap", "Gillar att springa", "Ska skriva om diabetes som uppsatsämne"];
const memSens = (t) => SR ? SR.test(t.replace(SW ?? /$^/, " ")) : null;

const nRow = NUM.map(([t, acc, bad]) => { const o = toSpeech(t).toLowerCase(); return { t, out: o, ok: !/\d/.test(o) && acc.split("|").some((a) => o.includes(a)) && !(bad && bad.split("|").some((b) => o.includes(b))) }; });
const cRow = CALC.map(([t, v]) => { const c = computeFragment(t, new Date("2026-11-10T10:00:00Z")); const g = c ? c.value : null; return { t, want: v, got: g, ok: g === null ? true : v !== null && Math.abs(g - v) < 1e-6 }; });
const sRow = SELF.map(([t, w]) => { const a = selfAnswer(t); const g = !a ? null : /AI-assistent/.test(a) ? "robot" : /lyssnar bara/.test(a) ? "listen" : /sparas/.test(a) ? "save" : "?"; return { t, want: w, got: g, answer: a, ok: g === w }; });
const eRow = ECHO.map(([f, w]) => { const r = stripEcho(f, ECHO_A); return { f, rest: r.rest, ok: w === "echo" ? r.rest.replace(/[^\p{L}]/gu, "").length < 6 : w.split("|").every((x) => r.rest.toLowerCase().includes(x)) }; });
const rRow = RES.map(([t, req, top]) => { const q = isResourceRequest(t); const tp = q ? resourceTopic(t, "") : ""; return { t, req: q, topic: tp, ok: q === req && (!req || tp.toLowerCase().includes(top)) }; });
const mRow = [...MEM_DROP.map((t) => ({ t, want: "drop", sens: memSens(t), ok: memSens(t) === true })), ...MEM_KEEP.map((t) => ({ t, want: "keep", sens: memSens(t), ok: memSens(t) === false }))];
const n = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ sum_numbers: n(nRow), sum_calc_no_wrong: n(cRow), sum_self: n(sRow), sum_echo: n(eRow), sum_resource: n(rRow), sum_memory_b5: n(mRow),
  fails: [...nRow, ...cRow, ...sRow, ...eRow, ...rRow, ...mRow].filter((x) => !x.ok), nRow, cRow, sRow, eRow, rRow, mRow }, null, 1));
