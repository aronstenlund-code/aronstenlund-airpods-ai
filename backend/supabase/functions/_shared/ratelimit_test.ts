import { assertEquals } from "jsr:@std/assert@1.0.8";
import { enforceLimits, MemoryRateLimiter, type RateLimiter } from "./ratelimit.ts";

Deno.test("fixed window: allows up to the limit, then denies with retry-after, then resets", async () => {
  let t = 1_000_000_000_000;
  const rl = new MemoryRateLimiter(() => t);
  for (let i = 0; i < 3; i++) assertEquals((await rl.check("k", 3, 60)).allowed, true);
  const denied = await rl.check("k", 3, 60);
  assertEquals(denied.allowed, false);
  assertEquals(denied.retryAfterSec > 0 && denied.retryAfterSec <= 60, true);
  assertEquals((await rl.check("other", 3, 60)).allowed, true, "keys are independent");
  t += 61_000;
  assertEquals((await rl.check("k", 3, 60)).allowed, true);
});

Deno.test("weighted cost (TTS characters)", async () => {
  const rl = new MemoryRateLimiter(() => 0);
  assertEquals((await rl.check("c", 100, 60, 60)).allowed, true);
  assertEquals((await rl.check("c", 100, 60, 60)).allowed, false);
  assertEquals((await rl.check("c", 100, 60, 40)).allowed, true);
});

Deno.test("enforceLimits applies per-minute, per-day and global caps", async () => {
  const rl = new MemoryRateLimiter(() => 0);
  const limits = { perMinute: 2, perDay: 100, globalPerDay: 3 };
  assertEquals((await enforceLimits(rl, "answer", "u1", limits)).allowed, true);
  assertEquals((await enforceLimits(rl, "answer", "u1", limits)).allowed, true);
  assertEquals((await enforceLimits(rl, "answer", "u1", limits)).allowed, false, "per-minute");
  assertEquals((await enforceLimits(rl, "answer", "u2", limits)).allowed, true);
  assertEquals(
    (await enforceLimits(rl, "answer", "u3", limits)).allowed,
    false,
    "global kill switch",
  );
});

Deno.test("a failing limiter denies (fail closed)", async () => {
  const broken: RateLimiter = { check: () => Promise.reject(new Error("db down")) };
  const r = await enforceLimits(broken, "answer", "u", {
    perMinute: 1,
    perDay: 1,
    globalPerDay: 1,
  });
  assertEquals(r.allowed, false);
});

Deno.test("enforceLimits uses a single checkMany round trip when the limiter supports it", async () => {
  let many = 0, single = 0;
  const rl: RateLimiter = {
    check: () => {
      single++;
      return Promise.resolve({ allowed: true, retryAfterSec: 0 });
    },
    checkMany: (checks) => {
      many++;
      assertEquals(checks.length, 3);
      return Promise.resolve({ allowed: false, retryAfterSec: 9 });
    },
  };
  const r = await enforceLimits(rl, "answer", "u", { perMinute: 1, perDay: 1, globalPerDay: 1 });
  assertEquals([many, single, r.allowed, r.retryAfterSec], [1, 0, false, 9]);
});
