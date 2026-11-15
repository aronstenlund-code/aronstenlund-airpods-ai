// O70 (Oscar moln, 2026-11-15): hållout-fall för K77 (D197, D116), skrivna utan att titta på Kevins testfall först.
// Kör: cd backend && deno test --no-lock --no-check --allow-read ../scripts/qa/o70_k77_test.ts
// Rena funktioner ur drill/analysis.ts: vad som hamnar i Arons analys (qa_log) när en vanlig användare sparar,
// ändrar och spelar. Testkonton, kopior och läslägets text täcks av Kevins handler_test (körs också i O70).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { pressStats, saveRows, statsRow } from "../../backend/supabase/functions/drill/analysis.ts";

const A = { id: "a", question: "Vad är fotosyntes?", short: "Växter gör socker av ljus.", long: "Växter gör socker av ljus. Det sker i bladen." };
const B = { id: "b", question: "Var sker cellandning?", short: "I mitokondrierna.", long: "I mitokondrierna. Där blir socker energi." };

Deno.test("O70 1: bara frågan ändrad ger Fråga före/efter och ingen svarsrad", () => {
  const r = saveRows("questions", [A, B], [{ ...A, question: "Vad gör fotosyntesen?" }, B]);
  assertEquals(r.length, 1);
  assertEquals(r[0].persona, "ändrad");
  assert(r[0].answer.includes("Fråga före: Vad är fotosyntes?") && r[0].answer.includes("Fråga efter: Vad gör fotosyntesen?"), r[0].answer);
  assert(!r[0].answer.includes("Svar före"), r[0].answer);
});

Deno.test("O70 2: bara ordningen ändrad loggar inget", () => {
  assertEquals(saveRows("questions", [A, B], [B, A]).length, 0);
});

Deno.test("O70 3: en ny fråga bland gamla loggas som sparad, de gamla inte", () => {
  const C = { question: "Vad är klorofyll?", short: "Ett grönt ämne.", long: "Ett grönt ämne. Det fångar ljus." };
  const r = saveRows("questions", [A, B], [A, B, C]);
  assertEquals(r.map((x) => [x.persona, x.question]), [["sparad", C.question]]);
  assertEquals(r[0].answer, C.long);
});

Deno.test("O70 4: en borttagen fråga ger ingen rad (obs i rapporten)", () => {
  // K77 loggar bara nya och ändrade frågor; att eleven tog bort en fråga syns inte i analysen
  assertEquals(saveRows("questions", [A, B], [A]).length, 0);
});

Deno.test("O70 5: läslägets text loggas aldrig, inte heller när den ändras", () => {
  const p = { id: "p", question: "", short: "", long: "Fotosyntesen sker i kloroplasterna.", part: "para" };
  assertEquals(saveRows("text", [], [p]).length, 0);
  assertEquals(saveRows("text", [p], [{ ...p, long: "Ändrad text om glukos." }]).length, 0);
});

Deno.test("O70 6: siffror maskas också i före/efter och i frågan", () => {
  const old = { ...A, long: "Ring 070-123 45 67 eller skriv 19990101-1234." };
  const r = saveRows("questions", [old], [{ ...A, question: "Vad är 19990101-1234?", long: "Kortet 4111 1111 1111 1111." }]);
  const all = r.map((x) => x.question + x.answer).join(" ");
  assert(!/1234|4111 1111|070-123/.test(all), all);
});

Deno.test("O70 7: långa texter kapas under tabellens gränser (fråga 1 000, svar 6 000)", () => {
  const long = "ord ".repeat(3000);
  const r = saveRows("questions", [{ ...A, long }], [{ ...A, question: "x".repeat(2000), long: long + "slut" }]);
  assert(r[0].question.length <= 1000 && r[0].answer.length <= 6000, `${r[0].question.length} ${r[0].answer.length}`);
});

Deno.test("O70 8: tryck för en text: ämnet och siffrorna, aldrig textens meningar", () => {
  const row = statsRow("text", "Historia", { "1": 3, "2": 5, "3": 1 }, [{ question: "Hemlig mening ur materialet", presses: { "1": 1, "2": 1, "3": 1 } }], 7);
  assertEquals([row.mode, row.persona, row.question], ["read", "tryck", "Historia"]);
  assert(!row.answer.includes("Hemlig mening"), row.answer);
  assert(row.answer.includes("1 tryck: 3, 2 tryck: 5, 3 tryck: 1") && row.answer.includes("Minuter: 7"), row.answer);
});

Deno.test("O70 9: tryck per fråga i ett frågeprov, och ogiltiga tryck nekas", () => {
  const row = statsRow("questions", "", { "1": 1, "2": 0, "3": 0 }, [{ question: B.question, presses: { "1": 1, "2": 0, "3": 0 } }], null);
  assertEquals(row.question, "(inget ämne)");
  assert(row.answer.includes(`${B.question}: 1 tryck: 1`) && !row.answer.includes("Minuter"), row.answer);
  for (const bad of [null, {}, { "1": 1, "2": 2 }, { "1": -1, "2": 0, "3": 0 }, { "1": 1.5, "2": 0, "3": 0 }, { "1": "3", "2": 0, "3": 0 }, { "1": 100_001, "2": 0, "3": 0 }]) {
    assertEquals(pressStats(bad), null, JSON.stringify(bad));
  }
});
