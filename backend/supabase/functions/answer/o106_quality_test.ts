// O106 (Oscar, the listening mode through K122) and Deangelo 04:09: the shortest answer that is still right, numbers
// readable. L3 a year read "trettioen" and "trettioett" in one answer; L2 a question cut off on a possessive went to
// the model; L4 "hur lång tid tar det att flyga" was a study answer; a question overheard in the room is short.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { numbersToSpeech } from "./svnum.ts";
import { isCutOff } from "./handler.ts";
import { classifyAnswerType } from "./length.ts";

Deno.test("O106 L3: a year is read the same way before a verb or at the end; counted things keep en", () => {
  assertStringIncludes(numbersToSpeech("Melodifestivalen 2031 har inte hållits än."), "tvåtusen trettioett har");
  assertStringIncludes(numbersToSpeech("År 2031 är långt bort."), "tvåtusen trettioett är");
  assertStringIncludes(numbersToSpeech("Det hände 1921."), "nittonhundratjugoett");
  assertStringIncludes(numbersToSpeech("Det blir 2031 kronor."), "tvåtusen trettioen kronor");
  assertStringIncludes(numbersToSpeech("Det var 1021 elever."), "tjugoen elever");
});

Deno.test("O106 L2: a question that ends on a possessive is cut off (the app waits for the rest)", () => {
  for (const f of ["och vad hette hennes", "vad heter hans", "när föddes deras", "vem var hennes"]) assertEquals(isCutOff(f), true, f);
  assertEquals(isCutOff("vad hette hennes hund"), false);
});

Deno.test("O106 L4: a duration question is a fact (one or two sentences), a why or a comparison still study", () => {
  assertEquals(classifyAnswerType("vad är klockan i New York och hur lång tid tar det att flyga dit", "adaptive", null), "fact");
  assertEquals(classifyAnswerType("varför har jordens medeltemperatur stigit", "adaptive", null), "study");
});

Deno.test("Deangelo 04:09: a question overheard in the listening mode gets the short-answer rule and a smaller budget", async () => {
  const { createHandler, DEFAULT_CONFIG } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const seen: { system: string; systemTail?: string; maxTokens: number; user: string }[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-q", isAnonymous: false }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: (r) => (seen.push(r), (async function* () { yield { type: "text" as const, text: '{"is_question":true,"reconstructed_question":"x","confidence":0.9}\nSvar.' }; })()) },
    recordUsage: () => {}, config: DEFAULT_CONFIG,
  });
  const ask = (fragment: string, mode: string) => h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.9" }, body: JSON.stringify({ fragment, mode, language: "sv", context: {} }) })).then((r) => r.text());
  await ask("förklara skillnaden mellan väder och klimat", "auto");
  const auto = seen.at(-1)!;
  assert(`${auto.system}${auto.systemTail ?? ""}${auto.user}`.includes("at most three short sentences"), "the short rule");
  assert(auto.maxTokens < 500, String(auto.maxTokens)); // 360 + the meta line's room (was about 880)
  await ask("förklara skillnaden mellan väder och klimat", "push_to_talk");
  const ptt = seen.at(-1)!;
  assert(!`${ptt.systemTail ?? ""}${ptt.user}`.includes("at most three short sentences"), "asked on purpose: as before");
});

Deno.test("Deangelo 04:09: no 'som en AI' talk in an answer; asked whether it is an AI, it still says so (D113)", async () => {
  const { AnswerPost } = await import("./speech.ts");
  const say = (raw: string, heard: string) => {
    const p = new AnswerPost({ heard, language: "sv", previousAnswers: [] } as never);
    return (p.push(raw) + p.finish()).trim();
  };
  assertEquals(say("Som en AI har jag inga egna åsikter, men de flesta tycker att pizza är godast.", "vad är godast pizza eller tacos"), "De flesta tycker att pizza är godast.");
  assertEquals(say("Jag är bara en AI och kan inte veta det säkert. Kanadas huvudstad är Ottawa.", "vad heter kanadas huvudstad"), "Kanadas huvudstad är Ottawa.");
  assertEquals(say("As an AI, I cannot taste food. Pizza is popular.", "which is better"), "Pizza is popular.");
  assertStringIncludes(say("Ja, jag är en AI-assistent.", "är du en AI"), "jag är en AI-assistent");
});
