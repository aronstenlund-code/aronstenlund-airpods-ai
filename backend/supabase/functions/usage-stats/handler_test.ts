import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { createStatsHandler } from "./handler.ts";

const rows = [
  {
    day: "2026-11-05",
    category: "matte",
    requests: 3,
    avg_ttft_ms: 700,
    input_tokens: 10,
    output_tokens: 5,
    est_cost_usd: 0.001,
  },
  {
    day: "2026-11-05",
    category: "historia",
    requests: 2,
    avg_ttft_ms: 800,
    input_tokens: 10,
    output_tokens: 5,
    est_cost_usd: 0.001,
  },
  {
    day: "2026-11-04",
    category: "matte",
    requests: 1,
    avg_ttft_ms: 650,
    input_tokens: 1,
    output_tokens: 1,
    est_cost_usd: 0,
  },
];
const mk = () => {
  const calls: unknown[] = [];
  const h = createStatsHandler({
    serviceKey: "svc-key",
    rpc: (fn, a) => (calls.push([fn, a]), Promise.resolve(rows)),
  });
  return { h, calls };
};
const get = (auth: string | null, q = "") =>
  new Request("http://x/usage-stats" + q, { headers: auth ? { authorization: auth } : {} });

Deno.test("usage-stats: service role only", async () => {
  const { h, calls } = mk();
  for (const a of [null, "Bearer anon-or-user-jwt", "Bearer svc-key2", "Basic svc-key"]) {
    assertEquals((await h(get(a))).status, 401, String(a));
  }
  assertEquals(calls.length, 0, "no database call without the service key");
  assertEquals(
    (await createStatsHandler({ serviceKey: null, rpc: () => Promise.resolve([]) })(
      get("Bearer x"),
    )).status,
    401,
  );
});

Deno.test("usage-stats: counts per category and day, days clamped, html escapes", async () => {
  const { h, calls } = mk();
  const j = await (await h(get("Bearer svc-key", "?days=9999"))).json();
  assertEquals(j.by_category, { matte: 4, historia: 2 });
  assertEquals(j.rows.length, 3);
  assertEquals(calls[0], ["usage_stats", { p_days: 366 }]);
  const html = await (await h(get("Bearer svc-key", "?format=html"))).text();
  assertStringIncludes(html, "<td>matte</td>");
  assertEquals(
    (await h(
      new Request("http://x/usage-stats", {
        method: "POST",
        headers: { authorization: "Bearer svc-key" },
      }),
    )).status,
    405,
  );
});
