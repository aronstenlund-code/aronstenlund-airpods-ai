// K105 (D234): test calls have their own global web cap (50 a day), users keep 100; the sum stays 150.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps, webCap, WEB_TEST_GLOBAL_KEY } from "./handler.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";

const AFTER = Date.parse("2026-11-19T00:00:01Z");
Deno.test("K105: the two caps add up to the old one, whatever WEB_GLOBAL_PER_DAY says", () => {
  // 18 Nov (the day already used up): one shared cap as before, so no extra searches that day
  assertEquals(webCap(DEFAULT_CONFIG, true, Date.parse("2026-11-18T15:00:00Z")), { scope: "answer-web", limits: DEFAULT_CONFIG.webLimits! });
  assertEquals(webCap(DEFAULT_CONFIG, false, Date.parse("2026-11-18T23:59:59Z")), { scope: "answer-web", limits: DEFAULT_CONFIG.webLimits! });
  assertEquals(webCap(DEFAULT_CONFIG, true, AFTER), { scope: "answer-web-test", limits: { ...DEFAULT_CONFIG.webLimits!, globalPerDay: 50 } });
  assertEquals(webCap(DEFAULT_CONFIG, false, AFTER), { scope: "answer-web", limits: { ...DEFAULT_CONFIG.webLimits!, globalPerDay: 100 } });
  const cfg = { ...DEFAULT_CONFIG, webLimits: { perMinute: 5, perDay: 20, globalPerDay: 30 } };
  assertEquals(webCap(cfg, true, AFTER).limits.globalPerDay + webCap(cfg, false, AFTER).limits.globalPerDay, 30);
  assertEquals(webCap({ ...cfg, webTestGlobalPerDay: 99 }, false, AFTER).limits.globalPerDay, 0, "never more than the whole cap");
  assertEquals(WEB_TEST_GLOBAL_KEY, "answer-web-test:global:d");
});

function world(globalPerDay: number, testShare: number) {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = {
    name: "fake",
    model: "claude-haiku-5-5",
    stream(r: LLMRequest): AsyncIterable<LLMChunk> {
      seen.push(r);
      return (async function* () {
        yield { type: "text", text: "Marcus och Martinus vann. källa: svt.se" } as LLMChunk;
      })();
    },
  };
  const limiter = new MemoryRateLimiter();
  let n = 0;
  const deps: Deps = {
    // a new user per call, so only the global caps count (per-user caps are 5 a minute, 20 a day)
    authenticate: () => Promise.resolve({ id: `u${n++}`, isAnonymous: true }),
    rateLimiter: limiter,
    provider,
    recordUsage: () => {},
    config: { ...DEFAULT_CONFIG, webLimits: { perMinute: 5, perDay: 20, globalPerDay }, webTestGlobalPerDay: testShare, webSplitFromMs: 0 },
  };
  const h = createHandler(deps);
  const ask = async (test: boolean) => {
    const before = seen.length;
    const res = await h(new Request("http://x/answer", {
      method: "POST",
      headers: { "content-type": "application/json", ...(test ? { "x-earmind-test": "oscar-qa" } : {}) },
      body: JSON.stringify({ fragment: "vem vann melodifestivalen 2024", mode: "text", language: "sv", context: {} }),
    }));
    const frames = (await res.text()).split("\n\n").filter(Boolean);
    const done = JSON.parse(/^data: (.*)$/m.exec(frames.find((f) => f.startsWith("event: done"))!)![1]) as Record<string, unknown>;
    const searched = !!seen[before]?.tools?.length;
    return { searched, done };
  };
  return { ask };
}

Deno.test("K105: a test call never uses the users' cap, a user call never the test cap; each stops at its own limit", async () => {
  const w = world(5, 2); // users 3, tests 2
  // tests use their 2, then stop with web_cap_test
  assertEquals((await w.ask(true)).searched, true);
  assertEquals((await w.ask(true)).searched, true);
  const t3 = await w.ask(true);
  assertEquals(t3.searched, false);
  assertEquals(t3.done.web_cap_test, true);
  // users still have all 3 of theirs
  for (let i = 0; i < 3; i++) {
    const u = await w.ask(false);
    assertEquals(u.searched, true, `user call ${i + 1}`);
    assertEquals("web_cap_test" in u.done, false);
  }
  const u4 = await w.ask(false);
  assertEquals(u4.searched, false, "the users' cap stops at its own limit");
  assertEquals("web_cap_test" in u4.done, false, "the field is only for tests");
});

Deno.test("K105: users using up their cap leave the test cap untouched", async () => {
  const w = world(4, 2); // users 2, tests 2
  assertEquals((await w.ask(false)).searched, true);
  assertEquals((await w.ask(false)).searched, true);
  assertEquals((await w.ask(false)).searched, false);
  const t = await w.ask(true);
  assertEquals(t.searched, true);
  assert(!("web_cap_test" in t.done));
});
