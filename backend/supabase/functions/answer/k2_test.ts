import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";
import { joinedSyllables } from "./prompt.ts";
import { isReasoningMeta } from "./speech.ts";

class Say implements LLMProvider {
  readonly name = "say";
  readonly model = "say-1";
  calls: LLMRequest[] = [];
  constructor(private readonly text: string) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.text };
    yield { type: "usage", inputTokens: 10, outputTokens: 5 };
  }
}
const run = async (text: string, body: Record<string, unknown>) => {
  const p = new Say(text);
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: p,
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  const res = await h(new Request("http://x/answer", { method: "POST", body: JSON.stringify(body) }));
  const raw = await res.text();
  const spoken = [...raw.matchAll(/^event: delta\ndata: (.*)$/gm)].map((m) => JSON.parse(m[1]).text).join("");
  return { p, spoken };
};
const tutor = (setup: string, fragment = "riksdagen") => ({
  fragment, mode: "tutor", language: "sv", persona: "tutor", persona_setup: setup, context: {},
});
const ANSWER = "Riksdagen är Sveriges parlament. Den stiftar lagar och granskar regeringen. Vad skiljer riksdagen från regeringen?";

Deno.test("K2 split syllables are joined for the model (Oscar's empty answers)", () => {
  assertEquals(joinedSyllables("pyt a goras"), "pytagoras");
  assertEquals(joinedSyllables("par tes läran"), "partesläran");
  assertEquals(joinedSyllables("ri bo so mer"), "ribosomer");
  assertEquals(joinedSyllables("vad är mito kondri"), "mitokondri");
  assertEquals(joinedSyllables("kloro fyll"), "klorofyll");
  for (const s of ["och den tredje?", "ge ett exempel", "mitos", "vad är mitos", "förklara varför antibiotika inte hjälper", "jag vet inte riktigt vad du menar"]) {
    assertEquals(joinedSyllables(s), null, s);
  }
});

Deno.test("K2 <joined> goes with the profile only", async () => {
  const withProfile = await run("Pythagoras sats gäller rätvinkliga trianglar.", tutor("Årskurs: Åk 9. Ämne: Matematik.", "pyt a goras"));
  assertStringIncludes(withProfile.p.calls[0].user, "<joined>pytagoras</joined>");
  assertStringIncludes(withProfile.p.calls[0].user, "never [[TYST]] for it");
  const none = await run("Pythagoras sats.", { fragment: "pyt a goras", mode: "tutor", language: "sv", context: {} });
  assert(!none.p.calls[0].user.includes("<joined>"));
});

Deno.test("K2 no closing question unless the profile asks for check questions", async () => {
  const noLine = await run(ANSWER, tutor("Årskurs: Åk 9. Ämne: Samhällskunskap. Förklaringar: mellanlånga förklaringar."));
  assert(!noLine.spoken.includes("?"), noLine.spoken);
  assertStringIncludes(noLine.spoken, "granskar regeringen.");
  const inga = await run(ANSWER, tutor("Årskurs: Åk 9. Ämne: Samhällskunskap. Kontrollfrågor: Inga kontrollfrågor."));
  assert(!inga.spoken.includes("?"));
  const asked = await run(ANSWER, tutor("Årskurs: Åk 9. Ämne: Samhällskunskap. Kontrollfrågor: Korta frågor."));
  assertStringIncludes(asked.spoken, "Vad skiljer riksdagen från regeringen?");
  const noProfile = await run(ANSWER, { fragment: "riksdagen", mode: "tutor", language: "sv", context: {} });
  assertStringIncludes(noProfile.spoken, "?", "without a profile nothing changes");
});

Deno.test("K2 English reasoning about the fragment is never spoken", () => {
  for (
    const s of [
      'The fragment sounds like "present perfect", a core English tense.',
      "It sounds like you mean the present perfect.",
      "You probably mean present perfect.",
      "This word sounds like present perfect.",
      "I take it as present perfect.",
    ]
  ) assert(isReasoningMeta(s, "pre sent per fekt"), s);
  for (
    const s of [
      'Present perfect bildas med "have" eller "has" och perfektparticip.',
      '"I have lived here for five years" betyder att du fortfarande bor här.',
      "The present perfect links the past to the present.",
      "Your answer is right.",
    ]
  ) assert(!isReasoningMeta(s, "pre sent per fekt"), s);
});

Deno.test("K2 profile rules: words cap, language subjects, check questions only when asked", async () => {
  const { p } = await run("Ok.", tutor("Årskurs: Åk 9. Ämne: Engelska."));
  const u = p.calls[0].user;
  assertStringIncludes(u, "at most about 100 words");
  assertStringIncludes(u, "explain in Swedish, the student's language");
  assertStringIncludes(u, '"in twenty nineteen"');
  assertStringIncludes(u, 'Without that line, or with "inga": never a check question');
});
