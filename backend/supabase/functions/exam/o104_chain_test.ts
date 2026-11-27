// O104 (Oscar, the exam chain through K122): E1 the trim removed the only cause/definition questions and isRecall
// knew only Swedish; E3 dropNearSame took "Varför …" and "Hur mycket …" about the same thing for the same question.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { isRecall, trimQuestions } from "./drill.ts";

Deno.test("O104 E1: the trim keeps the only why-question and the only definition; plain recall goes first (sv and en)", () => {
  const sv = ["När upptäcktes cellen?", "Vem såg cellen först?", "Vad är cellkärnan?", "Varför behöver cellen mitokondrier?"];
  const kept = trimQuestions(sv, 2);
  assert(kept.includes("Varför behöver cellen mitokondrier?") && kept.includes("Vad är cellkärnan?"), JSON.stringify(kept));
  const en = ["When did the Enlightenment start?", "Who wrote The Social Contract?", "Which ideas spread during the Enlightenment?", "Why did the ideas spread so fast?"];
  const k2 = trimQuestions(en, 2);
  assert(!k2.includes("When did the Enlightenment start?") && k2.includes("Why did the ideas spread so fast?"), JSON.stringify(k2));
  assertEquals(isRecall("When did the war end?"), true);
  assertEquals(isRecall("Who invented the telephone?"), true);
  assertEquals(isRecall("Vad är fotosyntes?"), false, "a definition is not plain recall");
  assertEquals(isRecall("Vad heter Norges huvudstad?"), true);
});

Deno.test("O104 E3: 'Varför …' and 'Hur mycket …' about the same thing are different questions; a reworded same ask still goes", async () => {
  const { dropNearSame } = await import("./drill.ts");
  const r = dropNearSame(["Hur mycket har jordens medeltemperatur stigit?", "Varför har jordens medeltemperatur stigit?"], [0, 0]);
  assertEquals(r.dropped, 0, JSON.stringify(r.questions));
  const same = dropNearSame(["Varför har jordens medeltemperatur stigit?", "Varför har medeltemperaturen på jorden stigit?"], [0, 0]);
  assertEquals(same.dropped, 1);
});

Deno.test("O104 E2: a rewrite the final check proposes but the code rejects never lends its sources to the old question", async () => {
  const { finalCheck, DEFAULT_DRILL_CONFIG } = await import("./drill.ts");
  const qs = ["Vilket land ligger Zorbia vid?", "Vad exporterar Zorbia mest?", "Hur styrs Zorbia?"];
  // q2's rewrite is far longer than the original + 4 words (rejected); its sources are q0's sentence
  const reply = { questions: [{ i: 1, q: "Vilken vara exporterar landet Zorbia mest av till sina grannländer i hela regionen idag?" }], sources: [{ i: 0, s: [1] }, { i: 1, s: [1] }, { i: 2, s: [3] }] };
  const provider = { name: "f", model: "f", stream: () => (async function* () { yield { type: "text" as const, text: JSON.stringify(reply) }; })() };
  const mat = "Zorbia ligger vid havet. Landet exporterar mest fisk. Zorbia styrs av ett parlament.";
  const r = await finalCheck(provider, DEFAULT_DRILL_CONFIG, qs, [0, 0, 0], mat);
  assertEquals(r.questions, qs, "nothing dropped on the rejected rewrite's sources");
});
