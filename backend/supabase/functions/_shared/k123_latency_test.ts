// K123 (Deangelo 23:38): the first answer as fast as possible. The usage row is written in the background
// (EdgeRuntime.waitUntil), never before the answer: a code answer (crisis, calculation, command) waited for it.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { supabaseUsageSink } from "./usage.ts";
import type { RestDb } from "./restdb.ts";

Deno.test("K123: the usage sink returns at once and hands the insert to waitUntil", async () => {
  let release!: () => void;
  const pending = new Promise<void>((r) => (release = r));
  const kept: Promise<unknown>[] = [];
  const g = globalThis as { EdgeRuntime?: { waitUntil(p: Promise<unknown>): void } };
  const before = g.EdgeRuntime;
  g.EdgeRuntime = { waitUntil: (p) => void kept.push(p) };
  try {
    const sink = supabaseUsageSink({ insert: () => pending } as unknown as RestDb);
    const t0 = performance.now();
    await sink({ user_id: "u" });
    assert(performance.now() - t0 < 20, "did not wait for the insert");
    assertEquals(kept.length, 1, "the insert still runs to the end");
    release();
    await kept[0];
  } finally {
    g.EdgeRuntime = before;
  }
});

Deno.test("K123: /exam reads the credits while the rate limit is checked (one database wait before the model, not two)", async () => {
  const { createExamHandler } = await import("../exam/handler.ts");
  const { MemoryRateLimiter } = await import("./ratelimit.ts");
  const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
  const mem = new MemoryRateLimiter();
  let started = 0;
  const t0 = performance.now();
  const h = createExamHandler({
    authenticate: () => Promise.resolve({ id: "u-k123", isAnonymous: true }),
    rateLimiter: { check: async (k: string, l: number, w: number, c?: number) => (await wait(80), mem.check(k, l, w, c)), checkMany: async (cs: { key: string; limit: number; windowSec: number }[], c?: number) => {
      await wait(80); // the platform's limiter: every window in one round trip (one RPC)
      let last = await mem.check(cs[0].key, cs[0].limit, cs[0].windowSec, c);
      for (const x of cs.slice(1)) if (last.allowed) last = await mem.check(x.key, x.limit, x.windowSec, c);
      return last;
    } } as unknown as InstanceType<typeof MemoryRateLimiter>,
    provider: { name: "f", model: "f", stream: () => (started = performance.now() - t0, (async function* () { throw new Error("stop"); })()) },
    quota: async () => (await wait(80), { used: 0, lim: 50_000 }),
  });
  await h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.3" }, body: JSON.stringify({ action: "drill", questions: 3, text: "Fotosyntes är när växter gör socker av ljus och vatten. Syre bildas." }) }));
  assert(started > 0, "the model was started");
  assert(started < 150, `the model started after ${Math.round(started)} ms (two 80 ms waits one after the other = 160)`);
});
