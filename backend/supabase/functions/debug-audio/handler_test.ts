// K43 (D140): test mode audio. Only owner/testers store anything; the purge removes only folders older than 14 days.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { AuthedUser } from "../_shared/auth.ts";
import { HttpError } from "../_shared/errors.ts";
import { createDebugAudioHandler, type DebugTurnRow } from "./handler.ts";

const anon: AuthedUser = { id: "a1", isAnonymous: true };
const tester: AuthedUser = { id: "t1", isAnonymous: false, email: "t@example.com", amr: ["otp"] };
const owner: AuthedUser = { id: "o1", isAnonymous: false, email: "aron@example.com", amr: ["otp"] };

function setup(user: AuthedUser | null, testers: string[] = [], folders = ["2026-10-20", "2026-11-11"]) {
  const store = new Map<string, Uint8Array>();
  const rows: DebugTurnRow[] = [];
  const t = new Set(testers);
  const removed: string[] = [];
  const h = createDebugAudioHandler({
    authenticate: () => user ? Promise.resolve(user) : Promise.reject(new HttpError(401, "unauthorized", "no")),
    rateLimiter: new MemoryRateLimiter(),
    ownerEmails: ["aron@example.com"],
    isTester: (u) => Promise.resolve(t.has(u)),
    setTester: (u, on) => { on ? t.add(u) : t.delete(u); return Promise.resolve(); },
    putAudio: (p, b) => { store.set(p, b); return Promise.resolve(); },
    signUrl: (p) => Promise.resolve(`https://signed/${p}`),
    folders: () => Promise.resolve(folders),
    removeFolder: (f) => { removed.push(f); return Promise.resolve(3); },
    insertTurn: (r) => { rows.push(r); return Promise.resolve(rows.length); },
    listTurns: () => Promise.resolve(rows.map((r, i) => ({ ...r, id: i + 1, created_at: "2026-11-11T20:00:00Z" }))),
    now: () => new Date("2026-11-11T21:00:00Z"),
    uuid: () => "u-1",
  });
  return { h, store, rows, t, removed };
}
const post = (body: unknown, q = "") => new Request(`http://x/debug-audio${q}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
const turn = { turn_id: "t-1", mode: "auto", audio_b64: btoa("RIFFfakeaudio"), audio_mime: "audio/wav", transcript: "vad är klockan, mitt nummer är 0701234567", words: [{ w: "vad", start_ms: 0, end_ms: 200, conf: 0.9 }], decision: "answered", answer: "Klockan är nio." };

Deno.test("K43: nobody but the owner and testers stores anything; anonymous users cannot turn it on", async () => {
  const a = setup(anon);
  assertEquals(await (await a.h(new Request("http://x/debug-audio"))).json(), { debug_audio: false });
  assertEquals((await a.h(post(turn))).status, 403);
  assertEquals((await a.h(post({}, "?action=opt_in"))).status, 403);
  assertEquals(a.store.size + a.rows.length, 0);
  assertEquals((await setup(null).h(post(turn))).status, 401);
});

Deno.test("K43: a tester opts in, a turn is stored with masked numbers; opt out stops it", async () => {
  const s = setup(tester);
  assertEquals((await s.h(post(turn))).status, 403, "not on before opting in");
  assertEquals(await (await s.h(post({}, "?action=opt_in"))).json(), { debug_audio: true });
  const r = await (await s.h(post(turn))).json();
  assertEquals(r.audio_path, "2026-11-11/t1/u-1.wav");
  assert(s.store.has("2026-11-11/t1/u-1.wav"));
  assert(!s.rows[0].transcript!.includes("0701234567"), s.rows[0].transcript!);
  assertEquals(s.rows[0].words![0].w, "vad");
  await s.h(post({}, "?action=opt_out"));
  assertEquals((await s.h(post(turn))).status, 403);
});

Deno.test("K43: the owner is on without opting in and sees the turns with signed links; others cannot", async () => {
  const o = setup(owner);
  assertEquals(await (await o.h(new Request("http://x/debug-audio"))).json(), { debug_audio: true });
  await o.h(post(turn));
  const v = await (await o.h(new Request("http://x/debug-audio?view=owner"))).json();
  assertEquals(v.turns[0].audio_url, "https://signed/2026-11-11/o1/u-1.wav");
  assertEquals((await setup(tester, ["t1"]).h(new Request("http://x/debug-audio?view=owner"))).status, 403);
});

Deno.test("K43: bad audio is refused; the purge removes only folders older than 14 days", async () => {
  const s = setup(tester, ["t1"]);
  assertEquals((await s.h(post({ ...turn, audio_mime: "video/mp4" }))).status, 400);
  assertEquals((await s.h(post({ ...turn, audio_b64: btoa("x".repeat(1_500_001)) }))).status, 413);
  assertEquals((await s.h(post({ turn_id: "x" }))).status, 400);
  const p = setup(null, [], ["2026-10-20", "2026-10-28", "2026-11-11", "junk"]);
  assertEquals(await (await p.h(post({}, "?action=purge"))).json(), { removed: 3 });
  assertEquals(p.removed, ["2026-10-20"]);
});
