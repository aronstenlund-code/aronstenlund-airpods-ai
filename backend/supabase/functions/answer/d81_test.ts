import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { validateAnswerRequest } from "./validate.ts";
import { formatConversation } from "./rizz.ts";
import { buildDirectUserMessage } from "./prompt.ts";
import { SYSTEM_PROMPT_INTERVIEW } from "./personas.ts";

const social = (transcript: unknown[], extra: Record<string, unknown> = {}) =>
  validateAnswerRequest({
    fragment: "vem av er vill ha pizza",
    mode: "tutor",
    language: "sv",
    persona: "social",
    social: { style: "social", trigger: "other_spoke", transcript, ...extra },
    context: {},
  });

Deno.test("D81 speaker labels: 'Du' is the user, 'Talare N' keeps its name; old user/other still works", () => {
  const r = social([
    { speaker: "Talare 1", text: "Jag tränar inför ett lopp." },
    { speaker: "Du", text: "Vilket lopp?" },
    { speaker: "other", label: "Talare 2", text: "Jag har aldrig sprungit." },
  ], { speaker: "Talare 2" });
  assertEquals(r.social!.transcript.map((l) => l.speaker), ["other", "user", "other"]);
  const conv = formatConversation(r);
  assertStringIncludes(conv, "Talare 1: Jag tränar inför ett lopp.");
  assertStringIncludes(conv, "Jag: Vilket lopp?");
  assertStringIncludes(conv, "Talare 2: vem av er vill ha pizza");
  const old = formatConversation(social([{ speaker: "other", text: "Hej" }, { speaker: "user", text: "Hej hej" }]));
  assertStringIncludes(old, "Den andra: Hej");
});

Deno.test("D81 interrupted answer: the said part goes along as 'never repeat'", () => {
  const req = validateAnswerRequest({
    fragment: "fortsätt",
    mode: "tutor",
    language: "sv",
    context: { recent_qa: [{ q: "vad är fotosyntes", a: "Fotosyntes är när växter", interrupted: true }] },
  });
  assertEquals(req.context.recent_qa[0].interrupted, true);
  const u = buildDirectUserMessage(req, null, {});
  assertStringIncludes(u, '<interrupted>Your last answer was stopped by the student after these words: "Fotosyntes är när växter"');
  const plain = buildDirectUserMessage(
    validateAnswerRequest({ fragment: "x", mode: "tutor", language: "sv", context: { recent_qa: [{ q: "a", a: "b" }] } }),
    null,
    {},
  );
  assert(!plain.includes("<interrupted>"));
});

Deno.test("D81 interview: job ad + CV up to 2 000 characters, CV facts are the user's", () => {
  const setup = "Jobbannons: Kassabiträde helger. CV: " + "Gymnasiet, Ekonomiprogrammet 2023–2026. ".repeat(40);
  const r = validateAnswerRequest({
    fragment: "berätta om dig själv", mode: "tutor", language: "sv", persona: "interview",
    persona_setup: setup.slice(0, 2000), context: {},
  });
  assert(r.personaSetup.length > 1500, String(r.personaSetup.length)); // above the old 1 500 limit
  assertStringIncludes(SYSTEM_PROMPT_INTERVIEW, "the CV is the user's own background");
});

Deno.test("D81 a suggestion that says a speaker label aloud is never shown", async () => {
  const { pickSuggestions } = await import("./rizz.ts");
  const raw = "1|x|Jag föreslår något där Talare ett får sitta ner.\n2|y|Konsert på lördag låter perfekt, vilken artist?\nTOP: 1,2";
  const picked = pickSuggestions(raw, true, undefined, 1);
  assert(picked.every((p: string) => !/talare/i.test(p)), JSON.stringify(picked));
});
