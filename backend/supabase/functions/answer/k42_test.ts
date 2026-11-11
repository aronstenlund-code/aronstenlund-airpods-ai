// K42.3: the asked length reaches the model, raises the limits and turns the short-first two-level answer off.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMRequest } from "./llm/types.ts";

function setup() {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k42", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "claude-haiku-5-5", stream: (r) => { seen.push(r); return (async function* () { yield { type: "text" as const, text: "Fotosyntes är när växter bildar socker." }; })(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (fragment: string) => new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode: "auto", language: "sv", two_level: true, context: { transcript: fragment } }) });

Deno.test("K42.3 'hundra ord eller mer': note, larger limits, no two-level", async () => {
  const { handler, seen } = setup();
  await (await handler(post("Förklara fotosyntes med hundra ord eller mer"))).text();
  assert(seen[0].user.includes("at least 100 words"), seen[0].user.slice(-400));
  assert(!seen[0].system.includes("[[MER]]"), "no two-level rule");
  assert((seen[0].maxTokens ?? 0) >= 400, String(seen[0].maxTokens));
  const r = setup();
  await (await r.handler(post("Förklara fotosyntes"))).text();
  assertEquals(r.seen[0].user.includes("LENGTH (K42)"), false);
});
