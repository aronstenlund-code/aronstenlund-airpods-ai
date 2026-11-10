// Oscar QA, O37: K34 retest of the memory guard (D113/D114 B5: only health, crisis and ID numbers are not saved) with
// NEW cases (none in O28 or O36). Reads the two regex literals from the deployed memory/handler.ts (it imports npm:,
// so it cannot be imported in Node). Free.  node scripts/qa/o37_b5_memory_offline.mjs > reports/qa/data/<stamp>-o37.json
// If K34 replaces the regexes with another check, the script reports "check not found" instead of guessing.
import { readFileSync } from "node:fs";

const SRC = readFileSync(new URL("../../backend/supabase/functions/memory/handler.ts", import.meta.url), "utf8");
const lit = (name) => { const m = new RegExp(String.raw`const ${name} =\s*\/(.+)\/([a-z]*);`).exec(SRC); return m ? new RegExp(m[1], m[2]) : null; };
const SR = lit("SENSITIVE_RAW"), SW = lit("STUDY_WORDS");
const sens = (t) => (SR ? SR.test(t.replace(SW ?? /$^/, " ")) : null);

const DROP = [ // health, crisis, ID numbers: must not be saved
  "Har typ 1-diabetes", "Äter antidepressiva", "Har ätstörningar", "Har ADHD-medicin på morgonen", "Har astma och använder inhalator",
  "Vill inte leva ibland", "Har försökt ta livet av sig förra året", "Skär sig när det blir jobbigt", "Har panikångest inför prov",
  "Opererades för blindtarmen i somras", "Är gravid", "Har cancer", "Personnummer 20090521-4417", "Har passnummer AA1234567",
];
const KEEP = [ // study and everyday facts: must be saved (A5: religion, politics etc. are no restriction)
  "Pluggar till provet om cellandning", "Har fått A i matte", "Läser om andra världskriget", "Går i 9B", "Spelar fotboll på tisdagar",
  "Är muslim", "Gillar Vänsterpartiets skolpolitik", "Har prov om sjukdomar i biologi", "Skriver om depression som tema i svenskan",
  "Vill bli läkare", "Gillar att läsa om hjärnan",
];
const rows = [...DROP.map((t) => ({ t, want: "drop", sens: sens(t), ok: sens(t) === true })), ...KEEP.map((t) => ({ t, want: "keep", sens: sens(t), ok: sens(t) === false }))];
const n = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ check_found: !!SR, sum_drop: n(rows.filter((r) => r.want === "drop")), sum_keep: n(rows.filter((r) => r.want === "keep")),
  fails: rows.filter((r) => !r.ok), rows }, null, 1));
