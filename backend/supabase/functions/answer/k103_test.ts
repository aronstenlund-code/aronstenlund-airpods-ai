// K103 (D232, Oscar O86): the five content faults B1–B5 and the first word without waiting (A1), one test each.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { textForVoice } from "./handler.ts";
import { WEB_PROMPT, TEXT_PROMPT } from "./web.ts";
import { SYSTEM_PROMPT_SOCIALLINE } from "./socialroute.ts";
import { AnswerPost, NumberStream, noParens, socialLineSentence } from "./speech.ts";
import { afterNumbers } from "./speechsym.ts";

Deno.test("K103 B1: a song is said without line breaks; a self-correction drops the wrong start", () => {
  const live = "Helan går\nsjunger vi An dricka långsamt\nHelan går\n\nJag är osäker på den exakta texten, så här kommer den vedertagna versionen:\n\nHelan går,\nsjung hopp faderallan lej.\nOch den som inte helan tar,\nhan ej heller halvan får.";
  const out = textForVoice(live, true);
  assertEquals(out, "Helan går, sjung hopp faderallan lej. Och den som inte helan tar, han ej heller halvan får.");
  assert(!out.includes("\n") && !out.includes("An dricka"));
  assertEquals(textForVoice("Helan går\nsjung hopp faderallan lallan lej\n", true), "Helan går, sjung hopp faderallan lallan lej ");
  assertEquals(textForVoice("lallan \nlej", false), "lallan, lej", "a line end is a pause also after a space");
  assertEquals(textForVoice(".\n\nOch", false), ". Och", "after a full stop only a space");
  assertStringIncludes(TEXT_PROMPT, "never start a text and then correct yourself");
});

Deno.test("K103 B2: a web answer gives the answer with the caveat, never the caveat alone", () => {
  assertStringIncludes(WEB_PROMPT, "Nilen räknas oftast som världens längsta flod, men vissa mätningar ger Amazonas.");
  assertStringIncludes(WEB_PROMPT, "never answer with only the disagreement or only a caveat");
});

Deno.test("K103 B3: a range is read as a range, also with a minus sign or a dash left between number words", () => {
  const say = (t: string) => {
    const s = new NumberStream();
    return afterNumbers(s.push(t + " ") + (s as unknown as { finish(): string }).finish()).trim();
  };
  assertEquals(say("öka mellan 1,4−5,7 grader"), "öka mellan ett komma fyra till fem komma sju grader");
  assertEquals(say("öka mellan 1,4 – 5,7 grader"), "öka mellan ett komma fyra till fem komma sju grader");
  assertEquals(afterNumbers("mellan ett komma fyra – fem komma sju grader"), "mellan ett komma fyra till fem komma sju grader");
  assertEquals(afterNumbers("Klimatet – det blir varmare"), "Klimatet – det blir varmare", "a dash between words stays");
  assertStringIncludes(WEB_PROMPT, "never with a dash or a minus sign");
  assertEquals(afterNumbers("blanda en ägg med en dl ströbröd"), "blanda ett ägg med en deciliter ströbröd", "O86 praktiskt-04");
});

Deno.test("K103 B4: no detail the memory does not hold (the Åre example is gone from the prompt)", () => {
  assert(!SYSTEM_PROMPT_SOCIALLINE.includes('"Jag åkte skidor i Åre, du då?"'), "the example taught the model to add a place");
  assertStringIncludes(SYSTEM_PROMPT_SOCIALLINE, "no place, person, time or number that is not in them");
  assertStringIncludes(SYSTEM_PROMPT_SOCIALLINE, '"Jag har åkt skidor, du då?"');
});

Deno.test("K103 B5: a social line is the line to say: advice about the other person and questions to the user go", () => {
  const run = (parts: string[]) => {
    const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, firstLineOnly: true, socialLine: true });
    return (parts.map((x) => p.push(x)).join("") + p.finish()).trim();
  };
  assertEquals(run(["Haha, då får du ", "visa honom att du är allt annat än tråkig! ", 'Men om du vill svara lugnt: "Jag tycker du är rolig, så du får gärna fortsätta."']), "Jag tycker du är rolig, så du får gärna fortsätta.");
  assertEquals(run(["Haha, då får du visa honom att du är allt annat än tråkig. ", "Vad sa han sen?"]), "");
  assertEquals(run(["Skojar du? ", "Då får du visa mig att du inte är det!"]), "Skojar du? Då får du visa mig att du inte är det!", "said to the other person: kept");
  assertEquals(socialLineSentence("Tråkig? "), "Tråkig? ");
  assertStringIncludes(SYSTEM_PROMPT_SOCIALLINE, "never advice about X to the user");
});

Deno.test("K103 (O86 tillägg): a parenthesis in a web answer is not read; its inside becomes an aside", () => {
  const ns = new NumberStream();
  const said = ["Enligt Climate Action Tracker (", "2025) är det ", "för lite."].map((c) => ns.push(c)).join("") + ns.finish();
  assertEquals(said.replace(/ {2,}/g, " "), "Enligt Climate Action Tracker, tvåtusen tjugofem, är det för lite.");
  assertEquals(noParens("Det var varmast (enligt SMHI)."), "Det var varmast, enligt SMHI.");
});

Deno.test("K103 B1: the prompt holds the exact words of Helan går, each word apart", () => {
  assertStringIncludes(TEXT_PROMPT, "Och den som inte helan tar, han heller inte halvan får.");
  assertStringIncludes(TEXT_PROMPT, "sjung hopp faderallan lallan lej");
});
