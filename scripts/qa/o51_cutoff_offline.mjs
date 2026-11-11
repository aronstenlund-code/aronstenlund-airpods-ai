// Oscar QA, O51: Kevin's standing round 15 (answer/handler.ts isCutOff, Toby T14): in Auto a question ending on a word
// that needs more becomes silent. NEW independent cases (none in k_standing7_test.ts): really cut off (should be
// silent) and COMPLETE questions that happen to end on such a word (Scribe often drops the "?"), which must be answered.
// Loads only isCutOff's lines from handler.ts (it imports npm:). Offline, 0 USD.
//   node --experimental-strip-types --no-warnings scripts/qa/o51_cutoff_offline.mjs > reports/qa/data/<stamp>-o51.json
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const src = readFileSync(new URL("../../backend/supabase/functions/answer/handler.ts", import.meta.url), "utf8");
const a = src.indexOf("const DANGLING"), b = src.indexOf("/** K1.4: the new check question");
if (a < 0 || b < a) throw new Error("isCutOff moved: update o51_cutoff_offline.mjs");
const tmp = join(mkdtempSync(join(tmpdir(), "o51-")), "cut.ts");
writeFileSync(tmp, src.slice(a, b).replace("export function isCutOff", "export function isCutOff"));
const { isCutOff } = await import(tmp);

const CUT = [ // really cut off: silent is right
  "hur många invånare har Sverige och", "vem var det som", "kan du förklara vad en", "hur fungerar en", "varför är det så att",
  "hur lång är", "är det sant att", "vilken av dem är", "vad hette kungen som", "hur mycket väger ett",
  "vad är huvudstaden i", "när började det andra", "vilken är den största", "vad heter Sveriges", "hur många ben har en spindel och",
  "hur vet man vilken", "vad är det för väder som", "vad är en",
];
const FULL = [ // complete questions without "?": must NOT be silent
  "vad tror du att svaret är", "hur gammal tror du att jag är", "vem tror du att mördaren är", "vad tror du det blir",
  "hur svårt tror du provet blir", "hur många katter tror du att hon har", "vad betyder ordet och",
  "vad är skillnaden mellan som och att", "kan du ge exempel på en mening med som", "vad heter det på engelska när man säger än",
  "vilken månad är det", "var ligger Mälaren",
];
const cut = CUT.map((t) => ({ t, cut: isCutOff(t), ok: isCutOff(t) }));
const full = FULL.map((t) => ({ t, cut: isCutOff(t), ok: !isCutOff(t) }));
const s = (x) => `${x.filter((r) => r.ok).length}/${x.length}`;
console.log(JSON.stringify({ cut_silent: s(cut), full_answered: s(full), missed_cut: cut.filter((r) => !r.ok).map((r) => r.t),
  false_cut: full.filter((r) => !r.ok).map((r) => r.t), cut, full }, null, 1));
