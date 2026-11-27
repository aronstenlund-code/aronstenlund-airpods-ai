// O109 (Oscar, every mode under Fler lägen through K122).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { CRISIS_OTHER, CRISIS_SELF } from "./crisis.ts";

async function ask(body: Record<string, unknown>) {
  const { createHandler, DEFAULT_CONFIG } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-o109", isAnonymous: false }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: () => (async function* () { yield { type: "text" as const, text: "nej" }; })() },
    recordUsage: () => {}, config: DEFAULT_CONFIG,
  });
  const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.11" }, body: JSON.stringify({ language: "sv", context: {}, ...body }) }));
  return await res.text();
}

Deno.test("O109-1: in Intervju the user's own answer with crisis words gets the answer for the user, the interviewer's question the one about someone else", async () => {
  const own = await ask({ fragment: "jag orkar inte leva längre", mode: "push_to_talk", persona: "interview", persona_setup: "Sommarjobb som butiksbiträde", turn: "user_answer" });
  assertStringIncludes(own, CRISIS_SELF.slice(0, 30));
  assert(!own.includes(CRISIS_OTHER.slice(0, 30)), "IN6: the user's own words are not about someone else");
  const theirs = await ask({ fragment: "jag orkar inte leva längre", mode: "push_to_talk", persona: "interview", persona_setup: "Sommarjobb som butiksbiträde", turn: "question" });
  assertStringIncludes(theirs, CRISIS_OTHER.slice(0, 30));
});

Deno.test("O109-5: 1177 as the web address and after 'Hitta vård' is 'elva sjuttiosju' (D46), the year 1177 is not", async () => {
  const { AnswerPost } = await import("./speech.ts");
  const say = (t: string) => {
    const p = new AnswerPost({ heard: "x", language: "sv", previousAnswers: [] } as never);
    return (p.push(t) + p.finish()).trim();
  };
  assertEquals(say("Läs mer på 1177.se."), "Läs mer på elva sjuttiosju punkt se.");
  assertStringIncludes(say("Sök under Hitta vård på 1177 punkt se, på mottagningens namn."), "Hitta vård på elva sjuttiosju punkt se");
  assertStringIncludes(say("Ring 1177 om du är orolig."), "Ring elva sjuttiosju");
  assertStringIncludes(say("År 1177 var Sverige ett annat land."), "elvahundrasjuttiosju");
});

Deno.test("O109-4: the prompt says that a line over 10 words is dropped and the next one shown", async () => {
  const { SYSTEM_PROMPT_RIZZ, SYSTEM_PROMPT_RIZZ_FLIRT } = await import("./rizz.ts");
  for (const p of [SYSTEM_PROMPT_RIZZ, SYSTEM_PROMPT_RIZZ_FLIRT]) assertStringIncludes(p, "a longer line is never shown, the next one is");
});

Deno.test("O109-3: grief, fear or a serious moment gets a warm line, not a joke, in both styles", async () => {
  const { SYSTEM_PROMPT_RIZZ, SYSTEM_PROMPT_RIZZ_FLIRT } = await import("./rizz.ts");
  for (const p of [SYSTEM_PROMPT_RIZZ, SYSTEM_PROMPT_RIZZ_FLIRT]) {
    assert(/sad, grieving, scared or hurt[^.]*no joke and no flirting/.test(p), "warm line rule");
    assert(/An insult meant seriously gets a calm, friendly line/.test(p));
  }
});

Deno.test("O109-6: in Provläge a new question after a check question (no quiz_key) is not a 'yes' to a confirmation", async () => {
  const { createHandler, DEFAULT_CONFIG } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const seen: string[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-pv7", isAnonymous: false }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: (r) => (seen.push(r.user), (async function* () { yield { type: "text" as const, text: "Det vet jag inte." }; })()) },
    recordUsage: () => {}, config: DEFAULT_CONFIG,
  });
  const post = (fragment: string) => h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.12" }, body: JSON.stringify({ fragment, mode: "tutor", language: "sv", goals: "Biologi 1: cellen.", context: { recent_qa: [{ q: "förhör mig på cellen", a: "Vilket cellorgan gör energi åt cellen?" }] } }) })).then((r) => r.text());
  await post("vad blir det för väder imorgon");
  assertStringIncludes(seen.at(-1)!, "<last_assistant_turn>answer</last_assistant_turn>");
  await post("mitokondrien"); // the reply to the check question is still graded (O104 T-a)
  assertStringIncludes(seen.at(-1)!, "<last_assistant_turn>check_question</last_assistant_turn>");
});

Deno.test("O109-7: the study examples follow the digits rule, the summary follows the answer's language, an opener with nothing given uses the moment", async () => {
  const { TUTOR_EXAMPLES, SUMMARY_RULE } = await import("./prompt.ts");
  const { SYSTEM_PROMPT_RIZZ } = await import("./rizz.ts");
  assert(!/Två, tre, fem och sju|fjorton rader/.test(TUTOR_EXAMPLES));
  assertStringIncludes(TUTOR_EXAMPLES, "2, 3, 5 och 7 är primtal");
  assertStringIncludes(SUMMARY_RULE, "in the answer's language");
  assertStringIncludes(SYSTEM_PROMPT_RIZZ, "with nothing given: what you both see or do now");
});
