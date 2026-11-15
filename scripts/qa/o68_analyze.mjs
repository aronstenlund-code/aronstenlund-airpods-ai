// O68 (Oscar moln, 2026-11-15): uppläsningstexten för långa svar, räknad med serverns egen kod.
// node scripts/qa/o68_analyze.mjs <voice.mjs> <items.json>
// voice.mjs = esbuild-bunt av backend (voiceText, longVoice, examLanguage), se oscar-live.yml.
// Räknar per svar: förkortningar, enheter, symboler, parenteser, listor, siffror (svenska), meningar över 30 ord,
// ord som inte uttalas som de stavas (versalförkortningar, bokstav+siffra). Skriver <items>-analysis.json och de 15 värsta.
import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";

const [voicePath, itemsPath] = process.argv.slice(2);
const V = await import(new URL(voicePath, `file://${process.cwd()}/`).href);
const data = JSON.parse(readFileSync(itemsPath, "utf8"));
// K74 (D196): regelversionen per prov; nya prov får 2. O68_RULES=1 ger texten från före K74.
const RULES = Number(process.env.O68_RULES ?? 2);

const ABBR = /(?<![\p{L}])(t\.ex\.?|bl\.a\.?|m\.m\.?|s\.k\.?|d\.v\.s\.?|dvs\.?|osv\.?|etc\.?|ca\.?|cirka\.(?=\s\p{Ll})|kap\.|nr\.?|jfr\.?|enl\.|fig\.|tab\.|resp\.|st\.|f\.d\.?|e\.Kr\.?|f\.Kr\.?|e\.g\.|i\.e\.|vs\.?|approx\.|p\.|pp\.|ex\.|ex:|milj\.|mdr\.|ggr|sthlm|gbg|ft|sec|yrs|w\/|a\.m\.|p\.m\.|kr\.?)(?![\p{L}])/giu;
const DOT_LOWER = /(?<![\p{L}])\p{L}{1,4}\.(?=\s+\p{Ll})/gu; // "enl. boken": en punkt före liten bokstav = förkortning
// en enhet räknas bara direkt efter ett tal (siffra eller räkneord), så variabler som "m gånger a" inte räknas
const UNIT = /(?:\p{N}|noll|en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|tio|elva|tolv|tton|tjugo|ttio|hundra|tusen|halv|miljon|miljoner)\s+(km|cm|mm|dm|kg|mg|ml|dl|cl|kWh|kW|MW|Wh|mph|kmh|m\/s|km\/h|Pa|kPa|hPa|mol|Hz|kHz|N|J|W|V|A|K|g|m|s|h|l)(?![\p{L}])/gu;
const SYMBOL = /[%‰°→←↔⇒=±~≈<>≤≥×÷·*^#&@§€$£²³_|\\[\]{}√∑∆Δπ∞]|(?<=\p{N})[–-](?=\p{N})/gu;
const PAREN = /[()]/g;
const LIST = /(^|\n)\s*([-•*–]|\d+[.)])\s|(?<![\p{L}\p{N}])[a-c1-9]\)\s|;\s/gu;
const DIGIT = /\p{N}/gu;
const ACRONYM = /(?<![\p{L}])[A-ZÅÄÖ]{2,}(?![\p{L}])/gu;
const LETTER_DIGIT = /(?<![\p{L}\p{N}])(?=[\p{L}\p{N}]*\p{L})(?=[\p{L}\p{N}]*\p{N})[\p{L}\p{N}]{2,}(?![\p{L}\p{N}])/gu;
// en kemisk formel i det skrivna svaret (CO2, H2O, CH4): rösten säger "se o två"
const CHEM = /(?<![\p{L}\p{N}])(?:[A-Z][a-z]?\d{0,2}){1,4}(?<=\d)(?![\p{L}\p{N}])/gu;
const W = { abbr: 3, unit: 2, symbol: 3, paren: 2, list: 2, digit: 1, long_sentence: 2, pronounce: 2 };

const sentences = (t) => t.split(/(?<=[.!?…])\s+(?=["“«(]?[\p{Lu}\p{N}])/u).filter(Boolean);
const uniq = (a) => [...new Set(a)];

const rows = [];
for (const it of data.items) {
  const lang = V.examLanguage(it.subject);
  const spoken = V.longVoice(it.short, it.long, lang, RULES).text;
  const sv = !lang;
  const hits = {
    abbr: (() => { const a = spoken.match(ABBR) ?? []; return uniq([...a, ...(spoken.match(DOT_LOWER) ?? []).filter((d) => !a.some((x) => x.endsWith(d)))]); })(),
    unit: sv ? uniq([...spoken.matchAll(UNIT)].map((m) => m[1])) : [],
    symbol: uniq(spoken.match(SYMBOL) ?? []),
    paren: (spoken.match(PAREN) ?? []).length ? ["( )"] : [],
    list: uniq((spoken.match(LIST) ?? []).map((x) => x.trim() || "radbrytning")),
    digit: sv ? uniq(spoken.match(/[\p{N}][\p{N},.]*/gu) ?? []) : [],
    long_sentence: sentences(spoken).filter((s) => s.split(/\s+/).length > 30).map((s) => `${s.split(/\s+/).length} ord: ${s.slice(0, 80)}…`),
    pronounce: (() => { const ld = spoken.match(LETTER_DIGIT) ?? []; return uniq([...ld, ...(spoken.match(ACRONYM) ?? []).filter((a) => !ld.some((x) => x.includes(a))), ...(it.long.match(CHEM) ?? []).map((c) => `formel ${c}`)]); })(),
  };
  const score = Object.entries(hits).reduce((n, [k, v]) => n + W[k] * v.length, 0);
  rows.push({ eid: it.eid, subject: it.subject, lang: lang || "sv", question: it.question, long: it.long, spoken,
    md5: createHash("md5").update(spoken).digest("hex"), score, hits });
}

const cats = Object.keys(W);
const per = Object.fromEntries(cats.map((c) => [c, rows.filter((r) => r.hits[c].length).length]));
const bySubject = {};
for (const r of rows) bySubject[r.subject] = (bySubject[r.subject] ?? 0) + 1;
const worst = [...rows].sort((a, b) => b.score - a.score).slice(0, 15);
const summary = { answers: rows.length, by_subject: bySubject, answers_with: per, clean: rows.filter((r) => r.score === 0).length };
writeFileSync(itemsPath.replace(/\.json$/, "-analysis.json"), JSON.stringify({ summary, worst, rows }, null, 1));
console.log(`=== O68 uppläsningstexten (regler v${RULES})`, JSON.stringify(summary));
worst.forEach((r, i) => {
  const h = Object.entries(r.hits).filter(([, v]) => v.length).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join(" | ");
  console.log(`\n#${i + 1} poäng ${r.score} | ${r.eid} (${r.subject}) | ${r.question}\n  FYND ${h}\n  RÖSTEN ${JSON.stringify(r.spoken)}`);
});
console.log("\nmd5 för SQL-jämförelse (första 20):", JSON.stringify(rows.slice(0, 20).map((r) => r.md5)));
