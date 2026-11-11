import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { AuthedUser } from "../_shared/auth.ts";
import { HttpError } from "../_shared/errors.ts";
import { type Choice, createLogoVoteHandler, results } from "./handler.ts";

function setup(user: AuthedUser | null, seed: Record<string, Choice> = {}) {
  const votes = new Map<string, Choice>(Object.entries(seed));
  const h = createLogoVoteHandler({
    authenticate: () => (user ? Promise.resolve(user) : Promise.reject(new HttpError(401, "unauthorized", "no"))),
    rateLimiter: new MemoryRateLimiter(),
    ownerEmails: ["aron@example.com"],
    cast: (u, c) => {
      votes.set(u, c);
      return Promise.resolve();
    },
    own: (u) => Promise.resolve(votes.get(u) ?? null),
    counts: () => {
      const o = { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 };
      for (const c of votes.values()) o[c]++;
      return Promise.resolve(o);
    },
  });
  return { h, votes };
}
const anon: AuthedUser = { id: "u1", isAnonymous: true };
const vote = (choice: unknown) => new Request("http://x/logo-vote", { method: "POST", body: JSON.stringify({ choice }) });
const many = (n: number) => Object.fromEntries(Array.from({ length: n }, (_, i) => [`v${i}`, (["A", "B", "C"] as Choice[])[i % 3]]));

Deno.test("K39 logo-vote: one vote per user, can be changed, only the own vote comes back", async () => {
  const { h, votes } = setup(anon, { other: "C" });
  assertEquals(await (await h(new Request("http://x/logo-vote"))).json(), { choice: null });
  assertEquals(await (await h(vote("a"))).json(), { choice: "A" });
  assertEquals(await (await h(vote("B"))).json(), { choice: "B" });
  assertEquals(votes.size, 2, "the change replaced the vote");
  assertEquals(await (await h(new Request("http://x/logo-vote"))).json(), { choice: "B" });
  for (const bad of ["G", "", null, 1]) assertEquals((await h(vote(bad))).status, 400);
  assertEquals((await setup(null).h(vote("A"))).status, 401);
});

Deno.test("K39 logo-vote: percent only after voting and from 20 votes; the totals only for the owner", async () => {
  const few = setup(anon, many(10));
  assertEquals(await (await few.h(vote("A"))).json(), { choice: "A" }, "11 votes: no percent yet");
  const lots = setup(anon, many(19));
  const r = await (await lots.h(vote("A"))).json();
  assertEquals(r.results.total, 20);
  assertEquals(r.results.percent.A, 40);
  assertEquals(await (await setup(anon, many(30)).h(new Request("http://x/logo-vote"))).json(), { choice: null }, "no peek before voting");
  assertEquals((await setup(anon, many(3)).h(new Request("http://x/logo-vote?view=owner"))).status, 403);
  const owner = setup({ id: "o", isAnonymous: false, email: "aron@example.com", amr: ["otp"] }, many(3));
  assertEquals((await (await owner.h(new Request("http://x/logo-vote?view=owner"))).json()).results.total, 3);
  const z = { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 };
  assertEquals(results(z).percent, z);
});

Deno.test("K41: six choices A-F; old votes stay and count", async () => {
  const { h } = setup(anon, { old1: "A", old2: "C" });
  assertEquals(await (await h(vote("F"))).json(), { choice: "F" });
  assertEquals((await setup(anon).h(vote("G"))).status, 400);
  const r = results({ A: 1, B: 0, C: 1, D: 0, E: 0, F: 2 });
  assertEquals([r.total, r.F, r.percent.F, r.percent.A], [4, 2, 50, 25]);
});
