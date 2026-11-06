import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createFeedbackHandler, type FeedbackRow, validateFeedback } from "./handler.ts";
import { createSharedHandler, type SharedRow, validateShared } from "../shared-history/handler.ts";
import { createAdminHandler } from "../feedback-admin/handler.ts";

const INSTALL = "abcDEF12_-xyz789";
const req = (method: string, url: string, body?: unknown, headers: Record<string, string> = {}) =>
  new Request(`http://x/${url}`, {
    method,
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

function fb(over: Record<string, unknown> = {}) {
  const rows: FeedbackRow[] = [];
  const handler = createFeedbackHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    insert: (r) => {
      rows.push(r);
      return Promise.resolve();
    },
    ...over,
  });
  return { handler, rows };
}

Deno.test("D57 feedback: a report is stored with user_id from the JWT, never from the body", async () => {
  const { handler, rows } = fb();
  const res = await handler(req("POST", "feedback", {
    install_id: INSTALL,
    type: "report",
    fragment: "vad är pi",
    answer: "Pi är tre komma ett fyra.",
    comment: "fel decimal",
    mode: "push_to_talk",
    persona: "tutor",
    timings: { ttft_ms: 700 },
    app_version: "1.0 (42)",
    user_id: "someone-else",
  }));
  assertEquals(res.status, 200);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].user_id, "u1");
  assertEquals(rows[0].type, "report");
  assertEquals(rows[0].timings, { ttft_ms: 700 });
});

Deno.test("D57 feedback: validation (install id, type, content required, sizes, control characters)", () => {
  const ok = { install_id: INSTALL, comment: "bra app" };
  assertEquals(validateFeedback(ok, "u").type, "report");
  assertEquals(validateFeedback({ ...ok, type: "suggestion" }, "u").type, "suggestion");
  const code = (o: unknown) => {
    try {
      validateFeedback(o, "u");
      return 0;
    } catch (e) {
      return (e as HttpError).status;
    }
  };
  assertEquals(code({ comment: "x" }), 400, "install id required");
  assertEquals(code({ ...ok, install_id: "kort" }), 400);
  assertEquals(code({ ...ok, install_id: "has spaces and ! chars" }), 400);
  assertEquals(code({ ...ok, type: "spam" }), 400);
  assertEquals(code({ install_id: INSTALL }), 400, "nothing to store");
  assertEquals(code({ ...ok, comment: "x".repeat(2001) }), 413);
  assertEquals(code({ ...ok, answer: "x".repeat(4001) }), 413);
  assertEquals(code({ ...ok, timings: "no" }), 400);
  assertEquals(code({ ...ok, timings: { a: "x".repeat(3000) } }), 413);
  assertEquals(code([]), 400);
  assertEquals(validateFeedback({ ...ok, comment: "a\u0000b" }, "u").comment, "ab");
});

Deno.test("D57 feedback: auth, method, rate limit and storage failure", async () => {
  const unauth = createFeedbackHandler({
    authenticate: () => Promise.reject(new HttpError(401, "unauthorized", "no")),
    rateLimiter: new MemoryRateLimiter(),
    insert: () => Promise.resolve(),
  });
  assertEquals((await unauth(req("POST", "feedback", {}))).status, 401);
  const { handler } = fb();
  assertEquals((await handler(req("GET", "feedback"))).status, 405);
  const limited = fb({ limits: { perMinute: 1, perDay: 10, globalPerDay: 10 } }).handler;
  const b = { install_id: INSTALL, comment: "hej" };
  assertEquals((await limited(req("POST", "feedback", b))).status, 200);
  assertEquals((await limited(req("POST", "feedback", b))).status, 429);
  const broken = fb({ insert: () => Promise.reject(new Error("db down")) }).handler;
  const res = await broken(req("POST", "feedback", b));
  assertEquals(res.status, 503);
  assert(!(await res.text()).includes("db down"), "internal error text is not leaked");
  assertEquals(
    (await handler(new Request("http://x/f", { method: "POST", body: "{" }))).status,
    400,
  );
});

function sh() {
  const rows: SharedRow[] = [];
  const filters: string[] = [];
  const handler = createSharedHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    insertMany: (r) => {
      rows.push(...r);
      return Promise.resolve();
    },
    deleteWhere: (f) => {
      filters.push(f);
      return Promise.resolve(7);
    },
  });
  return { handler, rows, filters };
}

Deno.test("D57 shared history: batch upload, verbatim, limits", async () => {
  const { handler, rows } = sh();
  const items = [
    {
      fragment: "vad är pi",
      answer: "Pi är ungefär tre komma ett fyra.",
      summary: "Om pi.",
      mode: "tutor",
    },
    { fragment: "och e", answer: "e är ungefär två komma sju." },
  ];
  const res = await handler(req("POST", "shared-history", { install_id: INSTALL, items }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).stored, 2);
  assertEquals(rows.length, 2);
  assertEquals(rows[0].user_id, "u1");
  assertEquals(rows[0].fragment, "vad är pi");
  assertEquals(rows[1].summary, null);
  const code = (b: unknown) => {
    try {
      validateShared(b, "u");
      return 0;
    } catch (e) {
      return (e as HttpError).status;
    }
  };
  assertEquals(code({ install_id: INSTALL, items: [] }), 400);
  assertEquals(
    code({ install_id: INSTALL, items: Array(51).fill({ fragment: "a", answer: "b" }) }),
    413,
  );
  assertEquals(code({ install_id: INSTALL, items: [{ fragment: "a" }] }), 400);
  assertEquals(
    code({ install_id: INSTALL, items: [{ fragment: "a".repeat(1001), answer: "b" }] }),
    413,
  );
  assertEquals(code({ install_id: "x", items }), 400);
  assertEquals(code({ items }), 400);
});

Deno.test("D57 shared history: opt-out deletes the caller's rows (by user id, and install id when given)", async () => {
  const { handler, filters } = sh();
  const r1 = await handler(req("DELETE", "shared-history"));
  assertEquals(r1.status, 200);
  assertEquals((await r1.json()).deleted, 7);
  assertEquals(filters[0], "user_id=eq.u1");
  const r2 = await handler(req("DELETE", "shared-history", { install_id: INSTALL }));
  assertEquals(r2.status, 200);
  assertEquals(filters[1], `or=(user_id.eq.u1,install_id.eq.${INSTALL})`);
  const r3 = await handler(req("DELETE", "shared-history", { install_id: "bad id!" }));
  assertEquals(r3.status, 400);
  assertEquals(filters.length, 2, "a bad install id deletes nothing");
  assertEquals((await handler(req("GET", "shared-history"))).status, 405);
});

Deno.test("D57 feedback-admin: service role only, newest first, html escapes", async () => {
  const queries: string[] = [];
  const handler = createAdminHandler({
    serviceKey: "service-secret",
    select: (q) => {
      queries.push(q);
      return Promise.resolve([{
        created_at: "t",
        type: "report",
        fragment: "<b>x</b>",
        comment: "hej",
      }]);
    },
  });
  assertEquals((await handler(req("GET", "feedback-admin"))).status, 401);
  assertEquals(
    (await handler(req("GET", "feedback-admin", undefined, { authorization: "Bearer other" })))
      .status,
    401,
  );
  const ok = await handler(
    req("GET", "feedback-admin?limit=5&type=report", undefined, {
      authorization: "Bearer service-secret",
    }),
  );
  assertEquals(ok.status, 200);
  assertEquals((await ok.json()).count, 1);
  assertEquals(queries[0], "select=*&order=created_at.desc&limit=5&type=eq.report");
  const html = await handler(
    req("GET", "feedback-admin?format=html&type=drop%20table", undefined, {
      authorization: "Bearer service-secret",
    }),
  );
  const t = await html.text();
  assert(t.includes("&#60;b&#62;x"), "text is escaped");
  assert(!queries[1].includes("drop"), "unknown type filter is ignored");
  const noKey = createAdminHandler({ serviceKey: null, select: () => Promise.resolve([]) });
  assertEquals(
    (await noKey(req("GET", "feedback-admin", undefined, { authorization: "Bearer x" }))).status,
    401,
  );
});
