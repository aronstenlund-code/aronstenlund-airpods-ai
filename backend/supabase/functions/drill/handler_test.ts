// K46 (D142-D145): drills and audio per account, with an in-memory database, storage and voice. Invented text only.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { questionKey } from "./length.ts";
import { DRILL_LIMITS } from "../exam/drill.ts";
import { runWithTest, TEST_VOICE_ID } from "../_shared/testmode.ts";
import { type AudioRow, createDrillHandler, type DrillRow, type ItemRow, longVoice, type PublicationRow, type SchoolRow, type ShareRow, timings, validDate, voiceText } from "./handler.ts";

function world(opts: { background?: (p: Promise<unknown>) => void; perDay?: number; noSynth?: boolean; credits?: number; busy?: number; outOfCredits?: boolean; styler?: (t: string, s: string) => Promise<string | null>; catalog?: { voice_id: string; name: string; language?: string | null }[]; picker?: (s: string, v: { voice_id: string }[]) => Promise<{ voice_id: string; reason: string } | null> } = {}) {
  let busy = opts.busy ?? 0;
  let out = !!opts.outOfCredits; // K78: credits can come back
  const quota = new Map<string, number>();
  const started: string[] = [];
  const admins = new Set<string>(); // K93: credit_admins
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
    drillByClient: (u: string, c: string) => Promise.resolve([...drills.values()].find((d) => d.user_id === u && d.client_id === c) ?? null),
    saveDrill: (row: DrillRow) => {
      // K88: the unique index (user_id, client_id)
      if (row.client_id && [...drills.values()].some((d) => d.id !== row.id && d.user_id === row.user_id && d.client_id === row.client_id)) {
        return Promise.reject(new Error("upsert drills failed: HTTP 409"));
      }
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
    // K78 (D200)
    refundQuota: (u: string, n: number) => {
      quota.set(u, Math.max(0, (quota.get(u) ?? 0) - n));
      return Promise.resolve();
    },
    recentUnavailable: (since: string, tag: string | null) =>
      Promise.resolve([...audio.values()].some((a) => a.status === "failed" && (a.error ?? "").startsWith(tag ? `audio_unavailable: test ${tag} ` : "audio_unavailable") &&
        (a.voice_id === TEST_VOICE_ID) === !!tag && (a.done_at ?? "") >= since)),
    setRefunded: (id: string, n: number) => {
      drills.get(id)!.refunded_chars = n;
      return Promise.resolve();
    },
    useQuota: (u: string, n: number) => {
      const used = quota.get(u) ?? 0, lim = opts.credits ?? 1_000_000; // K90 (D213): credits = characters
      if (admins.has(u)) return Promise.resolve({ ok: true, used, lim: used + 1_000_000, unlimited: true }); // K93 (as index.ts)
      if (n > 0 && used + n > lim) return Promise.resolve({ ok: false, used, lim });
      quota.set(u, used + n);
      return Promise.resolve({ ok: true, used: used + n, lim });
    },
    setHidden: (id: string, hidden: boolean) => {
      pubs.get(id)!.hidden = hidden;
      return Promise.resolve();
    },
    settings: () => Promise.resolve({ length_normal_max: 100, length_longer_max: 200 }),
    voiceAllowed: (id: string) => Promise.resolve(id === "CatalogVoice01" || (opts.catalog ?? []).some((v) => v.voice_id === id)), // K96
    catalogVoices: () => Promise.resolve(opts.catalog ?? []), // K99
    tryCredits: (u: string, keys: string[]) => Promise.resolve(keys.filter((k) => credits.has(`${u}|${k}`))),
    dropTryCredits: (u: string, keys: string[]) => {
      for (const k of keys) credits.delete(`${u}|${k}`);
      return Promise.resolve();
    },
  };
  const limiter = new MemoryRateLimiter(); // one per world, like the real database
  const logged: { mode: string; persona: string; question: string; answer: string }[] = []; // K77
  const h = (user: string, owner = false) =>
    createDrillHandler({
      authenticate: () => Promise.resolve(owner ? { id: user, isAnonymous: false, email: "owner@example.com", amr: ["otp"] } : { id: user, isAnonymous: true }),
      ownerEmails: ["owner@example.com"],
      styler: opts.styler,
      ...(opts.background ? { background: opts.background } : {}),
      onStarted: (u: string) => (started.push(u), Promise.resolve()),
      voicePicker: opts.picker,
      analysis: (r) => {
        logged.push(...r);
        return Promise.resolve();
      },
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
          if (out) return Promise.reject(new Error('elevenlabs 401: {"detail":{"code":"quota_exceeded"}}'));
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
  return { h, limiter, started, admins, drills, items, audio, uploads, spoken, shares, pubs, quota, credits, models, logged, setBusy: (n: number) => (busy = n), setOut: (v: boolean) => (out = v) };
}
const CUE = "Tryck en gång för svaret.";
const post = (b: unknown) => new Request("http://x/drill", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(b) });
/** K90 (D213): credits = the shown characters of a question and its long answer. */
const cost = (its: { question: string; long: string }[]) => its.reduce((n, i) => n + i.question.length + i.long.length, 0);
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
  assertEquals(Object.keys(b.drill).sort(), ["audio_started", "covers", "created_at", "grade", "id", "kind", "long_words", "mix_voices", "said", "shared_from", "style", "subject", "title", "updated_at", "voice_id", "voice_model"]);
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
  // K65: the first questions and the first question's finished audio, before "Lägg till"
  assertEquals(res[0].preview, [{ question: "Varför egen?", short: "Därför egen." }]);
  assert(String(res[0].first_audio_url).startsWith("https://signed/"), String(res[0].first_audio_url));
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

Deno.test("K90 (D213) limit: credits = characters of new audio (402 with cost, remaining, limit); nothing saved; existing audio and imports cost 0", async () => {
  const c2 = cost(ITEMS);
  const more = [{ question: "Varför regnar det?", short: "Moln släpper vatten.", long: "Moln släpper vatten. Mer." }, { question: "Hur fungerar ett öga?", short: "Ljus bryts.", long: "Ljus bryts. Mer." }];
  const w = world({ credits: c2 + cost([more[0]]) });
  const two = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals([two.cost, two.unit, two.generated_questions], [c2, "chars", 2]);
  assertEquals(w.quota.get("u1"), c2);
  const r = await w.h("u1")(post({ action: "save", items: more }));
  assertEquals(r.status, 402);
  const j = await r.json();
  assertEquals([j.error.code, j.unit, j.cost, j.remaining, j.limit, j.resets], ["quota_exceeded", "chars", cost(more), cost([more[0]]), c2 + cost([more[0]]), "2026-12-01"]);
  assertEquals(j.error.message, `Det här kostar ${cost(more)} krediter. Du har ${cost([more[0]])} kvar. Nya krediter den 1 december.`);
  const { thousands } = await import("./handler.ts");
  assertEquals([thousands(2011), thousands(764), thousands(1500000)], ["2\u00a0011", "764", "1\u00a0500\u00a0000"], "Kelly Ke71: thousands with a no-break space");
  assertEquals([j.used, j.needed, j.per], [c2, cost(more), "month"], "old fields kept");
  assertEquals(w.drills.size, 1, "nothing saved");
  // the same questions again (audio exists): costs 0
  assertEquals((await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json()).cost, 0);
  // someone else's drill, shared: free
  const { code } = await (await w.h("u1")(post({ action: "share", id: two.drill.id }))).json();
  assertEquals((await w.h("u2")(post({ action: "import", code }))).status, 200);
  assertEquals(w.quota.get("u2") ?? 0, 0);
  // one more own question fits exactly
  assertEquals((await w.h("u1")(post({ action: "save", items: [more[0]] }))).status, 200);
  const l = (await (await w.h("u1")(post({ action: "list" }))).json()).quota;
  assertEquals([l.unit, l.used, l.limit, l.remaining, l.left], ["chars", c2 + cost([more[0]]), c2 + cost([more[0]]), 0, 0]);
});

Deno.test("K90 (D212 3) a new drill saved for later whose cost the credits cannot pay is refused and not saved; an old one is kept", async () => {
  const w = world({ credits: cost(ITEMS) - 1 });
  const r = await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Säg" }, items: ITEMS }));
  assertEquals(r.status, 402);
  assertEquals((await r.json()).cost, cost(ITEMS));
  assertEquals(w.drills.size, 0, "no unstarted drill is left behind");
  const one = await (await w.h("u1")(post({ action: "save", defer_audio: true, items: [ITEMS[0]] }))).json();
  assertEquals([one.cost, one.audio.cost, one.drill.audio_started], [cost([ITEMS[0]]), cost([ITEMS[0]]), false], "the cost is known before start");
  assertEquals(w.quota.get("u1") ?? 0, 0, "nothing counted before start");
  const st = await (await w.h("u1")(post({ action: "start", id: one.drill.id }))).json();
  assertEquals([st.cost, st.audio.cost], [cost([ITEMS[0]]), 0]);
  assertEquals(w.quota.get("u1"), cost([ITEMS[0]]));
});

Deno.test("K52 D155: the month the limit starts again, in Swedish time", async () => {
  const { nextMonthStart } = await import("./handler.ts");
  assertEquals(nextMonthStart(Date.parse("2026-11-13T12:00:00Z")), "2026-12-01");
  assertEquals(nextMonthStart(Date.parse("2026-12-31T23:30:00Z")), "2027-02-01", "already January in Stockholm");
  assertEquals(nextMonthStart(Date.parse("2026-12-15T12:00:00Z")), "2027-01-01");
});

Deno.test("Cue: 'Tryck en gång för svaret.' in the drill's own voice, made once per voice, never counted", async () => {
  const w = world();
  const a = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  const j = await (await w.h("u1")(post({ action: "get", id: a.drill.id }))).json();
  assertEquals(j.cue.press_for_answer.status, "done");
  assert(j.cue.press_for_answer.url.startsWith("https://signed/"));
  assertEquals(w.spoken.filter((t) => t === "Tryck en gång för svaret.").length, 1);
  assertEquals(w.quota.get("u1"), cost(ITEMS), "the cue costs nothing");
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

Deno.test("K90 (D213): /help try credits no longer change a save; the save costs the characters of its new audio", async () => {
  const w = world();
  w.credits.add("u1|" + questionKey(ITEMS[0].question));
  const j = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals([j.generated_questions, j.cost], [ITEMS.length, cost(ITEMS)]);
});

Deno.test("K90 (D213): quota says credits in characters: limit, used, remaining, when they come back", async () => {
  const w = world({ credits: 1500 });
  const q = await (await w.h("u1")(post({ action: "quota" }))).json();
  assertEquals([q.unit, q.limit, q.used, q.remaining, q.resets, q.resets_day], ["chars", 1500, 0, 1500, "2026-12-01", "1 december"]);
  assertEquals([q.left, q.suggest, q.per], [1500, 12, "month"], "old fields kept (suggest 12, D239)");
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

Deno.test("K66 (O63 punkt 4): the display text is stored and returned; the voice reads the spoken text", async () => {
  const w = world({ noSynth: true });
  const items = [{ question: "Vad hände kring arton hundrafemtio?", short: "Industrin växte.", long: "Industrin växte. Mer.",
    screen: { question: "Vad hände kring 1850?", bogus: 3 } }];
  const j = await (await w.h("u1")(post({ action: "save", items }))).json();
  const g = await (await w.h("u1")(post({ action: "get", id: j.drill.id }))).json();
  assertEquals(g.drill?.items?.[0]?.screen ?? g.items?.[0]?.screen, { question: "Vad hände kring 1850?" });
  assert([...w.audio.values()].some((a) => a.text.includes("arton hundrafemtio")), "the voice reads the words");
  assert(![...w.audio.values()].some((a) => a.text.includes("1850")));
});

Deno.test("K66 (A102): the preview row carries the display text for question and short", async () => {
  const { previewItem } = await import("./handler.ts");
  assertEquals(previewItem({ question: "Sedan arton hundrafemtio?", short: "Ja.", screen: { question: "Sedan 1850?", long: "x" } }),
    { question: "Sedan arton hundrafemtio?", short: "Ja.", screen: { question: "Sedan 1850?" } });
  assertEquals(previewItem({ question: "A?", short: "B.", screen: null }), { question: "A?", short: "B." });
});

Deno.test("K67 (Oscar O64): '/' in a formula is 'delat med'; an English exam keeps digits and English signs", async () => {
  const { voiceText, divided } = await import("./handler.ts");
  const v = voiceText("Hur räknar man ut hastighet med formeln v = s / t?");
  assert(v.includes("s delat med t"), v);
  assert(!v.includes("/"), v);
  assert(voiceText("Arean är A = b · h / 2.").includes("delat med två"), voiceText("Arean är A = b · h / 2."));
  assertEquals(divided("och/eller", "delat med"), "och/eller");
  assert(voiceText("Farten är 12 km/h.").includes("kilometer i timmen"));
  const en = voiceText("Since about 1850 the temperature has risen 1.2 degrees, 4 % and v = s / t.", "English");
  assert(en.includes("1850") && en.includes("1.2") && en.includes("4 percent") && en.includes("s divided by t") && en.includes("equals"), en);
  assert(!/arton|komma/.test(en), en);
});

Deno.test("K67 (Oscar O65): 'ja/nej' stays; English units and fractions are said, not divided", async () => {
  const { voiceText, divided } = await import("./handler.ts");
  assertEquals(divided("ja/nej", "delat med"), "ja/nej");
  assert(voiceText("p = F/A").includes("F delat med A"));
  const en = voiceText("At 12 km/h, 3/4 of scientists and 7/9 agree that v = s / t.", "English");
  assert(en.includes("12 kilometres per hour") && en.includes("three quarters") && en.includes("7 over 9") && en.includes("s divided by t"), en);
});

// ---------- K70 (D185): Läsläget, a text drill ----------
const TEXT = [
  { kind: "heading", text: "Fotosyntesen" },
  { kind: "para", text: "Växter bildar glukos av koldioxid och vatten. Det kräver ljus! Syre blir över, t.ex. i bladen." },
  { kind: "para", text: "Klorofyll fångar ljuset." },
];

Deno.test("K70 save a text: one file per part with times per sentence, costs its characters (K90), shared by hash", async () => {
  const w = world();
  const r = await w.h("u1")(post({ action: "save", drill: { title: "Bio", kind: "text" }, items: TEXT }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.drill.kind, "text");
  assertEquals(j.audio.total, 3, "one file per part");
  assertEquals(j.audio.done, 3);
  assertEquals(j.items[0].part, "heading");
  assertEquals(j.items[0].audio.text.sentences.length, 1);
  const p = j.items[1];
  assertEquals(p.text, TEXT[1].text);
  assertEquals(p.sentences, ["Växter bildar glukos av koldioxid och vatten.", "Det kräver ljus!", "Syre blir över, t.ex. i bladen."]);
  const times = p.audio.text.sentences as number[][];
  assertEquals(times.length, 3, "a time for every displayed sentence");
  assert(times[0][0] === 0 && times[0][1] < times[1][0] && times[1][1] < times[2][0], "in order, not overlapping");
  assertEquals(times[2][1], p.audio.text.duration_ms, "the last sentence ends with the file");
  const shown = TEXT.reduce((n, t) => n + t.text.length, 0);
  assertEquals(j.cost, shown, "K90: a text costs its shown characters");
  assertEquals(w.quota.get("u1"), shown);
  // another account saving the same text: 0 new characters, nothing counted (D144)
  const k = w.spoken.length;
  const r2 = await (await w.h("u2")(post({ action: "save", drill: { kind: "text" }, items: TEXT }))).json();
  assertEquals(r2.new_chars, 0);
  assertEquals(w.spoken.length, k);
  assertEquals(w.quota.get("u2") ?? 0, 0);
  // the kind never changes
  const bad = await w.h("u1")(post({ action: "save", drill: { id: j.drill.id, kind: "questions" }, items: ITEMS }));
  assertEquals(bad.status, 409);
  // list says the kind; a copy keeps it
  const l = await (await w.h("u1")(post({ action: "list" }))).json();
  assertEquals(l.drills[0].kind, "text");
});

Deno.test("K90 a long text costs its characters (parts whose audio exists cost 0); a question drill its questions and long answers", async () => {
  const w = world();
  const para = "Det här är en mening om cellen och dess delar. ".repeat(40).trim();
  const parts = [{ kind: "para", text: para.slice(0, 1500) }, { kind: "para", text: para.slice(0, 900) + " Slut." }];
  const j = await (await w.h("u1")(post({ action: "save", drill: { kind: "text" }, items: parts }))).json();
  assertEquals(j.cost, parts[0].text.length + parts[1].text.length);
  const again = await (await w.h("u2")(post({ action: "save", drill: { kind: "text" }, items: [parts[0], { kind: "para", text: "En ny mening." }] }))).json();
  assertEquals(again.cost, "En ny mening.".length, "the first part's audio exists");
  const q = await (await w.h("u3")(post({ action: "save", items: ITEMS }))).json();
  assertEquals([q.drill.kind, q.cost], ["questions", cost(ITEMS)]);
});

Deno.test("K70 a test account's text gets silent audio with sentence times (D180)", async () => {
  const w = world();
  const j = await runWithTest({ test: true, reason: "script", userId: "t1" }, async () => await (await w.h("t1")(post({ action: "save", drill: { kind: "text" }, items: TEXT }))).json());
  const files = [...w.audio.values()].filter((a) => a.kind === "text");
  assertEquals(files.length, 3);
  assert(files.every((a) => a.voice_id === TEST_VOICE_ID));
  assertEquals(j.items[1].audio.text.sentences?.length ?? files[1].sentences?.length, 3);
});

// ---------- K71 (D190): the audio is made at Starta prov ----------
Deno.test("K71 save with defer_audio: no audio, no count; start makes it all and counts; an edit after start makes only that question", async () => {
  const w = world();
  const s = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Bio" }, items: ITEMS }))).json();
  assertEquals(s.drill.audio_started, false);
  assertEquals(s.generated_questions, 0);
  assertEquals(s.new_chars, 0);
  assert(s.chars_on_start > 0);
  assertEquals(w.spoken.filter((t) => t !== CUE).length, 0, "nothing voiced at save");
  assertEquals(w.quota.get("u1") ?? 0, 0);
  // edits before start are free
  const edited = [{ ...ITEMS[0], short: "Klorofyll fångar ljus.", long: "Klorofyll fångar ljus. Det ger energi." }, ITEMS[1]];
  const s2 = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { id: s.drill.id }, items: edited.map((x, i) => ({ ...x, id: s.items[i].id })) }))).json();
  assertEquals(s2.generated_questions, 0);
  assertEquals(w.spoken.filter((t) => t !== CUE).length, 0);
  // the share before start starts the audio
  const st = await (await w.h("u1")(post({ action: "start", id: s.drill.id }))).json();
  assertEquals(st.drill.audio_started, true);
  assertEquals(st.generated_questions, 2);
  assertEquals(st.audio.done, st.audio.total);
  assertEquals(w.spoken.filter((t) => t !== CUE).length, 4);
  assert(w.spoken.some((t) => t.includes("Det ger energi")), "the edited answer is what was voiced");
  // start again: nothing new
  const again = await (await w.h("u1")(post({ action: "start", id: s.drill.id }))).json();
  assertEquals(again.generated_questions, 0);
  // an edit after start (even with defer_audio) makes only that question's long file
  const n = w.spoken.length;
  const after = [{ ...edited[0], id: st.items[0].id }, { ...ITEMS[1], long: ITEMS[1].long + " Ny mening.", id: st.items[1].id }];
  const e = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { id: s.drill.id }, items: after }))).json();
  assertEquals(w.spoken.length - n, 1, "one new file");
  assertEquals(e.generated_questions, 1);
});

Deno.test("K71 share and publish of a drill never started make its audio first; an old app's save makes it at once", async () => {
  const w = world();
  const s = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Bio" }, items: ITEMS }))).json();
  const sh = await w.h("u1")(post({ action: "share", id: s.drill.id }));
  assertEquals(sh.status, 200, "the audio was made, then shared");
  assert((await sh.json()).code);
  assertEquals(w.quota.get("u1"), cost(ITEMS));
  const old = await (await w.h("u2")(post({ action: "save", drill: { title: "Gammal app" }, items: [ITEMS[0]] }))).json();
  assertEquals(old.drill.audio_started, true);
  assertEquals(old.audio.done, old.audio.total);
});

Deno.test("K71 a text drill waits for start too; a test account's start gets silent audio (D180)", async () => {
  const w = world();
  const s = await runWithTest({ test: true, reason: "script", userId: "t1" }, async () =>
    await (await w.h("t1")(post({ action: "save", defer_audio: true, drill: { kind: "text" }, items: TEXT }))).json());
  assertEquals([...w.audio.values()].filter((a) => a.kind === "text").length, 0);
  const st = await runWithTest({ test: true, reason: "script", userId: "t1" }, async () =>
    await (await w.h("t1")(post({ action: "start", id: s.drill.id }))).json());
  assertEquals(st.audio.done, 3);
  assert([...w.audio.values()].filter((a) => a.kind === "text").every((a) => a.voice_id === TEST_VOICE_ID));
});

Deno.test("K72 an English text with the subject Historia is read in English; every sentence ends with a stop", async () => {
  const w = world();
  const en = "In 1769 James Watt improved the steam engine, and it was used in the mills of the north. About 1.2 million people moved to the towns.";
  const j = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", subject: "Historia" }, items: [{ kind: "para", text: en }] }))).json();
  assertEquals(j.drill.language, "English");
  const f = [...w.audio.values()].find((a) => a.kind === "text")!;
  assert(f.text.includes("1769") && !/sjuttonhundra|komma/.test(f.text), f.text);
  const sv = await (await w.h("u1")(post({ action: "save", drill: { kind: "text" }, items: [{ kind: "para", text: "Kroppen behöver kol, kväve osv. Nästa stycke handlar om energi." }] }))).json();
  assertEquals(sv.items[0].sentences.length, 2);
  const t = [...w.audio.values()].find((a) => a.kind === "text" && a.text.includes("Nästa"))!.text;
  assert(/vidare\. Nästa/.test(t) || /osv\. Nästa/.test(t), t);
});

// ---------- K74: rules version per drill, eleven_v4 prepared but off ----------
Deno.test("K74 a new drill gets the newest voice rules (4 since K115); an old drill (version 1) keeps the text it had, so nothing is made again", async () => {
  const w = world();
  const its = [{ question: "Vad gör klorofyll (i bladen)?", short: "Det fångar ljus.", long: "Det fångar ljus." }];
  const j = await (await w.h("u1")(post({ action: "save", items: its }))).json();
  assertEquals(w.drills.get(j.drill.id)!.voice_rules, 4);
  assert([...w.audio.values()].some((a) => a.text === "Vad gör klorofyll, i bladen?"));
  // an old drill: version 1 and its version 1 files
  const old = await (await w.h("u2")(post({ action: "save", defer_audio: true, items: its }))).json();
  w.drills.get(old.drill.id)!.voice_rules = 1;
  const st = await (await w.h("u2")(post({ action: "start", id: old.drill.id }))).json();
  assertEquals(st.audio.done, st.audio.total);
  assert([...w.audio.values()].some((a) => a.text === "Vad gör klorofyll (i bladen)?"), "version 1 text for the old drill");
});

Deno.test("K74 eleven_v4 cannot be chosen while drill_settings.allow_eleven_v4 is 0 (no call is ever made)", async () => {
  const w = world();
  const r = await w.h("u1")(post({ action: "save", drill: { voice_model: "eleven_v4" }, items: ITEMS }));
  assertEquals(r.status, 409);
  assertEquals((await r.json()).error.code, "voice_model_unavailable");
  assertEquals(w.models.filter((m) => m === "eleven_v4").length, 0);
});

// ---------- K77 (D197, D116): Repetitionsläget in Aron's analysis ----------
Deno.test("K77 a save logs new questions and answers; an edit logs before and after; an unchanged save logs nothing", async () => {
  const w = world();
  // K113 (D247): logged only for test accounts and for the one who shares (D57, share_history)
  const j = await (await w.h("u1")(post({ action: "save", defer_audio: true, share_history: true, drill: { subject: "Biologi" }, items: ITEMS }))).json();
  assertEquals(w.logged.map((r) => [r.mode, r.persona, r.question]), [["repetition", "sparad", ITEMS[0].question], ["repetition", "sparad", ITEMS[1].question]]);
  assertEquals(w.logged[0].answer, ITEMS[0].long);
  const n = w.logged.length;
  await w.h("u1")(post({ action: "save", defer_audio: true, drill: { id: j.drill.id }, items: ITEMS.map((x, i) => ({ ...x, id: j.items[i].id })) }));
  assertEquals(w.logged.length, n, "nothing changed, nothing logged");
  await w.h("u1")(post({ action: "start", id: j.drill.id }));
  assertEquals(w.logged.length, n, "Starta prov logs nothing new");
  const edited = [{ ...ITEMS[0], id: j.items[0].id, long: ITEMS[0].long + " Ny mening." }, { ...ITEMS[1], id: j.items[1].id }];
  await w.h("u1")(post({ action: "save", share_history: true, drill: { id: j.drill.id }, items: edited }));
  const e = w.logged.slice(n);
  assertEquals(e.length, 1);
  assertEquals(e[0].persona, "ändrad");
  assert(e[0].answer.includes("Svar före: " + ITEMS[0].long) && e[0].answer.includes("Ny mening."), e[0].answer);
});

Deno.test("K77 a text drill's text is never logged (B4); press statistics are; test accounts and copies log nothing", async () => {
  const w = world();
  const t = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", subject: "Historia" }, items: TEXT }))).json();
  assertEquals(w.logged.length, 0, "the text is the material");
  const st = await (await w.h("u1")(post({ action: "stats", share_history: true, id: t.drill.id, presses: { "1": 4, "2": 7, "3": 1 }, minutes: 12 }))).json();
  assertEquals(st.logged, true);
  assertEquals(w.logged[0].mode, "read");
  assertEquals(w.logged[0].persona, "tryck");
  assertEquals(w.logged[0].question, "Historia");
  assert(w.logged[0].answer.includes("1 tryck: 4, 2 tryck: 7, 3 tryck: 1") && w.logged[0].answer.includes("Minuter: 12"));
  assert(!w.logged[0].answer.includes("Fotosyntes") && !w.logged[0].answer.includes("glukos"), "no text from the drill");
  // per question for a question drill
  const q = await (await w.h("u1")(post({ action: "save", drill: { subject: "Bio" }, items: ITEMS }))).json();
  await w.h("u1")(post({ action: "stats", share_history: true, id: q.drill.id, presses: { "1": 2, "2": 1, "3": 0 }, per_question: [{ position: 1, presses: { "1": 2, "2": 1, "3": 0 } }] }));
  assert(w.logged.at(-1)!.answer.includes(`${ITEMS[1].question}: 1 tryck: 2`));
  assertEquals((await w.h("u1")(post({ action: "stats", id: q.drill.id, presses: { "1": -1 } }))).status, 400);
  // K113 (D247): a test account is logged (the analysis of our own tests), without asking
  const n0 = w.logged.length;
  await runWithTest({ test: true, reason: "header", userId: "t9" }, async () => {
    const x = await (await w.h("t9")(post({ action: "save", items: ITEMS }))).json();
    await w.h("t9")(post({ action: "stats", id: x.drill.id, presses: { "1": 1, "2": 1, "3": 1 } }));
  });
  assertEquals(w.logged.length, n0 + ITEMS.length + 1, "test accounts are logged (D247)");
  const n = w.logged.length;
  // an imported copy: the original's questions are not the recipient's, nothing logged
  const sh = await (await w.h("u1")(post({ action: "share", id: q.drill.id }))).json();
  await w.h("u2")(post({ action: "import", code: sh.code }));
  assertEquals(w.logged.length, n);
});

Deno.test("K113 (D247): an ordinary user who has not shared is never in the question log (save, edit, stats)", async () => {
  const w = world();
  const j = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { subject: "Biologi" }, items: ITEMS }))).json();
  await w.h("u1")(post({ action: "save", drill: { id: j.drill.id }, items: [{ ...ITEMS[0], id: j.items[0].id, long: ITEMS[0].long + " Ny." }, { ...ITEMS[1], id: j.items[1].id }] }));
  const st = await (await w.h("u1")(post({ action: "stats", id: j.drill.id, presses: { "1": 1, "2": 0, "3": 0 } }))).json();
  assertEquals(st.logged, false);
  // share_history must be exactly true (no "yes", no 1)
  await w.h("u1")(post({ action: "stats", share_history: "yes", id: j.drill.id, presses: { "1": 1, "2": 0, "3": 0 } }));
  assertEquals(w.logged.length, 0);
});

Deno.test("K77 numbers are masked as in qa-log", async () => {
  const { saveRows } = await import("./analysis.ts");
  const r = saveRows("questions", [], [{ question: "Vad är mitt personnummer?", short: "Det är 19990101-1234.", long: "Det är 19990101-1234." }]);
  assert(r[0].answer.includes("[personnummer]") && !r[0].answer.includes("1234"));
});

// ---------- K78 (D200): out of ElevenLabs credits costs the user nothing ----------
Deno.test("K78 credits run out during the audio: the questions are given back once, the app gets the code with the text", async () => {
  const w = world({ outOfCredits: true });
  const s = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(w.quota.get("u1"), cost(ITEMS), "counted at start, before ElevenLabs said no");
  const st = await (await w.h("u1")(post({ action: "status", id: s.drill.id }))).json();
  assertEquals(st.audio_unavailable, true);
  assertEquals(st.notice, { code: "audio_unavailable", message: "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt." });
  assertEquals([st.refunded_credits, st.refunded_questions], [cost(ITEMS), cost(ITEMS)], "K90: given back in credits");
  assertEquals(w.quota.get("u1"), 0, "nothing paid for audio that was not made");
  assertEquals(st.items[0].question, ITEMS[0].question, "the text is there as usual");
  assertEquals(st.items[0].long, ITEMS[0].long);
  const again = await (await w.h("u1")(post({ action: "status", id: s.drill.id }))).json();
  assertEquals(again.refunded_credits, undefined, "given back once");
  assertEquals(w.quota.get("u1"), 0);
});

Deno.test("K78 known out of credits: Starta prov sends nothing, counts nothing, the drill stays text; credits back: made as usual", async () => {
  const w = world({ outOfCredits: true });
  await w.h("u9")(post({ action: "save", items: [{ question: "Varför regnar det?", short: "Moln.", long: "Moln. Mer." }] })); // a real failure now
  const calls = w.spoken.length;
  const d = await (await w.h("u1")(post({ action: "save", defer_audio: true, items: ITEMS }))).json();
  const st = await (await w.h("u1")(post({ action: "start", id: d.drill.id }))).json();
  assertEquals(st.audio_unavailable, true);
  assertEquals(st.notice.code, "audio_unavailable");
  assertEquals(st.generated_questions, 0);
  assertEquals(st.drill.audio_started, false, "still not started: the next Starta prov makes the audio");
  assertEquals(w.quota.get("u1") ?? 0, 0);
  assertEquals(w.spoken.length, calls, "no call to ElevenLabs while it is known to be out");
  assertEquals(st.items.length, 2);
  // credits back, and the last failure is older than UNAVAILABLE_RETRY_MS
  w.setOut(false);
  for (const a of w.audio.values()) if (a.status === "failed") a.done_at = "2026-11-13T11:00:00Z";
  const ok = await (await w.h("u1")(post({ action: "start", id: d.drill.id }))).json();
  assertEquals(ok.audio_unavailable, undefined);
  assertEquals(ok.generated_questions, 2);
  assertEquals(ok.audio.done, ok.audio.total);
});

Deno.test("K78 a test account's fake out-of-credits stays among test files (D180): real traffic is not blocked by it", async () => {
  const w = world();
  await runWithTest({ test: true, reason: "header", userId: "t1", mode: "unavailable" }, async () => {
    await w.h("t1")(post({ action: "save", items: ITEMS }));
  });
  const r = await (await w.h("u1")(post({ action: "save", items: [ITEMS[0]] }))).json();
  assertEquals(r.audio_unavailable, undefined);
  assertEquals(r.generated_questions, 1);
  const t2 = await runWithTest({ test: true, reason: "header", userId: "t2" }, async () =>
    await (await w.h("t2")(post({ action: "save", items: [{ question: "Vad är is?", short: "Fruset vatten.", long: "Fruset vatten." }] }))).json());
  assertEquals(t2.audio_unavailable, true, "the next test save sees the test's fake failure");
  assertEquals(t2.generated_questions, 0);
  // K100: another tester (another first word in x-earmind-test) is not held back by it
  const t3 = await runWithTest({ test: true, reason: "header", userId: "t3", tag: "kevin-t50" }, async () =>
    await (await w.h("t3")(post({ action: "save", items: [{ question: "Vad är ånga?", short: "Kokat vatten.", long: "Kokat vatten." }] }))).json());
  assertEquals([t3.audio_unavailable, t3.generated_questions], [undefined, 1]);
});

Deno.test("K78 get on a drill kept as text while credits are out says audio_unavailable too", async () => {
  const w = world({ outOfCredits: true });
  await w.h("u9")(post({ action: "save", items: [{ question: "Varför regnar det?", short: "Moln.", long: "Moln. Mer." }] }));
  const d = await (await w.h("u1")(post({ action: "save", defer_audio: true, items: ITEMS }))).json();
  await w.h("u1")(post({ action: "start", id: d.drill.id }));
  const g = await (await w.h("u1")(post({ action: "get", id: d.drill.id }))).json();
  assertEquals(g.audio_unavailable, true);
  assertEquals(g.notice.code, "audio_unavailable");
});

Deno.test("K82/K90: quota gives credits left, the limit, when they come back and the price (1 credit per character)", async () => {
  const w = world({ credits: 1500 });
  await w.h("u1")(post({ action: "save", items: ITEMS }));
  const q = await (await w.h("u1")(post({ action: "quota" }))).json();
  assertEquals([q.used, q.limit, q.remaining, q.per, q.resets], [cost(ITEMS), 1500, 1500 - cost(ITEMS), "month", "2026-12-01"]);
  assertEquals([q.prices.unit, q.prices.per_char], ["chars", 1]);
  assertEquals(q.prices.classes.map((c: { class: string; max_chars: number; tokens: number }) => [c.class, c.max_chars, c.tokens]),
    [["normal", 100, 40], ["longer", 200, 60], ["too_long", 4000, 80]], "kept for older apps");
});

Deno.test("K88 the same client_id from the same account is one exam; without it two saves are two; another account has its own", async () => {
  const w = world();
  const cid = "5B6E2F1A-0C3D-4E5F-8A9B-112233445566";
  const a = await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Bio", client_id: cid }, items: ITEMS }));
  assertEquals(a.status, 200);
  const first = await a.json();
  const b = await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Bio", client_id: cid }, items: ITEMS }));
  assertEquals(b.status, 200);
  const second = await b.json();
  assertEquals(second.drill.id, first.drill.id, "the exam already saved");
  assertEquals(second.already_saved, true);
  assertEquals(second.items.length, first.items.length);
  assertEquals([...w.drills.values()].filter((d) => d.user_id === "u1").length, 1);
  // started through save (an old app's way): the second save counts nothing again
  const cid2 = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
  const s1 = await (await w.h("u1")(post({ action: "save", drill: { title: "Kemi", client_id: cid2 }, items: ITEMS }))).json();
  const used = w.quota.get("u1") ?? 0;
  const s2 = await (await w.h("u1")(post({ action: "save", drill: { title: "Kemi", client_id: cid2 }, items: ITEMS }))).json();
  assertEquals(s2.drill.id, s1.drill.id);
  assertEquals(s2.generated_questions, 0);
  assertEquals(w.quota.get("u1") ?? 0, used, "nothing counted twice");
  // without client_id: as before, two exams
  await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Utan" }, items: ITEMS }));
  await w.h("u1")(post({ action: "save", defer_audio: true, drill: { title: "Utan" }, items: ITEMS }));
  assertEquals([...w.drills.values()].filter((d) => d.title === "Utan").length, 2);
  // another account with the same id gets its own exam
  const o = await (await w.h("u2")(post({ action: "save", defer_audio: true, drill: { title: "Bio", client_id: cid }, items: ITEMS }))).json();
  assert(o.drill.id !== first.drill.id);
  // a save of the exam by its id still edits it (client_id is only for the first save)
  const e = await w.h("u1")(post({ action: "save", defer_audio: true, drill: { id: first.drill.id, title: "Bio 2", client_id: cid }, items: ITEMS }));
  assertEquals((await e.json()).drill.title, "Bio 2");
  // not a UUID: refused
  const bad = await w.h("u1")(post({ action: "save", drill: { title: "x", client_id: "abc" }, items: ITEMS }));
  assertEquals(bad.status, 400);
});

Deno.test("K88 two saves with the same client_id at once: one exam, the second's credits given back", async () => {
  const w = world();
  const cid = "11111111-2222-4333-8444-555555555555";
  const [r1, r2] = await Promise.all([1, 2].map(() => w.h("u1")(post({ action: "save", drill: { title: "Samtidigt", client_id: cid }, items: ITEMS }))));
  const [j1, j2] = [await r1.json(), await r2.json()];
  assertEquals(r1.status, 200);
  assertEquals(r2.status, 200);
  assertEquals(j1.drill.id, j2.drill.id);
  assertEquals([...w.drills.values()].filter((d) => d.title === "Samtidigt").length, 1);
  assertEquals(w.quota.get("u1") ?? 0, cost(ITEMS), "the credits counted once");
});

Deno.test("K91 (Oscar O76): deleting a drill keeps the out-of-credits mark, so the next save is still held back (D200)", async () => {
  const w = world({ outOfCredits: true });
  const a = await (await w.h("u1")(post({ action: "save", items: [{ question: "Varför regnar det?", short: "Moln.", long: "Moln. Mer." }] }))).json();
  assert([...w.audio.values()].some((f) => f.status === "failed" && (f.error ?? "").startsWith("audio_unavailable")));
  await w.h("u1")(post({ action: "delete", id: a.drill.id }));
  assert([...w.audio.values()].some((f) => f.status === "failed" && (f.error ?? "").startsWith("audio_unavailable")), "the mark stays");
  const calls = w.spoken.length;
  const b = await (await w.h("u2")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(b.audio_unavailable, true);
  assertEquals(w.spoken.length, calls, "nothing sent to ElevenLabs");
  assertEquals(w.quota.get("u2") ?? 0, 0);
});

Deno.test("K92 (D215 8): cost before saving: the same count as save, existing audio 0, nothing saved or queued, limited per account", async () => {
  const w = world({ credits: 1500 });
  const files = w.audio.size, spoken = w.spoken.length;
  const text = [{ kind: "heading", text: "Rubrik" }, { kind: "para", text: "Klorofyll fångar ljus. Växten bildar glukos." }];
  const c = await w.h("u1")(post({ action: "cost", drill: { kind: "text" }, items: text }));
  assertEquals(c.status, 200);
  const j = await c.json();
  assertEquals([j.cost, j.remaining, j.limit, j.unit, j.enough], [text[0].text.length + text[1].text.length, 1500, 1500, "chars", true]);
  assertEquals([w.drills.size, w.audio.size, w.spoken.length, w.quota.get("u1") ?? 0], [0, files, spoken, 0], "nothing saved, queued, voiced or counted");
  // the save then costs exactly that
  const s = await (await w.h("u1")(post({ action: "save", drill: { kind: "text" }, items: text }))).json();
  assertEquals(s.cost, j.cost);
  // the same text again: 0 (its audio exists); questions too
  assertEquals((await (await w.h("u2")(post({ action: "cost", drill: { kind: "text" }, items: text }))).json()).cost, 0);
  assertEquals((await (await w.h("u2")(post({ action: "cost", items: ITEMS }))).json()).cost, cost(ITEMS));
  // a limit per account: the 21st in a minute is refused
  let last = 200;
  for (let i = 0; i < 20; i++) last = (await w.h("u3")(post({ action: "cost", items: [{ question: `Fråga ${i}?`, short: "Svar.", long: "Svar." }] }))).status;
  assertEquals(last, 200);
  assertEquals((await w.h("u3")(post({ action: "cost", items: ITEMS }))).status, 429);
});

Deno.test("O77: cost's day limit has its own words (the minute limit keeps its own)", async () => {
  const w = world({ credits: 1500 });
  await w.limiter.check("drill_cost:u:u9:d", 300, 86400, 300); // the day already used up
  const r = await w.h("u9")(post({ action: "cost", items: ITEMS }));
  assertEquals(r.status, 429);
  const j = await r.json();
  assertEquals(JSON.stringify(j).includes("Du har förhandsvisat många texter i dag. Försök igen i morgon."), true, JSON.stringify(j));
  for (let i = 0; i < 20; i++) await w.h("u8")(post({ action: "cost", items: ITEMS }));
  const m = await w.h("u8")(post({ action: "cost", items: ITEMS }));
  assertEquals(m.status, 429);
  assertEquals(JSON.stringify(await m.json()).includes("Vänta en stund."), true);
});

Deno.test("T28: drill.said marks a Säg text at its first save, is kept, shown in get and list, and not copied by import", async () => {
  const w = world({ credits: 1500 });
  const text = [{ kind: "para", text: "Ring mamma klockan fem." }];
  const s = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", said: true }, items: text }))).json();
  assertEquals(s.drill.said, true);
  // a resave without the field keeps it; a later said:false does not remove it either
  const r = await (await w.h("u1")(post({ action: "save", drill: { id: s.drill.id, kind: "text", said: false }, items: text }))).json();
  assertEquals(r.drill.said, true);
  assertEquals((await (await w.h("u1")(post({ action: "get", id: s.drill.id }))).json()).drill.said, true);
  assertEquals((await (await w.h("u1")(post({ action: "list" }))).json()).drills.find((d: { id: string }) => d.id === s.drill.id).said, true);
  // an exam is not said
  const e = await (await w.h("u1")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(e.drill.said, false);
  // the copy another account imports is not said
  const code = (await (await w.h("u1")(post({ action: "share", id: s.drill.id }))).json()).code;
  const imp = await (await w.h("u2")(post({ action: "import", code }))).json();
  assertEquals((imp.drill ?? imp).said ?? false, false);
});

Deno.test("K100: save with start:true makes a Säg text in one call (audio started, counted once); the inviter's reward runs once", async () => {
  const w = world({ credits: 1500 });
  const text = [{ kind: "para", text: "Ring mamma klockan fem i dag." }];
  const s = await (await w.h("u1")(post({ action: "save", start: true, defer_audio: true, drill: { kind: "text", said: true, client_id: crypto.randomUUID() }, items: text }))).json();
  assertEquals([s.drill.audio_started, s.cost, w.quota.get("u1"), w.started], [true, text[0].text.length, text[0].text.length, ["u1"]]);
  assert(s.items[0].id, "the item has its id in the answer");
  // the same drill started again: nothing new, no second reward
  const again = await (await w.h("u1")(post({ action: "start", id: s.drill.id }))).json();
  assertEquals([again.cost, w.started.length, again.items[0].id], [0, 1, s.items[0].id]);
  // the two-call way (save, then start) rewards once too
  const d = await (await w.h("u2")(post({ action: "save", defer_audio: true, drill: { kind: "text" }, items: [{ kind: "para", text: "Köp mjölk på vägen hem." }] }))).json();
  assertEquals([d.drill.audio_started, w.started.length], [false, 1]);
  await w.h("u2")(post({ action: "start", id: d.drill.id }));
  await w.h("u2")(post({ action: "start", id: d.drill.id }));
  assertEquals(w.started, ["u1", "u2"]);
  // the item ids given at save are the ones the drill keeps
  const g = await (await w.h("u1")(post({ action: "get", id: s.drill.id }))).json();
  assertEquals(g.items.map((i: { id: string }) => i.id), s.items.map((i: { id: string }) => i.id));
});

Deno.test("K100 with a background queue: the answer says pending without reading the files again; the files are made after", async () => {
  const bg: Promise<unknown>[] = [];
  const w = world({ credits: 1500, background: (p) => void bg.push(p) });
  const text = [{ kind: "para", text: "Ring mamma klockan sex i kväll." }];
  const s = await (await w.h("u1")(post({ action: "save", start: true, drill: { kind: "text" }, items: text }))).json();
  assertEquals([s.drill.audio_started, s.items[0].audio.text.status, s.cost], [true, "pending", text[0].text.length]);
  await Promise.all(bg);
  const g = await (await w.h("u1")(post({ action: "get", id: s.drill.id }))).json();
  assertEquals(g.items[0].audio.text.status, "done");
});

Deno.test("K93 (D216): an admin is never charged or refused; quota, list and cost say unlimited; another account is unchanged", async () => {
  const w = world({ credits: 10 });
  w.admins.add("aron");
  const s = await (await w.h("aron")(post({ action: "save", items: ITEMS }))).json();
  assertEquals([s.cost, s.audio.done, w.quota.get("aron") ?? 0], [cost(ITEMS), s.audio.total, 0], "made, nothing counted");
  const d = await w.h("aron")(post({ action: "save", defer_audio: true, items: [{ question: "Varför regnar det?", short: "Moln.", long: "Moln. Mer." }] }));
  assertEquals(d.status, 200, "never 402");
  const q = await (await w.h("aron")(post({ action: "quota" }))).json();
  assertEquals([q.unlimited, q.used], [true, 0]);
  assert(q.remaining >= 1_000_000);
  assertEquals((await (await w.h("aron")(post({ action: "list" }))).json()).quota.unlimited, true);
  const c = await (await w.h("aron")(post({ action: "cost", items: [{ question: "Hur fungerar ett öga?", short: "Ljus.", long: "Ljus. Mer." }] }))).json();
  assertEquals([c.unlimited, c.enough], [true, true]);
  assertEquals(w.drills.get(s.drill.id)!.charged_chars ?? 0, 0, "nothing charged, so nothing is ever given back");
  // another account: as before
  assertEquals((await w.h("u1")(post({ action: "save", items: [{ question: "Vad är en vulkan?", short: "Ett berg med magma.", long: "Ett berg med magma. Mer." }] }))).status, 402);
  assertEquals((await (await w.h("u1")(post({ action: "quota" }))).json()).unlimited, undefined);
});

// ---------- K95 (D220): "Hur ska det låta?" ----------
Deno.test("K95 style: words checked in code, only allowed tags, offsets mapped, tags are not words", async () => {
  const { checkTagged, mapOffset, stripTags, cleanStyle } = await import("./style.ts");
  const spoken = "Växter bildar glukos. Det kräver ljus.";
  assertEquals(checkTagged(spoken, "[calm] Växter bildar glukos. [short pause] Det kräver ljus."), "[calm] Växter bildar glukos. [short pause] Det kräver ljus.");
  assertEquals(checkTagged(spoken, "[Calm] Växter bildar glukos. Det kräver ljus."), "[calm] Växter bildar glukos. Det kräver ljus.", "lower case");
  assertEquals(checkTagged(spoken, "[skånsk dialekt] Växter bildar glukos. Det kräver ljus."), "Växter bildar glukos. Det kräver ljus.", "a tag not on the list is dropped");
  assertEquals(checkTagged(spoken, "[calm] Växter gör glukos. Det kräver ljus."), null, "a changed word: refused");
  assertEquals(checkTagged(spoken, "[calm] Växter bildar glukos. Det kräver ljus. Mer."), null, "an added word: refused");
  assertEquals(checkTagged(spoken, "Växter [bildar glukos. Det kräver ljus."), null, "a loose bracket: refused");
  const tagged = "[calm] Växter bildar glukos. [short pause] Det kräver ljus.";
  assertEquals(stripTags(tagged).plain, spoken);
  const end1 = spoken.indexOf(".") + 1;
  assertEquals(tagged.slice(0, mapOffset(tagged, end1)).endsWith("glukos."), true);
  assertEquals(mapOffset(tagged, spoken.length), tagged.length);
  assertEquals(cleanStyle("  Lugnt,\n  tydligt  " + "x".repeat(100)).length, 80);
  const { timings } = await import("./handler.ts");
  const t = "[calm] Hej då";
  const st = [...t].map((_, i) => i / 10), en = [...t].map((_, i) => i / 10 + 0.05);
  assertEquals(timings(t, st, en).words.length, 2, "[calm] is not a word");
});

Deno.test("K95 style: v3, tags only on new files, the same text and style again costs 0, another style is new; untagged without a styler", async () => {
  const asked: string[] = [];
  const styler = (t: string, s: string) => (asked.push(`${s}|${t}`), Promise.resolve(`[calm] ${t}`));
  const w = world({ styler });
  const text = [{ kind: "para", text: "Klorofyll fångar ljus. Växten bildar glukos." }];
  const a = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", style: "Lugnt och tydligt" }, items: text }))).json();
  assertEquals([a.drill.voice_model, a.drill.style, a.cost], ["eleven_v3", "Lugnt och tydligt", text[0].text.length]);
  assertEquals(asked.length, 1);
  const f = [...w.audio.values()].find((x) => x.kind === "text")!;
  assert(f.text.startsWith("[calm] "), f.text);
  assertEquals(f.model, "eleven_v3");
  // the same text and style on another account: the file exists, no Haiku, 0 credits
  const b = await (await w.h("u2")(post({ action: "save", drill: { kind: "text", style: "Lugnt och tydligt" }, items: text }))).json();
  assertEquals([b.cost, asked.length], [0, 1]);
  // the cost before saving counts the style, without Haiku
  assertEquals((await (await w.h("u3")(post({ action: "cost", drill: { kind: "text", style: "Glatt" }, items: text }))).json()).cost, text[0].text.length);
  assertEquals(asked.length, 1);
  // another style = new audio
  const c = await (await w.h("u3")(post({ action: "save", drill: { kind: "text", style: "Glatt" }, items: text }))).json();
  assertEquals([c.cost, asked.length], [text[0].text.length, 2]);
  // a styler that changes words is not trusted: the untagged text is voiced
  const w2 = world({ styler: () => Promise.resolve(null) });
  await w2.h("u1")(post({ action: "save", drill: { kind: "text", style: "Viskande" }, items: text }));
  assertEquals([...w2.audio.values()].find((x) => x.kind === "text")!.text, "Klorofyll fångar ljus. Växten bildar glukos.");
  // a drill locked to another voice cannot get a style
  const d = await (await w.h("u4")(post({ action: "save", drill: { voice_model: "A" }, items: ITEMS }))).json();
  assertEquals((await w.h("u4")(post({ action: "save", drill: { id: d.drill.id, style: "Lugnt" }, items: ITEMS }))).status, 409);
});

Deno.test("K96 (D220): a drill's voice from the catalog, locked at the first save; its own files; not in the catalog = 400", async () => {
  const w = world();
  const a = await (await w.h("u1")(post({ action: "save", drill: { voice_id: "CatalogVoice01" }, items: ITEMS }))).json();
  assertEquals(a.drill.voice_id, "CatalogVoice01");
  assert([...w.audio.values()].filter((f) => f.kind !== "question" || f.seq !== -1).some((f) => f.voice_id === "CatalogVoice01"));
  const b = await (await w.h("u2")(post({ action: "save", items: ITEMS }))).json();
  assertEquals(b.cost, cost(ITEMS), "another voice = other files");
  assertEquals((await w.h("u1")(post({ action: "save", drill: { id: a.drill.id, voice_id: "OtherVoice0002" }, items: ITEMS }))).status, 409);
  assertEquals((await w.h("u1")(post({ action: "save", drill: { id: a.drill.id }, items: ITEMS }))).status, 200, "kept when not sent");
  assertEquals((await w.h("u3")(post({ action: "save", drill: { voice_id: "NotInCatalog01" }, items: ITEMS }))).status, 400);
  assertEquals((await w.h("u3")(post({ action: "save", drill: { voice_id: "x y" }, items: ITEMS }))).status, 400);
});

// ---------- K99 (D223): mixed voices and the AI's choice ----------
const CAT = [{ voice_id: "VoiceAnnaSv0001", name: "Anna" }, { voice_id: "VoiceKinesSv002", name: "Kines" }, { voice_id: "VoiceHindiSv003", name: "Hindi" }];
Deno.test("K99 mix_voices: each part gets a catalog voice by lot, kept on later saves; the same each time; cost counts it", async () => {
  const w = world({ catalog: CAT });
  const parts = ["Första meningen här.", "Andra meningen här.", "Tredje meningen här.", "Fjärde meningen här.", "Femte meningen här.", "Sjätte meningen här."].map((text) => ({ kind: "para", text }));
  const c = await (await w.h("u1")(post({ action: "cost", drill: { kind: "text", mix_voices: true }, items: parts }))).json();
  const a = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { kind: "text", mix_voices: true }, items: parts }))).json();
  assertEquals([a.drill.mix_voices, c.cost, a.cost], [true, parts.reduce((n, p) => n + p.text.length, 0), parts.reduce((n, p) => n + p.text.length, 0)]);
  const voices = a.items.map((i: { voice_id?: string }) => i.voice_id);
  assert(voices.every((v: string) => CAT.some((x) => x.voice_id === v)));
  assert(new Set(voices).size >= 2, `mixed: ${voices}`);
  // start makes each part with its own voice; a later save keeps the voices (no new audio)
  const st = await (await w.h("u1")(post({ action: "start", id: a.drill.id }))).json();
  assertEquals(st.items.map((i: { voice_id?: string }) => i.voice_id), voices);
  const files = [...w.audio.values()].filter((f) => f.kind === "text");
  assert(new Set(files.map((f) => f.voice_id)).size >= 2);
  const again = await (await w.h("u1")(post({ action: "save", drill: { id: a.drill.id }, items: st.items.map((i: { id: string; text: string }) => ({ id: i.id, kind: "para", text: i.text })) }))).json();
  assertEquals([again.cost, again.items.map((i: { voice_id?: string }) => i.voice_id)], [0, voices]);
});

Deno.test("K114 (D252): mixing picks voices in the text's language (English text: en voices; Swedish: sv, as before)", async () => {
  const cat: { voice_id: string; name: string; language?: string }[] = [...CAT, { voice_id: "VoiceNikiEn0004", name: "Niki", language: "en" }, { voice_id: "VoicePaulEn0005", name: "Paul", language: "en" }, { voice_id: "VoiceChrisEn006", name: "Chris", language: "en" }];
  const en = new Set(cat.filter((v) => v.language === "en").map((v) => v.voice_id));
  const w = world({ catalog: cat });
  const sv = ["Första meningen här och nu.", "Andra meningen är det.", "Tredje meningen som är här.", "Fjärde meningen för att det är så.", "Femte meningen med en katt.", "Sjätte meningen på en stol."].map((text) => ({ kind: "para", text }));
  const enParts = ["The first sentence is here.", "The second one is of the same kind.", "The third is in the middle.", "The fourth is for the test.", "The fifth is with a cat.", "The sixth is by the sea."].map((text) => ({ kind: "para", text }));
  const a = await (await w.h("u1")(post({ action: "save", defer_audio: true, drill: { kind: "text", mix_voices: true }, items: sv }))).json();
  const b = await (await w.h("u2")(post({ action: "save", defer_audio: true, drill: { kind: "text", mix_voices: true }, items: enParts }))).json();
  const va = a.items.map((i: { voice_id?: string }) => i.voice_id), vb = b.items.map((i: { voice_id?: string }) => i.voice_id);
  assert(va.every((v: string) => !en.has(v)), `Swedish text, Swedish voices: ${va}`);
  assert(vb.every((v: string) => en.has(v)), `English text, English voices: ${vb}`);
  assert(new Set(vb).size >= 2, `mixed: ${vb}`);
  // the Swedish pool is the one it was before English voices came, so the same Swedish text keeps its voices (O81)
  const old = world({ catalog: CAT });
  const c = await (await old.h("u3")(post({ action: "save", defer_audio: true, drill: { kind: "text", mix_voices: true }, items: sv }))).json();
  assertEquals(c.items.map((i: { voice_id?: string }) => i.voice_id), va);
});

Deno.test("K115 (D253): the user's lang decides the voice's language when the text cannot tell (1999); the text's own language wins", async () => {
  const w = world();
  const text = (u: string, b: Record<string, unknown>) => w.h(u)(post({ action: "save", drill: { kind: "text" }, items: [{ kind: "para", text: "1999" }], ...b }));
  await text("u1", { lang: "en" });
  await text("u2", { lang: "sv" });
  const said = [...w.audio.values()].filter((f) => f.kind === "text").map((f) => f.text);
  assert(said.includes("1999."), `English: ${said}`);
  assert(said.includes("Nittonhundranittio nio."), `Swedish: ${said}`);
  // an English text with lang sv is still read in English (the exam/text language rule, D251)
  await w.h("u3")(post({ action: "save", drill: { kind: "text" }, items: [{ kind: "para", text: "The euro came in 1999 and the people of the country were happy with it." }], lang: "sv" }));
  assert([...w.audio.values()].some((f) => f.kind === "text" && f.text.startsWith("The euro came in 1999")), "English text keeps its digits");
});

Deno.test("O81: with mixed voices the same text gets the same voice in a new drill, so its audio is reused (cost 0)", async () => {
  const w = world({ catalog: CAT });
  const parts = ["Första meningen här.", "Andra meningen här.", "Tredje meningen här.", "Fjärde meningen här."].map((text) => ({ kind: "para", text }));
  const a = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", mix_voices: true }, items: parts }))).json();
  const b = await (await w.h("u2")(post({ action: "save", drill: { kind: "text", mix_voices: true }, items: parts }))).json();
  assertEquals(b.items.map((i: { voice_id?: string }) => i.voice_id), a.items.map((i: { voice_id?: string }) => i.voice_id));
  assertEquals([a.cost > 0, b.cost], [true, 0]);
});

Deno.test("O80 F2: a text with its own square brackets ([1], [sic]) still gets its style", async () => {
  const seen: string[] = [];
  const w = world({ styler: (t) => (seen.push(t), Promise.resolve(`[calm] ${t}`)) });
  const r = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", style: "Lugnt" }, items: [{ kind: "para", text: "Enligt källan [1] var det så [sic]." }] }))).json();
  assertEquals(r.status ?? 200, 200);
  assert(seen.length === 1 && !/[\[\]]/.test(seen[0]), seen.join("|"));
  const f = [...w.audio.values()].find((x) => x.kind === "text")!;
  // the voice text rules (D196) already read them as pauses; the tag is kept and no other bracket is left
  assert(f.text.startsWith("[calm] ") && !/\[(1|sic)\]/.test(f.text), f.text);
});

Deno.test("K99 the AI picks a catalog voice for a style when none is chosen; a voice not in the list is ignored; a chosen voice wins", async () => {
  const asked: string[] = [];
  const w = world({ catalog: CAT, picker: (s) => (asked.push(s), Promise.resolve({ voice_id: "VoiceKinesSv002", reason: "Lugn och tydlig röst." })) });
  const text = [{ kind: "para", text: "Klorofyll fångar ljus." }];
  const c = await (await w.h("u1")(post({ action: "cost", drill: { kind: "text", style: "Lugnt" }, items: text }))).json();
  assertEquals([c.voice_id, c.voice_reason], ["VoiceKinesSv002", "Lugn och tydlig röst."]);
  const a = await (await w.h("u1")(post({ action: "save", drill: { kind: "text", style: "Lugnt" }, items: text }))).json();
  assertEquals([a.drill.voice_id, a.voice_reason], ["VoiceKinesSv002", "Lugn och tydlig röst."]);
  const own = await (await w.h("u2")(post({ action: "save", drill: { kind: "text", style: "Lugnt", voice_id: "VoiceAnnaSv0001" }, items: text }))).json();
  assertEquals([own.drill.voice_id, own.voice_reason], ["VoiceAnnaSv0001", undefined]);
  const w2 = world({ catalog: CAT, picker: () => Promise.resolve({ voice_id: "MadeUpVoice0001", reason: "x" }) });
  const b = await (await w2.h("u1")(post({ action: "save", drill: { kind: "text", style: "Glatt" }, items: text }))).json();
  assertEquals(b.drill.voice_id, null, "a voice not in the catalog is never used");
});

Deno.test("Angela Fable A154: quota with long_words says what one question costs (the K110 upper bound) and suggests 12", async () => {
  const w = world();
  const { estimatedCostPerQuestion } = await import("../exam/drill.ts");
  const q = await (await w.h("u1")(post({ action: "quota", long_words: 90 }))).json();
  assertEquals(q.exam, { per_question: estimatedCostPerQuestion(90), min_questions: 3, long_words: 90 });
  assertEquals(q.exam.per_question, 642);
  assertEquals(q.suggest, 12);
  const longer = await (await w.h("u1")(post({ action: "quota", long_words: 130 }))).json();
  assertEquals(longer.exam.per_question, estimatedCostPerQuestion(130));
  const none = await (await w.h("u1")(post({ action: "quota" }))).json();
  assertEquals(none.exam.long_words, 90, "without long_words: the default length");
  const odd = await (await w.h("u1")(post({ action: "quota", long_words: 9999 }))).json();
  assertEquals(odd.exam.long_words, 200, "clamped as exam drill clamps it");
});

Deno.test("K114 (D249): a web account's new audio counts against the web's daily caps per network; the app's never", async () => {
  const { withWebGuard, WEB_LIMITS } = await import("../_shared/webguard.ts");
  const w = world();
  const jwt = (sub: string) => `x.${btoa(JSON.stringify({ sub })).replace(/=+$/, "")}.y`;
  const text = (n: number) => [{ kind: "para", text: ("Mening om cellen " + n + ". ").repeat(40).slice(0, 1200) }];
  const web = (u: string, n: number) =>
    withWebGuard(w.h(u), { limiter: w.limiter })(new Request("http://x/drill", {
      method: "POST", headers: { "content-type": "application/json", origin: "https://earmind.vercel.app", authorization: `Bearer ${jwt(u)}`, "x-forwarded-for": "203.0.113.9" },
      body: JSON.stringify({ action: "save", start: true, drill: { kind: "text", title: `W${n}` }, items: text(n) }),
    }));
  let paid = 0, status = 200, code = "", n = 0;
  while (status === 200 && n < 20) {
    const r = await web("w0", n++);
    const j = await r.json();
    status = r.status;
    if (status === 200) paid += j.cost ?? 0;
    else code = j.error?.code;
  }
  assertEquals(status, 429);
  assertEquals(code, "web_daily_cap");
  assert(paid <= WEB_LIMITS.creditsPerIpPerDay, `paid ${paid}`);
  assert(n > 1, "the first saves were allowed");
  // the app (no Origin) is not counted
  assertEquals((await w.h("app")(post({ action: "save", start: true, drill: { kind: "text", title: "App" }, items: text(99) }))).status, 200);
});

Deno.test("D239 (Toby T24): with 1 500 credits the quota prices the smallest exam at a long answer length that fits", async () => {
  const q = await (await world({ credits: 1500 }).h("u1")(post({ action: "quota", long_words: 90 }))).json();
  assert(q.exam.long_words < 90 && q.exam.long_words >= DRILL_LIMITS.longWordsMin, JSON.stringify(q.exam));
  assert(q.exam.per_question * q.exam.min_questions <= 1500, JSON.stringify(q.exam));
  assertEquals(q.exam.fitted, true);
  const rich = await (await world({ credits: 9000 }).h("u1")(post({ action: "quota", long_words: 90 }))).json();
  assertEquals([rich.exam.long_words, rich.exam.per_question, rich.exam.fitted], [90, 642, undefined], "enough credits: as before");
});
