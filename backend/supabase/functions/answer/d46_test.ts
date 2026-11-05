import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { cardinal, numbersToSpeech, ordinal, wordsToNumber } from "./svnum.ts";
import { computeFragment } from "./calc.ts";
import { AnswerPost, DupGuard, NumberStream, QuestionTrim } from "./speech.ts";
import {
  buildDirectUserMessage,
  SYSTEM_PROMPT_DIRECT_FACT,
  SYSTEM_PROMPT_DIRECT_TUTOR,
} from "./prompt.ts";
import { validateAnswerRequest } from "./validate.ts";
import { classifyAnswerType } from "./length.ts";

Deno.test("numbers: cardinals, years, decimals, percent, units, times, dates", () => {
  const t = numbersToSpeech;
  assertEquals(t("17 gånger 24 är 408."), "sjutton gånger tjugofyra är fyrahundraåtta.");
  assertEquals(t("Revolutionen började 1789."), "Revolutionen började sjuttonhundraåttionio.");
  assertEquals(t("Hon föddes 1905 och 2025."), "Hon föddes nittonhundrafem och tvåtusen tjugofem.");
  assertEquals(t("2,5 liter är 2500 ml."), "två komma fem liter är tvåtusen femhundra milliliter.");
  assertEquals(t("12 % av 250"), "tolv procent av tvåhundrafemtio");
  assertEquals(
    t("50 km/h och 37,5 °C"),
    "femtio kilometer i timmen och trettiosju komma fem grader celsius",
  );
  assertEquals(t("Klockan 14:30, den 3:e."), "Klockan fjorton trettio, den tredje.");
  assertEquals(
    t("1 liter och 21 personer och 1 barn"),
    "en liter och tjugoen personer och ett barn",
  );
  assertEquals(t("5-10 minuter"), "fem till tio minuter");
  assertEquals(t("1 500 kr, 2 000 000 kr"), "femtonhundra kronor, två miljoner kronor");
  assertEquals(t("2026-11-04"), "den fjärde november tvåtusen tjugosex");
  assertEquals(t("H2O och CO2 utan siffror: tre"), "H2O och CO2 utan siffror: tre");
  assertEquals(t("På 1800-talet och 90-talet"), "På artonhundratalet och nittiotalet");
  assertEquals(cardinal(2500), "tvåtusen femhundra");
  assertEquals(cardinal(101), "hundraett");
  assertEquals(ordinal(21), "tjugoförsta");
  assertEquals(wordsToNumber("fyrahundraåtta"), 408);
  assertEquals(wordsToNumber("tre tusen femhundra"), 3500);
  assertEquals(wordsToNumber("katt"), null);
});

Deno.test("calc: arithmetic, percent, units are computed in code; everything else is null", () => {
  const c = (s: string) => computeFragment(s)?.text ?? null;
  assertEquals(c("17 gånger 24"), "17 × 24 = 408");
  assertEquals(c("tolv gånger åtta"), "12 × 8 = 96");
  assertEquals(c("hundra delat med fyra"), "100 ÷ 4 = 25");
  assertEquals(c("12 procent av 250"), "12 % av 250 = 30");
  assertEquals(c("tjugofem procent av tvåhundra"), "25 % av 200 = 50");
  assertEquals(c("2,5 liter i ml"), "2,5 liter = 2500 milliliter");
  assertEquals(c("hur många gram är 2 kg"), "2 kilogram = 2000 gram");
  assertEquals(c("vad är 15 plus 27?"), "15 + 27 = 42");
  assertEquals(c("2 + 3 * 4"), "2 + 3 × 4 = 14");
  assertEquals(c("sju i kvadrat"), "7² = 49");
  assertEquals(c("roten ur 144"), "√144 = 12");
  assertEquals(c("100/3"), "100 ÷ 3 = 33,3333 (avrundat till fyra decimaler)");
  assertEquals(c("37,5 c till f"), "37,5 °C = 99,5 °F");
  for (
    const no of [
      "fotosyntes",
      "12",
      "när började andra världskriget",
      "vad är 5 procent av världens befolkning",
      "derivatan av x i kvadrat",
      "hon svarade bara vi får se",
    ]
  ) {
    assertEquals(c(no), null, no);
  }
});

function run(
  text: string,
  chunk: number,
  opts = { previousAnswers: [] as string[], trimQuestion: true },
) {
  const p = new AnswerPost(opts);
  let out = "";
  for (let i = 0; i < text.length; i += chunk) out += p.push(text.slice(i, i + chunk));
  out += p.finish();
  return { out, p };
}

Deno.test("speech: digits become words regardless of chunking; closing question is dropped", () => {
  for (const chunk of [1, 3, 7, 100]) {
    assertEquals(
      run("17 gånger 24 är 408. Vill du ha mer?", chunk).out,
      "Sjutton gånger tjugofyra är fyrahundraåtta. ",
    );
    assertEquals(
      run("Ta 2,5 dl havregryn. Koka 5 minuter.", chunk).out,
      "Ta två komma fem deciliter havregryn. Koka fem minuter.",
    );
  }
  // a question inside the answer stays, only the closing one goes
  assertEquals(
    run("Hur mår du? Jag mår bra. Och sedan?", 4).out.trim(),
    "Hur mår du? Jag mår bra. Och sedan?",
  );
  assertEquals(
    run("Det går bra. Vill du att jag hjälper dig? Annars säg till.", 5).out.trim(),
    "Det går bra. Vill du att jag hjälper dig? Annars säg till.",
  );
  // tutoring keeps its check question
  assertEquals(
    run("Svaret är fyra. Vill du ha mer?", 4, { previousAnswers: [], trimQuestion: false }).out,
    "Svaret är fyra. Vill du ha mer?",
  );
  // an answer that is only a question is reported
  const only = run("Vill du ha ett recept?", 3);
  assertEquals([only.out, only.p.questionOnly], ["", true]);
});

Deno.test("speech: a repeated earlier answer is detected before anything is sent", () => {
  const prev =
    "Franska revolutionen började 1789 och förändrade Europa för alltid med nya idéer om frihet.";
  const g = new DupGuard([prev]);
  let sent = "";
  for (
    const part of ["Franska ", "revolutionen bör", "jade 1789 och förändr", "ade Europa för alltid"]
  ) sent += g.push(part);
  assertEquals([g.tripped, sent, g.matched], [true, "", prev]);
  const ok = new DupGuard([prev]);
  let out = "";
  for (const part of ["Bankkortet ", "kan du spärra ", "direkt hos banken."]) out += ok.push(part);
  out += ok.finish();
  assertEquals([ok.tripped, out], [false, "Bankkortet kan du spärra direkt hos banken."]);
  // a short reply that simply ends early is released, not lost
  const short = new DupGuard([prev]);
  assertEquals(short.push("Franska") + short.finish(), "Franska");
});

Deno.test("speech: NumberStream and QuestionTrim never lose text", () => {
  const n = new NumberStream();
  let o = "";
  for (const ch of "Det var 1 789 och 12 %.") o += n.push(ch);
  assertEquals(o + n.finish(), "Det var sjuttonhundraåttionio och tolv procent.");
  const q = new QuestionTrim(true);
  assertEquals(q.push("Vad som hände var stort. ") + q.finish(), "Vad som hände var stort. ");
});

Deno.test("prompt: digits rule, computed + active_topic tags, behaviour rules, tutor exception", () => {
  for (const p of [SYSTEM_PROMPT_DIRECT_FACT, SYSTEM_PROMPT_DIRECT_TUTOR]) {
    assertStringIncludes(p, "as DIGITS");
    assertStringIncludes(p, "Never correct yourself");
    assertStringIncludes(p, "never to an older turn");
    assertStringIncludes(p, "<computed>");
    assertStringIncludes(p, "aimed at you");
    assertStringIncludes(p, "quantities and every step");
    assertStringIncludes(p, "only what the user gave");
    assertStringIncludes(p, "ONLY the translation");
  }
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_FACT, "Never end with a question");
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_TUTOR, "Apart from the one check question");
  const req = validateAnswerRequest({
    fragment: "varför då?",
    mode: "push_to_talk",
    language: "sv",
    context: {
      recent_qa: [{ q: "franska revolutionen", a: "Den började 1789." }, {
        q: "hungrig ägg pasta",
        a: "Koka pastan.",
      }],
    },
  });
  const m = buildDirectUserMessage(req, null, { computed: "17 × 24 = 408", note: "retry" });
  assertStringIncludes(m, "<active_topic>hungrig ägg pasta</active_topic>");
  assertStringIncludes(m, "<computed>17 × 24 = 408</computed>");
  assertStringIncludes(m, "<note>retry</note>");
  assert(m.indexOf("<computed>") < m.indexOf("<fragment>"));
});

Deno.test("length: practical intents get a developed answer", () => {
  for (const f of ["recept på havregrynsgröt", "hur lagar man ris", "plan för att packa"]) {
    assertEquals(classifyAnswerType(f, "adaptive", null), "study", f);
  }
  assertEquals(classifyAnswerType("17 gånger 24", "adaptive", null), "fact");
});

import {
  buildSocialLineUserMessage,
  isRewriteCommand,
  isSocialInput,
  lastLine,
  socialTask,
  SYSTEM_PROMPT_SOCIALLINE,
} from "./socialroute.ts";
import { buildPersonaUserMessage, personaPlan } from "./personas.ts";

Deno.test("social routing: situation fragments get a ready-to-say line in every explicit mode", () => {
  for (
    const f of [
      "hon skrev hej",
      "vad svarar jag på haha aa",
      "ge mig en bra komplimang",
      "hon sa nej",
      "hon har inte svarat på hela dagen",
      "hur börjar jag snacka med en tjej i klassen",
      "hon sa vi får se",
      "skriv något som ger henne dåligt samvete för att hon inte svarar",
      "han ignorerar mig",
    ]
  ) {
    assertEquals(isSocialInput(f), true, f);
  }
  for (
    const f of [
      "han skrev Hamlet",
      "vem var han som skrev romanen",
      "när började andra världskriget",
      "hon sa att teorin stämmer",
      "fotosyntes",
      "17 gånger 24",
      "kortare",
    ]
  ) {
    assertEquals(isSocialInput(f), false, f);
  }
  const req = (fragment: string, qa: { q: string; a: string }[] = [], mode = "push_to_talk") =>
    validateAnswerRequest({ fragment, mode, language: "sv", context: { recent_qa: qa } });
  assertEquals(socialTask(req("hon skrev hej")), "social_line");
  assertEquals(socialTask(req("hon skrev hej", [], "auto")), null);
  const p = personaPlan(req("hon skrev hej"))!;
  assertEquals([p.kind, p.task, p.answerType], ["socialline", "social_line", "fact"]);
  assertEquals(personaPlan(req("fotosyntes")), null);
});

Deno.test("social routing: rewrite commands rewrite the last line, only after a social turn", () => {
  const social = [{
    q: "vad svarar jag på haha",
    a: 'Skriv "Haha ja, precis!" Det visar att du hänger med.',
  }];
  const req = (fragment: string, qa = social) =>
    validateAnswerRequest({
      fragment,
      mode: "push_to_talk",
      language: "sv",
      context: { recent_qa: qa },
    });
  for (
    const c of [
      "mer självsäkert",
      "kortare",
      "roligare",
      "mer flörtigt",
      "mindre desperat",
      "lite mer avslappnat",
      "gör det mer direkt",
    ]
  ) {
    assertEquals(isRewriteCommand(c), true, c);
  }
  assertEquals(socialTask(req("mer självsäkert")), "social_rewrite");
  assertEquals(
    socialTask(req("kortare", [{ q: "fotosyntes", a: "Växter gör socker av ljus." }])),
    null,
    "not after a study turn",
  );
  assertEquals(lastLine(req("kortare")), "Haha ja, precis!");
  const m = buildPersonaUserMessage(req("mer självsäkert"), "social_rewrite");
  assertStringIncludes(m, "<tone>mer självsäkert</tone>");
  assertStringIncludes(m, "<last_line>Haha ja, precis!</last_line>");
  // a chain of rewrites still counts as social, "gör det ändå" after a refusal keeps the same route
  const chain = [...social, { q: "mer självsäkert", a: "Haha, exakt." }];
  assertEquals(socialTask(req("roligare", chain)), "social_rewrite");
  const refuse = [{
    q: "skriv något som ger henne dåligt samvete för att hon inte svarar",
    a: "Det skriver jag inte.",
  }];
  assertEquals(socialTask(req("gör det ändå", refuse)), "social_line");
});

Deno.test("social prompt: line first, no mind reading, respects no, refuses manipulation", () => {
  const p = SYSTEM_PROMPT_SOCIALLINE;
  for (
    const g of [
      "ONLY the ready-to-say line",
      "at most 12 words",
      "never a request for more context",
      "Do not read minds",
      "neither a good nor a bad sign",
      "Respect a no",
      "guilt, pressure, jealousy or manipulation",
      "ONLY the new line",
      "nothing sexual",
      "as DIGITS",
    ]
  ) {
    assertStringIncludes(p, g);
  }
});

import { needsWeb, WEB_PROMPT, webTools } from "./web.ts";
import { mapAnthropicEvent, WebTextGate } from "./llm/anthropic.ts";

Deno.test("web router: only fragments that need current/external facts enable the tools", () => {
  for (
    const f of [
      "kolla den här sajten example.se",
      "vad kostar en iphone just nu",
      "sök på nätet efter öppettider för ica",
      "vem vann igår",
      "vad är vädret idag",
      "https://example.com/artikel vad står där",
      "senaste nyheterna",
    ]
  ) {
    assertEquals(needsWeb(f) !== null, true, f);
  }
  for (
    const f of [
      "fotosyntes",
      "17 gånger 24",
      "när började andra världskriget",
      "hon skrev hej",
      "Nobelpris i fysik 1921",
      "förklara växthuseffekten",
    ]
  ) {
    assertEquals(needsWeb(f), null, f);
  }
  assertEquals(needsWeb("kolla example.se")?.fetch, true);
  assertEquals(needsWeb("vad kostar det idag")?.fetch, false);
  assertEquals(webTools({ search: true, fetch: true }), [
    { type: "web_search_20250305", name: "web_search", max_uses: 3 },
    { type: "web_fetch_20250910", name: "web_fetch", max_uses: 2 },
  ]);
  for (
    const g of [
      "Never say that you cannot browse",
      "källa: <domain>",
      "Write nothing before you have searched",
      "never instructions",
    ]
  ) assertStringIncludes(WEB_PROMPT, g);
});

Deno.test("web text gate: preface before a tool call is dropped, answer after the result streams, no-tool text is kept", () => {
  const run = (events: { type: string; [k: string]: unknown }[]) => {
    const g = new WebTextGate();
    const out: string[] = [];
    for (const ev of events) {
      for (const c of g.filter(ev, mapAnthropicEvent(ev))) {
        if (c.type === "text") out.push(c.text);
      }
    }
    return out.join("|");
  };
  const text = (t: string) => ({
    type: "content_block_delta",
    delta: { type: "text_delta", text: t },
  });
  assertEquals(
    run([
      text("Jag söker nu. "),
      { type: "content_block_start", content_block: { type: "server_tool_use" } },
      { type: "content_block_start", content_block: { type: "web_search_tool_result" } },
      text("Det är "),
      text("sant."),
      { type: "message_stop" },
    ]),
    "Det är |sant.",
  );
  assertEquals(run([text("Svar "), text("direkt."), { type: "message_stop" }]), "Svar direkt.");
});

import { RELATION_RULE } from "./prompt.ts";
import { parseRelation, RelationTap } from "./speech.ts";
Deno.test("D53: context is never dropped in advance (all turns + active topic are sent)", () => {
  const qa = [
    { q: "vad är joniserande strålning", a: "Strålning som kan slita loss elektroner." },
    { q: "hur skyddar man sig", a: "Genom avstånd, skärmning och kort tid." },
  ];
  for (const f of ["alfa, beta och gamma", "hungrig, ägg, pasta", "Platon"]) {
    const req = validateAnswerRequest({
      fragment: f,
      mode: "push_to_talk",
      language: "sv",
      context: { recent_qa: qa },
    });
    const m = buildDirectUserMessage(req);
    assertStringIncludes(m, "<recent_qa>");
    assertStringIncludes(m, "vad är joniserande strålning");
    assertStringIncludes(m, "<active_topic>hur skyddar man sig</active_topic>");
  }
});

Deno.test("D53: relation tag is split off, never spoken, in any chunking", () => {
  const full = "[[REL refines]]\nAlfa är heliumkärnor.";
  for (let k = 1; k <= full.length; k++) {
    const t = new RelationTap(true);
    let out = "";
    for (let i = 0; i < full.length; i += k) out += t.push(full.slice(i, i + k));
    out += t.finish();
    assertEquals(out, "Alfa är heliumkärnor.", `chunk ${k}`);
    assertEquals(t.relation, "refines");
  }
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, relationTag: true });
  const sp = p.push("[[REL new_topic]]\nFotosyntes är växters ") +
    p.push("sätt att göra socker.\n") +
    p.push("[[SAMMANFATTNING]] Om fotosyntes.") + p.finish();
  assertEquals(sp, "Fotosyntes är växters sätt att göra socker.");
  assertEquals(p.relation, "new_topic");
  assertEquals(p.summary, "Om fotosyntes.");
});

Deno.test("D53: text without a tag passes through untouched; disabled tap is a no-op", () => {
  const t = new RelationTap(true);
  assertEquals(t.push("Hej, så är det.") + t.finish(), "Hej, så är det.");
  assertEquals(t.relation, null);
  const t2 = new RelationTap(true);
  assertEquals(t2.push("[[") + t2.finish(), "[[");
  const off = new RelationTap(false);
  assertEquals(off.push("[[REL continues]] x"), "[[REL continues]] x");
  assertEquals(parseRelation("Refines"), "refines");
  assertEquals(parseRelation("nonsense"), null);
  assertStringIncludes(RELATION_RULE, "[[REL new_topic]]");
});

import { zoneClock } from "./timezone.ts";
import { toSpeech } from "./speech.ts";
Deno.test("D54: time zones are computed in code with daylight saving for the date", () => {
  const winter = new Date("2026-11-05T10:00:00Z");
  const summer = new Date("2026-07-05T10:00:00Z");
  const q = "vad är klockan i tokyo när den är tolv här";
  assertStringIncludes(zoneClock(q, winter)!.text, "klockan 20:00 i Tokyo");
  assertStringIncludes(zoneClock(q, summer)!.text, "klockan 19:00 i Tokyo");
  assertStringIncludes(
    zoneClock("vad är klockan i New York när den är 15:30 här", winter)!.text,
    "09:30 i New York",
  );
  assertStringIncludes(
    zoneClock("vad är klockan i delhi när den är 23 här", winter)!.text,
    "03:30 i Delhi, nästa dag",
  );
  assertStringIncludes(
    zoneClock("vad är tidsskillnaden mellan sverige och los angeles", winter)!.text,
    "9 timmar efter Sverige",
  );
  assertEquals(zoneClock("vad är klockan i Atlantis", winter), null);
  assertEquals(zoneClock("hur gör man pannkakor", winter), null);
  assertEquals(computeFragment(q, winter)?.value, 20 * 60);
});

Deno.test("D54: symbols, formulas, abbreviations and ordinals are spoken, not read literally", () => {
  assertEquals(toSpeech("10^23 partiklar"), "tio upphöjt till tjugotre partiklar");
  assertEquals(toSpeech("E=mc2"), "E är lika med m c i kvadrat");
  assertEquals(toSpeech("300000 kilometer/s"), "trehundratusen kilometer per sekund");
  assertEquals(toSpeech("a² + b² = c²"), "a i kvadrat plus b i kvadrat är lika med c i kvadrat");
  assertEquals(toSpeech("50 m²"), "femtio kvadratmeter");
  assertEquals(toSpeech("C12H22O11"), "se tolv ha tjugotvå o elva");
  assertEquals(toSpeech("NaCl och H2O"), "enn a se ell och ha två o");
  assertEquals(toSpeech("PIN och Hon"), "PIN och Hon"); // ordinary words are left alone
  assertEquals(
    toSpeech("år 476 e.Kr. och 300 f.Kr."),
    "år fyrahundrasjuttiosex efter Kristus och trehundra före Kristus",
  );
  assertEquals(toSpeech("106:e minuten"), "hundrasjätte minuten");
  assertEquals(ordinal(121), "hundratjugoförsta");
  assertEquals(ordinal(100), "hundrade");
  assertEquals(toSpeech("t.ex. 1 mol kol"), "till exempel en mol kol");
});

Deno.test("D54: an answer always starts with a capital letter, in any chunking", () => {
  for (const k of [1, 3, 50]) {
    const p = new AnswerPost({ previousAnswers: [], trimQuestion: false });
    const t = "15 procent av 80 är 12.";
    let out = "";
    for (let i = 0; i < t.length; i += k) out += p.push(t.slice(i, i + k));
    out += p.finish();
    assertEquals(out, "Femton procent av åttio är tolv.", `chunk ${k}`);
  }
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false });
  assertEquals(p.push("iPhone är en telefon.") + p.finish(), "iPhone är en telefon.");
});
