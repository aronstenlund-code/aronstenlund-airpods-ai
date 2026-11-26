// O103 Q2 (Oscar): years 1001-1099 were read as "tusen sextiosex"; as a year it is "tiohundrasextiosex".
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { numbersToSpeech } from "./svnum.ts";

Deno.test("O103 Q2: a year 1001-1099 is read in hundreds; an amount or plain number is not", () => {
  assertStringIncludes(numbersToSpeech("Slaget vid Hastings var den 14 oktober 1066."), "oktober tiohundrasextiosex");
  assertStringIncludes(numbersToSpeech("Det hände år 1066."), "år tiohundrasextiosex");
  assertStringIncludes(numbersToSpeech("Knut den store dog 1035-11-12."), "tiohundratrettiofem");
  assertStringIncludes(numbersToSpeech("Det kostar 1066 kr."), "tusen sextiosex kronor");
  assertStringIncludes(numbersToSpeech("Det var 1066 personer där."), "tusen sextiosex");
  assertEquals(numbersToSpeech("år 1000"), "år tusen");
  assertStringIncludes(numbersToSpeech("år 1789"), "sjuttonhundraåttionio");
});
