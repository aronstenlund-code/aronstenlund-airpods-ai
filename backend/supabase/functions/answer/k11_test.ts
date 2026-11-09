import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { withDeadline } from "./llm/deadline.ts";
import { type LLMChunk, type LLMProvider, LLMProviderError, type LLMRequest } from "./llm/types.ts";
import { AnswerPost, fixStump, quotedParts, quoteVerified } from "./speech.ts";
import { isPersonQuote } from "./web.ts";

const sleep = (ms: number, signal?: AbortSignal) =>
  new Promise<void>((resolve, reject) => {
    const t = setTimeout(resolve, ms);
    signal?.addEventListener("abort", () => {
      clearTimeout(t);
      reject(new DOMException("aborted", "AbortError"));
    });
  });

/** A fake provider: per model, a delay before the first text, chunks, then an optional hang. */
function fake(plan: Record<string, { delay?: number; text?: string[]; hangAfter?: number; error?: LLMProviderError }>) {
  const calls: LLMRequest[] = [];
  const p: LLMProvider = {
    name: "fake",
    model: "haiku",
    async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
      calls.push(req);
      const m = plan[req.model ?? "haiku"];
      yield { type: "usage", inputTokens: 10 };
      if (m.delay) await sleep(m.delay, req.signal);
      if (m.error) throw m.error;
      for (const [i, t] of (m.text ?? []).entries()) {
        if (m.hangAfter !== undefined && i === m.hangAfter) await sleep(60_000, req.signal);
        yield { type: "text", text: t };
      }
    },
  };
  return { p, calls };
}

async function collect(it: AsyncIterable<LLMChunk>): Promise<string> {
  let s = "";
  for await (const c of it) if (c.type === "text") s += c.text;
  return s;
}

Deno.test("K11.1 no first text in time: the same request goes to the default model without thinking", async () => {
  const { p, calls } = fake({ sonnet: { delay: 60_000, text: ["för sent"] }, haiku: { text: ["Derivatan ", "är lutningen."] } });
  const t0 = Date.now();
  const out = await collect(withDeadline(p, { firstTextMs: 80, idleMs: 80, fallbackModel: "haiku" }).stream({
    system: "s", user: "u", maxTokens: 10, model: "sonnet", think: true,
  }));
  assertEquals(out, "Derivatan är lutningen.");
  assert(Date.now() - t0 < 2000);
  assertEquals(calls.length, 2);
  assertEquals(calls[1].model, "haiku");
  assertEquals(calls[1].think, false);
  assertEquals(calls[1].noThinking, true);
});

Deno.test("K11.1 an overloaded error before any text falls back too; a quota error does not", async () => {
  const { p } = fake({ sonnet: { error: new LLMProviderError("unavailable", "overloaded", 529) }, haiku: { text: ["Svar."] } });
  const d = withDeadline(p, { firstTextMs: 500, idleMs: 500, fallbackModel: "haiku" });
  assertEquals(await collect(d.stream({ system: "s", user: "u", maxTokens: 10, model: "sonnet" })), "Svar.");
  const q = fake({ sonnet: { error: new LLMProviderError("quota", "credits", 400) }, haiku: { text: ["x"] } });
  await assertRejects(
    () => collect(withDeadline(q.p, { firstTextMs: 500, idleMs: 500, fallbackModel: "haiku" }).stream({ system: "s", user: "u", maxTokens: 10, model: "sonnet" })),
    LLMProviderError,
  );
});

Deno.test("K11.1 a stream that stalls after text ends with what was said", async () => {
  const { p } = fake({ sonnet: { text: ["Första meningen. ", "Andra."], hangAfter: 1 } });
  const t0 = Date.now();
  const out = await collect(withDeadline(p, { firstTextMs: 500, idleMs: 80, fallbackModel: "haiku" }).stream({
    system: "s", user: "u", maxTokens: 10, model: "sonnet",
  }));
  assertEquals(out, "Första meningen. ");
  assert(Date.now() - t0 < 2000);
});

Deno.test("K11.1 a web turn without a fallback fails as unavailable instead of hanging", async () => {
  const { p } = fake({ sonnet: { delay: 60_000, text: ["x"] } });
  await assertRejects(
    () => collect(withDeadline(p, { firstTextMs: 60, idleMs: 60 }).stream({ system: "s", user: "u", maxTokens: 10, model: "sonnet" })),
    LLMProviderError,
  );
});

Deno.test("K11.2 a sentence pointing at a dropped claim is dropped too", () => {
  for (const s of [
    "Det är just den noggrannheten jag vill ta med mig till Systembolaget.",
    "Den erfarenheten tar jag med mig.",
    "Det här är precis vad jag vill göra.",
    "Samma sak gäller här.",
  ]) assertEquals(fixStump(s), "", s);
  for (const s of ["Jag är noggrann och van vid kundkontakt.", "Det beror på läget.", "Den franska revolutionen började 1789."]) {
    assertEquals(fixStump(s), s, s);
  }
});

Deno.test("K11.2 interview: the claim is dropped and the stump after it as well (Oscar O5 C)", () => {
  const post = new AnswerPost({ previousAnswers: [], trimQuestion: false, interview: true, missingFact: "alkohol" });
  const out = post.push("Jag har jobbat med alkohol på en bar i två år. Det är just den noggrannheten jag vill ta med mig till Systembolaget. Jag kontrollerar alltid legitimation och säljer aldrig till någon som är påverkad. ") +
    post.finish();
  assert(!/^\s*Det är just/.test(out), out);
  assert(out.startsWith("Jag kontrollerar alltid legitimation"), out);
});

Deno.test("K11.3 a person's quote is checked; songs and verses are not", () => {
  for (const f of ["citera Strindberg om kärlek", "citera Strindberg om kvinnor i Giftas", "vad sa Churchill om krig", "ge mig ett citat av Karin Boye"]) {
    assert(isPersonQuote(f), f);
  }
  for (const f of ["citera en rad ur Bohemian Rhapsody", "hur lyder första versen av Du gamla du fria", "sjung helan går", "vad är fotosyntes"]) {
    assert(!isPersonQuote(f), f);
  }
  assertEquals(quotedParts("Strindberg skriver i Giftas: 'Jag tror nämligen att kärleken är en känsloaffär.'"), [
    "jag tror nämligen att kärleken är en känsloaffär",
  ]);
  assertEquals(quotedParts("Han kallade det \"ett dockhem\"."), []); // under four words: a title, not a quote
  assert(quoteVerified("vi kämpar på stränderna", "We shall fight ... vi kämpar på stränderna, vi kämpar"));
  assert(!quoteVerified("jag tror nämligen att kärleken är en känsloaffär", "Giftas är en novellsamling av August Strindberg från 1884."));
});

Deno.test("K11.3 an unverified quote is dropped and flagged; a quote from the search stays", () => {
  const bad = new AnswerPost({ previousAnswers: [], trimQuestion: false, source: true, quoteCheck: true });
  bad.addCited("Giftas är en novellsamling av August Strindberg från 1884.");
  const out = bad.push("Strindberg skriver i Giftas: 'Jag tror nämligen att kärleken är en känsloaffär.' ") + bad.finish();
  assertEquals(out.trim(), "");
  assert(bad.unverifiedQuote);

  const good = new AnswerPost({ previousAnswers: [], trimQuestion: false, source: true, quoteCheck: true });
  good.addCited("Kärleken är en fråga om kraft och en kamp om makten");
  const ok = good.push("Strindberg skriver: \"Kärleken är en fråga om kraft och en kamp om makten.\" ") + good.finish();
  assert(ok.includes("Kärleken är en fråga om kraft"), ok);
  assert(!good.unverifiedQuote);

  const off = new AnswerPost({ previousAnswers: [], trimQuestion: false, source: true });
  assert((off.push("Han skrev 'det här är ett långt citat utan sökning'. ") + off.finish()).includes("långt citat"));
});

Deno.test("K11.2 an interview answer never opens with a back-reference (live 2/5 before)", () => {
  for (const text of [
    "Det är precis den noggrannheten jag vill ta med mig till Systembolaget. Jag ser fram emot att lära mig reglerna. ",
    "Det har lärt mig att vara noggrann med regler. Jag ser fram emot att lära mig reglerna. ",
    "Det har gjort mig van vid ansvar. Jag ser fram emot att lära mig reglerna. ",
  ]) {
    const post = new AnswerPost({ previousAnswers: [], trimQuestion: false, interview: true, missingFact: "alkohol" });
    const out = post.push(text) + post.finish();
    assert(out.startsWith("Jag ser fram emot"), out);
  }
  const ok = new AnswerPost({ previousAnswers: [], trimQuestion: false, interview: true });
  const out = ok.push("Det jag tar med mig är ansvar i kassan. Det är just den noggrannheten jag vill visa. ") + ok.finish();
  assert(out.startsWith("Det jag tar med mig"), out);
});
