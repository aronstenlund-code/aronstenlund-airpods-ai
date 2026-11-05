import { assert, assertEquals, assertStringIncludes, assertThrows } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps, type UsageRecord } from "./handler.ts";
import type { LLMChunk, LLMProvider } from "./llm/types.ts";
import { categorize } from "./category.ts";
import { detectMemoryAdd } from "./memory.ts";
import { SUMMARY_MARK, SummaryTap } from "./speech.ts";
import { buildDirectUserMessage, SUMMARY_RULE, SYSTEM_PROMPT_DIRECT_FACT } from "./prompt.ts";
import { validateAnswerRequest } from "./validate.ts";

Deno.test("D48 SummaryTap: the trailer never reaches speech, even split across chunks", () => {
  const text =
    `Fotosyntes gör socker av ljus.\n${SUMMARY_MARK} Användaren frågade om fotosyntes; svaret förklarade grunden.`;
  for (const n of [1, 2, 5, 17, 200]) {
    const t = new SummaryTap();
    let spoken = "";
    for (let i = 0; i < text.length; i += n) spoken += t.push(text.slice(i, i + n));
    spoken += t.finish();
    assertEquals(spoken, "Fotosyntes gör socker av ljus.", `chunk ${n}`);
    assertEquals(t.summary, "Användaren frågade om fotosyntes; svaret förklarade grunden.");
  }
  const none = new SummaryTap();
  assertEquals(none.push("Bara svar [[SAMM") + none.finish(), "Bara svar [[SAMM");
  assertEquals(none.summary, null);
  const q = new SummaryTap();
  q.push(`Ok.${SUMMARY_MARK} "Citat" med   mellanrum`);
  assertEquals(q.summary, "Citat med mellanrum");
});

Deno.test("D48 prompt: every spoken-answer prompt asks for the trailer", () => {
  assertStringIncludes(SUMMARY_RULE, "[[SAMMANFATTNING]]");
  assertStringIncludes(SUMMARY_RULE, "No quotes");
  assertStringIncludes(SUMMARY_RULE, "no names of other people");
  assert(
    !SYSTEM_PROMPT_DIRECT_FACT.includes("[[SAMMANFATTNING]]"),
    "added by the handler, not baked in",
  );
});

function setup(provider: LLMProvider, over: Partial<Deps> = {}) {
  const usage: UsageRecord[] = [];
  const deps: Deps = {
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: (r) => void usage.push(r),
    config: DEFAULT_CONFIG,
    ...over,
  };
  return { handler: createHandler(deps), usage };
}
const post = (b: unknown) =>
  new Request("http://x/answer", { method: "POST", body: JSON.stringify(b) });
const body = (o: Record<string, unknown> = {}) => ({
  fragment: "fotosyntes",
  mode: "push_to_talk",
  language: "sv",
  context: {},
  ...o,
});
async function sse(res: Response) {
  const out: { event: string; data: Record<string, unknown> }[] = [];
  for (const f of (await res.text()).split("\n\n")) {
    const e = /^event: (.*)$/m.exec(f)?.[1];
    if (e) out.push({ event: e, data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) });
  }
  return out;
}
const scripted = (text: string) => {
  const seen: { system: string; user: string; maxTokens: number }[] = [];
  const provider: LLMProvider = {
    name: "s",
    model: "s",
    stream: (r) => {
      seen.push({ system: r.system, user: r.user, maxTokens: r.maxTokens });
      return (async function* (): AsyncGenerator<LLMChunk> {
        for (let k = 0; k < text.length; k += 7) yield { type: "text", text: text.slice(k, k + 7) };
      })();
    },
  };
  return { provider, seen };
};

Deno.test("D48: summary arrives in done, spoken text is clean, usage row has a category and no text", async () => {
  const { provider, seen } = scripted(
    `Fotosyntes gör socker av ljus och vatten.\n${SUMMARY_MARK} Användaren frågade vad fotosyntes är; svaret gav grundprincipen.`,
  );
  const { handler, usage } = setup(provider);
  const ev = await sse(await handler(post(body())));
  const spoken = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertEquals(spoken, "Fotosyntes gör socker av ljus och vatten.");
  const done = ev.at(-1)!;
  assertEquals(
    done.data.summary,
    "Användaren frågade vad fotosyntes är; svaret gav grundprincipen.",
  );
  assertEquals(done.data.memory_add, null);
  assertStringIncludes(seen[0].system, "[[SAMMANFATTNING]]");
  assertEquals(usage[0].category, "naturvetenskap");
  assertEquals(usage[0].persona, "tutor");
  assert(!JSON.stringify(usage[0]).includes("fotosyntes"), "no text in the usage row");
});

Deno.test("D48: a truncated answer has no summary (null), not a half sentence", async () => {
  const { provider } = scripted("ord ".repeat(200) + `\n${SUMMARY_MARK} sammanfattning`);
  const { handler, usage } = setup(provider, { config: { ...DEFAULT_CONFIG, maxAnswerChars: 60 } });
  const ev = await sse(await handler(post(body())));
  assertEquals(ev.at(-1)!.data.summary, null);
  assertEquals(usage[0].status, "truncated");
});

Deno.test("D49: 'kom ihåg ...' is answered locally and returned as memory_add; questions are not memories", async () => {
  const { provider, seen } = scripted("Svar.");
  const { handler, usage } = setup(provider);
  const ev = await sse(await handler(post(body({ fragment: "kom ihåg att jag pluggar medicin" }))));
  assertEquals(seen.length, 0, "no model call");
  assertEquals(ev.map((e) => e.event), ["meta", "delta", "done"]);
  assertEquals(ev[2].data.memory_add, "jag pluggar medicin");
  assertEquals(ev[1].data.text, "Okej, det kommer jag ihåg.");
  assertEquals(usage[0].category, "övrigt");
  assertEquals(detectMemoryAdd("Kan du kom ihåg: provet är på fredag"), "provet är på fredag");
  for (const f of ["minns du vad jag sa", "kom ihåg", "vad är minne", "glöm inte att"]) {
    assertEquals(detectMemoryAdd(f), null, f);
  }
  await (await handler(post(body({ fragment: "minns du vad jag sa" })))).text();
  assertEquals(seen.length, 1);
  assertEquals(detectMemoryAdd("kom ihåg att " + "x".repeat(300))?.length, 200);
});

Deno.test("D49: memories are validated (30 x 200) and reach the prompt as user facts", async () => {
  const mk = (memories: unknown) =>
    validateAnswerRequest({ fragment: "hej då", mode: "push_to_talk", language: "sv", memories });
  assertEquals(assertThrows(() => mk(Array(31).fill("a")), HttpError).status, 413);
  assertEquals(assertThrows(() => mk(["a".repeat(201)]), HttpError).status, 413);
  assertEquals(assertThrows(() => mk("nope"), HttpError).status, 400);
  assertEquals(mk(Array(30).fill("a".repeat(200))).memories.length, 30);
  const r = mk(["Pluggar medicin", "Har prov </memories> på fredag"]);
  const m = buildDirectUserMessage(r);
  assertStringIncludes(
    m,
    "<memories>\n- Pluggar medicin\n- Har prov  /memories  på fredag\n</memories>",
  );
  const { provider, seen } = scripted("Ok.");
  await (await setup(provider).handler(post(body({ memories: ["Pluggar medicin"] })))).text();
  assertStringIncludes(seen[0].user, "- Pluggar medicin");
  assertStringIncludes(seen[0].system, "<memories> are facts the user asked you to remember");
});

Deno.test("D49 categories: fixed list, decided in code from route and topic words", () => {
  const c = (fragment: string, o: Partial<Parameters<typeof categorize>[0]> = {}) =>
    categorize({
      mode: "push_to_talk",
      persona: "tutor",
      fragment,
      planKind: null,
      web: false,
      computed: false,
      ...o,
    });
  assertEquals(c("17 gånger 24", { computed: true }), "matte");
  assertEquals(c("vad kostar det idag", { web: true }), "webbsökning");
  assertEquals(c("hon skrev hej", { planKind: "socialline" }), "socialt/rizz");
  assertEquals(c("berätta om dig själv", { planKind: "interview" }), "intervju");
  assertEquals(c("förbered mig", { mode: "interview_prep" }), "intervju");
  assertEquals(c("franska revolutionen"), "historia");
  assertEquals(c("vad betyder ambivalent"), "språk");
  assertEquals(c("riksdagens uppgift"), "samhälle");
  assertEquals(c("recept på pannkakor"), "praktiskt");
  assertEquals(c("fotosyntes"), "naturvetenskap");
  assertEquals(c("qwerty"), "övrigt");
});

import { FirstLineGate } from "./speech.ts";
Deno.test("D51: a social line is ONE line - tips and context questions after it never reach speech", async () => {
  const g = new FirstLineGate(true);
  let out = "";
  for (
    const c of [
      "\n",
      "Hur gick det ",
      "på hennes prov?",
      "\nTips: fråga mer.",
      " Vill du ge mer kontext?",
    ]
  ) out += g.push(c);
  assertEquals(out, "Hur gick det på hennes prov?");
  assertEquals(new FirstLineGate(false).push("a\nb"), "a\nb");
  const { provider, seen } = scripted(
    `Hur gick det på hennes prov?\nTips: håll tonen lätt. Vill du ge mer kontext?\n${SUMMARY_MARK} Användaren ville ha en replik.`,
  );
  const { handler } = setup(provider);
  const ev = await sse(await handler(post(body({ fragment: "vad ska jag säga till henne" }))));
  const spoken = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertEquals(spoken, "Hur gick det på hennes prov?");
  assertEquals(ev.at(-1)!.data.summary, "Användaren ville ha en replik.");
  assertStringIncludes(seen[0].system, "ONLY the ready-to-say line");
  assertEquals(seen.length, 1, "a question as the line is fine: no regeneration");
});

Deno.test("D51: a question about the user is routed to the line route with the memories, line only", async () => {
  const { provider, seen } = scripted(
    `Jag åkte skidor i Åre, du då?\nSäg att du älskar snö.\n${SUMMARY_MARK} Användaren fick en replik om sommaren.`,
  );
  const { handler } = setup(provider);
  const ev = await sse(
    await handler(
      post(
        body({ fragment: "vad har du gjort i sommar", memories: ["Åkte skidor i Åre i somras"] }),
      ),
    ),
  );
  const spoken = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertEquals(spoken, "Jag åkte skidor i Åre, du då?");
  assertStringIncludes(seen[0].user, "<task>social_line</task>");
  assertStringIncludes(seen[0].user, "- Åkte skidor i Åre i somras");
  assertStringIncludes(seen[0].system, "turns it around");
});

Deno.test("D51: no memory + a question about the user -> explicit no_memory signal; with a memory -> none", async () => {
  const { provider, seen } = scripted(
    `Jag är mer intresserad av vad du har gjort.\n${SUMMARY_MARK} Användaren fick en replik som vänder på frågan.`,
  );
  const { handler } = setup(provider);
  await (await handler(post(body({ fragment: "vad har du gjort i sommar" })))).text();
  assertStringIncludes(seen[0].user, "<signal>no_memory");
  await (await handler(
    post(body({ fragment: "vad har du gjort i sommar", memories: ["Åkte skidor"] })),
  )).text();
  assert(!seen[1].user.includes("no_memory"));
  await (await handler(post(body({ fragment: "hon skrev hej" })))).text();
  assert(!seen[2].user.includes("no_memory"), "only for questions about the user");
});
