// K110 (D241, Oscar O91): the long answer is capped in code at long_words (so the cost estimate holds), the Lübeck
// question has its root removed, and the refill that gave 0 of 3 (printing) is found.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { answerItems, capLong, DEFAULT_DRILL_CONFIG, notAnswered, refillQuestions, SYSTEM_PROMPT_DRILL_ANSWERS, SYSTEM_PROMPT_DRILL_FINAL_CHECK, words } from "./drill.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";

function llm(replies: unknown[]): LLMProvider & { seen: LLMRequest[] } {
  const seen: LLMRequest[] = [];
  return {
    name: "f", model: "x", seen,
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(req);
      const r = replies[Math.min(seen.length - 1, replies.length - 1)];
      yield { type: "text", text: typeof r === "function" ? (r as (q: LLMRequest) => string)(req) : JSON.stringify(r) } as LLMChunk;
      yield { type: "usage", inputTokens: 300, outputTokens: 200 };
    },
  };
}

const SENT = "Energin minskar för varje steg i kedjan eftersom djuren använder den för att leva och röra sig.";
const LONG_REST = Array.from({ length: 9 }, () => SENT).join(" "); // 9 × 17 = 153 words

Deno.test("K110: the long answer never goes over long_words; whole sentences, the short answer always kept", () => {
  const short = "Bara en tiondel av energin följer med till nästa nivå.";
  const long = `${short} ${LONG_REST}`;
  const c = capLong(long, short, 90);
  assert(words(c.long) <= 90, String(words(c.long)));
  assert(c.long.startsWith(short));
  assert(/[.!?]$/.test(c.long));
  assertEquals(c.kept, Math.floor((90 - words(short)) / words(SENT)));
  const fits = `${short} ${SENT}`;
  assertEquals(capLong(fits, short, 90), { long: fits, kept: -1 }, "within the limit: unchanged");
  assertEquals(capLong(`${short} ${"ord ".repeat(120).trim()}.`, short, 90).long, short, "no whole sentence fits: the short answer alone");
});

Deno.test("K110: answerItems caps the long answer and the screen's long answer by the same sentences", async () => {
  const short = "Bara en tiondel av energin följer med.";
  const p = llm([{ answers: [{ id: "q1", short, rest: LONG_REST, display: { rest: LONG_REST.replace("eftersom", "då") } }] }]);
  const r = await answerItems(p, DEFAULT_DRILL_CONFIG, [{ id: "q1", question: "Hur mycket energi följer med till nästa nivå?" }], { subject: "Biologi", grade: "", notes: "n", longWords: 90 });
  const it = r.items[0];
  assert(words(it.long!) <= 90, String(words(it.long!)));
  const sentences = (s: string) => s.split(/(?<=[.!?])\s+/).length;
  assertEquals(sentences(it.screen?.long ?? it.long!), sentences(it.long!));
  assert(!SYSTEM_PROMPT_DRILL_ANSWERS.includes("by at most a fifth"), "the prompt no longer lets it go over");
});

Deno.test("K110 (Oscar O91 F1): 'är inte känt härifrån' and a long answer that says 'framgår inte' are unanswered", async () => {
  assert(notAnswered("Varför kronan hade skulder till Lübeck är inte känt härifrån, men kronan behövde pengar."));
  const q = { id: "q1", question: "Hur fick Gustav Vasa med sig bönderna i Dalarna?" };
  const bad = { id: "q1", short: "Han fick med sig bönderna i ett uppror.", rest: "Hur han lyckades övertyga bönderna framgår inte, men upproret ledde till att han blev kung." };
  const good = { id: "q1", question: "Vad gjorde bönderna i Dalarna?", short: "De gjorde uppror mot danskarna med Gustav Vasa.", rest: "Upproret ledde till att han blev kung." };
  const p = llm([{ answers: [bad] }, { answers: [good] }]);
  const r = await answerItems(p, DEFAULT_DRILL_CONFIG, [q], { subject: "Historia", grade: "", notes: "n", longWords: 90, mayFix: true });
  assertEquals(p.seen.length, 2, "the long answer's 'framgår inte' asks again");
  assertEquals(r.items[0].question, "Vad gjorde bönderna i Dalarna?");
});

Deno.test("K110 (Oscar O91 F1, root): the final check's example no longer teaches the Lübeck why-question", () => {
  assert(!SYSTEM_PROMPT_DRILL_FINAL_CHECK.includes("Lübeck"));
  assert(!SYSTEM_PROMPT_DRILL_FINAL_CHECK.includes("Varför hade kronan"));
});

Deno.test("K110 (printing 11/14, refill 0 of 3 and 0 repeats): questions given as objects are read too", async () => {
  const p = llm([{ questions: [{ i: 0, q: "How did printing change the way scientists worked?" }, { question: "Why did the Church lose control over ideas?" }] }]);
  const r = await refillQuestions(p, DEFAULT_DRILL_CONFIG, ["Why were books rare before printing?"], 2, "Printing changed Europe.");
  assertEquals(r.questions, ["How did printing change the way scientists worked?", "Why did the Church lose control over ideas?"]);
});
