import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps, type UsageRecord } from "./handler.ts";
import { MockProvider } from "./llm/mock.ts";
const SUMMARY_TOKENS = 80; // D48 trailer budget
import { type LLMChunk, type LLMProvider, LLMProviderError } from "./llm/types.ts";

interface Sse {
  event: string;
  data: Record<string, unknown>;
}
async function readSse(res: Response): Promise<Sse[]> {
  const text = await res.text();
  return text.split("\n\n").filter(Boolean).map((f) => {
    const event = /^event: (.*)$/m.exec(f)![1];
    return { event, data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) };
  });
}

function setup(over: Partial<Deps> = {}) {
  const usage: UsageRecord[] = [];
  const deps: Deps = {
    authenticate: () => Promise.resolve({ id: "user-1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: new MockProvider(),
    recordUsage: (r) => void usage.push(r),
    config: DEFAULT_CONFIG,
    ...over,
  };
  return { handler: createHandler(deps), usage };
}
const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
const body = (o: Record<string, unknown> = {}) => ({
  fragment: "fem plus två",
  mode: "push_to_talk",
  language: "sv",
  context: {},
  ...o,
});

Deno.test("streams meta, deltas, done in order and logs usage", async () => {
  const { handler, usage } = setup();
  const res = await handler(post(body()));
  assertEquals(res.status, 200);
  assert(res.headers.get("content-type")!.startsWith("text/event-stream"));
  const ev = await readSse(res);
  assertEquals(ev[0].event, "meta");
  assertEquals(ev[0].data.is_question, true);
  assertEquals(ev[0].data.reconstructed_question, "fem plus två");
  assertEquals(ev[0].data.confidence, 1, "direct mode synthesises the meta");
  assert(ev.slice(1, -1).length > 0 && ev.slice(1, -1).every((e) => e.event === "delta"));
  const answer = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertEquals(answer, "Mocksvar på: fem plus två.");
  const done = ev.at(-1)!;
  assertEquals(done.event, "done");
  assertEquals(done.data.answered, true);
  const bd = done.data.breakdown as Record<string, unknown>;
  assertEquals(bd.direct, true);
  assertEquals(bd.cold, true);
  assert(
    typeof bd.auth_ms === "number" && typeof bd.limits_ms === "number" &&
      typeof bd.llm_first_chunk_ms === "number",
  );
  const timing = done.data.timing as Record<string, number>;
  assert(timing.meta_ms <= timing.ttft_ms && timing.ttft_ms <= timing.total_ms);
  assertEquals(usage.length, 1);
  assertEquals(usage[0].status, "ok");
  assertEquals(usage[0].user_id, "user-1");
  assert(usage[0].input_tokens! > 0 && usage[0].output_tokens! > 0 && usage[0].est_cost_usd! > 0);
});

Deno.test("auto mode: non-question gets meta(is_question=false) and nothing else answered", async () => {
  const { handler, usage } = setup();
  const ev = await readSse(
    await handler(post(body({ mode: "auto", fragment: "ja det var ju trevligt igår" }))),
  );
  assertEquals(ev.map((e) => e.event), ["meta", "done"]);
  assertEquals(ev[0].data.is_question, false);
  assertEquals(ev[1].data.answered, false);
  assertEquals(usage[0].status, "not_question");
});

Deno.test("header mode (auto, or directModes off): low confidence is flagged for a confirmation question", async () => {
  const { handler } = setup({ config: { ...DEFAULT_CONFIG, directModes: false } });
  const ev = await readSse(await handler(post(body({ fragment: "ro" }))));
  assertEquals(ev[0].data.needs_confirmation, true);
  assertEquals(
    ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""),
    "Menar du det?",
  );
});

Deno.test("401 without valid auth, and nothing is called", async () => {
  let called = false;
  const { handler } = setup({
    authenticate: () => Promise.reject(new HttpError(401, "unauthorized", "no")),
    provider: {
      name: "x",
      model: "x",
      stream: () => {
        called = true;
        return (async function* () {})();
      },
    },
  });
  const res = await handler(post(body()));
  assertEquals(res.status, 401);
  assertEquals((await res.json()).error.code, "unauthorized");
  assertEquals(called, false);
});

Deno.test("429 with Retry-After once the per-minute limit is hit", async () => {
  const { handler } = setup({
    config: { ...DEFAULT_CONFIG, limits: { perMinute: 2, perDay: 100, globalPerDay: 100 } },
  });
  for (let i = 0; i < 2; i++) {
    const r = await handler(post(body()));
    assertEquals(r.status, 200);
    await r.text();
  }
  const res = await handler(post(body()));
  assertEquals(res.status, 429);
  assert(Number(res.headers.get("retry-after")) > 0);
  assertEquals((await res.json()).error.fallback, true);
});

Deno.test("request validation: 400 bad json / fields, 413 oversize", async () => {
  const { handler } = setup();
  assertEquals((await handler(post("{nope"))).status, 400);
  assertEquals((await handler(post(body({ mode: "x" })))).status, 400);
  assertEquals((await handler(post(body({ fragment: "a".repeat(1001) })))).status, 413);
  assertEquals((await handler(post(body(), { "content-length": "999999" }))).status, 413);
  assertEquals((await handler(new Request("http://x", { method: "GET" }))).status, 405);
});

Deno.test("no provider configured -> 503 provider_unconfigured with fallback flag", async () => {
  const { handler } = setup({ provider: null });
  const res = await handler(post(body()));
  assertEquals(res.status, 503);
  const e = (await res.json()).error;
  assertEquals([e.code, e.fallback], ["provider_unconfigured", true]);
});

function failingProvider(kind: ConstructorParameters<typeof LLMProviderError>[0]): LLMProvider {
  return {
    name: "f",
    model: "f",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        throw new LLMProviderError(kind, "boom");
      })(),
  };
}

Deno.test("out of credits -> 503 provider_quota (app falls back), usage logged", async () => {
  const { handler, usage } = setup({ provider: failingProvider("quota") });
  const res = await handler(post(body()));
  assertEquals(res.status, 503);
  const e = (await res.json()).error;
  assertEquals([e.code, e.fallback], ["provider_quota", true]);
  assertEquals(usage[0].status, "provider_error");
});

Deno.test("other provider failures map to 5xx with fallback", async () => {
  for (
    const [kind, status, code] of [["auth", 503, "provider_misconfigured"], [
      "rate_limited",
      503,
      "provider_busy",
    ], ["unavailable", 502, "provider_unavailable"]] as const
  ) {
    const { handler } = setup({ provider: failingProvider(kind) });
    const res = await handler(post(body()));
    assertEquals([res.status, (await res.json()).error.code], [status, code]);
  }
});

Deno.test("error after the first chunk arrives as an SSE error event with fallback", async () => {
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        yield {
          type: "text",
          text: '{"is_question":true,"reconstructed_question":"q","confidence":0.9}\nHej då. Hal',
        };
        throw new LLMProviderError("unavailable", "dropped");
      })(),
  };
  const { handler, usage } = setup({ provider });
  const ev = await readSse(await handler(post(body())));
  assertEquals(ev.map((e) => e.event), ["meta", "delta", "error"]);
  assertEquals(ev[2].data.fallback, true);
  assertEquals(usage[0].status, "provider_unavailable");
});

Deno.test("empty answer for a real question is reported, not silently dropped", async () => {
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        yield {
          type: "text",
          text: '{"is_question":true,"reconstructed_question":"q","confidence":0.9}',
        };
      })(),
  };
  const { handler } = setup({ provider });
  const ev = await readSse(await handler(post(body({ mode: "auto", fragment: "vad är pi" }))));
  assertEquals(ev.map((e) => e.event), ["meta", "error", "done"]);
  assertEquals(ev[1].data.code, "empty_answer");
});

Deno.test("overlong answers are cut off at maxAnswerChars", async () => {
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        yield {
          type: "text",
          text: '{"is_question":true,"reconstructed_question":"q","confidence":0.9}\n',
        };
        for (let i = 0; i < 100; i++) yield { type: "text", text: "abcde ".repeat(8) };
      })(),
  };
  const { handler, usage } = setup({
    provider,
    config: { ...DEFAULT_CONFIG, maxAnswerChars: 120 },
  });
  const ev = await readSse(await handler(post(body())));
  const n = ev.filter((e) => e.event === "delta").reduce(
    (a, e) => a + (e.data.text as string).length,
    0,
  );
  assert(n >= 120 && n <= 200, `n=${n}`);
  assertEquals(usage[0].status, "truncated");
});

Deno.test("client disconnect aborts the provider", async () => {
  let signal: AbortSignal | undefined;
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: (r) => {
      signal = r.signal;
      return (async function* (): AsyncGenerator<LLMChunk> {
        yield {
          type: "text",
          text: '{"is_question":true,"reconstructed_question":"q","confidence":0.9}\nA',
        };
        for (let i = 0; i < 50; i++) {
          await new Promise((res) => setTimeout(res, 5));
          yield { type: "text", text: "b" };
        }
      })();
    },
  };
  const { handler } = setup({ provider });
  const res = await handler(post(body()));
  const reader = res.body!.getReader();
  await reader.read();
  await reader.cancel();
  await new Promise((r) => setTimeout(r, 50));
  assertEquals(signal?.aborted, true);
});

Deno.test("direct mode: a model-side confirmation question is just the answer text, no meta change", async () => {
  const { handler } = setup();
  const ev = await readSse(await handler(post(body({ fragment: "ro" }))));
  assertEquals(ev[0].data.needs_confirmation, false);
  assertEquals(
    ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""),
    "Menar du det?",
  );
});

Deno.test("direct mode sends meta before the first delta and never waits for a JSON header", async () => {
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        yield { type: "text", text: "  Sju" };
        yield { type: "text", text: "." };
      })(),
  };
  const { handler } = setup({ provider });
  const ev = await readSse(await handler(post(body())));
  assertEquals(ev.map((e) => e.event), ["meta", "delta", "done"]);
  assertEquals(ev[1].data.text, "Sju.", "leading whitespace trimmed");
});

Deno.test("shared limiter runs in parallel with the LLM start; a denial aborts the LLM and sends nothing", async () => {
  let started = false;
  let signal: AbortSignal | undefined;
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: (r) => {
      signal = r.signal;
      started = true;
      return (async function* (): AsyncGenerator<LLMChunk> {
        await new Promise((res) => setTimeout(res, 20));
        yield { type: "text", text: "Svar." };
      })();
    },
  };
  const denying = { check: () => Promise.resolve({ allowed: false, retryAfterSec: 7 }) };
  const { handler } = setup({ provider, rateLimiter: denying });
  const res = await handler(post(body()));
  assertEquals(res.status, 429);
  assertEquals(res.headers.get("retry-after"), "7");
  assertEquals(started, true, "LLM was started speculatively");
  assertEquals(signal?.aborted, true, "and aborted on denial");
  assert(!(await res.text()).includes("Svar"));
});

Deno.test("limiter and LLM really overlap (total ~ max, not sum)", async () => {
  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
  const ok = async () => {
    await sleep(60);
    return { allowed: true, retryAfterSec: 0 };
  };
  const slowLimiter = { check: ok, checkMany: ok };
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: () =>
      (async function* (): AsyncGenerator<LLMChunk> {
        await sleep(60);
        yield { type: "text", text: "Ja." };
      })(),
  };
  const { handler } = setup({ provider, rateLimiter: slowLimiter });
  const t = performance.now();
  const res = await handler(post(body()));
  const dt = performance.now() - t;
  await res.text();
  assertEquals(res.status, 200);
  assert(dt < 105, `expected overlap (<105 ms), got ${dt.toFixed(0)} ms`);
});

Deno.test("local per-isolate guard stops a user before the LLM is ever called", async () => {
  let calls = 0;
  const provider: LLMProvider = {
    name: "m",
    model: "m",
    stream: () => {
      calls++;
      return new MockProvider().stream({
        system: "",
        user: "<fragment>vad är pi</fragment>",
        maxTokens: 10,
      });
    },
  };
  const { handler } = setup({
    provider,
    localLimiter: new MemoryRateLimiter(),
    config: { ...DEFAULT_CONFIG, limits: { perMinute: 2, perDay: 100, globalPerDay: 100 } },
  });
  const q = () => post(body({ fragment: "vad är roten ur hundra" }));
  for (let i = 0; i < 2; i++) await (await handler(q())).text();
  const res = await handler(q());
  assertEquals(res.status, 429);
  assertEquals(calls, 2);
});

Deno.test("GET with x-warm:1 triggers the upstream warm-up and answers 204 without auth", async () => {
  let warmed = 0;
  const { handler } = setup({
    warm: () => {
      warmed++;
    },
    authenticate: () => Promise.reject(new HttpError(401, "unauthorized", "no")),
  });
  const res = await handler(new Request("http://x", { method: "GET", headers: { "x-warm": "1" } }));
  assertEquals([res.status, warmed], [204, 1]);
  assertEquals((await handler(new Request("http://x", { method: "GET" }))).status, 405);
});

// ---- D35: adaptive length, fewer confirmations ----
function recordingProvider(text = "Svar.") {
  const seen: { system: string; user: string; maxTokens: number; model?: string }[] = [];
  const provider: LLMProvider = {
    name: "rec",
    model: "rec",
    stream: (r) => {
      seen.push({ system: r.system, user: r.user, maxTokens: r.maxTokens, model: r.model });
      return (async function* (): AsyncGenerator<LLMChunk> {
        for (let k = 0; k < text.length; k += 23) {
          yield { type: "text", text: text.slice(k, k + 23) };
        }
      })();
    },
  };
  return { provider, seen };
}

Deno.test("D35: fact request -> short prompt, 256 tokens, answer_type fact in meta", async () => {
  const { provider, seen } = recordingProvider();
  const { handler } = setup({ provider });
  const ev = await readSse(await handler(post(body({ fragment: "när föll berlinmuren" }))));
  assertEquals(ev[0].data.answer_type, "fact");
  assertEquals(seen[0].maxTokens, 256 + SUMMARY_TOKENS);
  assert(seen[0].system.includes("at most two short sentences"));
});

Deno.test("D35: study request -> developed prompt, 800 tokens, answer_type study", async () => {
  const { provider, seen } = recordingProvider();
  const { handler } = setup({ provider });
  const ev = await readSse(await handler(post(body({ fragment: "elbilar procons" }))));
  assertEquals(ev[0].data.answer_type, "study");
  assertEquals(ev[0].data.needs_confirmation, false);
  assertEquals(seen[0].maxTokens, 800 + SUMMARY_TOKENS);
  assert(seen[0].system.includes("five to eight short sentences"));
  const done = ev.at(-1)!.data.breakdown as Record<string, unknown>;
  assertEquals(done.answer_type, "study");
});

Deno.test("D35: length setting short/long overrides, invalid value -> 400", async () => {
  const a = recordingProvider();
  const h1 = setup({ provider: a.provider }).handler;
  await (await h1(post(body({ fragment: "förklara växthuseffekten", length: "short" })))).text();
  assertEquals(a.seen[0].maxTokens, 256 + SUMMARY_TOKENS);
  const b = recordingProvider();
  const h2 = setup({ provider: b.provider }).handler;
  await (await h2(post(body({ fragment: "vad är pi", length: "long" })))).text();
  assertEquals(b.seen[0].maxTokens, 800 + SUMMARY_TOKENS);
  const h3 = setup().handler;
  assertEquals((await h3(post(body({ length: "enormous" })))).status, 400);
});

Deno.test("D35: 'mer' / 'förklara enklare' continue the last answer when history exists", async () => {
  const { provider, seen } = recordingProvider();
  const { handler } = setup({ provider });
  const ctx = { recent_qa: [{ q: "elbilar procons", a: "Fördelarna är låga utsläpp." }] };
  await (await handler(post(body({ fragment: "mer", context: ctx })))).text();
  assert(seen[0].user.includes("<task>continue_more</task>"));
  assert(seen[0].user.includes("A: Fördelarna är låga utsläpp."));
  assertEquals(seen[0].maxTokens, 800 + SUMMARY_TOKENS + 12);
  await (await handler(post(body({ fragment: "förklara det enklare", context: ctx })))).text();
  assert(seen[1].user.includes("<task>continue_simpler</task>"));
  await (await handler(post(body({ fragment: "mer" })))).text();
  assert(!seen[2].user.includes("<task>"), "no history -> not a continuation");
});

Deno.test("D35: study answers may be long (1 800 chars) while fact answers are still cut at 600", async () => {
  const long = "Ett mycket långt svar. ".repeat(60); // ~1 400 chars
  const study = recordingProvider(long);
  const hs = setup({ provider: study.provider }).handler;
  const evS = await readSse(await hs(post(body({ fragment: "förklara växthuseffekten" }))));
  const nS = evS.filter((e) => e.event === "delta").reduce(
    (a, e) => a + (e.data.text as string).length,
    0,
  );
  assert(nS > 1300, `study kept ${nS}`);
  const fact = recordingProvider(long);
  const hf = setup({ provider: fact.provider }).handler;
  const evF = await readSse(await hf(post(body({ fragment: "vad är pi" }))));
  const nF = evF.filter((e) => e.event === "delta").reduce(
    (a, e) => a + (e.data.text as string).length,
    0,
  );
  assert(nF <= 700 && nF >= 590, `fact kept ${nF}`);
});

Deno.test("D36: mode tutor -> tutor prompt, study budget, no header, always a question, history sent", async () => {
  const { provider, seen } = recordingProvider();
  const { handler, usage } = setup({ provider });
  const ctx = {
    recent_qa: [{ q: "vad är en enzym", a: "Enzymer är proteiner som påskyndar reaktioner." }],
  };
  const ev = await readSse(
    await handler(
      post(body({ mode: "tutor", fragment: "och hur påverkas de av temperatur", context: ctx })),
    ),
  );
  assertEquals(ev[0].data.answer_type, "study");
  assertEquals(ev[0].data.is_question, true);
  assertEquals(ev[0].data.needs_confirmation, false);
  assertEquals(seen[0].maxTokens, 800 + SUMMARY_TOKENS + 12);
  assert(seen[0].system.includes("tutoring in a spoken conversation"));
  assert(!seen[0].system.includes("is_question"), "tutor is headerless");
  assert(seen[0].user.includes("A: Enzymer är proteiner som påskyndar reaktioner."));
  assertEquals(usage[0].mode, "tutor");
});

Deno.test("D37: goals and commands reach the prompt; commands force a developed answer", async () => {
  const { provider, seen } = recordingProvider();
  const { handler } = setup({ provider });
  const ev = await readSse(
    await handler(post(body({
      fragment: "mitos",
      goals: "Kursen ska ge förståelse för cellbiologi på gymnasienivå.",
      commands: [{ keyword: "mitos", instruction: "förklara mitos och jämför med meios" }],
    }))),
  );
  assertEquals(ev[0].data.answer_type, "study");
  assertEquals(seen[0].maxTokens, 800 + SUMMARY_TOKENS);
  assert(
    seen[0].user.includes(
      "<goals>\nKursen ska ge förståelse för cellbiologi på gymnasienivå.\n</goals>",
    ),
  );
  assert(seen[0].user.includes("- mitos: förklara mitos och jämför med meios"));
  const none = recordingProvider();
  await (await setup({ provider: none.provider }).handler(post(body({ fragment: "enzym" }))))
    .text();
  assertEquals(none.seen[0].maxTokens, 256 + SUMMARY_TOKENS);
  assert(!none.seen[0].user.includes("<goals>") && !none.seen[0].user.includes("<commands>"));
});

Deno.test("D35: a confirmation in the middle of the history is dropped, a trailing one is flagged", async () => {
  const { provider, seen } = recordingProvider();
  const { handler } = setup({ provider });
  const ctx = {
    recent_qa: [
      { q: "enzym", a: "Enzymer påskyndar reaktioner." },
      { q: "x", a: "Menar du något annat?" },
      { q: "kofaktor", a: "En kofaktor hjälper enzymet." },
    ],
  };
  await (await handler(post(body({ fragment: "mer om det", context: ctx })))).text();
  assert(!seen[0].user.includes("Menar du något annat"));
  assert(seen[0].user.includes("<last_assistant_turn>answer</last_assistant_turn>"));
  await (await handler(
    post(body({ fragment: "ja", context: { recent_qa: [{ q: "k", a: "Menar du kofaktorer?" }] } })),
  )).text();
  assert(seen[1].user.includes("<last_assistant_turn>confirmation</last_assistant_turn>"));
  assert(seen[1].user.includes("A: Menar du kofaktorer?"));
});

// ---- D42 personas ----
Deno.test("D42/D72 interview: question -> perfect answer prompt with the role, 500 tokens; own answer -> improved version; klar -> summary", async () => {
  const { provider, seen } = recordingProvider();
  const { handler } = setup({ provider });
  const common = {
    mode: "tutor",
    persona: "interview",
    persona_setup: "Lagerarbetare, truckkort krävs",
  };
  const ev = await readSse(
    await handler(post(body({ ...common, fragment: "berätta om en gång du löste ett problem" }))),
  );
  assertEquals(ev[0].data.is_question, true);
  assertEquals(ev[0].data.needs_confirmation, false);
  assert(seen[0].system.includes("interview coach") && seen[0].system.includes("STAR"));
  assert(seen[0].user.includes("<task>interview_question</task>"));
  assert(seen[0].user.includes("Lagerarbetare, truckkort krävs"));
  assertEquals(seen[0].maxTokens, 500 + SUMMARY_TOKENS);
  await (await handler(
    post(
      body({
        ...common,
        turn: "user_answer",
        fragment: "Jag packade om en pall som var fel märkt.",
        context: {
          recent_qa: [{ q: "berätta om en gång du löste ett problem", a: "Struktur: STAR." }],
        },
      }),
    ),
  )).text();
  assert(seen[1].user.includes("<task>interview_improve</task>"));
  assertEquals(seen[1].maxTokens, 500 + SUMMARY_TOKENS);
  await (await handler(post(body({ ...common, fragment: "klar" })))).text();
  assert(seen[2].user.includes("<task>interview_summary</task>"), "DECISIONS D72: klar = summary");
  await (await handler(post(body({ ...common, fragment: "sammanfatta" })))).text();
  assert(seen[3].user.includes("<task>interview_summary</task>"));
  assertEquals(seen[3].maxTokens, 450 + SUMMARY_TOKENS);
});

Deno.test("D42 social: one short suggestion, tiny budget, scenario passed, no history confirmation logic", async () => {
  const { provider, seen } = recordingProvider("Låter kul, vilken låt gillade du mest?");
  const { handler } = setup({ provider });
  const ev = await readSse(
    await handler(
      post(
        body({
          mode: "tutor",
          persona: "social",
          persona_setup: "Fika med en kompis efter skolan",
          fragment: "jag var på en konsert i helgen",
        }),
      ),
    ),
  );
  assertEquals(
    ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""),
    "Låter kul, vilken låt gillade du mest?",
  );
  assert(seen[0].system.includes("knows that the app listens"));
  assert(seen[0].user.includes("<task>social_suggestion</task>"));
  assert(seen[0].user.includes("Fika med en kompis efter skolan"));
  assertEquals(seen[0].maxTokens, 160 + SUMMARY_TOKENS);
});

Deno.test("D42 interview_prep: needs persona_setup, five-question prompt, big budget and cap", async () => {
  const { provider, seen } = recordingProvider("Fråga ett: Varför söker du?\nSvar: Jag ...");
  const { handler } = setup({ provider });
  assertEquals(
    (await handler(post(body({ mode: "interview_prep", fragment: "förbered mig" })))).status,
    400,
  );
  const ev = await readSse(
    await handler(
      post(
        body({
          mode: "interview_prep",
          fragment: "förbered mig",
          persona_setup: "Kundtjänst, deltid, kvällar",
        }),
      ),
    ),
  );
  assertEquals(ev[0].data.answer_type, "study");
  assert(seen[0].system.includes("exactly five likely interview questions"));
  assert(
    seen[0].user.includes("<task>interview_prep</task>") &&
      seen[0].user.includes("Kundtjänst, deltid, kvällar"),
  );
  assertEquals(seen[0].maxTokens, 1200 + SUMMARY_TOKENS);
});

Deno.test("D42: persona never applies in auto mode; ordinary tutor flow untouched", async () => {
  const a = recordingProvider();
  await (await setup({ provider: a.provider }).handler(
    post(body({ mode: "auto", persona: "social", fragment: "vad är en enzym" })),
  )).text();
  assert(a.seen[0].system.includes("OUTPUT (strict)"), "header protocol");
  const b = recordingProvider();
  await (await setup({ provider: b.provider }).handler(
    post(body({ mode: "tutor", fragment: "enzym" })),
  )).text();
  assert(b.seen[0].system.includes("tutoring in a spoken conversation"));
});

// ---- D43 Rizzläge ----
const socialBody = (o: Record<string, unknown> = {}) => ({
  fragment: "",
  mode: "tutor",
  language: "sv",
  persona: "social",
  context: {},
  social: {
    style: "rolig",
    trigger: "other_spoke",
    transcript: [{ speaker: "other", text: "Jag har tränat inför ett lopp i helgen." }],
    interests: ["löpning"],
    profile: "",
  },
  ...o,
});

const CANDS =
  "1|Vilket lopp är det?\n2|Hoppas det blir sol!\n3|Vad springer du helst?\n4|En fjärde?\nTOP: 1,2,3\n";
Deno.test("D52: Rizz = 5 candidates + TOP -> ONE suggestions event with the 3 picked, best first; Sonnet model + cost", async () => {
  const { provider, seen } = recordingProvider(CANDS);
  const { handler, usage } = setup({ provider });
  const ev = await readSse(await handler(post(socialBody())));
  // D63: the strongest line (candidate 1) is previewed at once, the full list follows
  assertEquals(ev.map((e) => e.event), ["suggestion_preview", "suggestions", "done"]);
  assertEquals(ev[0].data.text, "Vilket lopp är det?");
  // D72: exactly one suggestion, the best (the model's line 1)
  assertEquals(ev[1].data as unknown, ["Vilket lopp är det?"]);
  assertEquals(ev[2].data.answered, true);
  assertEquals(seen[0].maxTokens, 100);
  assertEquals(seen[0].model, "claude-sonnet-5-5");
  assert(seen[0].system.includes("conversation wingman"));
  assert(
    seen[0].user.includes("<style>social</style>") &&
      seen[0].user.includes("<stage>middle</stage>") &&
      seen[0].user.includes("Den andra: Jag har tränat inför ett lopp i helgen."),
  );
  assertEquals(usage[0].mode, "tutor");
  assertEquals(usage[0].model, "claude-sonnet-5-5");
  assert(usage[0].ttft_ms !== null);
});

Deno.test("D43: unsafe or over-long output is filtered; if nothing is left, a safe fallback is sent", async () => {
  const { provider } = recordingProvider("Du har så sexig kropp\nVill du ligga med mig?");
  const { handler, usage } = setup({ provider });
  const ev = await readSse(await handler(post(socialBody())));
  assertEquals(ev[0].event, "suggestions");
  assertEquals(ev[0].data as unknown, ["Berätta mer om det."]);
  assertEquals(usage[0].status, "filtered");
  const d = await readSse(
    await setup({ provider }).handler(
      post(
        socialBody({
          social: {
            ...socialBody().social,
            transcript: [{ speaker: "other", text: "Nej tack, sluta." }],
          },
        }),
      ),
    ),
  );
  assertEquals(d[0].data as unknown, ["Okej, helt lugnt."]);
});

Deno.test("D43: decline signal and stall/opener triggers (no fragment) reach the prompt", async () => {
  const { provider, seen } = recordingProvider("Okej, ingen fara.");
  const { handler } = setup({ provider });
  await (await handler(
    post(
      socialBody({
        social: {
          ...socialBody().social,
          transcript: [{ speaker: "other", text: "Jag måste gå nu." }],
        },
      }),
    ),
  )).text();
  assert(seen[0].user.includes("<signal>decline</signal>"));
  await (await handler(post(socialBody({ social: { ...socialBody().social, trigger: "stall" } }))))
    .text();
  assert(seen[1].user.includes("<trigger>stall</trigger>"));
  await (await handler(
    post(
      socialBody({
        social: {
          style: "uppriktig",
          trigger: "opener",
          transcript: [],
          interests: ["bergsklättring"],
          profile: "Gillar indisk mat.",
        },
      }),
    ),
  )).text();
  assert(
    seen[2].user.includes("<trigger>opener</trigger>") &&
      seen[2].user.includes("Gillar indisk mat.") && seen[2].user.includes("(inget sagt ännu)"),
  );
});

Deno.test("D43: empty model output -> fallback suggestions (never an empty array); old D42 social path unchanged", async () => {
  const { handler } = setup({ provider: recordingProvider("").provider });
  const ev = await readSse(await handler(post(socialBody())));
  assertEquals(ev[0].event, "suggestions");
  assertEquals((ev[0].data as unknown as string[]).length, 1);
  const old = recordingProvider("Låter kul!");
  const e2 = await readSse(
    await setup({ provider: old.provider }).handler(
      post(body({ mode: "tutor", persona: "social", fragment: "jag var på konsert" })),
    ),
  );
  assertEquals(e2.map((e) => e.event).slice(0, 2), ["meta", "delta"]);
});

Deno.test("D52: candidates over 10 words or unsafe are dropped and the pick is topped up; stream ends at the TOP line", async () => {
  const { provider } = recordingProvider(
    "1|a|Ett två tre fyra fem sex sju åtta nio tio elva\n2|b|Vilket lopp?\n3|c|Hoppas det blir sol!\n4|d|Vill du ligga med mig?\n5|e|Vad springer du helst?\nTOP: 1,4,3\nEftersnack som aldrig ska läsas",
  );
  const { handler } = setup({ provider });
  const ev = await readSse(
    await handler(post(socialBody({ social: { ...socialBody().social, calibrate: "ge mig tre" } }))),
  );
  // D72 with a count of 3: dropped lines do not count; a legacy TOP line still sets the order
  assertEquals(ev[0].data as unknown, [
    "Hoppas det blir sol!",
    "Vilket lopp?",
    "Vad springer du helst?",
  ]);
  assertEquals(ev.map((e) => e.event), ["suggestions", "done"]);
});

// ---- D46 answer quality ----
function scripted(...texts: string[]) {
  const seen: { user: string }[] = [];
  const provider: LLMProvider = {
    name: "s",
    model: "s",
    stream: (r) => {
      const text = texts[Math.min(seen.length, texts.length - 1)];
      seen.push({ user: r.user });
      return (async function* (): AsyncGenerator<LLMChunk> {
        for (let k = 0; k < text.length; k += 9) yield { type: "text", text: text.slice(k, k + 9) };
        yield { type: "usage", inputTokens: 100, outputTokens: 10 };
      })();
    },
  };
  return { provider, seen };
}
const textOf = (ev: { event: string; data: Record<string, unknown> }[]) =>
  ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");

Deno.test("D46: arithmetic is computed in code, handed over as <computed>, digits spoken as words", async () => {
  const { provider, seen } = scripted("17 gånger 24 är 408.");
  const { handler } = setup({ provider });
  const ev = await readSse(await handler(post(body({ fragment: "17 gånger 24" }))));
  assertStringIncludes(seen[0].user, "<computed>17 × 24 = 408</computed>");
  assertEquals(textOf(ev), "Sjutton gånger tjugofyra är fyrahundraåtta.");
  assertEquals(ev[0].data.answer_type, "fact");
});

Deno.test("D46: a closing question to the user is removed; tutor mode keeps its check question", async () => {
  const { provider } = scripted("Det är fyra. Vill du att jag räknar mer?");
  const { handler } = setup({ provider });
  assertEquals(
    textOf(await readSse(await handler(post(body({ fragment: "två plus två" }))))).trim(),
    "Det är fyra.",
  );
  const t = await readSse(
    await setup({ provider }).handler(post(body({ mode: "tutor", fragment: "förklara addition" }))),
  );
  assertStringIncludes(textOf(t), "Vill du att jag räknar mer?");
});

Deno.test("D46: an answer that is only a question is regenerated once with a note", async () => {
  const { provider, seen } = scripted("Vad har du i tankarna?", "Koka pastan i åtta minuter.");
  const { handler, usage } = setup({ provider });
  const ev = await readSse(await handler(post(body({ fragment: "hungrig ägg pasta" }))));
  assertEquals(seen.length, 2);
  assertStringIncludes(seen[1].user, "<note>");
  assertEquals(textOf(ev), "Koka pastan i åtta minuter.");
  assertEquals(usage[0].input_tokens, 200, "tokens of both attempts are counted");
});

Deno.test("D46: a repeat of an earlier answer for another fragment is regenerated once, history entry dropped", async () => {
  const old = "Garantin gäller felet i produkten och reklamationsrätten ger dig skydd i tre år.";
  const { provider, seen } = scripted(old, "Spärra kortet direkt hos banken.");
  const { handler } = setup({ provider });
  const ev = await readSse(
    await handler(post(body({
      fragment: "vad gäller för mitt bankkort borta",
      context: { recent_qa: [{ q: "skillnad garanti reklamationsrätt", a: old }] },
    }))),
  );
  assertEquals(seen.length, 2);
  assertEquals(textOf(ev), "Spärra kortet direkt hos banken.");
  assertStringIncludes(
    seen[0].user,
    "<active_topic>skillnad garanti reklamationsrätt</active_topic>",
  );
  assert(!seen[1].user.includes("<recent_qa>"), "the repeated entry is not sent again");
  assertStringIncludes(seen[1].user, "<note>");
});

Deno.test("D46: a normal answer with history is not delayed or retried", async () => {
  const { provider, seen } = scripted(
    "Det beror på vilken sorts ägg du har och hur du vill ha dem.",
  );
  const { handler } = setup({ provider });
  const ev = await readSse(
    await handler(post(body({
      fragment: "varför då",
      context: {
        recent_qa: [{ q: "hungrig", a: "Koka pasta och stek ägg i fem minuter, sedan äter du." }],
      },
    }))),
  );
  assertEquals(seen.length, 1);
  assertStringIncludes(textOf(ev), "Det beror på");
});

Deno.test("D46 web: a fragment that needs the web enables the tools within caps; over the cap it answers without them", async () => {
  const seenTools: unknown[] = [];
  const provider: LLMProvider = {
    name: "w",
    model: "w",
    stream: (r) => {
      seenTools.push({ tools: r.tools, system: r.system, user: r.user, maxTokens: r.maxTokens });
      return (async function* (): AsyncGenerator<LLMChunk> {
        yield { type: "text", text: "Det kostar 9 990 kr. Källa: apple.com" };
        yield { type: "usage", inputTokens: 1000, outputTokens: 40, webSearches: 2 };
      })();
    },
  };
  const { handler, usage } = setup({ provider });
  const ev = await readSse(await handler(post(body({ fragment: "vad kostar en iphone just nu" }))));
  const first = seenTools[0] as { tools: { type: string }[]; system: string; maxTokens: number };
  assertEquals(first.tools.map((t) => t.type), ["web_search_20250305"]);
  assertStringIncludes(first.system, "WEB:");
  assertEquals(first.maxTokens, 600 + SUMMARY_TOKENS);
  assertStringIncludes(
    textOf(ev),
    "nio tusen nio hundra nittio kronor".replace(" ", " ").slice(0, 3),
  );
  assertEquals((ev.at(-1)!.data.usage as { web_searches: number }).web_searches, 2);
  assert((usage[0].est_cost_usd ?? 0) >= 0.02, "two searches are in the cost estimate");
  // no web need -> no tools
  await (await handler(post(body({ fragment: "fotosyntes" })))).text();
  assertEquals((seenTools[1] as { tools?: unknown }).tools, undefined);
  // cap: 4th web request within the minute is answered without tools + note
  const { handler: h2 } = setup({
    provider,
    config: { ...DEFAULT_CONFIG, webLimits: { perMinute: 1, perDay: 5, globalPerDay: 5 } },
  });
  await (await h2(post(body({ fragment: "vad kostar en iphone just nu" })))).text();
  await (await h2(post(body({ fragment: "vad kostar en iphone just nu" })))).text();
  const last = seenTools[seenTools.length - 1] as { tools?: unknown; user: string };
  assertEquals(last.tools, undefined);
  assertStringIncludes(last.user, "<note>Web search is not available right now");
});

Deno.test("D69: social.calibrate -> merged calibration in done, no suggestions, default (Haiku) model; calibration sent on", async () => {
  const { provider, seen } = recordingProvider("mindre kaxig; hon gillar fotboll\n");
  const { handler, usage } = setup({ provider });
  const ev = await readSse(
    await handler(post(socialBody({
      social: {
        ...socialBody().social,
        style: "flirt",
        calibration: "kaxigare",
        calibrate: "lite mindre kaxig, hon gillar fotboll",
      },
      adult_confirmed: true,
    }))),
  );
  assertEquals(ev.map((e) => e.event), ["done"]);
  assertEquals(ev[0].data.calibration, "mindre kaxig; hon gillar fotboll");
  assertEquals(ev[0].data.answered, true);
  assertEquals(ev[0].data.summary, null);
  assertEquals(seen[0].model, undefined, "calibration runs on the default model");
  assert(seen[0].system.includes("You keep a short calibration"));
  assert(seen[0].user.includes("<instruction>lite mindre kaxig, hon gillar fotboll</instruction>"));
  assertEquals(usage[0].category, "socialt/rizz");
  // RESET clears it
  const r2 = await readSse(
    await setup({ provider: recordingProvider("RESET").provider }).handler(
      post(socialBody({ social: { ...socialBody().social, calibration: "x", calibrate: "återställ" } })),
    ),
  );
  assertEquals(r2[0].data.calibration, "");
  // flirt calibration still needs the 18+ confirmation
  const r3 = await setup({ provider: recordingProvider("x").provider }).handler(
    post(socialBody({ social: { ...socialBody().social, style: "flirt", calibrate: "mer skämt" } })),
  );
  assertEquals(r3.status, 403);
  await r3.body?.cancel();
  // an ordinary suggestion request carries the calibration and reports no new one
  const s = recordingProvider(CANDS);
  const ev4 = await readSse(
    await setup({ provider: s.provider }).handler(
      post(socialBody({ social: { ...socialBody().social, calibration: "fler skämt" } })),
    ),
  );
  assert(s.seen[0].user.includes("<calibration>fler skämt</calibration>"));
  assertEquals(ev4.at(-1)?.data.calibration, null);
});


Deno.test("D72: 'ge mig tre pickup lines' -> three suggestions on the suggestion model, calibration untouched; default stops after line 1", async () => {
  const three = recordingProvider("1|Första raden här.\n2|Andra raden här.\n3|Tredje raden här.\n4|Fjärde.\n");
  const ev = await readSse(
    await setup({ provider: three.provider }).handler(
      post(socialBody({
        social: { ...socialBody().social, calibration: "fler skämt", calibrate: "ge mig tre pickup lines" },
      })),
    ),
  );
  assertEquals(ev.find((e) => e.event === "suggestions")?.data as unknown, [
    "Första raden här.",
    "Andra raden här.",
    "Tredje raden här.",
  ]);
  assertEquals(ev.at(-1)?.data.calibration, null, "a count request never changes the calibration");
  assertEquals(three.seen[0].model, "claude-sonnet-5-5");
  assert(three.seen[0].user.includes("<count>3</count>"));
  assert(three.seen[0].user.includes("<request>ge mig tre pickup lines</request>"));
  assert(three.seen[0].user.includes("<calibration>fler skämt</calibration>"));
  assertEquals(three.seen[0].maxTokens, 130);
  const one = recordingProvider("1|Bara den här.\n2|Ska aldrig visas.\n");
  const e1 = await readSse(await setup({ provider: one.provider }).handler(post(socialBody())));
  assertEquals(e1.map((e) => e.event), ["suggestion_preview", "suggestions", "done"]);
  assertEquals(e1[1].data as unknown, ["Bara den här."]);
  assert(one.seen[0].user.includes("<count>2</count>"), "one shown, a backup line written");
  // the backup is used when line 1 is filtered
  const bk = recordingProvider("1|Vill du ligga med mig ikväll?\n2|Då bjuder jag på kaffe efteråt.\n");
  const e2 = await readSse(await setup({ provider: bk.provider }).handler(post(socialBody())));
  assertEquals(e2.find((e) => e.event === "suggestions")?.data as unknown, ["Då bjuder jag på kaffe efteråt."]);
});

// ---- D75: Provläge / Auto stay silent on non-questions ----
Deno.test("D75 tutor: the [[TYST]] marker gives meta(is_question=false), no delta, answered false", async () => {
  for (const reply of ["[[TYST]]", "[[REL new_topic]]\n[[TYST]]", "  [[TYST]]\n[[SAMMANFATTNING]] x"]) {
    const { provider } = scripted(reply);
    const { handler, usage } = setup({ provider });
    const ev = await readSse(
      await handler(post(body({
        mode: "tutor",
        fragment: "Det är en annan. Ja, obrutet. Kom igen.",
        context: { recent_qa: [{ q: "vad är mitos", a: "Mitos är celldelning." }] },
      }))),
    );
    assertEquals(ev.map((e) => e.event), ["meta", "done"], reply);
    assertEquals(ev[0].data.is_question, false);
    assertEquals(ev[1].data.answered, false);
    assertEquals(ev[1].data.summary, null);
    assertEquals(usage[0].status, "not_question");
    assertEquals(usage[0].is_question, false);
  }
});

Deno.test("D75 tutor: an answer that is only a meta comment is silence; a meta lead-in is dropped", async () => {
  const meta = "Det låter som att du tänker på något ord. Berätta gärna ordet så förklarar jag det.";
  const { provider } = scripted(meta);
  const ev = await readSse(
    await setup({ provider }).handler(post(body({ mode: "tutor", fragment: "Äh, syntes." }))),
  );
  assertEquals(ev.map((e) => e.event), ["meta", "done"]);
  assertEquals(ev[0].data.is_question, false);
  const mixed = scripted("Det låter som att du menar fotosyntes. Fotosyntes är när växter gör socker av ljus.");
  const ev2 = await readSse(
    await setup({ provider: mixed.provider }).handler(post(body({ mode: "tutor", fragment: "syntes" }))),
  );
  assertEquals(ev2[0].event, "meta");
  assertEquals(ev2[0].data.is_question, true, "meta comes with the first spoken text");
  assertEquals(textOf(ev2).trim(), "Fotosyntes är när växter gör socker av ljus.");
  assertEquals(ev2.at(-1)!.data.answered, true);
});

Deno.test("D75 tutor: a real answer streams as before (meta first, then deltas)", async () => {
  const { provider } = scripted("Fotosyntes är när växter bygger socker med hjälp av ljus. Det sker i kloroplasterna.");
  const ev = await readSse(
    await setup({ provider }).handler(post(body({ mode: "tutor", fragment: "fotosyntes" }))),
  );
  assertEquals(ev[0].event, "meta");
  assertEquals(ev[0].data.is_question, true);
  assert(ev.slice(1, -1).every((e) => e.event === "delta"));
  assertStringIncludes(textOf(ev), "kloroplasterna");
});

Deno.test("D75 text mode keeps a confirmation question (silence is only for Provläge and Auto)", async () => {
  const { provider } = scripted("Menar du roten ur hundra?");
  const ev = await readSse(
    await setup({ provider }).handler(post(body({ mode: "text", fragment: "roten av hun" }))),
  );
  assertEquals(textOf(ev).trim(), "Menar du roten ur hundra?");
});

Deno.test("D75 auto: a low-confidence header is silence, not a confirmation question", async () => {
  const { provider } = scripted(
    '{"is_question":true,"answer_type":"fact","relation":null,"reconstructed_question":"?","confidence":0.3}\nMenar du roten ur hundra?',
  );
  const ev = await readSse(await setup({ provider }).handler(post(body({ mode: "auto", fragment: "roten hun" }))));
  assertEquals(ev.map((e) => e.event), ["meta", "done"]);
  assertEquals(ev[0].data.is_question, false);
  assertEquals(ev[1].data.answered, false);
});

Deno.test("D75 auto: an answer that is only a meta comment becomes silence", async () => {
  const { provider } = scripted(
    '{"is_question":true,"answer_type":"fact","relation":null,"reconstructed_question":"x","confidence":0.8}\nDet verkar som att du pratar om något annat.',
  );
  const ev = await readSse(await setup({ provider }).handler(post(body({ mode: "auto", fragment: "kom igen nu" }))));
  assertEquals(ev.map((e) => e.event), ["meta", "done"]);
  assertEquals(ev[0].data.is_question, false);
  assertEquals(ev[1].data.answered, false);
});
