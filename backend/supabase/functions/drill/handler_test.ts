// K46 (D142-D145): drills and audio per account, with an in-memory database, storage and voice. Invented text only.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { questionKey } from "./length.ts";
import { runWithTest, TEST_VOICE_ID } from "../_shared/testmode.ts";
import { type AudioRow, createDrillHandler, type DrillRow, type ItemRow, longVoice, type PublicationRow, type SchoolRow, type ShareRow, timings, validDate, voiceText } from "./handler.ts";

function world(opts: { perDay?: number; noSynth?: boolean; freeQuestions?: number; busy?: number; outOfCredits?: boolean } = {}) {
  let busy = opts.busy ?? 0;
  const quota = new Map<string, number>();
  const credits = new Set<string>(); // K61 (D177): "user|question key" counted in /help try
  const models: string[] = [];
  const drills = new Map<string, DrillRow>();
  const items = new Map<string, ItemRow & { id: string }>();
  const audio = new Map<string, AudioRow>();
  const shares = new Map<string, ShareRow>();
  const schools = new Map<string, SchoolRow>([
    ["11111111", { code: "11111111", name: "Påhittade skolan", locality: "Nyköping", status: "AKTIV" }],
    ["22222222", { code: "22222222", name: "Andra skolan", locality: "Umeå", status: "AKTIV" }],
    ["33333333", { code: "33333333", name: "Nedlagda skolan", locality: "Umeå", status: "UPPHORT" }],
  ]);
  const pubs = new Map<string, PublicationRow>();
  const reports = new Map<string, Set<string>>();
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
    referenced: (hs: string[]) => Promise.resolve(hs.filter((h) => [...items.values()].some((i) => i.question_hash === h || i.long_hash === h))),
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
    schools: (q: string, n: number) => Promise.resolve([...schools.values()].filter((x) => x.status === "AKTIV" && x.name.toLowerCase().includes(q.toLowerCase())).slice(0, n)),
    school: (c: string) => Promise.resolve(schools.get(c) ?? null),
    publicationOf: (id: string) => Promise.resolve([...pubs.values()].find((x) => x.drill_id === id) ?? null),
    publication: (id: string) => Promise.resolve(pubs.get(id) ?? null),
    savePublication: (row: PublicationRow) => {
      pubs.set(row.id, { hidden: false, reports: 0, imports: 0, plays: 0, ...pubs.get(row.id), ...row });
      return Promise.resolve();
    },
    deletePublication: (id: string) => {
      for (const [k, v] of pubs) if (v.drill_id === id) pubs.delete(k);
      return Promise.resolve();
    },
    searchPublications: (f: { school?: string; subject?: string }) =>
      Promise.resolve([...pubs.values()].filter((x) => !x.hidden && (!f.school || x.school_code === f.school) && (!f.subject || x.subject.toLowerCase().includes(f.subject.toLowerCase())))),
    report: (id: string, u: string) => {
      const set = reports.get(id) ?? new Set<string>();
      set.add(u);
      reports.set(id, set);
      const pb = pubs.get(id)!;
      pb.reports = set.size;
      pb.hidden = pb.hidden || set.size >= 3;
      return Promise.resolve({ reports: pb.reports, hidden: pb.hidden! });
    },
    bump: (id: string, field: "imports" | "plays") => {
      const pb = pubs.get(id)!;
      pb[field] = (pb[field] ?? 0) + 1;
      return Promise.resolve();
    },
    pending: () => Promise.resolve([...audio.values()].some((a) => a.status === "pending" || a.status === "working")),
    requeue: (hs: string[]) => {
      for (const h of hs) {
        const a = audio.get(h);
        if (a?.status === "failed") Object.assign(a, { status: "pending", attempts: 0 });
      }
      return Promise.resolve();
    },
    useQuota: (u: string, n: number) => {
      const used = quota.get(u) ?? 0, lim = opts.freeQuestions ?? 30;
      if (n > 0 && used + n > lim) return Promise.resolve({ ok: false, used, lim });
      quota.set(u, used + n);
      return Promise.resolve({ ok: true, used: used + n, lim });
    },
    setHidden: (id: string, hidden: boolean) => {
      pubs.get(id)!.hidden = hidden;
      return Promise.resolve();
    },
    settings: () => Promise.resolve({ length_normal_max: 100, length_longer_max: 200 }),
    tryCredits: (u: string, keys: string[]) => Promise.resolve(keys.filter((k) => credits.has(`${u}|${k}`))),
    dropTryCredits: (u: string, keys: string[]) => {
      for (const k of keys) credits.delete(`${u}|${k}`);
      return Promise.resolve();
    },
  };
  const limiter = new MemoryRateLimiter(); // one per world, like the real database
  const h = (user: string, owner = false) =>
    createDrillHandler({
      authenticate: () => Promise.resolve(owner ? { id: user, isAnonymous: false, email: "owner@example.com", amr: ["otp"] } : { id: user, isAnonymous: true }),
      ownerEmails: ["owner@example.com"],
      now: () => Date.parse("2026-11-13T12:00:00Z"),
      sleep: () => Promise.resolve(),
      rateLimiter: limiter,
      db,
      storage: {
        upload: (p) => {
          uploads.push(p);
          return Promise.resolve();
        },
        sign: (ps) => Promise.resolve(Object.fromEntries(ps.map((p) => [p, `https://signed/${p}`]))),
      },
      synth: opts.noSynth ? null : {
        speak: (text, model) => {
          if (opts.outOfCredits) return Promise.reject(new Error('elevenlabs 401: {"detail":{"code":"quota_exceeded"}}'));
          if (busy > 0) {
            busy--;
            return Promise.reject(new Error("elevenlabs 429: concurrent_limit_exceeded"));
          }
          spoken.push(text);
          models.push(model);
          // 0.05 s per character
          return Promise.resolve({
            credits: Math.round(text.length * 0.4),
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
  return { h, drills, items, audio, uploads, spoken, shares, pubs, quota, credits, models, setBusy: (n: number) => (busy = n) };
}
const CUE = "Tryck en gång för svaret.";
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
  assertEquals(j.audio.chars, w.spoken.filter((t) => t !== CUE).join("").length);
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
  assertEquals(w.audio.size, 5, "audio stays for other accounts (4 + the voice's cue)");
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
  assertEquals(Object.keys(b.drill).sort(), ["covers", "created_at", "grade", "id", "long_words", "shared_from", "subject", "title", "updated_at", "voice_model"]);
  assertEquals((await w.h("u3")(post({ action: "import", code: "nosuchcode1" }))).status, 404);
  assertEquals((await (await w.h("u2")(post({ action: "import", code: `earmind://prov/${code}` }))).json()).new_chars, 0);
});

Deno.test("K49 R12: publishing is refused without school, subject, date or finished audio (4/4), with what is missing", async () => {
  const w = world({ noSynth: true });
  const j = await (await w.h("u1")(post({ action: "save", drill: { title: "Ekologi" }, items: ITEMS }))).json();
  const ok = { action: "publish", id: j.drill.id, school_code: "11111111", subject: "Biologi", exam_date: "2026-11-20" };
  const missing = async (b: Record<string, unknown>) => {
    const r = await w.h("u1")(post(b));
    assertEquals(r.status, 409);
    return (await r.json()).missing;
  };
  assertEquals(await missing(ok), ["audio"], "audio not ready");
  for (const a of w.audio.values()) a.status = "done";
  assertEquals(await missing({ ...ok, school_code: "" }), ["school"]);
  assertEquals(await missing({ ...ok, school_code: "33333333" }), ["school"], "a closed school is not offered");
  assertEquals(await missing({ ...ok, subject: "" }), ["subject"], "no subject on the drill either");
  assertEquals(await missing({ ...ok, exam_date: "13/11" }), ["date"]);
  assertEquals(await missing({ ...ok, exam_date: "2026-02-30" }), ["date"]);
  const r = await w.h("u1")(post(ok));
  assertEquals(r.status, 200);
  assertEquals((await w.h("u2")(post(ok))).status, 404, "only the owner publishes");
});

Deno.test("K49 search: own school first, old exams sink, hidden never; no account, photos or name unless chosen", async () => {
  const w = world();
  const mk = async (user: string, title: string, school: string, date: string, extra: Record<string, unknown> = {}) => {
    const j = await (await w.h(user)(post({ action: "save", drill: { title }, items: [{ question: `Varför ${title}?`, short: `Därför ${title}.`, long: `Därför ${title}. Mer.` }] }))).json();
    const p = await (await w.h(user)(post({ action: "publish", id: j.drill.id, school_code: school, subject: "Biologi", exam_date: date, ...extra }))).json();
    return { drill: j.drill.id, pub: p.publication.id };
  };
  await mk("u1", "gammalt", "22222222", "2026-09-01");
  await mk("u2", "nytt", "22222222", "2026-11-20", { show_name: true, display_name: "Sara <script>" });
  await mk("u3", "egen", "11111111", "2026-10-01");
  const res = (await (await w.h("u9")(post({ action: "search", my_school: "11111111" }))).json()).results;
  assertEquals(res.map((x: { title: string }) => x.title), ["egen", "nytt", "gammalt"]);
  const json = JSON.stringify(res);
  for (const bad of ["u1", "u2", "u3", "user_id", "drill_id"]) assert(!json.includes(`"${bad}"`) && !json.includes(bad + '"'), bad);
  assertEquals(res[1].display_name, "Sara script");
  assertEquals("display_name" in res[0], false, "no name unless chosen (D150)");
  assertEquals(res[0].school, { code: "11111111", name: "Påhittade skolan", locality: "Nyköping" });
  const one = (await (await w.h("u9")(post({ action: "search", school_code: "22222222" }))).json()).results;
  assertEquals(one.length, 2);
  assertEquals((await (await w.h("u9")(post({ action: "schools", q: "påhitt" }))).json()).schools, [{ code: "11111111", name: "Påhittade skolan", locality: "Nyköping" }]);
  assertEquals((await (await w.h("u9")(post({ action: "schools", q: "nedlagd" }))).json()).schools, []);
});

Deno.test("K49 import a published drill: 0 characters, counted; plays counted at most 3 a day; 3 reports hide it; Aron shows it again", async () => {
  const w = world();
  const j = await (await w.h("u1")(post({ action: "save", drill: { title: "Ekologi" }, items: ITEMS }))).json();
  const pub = (await (await w.h("u1")(post({ action: "publish", id: j.drill.id, school_code: "11111111", subject: "Biologi", exam_date: "2026-11-20" }))).json()).publication;
  const n = w.spoken.length;
  const copy = await (await w.h("u2")(post({ action: "import", publication_id: pub.id }))).json();
  assertEquals([copy.new_chars, copy.audio.done, w.spoken.length], [0, 4, n]);
  assertEquals(w.pubs.get(pub.id)!.imports, 1);
  for (let i = 0; i < 5; i++) await w.h("u2")(post({ action: "played", id: copy.drill.id }));
  assertEquals(w.pubs.get(pub.id)!.plays, 1, "the minute limit: one per minute, at most three a day");
  assertEquals((await (await w.h("u1")(post({ action: "played", id: j.drill.id }))).json()).counted, false, "the original is not a copy");
  for (const u of ["r1", "r1", "r2"]) await w.h(u)(post({ action: "report", publication_id: pub.id, reason: "krankande" }));
  assertEquals(w.pubs.get(pub.id)!.hidden, false, "the same account twice counts once");
  const third = await (await w.h("r3")(post({ action: "report", publication_id: pub.id, reason: "fel" }))).json();
  assertEquals(third, { reports: 3, hidden: true });
  assertEquals((await (await w.h("u9")(post({ action: "search", school_code: "11111111" }))).json()).results, []);
  assertEquals((await w.h("u9")(post({ action: "import", publication_id: pub.id }))).status, 404);
  assertEquals((await w.h("u1")(post({ action: "moderate", publication_id: pub.id, hidden: false }))).status, 403);
  assertEquals((await w.h("aron", true)(post({ action: "moderate", publication_id: pub.id, hidden: false }))).status, 200);
  assertEquals((await (await w.h("u9")(post({ action: "search", school_code: "11111111" }))).json()).results.length, 1);
  assertEquals((await w.h("u1")(post({ action: "unpublish", id: j.drill.id }))).status, 200);
  assertEquals(w.pubs.size, 0);
});

Deno.test("K49 dates", () => {
  const now = Date.parse("2026-11-13T12:00:00Z");
  assertEquals(validDate("2026-11-20", now), "2026-11-20");
  assertEquals(validDate("2026-02-30", now), null);
  assertEquals(validDate("2020-01-01", now), null);
  assertEquals(validDate("2028-01-01", now), null);
});

Deno.test("K50 voice: chosen before the audio (A/B/C or the model id), locked after (409), another voice = other files", async () => {
  const w = world();
  const a = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(a.drill.voice_model, "eleven_multilingual_v2", "A is the default (D151)");
  const n = w.spoken.length;
  const c = await (await w.h("u2")(post({ action: "save", drill: { voice_model: "C" }, items: ITEMS }))).json();
  assertEquals(c.drill.voice_model, "eleven_flash_v2_5");
  assertEquals(w.spoken.length, n + 5, "the same text with another voice is new audio (and its cue)");
  assertEquals(new Set(w.models.slice(n)), new Set(["eleven_flash_v2_5"]));
  const r = await w.h("u1")(post({ action: "save", drill: { id: a.drill.id, voice_model: "eleven_v3" }, items: ITEMS }));
  assertEquals(r.status, 409);
  assertEquals((await r.json()).error.code, "voice_locked");
  assertEquals((await w.h("u1")(post({ action: "save", drill: { id: a.drill.id, voice_model: "A" }, items: ITEMS }))).status, 200, "the same voice again is fine");
  assertEquals((await w.h("u1")(post({ action: "save", drill: { voice_model: "robot" }, items: ITEMS }))).status, 400);
  assertEquals(a.audio.est_usd, Math.round(a.audio.chars * 0.08 / 10) / 100);
  assertEquals(c.audio.est_usd, Math.round(c.audio.chars * 0.04 / 10) / 100, "Flash at half the list price");
  assertEquals(a.audio.credits, w.spoken.slice(0, 4).reduce((m, t) => m + Math.round(t.length * 0.4), 0), "what ElevenLabs charged is kept");
});

Deno.test("K50 limit: 30 generated questions per account by default (402 with the numbers); imported and existing audio never count", async () => {
  const w = world({ freeQuestions: 3 });
  const two = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(two.generated_questions, 2);
  const more = [{ question: "Varför regnar det?", short: "Moln släpper vatten.", long: "Moln släpper vatten. Mer." }, { question: "Hur fungerar ett öga?", short: "Ljus bryts.", long: "Ljus bryts. Mer." }];
  const r = await w.h("u1")(post({ action: "save", items: more }));
  assertEquals(r.status, 402);
  const j = await r.json();
  assertEquals([j.error.code, j.used, j.limit, j.needed, j.per, j.resets], ["quota_exceeded", 2, 3, 2, "month", "2026-12-01"]);
  assert(j.error.message.includes("den här månaden"));
  assert(j.error.message.includes("Andras prov är gratis") && j.error.message.includes("Nya frågor går att göra från den 1 ") && !j.error.message.includes("Köp"));
  assertEquals(w.drills.size, 1, "nothing saved");
  // the same questions again (audio exists): 0 generated, free
  assertEquals((await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json()).generated_questions, 0);
  // someone else's drill, shared: free
  const { code } = await (await w.h("u1")(post({ action: "share", id: two.drill.id }))).json();
  const imp = await w.h("u2")(post({ action: "import", code }));
  assertEquals(imp.status, 200);
  assertEquals(w.quota.get("u2") ?? 0, 0);
  // one more own question fits exactly
  assertEquals((await w.h("u1")(post({ action: "save", items: [more[0]] }))).status, 200);
  assertEquals((await (await w.h("u1")(post({ action: "list" }))).json()).quota, { used: 3, limit: 3, left: 0, per: "month", resets: "2026-12-01" });
});

Deno.test("K52 D155: the month the limit starts again, in Swedish time", async () => {
  const { nextMonthStart } = await import("./handler.ts");
  assertEquals(nextMonthStart(Date.parse("2026-11-13T12:00:00Z")), "2026-12-01");
  assertEquals(nextMonthStart(Date.parse("2026-12-31T23:30:00Z")), "2027-02-01", "already January in Stockholm");
  assertEquals(nextMonthStart(Date.parse("2026-12-15T12:00:00Z")), "2027-01-01");
});

Deno.test("Cue: 'Tryck en gång för svaret.' in the drill's own voice, made once per voice, never counted", async () => {
  const w = world({ freeQuestions: 2 });
  const a = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  const j = await (await w.h("u1")(post({ action: "get", id: a.drill.id }))).json();
  assertEquals(j.cue.press_for_answer.status, "done");
  assert(j.cue.press_for_answer.url.startsWith("https://signed/"));
  assertEquals(w.spoken.filter((t) => t === "Tryck en gång för svaret.").length, 1);
  assertEquals(w.quota.get("u1"), 2, "the cue is not a generated question");
  assertEquals(j.audio.total, 4, "the cue is not part of the drill's progress");
  // another drill, same voice: no new cue; another voice: its own cue
  await w.h("u2")(post({ action: "save", items: ITEMS }));
  const c = await (await w.h("u3")(post({ action: "save", drill: { voice_model: "C" }, items: ITEMS }))).json();
  await w.h("u3")(post({ action: "get", id: c.drill.id }));
  assertEquals(w.spoken.filter((t) => t === "Tryck en gång för svaret.").length, 2);
});

Deno.test("K55 ElevenLabs busy (429): back in the queue without counting a try; a failed file is made again on the next save", async () => {
  const w = world({ busy: 5 });
  const j = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(j.audio.done, 4, "five 429s and still everything made (none counted as a try)");
  assert([...w.audio.values()].every((a) => (a.attempts ?? 0) <= 1));
  // an old failure (not a 429) is queued again when the text is saved again
  const one = [...w.audio.values()][0];
  Object.assign(one, { status: "failed", attempts: 3 });
  const again = await (await w.h("u2")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(again.audio.failed, 0);
  assertEquals(one.status, "done");
});

Deno.test("K61 D176: each question gets its length (question + long answer to ElevenLabs) and class from drill_settings", async () => {
  const w = world();
  const long = "Moln släpper vatten. " + "Mer om moln och regn. ".repeat(6);
  const j = await (await w.h("u1")(post({ action: "save", items: [ITEMS[0], { question: "Varför regnar det?", short: "Moln släpper vatten.", long }] }))).json();
  const [a, b] = j.items as { voice_chars: number; length_class: string }[];
  assert(a.voice_chars > 0 && a.voice_chars <= 100, String(a.voice_chars));
  assertEquals(a.length_class, "normal");
  assert(b.voice_chars > 100, String(b.voice_chars));
  assertEquals(b.length_class, b.voice_chars > 200 ? "too_long" : "longer");
});

Deno.test("K61 D177: questions already counted in /help try are not counted again when saved", async () => {
  const w = world({ freeQuestions: 15 });
  w.credits.add("u1|" + questionKey(ITEMS[0].question));
  const j = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals([j.generated_questions, j.already_counted], [ITEMS.length - 1, 1]);
  assertEquals(w.credits.size, 0, "the credit is used once");
});

Deno.test("K61 D175: quota tells the app what is left and what to suggest (never over 20)", async () => {
  const w = world({ freeQuestions: 15 });
  const q = await (await w.h("u1")(post({ action: "quota" }))).json();
  assertEquals([q.used, q.limit, q.left, q.suggest, q.per], [0, 15, 15, 15, "month"]);
});

Deno.test("K62b D180: a test account's drill uses the silent test voice, never the real files or voice", async () => {
  const w = world();
  const real = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  const test = await runWithTest({ test: true, reason: "script", userId: "u2" }, async () => await (await w.h("u2")(post({ action: "save", items: ITEMS }))).json());
  const testFiles = [...w.audio.values()].filter((a) => a.voice_id === TEST_VOICE_ID);
  assertEquals(testFiles.filter((a) => (a.seq ?? 0) >= 0).length, 4, "two questions = four silent files of its own (plus its cue)");
  assertEquals(real.generated_questions, 2);
  assertEquals(test.generated_questions, 2);
  assert([...w.audio.values()].filter((a) => a.voice_id !== TEST_VOICE_ID).length >= 4, "the real files are untouched");
});

Deno.test("K62: out of ElevenLabs credits = the files say audio_unavailable (the app shows 'Ljudet kan inte göras just nu')", async () => {
  const w = world({ outOfCredits: true });
  const saved = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  const st = await (await w.h("u1")(post({ action: "status", id: saved.drill.id }))).json();
  const files = st.items.flatMap((i: { audio: { question: { status: string; error?: string }; long: { status: string; error?: string } } }) => [i.audio.question, i.audio.long]);
  assert(files.some((f: { status: string; error?: string }) => f.status === "failed" && f.error === "audio_unavailable"), JSON.stringify(files));
  assert(files.every((f: { status: string; error?: string }) => f.status !== "failed" || f.error === "audio_unavailable"));
});

Deno.test("K62b (Oscar O61): a test request never makes other people's waiting files with the real voice", async () => {
  const w = world();
  w.audio.set("realpending", { hash: "realpending", kind: "question", text: "Någon annans fråga?", model: "eleven_multilingual_v2", voice_id: "voice-1", status: "pending", attempts: 0, seq: 0, queued_at: new Date().toISOString() });
  await runWithTest({ test: true, reason: "header", userId: "u9" }, async () => {
    const j = await (await w.h("u9")(post({ action: "save", items: ITEMS }))).json();
    await (await w.h("u9")(post({ action: "status", id: j.drill.id }))).json();
  });
  assertEquals(w.audio.get("realpending")!.status, "pending", "the real file waits for real traffic");
  assert(!w.spoken.includes("Någon annans fråga?"));
  assert([...w.audio.values()].filter((a) => a.voice_id === TEST_VOICE_ID).every((a) => a.status === "done"), "the test's own files are made");
});

Deno.test("K64 (Oscar O61 fynd 2): no credits for audio no question uses; a deleted drill's waiting files leave the queue", async () => {
  const w = world({ noSynth: false });
  const old = "2026-11-13T11:50:00Z"; // the world's clock is 2026-11-13 12:00
  w.audio.set("orphan", { hash: "orphan", kind: "long", text: "Ett svar som ingen fråga använder längre.", model: "eleven_multilingual_v2", voice_id: "voice-1", status: "pending", attempts: 0, seq: 3, queued_at: old });
  w.audio.set("young", { hash: "young", kind: "long", text: "Ett svar som sparas just nu.", model: "eleven_multilingual_v2", voice_id: "voice-1", status: "pending", attempts: 0, seq: 3, queued_at: "2026-11-13T11:59:30Z" });
  const saved = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(w.audio.get("orphan")!.status, "failed");
  assert(!w.spoken.includes("Ett svar som ingen fråga använder längre."), "never sent to ElevenLabs");
  assert(!w.spoken.includes("Ett svar som sparas just nu."), "a file queued in the last 2 minutes is not made either");
  assertEquals(w.audio.get("young")!.status, "pending", "but it waits (its drill may be saving)");
  // a drill deleted while its files wait: they leave the queue
  const w2 = world({ noSynth: true });
  const d = await (await w2.h("u1")(post({ action: "save", items: ITEMS }))).json();
  await w2.h("u1")(post({ action: "delete", id: d.drill.id }));
  assert([...w2.audio.values()].filter((a) => (a.seq ?? 0) >= 0).every((a) => a.status === "failed" && /unused/.test(a.error ?? "")));
  assert(saved.drill.id);
});

Deno.test("K64 (Oscar O61): x-earmind-test unavailable and slow let tests see 'Ljudet kan inte göras' and waiting audio", async () => {
  const w = world();
  const un = await runWithTest({ test: true, reason: "header", userId: "u7", mode: "unavailable" }, async () => {
    const j = await (await w.h("u7")(post({ action: "save", items: ITEMS }))).json();
    return await (await w.h("u7")(post({ action: "status", id: j.drill.id }))).json();
  });
  const files = un.items.flatMap((i: { audio: { question: { status: string; error?: string }; long: { status: string; error?: string } } }) => [i.audio.question, i.audio.long]);
  assert(files.every((f: { status: string; error?: string }) => f.status === "failed" && f.error === "audio_unavailable"), JSON.stringify(files));
  const w3 = world();
  const slow = await runWithTest({ test: true, reason: "header", userId: "u8", mode: "slow" }, async () => {
    const j = await (await w3.h("u8")(post({ action: "save", items: [{ question: "Varför snöar det?", short: "Det är kallt.", long: "Det är kallt. Mer." }] }))).json();
    return await (await w3.h("u8")(post({ action: "status", id: j.drill.id }))).json();
  });
  assertEquals([slow.audio.done, slow.audio.total], [0, 2]);
});
