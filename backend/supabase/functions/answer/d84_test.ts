import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { needsText, TEXT_DOMAINS, textTools } from "./web.ts";
import { buildDirectUserMessage, SYSTEM_PROMPT_DIRECT_TUTOR } from "./prompt.ts";
import { validateAnswerRequest } from "./validate.ts";

Deno.test("D84 text requests are recognised; ordinary questions are not", () => {
  for (const f of ["sjung en snapsvisa", "kan du sjunga helan går", "citera Strindberg om kärlek", "vad är texten till du gamla du fria", "hur går visan", "vad sa Churchill om krig"]) {
    assert(needsText(f), f);
  }
  for (const f of ["vad är fotosyntes", "när föddes Strindberg", "vilken sång vann melodifestivalen"]) assert(!needsText(f), f);
  const t = textTools()[0] as { allowed_domains: string[] };
  assertEquals(t.allowed_domains, TEXT_DOMAINS);
  assert(TEXT_DOMAINS.includes("runeberg.org"));
});

Deno.test("D84 subject-led interpretation travels with the profile; prep_terms up to 50", () => {
  const req = validateAnswerRequest({
    fragment: "syntes", mode: "tutor", language: "sv", persona: "tutor",
    persona_setup: "Årskurs: Åk 9. Ämne: Biologi.",
    context: { prep_terms: Array.from({ length: 50 }, (_, i) => `term${i}`) },
  });
  assertEquals(req.context.prep_terms.length, 50);
  const u = buildDirectUserMessage(req, null, {});
  assertStringIncludes(u, "Subject first (D84)");
  assert(!SYSTEM_PROMPT_DIRECT_TUTOR.includes("Subject first"), "not in the cached prompt");
});
