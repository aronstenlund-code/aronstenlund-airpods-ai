import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createSttHandler, DEFAULT_STT_CONFIG, type SttDeps } from "./handler.ts";

function setup(over: Partial<SttDeps> = {}, reply?: Response) {
  const calls: { url: string; init: RequestInit }[] = [];
  const recs: Record<string, unknown>[] = [];
  const deps: SttDeps = {
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    apiKey: "xi-secret",
    config: DEFAULT_STT_CONFIG,
    recordUsage: (r) => void recs.push(r),
    fetchImpl: (url, init) => {
      calls.push({ url: String(url), init: init! });
      return Promise.resolve(
        reply ?? new Response(JSON.stringify({ token: "tok-123" }), { status: 200 }),
      );
    },
    ...over,
  };
  return { handler: createSttHandler(deps), calls, recs };
}
const get = () => new Request("http://x/stt-token", { method: "GET" });
const post = (b: unknown) =>
  new Request("http://x/stt-token", { method: "POST", body: JSON.stringify(b) });

Deno.test("mints a single-use token; the API key goes upstream only, never to the client", async () => {
  const { handler, calls, recs } = setup();
  const res = await handler(get());
  const j = await res.json();
  assertEquals([res.status, j.token, j.expires_in, j.model_id], [
    200,
    "tok-123",
    900,
    "scribe_v2_realtime",
  ]);
  assert(!JSON.stringify(j).includes("xi-secret"));
  assert(calls[0].url.endsWith("/v1/single-use-token/realtime_scribe"));
  assertEquals((calls[0].init.headers as Record<string, string>)["xi-api-key"], "xi-secret");
  assertEquals([recs[0].endpoint, recs[0].status], ["stt-token", "ok"]);
});

Deno.test("missing permission / unconfigured / quota fail closed with fallback", async () => {
  const perm = setup(
    {},
    new Response('{"detail":{"status":"missing_permissions"}}', { status: 401 }),
  );
  const r1 = await perm.handler(get());
  assertEquals([r1.status, (await r1.json()).error.fallback], [503, true]);
  assertEquals((await setup({ apiKey: null }).handler(get())).status, 503);
  assertEquals((await setup({}, new Response("{}", { status: 402 })).handler(get())).status, 503);
  assertEquals((await setup({}, new Response("{}", { status: 200 })).handler(get())).status, 502);
});

Deno.test("per-user minute limit applies; usage report logs seconds and cost", async () => {
  const { handler } = setup({ config: { limits: { perMinute: 1, perDay: 10, globalPerDay: 10 } } });
  assertEquals((await handler(get())).status, 200);
  assertEquals((await handler(get())).status, 429);
  const { handler: h2, recs } = setup();
  assertEquals((await h2(post({ seconds: 36 }))).status, 200);
  assertEquals(recs[0].endpoint, "stt");
  assertEquals(recs[0].total_ms, 36000);
  assert(Math.abs((recs[0].est_cost_usd as number) - 0.0039) < 1e-9);
  assertEquals((await h2(post({ seconds: 99999 }))).status, 400);
  assertEquals((await h2(new Request("http://x/stt-token", { method: "PUT" }))).status, 405);
});

Deno.test("Toby T10: a mint that ElevenLabs rejects gives the user's and the global units back", async () => {
  const rl = new MemoryRateLimiter();
  let status = 402;
  const h = createSttHandler({
    authenticate: () => Promise.resolve({ id: "u-t10", isAnonymous: true }),
    rateLimiter: rl,
    apiKey: "k",
    config: { limits: { perMinute: 2, perDay: 2, globalPerDay: 2 } },
    recordUsage: () => {},
    fetchImpl: () => Promise.resolve(status === 200 ? new Response(JSON.stringify({ token: "t" })) : new Response("quota_exceeded", { status })),
  });
  for (let i = 0; i < 5; i++) assertEquals((await h(new Request("http://x/stt-token"))).status, 503, "quota: fallback, not 429");
  assertEquals(rl.count("stt:global:d", 86400), 0, "nothing counted");
  status = 200;
  assertEquals((await h(new Request("http://x/stt-token"))).status, 200);
  assertEquals((await h(new Request("http://x/stt-token"))).status, 200);
  assertEquals((await h(new Request("http://x/stt-token"))).status, 429, "a real token still counts");
});
