// K74: the voice text's rule table. Constructed cases, then 203 real answers from O63/O64 (testdata/voice).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { longVoice, voiceText } from "./handler.ts";
import { polishVoice, splitLong, VOICE_RULES } from "./voicerules.ts";
import { examLanguage } from "../exam/drill.ts";
import { textLanguage } from "../exam/read.ts";

const SV: [string, string][] = [
  ["Läs kap. 3 och s. 12.", "Läs kapitel tre och sidan tolv."],
  ["Det gäller fr.o.m. måndag t.o.m. fredag.", "Det gäller från och med måndag till och med fredag."],
  ["Han/hon ska välja och/eller rösta.", "Han eller hon ska välja och eller rösta."],
  ["Fotosyntesen (som sker i bladen) ger socker.", "Fotosyntesen, som sker i bladen, ger socker."],
  ["Växten bildar socker (glukos).", "Växten bildar socker, glukos."],
  ['Han sa "vi ses" och gick.', "Han sa vi ses och gick."],
  ["Hon kallade det ”den fjärde statsmakten”.", "Hon kallade det den fjärde statsmakten."],
  ["Svaret är ~40 km.", "Svaret är ungefär fyrtio kilometer."],
  ["Se punkterna: • luft • vatten • ljus", "Se punkterna: luft, vatten, ljus"],
  ["Jfr kapitel 2.", "Jämför kapitel två."],
  ["Ca 300 st. elever kom.", "Cirka trehundra stycken elever kom."],
  ["Obs! Det här är viktigt.", "Observera! Det här är viktigt."],
  ["Inkl. moms blir det 125 kr.", "Inklusive moms blir det hundratjugofem kronor."],
  ["Vattnet kokar vid 100 °C.", "Vattnet kokar vid hundra grader celsius."],
  ["Kol → koldioxid.", "Kol ger koldioxid."],
  ["Gustav Vasa valdes 1523.", "Gustav Vasa valdes femtonhundratjugotre."],
  ["Värdet är 3,5.", "Värdet är tre komma fem."],
  ["Järn, zink etc. finns i jorden.", "Järn, zink etcetera finns i jorden."],
];
const EN: [string, string][] = [
  ["Use salt, e.g. sea salt, i.e. coarse salt.", "Use salt, for example sea salt, that is coarse salt."],
  ["Cats vs. dogs.", "Cats versus dogs."],
  ["It costs ~40 dollars.", "It costs about 40 dollars."],
  ['He/she said "yes".', "He or she said yes."],
  ["Water boils at 100 °C.", "Water boils at 100 degrees Celsius."],
  ["It was built in 1952.", "It was built in 1952."],
  ["The value is 3.5 (roughly).", "The value is 3.5, roughly."],
];

Deno.test("K74 the rule table: Swedish", () => {
  for (const [a, b] of SV) assertEquals(voiceText(a, "", 2), b, a);
});
Deno.test("K74 the rule table: English (digits stay digits, D182)", () => {
  for (const [a, b] of EN) assertEquals(voiceText(a, "English", 2), b, a);
});
Deno.test("K74 version 1 is the text before K74 (old drills keep their hashes)", () => {
  assertEquals(voiceText("Fotosyntesen (som sker i bladen) ger socker.", "", 1), "Fotosyntesen (som sker i bladen) ger socker.");
  assertEquals(voiceText('He/she said "yes".', "English", 1), 'He/she said "yes".');
  assertEquals(voiceText("Fotosyntesen ger socker."), "Fotosyntesen ger socker.", "the default is version 1");
});
Deno.test("K74 a sentence over 30 words is cut where it breathes", () => {
  const s = "Många väljare kan bli tveksamma till att rösta på ett litet parti, eftersom de är rädda att rösten går förlorad, och det kan göra det ännu svårare för partiet att komma in i riksdagen nästa gång.";
  const parts = splitLong(s, "sv");
  assert(parts.length >= 2, JSON.stringify(parts));
  assert(parts.every((p) => p.split(/\s+/).length <= 30));
  assert(parts.every((p) => /[.!?]$/.test(p)));
  assertEquals(splitLong("En kort mening.", "sv"), ["En kort mening."]);
  assertEquals(polishVoice("Kort. Också kort."), "Kort. Också kort.");
});
Deno.test("K74 every rule has a kind and a language", () => {
  assert(VOICE_RULES.length >= 40);
  for (const k of ["abbreviation", "parenthesis", "slash", "list", "symbol", "quote", "space"]) assert(VOICE_RULES.some((r) => r.kind === k), k);
});

Deno.test("K74 203 real answers (O63/O64): no brackets, quotes, word slashes or sentences over 30 words; no word lost", () => {
  const items = JSON.parse(Deno.readTextFileSync(new URL("../../../testdata/voice/o63-o64-answers.json", import.meta.url))) as
    { subject: string; question: string; short: string; long: string }[];
  assert(items.length >= 40);
  let changed = 0;
  const letters = (t: string) => (t.toLowerCase().match(/\p{L}{3,}/gu) ?? []).filter((w) => !["och", "and", "eller", "beror", "att", "det", "that", "because"].includes(w));
  for (const it of items) {
    const lang = examLanguage(it.subject) || textLanguage(`${it.question} ${it.long}`, it.subject);
    for (const [v1, v2] of [[voiceText(it.question, lang, 1), voiceText(it.question, lang, 2)], [longVoice(it.short, it.long, lang, 1).text, longVoice(it.short, it.long, lang, 2).text]]) {
      if (v1 !== v2) changed++;
      assert(!/[()[\]"“”„«»]/.test(v2), v2);
      assert(!/\p{L}\/\p{L}/u.test(v2), v2);
      for (const s of v2.split(/(?<=[.!?])\s+/)) assert(s.split(/\s+/).length <= 30, `${s.split(/\s+/).length} words: ${s}`);
      // nothing said before is lost (only abbreviations become words and marks go)
      const after = new Set(letters(v2));
      const lost = letters(v1).filter((w) => !after.has(w) && !/^(?:ca|kap|obs|inkl|exkl|jfr|etc|vs|approx)$/.test(w));
      assertEquals(lost, [], `${v1}\n${v2}`);
    }
  }
  console.log(`K74: ${items.length} answers, ${changed} voice texts changed by version 2`);
});

Deno.test("K74 the v4 pause tag goes in front of the long answer and moves the short answer's end", async () => {
  const { withPauseTag, V4_PAUSE_TAG } = await import("./voicerules.ts");
  const l = longVoice("Klorofyll fångar ljus.", "Klorofyll fångar ljus. Det ger energi.", "", 2);
  const t = withPauseTag(l.text, l.shortChars);
  assert(t.text.startsWith(`${V4_PAUSE_TAG} Klorofyll`));
  assertEquals(t.text.slice(0, t.shortChars), `${V4_PAUSE_TAG} Klorofyll fångar ljus.`);
});

Deno.test("K74 the A/B texts in testdata match the code (scripts/k74-ab-texts.ts)", async () => {
  const { abTexts } = await import("../../../scripts/k74-ab-texts.ts");
  const file = JSON.parse(Deno.readTextFileSync(new URL("../../../testdata/voice/k74-ab-texts.json", import.meta.url)));
  assertEquals(file, abTexts());
  const total = file.items.reduce((n: number, i: { plain: string; tagged: string }) => n + 2 * i.plain.length + i.tagged.length, 0);
  assert(total > 2500 && total <= 3200, String(total));
});

// ---------- K75 (Oscar O68): version 3 ----------
Deno.test("K75 version 3: abbreviations, < >, numbered lists, w/, formulas, units, semicolons, a final stop", () => {
  const SV3: [string, string][] = [
    ["Enl. kap. 4 skrivs det så (se fig. 3).", "Enligt kapitel fyra skrivs det så, se figur tre."],
    ["Det är 15 milj. grader och 4 ggr varmare.", "Det är femton miljoner grader och fyra gånger varmare."],
    ["De bor i Sthlm, Gbg och Malmö.", "De bor i Stockholm, Göteborg och Malmö."],
    ["pH < 7 är surt och pH > 7 basiskt.", "pH är mindre än sju är surt och pH är större än sju basiskt."],
    ["Två argument: 1) tonåringar sover mer, 2) de lär sig bättre.", "Två argument: tonåringar sover mer, de lär sig bättre."],
    ["CH4 + 2O2 → CO2 + 2H2O", "Metan plus två syre ger koldioxid plus två vatten."],
    ["Hemoglobinet binder O2 i lungorna.", "Hemoglobinet binder syre i lungorna."],
    ["Kraften är 10 N och temperaturen 5800 K.", "Kraften är tio newton och temperaturen femtusen åttahundra kelvin."],
    ["Ett kylskåp drar 2 kWh/dag.", "Ett kylskåp drar två kilowattimmar per dag."],
    ["Det är surt; det är basiskt", "Det är surt. Det är basiskt."],
    ["Den upprepas i slutet m.m.", "Den upprepas i slutet med mera."],
  ];
  for (const [a, b] of SV3) assertEquals(voiceText(a, "", 3), b, a);
  const EN3: [string, string][] = [
    ["He climbed with a lamp w/ a friend at 3 a.m.", "He climbed with a lamp with a friend at 3 a m."],
    ["It is 100 ft tall and flashes every 5 sec.", "It is 100 feet tall and flashes every 5 seconds."],
    ["CO2 and CH4 trap heat.", "Carbon dioxide and methane trap heat."],
    ["It can be seen 20+ km away.", "It can be seen more than 20 kilometres away."],
    ["More gases → the Earth gets warmer.", "More gases, so the Earth gets warmer."],
  ];
  for (const [a, b] of EN3) assertEquals(voiceText(a, "English", 3), b, a);
  // version 2 is unchanged by version 3 rules
  assertEquals(voiceText("pH < 7 är surt.", "", 2), "pH < sju är surt.");
});

Deno.test("K75 Oscar's 20 edited answers (O68): none of his findings left in version 3", () => {
  const d = JSON.parse(Deno.readTextFileSync(new URL("../../../testdata/voice/o68-edited.json", import.meta.url)));
  const items = d.items as { subject: string; question: string; short: string; long: string }[];
  assertEquals(items.length, 20);
  const BAD = /(?<![\p{L}])(?:enl\.|fig\.|milj\.|ggr|Sthlm|Gbg|Ex:|ft|sec|se ha fyra|o två|ett\)|två\)|w divided by)(?![\p{L}])|[<>→;]|\b(?:CO2|CH4|O2|H2O)\b|(?:tio|hundra) [NK](?![\p{L}])|eller dag/u;
  for (const it of items) {
    const lang = examLanguage(it.subject);
    for (const t of [voiceText(it.question, lang, 3), longVoice(it.short, it.long, lang, 3).text]) {
      assert(!BAD.test(t), t);
      assert(/[.!?:]$/.test(t), `ends with a stop: ${t}`);
    }
  }
});
