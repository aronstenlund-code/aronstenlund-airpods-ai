// K114 (D251): the answer's language: "language" (or "lang") sv/en, English when the app or web leaves it out.
import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.8";
import { validateAnswerRequest } from "./validate.ts";

const base = { fragment: "what is photosynthesis", mode: "text", context: {} };
Deno.test("K114: language defaults to English; lang is the same field; anything else is refused", () => {
  assertEquals(validateAnswerRequest(base).language, "en");
  assertEquals(validateAnswerRequest({ ...base, lang: "sv" }).language, "sv");
  assertEquals(validateAnswerRequest({ ...base, language: "sv" }).language, "sv");
  assertThrows(() => validateAnswerRequest({ ...base, language: "de" }));
});
