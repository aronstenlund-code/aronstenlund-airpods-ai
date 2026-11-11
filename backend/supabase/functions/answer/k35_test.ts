// K35 (D122): phone tools through Claude tool use; the app runs them, the server validates and confirms.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { confirmText, phoneToolDefs, validatePhoneInput, whenSv } from "./phonetools.ts";

Deno.test("K35 tools: definitions only for what the app offers (strict); inputs validated; Swedish confirmation", () => {
  const defs = phoneToolDefs(["calendar_add", "timer_start", "nope"]) as { name: string; strict: boolean }[];
  assertEquals(defs.map((d) => d.name), ["calendar_add", "timer_start"]);
  assert(defs.every((d) => d.strict));
  assertEquals(validatePhoneInput("calendar_add", { title: "Tandläkaren", start: "2026-11-12T15:00" }), { title: "Tandläkaren", start: "2026-11-12T15:00" });
  assertEquals(validatePhoneInput("calendar_add", { title: "x", start: "torsdag" }), null);
  assertEquals(validatePhoneInput("timer_start", { seconds: 0 }), null);
  assertEquals(validatePhoneInput("alarm_set", { time: "25:00" }), null);
  assertEquals(validatePhoneInput("rm_rf", {}), null);
  assertEquals(whenSv("2026-11-12T15:00"), "torsdag den 12 november klockan 15:00");
  assertEquals(confirmText("calendar_add", { title: "Tandläkaren", start: "2026-11-12T15:00" }), "Ska jag lägga in Tandläkaren torsdag den 12 november klockan 15:00 i kalendern?");
  assertEquals(confirmText("timer_start", { seconds: 300 }), null);
});

function setup(chunks: LLMChunk[]) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k35", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "claude-haiku-5-5",
      stream: (r) => {
        seen.push(r);
        return (async function* () {
          for (const c of chunks) yield c;
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", context: {}, mode: "push_to_talk", ...b }) });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("K35 a tool call reaches the app with its confirmation; done says a tool is pending; no tools without tools_available", async () => {
  const call: LLMChunk = { type: "tool_use", id: "toolu_1", name: "calendar_add", input: { title: "Tandläkaren", start: "2026-11-12T15:00" } };
  const { handler, seen } = setup([call]);
  const ev = await events(await handler(post({ fragment: "lägg in tandläkaren på torsdag klockan tre", tools_available: ["calendar_add", "reminder_add"] })));
  const tc = ev.find((e) => e.event === "tool_call")!;
  assertEquals(tc.data.name, "calendar_add");
  assertEquals(tc.data.kind, "write");
  assert(String(tc.data.confirm).startsWith("Ska jag lägga in Tandläkaren"));
  const done = ev.find((e) => e.event === "done")!;
  assertEquals(done.data.tool_pending, true);
  assert(!ev.some((e) => e.event === "error"), "no empty_answer error");
  assertEquals((seen[0].tools as { name: string }[]).map((t) => t.name), ["calendar_add", "reminder_add"]);
  assert(seen[0].system.includes("Phone tools (K35)"));
  // bad input from the model never reaches the app
  const bad = setup([{ type: "tool_use", id: "toolu_2", name: "calendar_add", input: { title: "x", start: "på torsdag" } }, { type: "text", text: "Det gick inte." }]);
  const ev2 = await events(await bad.handler(post({ fragment: "lägg in något", tools_available: ["calendar_add"] })));
  assert(!ev2.some((e) => e.event === "tool_call"));
  // without tools_available: as before, no tools, no rule
  const plain = setup([{ type: "text", text: "Hej." }]);
  await (await plain.handler(post({ fragment: "vad är huvudstaden i Japan" }))).text(); // (a zone clock is now said by code)
  assertEquals(plain.seen[0].tools, undefined);
  assert(!plain.seen[0].system.includes("Phone tools (K35)"));
});

Deno.test("K35 tool round: the model gets the call and the result as messages and says one sentence", async () => {
  const { handler, seen } = setup([{ type: "text", text: "Klart, tandläkaren ligger på torsdag klockan tre." }]);
  const ev = await events(await handler(post({
    fragment: "lägg in tandläkaren på torsdag klockan tre",
    tools_available: ["calendar_add"],
    tool_round: { call: { id: "toolu_1", name: "calendar_add", input: { title: "Tandläkaren", start: "2026-11-12T15:00" } }, status: "ok", result: { event_id: "E1" } },
  })));
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assert(said.startsWith("Klart"));
  const m = seen[0].messages as { role: string; content: unknown }[];
  assertEquals(m.map((x) => x.role), ["user", "assistant", "user"]);
  assertEquals((m[2].content as { type: string; tool_use_id: string }[])[0].tool_use_id, "toolu_1");
  // a declined call is an error result for the model; a bad round is rejected
  const d = setup([{ type: "text", text: "Okej, jag lät bli." }]);
  await (await d.handler(post({ fragment: "x", tools_available: ["calendar_add"], tool_round: { call: { id: "t", name: "calendar_add", input: { title: "A", start: "2026-11-12" } }, status: "declined" } }))).text();
  assertEquals(((d.seen[0].messages as { content: unknown }[])[2].content as { is_error?: boolean }[])[0].is_error, true);
  const r = await d.handler(post({ fragment: "x", tool_round: { call: { id: "t", name: "rm", input: {} }, status: "ok" } }));
  assertEquals(r.status, 400);
});
