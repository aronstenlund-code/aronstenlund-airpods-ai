import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "./llm/types.ts";
import { COMMAND_FAMILIES, commandTask, detectRule, normalizeCommand, socialRequest, socialStyle } from "./commands.ts";
import { requestedCount } from "./rizz.ts";

// three spoken variants per task (K9: "3 varianter per task")
const VARIANTS: Record<string, [string, "study" | "interview" | "social", string[]]> = {
  example: ["example", "study", ["Lumen, ge ett exempel", "kan du ge mig ett exempel tack", "har du något exempel?"]],
  summary: ["summary", "study", ["sammanfatta det viktigaste", "Lumen, summera", "vad är det viktigaste"]],
  a_level: ["a_level", "study", ["förklara på a-nivå", "Lumen, som ett A-svar", "hur får jag ett A på det här"]],
  harder_question: ["harder_question", "study", ["ställ en svår fråga", "Lumen, en svårare fråga", "utmana mig"]],
  quick_quiz: ["quick_quiz", "study", ["snabbförhör", "ge mig fem snabba frågor", "Lumen, kör fem frågor i rad"]],
  yes_no_quiz: ["yes_no_quiz", "study", ["ja eller nej frågor", "ställ ja nej frågor", "förhör mig med ja och nej"]],
  quiz_topic: ["quiz_topic", "study", ["förhör mig på cellandning", "Lumen, testa mig om franska revolutionen", "fråga ut mig om ekvationer"]],
  weak_areas: ["weak_areas", "study", ["testa mina svagaste områden", "vad kan jag sämst", "vad behöver jag öva mer på"]],
  self_assessment: ["self_assessment", "study", ["hur bra kan jag det här", "Lumen, hur ligger jag till", "kan jag det här?"]],
  careful: ["careful", "study", ["var säker", "Lumen, dubbelkolla det", "är du säker på det?"]],
  catch_up: ["catch_up", "study", ["vad missade jag", "Lumen, vad har jag missat", "vad sa läraren"]],
  brief_style: ["brief_style", "study", ["hjälp mig diskret", "kort och diskret", "bara en mening"]],
  ih_prof: ["interview_help:professional", "interview", ["hjälp mig svara professionellt", "vad borde jag säga", "Lumen, vad ska jag säga"]],
  ih_better: ["interview_help:better", "interview", ["ge mig ett bättre svar", "gör svaret bättre", "förbättra det"]],
  ih_conf: ["interview_help:confident", "interview", ["mer självsäkert", "låt mer säker", "mer övertygande"]],
  ih_counter: ["interview_help:counter_question", "interview", ["ge mig en motfråga", "vad kan jag fråga tillbaka", "en bra fråga att ställa"]],
  ih_stuck: ["interview_help:stuck", "interview", ["hjälp, jag fastnar", "jag har fastnat", "jag vet inte vad jag ska säga"]],
  s_reply: ["social:reply", "social", ["vad ska jag svara", "vad svarar jag", "Lumen, vad kan jag säga"]],
  s_fun: ["social:funnier", "social", ["roligare", "gör det roligare", "mer humor"]],
  s_nat: ["social:natural", "social", ["mer naturligt", "naturligare", "mindre stelt"]],
  s_topic: ["social:change_topic", "social", ["byt ämne", "hjälp mig byta ämne", "något annat att prata om"]],
  s_follow: ["social:follow_up", "social", ["smart följdfråga", "ge mig en bra följdfråga", "en följdfråga"]],
  s_meant: ["social:what_meant", "social", ["vad menade hon", "vad menade han med det", "vad menade personen"]],
  r_more: ["rizz:more", "social", ["ge mig lite rizz", "mer rizz", "rizz"]],
  r_conf: ["rizz:confident", "social", ["mer självsäker", "säkrare", "mer självsäkert"]],
  r_flirt: ["rizz:flirty", "social", ["flirtigare", "mer flörtig", "mer flirtig"]],
  r_subtle: ["rizz:subtle", "social", ["mer subtil", "subtilare", "lugnare"]],
  r_cocky: ["rizz:cocky", "social", ["kaxigare", "mer kaxig", "mer kaxigt"]],
  r_rescue: ["rizz:rescue", "social", ["rädda mig", "det går dåligt", "rädda situationen"]],
  r_cringe: ["rizz:less_cringe", "social", ["mindre cringe", "mindre pinsamt", "Lumen, mindre cringe tack"]],
  alt3: ["alternatives:3", "social", ["ge mig tre alternativ", "tre förslag", "ge mig tre"]],
};

Deno.test("K9 every family: three variants each map to the task", () => {
  for (const [task, scope, phrases] of Object.values(VARIANTS)) {
    for (const p of phrases) assertEquals(commandTask(p, scope)?.task, task, `${p} (${scope})`);
  }
  // every family in the table has variants above
  const covered = new Set(Object.values(VARIANTS).map((v) => v[0]));
  for (const f of COMMAND_FAMILIES) assert(covered.has(f.task), `no variants for ${f.task}`);
  assertEquals(commandTask("förhör mig på cellandning", "study")?.arg, "cellandning");
});

Deno.test("K9 negatives: the words inside an ordinary question or sentence never trigger a task", () => {
  for (
    const f of [
      "ge ett exempel på en exoterm reaktion",
      "vad är ett exempel på en vektor",
      "sammanfatta franska revolutionens orsaker",
      "jag vill byta ämne på gymnasiet",
      "kan du upprepa det för klassen",
      "vad menade Marx med klasskamp",
      "är du säker på att mitokondrien gör energi",
      "hur bra kan man bli på schack",
      "vad missade Napoleon i Ryssland",
      "en mening med bisats",
      "fotosyntes",
    ]
  ) assertEquals(commandTask(f, "study"), null, f);
  // a task never crosses its scope
  assertEquals(commandTask("roligare", "study"), null);
  assertEquals(commandTask("ge ett exempel", "social"), null);
  assertEquals(normalizeCommand("Lumen, kan du snälla ge ett exempel tack!"), "ge ett exempel");
});

Deno.test("K9 social: requests ask for lines, styles stay calibrations", () => {
  assertEquals(socialRequest("ge mig tre alternativ")?.count, 3);
  assertEquals(requestedCount("vad ska jag svara"), 1);
  assertEquals(requestedCount("byt ämne"), 1);
  assertEquals(requestedCount("roligare"), null); // a calibration, as before
  assertEquals(socialStyle("kaxigare"), "cockier, playful");
  assertEquals(requestedCount("ge mig fem pickup lines"), 5); // D72 unchanged
});

Deno.test("K9 standing rules from the user's own words (Aron 21:20)", () => {
  const a = detectRule("fortsätt att du i framtiden bara ska ställa korta svar under en mening alltså det är minnet");
  assert(a, "Aron's sentence");
  assertEquals(a!.ack, "Okej, korta svar.");
  assertStringIncludes(a!.rule.toLowerCase(), "korta svar under en mening");
  for (const f of ["från och med nu ska du svara på engelska", "svara alltid med ett exempel", "i framtiden ska du förklara enklare"]) {
    assert(detectRule(f), f);
  }
  for (
    const f of [
      "vad händer med klimatet i framtiden",
      "kommer jag alltid att vara trött?",
      "solen går alltid upp i öster",
      "i framtiden vill jag bli läkare",
      "fotosyntes",
    ]
  ) assertEquals(detectRule(f), null, f);
});

// ---------- the handler ----------
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
async function sse(res: Response) {
  const out: { event: string; data: Record<string, unknown> }[] = [];
  for (const f of (await res.text()).split("\n\n")) {
    const e = /^event: (.*)$/m.exec(f)?.[1];
    if (e) out.push({ event: e, data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) });
  }
  return out;
}
const QA = [{ q: "fotosyntes", a: "Fotosyntes är när växter gör socker av ljus, koldioxid och vatten." }];

Deno.test("K9 handler: a task and its rule go in the user message; the cached system prompt is unchanged", async () => {
  const { handler, seen } = setup("Ett exempel är en gran i solen.");
  const ev = await sse(await handler(post({ fragment: "ge ett exempel", mode: "push_to_talk", language: "sv", context: { recent_qa: QA } })));
  assertStringIncludes(seen[0].user, "<task>example</task>");
  assertStringIncludes(seen[0].user, "<task_rule>");
  assert(!seen[0].system.includes("<task_rule>"));
  assert(ev.some((e) => e.event === "delta"));
});

Deno.test("K9 handler: a hard question in Provläge keeps only the question; weak_areas gets the stats", async () => {
  const { handler, seen } = setup("Bra. Varför behöver cellandningen syre?");
  const ev = await sse(await handler(post({
    fragment: "testa mina svagaste områden", mode: "tutor", language: "sv", persona: "tutor",
    context: { recent_qa: QA, concept_stats: [{ concept: "cellandning", right: 1, wrong: 3 }] },
  })));
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertEquals(said.trim(), "Varför behöver cellandningen syre?");
  assertStringIncludes(seen[0].user, "cellandning: 1 rätt, 3 fel");
});

Deno.test("K9 handler: 'var säker' uses the stronger model and thinks", async () => {
  const { handler, seen } = setup("Det stämmer.");
  await sse(await handler(post({ fragment: "Lumen, dubbelkolla det", mode: "push_to_talk", language: "sv", context: { recent_qa: QA } })));
  assertEquals(seen[0].model, DEFAULT_CONFIG.rizzModel);
  assertEquals(seen[0].think, true);
});

Deno.test("K9 handler: a standing rule is answered locally and returned as a memory", async () => {
  const { handler, seen } = setup("x");
  const ev = await sse(await handler(post({
    fragment: "fortsätt att du i framtiden bara ska ställa korta svar under en mening alltså det är minnet",
    mode: "tutor", language: "sv", persona: "tutor", context: {},
  })));
  assertEquals(seen.length, 0);
  assertEquals(ev.find((e) => e.event === "delta")?.data.text, "Okej, korta svar.");
  const done = ev.find((e) => e.event === "done")!.data;
  assert(String(done.memory_add).startsWith("Regel: "), String(done.memory_add));
  assert(typeof done.rule_add === "string");
});

Deno.test("K9 handler: an unknown voice instruction goes to the model as an instruction", async () => {
  const { handler, seen } = setup("Kort: växter gör socker av ljus.");
  await sse(await handler(post({
    fragment: "säg det som en rubrik", mode: "push_to_talk", language: "sv", voice_instruction: true, context: { recent_qa: QA },
  })));
  assertStringIncludes(seen[0].user, "spoken instruction to you");
});

Deno.test("K9 handler: the interview counter question is said (the answer is a question)", async () => {
  const { handler } = setup("Hur ser ett vanligt kvällspass ut hos er, och hur många jobbar samtidigt?");
  const ev = await sse(await handler(post({
    fragment: "ge mig en motfråga", mode: "tutor", language: "sv", persona: "interview", turn: "question",
    persona_setup: "Jobbannons: Kassapersonal. CV: Gymnasieelev.", context: { recent_qa: QA },
  })));
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertStringIncludes(said, "kvällspass");
});
