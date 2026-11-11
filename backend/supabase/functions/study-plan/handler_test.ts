import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { createPlanHandler, dueConcepts, planDays, promptFor, schedule, whenSaid } from "./handler.ts";

Deno.test("K17 spaced repetition: wrong = back tomorrow; right moves on 1, 3, 7 days", () => {
  assertEquals(schedule([{ date: "2026-11-09", ok: false }])!.next, "2026-11-10");
  assertEquals(schedule([{ date: "2026-11-09", ok: true }])!.next, "2026-11-12", "box 1 = 3 days");
  assertEquals(schedule([{ date: "2026-11-05", ok: true }, { date: "2026-11-08", ok: true }])!.next, "2026-11-15", "box 2 = 7 days");
  assertEquals(schedule([{ date: "2026-11-05", ok: true }, { date: "2026-11-08", ok: false }])!.next, "2026-11-09", "a miss resets");
});

Deno.test("K17 today's concepts and the spoken prompt ('I går missade du cellandning')", () => {
  const c = [
    { concept: "cellandning", history: [{ date: "2026-11-09", ok: false }] },
    { concept: "fotosyntes", history: [{ date: "2026-11-09", ok: true }] },
    { concept: "osmos", history: [{ date: "2026-11-07", ok: true }] },
  ];
  const due = dueConcepts(c, "2026-11-10");
  assertEquals(due.map((x) => x.concept), ["cellandning", "osmos"]);
  assertEquals(promptFor(due, "2026-11-10"), "I går missade du cellandning. Ska vi ta det nu?");
  assertEquals(promptFor([], "2026-11-10"), null);
});

Deno.test("K17 a daily ~10 minute plan up to the day before the exam, missed first, a mix the last day", () => {
  const c = [
    { concept: "cellandning", history: [{ date: "2026-11-09", ok: false }, { date: "2026-11-08", ok: false }] },
    { concept: "fotosyntes", history: [{ date: "2026-11-09", ok: true }] },
    { concept: "mitos", history: [{ date: "2026-11-09", ok: false }] },
    { concept: "osmos", history: [] },
  ];
  const p = planDays(c, "2026-11-10", "2026-11-13");
  assertEquals(p.map((d) => d.date), ["2026-11-10", "2026-11-11", "2026-11-12"]);
  assertEquals(p[0].concepts[0], "cellandning");
  assert(p.every((d) => d.minutes >= 10 && d.minutes <= 15 && d.concepts.length >= 1));
  assert(p[2].note.includes("dagen före provet"));
  const all = new Set(p.flatMap((d) => d.concepts));
  assert(all.has("osmos") && all.has("mitos"), "every concept comes back");
});

Deno.test("K17 endpoint: code only, validates the input", async () => {
  const h = createPlanHandler({ authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }) });
  const r = await h(new Request("http://x/study-plan", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ today: "2026-11-10", exams: [{ name: "Biologiprovet", date: "2026-11-13", concepts: [{ concept: "cellandning", history: [{ date: "2026-11-09", ok: false }] }] }] }),
  }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.exams[0].days_left, 3);
  assertEquals(j.exams[0].prompt, "I går missade du cellandning. Ska vi ta det nu?");
  assertEquals((await h(new Request("http://x/study-plan", { method: "POST", body: "{}" }))).status, 400);
});

Deno.test("O13 del 2: every day 3 concepts, the real day before the exam 4; a far exam has no 'dagen före'; due concepts on their day", () => {
  const mk = (c: string, hist: [string, boolean][]) => ({ concept: c, history: hist.map(([date, ok]) => ({ date, ok })) });
  const cs = ["RNA", "DNA", "protein", "mitos", "meios"].map((c) => mk(c, [["2026-11-10", false]]));
  const p = planDays(cs, "2026-11-11", "2026-11-21");
  assertEquals(p.length, 10);
  for (const d of p.slice(0, -1)) assertEquals(d.concepts.length, 3, d.date);
  assertEquals(p.at(-1)!.date, "2026-11-20");
  assertEquals(p.at(-1)!.concepts.length, 4);
  assert(p.at(-1)!.note.includes("dagen före provet"));
  const far = planDays(cs, "2026-11-11", "2026-12-01");
  assertEquals(far.length, 14);
  assert(!far.some((d) => d.note.includes("dagen före provet")), "the exam is 20 days away");
  // meios right twice (box 2): it must be in the plan on the day it is due
  const withDue = [...cs.slice(0, 4), mk("meios", [["2026-11-09", true], ["2026-11-10", true]])];
  const next = schedule(withDue[4].history)!.next;
  const day = planDays(withDue, "2026-11-11", "2026-11-30").find((d) => d.date === next)!;
  assert(day.concepts.includes("meios"), `${next}: ${day.concepts}`);
  assertEquals(whenSaid("2026-10-21", "2026-11-11"), "Den 21 oktober");
  assertEquals(whenSaid("2026-10-27", "2026-11-11"), "För två veckor sedan");
  assertEquals(whenSaid("2026-11-02", "2026-11-11"), "Förra veckan");
});
