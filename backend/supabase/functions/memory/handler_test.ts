import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createMemoryHandler, DEFAULT_MEMORY_CONFIG, parseMemoryReply, SYSTEM_PROMPT_MEMORY } from "./handler.ts";

class FakeLLM implements LLMProvider {
  readonly name = "fake";
  readonly model = "fake-1";
  calls: LLMRequest[] = [];
  constructor(private reply: string) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.reply };
    yield { type: "usage", inputTokens: 400, outputTokens: 40 };
  }
}
const post = (b: unknown) =>
  new Request("http://x/memory", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify(b),
  });

function mk(reply: string, logged: Record<string, unknown>[] = []) {
  const llm = new FakeLLM(reply);
  const h = createMemoryHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: llm,
    recordUsage: (r) => void logged.push(r),
    now: () => new Date("2026-11-07T20:00:00Z"),
  });
  return { h, llm };
}

Deno.test("D80 memory: a turn about the wearer gives new facts; absolute dates come from <now>", async () => {
  const logged: Record<string, unknown>[] = [];
  const { h, llm } = mk(
    '{"add": ["Har prov i kemi fredag 13 november 2026."], "update": [], "remove": []}',
    logged,
  );
  const r = await h(post({ turn: { q: "jag har kemiprov på fredag", a: "Lycka till!" }, memories: [] }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.add, ["Har prov i kemi fredag 13 november 2026."]);
  assertEquals(j.update, []);
  assert(llm.calls[0].user.includes("<now>lördag 7 november 2026"), llm.calls[0].user.slice(0, 80));
  assertEquals(llm.calls[0].system, SYSTEM_PROMPT_MEMORY);
  assertEquals(llm.calls[0].cacheSystem, true);
  // usage keeps metadata only: never the text
  assertEquals(logged.length, 1);
  assert(!JSON.stringify(logged).includes("kemiprov"), "the turn text is never logged");
  assertEquals(logged[0].endpoint, "memory");
});

Deno.test("D80 memory: no self-reference = no model call", async () => {
  const { h, llm } = mk("{}");
  const r = await h(post({ turn: { q: "vad är fotosyntes" } }));
  assertEquals(r.status, 200);
  assertEquals((await r.json()).skipped, "no_self_reference");
  assertEquals(llm.calls.length, 0);
});

Deno.test("D80 memory: sensitive, duplicate, malformed and unknown updates are dropped", () => {
  const mem = ["Läser Kemi 1.", "Har prov i matte måndag 9 november 2026."];
  const r = parseMemoryReply(
    `Här: {"add": ["Är allergisk mot nötter.", "Läser Kemi 1.", "Vill ha kortare svar.", "${"x".repeat(200)}"],
      "update": [{"old": "Har prov i matte måndag 9 november 2026.", "new": "Har prov i matte tisdag 10 november 2026."},
                 {"old": "finns inte", "new": "Något."}],
      "remove": ["Läser Kemi 1.", "okänd"]}`,
    mem,
  );
  assertEquals(r.add, ["Vill ha kortare svar."]);
  assertEquals(r.update, [{ old: "Har prov i matte måndag 9 november 2026.", new: "Har prov i matte tisdag 10 november 2026." }]);
  assertEquals(r.remove, ["Läser Kemi 1."]);
  assertEquals(parseMemoryReply("inget json", mem), { add: [], update: [], remove: [] });
});

Deno.test("D80 memory: validation, method and rate limits", async () => {
  const { h } = mk('{"add": []}');
  assertEquals((await h(new Request("http://x/memory"))).status, 405);
  assertEquals((await h(post({ turn: {} }))).status, 400);
  assertEquals((await h(post({ turn: { q: "jag" }, memories: Array(31).fill("x") }))).status, 400);
  const tight = createMemoryHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: new FakeLLM('{"add": []}'),
    config: { ...DEFAULT_MEMORY_CONFIG, limits: { perMinute: 1, perDay: 10, globalPerDay: 10 } },
  });
  assertEquals((await tight(post({ turn: { q: "jag läser kemi" } }))).status, 200);
  assertEquals((await tight(post({ turn: { q: "jag läser kemi" } }))).status, 429);
});

Deno.test("D80 memory: accepts the app's body (turn.question / turn.answer / mode, today, weekday, timezone)", async () => {
  const { h, llm } = mk('{"add": ["Har biologiprov fredag 13 november 2026."]}');
  const r = await h(post({
    turn: { question: "jag har biologiprov på fredag", answer: "Lycka till!", mode: "prov" },
    memories: [],
    today: "2026-11-07",
    weekday: "lördag",
    timezone: "Europe/Stockholm",
    language: "sv",
  }));
  assertEquals(r.status, 200);
  assertEquals((await r.json()).add, ["Har biologiprov fredag 13 november 2026."]);
  assert(llm.calls[0].user.includes("<q>jag har biologiprov på fredag</q>"));
  assert(llm.calls[0].user.includes("<a>Lycka till!</a>"));
});

Deno.test("Oscar 2026-11-08 memory: address, debts and money are never kept; English 'I' turns are read", async () => {
  const r = parseMemoryReply(
    '{"add": ["Bor på Storgatan 5 i Umeå.", "Har skulder på 50 000 kronor.", "Tjänar 20 000 i månaden.", "Har prov i kemi fredag 13 november 2026."]}',
    [],
  );
  assertEquals(r.add, ["Har prov i kemi fredag 13 november 2026."]);
  const { h, llm } = mk('{"add": ["Har prov i kemi fredag 13 november 2026."]}');
  const res = await h(post({ turn: { question: "I have a chemistry exam on Friday" } }));
  assertEquals((await res.json()).add, ["Har prov i kemi fredag 13 november 2026."]);
  assertEquals(llm.calls.length, 1, "an English first-person turn is not skipped");
});
