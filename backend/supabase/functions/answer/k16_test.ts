import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, type Deps } from "./handler.ts";
import { type LLMChunk, type LLMProvider, type LLMRequest } from "./llm/types.ts";
import { cleanDomain, isFollowUp, lookupKind, needsWeb, SEARCH_MARK_RULE, webTools } from "./web.ts";

function scripted(...texts: string[]) {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = {
    name: "s",
    model: "s",
    stream: (r) => {
      const text = texts[Math.min(seen.length, texts.length - 1)];
      seen.push(r);
      return (async function* (): AsyncGenerator<LLMChunk> {
        for (let k = 0; k < text.length; k += 5) yield { type: "text", text: text.slice(k, k + 5) };
        yield { type: "usage", inputTokens: 100, outputTokens: 10 };
      })();
    },
  };
  return { provider, seen };
}
function handlerWith(provider: LLMProvider) {
  const deps: Deps = {
    authenticate: () => Promise.resolve({ id: "user-1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider,
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  };
  return createHandler(deps);
}
const ask = (o: Record<string, unknown>) =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ fragment: "vad är en atom", mode: "push_to_talk", language: "sv", context: {}, ...o }),
  });
async function spoken(res: Response): Promise<string> {
  const t = await res.text();
  return t.split("\n\n").filter((f) => f.startsWith("event: delta")).map((f) =>
    JSON.parse(/^data: (.*)$/m.exec(f)![1]).text
  ).join("");
}
const searches = (r: LLMRequest) => JSON.stringify(r.tools ?? []).includes("web_search");

Deno.test("K16.1 recipes, instructions and rules search; ordinary questions do not", () => {
  for (const [f, k] of [
    ["recept på kanelbullar", "recipe"],
    ["hur mycket mjöl i pannkakor", "recipe"],
    ["hur länge ska kycklingfilé i ugnen", "recipe"],
    ["hur återställer man en iphone", "howto"],
    ["steg för steg hur jag byter däck", "howto"],
    ["är det lagligt att köra moped utan hjälm", "rule"],
    ["vad är åldersgränsen för att köra moped", "rule"],
  ] as const) {
    assertEquals(lookupKind(f), k, f);
    assert(needsWeb(f)?.search, f);
  }
  for (const f of ["vad är en atom", "vad gäller för mitt bankkort borta", "hur fungerar fotosyntesen", "vad betyder demokrati"]) {
    assertEquals(lookupKind(f), null, f);
  }
  const t = JSON.stringify(webTools({ search: true, fetch: false, lookup: "recipe" }));
  assert(t.includes("ica.se") && t.includes("arla.se"));
});

Deno.test("K16.2 follow-ups and source domains", () => {
  for (const f of ["hur länge i ugnen?", "kan jag byta mjölet?", "och sen?", "vilken temperatur?"]) assert(isFollowUp(f), f);
  assert(!isFollowUp("vem var Gustav Vasa och varför blev han kung över hela Sverige efter Stockholms blodbad egentligen"));
  assertEquals(cleanDomain("https://www.ica.se/recept/x"), "ica.se");
  assertEquals(cleanDomain("not a domain"), null);
});

Deno.test("K16.1 [[SÖK]] from the model: nothing is said, the question is asked again with web search", async () => {
  const { provider, seen } = scripted("[[SÖK]]", "Bullarna gräddas i 250 grader i fem till sju minuter. källa: ica.se");
  const out = await spoken(await handlerWith(provider)(ask({ fragment: "hur varm ska ugnen vara för Lisas pepparkakor" })));
  assertEquals(seen.length, 2);
  assert(seen[0].system.includes("SURE OR SEARCH (K16"));
  assert(!searches(seen[0]));
  assert(searches(seen[1]), "second call searches");
  assert(!seen[1].system.includes(SEARCH_MARK_RULE.trim().slice(0, 20)) || !seen[1].system.includes("[[SÖK]]"));
  assert(!out.includes("SÖK"), out);
  assert(out.startsWith("Bullarna gräddas"), out);
});

Deno.test("K16.1 the marker after a relation tag works too; a normal answer is said as before", async () => {
  const a = scripted("[[REL new_topic]]\n[[SÖK]]", "Svar från källan. källa: ica.se");
  const out = await spoken(await handlerWith(a.provider)(ask({
    fragment: "vem uppfann surdegen",
    context: { recent_qa: [{ q: "vad är en atom", a: "En atom är den minsta delen av ett grundämne." }] },
  })));
  assertEquals(a.seen.length, 2);
  assert(!out.includes("SÖK"), out);
  const b = scripted("En atom är den minsta delen av ett grundämne.");
  const out2 = await spoken(await handlerWith(b.provider)(ask({})));
  assertEquals(b.seen.length, 1);
  assertEquals(out2, "En atom är den minsta delen av ett grundämne.");
  const c = scripted("Ja.");
  assertEquals(await spoken(await handlerWith(c.provider)(ask({ fragment: "är vatten blött" }))), "Ja.");
});

Deno.test("K16.2 a follow-up to a sourced answer searches the same source", async () => {
  const { provider, seen } = scripted("I tjugo minuter. källa: arla.se");
  await spoken(await handlerWith(provider)(ask({
    fragment: "hur länge i ugnen?",
    context: { recent_qa: [{ q: "recept på kladdkaka", a: "Du behöver två ägg, tre deciliter socker …", source: "arla.se" }] },
  })));
  assertEquals(seen.length, 1);
  assert(searches(seen[0]));
  assert(JSON.stringify(seen[0].tools).includes("arla.se"));
  assert(seen[0].user.includes("Source: arla.se"));
  assert(seen[0].user.includes("came from arla.se"));
});

Deno.test("K16 recipe fractions and kitchen measures are read as words", async () => {
  const { numbersToSpeech } = await import("./svnum.ts");
  assertEquals(numbersToSpeech("2 1/2 dl vetemjöl"), "två och en halv deciliter vetemjöl");
  assertEquals(numbersToSpeech("1/2 tsk salt"), "en halv tesked salt");
  assertEquals(numbersToSpeech("3/4 dl"), "tre fjärdedels deciliter");
  assertEquals(numbersToSpeech("2½ dl"), "två och en halv deciliter");
  assertEquals(numbersToSpeech("3 msk socker"), "tre matskedar socker");
  assertEquals(numbersToSpeech("öppet 24/7"), "öppet tjugofyra/sju");
});

Deno.test("K16 changing facts search; a late [[SÖK]] is never spoken", async () => {
  assert(needsWeb("hur många invånare har Ockelbo kommun")?.search);
  assert(needsWeb("vem är rektor på KTH")?.search);
  const { provider } = scripted("Ockelbo har ungefär femtusen invånare. [[SÖK]]");
  const out = await spoken(await handlerWith(provider)(ask({ fragment: "hur gammal är Ockelbo kyrka" })));
  assert(!out.includes("SÖK") && !out.includes("["), out);
});

Deno.test("K16 the [[VET]] marker is never spoken, also after a relation tag", async () => {
  const a = scripted("[[VET]] En atom är den minsta delen av ett grundämne.");
  assertEquals(await spoken(await handlerWith(a.provider)(ask({}))), "En atom är den minsta delen av ett grundämne.");
  const b = scripted("[[REL new_topic]]\n[[VET]]\nJa.");
  const out = await spoken(await handlerWith(b.provider)(ask({
    fragment: "är vatten blött",
    context: { recent_qa: [{ q: "vad är en atom", a: "En atom är den minsta delen av ett grundämne." }] },
  })));
  assertEquals(out.trim(), "Ja.");
});

Deno.test("K16 an English 'the sources do not say' sentence is never spoken in a web answer", async () => {
  const { isEnglishSentence } = await import("./speech.ts");
  assert(isEnglishSentence("The sources don't give a founding year for IFK Kalmar."));
  assert(!isEnglishSentence("Källorna anger inget grundår för IFK Kalmar."));
});

Deno.test("K4 loop: 'en 5:a' is a five, 1/6 is a sixth, 5:e is still fifth", async () => {
  const { numbersToSpeech } = await import("./svnum.ts");
  assertEquals(numbersToSpeech("Sannolikheten att slå en 5:a är 1/6."), "Sannolikheten att slå en femma är en sjättedel.");
  assertEquals(numbersToSpeech("Han kom på 5:e plats."), "Han kom på femte plats.");
  assertEquals(numbersToSpeech("2/5 av eleverna"), "två femtedelar av eleverna");
  assertEquals(numbersToSpeech("öppet 24/7"), "öppet tjugofyra/sju");
});
