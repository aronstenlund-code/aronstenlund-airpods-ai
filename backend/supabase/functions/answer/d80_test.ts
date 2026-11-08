import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type UsageRecord } from "./handler.ts";
import { MockProvider } from "./llm/mock.ts";

const ask = () =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify({ fragment: "vad är fotosyntes", mode: "text", language: "sv", context: {} }),
  });
const tick = (ms = 60) => new Promise((r) => setTimeout(r, ms));

Deno.test("D80 an answer the client aborts does not count against the user's own allowance", async () => {
  const rl = new MemoryRateLimiter();
  const usage: UsageRecord[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: rl,
    provider: new MockProvider({ delayMs: 15, chunkSize: 2 }), // slow enough to abort mid-answer
    recordUsage: (r) => void usage.push(r),
    config: { ...DEFAULT_CONFIG, limits: { perMinute: 2, perDay: 2, globalPerDay: 100 } },
  });
  for (let i = 0; i < 4; i++) {
    const res = await h(ask());
    assertEquals(res.status, 200, `aborted request ${i} is still allowed`);
    const reader = res.body!.getReader();
    await reader.read(); // first bytes arrived
    await reader.cancel(); // the app redoes its preliminary answer
    await tick();
  }
  assertEquals(rl.count("answer:u:u1:d", 86400), 0, "aborted answers are given back");
  assert(usage.every((u) => u.status === "aborted"), JSON.stringify(usage.map((u) => u.status)));
  // network and global windows stay counted (aborting does not buy free answers)
  assertEquals(rl.count("answer:global:d", 86400), 4);
  // two complete answers fit the per-day allowance of 2, the third is refused
  for (let i = 0; i < 2; i++) {
    const res = await h(ask());
    assertEquals(res.status, 200);
    await res.text();
  }
  await tick();
  assertEquals(rl.count("answer:u:u1:d", 86400), 2);
  assertEquals((await h(ask())).status, 429);
});

Deno.test("Oscar 2026-11-08 an aborted answer is also given back in the new-session window", async () => {
  const rl = new MemoryRateLimiter();
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "n1", isAnonymous: true, sessionStartSec: Math.floor(Date.now() / 1000) - 30 }),
    rateLimiter: rl,
    provider: new MockProvider({ delayMs: 15, chunkSize: 2 }),
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, appGuard: { networkPerDay: 1500, newUserAgeSec: 600, newUserPerHour: 3 } },
  });
  for (let i = 0; i < 6; i++) {
    const res = await h(ask());
    assertEquals(res.status, 200, `aborted ${i}`);
    const reader = res.body!.getReader();
    await reader.read();
    await reader.cancel();
    await tick();
  }
  assertEquals(rl.count("answer:new:u:n1:h", 3600), 0);
});
