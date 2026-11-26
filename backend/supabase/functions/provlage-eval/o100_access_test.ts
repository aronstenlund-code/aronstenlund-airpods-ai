// O100 S1 (Oscar 2026-11-26, HIGH): /provlage-eval ran Sonnet/Opus (and Scribe outside test mode) for any signed-in
// account, anonymous ones too, without the user's limits or credits. Now only the owner, or test traffic that also
// comes from GitHub Actions (the evals); everyone else 403 before any model work. A pretend model only.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { runWithTest, setCiRangesForTest } from "../_shared/testmode.ts";
import type { AuthedUser } from "../_shared/auth.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createEvalHandler } from "./handler.ts";

const OWNER = "owner@example.com";
function world(user: AuthedUser) {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = { name: "fake", model: "claude-haiku-5-5", stream(r: LLMRequest): AsyncIterable<LLMChunk> {
    seen.push(r);
    return (async function* () { yield { type: "text", text: '{"correct":1}' } as LLMChunk; })();
  } };
  const h = createEvalHandler({ authenticate: () => Promise.resolve(user), rateLimiter: new MemoryRateLimiter(), provider, ownerEmails: [OWNER] });
  return { h, seen };
}
const req = (ip = "203.0.113.9") => new Request("http://x/provlage-eval", { method: "POST", headers: { "x-forwarded-for": ip },
  body: JSON.stringify({ action: "grade", judge: "sonnet", case: { q: "fotosyntes", grade: "Åk 7" }, answer: "Fotosyntes är …" }) });

Deno.test("O100 S1: an anonymous and an ordinary account are refused 403, before any model call", async () => {
  for (const user of [{ id: "a1", isAnonymous: true }, { id: "u1", isAnonymous: false, email: "someone@example.com", amr: ["otp"] }] as AuthedUser[]) {
    const w = world(user);
    const r = await w.h(req());
    assertEquals([r.status, (await r.json()).error.code], [403, "forbidden"]);
    assertEquals(w.seen.length, 0);
  }
});

Deno.test("O100 S1: the test header alone (anyone can send it) is not enough; test traffic from GitHub Actions is", async () => {
  setCiRangesForTest(["198.51.100.0/24"]);
  const anon = { id: "a1", isAnonymous: true } as AuthedUser;
  const spoofed = world(anon);
  const r1 = await runWithTest({ test: true, reason: "header", userId: "a1" }, () => spoofed.h(req("203.0.113.9")));
  assertEquals(r1.status, 403);
  const ci = world(anon);
  const r2 = await runWithTest({ test: true, reason: "ci", userId: "a1" }, () => ci.h(req("198.51.100.7")));
  assertEquals(r2.status, 200);
  setCiRangesForTest([]);
});

Deno.test("O100 S1: the owner (signed in by email) gets through", async () => {
  const w = world({ id: "o1", isAnonymous: false, email: OWNER, amr: ["otp"] } as AuthedUser);
  assertEquals((await w.h(req())).status, 200);
  const pw = world({ id: "o2", isAnonymous: false, email: OWNER, amr: ["password"] } as AuthedUser);
  assertEquals((await pw.h(req())).status, 403, "the owner's address with a password sign-up is not the owner (K30)");
});
