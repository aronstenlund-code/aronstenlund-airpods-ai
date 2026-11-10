import { assertEquals } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import type { AuthedUser } from "../_shared/auth.ts";
import { createQaLogHandler } from "./handler.ts";

function setup(user: AuthedUser | null, owners = ["aron@example.com"]) {
  const deleted: string[] = [];
  const h = createQaLogHandler({
    authenticate: () => (user ? Promise.resolve(user) : Promise.reject(new HttpError(401, "unauthorized", "no"))),
    ownerEmails: owners,
    select: () => Promise.resolve([{ id: 2, created_at: "2026-11-10T20:00:00Z", mode: "tutor", persona: "tutor", question: "q", answer: "a" }]),
    deleteWhere: (f) => {
      deleted.push(f);
      return Promise.resolve(3);
    },
  });
  return { h, deleted };
}
const owner: AuthedUser = { id: "u1", isAnonymous: false, email: "Aron@Example.com", amr: ["otp"] };

Deno.test("K30 qa-log: only the owner signed in by email reads; the rows and the newest time come back", async () => {
  const r = await setup(owner).h(new Request("http://x/qa-log"));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.rows.length, 1);
  assertEquals(j.newest, "2026-11-10T20:00:00Z");
  for (const u of [
    null,
    { id: "a", isAnonymous: true },
    { id: "b", isAnonymous: false, email: "someone@example.com", amr: ["otp"] },
    { id: "c", isAnonymous: false, email: "aron@example.com", amr: ["password"] },
  ] as (AuthedUser | null)[]) {
    const s = (await setup(u).h(new Request("http://x/qa-log"))).status;
    assertEquals(s === 401 || s === 403, true, JSON.stringify(u));
  }
  assertEquals((await setup(owner, [""]).h(new Request("http://x/qa-log"))).status, 503, "OWNER_EMAIL unset");
  assertEquals((await setup({ id: "a", isAnonymous: true }, [""]).h(new Request("http://x/qa-log"))).status, 403, "anonymous never sees the config");
});

Deno.test("K30 qa-log: 'Hämtat' deletes up to the newest fetched row, nothing else", async () => {
  const { h, deleted } = setup(owner);
  const r = await h(new Request("http://x/qa-log", { method: "POST", body: JSON.stringify({ fetched_until: "2026-11-10T20:00:00Z" }) }));
  assertEquals(await r.json(), { deleted: 3 });
  assertEquals(deleted, ["created_at=lte.2026-11-10T20%3A00%3A00.000Z"]);
  assertEquals((await h(new Request("http://x/qa-log", { method: "POST", body: "{}" }))).status, 400);
});
