import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { buildDirectUserMessage, SYSTEM_PROMPT_DIRECT, SYSTEM_PROMPT_DIRECT_TUTOR } from "./prompt.ts";
import { validateAnswerRequest } from "./validate.ts";

const PROFILE = "Prov i Biologi fredag 13 november 2026 (om 5 dagar). Årskurs: Åk 7. Kontrollfrågor: Ja–nej-frågor (svara med rösten eller nicka). Förklaringar: korta förklaringar.";

Deno.test("D83 the Provläge profile goes in the user message after the cached system prompt", () => {
  const req = validateAnswerRequest({
    fragment: "vad är fotosyntes", mode: "tutor", language: "sv", persona: "tutor", persona_setup: PROFILE, context: {},
  });
  const u = buildDirectUserMessage(req, null, {});
  assertStringIncludes(u, `<profile>${PROFILE}</profile>`);
  assert(!SYSTEM_PROMPT_DIRECT_TUTOR.includes("Åk 7."), "the system prompt stays static");
  assertStringIncludes(u, "top grade A in exactly that grade and course");
  assertStringIncludes(u, "answered with one word or a nod");
  assert(!SYSTEM_PROMPT_DIRECT_TUTOR.includes("<profile> (optional) is"), "the rule is not in the cached prompt");
  // no profile: nothing added; other modes never get it
  const none = buildDirectUserMessage(validateAnswerRequest({ fragment: "x", mode: "tutor", language: "sv", context: {} }), null, {});
  assert(!none.includes("<profile>") && !none.includes("<profile_rules>"));
  const text = buildDirectUserMessage(
    validateAnswerRequest({ fragment: "x", mode: "text", language: "sv", persona: "tutor", persona_setup: PROFILE, context: {} }),
    null,
    {},
  );
  assert(!text.includes("<profile>"));
  assertEquals(SYSTEM_PROMPT_DIRECT.includes("<profile> (optional) is the student's"), false);
});
