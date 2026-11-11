import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { commandTask } from "./commands.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { selfAnswer } from "./self.ts";
import { afterNumbers, beforeNumbers } from "./speechsym.ts";
import { numbersToSpeech } from "./svnum.ts";
import { needsWeb } from "./web.ts";

const spoken = (t: string) => afterNumbers(numbersToSpeech(beforeNumbers(t)));

Deno.test("K20 kings' numbers are ordinals, also as digits or cardinal words", () => {
  assertEquals(spoken("Erik 14 var kung."), "Erik den fjortonde var kung.");
  assertEquals(spoken("Johan den tre gifte sig."), "Johan den tredje gifte sig.");
  assertEquals(spoken("Erik den fjorton var kung."), "Erik den fjortonde var kung.");
  assertEquals(spoken("Karl XII dog."), "Karl den tolfte dog.");
  assertEquals(spoken("Karl är 12 år."), "Karl är tolv år.");
});

Deno.test("K20 questions about Lumen: honest (O16: ElevenLabs may keep the audio)", () => {
  assert(selfAnswer("Lumen är du en robot")!.includes("AI-assistent"));
  assert(selfAnswer("lyssnar du hela tiden?")!.includes("lyssnar bara när du har startat den"));
  const save = selfAnswer("sparar du mina frågor")!;
  assert(save.includes("Earmind sparar inget ljud") && save.includes("Earminds server till en AI-modell") && save.includes("på den här telefonen"));
  assert(selfAnswer("spelar du in det här")!.includes("Earmind sparar inget ljud"));
  for (const t of ["vad är en robot", "lyssnar du på musik", "sparar du pengar", "hur fungerar en AI"]) assertEquals(selfAnswer(t), null, t);
});

Deno.test("K20 'jag vet inte ens vad jag ska fråga' starts the student; a hard question follows the profile's subject", () => {
  assertEquals(commandTask("jag vet inte ens vad jag ska fråga", "study")?.task, "get_started");
  assertEquals(commandTask("var ska jag börja", "study")?.task, "get_started");
  assert(commandTask("ge mig en svår fråga", "study")!.rule.includes("the subject and exam in <profile>"));
});

Deno.test("K20 results and weather search", () => {
  for (const f of ["hur gick El Clásico", "vem vann matchen igår", "hur blir vädret i helgen", "regnar det i morgon", "vem är statsminister"]) assert(needsWeb(f)?.search, f);
  assertEquals(needsWeb("vad blev det för betyg"), null);
});

Deno.test("K20 a question about Lumen is answered in code in Auto too, no model call", async () => {
  const seen: LLMRequest[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k20", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "s", stream: (r) => { seen.push(r); return (async function* (): AsyncGenerator<LLMChunk> {})(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment: "Lyssnar du hela tiden?", mode: "auto", language: "sv", context: {} }) }));
  const t = await res.text();
  assert(t.includes("lyssnar bara när du har startat den"), t.slice(0, 300));
  assertEquals(seen.length, 0);
});
