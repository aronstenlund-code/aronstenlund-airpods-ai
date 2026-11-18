// K101: deleting one's own account, with an in-memory store.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { type AccountFile, createAccountHandler, SUBSCRIPTION_NOTICE } from "./handler.ts";

function world(o: { subActive?: boolean } = {}) {
  const items = [
    { user_id: "u1", hash: "mine1" }, { user_id: "u1", hash: "shared" }, { user_id: "u1", hash: "cue" }, { user_id: "u1", hash: "mine2" },
    { user_id: "u2", hash: "shared" }, { user_id: "u2", hash: "theirs" },
  ];
  const audio = new Map<string, AccountFile>(["mine1", "mine2", "shared", "cue", "theirs"].map((h) => [h, { hash: h, model: "m", voice_id: "v" }]));
  const removed: { bucket: string; paths: string[] }[] = [];
  const users = new Set(["u1", "u2"]);
  const ownRows = new Set(["u1", "u2"]);
  const debug = new Map([["u1", ["u1/turn1.m4a"]], ["u2", ["u2/turn9.m4a"]]]);
  const h = createAccountHandler({
    authenticate: (req) => {
      const u = req.headers.get("x-user");
      return u ? Promise.resolve({ id: u, isAnonymous: true }) : Promise.reject(Object.assign(new Error("no"), { status: 401 }));
    },
    rateLimiter: new MemoryRateLimiter(),
    audioPath: (x) => `${x.slice(0, 2)}/${x}.mp3`,
    cueHashes: () => Promise.resolve(new Set(["cue"])),
    removeObjects: (bucket, paths) => (removed.push({ bucket, paths }), Promise.resolve()),
    store: {
      drillFiles: (u) => Promise.resolve(items.filter((i) => i.user_id === u).map((i) => audio.get(i.hash)!).filter(Boolean)),
      usedByOthers: (hs, u) => Promise.resolve(new Set(items.filter((i) => i.user_id !== u && hs.includes(i.hash)).map((i) => i.hash))),
      deleteAudioRows: (hs) => (hs.forEach((x) => audio.delete(x)), Promise.resolve()),
      debugAudioPaths: (u) => Promise.resolve(debug.get(u) ?? []),
      subscription: () => Promise.resolve({ active: !!o.subActive, until: o.subActive ? "2026-11-25T10:00:00.000Z" : null }),
      deleteOwnRows: (u) => (ownRows.delete(u), Promise.resolve()),
      deleteAuthUser: (u) => {
        users.delete(u);
        for (let i = items.length - 1; i >= 0; i--) if (items[i].user_id === u) items.splice(i, 1); // the cascade
        return Promise.resolve();
      },
    },
  });
  const call = (body: unknown, user: string | null = "u1", path = "/account/delete") =>
    h(new Request(`http://x${path}`, { method: "POST", headers: user ? { "x-user": user } : {}, body: JSON.stringify(body) }));
  return { call, audio, removed, users, ownRows, items };
}

Deno.test("K101: the account and its own audio go; audio another account or every drill uses stays; nobody else is touched", async () => {
  const w = world();
  const r = await w.call({ confirm: true });
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals([j.deleted, j.removed, j.subscription.active, j.notice], [true, { audio_files: 2, shared_audio_kept: 2 }, false, undefined]);
  assertEquals([...w.audio.keys()].sort(), ["cue", "shared", "theirs"]);
  assertEquals(w.removed, [{ bucket: "drill_audio", paths: ["mi/mine1.mp3", "mi/mine2.mp3"] }, { bucket: "debug_audio", paths: ["u1/turn1.m4a"] }]);
  assertEquals([[...w.users], [...w.ownRows]], [["u2"], ["u2"]]);
  assertEquals(w.items.map((i) => i.user_id), ["u2", "u2"]);
});

Deno.test("K101: only with confirm, only POST, only signed in; the body action works too; an active subscription is named", async () => {
  const w = world({ subActive: true });
  assertEquals((await w.call({})).status, 400);
  assertEquals((await (await w.call({ confirm: "yes" })).json()).error.code, "confirm_required");
  assertEquals((await w.call({ confirm: true }, null)).status >= 400, true);
  assertEquals((await w.call({ action: "other", confirm: true }, "u1", "/account")).status, 400);
  assertEquals(w.users.size, 2, "nothing deleted by the refused calls");
  const r = await (await w.call({ action: "delete", confirm: true }, "u1", "/account")).json();
  assertEquals([r.deleted, r.subscription.active, r.notice], [true, true, SUBSCRIPTION_NOTICE]);
  assertEquals([...w.users], ["u2"]);
});
