import { assertEquals, assertInstanceOf } from "jsr:@std/assert@1.0.8";
import { classifyAnthropicError, mapAnthropicEvent } from "./llm/anthropic.ts";
import { providerFromEnv } from "./llm/factory.ts";
import { LLMProviderError } from "./llm/types.ts";
import { MockProvider } from "./llm/mock.ts";

Deno.test("Anthropic stream events map to chunks", () => {
  assertEquals(
    mapAnthropicEvent({
      type: "message_start",
      message: { usage: { input_tokens: 321, output_tokens: 1 } },
    }),
    {
      type: "usage",
      inputTokens: 321,
      outputTokens: 1,
      cacheReadTokens: undefined,
      cacheWriteTokens: undefined,
    },
  );
  assertEquals(
    mapAnthropicEvent({ type: "content_block_delta", delta: { type: "text_delta", text: "Hej" } }),
    { type: "text", text: "Hej" },
  );
  assertEquals(
    mapAnthropicEvent({
      type: "content_block_delta",
      delta: { type: "thinking_delta", thinking: "x" },
    }),
    null,
  );
  assertEquals(mapAnthropicEvent({ type: "message_delta", usage: { output_tokens: 42 } }), {
    type: "usage",
    outputTokens: 42,
  });
  assertEquals(mapAnthropicEvent({ type: "ping" }), null);
});

Deno.test("credit exhaustion and billing errors classify as quota (fail closed)", () => {
  assertEquals(classifyAnthropicError(402, "billing").kind, "quota");
  assertEquals(
    classifyAnthropicError(400, "Your credit balance is too low to access the Anthropic API").kind,
    "quota",
  );
  assertEquals(classifyAnthropicError(401, "invalid x-api-key").kind, "auth");
  assertEquals(classifyAnthropicError(429, "rate").kind, "rate_limited");
  assertEquals(classifyAnthropicError(400, "bad param").kind, "bad_request");
  assertEquals(classifyAnthropicError(529, "overloaded").kind, "unavailable");
  assertEquals(classifyAnthropicError(undefined, "ECONNRESET").kind, "unavailable");
  assertInstanceOf(classifyAnthropicError(500, "x"), LLMProviderError);
});

Deno.test("provider selection fails closed without a key; mock only when explicit", () => {
  const env = (o: Record<string, string>) => ({ get: (k: string) => o[k] });
  assertEquals(providerFromEnv(env({})), null);
  assertEquals(providerFromEnv(env({ LLM_PROVIDER: "nonsense" })), null);
  assertEquals(providerFromEnv(env({ LLM_PROVIDER: "mock" }))?.name, "mock");
  const real = providerFromEnv(env({ ANTHROPIC_API_KEY: "sk-test" }));
  assertEquals(real?.name, "anthropic");
  assertEquals(real?.model, "claude-haiku-5-5");
});

Deno.test("mock provider follows the wire protocol", async () => {
  const user = "<mode>auto</mode>\n<language>sv</language>\n<fragment>fem plus två</fragment>";
  let text = "";
  for await (const c of new MockProvider().stream({ system: "", user, maxTokens: 100 })) {
    if (c.type === "text") text += c.text;
  }
  const [header, answer] = text.split("\n");
  assertEquals(JSON.parse(header).is_question, true);
  assertEquals(answer.startsWith("Mocksvar"), true);
});

Deno.test("message_start: cached prompt tokens count as input and are reported separately", () => {
  assertEquals(
    mapAnthropicEvent({
      type: "message_start",
      message: {
        usage: {
          input_tokens: 40,
          cache_read_input_tokens: 900,
          cache_creation_input_tokens: 0,
          output_tokens: 1,
        },
      },
    }),
    { type: "usage", inputTokens: 940, outputTokens: 1, cacheReadTokens: 900, cacheWriteTokens: 0 },
  );
});

// ---- fetch-based Anthropic provider (no SDK) ----
import { ANTHROPIC_VERSION, AnthropicProvider, sseJson } from "./llm/anthropic.ts";

const cfg = {
  apiKey: "sk-test",
  model: "claude-haiku-5-5",
  effort: "low" as const,
  disableThinking: true,
};
const sse = (events: unknown[]) =>
  new Response(
    events.map((e) => `event: x\ndata: ${JSON.stringify(e)}\n\n`).join(""),
    { status: 200, headers: { "content-type": "text/event-stream" } },
  );

Deno.test("AnthropicProvider: request shape matches what the SDK sent, stream maps to chunks", async () => {
  let captured: { url: string; init: RequestInit } | undefined;
  const f = ((url: string, init: RequestInit) => {
    captured = { url: String(url), init };
    return Promise.resolve(sse([
      {
        type: "message_start",
        message: { usage: { input_tokens: 40, cache_read_input_tokens: 460, output_tokens: 1 } },
      },
      { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
      { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "Tio" } },
      { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "." } },
      { type: "message_delta", delta: { stop_reason: "end_turn" }, usage: { output_tokens: 5 } },
      { type: "message_stop" },
    ]));
  }) as typeof fetch;
  const chunks = [];
  for await (
    const c of new AnthropicProvider(cfg, f).stream({
      system: "S",
      user: "U",
      maxTokens: 99,
      cacheSystem: true,
    })
  ) chunks.push(c);
  const h = captured!.init.headers as Record<string, string>;
  assertEquals([h["x-api-key"], h["anthropic-version"]], ["sk-test", ANTHROPIC_VERSION]);
  const body = JSON.parse(captured!.init.body as string);
  assertEquals(body.model, "claude-haiku-5-5");
  assertEquals(body.stream, true);
  assertEquals(body.thinking, { type: "disabled" });
  assertEquals(body.output_config, { effort: "low" });
  assertEquals(body.system, [{ type: "text", text: "S", cache_control: { type: "ephemeral" } }]);
  assertEquals("temperature" in body, false);
  assertEquals(
    chunks.filter((c) => c.type === "text").map((c) => (c as { text: string }).text).join(""),
    "Tio.",
  );
  assertEquals(chunks[0], {
    type: "usage",
    inputTokens: 500,
    outputTokens: 1,
    cacheReadTokens: 460,
    cacheWriteTokens: undefined,
  });
});

Deno.test("AnthropicProvider: HTTP errors classify (402/400-credit => quota, 401 => auth, 429, 5xx)", async () => {
  const cases: [number, string, string][] = [
    [402, "billing", "quota"],
    [400, "Your credit balance is too low to access the Anthropic API", "quota"],
    [401, "invalid x-api-key", "auth"],
    [429, "slow down", "rate_limited"],
    [529, "overloaded", "unavailable"],
  ];
  for (const [status, message, kind] of cases) {
    const f = (() =>
      Promise.resolve(
        new Response(JSON.stringify({ error: { message } }), { status }),
      )) as typeof fetch;
    const it = new AnthropicProvider(cfg, f).stream({ system: "S", user: "U", maxTokens: 9 })
      [Symbol.asyncIterator]();
    const e = await it.next().then(() => null, (x) => x);
    assertEquals((e as LLMProviderError).kind, kind, `${status}`);
  }
});

Deno.test("AnthropicProvider: a mid-stream error event and network failure surface as provider errors", async () => {
  const f1 = (() =>
    Promise.resolve(
      sse([{ type: "error", error: { type: "overloaded_error", message: "Overloaded" } }]),
    )) as typeof fetch;
  const e1 = await new AnthropicProvider(cfg, f1).stream({ system: "S", user: "U", maxTokens: 9 })
    [Symbol.asyncIterator]().next().then(() => null, (x) => x);
  assertEquals((e1 as LLMProviderError).kind, "unavailable");
  const f2 = (() => Promise.reject(new TypeError("connection reset"))) as typeof fetch;
  const e2 = await new AnthropicProvider(cfg, f2).stream({ system: "S", user: "U", maxTokens: 9 })
    [Symbol.asyncIterator]().next().then(() => null, (x) => x);
  assertEquals((e2 as LLMProviderError).kind, "unavailable");
});

Deno.test("sseJson handles frames split across chunks and ignores junk", async () => {
  const enc = new TextEncoder();
  const body = new ReadableStream<Uint8Array>({
    start(c) {
      c.enqueue(enc.encode('event: a\ndata: {"type":"a","n":'));
      c.enqueue(enc.encode('1}\n\nevent: b\ndata: not-json\n\n: ping\n\ndata: {"type":"b"}\n\n'));
      c.close();
    },
  });
  const out = [];
  for await (const ev of sseJson(body)) out.push(ev);
  assertEquals(out, [{ type: "a", n: 1 }, { type: "b" }]);
});
