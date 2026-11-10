// Oscar QA, O26: how the answer pipeline reads numbers aloud (answer/speech.ts toSpeech = beforeNumbers ->
// numbersToSpeech -> afterNumbers), offline and free in Node 24 with the deployed files. Kevin's K4 loop (78c10f5:
// 'en 5:a' = en femma, fractions in words) plus how model answers for students actually write numbers: grades,
// fractions vs dates (6/6), decimals, money, scores, ranges, units, formulas, ordinals, gender.
// Graded: spoken text has no digits left, contains one of the accepted forms (|), and none of the forbidden ones.
//   node --experimental-transform-types scripts/qa/o26_numbers_offline.mjs > reports/qa/data/<stamp>-o26-numbers.json
import { toSpeech } from "../../backend/supabase/functions/answer/speech.ts";

const C = [ // [model text, accepted spoken forms (any, | separated), forbidden (| separated) or ""]
  ["Du fick en 5:a på provet.", "en femma", ""],
  ["Hon fick en 2:a i matte.", "en tvåa", ""],
  ["Han kom 2:a i loppet.", "kom tvåa|kom på andra", ""],
  ["Sverige kom på 3:e plats.", "tredje plats", ""],
  ["1:a världskriget började 1914.", "första världskriget", ""],
  ["Det var hennes 21:a födelsedag.", "tjugoförsta", ""],
  ["3/4 av eleverna klarade det.", "tre fjärdedelar", ""],
  ["Ungefär 1/3 av klassen var sjuk.", "en tredjedel", ""],
  ["Blanda 1 1/2 dl mjöl.", "en och en halv deciliter", ""],
  ["Tillsätt ½ tsk salt.", "en halv tesked", ""],
  ["7/12 är mer än hälften.", "sju tolftedelar", ""],
  ["Nationaldagen firas 6/6.", "sjätte juni|sjätte i sjätte", "sjättedelar"],
  ["Valborg firas 30/4.", "trettionde april|trettionde i fjärde", "fjärdedelar"],
  ["Pi är ungefär 3,14.", "tre komma ett fyra|tre komma fjorton", ""],
  ["Drick 0,5 liter vatten.", "noll komma fem liter|en halv liter", ""],
  ["Det var -5 grader i natt.", "minus fem grader", ""],
  ["Staden har 1 000 000 invånare.", "en miljon", ""],
  ["Det kostar 10 000 kr.", "tiotusen kronor", ""],
  ["Biljetten kostar 12,50 kr.", "tolv kronor och femtio öre|tolv och femtio|tolv komma femtio kronor", ""],
  ["Gustav Vasa blev kung 1523.", "femtonhundratjugotre", ""],
  ["Det hände på 1990-talet.", "nittonhundranittiotalet", ""],
  ["Första världskriget pågick 1914–1918.", "nittonhundrafjorton till nittonhundraarton", ""],
  ["Ungefär 25 % av alla röstade.", "tjugofem procent", ""],
  ["Lektionen börjar kl. 14.30.", "klockan fjorton och trettio|klockan halv tre|klockan fjorton trettio", ""],
  ["Midsommar är den 20 juni i år.", "tjugonde juni", ""],
  ["Sverige vann med 3–1.", "tre mot ett|tre–ett|tre ett", ""],
  ["Bilen körde 50 km/h.", "femtio kilometer i timmen|femtio kilometer per timme", ""],
  ["Tyngdaccelerationen är 9,82 m/s².", "meter per sekundkvadrat|meter per sekund i kvadrat", ""],
  ["Arean är x² + 2x.", "x i kvadrat|x två", ""],
  ["Lös 2x + 3 = 7.", "två x plus tre", ""],
  ["Läs kapitel 3 till sidan 42.", "kapitel tre|sidan fyrtiotvå", ""],
  ["Hon har 1 bok och 1 äpple.", "en bok", "ett bok"],
  ["Han har 1 äpple.", "ett äpple", "en äpple"],
  ["Köp 3 st ägg.", "tre stycken|tre ägg", ""],
  ["Spår nr 7 avgår snart.", "nummer sju", ""],
  ["Det var ca 8 000 f.Kr.", "åttatusen före kristus", ""],
  ["Ring 112 om det är akut.", "ett ett två", ""],
  ["Hon fick 4,5 av 5 i betyg.", "fyra komma fem av fem", ""],
  ["Vattnet kokar vid 100 °C.", "hundra grader", ""],
  ["Det är 2,5 miljoner kvadratkilometer.", "två komma fem miljoner|två och en halv miljon", ""],
  ["Svaret är 0,25, alltså 1/4.", "en fjärdedel", ""],
  ["Hälften av 18 är 9.", "arton|nio", ""],
  ["Erik fick 14 poäng och Johan 12 poäng.", "fjorton poäng", "den fjortonde|den tolfte"],
  ["Han sprang 100 m på 11,2 sekunder.", "hundra meter|elva komma två sekunder", ""],
  ["Mobilnumret står på 070-123 45 67.", "", "noll sju noll"],
];
const rows = C.map(([t, acc, bad]) => {
  const out = toSpeech(t);
  const digits = /\d/.test(out);
  const hasAcc = !acc || acc.split("|").some((a) => out.toLowerCase().includes(a));
  const hasBad = !!bad && bad.split("|").some((b) => out.toLowerCase().includes(b));
  return { t, out, digits_left: digits, accepted: hasAcc, forbidden: hasBad, ok: !digits && hasAcc && !hasBad };
});
console.log(JSON.stringify({ n: rows.length, ok: rows.filter((r) => r.ok).length, fails: rows.filter((r) => !r.ok), rows }, null, 1));
