import { assertEquals } from "jsr:@std/assert@1.0.8";
import { classifyAnswerType, detectContinuation } from "./length.ts";

const kind = (f: string, len: "short" | "adaptive" | "long" = "adaptive") =>
  classifyAnswerType(f, len, detectContinuation(f));

Deno.test("study cues -> study; plain facts/maths/terms -> fact (adaptive)", () => {
  for (
    const f of [
      "kärnkraftverk procons",
      "för- och nackdelar med kärnkraft",
      "förklara växthuseffekten",
      "varför föll romarriket",
      "jämför mitos och meios",
      "vad är skillnaden mellan virus och bakterier",
      "hur fungerar ett vaccin",
      "orsakerna till första världskriget",
      "beskriv cellens delar",
      "berätta om franska revolutionen",
      "konsekvenser av klimatförändringar",
      "sammanfatta andra världskriget",
      "pros and cons med elbilar",
    ]
  ) assertEquals(kind(f), "study", f);
  for (
    const f of [
      "roten ur hundra",
      "fem plus två",
      "vad är pi",
      "när föll berlinmuren",
      "vem var gustav vasa",
      "vad är huvudstaden i australien",
      "hur många invånare har sverige",
      "fotosyntes",
      "hur stavas man restaurang",
      "vad betyder ambivalent",
      "tjugofem procent av tvåhundra",
    ]
  ) assertEquals(kind(f), "fact", f);
});

Deno.test("word boundaries respect å/ä/ö (no false hits inside other words)", () => {
  assertEquals(kind("förklaringsmodell"), "fact"); // not 'förklaring' as a whole word
  assertEquals(kind("proton"), "fact");
  assertEquals(kind("pros"), "study");
});

Deno.test("length setting overrides the heuristic", () => {
  assertEquals(kind("förklara växthuseffekten", "short"), "fact");
  assertEquals(kind("vad är pi", "long"), "study");
});

Deno.test("continuations: mer / fortsätt / förklara enklare", () => {
  for (const f of ["mer", "Mer.", "fortsätt", "berätta mer", "och sen", "utveckla"]) {
    assertEquals(detectContinuation(f), "more", f);
  }
  for (
    const f of [
      "förklara enklare",
      "förklara det igen",
      "kan du förklara det enklare",
      "enklare tack",
    ]
  ) assertEquals(detectContinuation(f), "simpler", f);
  for (const f of ["förklara växthuseffekten", "mer om vulkaner", "vad är mer"]) {
    assertEquals(detectContinuation(f), null, f);
  }
  assertEquals(classifyAnswerType("mer", "adaptive", "more"), "study");
  assertEquals(classifyAnswerType("mer", "short", "more"), "fact");
});
