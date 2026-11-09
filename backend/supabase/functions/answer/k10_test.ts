import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { type AppMode, detectAppCommand } from "./appcommand.ts";

import CASES from "../../../../scripts/k10-appcommand-cases.json" with { type: "json" };

Deno.test("K10.1 app commands in the user's own words: 30 positive, 30 negative (>= 95 % right, <= 1 false hit)", () => {
  let right = 0;
  const wrong: string[] = [];
  for (const [text, cur, action, mode] of CASES.positive as [string, AppMode, string, AppMode | null][]) {
    const c = detectAppCommand(text, cur);
    if (c && c.action === action && (mode === null || c.mode === mode)) right++;
    else wrong.push(`${text} (${cur}) -> ${JSON.stringify(c)}`);
  }
  let falseHits = 0;
  for (const [text, cur] of CASES.negative as [string, AppMode][]) {
    const c = detectAppCommand(text, cur);
    if (c) {
      falseHits++;
      wrong.push(`NEG ${text} (${cur}) -> ${JSON.stringify(c)}`);
    }
  }
  assertEquals(CASES.positive.length, 30);
  assertEquals(CASES.negative.length, 30);
  assert(right === 30 && falseHits === 0, `${right}/30 right, ${falseHits} false: ${wrong.join("; ")}`);
});

import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";

function setup(text: string) {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = {
    name: "s",
    model: "s",
    stream: (r) => {
      seen.push(r);
      return (async function* (): AsyncGenerator<LLMChunk> {
        yield { type: "text", text };
        yield { type: "usage", inputTokens: 10, outputTokens: 5 };
      })();
    },
  };
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (b: unknown) => new Request("http://x/answer", { method: "POST", body: JSON.stringify(b) });

Deno.test("K10.1 a sure app command is answered by the app: no model call, app_command in meta and done", async () => {
  const { handler, seen } = setup("x");
  const t = await (await handler(post({ fragment: "kan vi köra vanliga frågor nu", mode: "tutor", persona: "tutor", language: "sv", context: {} }))).text();
  assertEquals(seen.length, 0);
  assert(t.includes('"app_command":{"action":"switch_mode","mode":"fragor"'), t);
});

Deno.test("K10.2-3 only the settings for this context reach the model; the profile is a cached system block", async () => {
  const { handler, seen } = setup("Fotosyntes gör socker av ljus.");
  await (await handler(post({
    fragment: "vad är fotosyntes", mode: "tutor", persona: "tutor", language: "sv",
    persona_setup: "Årskurs: Åk 9. Ämne: Biologi. Förklaringar: mellanlånga förklaringar.",
    preferences: [
      { key: "length", value: "shorter", scope: { subject: "Biologi" } },
      { key: "examples", value: "more", scope: { subject: "Historia" } },
    ],
    pref_profile: "Användaren vill ha: kortare svar i biologi.",
    context: {},
  }))).text();
  assert(seen[0].user.includes("Kortare svar i biologi"), seen[0].user);
  assert(!seen[0].user.includes("Fler exempel"), "a setting for another subject is not sent");
  assert(seen[0].systemTail?.includes("kortare svar i biologi"));
  assert(!seen[0].system.includes("<user_profile>"), "the shared cached prompt is unchanged");
});

Deno.test("K8 interview: a situation question about alcohol is not a missing fact; only own claims are", async () => {
  const { missingFact, claimsMissing } = await import("./interviewfacts.ts");
  const setup = "Jobbannons: Kassapersonal på Systembolaget. CV: Gymnasieelev.";
  assertEquals(missingFact("Hur skulle du hantera en full kund som vill köpa alkohol?", setup), null);
  assertEquals(missingFact("Har du jobbat med alkohol förut?", setup), "alkohol");
  assert(!claimsMissing("alkohol", "Jag nekar försäljning och kontrollerar alltid legitimation."));
  assert(claimsMissing("alkohol", "Jag har jobbat med alkohol på en restaurang."));
});

Deno.test("K8 Rizz/Socialt: a no is a no only when the line is one (Oscar O7 D1-D3)", async () => {
  const { isDecline } = await import("./rizz.ts");
  for (const t of ["Jag ska gå på bio i helgen, gillar du film?", "Jag vill inte missa matchen ikväll, ska du kolla?", "Jag ska gå och hämta en drink, vill du ha något?", "Jag ska gå på konsert sen."]) {
    assert(!isDecline(t), t);
  }
  for (const t of ["Nej tack.", "Jag måste gå nu, hej då!", "Sluta.", "Jag är inte intresserad.", "Jag vill inte.", "Lämna mig ifred"]) assert(isDecline(t), t);
});

Deno.test("K8 Rizz filters read words in context", async () => {
  const { parseSuggestions } = await import("./rizz.ts");
  assertEquals(parseSuggestions("Frukost på sängen är det bästa.\n"), ["Frukost på sängen är det bästa."]);
  assertEquals(parseSuggestions("Simmar du bröstsim också?\n"), ["Simmar du bröstsim också?"]);
  assertEquals(parseSuggestions("Du måste testa pizzan där.\n"), ["Du måste testa pizzan där."]);
  assertEquals(parseSuggestions("Följ med upp i sängen.\n"), []);
  assertEquals(parseSuggestions("Du måste följa med mig hem.\n"), []);
});

Deno.test("K8 texts: 'hur lyder', 'första versen', 'en rad ur' go to the text path; prices search shops", async () => {
  const { needsText, needsWeb, webTools } = await import("./web.ts");
  for (const f of ["hur lyder första versen av Du gamla du fria", "citera en rad ur Bohemian Rhapsody", "första versen av Vem kan segla"]) assert(needsText(f), f);
  const w = needsWeb("vad kostar en iPhone 17 i Sverige");
  assert(w?.price);
  assert(JSON.stringify(webTools(w!)).includes("prisjakt.nu"));
});
