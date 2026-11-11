// K40 (Aron's phone test): short quiz answers misheard ("Nilen" -> "Nilan", "Seine" -> "såg en"): compared by sound.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { matchAnswer, parseQuizKey, readQuizKey } from "./soundalike.ts";

const BANK = JSON.parse(Deno.readTextFileSync(new URL("../../../testdata/k40-quiz-sound.json", import.meta.url))) as {
  cases: { key: { answer: string; alternatives: string[] }; heard: string; ok: "right" | "wrong" }[];
};

Deno.test("K40 the sound bank: misheard right answers are right, wrong answers never 'right'", () => {
  const bad = BANK.cases.filter((c) => {
    const v = matchAnswer(c.heard, c.key).verdict;
    return (c.ok === "right") !== (v === "correct" || v === "near");
  });
  assertEquals(bad.map((c) => `${c.key.answer}: ${c.heard}`), []);
  assert(BANK.cases.length >= 40);
});

Deno.test("K40 the key line is parsed; the app's key is read leniently", () => {
  assertEquals(parseQuizKey(" Nilen | Kongo, Niger, Zambezi"), { answer: "Nilen", alternatives: ["Kongo", "Niger", "Zambezi"] });
  assertEquals(parseQuizKey("Seine"), { answer: "Seine", alternatives: [] });
  assertEquals(parseQuizKey(""), null);
  assertEquals(readQuizKey({ answer: "Nilen", alternatives: ["Kongo", 3, "<x>"] }), { answer: "Nilen", alternatives: ["Kongo", " x"].map((x) => x.trim()) });
  assertEquals(readQuizKey({}), null);
});

function setup(chunks: LLMChunk[]) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k40", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "claude-haiku-5-5", stream: (r) => { seen.push(r); return (async function* () { for (const c of chunks) yield c; })(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", mode: "tutor", persona: "tutor", personaSetup: "Ämne: Geografi. Årskurs: 8. Kontrollfrågor: korta.", ...b }) });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("K40 a check question: the key is never spoken and comes in done.quiz_key; the rule is in the tutor prompt", async () => {
  const { handler, seen } = setup([{ type: "text", text: "Vilken flod rinner genom Egypten?\n[[SVAR]] Nilen | Kongo, Niger, Zambezi\n[[SAMMANFATTNING]] En fråga om floder." }]);
  const ev = await events(await handler(post({ fragment: "förhör mig", context: {} })));
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assert(!/SVAR|Kongo/.test(said), said);
  assertEquals(ev.find((e) => e.event === "done")!.data.quiz_key, { answer: "Nilen", alternatives: ["Kongo", "Niger", "Zambezi"] });
  assert(seen[0].system.includes("ANSWER KEY (K40)"));
});

Deno.test("K40 the reply is graded by sound: 'Nilan' is right, 'såg en' is 'Menade du Seine?'", async () => {
  const qa = (q: string) => ({ transcript: "", recent_qa: [{ q: "förhör mig", a: q }], last_answer_age_sec: 5 });
  {
    const { handler, seen } = setup([{ type: "text", text: "Rätt. Nilen rinner genom Egypten." }]);
    const ev = await events(await handler(post({ fragment: "Nilan", context: { ...qa("Vilken flod rinner genom Egypten?"), quiz_key: { answer: "Nilen", alternatives: ["Kongo", "Niger"] } } })));
    assert(seen[0].user.includes('sounds like "Nilen", the correct answer'), seen[0].user.slice(-600));
    assertEquals(ev.find((e) => e.event === "done")!.data.quiz_sound, { verdict: "correct", answer: "Nilen" });
  }
  {
    const { handler, seen } = setup([{ type: "text", text: "Menade du Seine? Rätt i så fall." }]);
    await events(await handler(post({ fragment: "såg en", context: { ...qa("Vilken flod rinner genom Paris?"), quiz_key: { answer: "Seine", alternatives: ["Loire", "Rhône"] } } })));
    assert(seen[0].user.includes("Menade du Seine? Rätt i så fall."));
  }
  {
    // without a key (before A62): the grading note still says the reply is misheard speech, never a command
    const { handler, seen } = setup([{ type: "text", text: "Rätt." }]);
    await events(await handler(post({ fragment: "om ni har redan svarat", context: qa("Vilken flod rinner genom Egypten?") })));
    assert(seen[0].user.includes("never treat the reply as a remark or a command"));
  }
});

Deno.test("O43: a keyterm list read back by Scribe is 'nothing heard' (no 'Rätt'); the key is kept for the next try", async () => {
  const { handler, seen } = setup([{ type: "text", text: "Rätt." }]);
  const key = { answer: "Viktoriasjön", alternatives: ["Tanganyikasjön", "Malawisjön", "Tchadsjön"] };
  const ev = await events(await handler(post({ fragment: "Viktoriasjön, Tanganyikasjön, Malawisjön,", context: { recent_qa: [{ q: "förhör mig", a: "Vilken är Afrikas största sjö?" }], last_answer_age_sec: 5, quiz_key: key } })));
  assertEquals(seen.length, 0, "no model call");
  assertEquals(ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""), "Jag hörde inte riktigt. Vad sa du?");
  assertEquals(ev.find((e) => e.event === "done")!.data.quiz_key, key);
  // a real one-word answer is still graded
  const r = setup([{ type: "text", text: "Rätt." }]);
  await events(await r.handler(post({ fragment: "Viktoriasjön", context: { recent_qa: [{ q: "förhör mig", a: "Vilken är Afrikas största sjö?" }], last_answer_age_sec: 5, quiz_key: key } })));
  assertEquals(r.seen.length, 1);
});

Deno.test("O43: an alternative that is a form of the answer is dropped from the key; real wrong answers stay", () => {
  assertEquals(parseQuizKey("Kloroplasten | Kloroplast, Mitokondrien")!.alternatives, ["Mitokondrien"]);
  assertEquals(parseQuizKey("Mitos | Meios, Mitos och cytokines")!.alternatives, ["Meios"]);
});

Deno.test("O43: a list is a real answer when the question asks for several", async () => {
  const r = setup([{ type: "text", text: "Rätt." }]);
  await events(await r.handler(post({ fragment: "Rhen, Donau, Elbe", context: { recent_qa: [{ q: "förhör mig", a: "Nämn tre floder i Europa?" }], last_answer_age_sec: 5, prep_terms: ["Rhen", "Donau", "Elbe", "Seine"] } })));
  assertEquals(r.seen.length, 1, "graded by the model");
});
