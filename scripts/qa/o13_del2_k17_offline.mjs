// Oscar QA, O13 del 2: K17 spaced repetition and the plan up to the exam, offline with simulated time
// (backend/supabase/functions/study-plan/handler.ts). Independent of handler_test.ts. 0 USD.
//   node --experimental-strip-types --no-warnings scripts/qa/o13_del2_k17_offline.mjs > reports/qa/data/<stamp>-o13d2.json
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
// handler.ts imports auth.ts (npm:), so load only its pure part (everything before `function clean`) as a temp module
const src = readFileSync(new URL("../../backend/supabase/functions/study-plan/handler.ts", import.meta.url), "utf8");
const pure = src.slice(0, src.indexOf("function clean(")).replace(/^import .*$/gm, "");
if (!/export function planDays/.test(pure)) throw new Error("study-plan/handler.ts changed shape: update o13_del2_k17_offline.mjs");
const tmp = join(mkdtempSync(join(tmpdir(), "o13d2-")), "plan.ts");
writeFileSync(tmp, pure);
const { dueConcepts, planDays, promptFor, schedule, whenSaid } = await import(tmp);

const DAY = 86_400_000;
const add = (d, n) => new Date(Date.parse(d + "T00:00:00Z") + n * DAY).toISOString().slice(0, 10);
const rows = [];
const check = (name, ok, got) => rows.push({ name, ok: !!ok, got });

// 1. A simulated student, 21 days: the concept is quizzed exactly on the days it is due, answers as scripted.
//    Leitner 1/3/7/14: wrong -> tomorrow, right -> up a box.
{
  const answers = [false, true, true, false, true, true, true]; // what the student answers each time it comes up
  const hist = [{ date: "2026-11-01", ok: false }];
  const shown = ["2026-11-01"];
  let i = 1;
  for (let d = 1; d <= 40 && i < answers.length; d++) {
    const today = add("2026-11-01", d);
    const due = dueConcepts([{ concept: "cellandning", history: hist }], today).map((x) => x.concept);
    if (due.includes("cellandning")) { hist.push({ date: today, ok: answers[i++] }); shown.push(today); }
  }
  const gaps = shown.slice(1).map((d, k) => Math.round((Date.parse(d) - Date.parse(shown[k])) / DAY));
  // expected gaps: after wrong 1, after right(box1) 3, after right(box2) 7, after wrong 1, right 3, right 7
  check("simulated student comes back after 1,3,7,1,3,7 days", JSON.stringify(gaps) === "[1,3,7,1,3,7]", { shown, gaps });
}
// 2. Not due before its day, due on it, still due (not lost) days later
{
  const h = [{ date: "2026-11-10", ok: true }]; // box 1 -> 3 days
  check("right answer: not due after 2 days", dueConcepts([{ concept: "x", history: h }], "2026-11-12").length === 0);
  check("right answer: due on day 3", dueConcepts([{ concept: "x", history: h }], "2026-11-13").length === 1);
  check("overdue stays due (10 days later)", dueConcepts([{ concept: "x", history: h }], "2026-11-20").length === 1);
}
// 3. Unsorted history and a bad date
{
  const s = schedule([{ date: "2026-11-09", ok: true }, { date: "2026-11-08", ok: false }, { date: "inte ett datum", ok: true }]);
  check("unsorted history sorted, bad date ignored (wrong then right = box 1, next +3)", s && s.box === 1 && s.next === "2026-11-12", s);
}
// 4. Prompt wording
{
  check("whenSaid yesterday", whenSaid("2026-11-10", "2026-11-11") === "I går", whenSaid("2026-11-10", "2026-11-11"));
  check("whenSaid Monday (9 nov 2026 is a Monday)", whenSaid("2026-11-09", "2026-11-13") === "I måndags", whenSaid("2026-11-09", "2026-11-13"));
  check("whenSaid 3 weeks ago is not 'Förra veckan'", whenSaid("2026-10-21", "2026-11-11") !== "Förra veckan", whenSaid("2026-10-21", "2026-11-11"));
  const p = promptFor(dueConcepts([{ concept: "cellandning", history: [{ date: "2026-11-10", ok: false }] },
    { concept: "fotosyntes", history: [{ date: "2026-11-10", ok: false }] }], "2026-11-11"), "2026-11-11");
  check("prompt two missed", p === "I går missade du cellandning och fotosyntes. Ska vi ta dem nu?", p);
}
// 5. The plan: does a concept come back on the day it is due (not only today)?
{
  const today = "2026-11-11", exam = "2026-11-21"; // 10 days
  const concepts = [
    { concept: "mitos", history: [{ date: "2026-11-10", ok: true }] },           // box1 -> due 11-13
    { concept: "meios", history: [{ date: "2026-11-09", ok: true }, { date: "2026-11-10", ok: true }] }, // box2 -> due 11-17
    { concept: "DNA", history: [{ date: "2026-11-10", ok: false }] },              // due today
    { concept: "RNA", history: [{ date: "2026-11-04", ok: false }, { date: "2026-11-05", ok: false }, { date: "2026-11-06", ok: false }] }, // weakest, due
    { concept: "protein", history: [{ date: "2026-11-10", ok: false }] },
  ];
  const plan = planDays(concepts, today, exam);
  const on = (date, c) => (plan.find((p) => p.date === date)?.concepts ?? []).includes(c);
  check("plan has one day per day up to the day before the exam", plan.length === 10 && plan.at(-1).date === "2026-11-20", plan.map((p) => p.date));
  check("due-today concepts first on day 0", on(today, "DNA") && on(today, "RNA"), plan[0]);
  check("mitos is in the plan on its due day 2026-11-13", on("2026-11-13", "mitos"), plan.find((p) => p.date === "2026-11-13"));
  check("meios is in the plan on its due day 2026-11-17", on("2026-11-17", "meios"), plan.find((p) => p.date === "2026-11-17"));
  check("every concept comes back at least once", concepts.every((c) => plan.some((p) => p.concepts.includes(c.concept))), plan.map((p) => p.concepts));
}
// 6. Exam more than 14 days away: the "day before the exam" note must be on the day before the exam
{
  const plan = planDays([{ concept: "a", history: [] }, { concept: "b", history: [] }], "2026-11-11", "2026-12-01"); // 20 days
  const last = plan.at(-1);
  check("exam in 20 days: the 'dagen före provet' day is 2026-11-30 (or no such note)",
    !last || !/dagen före provet/.test(last.note) || last.date === "2026-11-30", { days: plan.length, last });
}
// 7. Exam tomorrow, today, in the past; concept with empty history
{
  const c = [{ concept: "a", history: [{ date: "2026-11-10", ok: false }] }];
  const p1 = planDays(c, "2026-11-11", "2026-11-12");
  check("exam tomorrow: one 15-min mixed day today with the missed concept", p1.length === 1 && p1[0].minutes === 15 && p1[0].concepts.includes("a"), p1);
  check("exam today: no plan", planDays(c, "2026-11-11", "2026-11-11").length === 0);
  check("exam in the past: no plan", planDays(c, "2026-11-11", "2026-11-01").length === 0);
  check("never-quizzed concept is not 'due' (no history)", dueConcepts([{ concept: "z", history: [] }], "2026-11-11").length === 0);
}
const ok = rows.filter((r) => r.ok).length;
console.log(JSON.stringify({ ok: `${ok}/${rows.length}`, fails: rows.filter((r) => !r.ok), rows }, null, 1));
