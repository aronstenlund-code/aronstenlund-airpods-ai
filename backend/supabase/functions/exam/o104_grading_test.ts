// O104 (Oscar, the exam flow through K122): G-a "en"/"ett" in a facit without digits was read as the number 1, so a
// fully right answer lost its answer point; G-b K1.7's "Visa hur du räknar" replaced the feedback for a wrong year.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { correctPoints, numericCheck } from "./handler.ts";

Deno.test("O104 G-a: the article en/ett in a worded facit is not a number; a real number (also in words) still is", () => {
  assertEquals(numericCheck("När en syra och en bas blandas bildas vatten och ett salt.", "syra och bas blandas och då bildas vatten och salt"), null);
  const task = { no: "1", text: "Vad bildas när en syra och en bas blandas?", points: { E: 1, C: 1, A: 0 }, answer: "När en syra och en bas blandas bildas vatten och ett salt.", assessment: "+E nämner vatten, +C korrekt svar" };
  const n = numericCheck(task.answer, "vatten och ett salt bildas");
  assertEquals(correctPoints(task, "vatten och ett salt bildas", { E: 1, C: 1, A: 0 }, n), { E: 1, C: 1, A: 0 });
  assertEquals(numericCheck("126 kr", "det blir 126 kronor")?.equal, true);
  assertEquals(numericCheck("Svaret är ett", "ett")?.expected, 1, "a short facit that IS the number");
  assertEquals(numericCheck("Det finns tjugofem elever i klassen.", "25")?.equal, true);
});

Deno.test("O104 G-b: 'Visa hur du räknar' only for a calculation task, never for a year or a fact", async () => {
  const { isCalculationTask } = await import("./handler.ts");
  const t = (text: string, assessment = "") => ({ no: "1", text, points: { E: 1, C: 0, A: 0 }, answer: "", assessment });
  assertEquals(isCalculationTask(t("Vilket år blev Sverige ett arvrike?")), false);
  assertEquals(isCalculationTask(t("När föll Berlinmuren?")), false);
  assertEquals(isCalculationTask(t("Hur många ben har en spindel?")), false);
  assertEquals(isCalculationTask(t("Beräkna 15 % av 840 kr.")), true);
  assertEquals(isCalculationTask(t("Lös ekvationen 3x + 4 = 19.")), true);
  assertEquals(isCalculationTask(t("Hur mycket kostar fem pennor om tre kostar 27 kr?")), true);
  assertEquals(isCalculationTask(t("Ange svaret.", "+E korrekt metod, +C korrekt svar")), true);
});

Deno.test("O104 G-c/G-d: an English task is graded and hinted in English; the practice rule says it replaces the feedback rule", async () => {
  const { createExamHandler, PRACTICE_GRADE_RULE, SYSTEM_PROMPT_EXAM_GRADE } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const seen: { system: string; user: string }[] = [];
  const h = createExamHandler({
    authenticate: () => Promise.resolve({ id: "u-o104", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: (r) => (seen.push(r), (async function* () { yield { type: "text" as const, text: '{"points":{"E":1,"C":0,"A":0},"feedback":"Good."}' }; })()) },
  });
  const post = (b: unknown) => h(new Request("http://x/exam", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.5" }, body: JSON.stringify(b) }));
  const en = { no: "1", text: "Explain why the Enlightenment ideas spread so quickly in Europe.", points: { E: 1, C: 0, A: 0 }, answer: "Printing and coffee houses spread the ideas.", assessment: "+E names one reason" };
  await post({ action: "grade", task: en, answer: "because of printing presses" });
  assertEquals(seen[0].user.includes("<language>en</language>"), true, seen[0].user);
  await post({ action: "hint", task: en, level: 1 });
  assertEquals(seen[1].user.includes("<language>en</language>"), true);
  const sv = { ...en, text: "Förklara varför upplysningens idéer spreds så snabbt i Europa.", answer: "Boktryckarkonsten och kaffehusen." };
  await post({ action: "grade", task: sv, answer: "på grund av boktryckarkonsten" });
  assertEquals(seen[2].user.includes("<language>"), false, "Swedish: as before");
  assertEquals(/language of <language>/.test(SYSTEM_PROMPT_EXAM_GRADE), true);
  assertEquals(/replaces the feedback rule/.test(PRACTICE_GRADE_RULE), true);
});
