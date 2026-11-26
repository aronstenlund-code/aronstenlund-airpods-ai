// K122 (D265): the prompt dump and the replay. Nothing leaves the process: the real AnthropicProvider sends to a
// scripted fetch, every other host is refused, and the saved reply goes through the rest of the server's chain.
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { CRISIS_SELF } from "../supabase/functions/answer/crisis.ts";
import { blockedFetch, FAKE_BASE, loadCases, type Reply, runCase } from "./k122-lib.ts";

const map = (o: Record<string, Reply>) => (stem: string) => o[stem] ?? null;
const F01 = { id: "F01", cat: "fakta", turns: [{ q: "hur många ben har en spindel" }] };

Deno.test("K122 dump: the first call is captured exactly as sent and nothing else is called", async () => {
  const r = await runCase(F01, () => null);
  assertEquals(r.status, "needs_reply");
  assertEquals(r.needs, "F01.t1.c1");
  assertEquals(r.prompts.length, 1);
  const p = r.prompts[0];
  assertEquals(p.stem, "F01.t1.c1");
  assertEquals(p.endpoint, "answer");
  assertEquals(p.url, `${FAKE_BASE}/v1/messages`);
  const body = p.anthropic_request as Record<string, unknown>;
  assertEquals(body.model, "claude-haiku-5-5");
  assertEquals(body.stream, true);
  assert(Number(body.max_tokens) > 0);
  assert(JSON.stringify(body.system).length > 200, "the system prompt is there");
  assert(JSON.stringify(body.messages).includes("hur många ben har en spindel"));
  assertEquals(p.client_request.fragment, "hur många ben har en spindel");
  assertEquals(r.blocked, []);
  assert(p.reply_hint.startsWith("Direct mode"), p.reply_hint);
  const auto = await runCase({ id: "A1", mode: "auto", turns: [{ q: "vad heter Norges huvudstad" }] }, () => null);
  assert(auto.prompts[0].reply_hint.startsWith("First line: the JSON meta"), auto.prompts[0].reply_hint);
});

Deno.test("K122 replay: a saved reply goes through the spoken format (K115) to what the user hears", async () => {
  const r = await runCase({ id: "F05", cat: "fakta", turns: [{ q: "hur högt är Kebnekaise" }] }, map({ "F05.t1.c1": { text: "Kebnekaise är 2097 meter högt." } }));
  assertEquals(r.status, "done");
  const t = r.turns[0];
  assertEquals(t.http_status, 200);
  assert(t.said && !/2097/.test(t.said) && /tusen/.test(t.said), t.said);
  assert(t.done, "a done event");
  assertEquals(t.usage.length, 1);
  assertEquals(t.usage[0].model, "claude-haiku-5-5");
});

Deno.test("K122 replay: the model's crisis marker asks for the check call (D256); 'ja' gives the crisis answer", async () => {
  const c = { id: "K1", cat: "test", turns: [{ q: "recept på ris" }] };
  const first = await runCase(c, map({ "K1.t1.c1": { text: "[[KRIS]]" } }));
  assertEquals(first.status, "needs_reply");
  assertEquals(first.needs, "K1.t1.c2");
  assert(JSON.stringify(first.prompts.at(-1)!.anthropic_request).includes("You check ONE utterance"));
  assert(first.prompts.at(-1)!.reply_hint.startsWith("crisis check"), first.prompts.at(-1)!.reply_hint);
  const r = await runCase(c, map({ "K1.t1.c1": { text: "[[KRIS]]" }, "K1.t1.c2": { text: "ja" } }));
  assertEquals(r.status, "done");
  assertEquals(r.turns[0].said, CRISIS_SELF);
  assertEquals(r.turns[0].done?.safety, "crisis");
});

Deno.test("K122 replay: an error reply gives the error code the user gets (402 -> provider_quota)", async () => {
  const r = await runCase(F01, map({ "F01.t1.c1": { error: { status: 402, message: "Your credit balance is too low" } } }));
  assertEquals(r.status, "done");
  const t = r.turns[0];
  assertEquals(t.error?.code, "provider_quota");
});

Deno.test("K122 replay: turn 2's prompt carries what the user heard in turn 1", async () => {
  const c = { id: "E2", cat: "följdfråga", turns: [{ q: "vem skrev Röda rummet" }, { q: "när då" }] };
  const r = await runCase(c, map({ "E2.t1.c1": { text: "Det var August Strindberg." } }));
  assertEquals(r.needs, "E2.t2.c1");
  const p = r.prompts.find((x) => x.stem === "E2.t2.c1")!;
  assertEquals(p.client_request.context.recent_qa[0].a, "Det var August Strindberg.");
  assert(JSON.stringify(p.anthropic_request).includes("August Strindberg"));
});

Deno.test("K122: Provläge via provlage-eval, exam compress and help run on the same engine", async () => {
  const tutor = await runCase({ id: "P1", endpoint: "provlage-eval", body: { action: "answer", model: "sonnet", request: { fragment: "vad är fotosyntes", mode: "tutor", language: "sv", goals: "Biologi 1", context: {} } } }, () => null);
  assertEquals((tutor.prompts[0].anthropic_request as { model: string }).model, "claude-sonnet-5-5");
  const comp = await runCase({ id: "C1", endpoint: "exam", body: { action: "compress", text: "Fotosyntesen är processen där växter med hjälp av ljus gör socker av koldioxid och vatten. Syre bildas." } }, map({ "C1.t1.c1": { text: "Växter gör socker av koldioxid och vatten med ljus, och syre bildas." } }));
  assertEquals(comp.turns[0].http_status, 200);
  assert(JSON.stringify(comp.turns[0].json).includes("Växter gör socker"), JSON.stringify(comp.turns[0].json));
  const help = await runCase({ id: "H1", endpoint: "help", body: { question: "hur gör jag ett prov" } }, map({ "H1.t1.c1": { text: '{"in_scope":true,"answer":"Tryck på Nytt prov."}' } }));
  assertEquals(help.turns[0].http_status, 200);
  assert(JSON.stringify(help.turns[0].json).includes("Nytt prov"), JSON.stringify(help.turns[0].json));
});

Deno.test("K122: every host but the scripted model is refused, and the eval's Scribe action is not run", async () => {
  await assertRejects(() => blockedFetch([])("https://api.anthropic.com/v1/messages"));
  await assertRejects(() => blockedFetch([])("https://api.elevenlabs.io/v1/speech-to-text"));
  const r = await runCase({ id: "S1", endpoint: "provlage-eval", body: { action: "transcribe", audio_base64: "AAAA" } }, () => null);
  assertEquals(r.status, "refused");
});

Deno.test("K122: the QA cases and the extra cases load", async () => {
  const cases = await loadCases();
  assert(cases.length > 100, String(cases.length));
  for (const ep of ["answer", "provlage-eval", "exam", "help"]) assert(cases.some((c) => (c.endpoint ?? "answer") === ep), ep);
  assert(cases.some((c) => c.id === "RZ1"), "Rizz cases as their social body");
});

Deno.test("O102 P4: a question that must be searched, answered without a search or a source, is marked source_missing", async () => {
  const r = await runCase({ id: "W1", cat: "webb", turns: [{ q: "sök på nätet vem som är riksbankschef" }] }, map({ "W1.t1.c1": { text: "Erik Thedéen är riksbankschef." } }));
  assertEquals(r.status, "done");
  assertEquals(r.turns[0].done?.source_missing, true, JSON.stringify(r.turns[0].done));
  const plain = await runCase({ id: "F2", cat: "fakta", turns: [{ q: "vad heter Norges huvudstad" }] }, map({ "F2.t1.c1": { text: "Oslo." } }));
  assertEquals(plain.turns[0].done?.source_missing, undefined, "an ordinary answer is never marked");
});

Deno.test("O102 P5: the model's [[KRIS]] after a relation tag or [[VET]] is the whole reply: the check, then the crisis answer only", async () => {
  const ctx = { recent_qa: [{ q: "vad är fotosyntes", a: "Fotosyntes är när växter gör socker av ljus." }] };
  for (const first of ["[[VET]]\n[[KRIS]]", "[[REL new_topic]]\n[[VET]]\n[[KRIS]]", "[[REL new_topic]]\n[[KRIS]]"]) {
    const r = await runCase({ id: "K5", endpoint: "answer", body: { fragment: "allt känns meningslöst nu", mode: "push_to_talk", language: "sv", context: ctx } },
      map({ "K5.t1.c1": { text: first }, "K5.t1.c2": { text: "ja" }, "K5.t1.c3": { text: "ja" } }));
    assertEquals(r.status, "done", first);
    assertEquals(r.prompts.length, 2, `${first}: the answer and the check, no second answer call`);
    assert(JSON.stringify(r.prompts[1].anthropic_request).includes("You check ONE utterance"), first);
    assertEquals(r.turns[0].said, CRISIS_SELF, first);
  }
});

Deno.test("O103 Q1: an English web question gets an English web prompt, the English answer is said and its source in English", async () => {
  const body = { fragment: "how do I make pancakes", mode: "push_to_talk", language: "en", lang: "en", context: {} };
  const first = await runCase({ id: "Q1", endpoint: "answer", body, headers: { "x-earmind-lang": "en" } }, () => null);
  const sys = JSON.stringify(first.prompts.map((p) => (p.anthropic_request as { system: unknown }).system));
  assert(!sys.includes("Answer ONLY in Swedish"), "never the Swedish-only rule for English");
  assert(!sys.includes("Always answer in Swedish"), "nor for texts");
  const text = "Whisk 2.5 dl flour with 6 dl milk and 3 eggs, then fry thin pancakes in butter. källa: bbcgoodfood.com";
  // RQ3 live path: the model says [[SÖK]] and the search turn gets the web rules (English ones now)
  const r = await runCase({ id: "Q1", endpoint: "answer", body, headers: { "x-earmind-lang": "en" } }, map({ "Q1.t1.c1": { text: "[[SÖK]]" }, "Q1.t1.c2": { text } }));
  const webSys = JSON.stringify((r.prompts[1].anthropic_request as { system: unknown }).system);
  assert(webSys.includes("WEB: you have web tools") && webSys.includes("Answer ONLY in English") && !webSys.includes("ONLY in Swedish"));
  const said = r.turns[0]?.said ?? "";
  assert(said.startsWith("Whisk 2.5 dl flour"), said);
  assert(!/Källa|källa/.test(said) && / Source: Bbcgoodfood\.$/.test(said), said);
  assertEquals(r.turns[0].done?.source, "bbcgoodfood.com");
});

Deno.test("O103 Q4: the web retry note keeps its <domain> placeholder readable", async () => {
  const { noteText } = await import("../supabase/functions/answer/prompt.ts");
  assert(noteText('end with "källa: <domain>".').includes("‹domain›"));
});

Deno.test("O103 tool: the replay has index.ts's language wrapper (an error in English with x-earmind-lang en)", async () => {
  const r = await runCase({ id: "E1", endpoint: "answer", body: { fragment: "what is the capital of france", mode: "push_to_talk", language: "en", context: {} }, headers: { "x-earmind-lang": "en" } },
    map({ "E1.t1.c1": { error: { status: 402, message: "Your credit balance is too low" } } }));
  const msg = String(r.turns[0].error?.message ?? "");
  assert(msg && !/[åäö]/i.test(msg), msg);
});
