// K46 (D142-D145): drills and audio per account, with an in-memory database, storage and voice. Invented text only.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { type AudioRow, createDrillHandler, type DrillRow, type ItemRow, longVoice, type ShareRow, timings, voiceText } from "./handler.ts";

function world(opts: { perDay?: number; noSynth?: boolean } = {}) {
  const drills = new Map<string, DrillRow>();
  const items = new Map<string, ItemRow & { id: string }>();
  const audio = new Map<string, AudioRow>();
  const shares = new Map<string, ShareRow>();
  const uploads: string[] = [];
  const spoken: string[] = [];
  const db = {
    drill: (id: string) => Promise.resolve(drills.get(id) ?? null),
    drills: (u: string) => Promise.resolve([...drills.values()].filter((d) => d.user_id === u)),
    saveDrill: (row: DrillRow) => {
      drills.set(row.id, { ...row, created_at: drills.get(row.id)?.created_at ?? "t", updated_at: "t" });
      return Promise.resolve();
    },
    items: (ids: string[]) => Promise.resolve([...items.values()].filter((i) => ids.includes(i.drill_id))),
    replaceItems: (drillId: string, keep: string[], rows: ItemRow[]) => {
      for (const [k, v] of items) if (v.drill_id === drillId && !keep.includes(k)) items.delete(k);
      for (const r of rows) {
        const id = r.id ?? crypto.randomUUID();
        items.set(id, { ...r, id });
      }
      return Promise.resolve();
    },
    deleteDrill: (id: string) => {
      drills.delete(id);
      for (const [k, v] of items) if (v.drill_id === id) items.delete(k);
      return Promise.resolve();
    },
    audio: (hs: string[]) => Promise.resolve(hs.map((h) => audio.get(h)).filter((a): a is AudioRow => !!a)),
    enqueue: (rows: AudioRow[]) => {
      const keys = new Set(rows.map((r) => Object.keys(r).sort().join(",")));
      if (keys.size > 1) throw new Error("bulk insert rows must have the same keys (PostgREST)");
      for (const r of rows) if (!audio.has(r.hash)) audio.set(r.hash, { ...r, attempts: 0 });
      return Promise.resolve();
    },
    claim: (n: number) => {
      const out = [...audio.values()].filter((a) => a.status === "pending").sort((a, b) => (a.seq ?? 0) - (b.seq ?? 0)).slice(0, n);
      for (const a of out) {
        a.status = "working";
        a.attempts = (a.attempts ?? 0) + 1;
      }
      return Promise.resolve(out.map((a) => ({ ...a })));
    },
    finish: (h: string, patch: Partial<AudioRow>) => {
      Object.assign(audio.get(h)!, patch);
      return Promise.resolve();
    },
    shareOf: (id: string) => Promise.resolve([...shares.values()].find((x) => x.drill_id === id && !x.revoked_at) ?? null),
    shareByCode: (c: string) => Promise.resolve(shares.get(c) ?? null),
    createShare: (row: ShareRow) => {
      shares.set(row.code, { ...row });
      return Promise.resolve();
    },
    revokeShares: (id: string) => {
      let n = 0;
      for (const x of shares.values()) if (x.drill_id === id && !x.revoked_at) (x.revoked_at = "t", n++);
      return Promise.resolve(n);
    },
    countImport: () => Promise.resolve(),
  };
  const h = (user: string) =>
    createDrillHandler({
      authenticate: () => Promise.resolve({ id: user, isAnonymous: true }),
      rateLimiter: new MemoryRateLimiter(),
      db,
      storage: {
        upload: (p) => {
          uploads.push(p);
          return Promise.resolve();
        },
        sign: (ps) => Promise.resolve(Object.fromEntries(ps.map((p) => [p, `https://signed/${p}`]))),
      },
      synth: opts.noSynth ? null : {
        speak: (text) => {
          spoken.push(text);
          // 0.05 s per character
          return Promise.resolve({
            audio: new Uint8Array(text.length),
            starts: [...text].map((_, i) => i * 0.05),
            ends: [...text].map((_, i) => (i + 1) * 0.05),
          });
        },
      },
      model: "eleven_multilingual_v2",
      voiceId: "VoiceDefault12345",
      usdPer1kChars: 0.08,
      charLimits: { perMinute: 1e9, perDay: opts.perDay ?? 1e9, globalPerDay: 1e9 },
    });
  return { h, drills, items, audio, uploads, spoken, shares };
}
const post = (b: unknown) => new Request("http://x/drill", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(b) });
const ITEMS = [
  { question: "Varför behövs klorofyll?", short: "Klorofyll fångar ljusenergi.", long: "Klorofyll fångar ljusenergi. Utan den kan växten inte bilda glukos." },
  { question: "Hur bildas en näringsväv?", short: "Kedjor hakar i varandra.", long: "Kedjor hakar i varandra. De flesta djur äter mer än en sorts föda." },
];

Deno.test("K46 save: two files per question in play order, the short answer ends in the long file (D145), signed URLs", async () => {
  const w = world();
  const r = await w.h("u1")(post({ action: "save", drill: { title: "Biologi", grade: "åk 8" }, items: ITEMS }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.audio.total, 4);
  assertEquals(j.audio.done, 4);
  assertEquals(w.spoken[0], "Varför behövs klorofyll?", "the first question first (play order)");
  const it = j.items[0];
  assertEquals(it.audio.question.url.startsWith("https://signed/"), true);
  const short = voiceText(ITEMS[0].short);
  assertEquals(it.audio.long.short_end_ms, short.length * 50, "the short answer stops where it ends in the long file");
  assertEquals(j.audio.chars, w.spoken.join("").length);
  assertEquals(j.audio.est_usd, Math.round(j.audio.chars * 0.08 / 10) / 100);
  assertEquals(j.new_chars, j.audio.chars);
});

Deno.test("K46 D144: the same text is never generated twice, for any account; an edit makes only that question's files", async () => {
  const w = world();
  const first = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  const n = w.spoken.length;
  // another account with the same questions: 0 new characters, the same files
  const other = await (await w.h("u2")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(other.new_chars, 0);
  assertEquals(w.spoken.length, n);
  assertEquals(other.audio.done, 4);
  // u1 edits the second long answer: only that file is made
  const edited = [ITEMS[0], { ...ITEMS[1], long: "Kedjor hakar i varandra. Ett djur äter ofta flera arter." }];
  const items0 = first.items.map((i: { id: string }) => i.id);
  const again = await (await w.h("u1")(post({ action: "save", drill: { id: first.drill.id }, items: edited.map((x, i) => ({ ...x, id: items0[i] })) }))).json();
  assertEquals(w.spoken.length, n + 1);
  assertEquals(w.spoken.at(-1)!.endsWith("Ett djur äter ofta flera arter."), true);
  assertEquals(again.items.map((i: { id: string }) => i.id), items0, "the items keep their ids");
  assertEquals(w.uploads.length, new Set(w.uploads).size, "no file uploaded twice");
});

Deno.test("K46 an edited short answer is put in front of the long one again (D145)", async () => {
  const w = world();
  const j = await (await w.h("u1")(post({ action: "save", items: [{ question: "Varför?", short: "Ny kort mening", long: "Gammal kort mening. Resten." }] }))).json();
  assertEquals(j.items[0].long, "Ny kort mening. Gammal kort mening. Resten.");
  assert(j.items[0].long.startsWith(j.items[0].short));
});

Deno.test("K46 R5: another account can never read, change or delete a drill; deleting keeps the shared audio", async () => {
  const w = world();
  const j = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  for (const action of ["get", "status", "delete"]) assertEquals((await w.h("u2")(post({ action, id: j.drill.id }))).status, 404, action);
  assertEquals((await w.h("u2")(post({ action: "save", drill: { id: j.drill.id }, items: ITEMS }))).status, 404);
  assertEquals((await (await w.h("u2")(post({ action: "list" }))).json()).drills, []);
  const mine = (await (await w.h("u1")(post({ action: "list" }))).json()).drills;
  assertEquals(mine.length, 1);
  assertEquals(mine[0].audio, { done: 4, total: 4 });
  assertEquals((await w.h("u1")(post({ action: "delete", id: j.drill.id }))).status, 200);
  assertEquals(w.items.size, 0);
  assertEquals(w.audio.size, 4, "audio stays for other accounts");
});

Deno.test("K46 a daily character limit for new audio; reused audio is free", async () => {
  const w = world({ perDay: 60 });
  const r = await w.h("u1")(post({ action: "save", items: ITEMS }));
  assertEquals(r.status, 429);
  assertEquals(w.spoken.length, 0);
  assertEquals(w.drills.size, 0, "nothing saved when it is refused");
  const ok = world({ perDay: 1e9 });
  await ok.h("u1")(post({ action: "save", items: ITEMS }));
});

Deno.test("K46 bad input is refused before anything is stored", async () => {
  const w = world();
  for (const b of [{ action: "save", items: [] }, { action: "save", items: [{ question: "", short: "x" }] }, { action: "save", items: [{ question: "Q?", short: "" }] }, { action: "get", id: "nope" }, { action: "x" }]) {
    assertEquals((await w.h("u1")(post(b))).status, 400, JSON.stringify(b));
  }
  assertEquals(w.drills.size + w.audio.size, 0);
});

Deno.test("K46 voice text and timings", () => {
  assertEquals(voiceText("**6** koldioxid ger 1 glukos"), "Sex koldioxid ger en glukos");
  const l = longVoice("Klorofyll fångar ljus.", "Klorofyll fångar ljus. Därför 2 saker.");
  assertEquals(l.text, "Klorofyll fångar ljus. Därför två saker.");
  assertEquals(l.shortChars, "Klorofyll fångar ljus.".length);
  const t = timings("Hej du", [0, 0.1, 0.2, 0.3, 0.4, 0.5], [0.1, 0.2, 0.3, 0.4, 0.5, 0.6], 3);
  assertEquals(t.words, [[0, 300], [400, 600]]);
  assertEquals(t.short_end_ms, 300);
  assertEquals(t.duration_ms, 600);
});

Deno.test("K47 share: only when all audio is done (409 with the progress), the same code again, revoked by the owner only", async () => {
  const w = world({ noSynth: true }); // the audio is queued but not made yet
  const j = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  const r = await w.h("u1")(post({ action: "share", id: j.drill.id }));
  assertEquals(r.status, 409);
  assertEquals((await r.json()).error?.message ?? "", "Delas när ljudet är klart (0 av 4)");
  for (const a of w.audio.values()) a.status = "done";
  const s1 = await (await w.h("u1")(post({ action: "share", id: j.drill.id }))).json();
  assert(/^[a-z0-9]{10}$/.test(s1.code));
  assertEquals(s1.url, `https://earmind.ai/p/${s1.code}`);
  assertEquals((await (await w.h("u1")(post({ action: "share", id: j.drill.id }))).json()).code, s1.code);
  assertEquals((await w.h("u2")(post({ action: "share", id: j.drill.id }))).status, 404, "not someone else's drill");
  assertEquals((await w.h("u2")(post({ action: "unshare", id: j.drill.id }))).status, 404);
  assertEquals((await (await w.h("u1")(post({ action: "unshare", id: j.drill.id }))).json()).revoked, 1);
  assertEquals((await w.h("u2")(post({ action: "import", code: s1.code }))).status, 404, "a revoked link is dead");
});

Deno.test("K47 R5c: import copies questions, answers and audio with 0 new characters; the recipient's edit never touches the original", async () => {
  const w = world();
  const a = await (await w.h("u1")(post({ action: "save", drill: { title: "Ekologi" }, items: ITEMS }))).json();
  const { code } = await (await w.h("u1")(post({ action: "share", id: a.drill.id }))).json();
  const spokenBefore = w.spoken.length;
  const info = await (await w.h("u2")(post({ action: "share_info", code }))).json();
  assertEquals([info.title, info.items, info.audio_ready], ["Ekologi", 2, true]);
  const b = await (await w.h("u2")(post({ action: "import", code: `https://earmind.ai/p/${code.toUpperCase()}` }))).json();
  assertEquals(b.new_chars, 0);
  assertEquals(b.drill.shared_from, a.drill.id);
  assertEquals(b.audio.done, 4);
  assertEquals(w.spoken.length, spokenBefore, "no voice call");
  assertEquals(b.items[0].audio.long.short_end_ms, a.items[0].audio.long.short_end_ms);
  // the recipient changes one question: one new file, the original unchanged
  const ids = b.items.map((i: { id: string }) => i.id);
  const edited = [{ ...ITEMS[0], id: ids[0], question: "Varför är bladen gröna?" }, { ...ITEMS[1], id: ids[1] }];
  await w.h("u2")(post({ action: "save", drill: { id: b.drill.id }, items: edited }));
  assertEquals(w.spoken.length, spokenBefore + 1);
  const orig = await (await w.h("u1")(post({ action: "get", id: a.drill.id }))).json();
  assertEquals(orig.items[0].question, ITEMS[0].question);
  // the photos and documents are never part of a drill, so nothing else can be shared
  assertEquals(Object.keys(b.drill).sort(), ["covers", "created_at", "grade", "id", "long_words", "shared_from", "subject", "title", "updated_at"]);
  assertEquals((await w.h("u3")(post({ action: "import", code: "nosuchcode1" }))).status, 404);
  assertEquals((await (await w.h("u2")(post({ action: "import", code: `earmind://prov/${code}` }))).json()).new_chars, 0);
});
