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
