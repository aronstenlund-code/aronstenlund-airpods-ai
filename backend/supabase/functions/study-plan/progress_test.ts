// K31 (streak + notification) and K33 (% redo), code only.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { notificationFor, readinessOf, streakOf } from "./progress.ts";
import { createPlanHandler } from "./handler.ts";

Deno.test("K31 streak: days in a row, alive until midnight, lost after a missed day, best run kept", () => {
  assertEquals(streakOf(["2026-11-08", "2026-11-09", "2026-11-10"], "2026-11-10"), { current: 3, best: 3, done_today: true, at_risk: false });
  assertEquals(streakOf(["2026-11-08", "2026-11-09"], "2026-11-10"), { current: 2, best: 2, done_today: false, at_risk: true });
  assertEquals(streakOf(["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-08"], "2026-11-10"), { current: 0, best: 3, done_today: false, at_risk: false });
  assertEquals(streakOf([], "2026-11-10"), { current: 0, best: 0, done_today: false, at_risk: false });
  assertEquals(streakOf(["2026-11-10", "2026-11-10", "2026-11-11"], "2026-11-10").current, 1, "duplicates and future days ignored");
});

Deno.test("K31 notification: countdown + '5 snabba frågor', the streak when it is at risk, nothing when today is done", () => {
  const atRisk = streakOf(["2026-11-09"], "2026-11-10");
  assertEquals(notificationFor(atRisk, { name: "Biologiprovet", days_left: 3, first: "cellandning" }), {
    title: "3 dagar kvar till Biologiprovet",
    body: "5 snabba frågor på cellandning håller din svit på 1 dag vid liv.",
  });
  const none = streakOf([], "2026-11-10");
  assertEquals(notificationFor(none, { name: "Provet", days_left: 1 }), { title: "I morgon är det provet", body: "5 snabba frågor? Det tar två minuter." });
  assertEquals(notificationFor(none, { name: "Kemiprovet", days_left: 0 })?.title, "I dag är det Kemiprovet. Lycka till!");
  assertEquals(notificationFor(none, null)?.title, "5 snabba frågor");
  assertEquals(notificationFor(streakOf(["2026-11-10"], "2026-11-10"), { name: "x", days_left: 2 }), null);
});

Deno.test("K33 readiness: the documented formula, the three weakest with a reason", () => {
  const r = readinessOf([
    { concept: "cellandning", history: [{ date: "2026-11-09", ok: false }] }, // wrong last = 0
    { concept: "fotosyntes", history: [{ date: "2026-11-09", ok: true }] }, // right once = 0.5
    { concept: "mitos", history: [{ date: "2026-11-01", ok: true }, { date: "2026-11-02", ok: true }, { date: "2026-11-05", ok: true }] }, // three in a row = 1.0
    { concept: "meios", history: [] }, // never = 0
  ], "2026-11-10");
  assertEquals(r.total, 4);
  assertEquals(r.practiced, 3);
  assertEquals(r.ready_pct, Math.round(((0 + 0.5 + 1 + 0) / 4) * 100));
  assertEquals(r.weakest.map((w) => w.concept), ["cellandning", "meios", "fotosyntes"]);
  assertEquals(r.weakest[0].why, "fel senast");
  assertEquals(r.weakest[1].why, "inte övat än");
  // overdue: right twice, review day passed long ago = 0.75 * 0.8
  const o = readinessOf([{ concept: "x", history: [{ date: "2026-10-01", ok: true }, { date: "2026-10-02", ok: true }] }], "2026-11-10");
  assertEquals(o.ready_pct, 60);
  assertEquals(readinessOf([], "2026-11-10").ready_pct, null);
});

Deno.test("K31/K33 in /study-plan: streak, notification and readiness come back with the plan", async () => {
  const h = createPlanHandler({ authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }) });
  const r = await h(new Request("http://x/study-plan", {
    method: "POST",
    body: JSON.stringify({
      today: "2026-11-10",
      quiz_days: ["2026-11-08", "2026-11-09"],
      exams: [{ name: "Biologiprovet", date: "2026-11-13", concepts: [{ concept: "cellandning", history: [{ date: "2026-11-09", ok: false }] }] }],
    }),
  }));
  const j = await r.json();
  assertEquals(j.streak.current, 2);
  assertEquals(j.notification.title, "3 dagar kvar till Biologiprovet");
  assert(j.notification.body.includes("cellandning"));
  assertEquals(j.exams[0].readiness.ready_pct, 0);
  const s = await h(new Request("http://x/study-plan", { method: "POST", body: JSON.stringify({ today: "2026-11-10", quiz_days: ["2026-11-10"] }) }));
  assertEquals((await s.json()).streak.done_today, true, "streak alone, without exams");
});
