// K104 (D233): an SSE event `searching` as soon as the web search begins, before the first word of the answer.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps } from "./handler.ts";
import { AnthropicProvider } from "./llm/anthropic.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";

const cfg = { apiKey: "sk-test", model: "claude-haiku-5-5", effort: "low" as const, disableThinking: true };
const sse = (events: unknown[]) =>
  new Response(events.map((e) => `event: x\ndata: ${JSON.stringify(e)}\n\n`).join(""), { status: 200, headers: { "content-type": "text/event-stream" } });

Deno.test("K104: the provider yields `searching` once, when the server tool starts, before any answer text", async () => {
  const f = (() =>
    Promise.resolve(sse([
      { type: "message_start", message: { usage: { input_tokens: 10, output_tokens: 1 } } },
      { type: "content_block_start", index: 0, content_block: { type: "server_tool_use", id: "s1", name: "web_search" } },
      { type: "content_block_stop", index: 0 },
      { type: "content_block_start", index: 1, content_block: { type: "web_search_tool_result", content: [] } },
      { type: "content_block_start", index: 2, content_block: { type: "server_tool_use", id: "s2", name: "web_search" } },
      { type: "content_block_start", index: 3, content_block: { type: "text", text: "" } },
      { type: "content_block_delta", index: 3, delta: { type: "text_delta", text: "Nilen räknas oftast som längst." } },
      { type: "message_delta", delta: { stop_reason: "end_turn" }, usage: { output_tokens: 9 } },
      { type: "message_stop" },
    ]))) as unknown as typeof fetch;
  const kinds: string[] = [];
  for await (const c of new AnthropicProvider(cfg, f).stream({ system: "S", user: "U", maxTokens: 50, tools: [{ type: "web_search_20250305", name: "web_search" }] })) {
    kinds.push(c.type === "searching" ? `searching:${c.tool}` : c.type);
  }
  assertEquals(kinds.filter((k) => k.startsWith("searching")), ["searching:web_search"], "once, even with two searches");
  assert(kinds.indexOf("searching:web_search") < kinds.indexOf("text"));
});

Deno.test("K104: no `searching` without a server tool", async () => {
  const f = (() =>
    Promise.resolve(sse([
      { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
      { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "Tio." } },
      { type: "message_stop" },
    ]))) as unknown as typeof fetch;
  const kinds: string[] = [];
  for await (const c of new AnthropicProvider(cfg, f).stream({ system: "S", user: "U", maxTokens: 9 })) kinds.push(c.type);
  assertEquals(kinds.includes("searching"), false);
});

Deno.test("K104: /answer sends `searching` before the first delta, once, and nothing is spoken for it", async () => {
  const provider: LLMProvider = {
    name: "fake",
    model: "claude-haiku-5-5",
    stream(_req: LLMRequest): AsyncIterable<LLMChunk> {
      return (async function* () {
        yield { type: "searching", tool: "web_search" } as LLMChunk;
        yield { type: "searching", tool: "web_search" } as LLMChunk;
        yield { type: "text", text: "Riksdagen har 349 ledamöter. " };
        yield { type: "text", text: "källa: riksdagen.se" };
        yield { type: "usage", inputTokens: 10, outputTokens: 5, webSearches: 1 };
      })();
    },
  };
  const deps: Deps = {
    authenticate: () => Promise.resolve({ id: "user-1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  };
  const res = await createHandler(deps)(new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ fragment: "hur många ledamöter har riksdagen just nu", mode: "push_to_talk", language: "sv", context: {} }),
  }));
  assertEquals(res.status, 200);
  const ev = (await res.text()).split("\n\n").filter(Boolean).map((f) => ({
    event: /^event: (.*)$/m.exec(f)![1],
    data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) as Record<string, unknown>,
  }));
  const names = ev.map((e) => e.event);
  assertEquals(names.filter((n) => n === "searching").length, 1);
  const firstDelta = names.indexOf("delta");
  assert(firstDelta > names.indexOf("searching"), names.join(","));
  const s = ev.find((e) => e.event === "searching")!.data;
  assertEquals(s.tool, "web_search");
  assert(typeof s.ms === "number");
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assert(said.startsWith("Riksdagen har trehundrafyrtionio ledamöter"), said);
  assertEquals(ev.at(-1)!.event, "done");
});

import { testModelPick } from "./handler.ts";
async function modelFor(fragment: string, header: string | null): Promise<string | undefined> {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = {
    name: "fake",
    model: "claude-haiku-5-5",
    stream(r: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(r);
      return (async function* () {
        yield { type: "text", text: "Svar. källa: ne.se" } as LLMChunk;
      })();
    },
  };
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  await (await h(new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json", ...(header ? { "x-earmind-test": header } : {}) },
    body: JSON.stringify({ fragment, mode: "text", language: "sv", context: {} }),
  }))).text();
  return seen[0]?.model;
}

Deno.test("K104: a test picks the model of a searched call only; without the header nothing changes", async () => {
  assertEquals(testModelPick("kevin-k104 model-haiku"), "haiku");
  assertEquals(testModelPick("oscar-qa model-sonnet slow"), "sonnet");
  assertEquals(testModelPick("oscar-qa"), null);
  assertEquals(testModelPick(null), null);
  // a song searches (text tools): Sonnet by default, Haiku when the test asks for it
  assertEquals(await modelFor("sjung en snapsvisa", null), "claude-sonnet-5-5");
  assertEquals(await modelFor("sjung en snapsvisa", "kevin-k104 model-haiku"), "claude-haiku-5-5");
  // a searched question on the default model gets Sonnet only when asked
  assertEquals(await modelFor("vem vann melodifestivalen 2024", null), undefined);
  assertEquals(await modelFor("vem vann melodifestivalen 2024", "kevin-k104 model-sonnet"), "claude-sonnet-5-5");
  // a call without web tools never changes model (no cheap way to Sonnet for ordinary answers)
  assertEquals(await modelFor("vad är en atom", "kevin-k104 model-sonnet"), undefined);
});
