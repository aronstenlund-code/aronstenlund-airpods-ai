import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { commandTask } from "./commands.ts";
import { createHandler, DEFAULT_CONFIG, type Deps } from "./handler.ts";
import { type LLMChunk, type LLMProvider } from "./llm/types.ts";

Deno.test("K12.1 'för mig' is kept when it carries meaning, dropped when it is only polite", () => {
  assertEquals(commandTask("hur går det för mig", "study")?.task, "self_assessment");
  assertEquals(commandTask("Lumen, ge mig ett exempel för mig", "study")?.task, "example");
  assertEquals(commandTask("sammanfatta det för mig", "study")?.task, "summary");
});

Deno.test("K12.2 'mina sämsta områden' is weak_areas, never a quiz topic", () => {
  assertEquals(commandTask("förhör mig på mina sämsta områden", "study")?.task, "weak_areas");
  assertEquals(commandTask("testa mig på mina svaga begrepp", "study")?.task, "weak_areas");
  const q = commandTask("förhör mig på fotosyntesen", "study");
  assertEquals(q?.task, "quiz_topic");
  assertEquals(q?.arg, "fotosyntesen");
});

Deno.test("K12.3 'göra' after 'kan du' matches like 'gör'", () => {
  assertEquals(commandTask("kan du göra det roligare", "social")?.task, "social:funnier");
  assertEquals(commandTask("kan du göra svaret bättre", "interview")?.task, "interview_help:better");
  assertEquals(commandTask("gör det roligare", "social")?.task, "social:funnier");
});

Deno.test("K12.4 a summary ends without a check question unless asked", () => {
  assert(commandTask("sammanfatta", "study")!.rule.includes("no check question"));
});

Deno.test("K12.5 instructions have their own budget: 4 in a row never get 429 after a full minute of questions", async () => {
  const provider: LLMProvider = {
    name: "s",
    model: "s",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        yield { type: "text", text: "Okej." };
        yield { type: "usage", inputTokens: 10, outputTokens: 2 };
      })(),
  };
  const deps: Deps = {
    authenticate: () => Promise.resolve({ id: "u-k12", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, limits: { perMinute: 3, perDay: 100, globalPerDay: 1000 } },
  };
  const h = createHandler(deps);
  const ask = (fragment: string) =>
    h(new Request("http://x/answer", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ fragment, mode: "push_to_talk", language: "sv", context: { recent_qa: [{ q: "vad är en atom", a: "En atom är den minsta delen av ett grundämne." }] } }),
    }));
  for (let i = 0; i < 3; i++) await (await ask(`vad är en atom nummer ${i}`)).text();
  assertEquals((await ask("vad är en molekyl")).status, 429, "the question budget is used up");
  for (const f of ["ge mig ett exempel", "sammanfatta", "förhör mig på atomer", "en mening", "mer", "kortare"]) {
    const r = await ask(f);
    await r.text();
    assertEquals(r.status, 200, f);
  }
});

Deno.test("K13 (O10 #7) at the cap the answer ends after the last whole sentence, no stray bracket", async () => {
  const sentences = Array.from({ length: 30 }, (_, i) => `Det här är mening nummer ${i + 1} i svaret.`).join(" ") + " [";
  const provider: LLMProvider = {
    name: "s",
    model: "s",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        for (let k = 0; k < sentences.length; k += 7) yield { type: "text", text: sentences.slice(k, k + 7) };
      })(),
  };
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-cap", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, maxAnswerChars: 600, maxAnswerCharsStudy: 600 },
  });
  const res = await h(new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ fragment: "berätta om svaret", mode: "push_to_talk", language: "sv", context: {} }),
  }));
  const txt = (await res.text()).split("\n\n").filter((f) => f.startsWith("event: delta"))
    .map((f) => JSON.parse(/^data: (.*)$/m.exec(f)![1]).text).join("");
  assert(txt.length <= 600, String(txt.length));
  assert(/\.$/.test(txt.trim()), txt.slice(-40));
  assert(!txt.includes("["));
});
