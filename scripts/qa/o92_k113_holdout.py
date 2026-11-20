"""O92 (Oscar moln, 2026-11-20): K113 offline, egna fall utöver Kevins handler_test.ts.
Bygger en testfil i en temporär mapp av handler_test.ts rad 1-212 (world, post, ITEMS) med absoluta importer och lägger
till Oscars fall; ändrar inget i backend/. Kör: python3 scripts/qa/o92_k113_holdout.py [sökväg till deno]"""
import os, pathlib, subprocess, sys, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
D = ROOT / "backend/supabase/functions/drill"
head = (D / "handler_test.ts").read_text(encoding="utf-8").split("\n")[:212]
src = "\n".join(head).replace('from "./', f'from "file://{D}/').replace('from "../', f'from "file://{D.parent}/')
src += r'''

// ---------- O92 (Oscar): K113 holdout ----------
const STATS = (id: string, extra: Record<string, unknown> = {}) => post({ action: "stats", id, presses: { "1": 1, "2": 0, "3": 0 }, ...extra });

Deno.test("O92 1: share_history som sträng \"true\" eller 1 loggar inget (save, stats)", async () => {
  const w = world();
  for (const v of ["true", 1, "1", "ja"]) {
    const j = await (await w.h("u1")(post({ action: "save", defer_audio: true, share_history: v, drill: { subject: "Bio" }, items: ITEMS.map((x) => ({ ...x, question: x.question + String(v) })) }))).json();
    const st = await (await w.h("u1")(STATS(j.drill.id, { share_history: v }))).json();
    assertEquals(st.logged, false, `stats med ${JSON.stringify(v)}`);
  }
  assertEquals(w.logged.length, 0);
});

Deno.test("O92 2: delning gäller per anrop: save med true loggar, nästa ändring utan loggar inte", async () => {
  const w = world();
  const j = await (await w.h("u1")(post({ action: "save", defer_audio: true, share_history: true, drill: { subject: "Bio" }, items: ITEMS }))).json();
  assertEquals(w.logged.length, ITEMS.length);
  await w.h("u1")(post({ action: "save", drill: { id: j.drill.id }, items: [{ ...ITEMS[0], id: j.items[0].id, long: ITEMS[0].long + " Till." }, { ...ITEMS[1], id: j.items[1].id }] }));
  assertEquals(w.logged.length, ITEMS.length, "ändringen utan share_history loggas inte");
  const st = await (await w.h("u1")(STATS(j.drill.id))).json();
  assertEquals(st.logged, false);
});

Deno.test("O92 3: testtrafik loggas också med share_history false, för alla skäl (huvud, skript, ci, testkonto)", async () => {
  const w = world();
  let n = 0;
  for (const reason of ["header", "script", "ci", "account"]) {
    await runWithTest({ test: true, reason, userId: "t" + reason } as never, async () => {
      const x = await (await w.h("t" + reason)(post({ action: "save", defer_audio: true, share_history: false, drill: { subject: "Bio" }, items: ITEMS.map((i) => ({ ...i, question: i.question + reason })) }))).json();
      const st = await (await w.h("t" + reason)(STATS(x.drill.id, { share_history: false }))).json();
      assertEquals(st.logged, true, reason);
    });
    n += ITEMS.length + 1;
    assertEquals(w.logged.length, n, reason);
  }
});

Deno.test("O92 4: test: false i testsammanhanget loggar inte (bara test: true räknas)", async () => {
  const w = world();
  await runWithTest({ test: false, reason: "none", userId: "u5" } as never, async () => {
    const x = await (await w.h("u5")(post({ action: "save", defer_audio: true, drill: { subject: "Bio" }, items: ITEMS }))).json();
    const st = await (await w.h("u5")(STATS(x.drill.id))).json();
    assertEquals(st.logged, false);
  });
  assertEquals(w.logged.length, 0);
});

Deno.test("O92 5: en Säg-text med share_history true loggar aldrig texten (B4), bara trycken", async () => {
  const w = world();
  const t = await (await w.h("u1")(post({ action: "save", defer_audio: true, share_history: true, drill: { kind: "text", said: true, subject: "Svenska" }, items: [{ kind: "para", text: "Ring mormor på söndag klockan fem." }] }))).json();
  assertEquals(w.logged.length, 0);
  await w.h("u1")(STATS(t.drill.id, { share_history: true }));
  assert(w.logged.every((r) => !r.answer.includes("mormor") && !r.question.includes("mormor")), JSON.stringify(w.logged));
});
'''
deno = sys.argv[1] if len(sys.argv) > 1 else "deno"
with tempfile.TemporaryDirectory() as tmp:
    f = pathlib.Path(tmp) / "o92_k113_test.ts"
    f.write_text(src, encoding="utf-8")
    r = subprocess.run([deno, "test", "--no-lock", "--no-check", "-A", "--filter", "O92", str(f)], cwd=str(D), env={**os.environ, "NO_COLOR": "1"})
    sys.exit(r.returncode)
