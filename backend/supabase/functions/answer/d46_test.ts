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
  assertEquals(t("Klockan 14:30, den 3:e."), "Klockan fjorton och trettio, den tredje.");
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

import { needsWeb, RELIABLE_DOMAINS, WEB_PROMPT, webTools } from "./web.ts";
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
    {
      type: "web_search_20250305",
      name: "web_search",
      max_uses: 3,
      allowed_domains: RELIABLE_DOMAINS,
    },
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
  assertEquals(toSpeech("C\u2081\u2082H\u2082\u2082O\u2081\u2081"), "se tolv ha tjugotvå o elva");
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

Deno.test("D54: web search is limited to reliable domains; 'genom' divides; ett mol -> en mol", () => {
  const t = webTools({ search: true, fetch: false })[0] as { allowed_domains: string[] };
  assertEquals(t.allowed_domains, RELIABLE_DOMAINS);
  assert(RELIABLE_DOMAINS.includes("scb.se") && !RELIABLE_DOMAINS.includes("masterskapssidan.se"));
  assertEquals(computeFragment("tiotusen genom fyra hundra")?.value, 25);
  assertEquals(computeFragment("10000 genom 400")?.value, 25);
  assertEquals(toSpeech("Ett mol kol väger tolv gram."), "En mol kol väger tolv gram.");
});

import { findSummaryMarker, SummaryTap } from "./speech.ts";
Deno.test("D65: the summary marker is cut in every variant, anywhere, in any chunking; a missing summary is still removed", () => {
  const variants = [
    "[[SAMMANFATTNING]] Om fotosyntes och ljus.",
    "SAMMANFATTNING: Om fotosyntes och ljus.",
    "[SAMMANFATTNING] Om fotosyntes och ljus.",
    "[[sammanfattning]]: Om fotosyntes och ljus.",
    "Sammanfattning: Om fotosyntes och ljus.",
    "**Sammanfattning:** Om fotosyntes och ljus.",
    "SAMMANFATTNING Om fotosyntes och ljus.",
  ];
  for (const v of variants) {
    for (const k of [1, 2, 5, 400]) {
      const t = new SummaryTap();
      const text = `Svaret kommer här. Det är kort.\n${v}`;
      let out = "";
      for (let i = 0; i < text.length; i += k) out += t.push(text.slice(i, i + k));
      out += t.finish();
      assertEquals(out, "Svaret kommer här. Det är kort.", `${v} / chunk ${k}`);
      assertEquals(t.summary, "Om fotosyntes och ljus.", `${v} / chunk ${k}`);
    }
  }
  // mid-text, on the same line as the answer
  const t = new SummaryTap();
  assertEquals(
    t.push("Här lägger du ett exempel. SAMMANFATTNING: Intervju om butik.") + t.finish(),
    "Här lägger du ett exempel.",
  );
  assertEquals(t.summary, "Intervju om butik.");
  // marker without any summary: the line is still removed from the speech
  const e = new SummaryTap();
  assertEquals(e.push("Svar.\n[[SAMMANFATTNING]]") + e.finish(), "Svar.");
  assertEquals(e.summary, null);
  const e2 = new SummaryTap();
  assertEquals(e2.push("Svar.\nSAMMANFATTNING:") + e2.finish(), "Svar.");
  // ordinary speech that merely contains the word is untouched
  for (
    const ok of [
      "Här är en sammanfattning av läget.",
      "Samma sak, Samtidigt och Svenska ord.",
      "Sammanfattningsvis är det klart.",
    ]
  ) {
    const n = new SummaryTap();
    assertEquals(n.push(ok) + n.finish(), ok);
    assertEquals(n.summary, null);
  }
  assertEquals(findSummaryMarker("inget här"), null);
});

Deno.test("D65: clock times with a dot, regnal numbers, 2x, 5G and hertz are spoken", () => {
  assertEquals(toSpeech("Tåget går klockan 17.40."), "Tåget går klockan sjutton och fyrtio.");
  assertEquals(
    toSpeech("Möte kl 9.05 och 14:30."),
    "Möte kl nio noll fem och fjorton och trettio.",
  );
  assertEquals(toSpeech("Pi är 3.14 ungefär."), "Pi är tre komma ett fyra ungefär.");
  assertEquals(
    toSpeech("Oscar I regerade 1844."),
    "Oscar den förste regerade artonhundrafyrtiofyra.",
  );
  assertEquals(
    toSpeech("Karl XII och Karl XV, Gustav II Adolf."),
    "Karl den tolfte och Karl den femtonde, Gustav den andre Adolf.",
  );
  assertEquals(toSpeech("Karl IV I Sverige"), "Karl den fjärde I Sverige"); // lone I before a name is the preposition
  assertEquals(toSpeech("Det går 2x snabbare och 5G."), "Det går två gånger snabbare och fem G.");
  assertEquals(
    toSpeech("En processor på 3,5 GHz och 50 Hz."),
    "En processor på tre komma fem gigahertz och femtio hertz.",
  );
  assertEquals(toSpeech("kof­fein​et"), "koffeinet");
});

import { dateCalc, isoWeek, nowContext } from "./datecalc.ts";
Deno.test("D65: date, weekday, week, clock and days-until are computed in code (Swedish time)", () => {
  const at = new Date("2026-11-06T16:40:00Z"); // fredag 17:40 svensk tid
  assertEquals(
    nowContext(at),
    "fredag 6 november 2026, vecka 45, klockan 17:40 (svensk tid, Europe/Stockholm)",
  );
  assertStringIncludes(dateCalc("vilket datum är det", at)!.text, "fredag 6 november 2026");
  assertStringIncludes(dateCalc("vilken veckodag är det idag", at)!.text, "fredag");
  assertEquals(dateCalc("vilken vecka är det", at)!.value, 45);
  assertEquals(dateCalc("vad är klockan", at)!.text.slice(0, 18), "Klockan är 17:40 s");
  const jul = dateCalc("hur många dagar är det kvar till julafton", at)!;
  assertEquals(jul.value, 48);
  assertStringIncludes(jul.text, "om 48 dagar (6 veckor och 6 dagar)");
  assertEquals(dateCalc("hur många dagar är det till nyår", at)!.value, 56);
  assertEquals(dateCalc("hur många dagar till midsommar", at)!.value, 231); // 2027-06-25
  assertEquals(dateCalc("hur många dagar till påsk", at)!.value, 142); // 2027-03-28
  assertEquals(dateCalc("hur många dagar till 3 mars", at)!.value, 117);
  assertEquals(dateCalc("hur många dagar tills 24 december 2026", at)!.value, 48);
  assertEquals(dateCalc("hur många dagar till idag", at), null);
  assertEquals(dateCalc("vem är kung", at), null);
  assertEquals(isoWeek(2026, 12, 31), 53);
  assertEquals(computeFragment("hur många dagar är det kvar till julafton", at)?.value, 48);
  assertStringIncludes(
    computeFragment("vad är klockan i kapstaden när den är tolv här", at)!.text,
    "Kapstaden",
  );
});

Deno.test("D65: every request carries <now>; the prompt forbids 'I have no access to the date'", () => {
  const req = validateAnswerRequest({
    fragment: "vilket datum är det",
    mode: "push_to_talk",
    language: "sv",
  });
  const m = buildDirectUserMessage(req, null, {
    now: nowContext(new Date("2026-11-06T16:40:00Z")),
  });
  assertStringIncludes(m, "<now>fredag 6 november 2026, vecka 45");
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_FACT, "never say that you have no access to the date");
});

import { guardPhoneNumbers, PHONE_PLACEHOLDER } from "./speechsym.ts";
Deno.test("D65 safety: phone numbers are never read out unless 112, 1177 or 114 14 for the police", () => {
  assertEquals(toSpeech("Ring 112 vid nödläge."), "Ring ett ett två vid nödläge.");
  assertEquals(
    toSpeech("Ring 1177 för sjukvårdsrådgivning."),
    "Ring elva sjuttiosju för sjukvårdsrådgivning.",
  );
  assertEquals(
    toSpeech("Spärra kortet: ring 114 14 eller bankens nummer."),
    `Spärra kortet: ring ${PHONE_PLACEHOLDER} eller bankens nummer.`,
  );
  assertStringIncludes(
    toSpeech("Polisen når du på 114 14 när det inte är akut."),
    "hundrafjorton fjorton",
  );
  assertEquals(
    toSpeech("Ring kundtjänst på 020-123 456."),
    `Ring kundtjänst på ${PHONE_PLACEHOLDER}.`,
  );
  assertEquals(toSpeech("Ring 08-123 45 67 direkt."), `Ring ${PHONE_PLACEHOLDER} direkt.`);
  assertEquals(toSpeech("Ring +46 70 123 45 67."), `Ring ${PHONE_PLACEHOLDER}.`);
  // ordinary numbers next to no phone cue are untouched
  assertEquals(
    toSpeech("Det kostar 10 000 kr och tar 25 minuter."),
    "Det kostar tiotusen kronor och tar tjugofem minuter.",
  );
  assertEquals(
    toSpeech("Året var 1789 och 2026."),
    "Året var sjuttonhundraåttionio och tvåtusen tjugosex.",
  );
  // the cue may sit in an earlier chunk (the stream passes its raw tail as context)
  assertEquals(
    guardPhoneNumbers("020 123 456 direkt", "Ring spärrjouren på "),
    PHONE_PLACEHOLDER + " direkt",
  );
  assertEquals(guardPhoneNumbers("hej 112"), "hej 112");
  // streaming: split anywhere
  const txt = "För att spärra kortet ring 020 123 456 eller använd appen.";
  for (const k of [1, 3, 7, 80]) {
    const p = new AnswerPost({ previousAnswers: [], trimQuestion: false });
    let o = "";
    for (let i = 0; i < txt.length; i += k) o += p.push(txt.slice(i, i + k));
    o += p.finish();
    assert(!/\d/.test(o) && o.includes(PHONE_PLACEHOLDER), `chunk ${k}: ${o}`);
  }
});

Deno.test("D65 safety: allergy / health memories add a binding <safety> rule; the prompt names the only allowed numbers", () => {
  const mk = (memories: string[]) =>
    validateAnswerRequest({
      fragment: "vilken godis kan jag köpa",
      mode: "push_to_talk",
      language: "sv",
      memories,
    });
  assertStringIncludes(buildDirectUserMessage(mk(["jag är allergisk mot nötter"])), "<safety>");
  assertStringIncludes(
    buildDirectUserMessage(mk(["Jag har celiaki"])),
    "never say that something is safe",
  );
  assert(!buildDirectUserMessage(mk(["jag gillar skidor"])).includes("<safety>"));
  assert(!buildDirectUserMessage(mk([])).includes("<safety>"));
  for (const p of [SYSTEM_PROMPT_DIRECT_FACT, SYSTEM_PROMPT_DIRECT_TUTOR]) {
    assertStringIncludes(p, "112 (emergency), 1177 (healthcare advice) and 114 14 (police");
    assertStringIncludes(p, "<safety>");
  }
});

import { EnglishGate, isEnglishSentence, isSearchMeta, SourceTap, spokenSource } from "./speech.ts";
Deno.test("D65 web: source line is spoken as a name, English sentences are dropped, wikis are not allowed", () => {
  const raw =
    "Riksbankschef är Erik Thedéen, som tillträdde 1 januari 2023. Since 1 January 2023 he serves as the Governor of Sveriges Riksbank, the central bank of Sweden.\n\nkälla: en.wikipedia.org";
  for (const k of [1, 4, 9, 400]) {
    const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, web: true });
    let o = "";
    for (let i = 0; i < raw.length; i += k) o += p.push(raw.slice(i, i + k));
    o += p.finish();
    assert(!/Since|serves|Governor/.test(o), `chunk ${k}: ${o}`);
    assert(!/punkt|\.org|\.se/i.test(o), `chunk ${k}: ${o}`);
    assert(o.endsWith("Källa: Wikipedia."), `chunk ${k}: ${o}`);
    assertEquals(p.source, "en.wikipedia.org");
  }
  assertEquals(spokenSource("scb.se"), "SCB");
  assertEquals(spokenSource("www.riksdagen.se"), "Riksdagen");
  assertEquals(spokenSource("developer.mozilla.org"), "Mozilla");
  assertEquals(spokenSource("bbc.co.uk"), "BBC");
  assert(isEnglishSentence("He serves as the Governor of the central bank of Sweden."));
  assert(!isEnglishSentence("Han är riksbankschef och har varit det sedan 2023."));
  assert(!isEnglishSentence("Staden Washington D.C. ligger i USA."));
  const t = new SourceTap(true);
  assertEquals(t.push("Svar. Källa: scb.se") + t.finish(), "Svar. Källa: SCB.");
  const off = new SourceTap(false);
  assertEquals(off.push("källa: x.se") + off.finish(), "källa: x.se");
  const g = new EnglishGate(false);
  assertEquals(g.push("The cat is on the mat and it is."), "The cat is on the mat and it is.");
  assert(!RELIABLE_DOMAINS.some((d) => d.includes("wikipedia")), "no wikis");
  assert(RELIABLE_DOMAINS.includes("riksbank.se") && !RELIABLE_DOMAINS.includes("riksbanken.se"));
});

Deno.test("D65 web: narrower search rules; ordinal list facts search", () => {
  for (
    const q of [
      "vem vann slaget vid Lützen",
      "vad är skillnaden mellan väder och klimat",
      "vad heter idag på engelska",
      "vad är senaste istiden",
      "vad betyder öppet hav",
      "hur kommer man ut ur en återvändsgränd",
      "vilken veckodag är det idag",
    ]
  ) assertEquals(needsWeb(q), null, q);
  for (
    const q of [
      "vem vann senaste fotbolls VM",
      "vad är vädret i Stockholm idag",
      "senaste nyheterna",
      "vilken var den tredje kungen av ätten Bernadotte",
      "sök på nätet vem som är riksbankschef",
      "när kommer nya iPhone ut",
    ]
  ) assertEquals(needsWeb(q)?.search, true, q);
});

import { computeFollowUp } from "./calc.ts";
Deno.test("D65: a bare unit in a follow-up is converted in code from the previous answer's value", () => {
  const r = computeFollowUp(
    "och i fot",
    "Eiffeltornet är cirka trehundratrettio meter högt, inklusive antenner.",
  )!;
  assertEquals(Math.round(r.value), 1083);
  assertStringIncludes(r.text, "330 meter = 1082,6772 fot");
  assertEquals(Math.round(computeFollowUp("i kilometer", "Det är tre mil dit.")!.value), 30);
  assertEquals(Math.round(computeFollowUp("och i pund", "Paketet väger två kilo.")!.value), 4);
  assertEquals(
    Math.round(computeFollowUp("och i fahrenheit", "Det är tjugo grader celsius ute.")!.value),
    68,
  );
  assertEquals(
    Math.round(computeFollowUp("och i celsius", "Det är sjuttiotvå grader fahrenheit.")!.value),
    22,
  );
  assertEquals(
    Math.round(
      computeFollowUp("hur mycket är det i tum", "Linjalen är trettio centimeter lång.")!.value,
    ),
    12,
  );
  assertEquals(
    Math.round(
      computeFollowUp("och i meter", "Tornet är tusen åttahundrafyrtiotvå fot högt.")!.value,
    ),
    561,
  );
  assertEquals(computeFollowUp("och i fot", "Det blir bra väder i morgon."), null);
  assertEquals(computeFollowUp("och i fot", undefined), null);
  assertEquals(computeFollowUp("vad är fotosyntes", "Tornet är tre meter högt."), null);
  assertEquals(
    computeFollowUp("och i liter", "Tornet är tre meter högt."),
    null,
    "different kind of quantity",
  );
});

import { lastQuestion, SYSTEM_PROMPT_DIRECT_STUDY } from "./prompt.ts";
import { tutorQuestionOk } from "./speech.ts";
Deno.test("D65 tutor: one short check question; two-part questions are dropped; asked questions are listed", () => {
  assert(tutorQuestionOk("Vad kallas organellen som bildar ATP?"));
  assert(
    !tutorQuestionOk(
      "Vad kallas den organell som bildar ATP, och vilken ordning har de två delarna i cellandningen?",
    ),
  );
  assert(!tutorQuestionOk("Vad är en cell? Vad är en kärna?"));
  const run = (text: string, k: number) => {
    const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, tutor: true });
    let o = "";
    for (let i = 0; i < text.length; i += k) o += p.push(text.slice(i, i + k));
    return o + p.finish();
  };
  for (const k of [1, 4, 500]) {
    assertEquals(
      run("Mitokondrien bildar ATP. Vad heter organellen? Svara gärna med ett ord.", k),
      "Mitokondrien bildar ATP. Vad heter organellen? Svara gärna med ett ord.",
    );
    assertEquals(
      run(
        "Mitokondrien bildar ATP. Vad kallas organellen, och vilken ordning har delarna i cellandningen? Svara med ett ord.",
        k,
      ),
      "Mitokondrien bildar ATP. Svara med ett ord.",
    );
    assertEquals(
      run(
        "Mitokondrien bildar ATP. Vad kallas organellen, och vilken ordning har delarna i cellandningen?",
        k,
      ),
      "Mitokondrien bildar ATP. ",
    );
  }
  assertEquals(
    lastQuestion("Proteinerna byggs i ribosomerna. Vad heter organellen som bygger proteinerna?"),
    "Vad heter organellen som bygger proteinerna?",
  );
  assertEquals(lastQuestion("Inget frågetecken här."), null);
  const req = validateAnswerRequest({
    fragment: "nästa fråga",
    mode: "tutor",
    language: "sv",
    context: {
      recent_qa: [{
        q: "vet inte",
        a: "Proteinerna byggs i ribosomerna. Vad heter organellen som bygger proteinerna?",
      }],
    },
  });
  const m = buildDirectUserMessage(req);
  assertStringIncludes(
    m,
    '<already_asked count="1">\n- Vad heter organellen som bygger proteinerna?',
  );
  const plain = validateAnswerRequest({
    ...{ fragment: "x", mode: "push_to_talk", language: "sv" },
  });
  assert(!buildDirectUserMessage(plain).includes("<already_asked>"));
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_TUTOR, "<already_asked>");
  assertStringIncludes(
    SYSTEM_PROMPT_DIRECT_TUTOR,
    "Never ask about something you have just explained",
  );
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_STUDY, "use no fixed stock phrases");
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_FACT, "koffeinets halveringstid");
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_FACT, "put the whole list in order");
});

Deno.test("Oscar round 2 M04.2: a clock time split from 'klockan' by the stream is still a time", () => {
  for (const size of [1, 2, 3, 5, 9, 40]) {
    for (const t of ["Ditt tåg går klockan 17.40.", "Ditt tåg går klockan 17,40.", "Bussen går kl 7.05 i morgon."]) {
      const s = new NumberStream();
      let out = "";
      for (let k = 0; k < t.length; k += size) out += s.push(t.slice(k, k + size));
      out += s.finish();
      assert(/sjutton och fyrtio|sju noll fem/.test(out), `${size}: ${out}`);
      assert(!out.includes("komma"), `${size}: ${out}`);
    }
  }
  assert(!toSpeech("Det kostar 17,40 kronor.").includes("och fyrtio"), "prices stay prices");
  const s = new NumberStream();
  assert(!(s.push("Det kostar ") + s.push("17,40 kronor.") + s.finish()).includes("och fyrtio"));
});

Deno.test("Oscar round 2 F16: web-mode sentences that narrate the search decision are never spoken", () => {
  const t =
    "Det här är en historisk fråga som jag kan svara på direkt, utan sökning. Den tredje kungen av ätten Bernadotte är Karl den femtonde.";
  for (const size of [1, 4, 17, 400]) {
    const g = new EnglishGate(true);
    let out = "";
    for (let k = 0; k < t.length; k += size) out += g.push(t.slice(k, k + size));
    assertEquals(out + g.finish(), "Den tredje kungen av ätten Bernadotte är Karl den femtonde.", `${size}`);
  }
  for (const s of ["Jag söker på Riksbankens webbplats.", "Det behövs ingen sökning för det här."]) {
    assert(isSearchMeta(s), s);
  }
  for (const s of ["Sökningen visar att räntan är 2 procent.", "Han söker jobb i Malmö.", "Du kan svara direkt i appen."]) {
    assert(!isSearchMeta(s), s);
  }
  assertStringIncludes(WEB_PROMPT, "Never mention searching");
  assertStringIncludes(SYSTEM_PROMPT_DIRECT_FACT, "never read the list aloud");
});
