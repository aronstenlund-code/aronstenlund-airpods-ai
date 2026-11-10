import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { CRISIS_OTHER, CRISIS_SELF, isCrisis } from "./crisis.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";

import CASES from "../../../../scripts/k21-crisis-cases.json" with { type: "json" };

Deno.test("K21 20 own cases are always caught, 20 figures of speech never", () => {
  const missed = CASES.positive.filter((t: string) => !isCrisis(t));
  const false_ = CASES.negative.filter((t: string) => isCrisis(t));
  assertEquals(missed, [], "missed");
  assertEquals(false_, [], "false alarms");
});

function h() {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k21", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "s",
      stream: (r) => {
        seen.push(r);
        return (async function* (): AsyncGenerator<LLMChunk> {
          yield { type: "text", text: '{"is_question":false,"reconstructed_question":"x","confidence":0.2}\n' };
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", context: {}, ...b }) });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("K21 Auto, Frågor, Provläge, the demo: the warm answer with 112, Självmordslinjen and Bris, no model call", async () => {
  for (const b of [
    { fragment: "Jag mår skit och orkar inte leva.", mode: "auto" },
    { fragment: "jag orkar inte leva", mode: "push_to_talk" },
    { fragment: "jag vill dö", mode: "tutor", persona: "tutor", persona_setup: "Prov i Biologi. Årskurs: Åk 9." },
    { fragment: "jag vill inte leva mer", mode: "text", source: "demo" },
  ]) {
    const { handler, seen } = h();
    const ev = await events(await handler(post(b)));
    const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
    assertEquals(said, CRISIS_SELF, JSON.stringify(b));
    assertEquals(seen.length, 0, "decided in code");
    assert(said.includes("ett ett två") && said.includes("nittio ett noll ett") && said.includes("ett ett sex ett ett ett"));
    assertEquals(ev.find((e) => e.event === "done")!.data.summary, null, "never stored");
  }
});

Deno.test("K21 when someone else says it (Socialt): a line to the user about how to help", async () => {
  const { handler } = h();
  const ev = await events(await handler(post({
    fragment: "",
    mode: "tutor",
    persona: "social",
    social: { style: "social", trigger: "other_spoke", transcript: [{ speaker: "Talare 1", text: "ärligt talat orkar jag inte leva längre" }], speaker: "Talare 1" },
  })));
  const sug = ev.find((e) => e.event === "suggestions");
  assert(sug && JSON.stringify(sug.data).includes(CRISIS_OTHER.slice(0, 30)), JSON.stringify(ev.map((e) => e.event)));
});

Deno.test("K21 an ordinary sentence goes to the model as before", async () => {
  const { handler, seen } = h();
  await events(await handler(post({ fragment: "provet tar livet av mig", mode: "push_to_talk" })));
  assertEquals(seen.length, 1);
});
