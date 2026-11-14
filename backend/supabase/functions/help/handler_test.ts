import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { ANSWERS_DEF, createHelpHandler, isAnswersQuestion, isPressQuestion, OUT_OF_SCOPE, parseHelp, PRESSES, SYSTEM_PROMPT_HELP, UNKNOWN } from "./handler.ts";

const post = (b: unknown) => new Request("http://x/help", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(b) });
function llm(reply: (req: LLMRequest) => string): LLMProvider & { calls: LLMRequest[] } {
  return {
    name: "f",
    model: "haiku",
    calls: [],
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      this.calls.push(req);
      yield { type: "text", text: reply(req) };
      yield { type: "usage", inputTokens: 3000, outputTokens: 80 };
    },
  };
}
const mk = (p: LLMProvider, used = 0, lim = 15) => {
  let u = used;
  return createHelpHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: p,
    useQuota: (_u, n) => {
      if (n > 0 && u + n > lim) return Promise.resolve({ ok: false, used: u, lim });
      u += n;
      return Promise.resolve({ ok: true, used: u, lim });
    },
  });
};

Deno.test("K57 the help knows the app: the help text and the capability list are in the cached system prompt", () => {
  assert(SYSTEM_PROMPT_HELP.includes("Medan frågan spelas: 1 tryck = det långa A-svaret. 2 tryck = det korta A-svaret, en till två meningar. 3 tryck = paus."));
  assert(SYSTEM_PROMPT_HELP.includes("Det här finns inte i Earmind"));
  assert(SYSTEM_PROMPT_HELP.includes("Publicera prov"));
  assert(SYSTEM_PROMPT_HELP.includes("Styra Spotify (spela, pausa, nästa låt): kommer snart"));
});

Deno.test("K57 outside the app: exactly 'Det kan jag inte svara på.' with a hint; broken reply = 'Det vet jag inte'", async () => {
  const p = llm(() => JSON.stringify({ in_scope: false, answer: "Fotosyntes är ..." }));
  const j = await (await mk(p)(post({ question: "Vad är fotosyntes?" }))).json();
  assertEquals([j.answer, j.in_scope, typeof j.hint], [OUT_OF_SCOPE, false, "string"]);
  assertEquals(parseHelp("trasigt"), { in_scope: true, answer: UNKNOWN });
  assertEquals(parseHelp(JSON.stringify({ in_scope: true, answer: "Så här börjar du:\n1. Tryck Nytt prov." })).answer, "1. Tryck Nytt prov.");
  const ok = llm(() => JSON.stringify({ in_scope: true, answer: "Tryck **Dela** på provet." }));
  assertEquals((await (await mk(ok)(post({ question: "Hur delar jag?" }))).json()).answer, "Tryck Dela på provet.");
  assertEquals((await mk(ok)(post({}))).status, 400);
});

Deno.test("K57 try: three questions with answers from a short text, counted as 3 only when made; 402 when not left", async () => {
  const p = llm((req) => {
    if (req.system.includes("revision list")) return JSON.stringify({ summary: { subject: "Biologi", grade: "åk 8", covers: "x" }, notes: "n", questions_possible: 3, questions: ["Varför A?", "Varför B?", "Varför C?"] });
    if (req.system.includes("You check Swedish exam questions")) return JSON.stringify({ questions: [] });
    const qs = JSON.parse(/<questions>([\s\S]*)<\/questions>/.exec(req.user)![1]) as { id: string }[];
    return JSON.stringify({ answers: qs.map((q) => ({ id: q.id, short: "Ett riktigt svar här.", rest: "Mer." })) });
  });
  const text = "Fotosyntes sker i kloroplasterna. Klorofyll fångar ljus. Växten bildar glukos och syre av koldioxid och vatten.";
  const j = await (await mk(p, 0)(post({ action: "try", text }))).json();
  assertEquals(j.items.length, 3);
  assertEquals(j.quota, { used: 3, limit: 15 });
  const full = await mk(p, 13)(post({ action: "try", text }));
  assertEquals(full.status, 402);
  assertEquals((await full.json()).error.message, "Du har inga frågor kvar den här månaden.");
  assertEquals((await mk(p)(post({ action: "try", text: "kort" }))).status, 400);
});

Deno.test("K57 the presses are always Aron's text word for word (Ke57 rule 3)", async () => {
  for (const q of ["Hur fungerar trycken?", "Vad händer om jag trycker två gånger?", "Hur pausar jag?", "Hur fortsätter jag efter paus?", "Hur styr jag med AirPods?",
    "hur får jag det långa svaret", "hur får jag höra svaret på en fråga", "hur får jag det korta svaret", "vilka tryck finns det", "hur får jag fram svaret", "jag vill höra hela förklaringen"]) {
    assert(isPressQuestion(q), q);
  }
  for (const q of ["Vad gör jag om ett tryck inte kommer fram?", "Fungerar det med gamla AirPods?", "Hur delar jag ett prov?", "jag har gamla airpods, hur får jag det korta svaret", "vad är det korta svaret", "kan jag få längre svar"]) assert(!isPressQuestion(q), q);
  const p = llm(() => JSON.stringify({ in_scope: true, answer: "Under en fråga trycker du en gång ..." }));
  assertEquals((await (await mk(p)(post({ question: "Hur fungerar trycken?" }))).json()).answer, PRESSES);
});

Deno.test("K60 what the short and the long answer are is fixed text", async () => {
  for (const q of ["vad är det korta svaret", "Vad är det långa svaret?", "Vad är skillnaden mellan kort och långt svar?"]) assert(isAnswersQuestion(q), q);
  assert(!isAnswersQuestion("hur får jag det korta svaret"));
  const p = llm(() => JSON.stringify({ in_scope: true, answer: "Det första svaret i en fråga." }));
  assertEquals((await (await mk(p)(post({ question: "vad är det korta svaret" }))).json()).answer, ANSWERS_DEF);
});
