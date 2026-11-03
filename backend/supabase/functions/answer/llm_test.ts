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
    inputTokens: undefined,
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
