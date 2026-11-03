import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps, type UsageRecord } from "./handler.ts";
import { MockProvider } from "./llm/mock.ts";
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
          text: '{"is_question":true,"reconstructed_question":"q","confidence":0.9}\nHal',
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
        for (let i = 0; i < 100; i++) yield { type: "text", text: "x".repeat(50) };
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
  assertEquals(ev.map((e) => e.event), ["meta", "delta", "delta", "done"]);
  assertEquals(ev[1].data.text, "Sju", "leading whitespace trimmed");
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
        user: "<fragment>x</fragment>",
        maxTokens: 10,
      });
    },
  };
  const { handler } = setup({
    provider,
    localLimiter: new MemoryRateLimiter(),
    config: { ...DEFAULT_CONFIG, limits: { perMinute: 2, perDay: 100, globalPerDay: 100 } },
  });
  for (let i = 0; i < 2; i++) await (await handler(post(body()))).text();
  const res = await handler(post(body()));
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
