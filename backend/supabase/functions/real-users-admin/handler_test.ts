import { assertEquals } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import type { AuthedUser } from "../_shared/auth.ts";
import { createRealUsersAdminHandler } from "./handler.ts";

function setup(user: AuthedUser | null, owners = ["aron@example.com"]) {
  const updates: [string, object][] = [];
  const h = createRealUsersAdminHandler({
    authenticate: () => (user ? Promise.resolve(user) : Promise.reject(new HttpError(401, "unauthorized", "no"))),
    ownerEmails: owners,
    select: () =>
      Promise.resolve([{ id: "real-0123456789", week: "2026-11-09", q: "vad är fotosyntes", mode: "prov", installs: 3, count: 4, decision: null }]),
    updateWhere: (f, p) => {
      updates.push([f, p]);
      return Promise.resolve(1);
    },
    now: () => new Date("2026-11-11T10:00:00Z"),
  });
  return { h, updates };
}
const owner: AuthedUser = { id: "u1", isAnonymous: false, email: "aron@example.com", amr: ["otp"] };
const post = (body: unknown) => new Request("http://x/real-users-admin", { method: "POST", body: JSON.stringify(body) });

Deno.test("K38 real-users-admin: only the owner signed in by email sees the candidates", async () => {
  const r = await setup(owner).h(new Request("http://x/real-users-admin"));
  assertEquals(r.status, 200);
  assertEquals((await r.json()).rows[0].q, "vad är fotosyntes");
  for (const u of [
    null,
    { id: "a", isAnonymous: true },
    { id: "b", isAnonymous: false, email: "oscar@example.com", amr: ["otp"] },
    { id: "c", isAnonymous: false, email: "aron@example.com", amr: ["password"] },
  ] as (AuthedUser | null)[]) {
    const { h, updates } = setup(u);
    const s1 = (await h(new Request("http://x/real-users-admin"))).status;
    const s2 = (await h(post({ id: "real-0123456789", decision: "approved" }))).status;
    assertEquals([s1 === 401 || s1 === 403, s2 === 401 || s2 === 403], [true, true], JSON.stringify(u));
    assertEquals(updates, [], "nothing changed by a non-owner");
  }
});

Deno.test("K38 real-users-admin: approve, reject and undo one row; anything else is 400", async () => {
  const { h, updates } = setup(owner);
  assertEquals(await (await h(post({ id: "real-0123456789", decision: "approved" }))).json(), { changed: 1 });
  await h(post({ id: "real-0123456789", decision: "rejected" }));
  await h(post({ id: "real-0123456789", decision: null }));
  assertEquals(updates, [
    ["id=eq.real-0123456789", { decision: "approved", decided_at: "2026-11-11T10:00:00.000Z" }],
    ["id=eq.real-0123456789", { decision: "rejected", decided_at: "2026-11-11T10:00:00.000Z" }],
    ["id=eq.real-0123456789", { decision: null, decided_at: null }],
  ]);
  for (const bad of [{}, { id: "real-0123456789" }, { id: "real-0123456789", decision: "yes" }, { id: "x&id=neq.0", decision: "approved" }]) {
    assertEquals((await h(post(bad))).status, 400, JSON.stringify(bad));
  }
  assertEquals(updates.length, 3, "a bad request changes nothing (no filter injection)");
});
