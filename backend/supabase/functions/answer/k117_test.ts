// K117 (D256): the model's crisis marker is checked once more when the code layer sees no danger (crisisLevel null):
// only a clear "nej" from CRISIS_CHECK_PROMPT ignores it (logged crisis_marker_ignored); anything else – an error,
// a time-out, "ja", an empty or other reply – gives the crisis answer as before. The code's own hits and O17 unchanged.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { CRISIS_SELF } from "./crisis.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import type { LLMChunk, LLMRequest } from "./llm/types.ts";

function world(turns: string[], check: string | Error) {
  const seen: LLMRequest[] = [];
  let n = 0;
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k117", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s", model: "s",
      stream: (r) => {
        seen.push(r);
        const isCheck = r.system.startsWith("You check ONE utterance");
        const t = isCheck ? check : turns[Math.min(n++, turns.length - 1)];
        return (async function* (): AsyncGenerator<LLMChunk> {
          if (t instanceof Error) throw t;
          for (let k = 0; k < t.length; k += 6) yield { type: "text", text: t.slice(k, k + 6) };
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen, checks: () => seen.filter((r) => r.system.startsWith("You check ONE utterance")) };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", context: {}, ...b }) });
async function run(w: ReturnType<typeof world>, b: Record<string, unknown>) {
  const ev = (await (await w.handler(post(b))).text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) as Record<string, unknown> }));
  return { said: ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""), done: ev.find((e) => e.event === "done")!.data, ev };
}
const RIS = { fragment: "recept på ris", mode: "push_to_talk" };
const PLAIN = { fragment: "vad är ris", mode: "push_to_talk" }; // not a recipe lookup (K116 holds those until their source)

Deno.test("K117: 'recept på ris' with the model's marker and a clear 'nej' from the check: the real answer", async () => {
  const w = world(["[[KRIS]]", "Koka riset i saltat vatten i tolv minuter. källa: ica.se"], "nej");
  const r = await run(w, RIS);
  assert(r.said.startsWith("Koka riset i saltat vatten i tolv minuter."), r.said);
  assertEquals(r.done.safety, undefined);
  assertEquals(w.checks().length, 1);
  assert(w.checks()[0].user.includes("recept på ris"));
});

Deno.test("K117: the check fails, times out, says 'ja' or anything else: the crisis answer as before", async () => {
  for (const check of [new Error("timeout"), "ja", "", "Osäker", "Nej?? ja"]) {
    const r = await run(world(["[[KRIS]]", "Koka riset."], check), RIS);
    assertEquals(r.said, CRISIS_SELF, String(check));
    assertEquals(r.done.safety, "crisis");
  }
});

Deno.test("K117: a second marker after a 'nej' still gives the crisis answer (one check only)", async () => {
  const w = world(["[[KRIS]]", "[[KRIS]]"], "nej");
  const r = await run(w, RIS);
  assertEquals(r.said, CRISIS_SELF);
  assertEquals(w.checks().length, 1);
});

Deno.test("K117: a late marker after text with a clear 'nej': the text stands and no crisis text is added", async () => {
  const r = await run(world(["Ris är ett sädesslag. [[KRIS]]"], "nej"), PLAIN);
  assertEquals(r.said.trim(), "Ris är ett sädesslag.");
  assertEquals(r.done.safety, undefined);
  const kept = await run(world(["Ris är ett sädesslag. [[KRIS]]"], "ja"), PLAIN);
  assert(kept.said.includes("nittio ett noll ett"), kept.said);
});

Deno.test("K117: Auto's self_harm_risk flag with a clear 'nej': the answer after the meta line is said", async () => {
  const meta = '{"is_question":true,"self_harm_risk":true,"reconstructed_question":"vad är ris","confidence":0.9}\n';
  const r = await run(world([meta + "Ris är ett sädesslag."], "nej"), { fragment: "vad är ris", mode: "auto" });
  assertEquals(r.said.trim(), "Ris är ett sädesslag.");
  assertEquals(r.done.safety, undefined);
  assert(r.ev.some((e) => e.event === "meta" && e.data.safety !== "crisis"));
});

Deno.test("K117: the code's own hits are untouched: a clear crisis phrase is answered in code, no model call", async () => {
  const w = world(["Koka riset."], "nej");
  const r = await run(w, { fragment: "jag vill inte leva längre", mode: "push_to_talk" });
  assertEquals(r.said, CRISIS_SELF);
  assertEquals(w.seen.length, 0);
});
