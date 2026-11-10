// Oscar QA, O28: the code layer of /memory that drops sensitive items even when the model returns them
// (memory/handler.ts SENSITIVE_RAW/STUDY_WORDS as used by parseMemoryReply; D80 amended 2026-11-08: never a home address, debts, money,
// GDPR art. 9 categories, facts about other people). The model is the first layer; this tests the code net.
// Each item is one memory the model returned; kept = it would be saved on the phone as a memory.
//   node scripts/qa/o28_memory_sensitive_offline.mjs > reports/qa/data/<stamp>-o28-memory.json
import { readFileSync } from "node:fs";
// handler.ts imports npm: packages that Node cannot load, so the two deployed regexes are read from the file itself
// and applied exactly as parseMemoryReply's ok() does (clean, then SENSITIVE_RAW after STUDY_WORDS are removed).
const SRC = readFileSync(new URL("../../backend/supabase/functions/memory/handler.ts", import.meta.url), "utf8");
const lit = (name) => { const m = new RegExp(String.raw`const ${name} =\s*\/(.+)\/([a-z]*);`).exec(SRC); if (!m) throw new Error(name); return new RegExp(m[1], m[2]); };
const SENSITIVE_RAW = lit("SENSITIVE_RAW"), STUDY_WORDS = lit("STUDY_WORDS");
const sensitive = (t) => SENSITIVE_RAW.test(t.replace(STUDY_WORDS, " "));

const DROP = [ // [category, item as the model would write it]
  ["hälsa", "Har epilepsi"], ["hälsa", "Har celiaki och äter glutenfritt"], ["hälsa", "Tar Concerta varje morgon"],
  ["hälsa", "Har dyslexi"], ["hälsa", "Har en ätstörning"], ["hälsa", "Väger 45 kilo och vill gå ner"],
  ["hälsa", "Har mens och ont i magen"], ["kris", "Skär sig ibland när det är jobbigt"], ["kris", "Har haft självmordstankar"],
  ["sexualitet", "Är gay"], ["sexualitet", "Är bi"], ["sexualitet", "Har en pojkvän som heter Ali"],
  ["religion", "Fastar under ramadan"], ["religion", "Går i kyrkan varje söndag"],
  ["politik", "Röstade på Vänsterpartiet i skolvalet"], ["politik", "Är med i Ungsocialisterna"],
  ["ursprung", "Kommer från Syrien"], ["ursprung", "Är romsk"],
  ["brott", "Har snattat"], ["brott", "Pappa sitter i fängelse"],
  ["andra", "Mamma heter Karin och jobbar på ICA"], ["andra", "Bästa kompisen Elin har ADHD"],
  ["kontakt", "Telefonnummer 070 123 45 67"], ["kontakt", "Mejl elin.k@gmail.com"], ["kontakt", "Instagram lisa_2009"],
  ["pengar", "Har 2000 kr på kortet"], ["plats", "Bor i Rinkeby"],
];
const KEEP = [
  "Har prov i biologi på fredag", "Gillar korta svar", "Går i årskurs 9", "Läser religionskunskap", "Spelar fotboll",
  "Vill bli läkare", "Pluggar till högskoleprovet", "Vill ha exempel med fotboll", "Har svårt med bråk",
  "Har lånat en bok om rymden", "Gillar sjukt mycket fotboll", "Skriver en uppsats om brottslighet i Sverige",
  "Läser om kristendomen i religion", "Har prov i historia om judeförföljelsen", "Vill ha svar på engelska",
  "Ska till Gotland i sommar", "Läser kursen sex och samlevnad", "Gillar att laga mat", "Har prov om partiklar",
  "Tränar på hälsning på spanska",
];
const kept = (item) => !sensitive(item.replace(/\s+/g, " ").trim());
const drop = DROP.map(([c, t]) => ({ c, t, kept: kept(t), ok: !kept(t) }));
const keep = KEEP.map((t) => ({ t, kept: kept(t), ok: kept(t) }));
const s = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ sensitive_dropped: s(drop), ordinary_kept: s(keep), fails: [...drop, ...keep].filter((x) => !x.ok), drop, keep }, null, 1));
