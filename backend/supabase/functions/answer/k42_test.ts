// K42.3: the asked length reaches the model, raises the limits and turns the short-first two-level answer off.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMRequest } from "./llm/types.ts";

function setup() {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k42", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "claude-haiku-5-5", stream: (r) => { seen.push(r); return (async function* () { yield { type: "text" as const, text: "Fotosyntes är när växter bildar socker." }; })(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (fragment: string) => new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode: "auto", language: "sv", two_level: true, context: { transcript: fragment } }) });

Deno.test("K42.3 'hundra ord eller mer': note, larger limits, no two-level", async () => {
  const { handler, seen } = setup();
  await (await handler(post("Förklara fotosyntes med hundra ord eller mer"))).text();
  assert(seen[0].user.includes("at least 100 words"), seen[0].user.slice(-400));
  assert(!seen[0].system.includes("[[MER]]"), "no two-level rule");
  assert((seen[0].maxTokens ?? 0) >= 400, String(seen[0].maxTokens));
  const r = setup();
  await (await r.handler(post("Förklara fotosyntes"))).text();
  assertEquals(r.seen[0].user.includes("LENGTH (K42)"), false);
});

import { complaintAnswer, isComplaint } from "./complaint.ts";
import { withQaLog } from "./qalog.ts";
Deno.test("K42.4 a complaint about the app: honest answer in code, no promise, marked in qa_log", async () => {
  for (const q of ["varför upprepar du", "Varför svarar du inte när jag pratar med dig?", "Lumen varför upprepar du dig", "du lyssnar inte", "sluta upprepa", "varför säger du samma sak", "du hörde fel"]) assert(isComplaint(q), q);
  for (const q of ["varför upprepar man ett experiment", "varför svarar inte min kompis", "hur fungerar ett eko", "upprepa frågan", "varför är himlen blå"]) assert(!isComplaint(q), q);
  assert(!/ska inte|kommer inte|lovar/.test(complaintAnswer(true) + complaintAnswer(false)));
  const { handler, seen } = setup();
  const rows: Record<string, unknown>[] = [];
  const h = withQaLog(handler, (r) => { rows.push(r as unknown as Record<string, unknown>); return Promise.resolve(); }, (p) => void p);
  const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment: "varför upprepar du", mode: "auto", language: "sv", qa_log: true, context: {} }) }));
  const text = await res.text();
  assert(text.includes("Jag har sparat det så att det kan rättas"), text);
  assertEquals(seen.length, 0, "no model call");
  await new Promise((r) => setTimeout(r, 20));
  assertEquals(rows[0]?.kind, "complaint");
});

Deno.test("K42.5 a lone 'utveckla' after an answer: unsure or too short = silence; sure and long enough = carried out", async () => {
  const recent = [{ q: "vad är fotosyntes", a: "Fotosyntes är när växter bildar socker av ljus." }];
  const send = (conf?: number, ms?: number, fragment = "utveckla") =>
    new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode: "auto", language: "sv", context: { transcript: fragment, recent_qa: recent, ...(conf !== undefined ? { stt_confidence: conf } : {}), ...(ms !== undefined ? { utterance_ms: ms } : {}) } }) });
  // "jaha"/"ja"/"aha"/"okej" misheard as "utveckla": short (200-330 ms) or unsure (< 0.85): 20 combinations
  let asCommand = 0;
  for (const [c, ms] of [[0.4, 300], [0.6, 250], [0.7, 330], [0.8, 280], [0.84, 600], [0.5, 900], [0.95, 200], [0.99, 250], [0.9, 300], [0.97, 330]].flatMap((x) => [x, [x[0] * 0.95, x[1]]])) {
    const { handler, seen } = setup();
    await (await handler(send(c, ms))).text();
    if (seen.length) asCommand++;
  }
  assertEquals(asCommand, 0, "jaha as utveckla: 0/20");
  // a real "utveckla": sure and long enough
  let done = 0;
  for (let i = 0; i < 20; i++) {
    const { handler, seen } = setup();
    await (await handler(send(0.86 + (i % 14) / 100, 420 + i * 20))).text();
    if (seen.length) done++;
  }
  assert(done >= 19, `utveckla ${done}/20`);
  // without the app's data nothing changes; "Lumen, utveckla" is always carried out
  const a = setup(); await (await a.handler(send())).text(); assertEquals(a.seen.length, 1);
  const b = setup(); await (await b.handler(send(0.3, 100, "Lumen, utveckla"))).text(); assertEquals(b.seen.length, 1);
});

Deno.test("O51 after K42: more complaints, 'vad heter appen', 'utveckla det' and a word cap", async () => {
  for (const q of ["varför sa du samma sak två gånger", "du är så dålig", "appen är buggig", "du missförstod mig", "sluta svara på allt jag säger", "varför svarade du på engelska", "Lumen, du förstår inte"]) assert(isComplaint(q), q);
  for (const q of ["varför sa du att Vänern är störst", "du är bäst", "appen för matte", "vad betyder missförstånd"]) assert(!isComplaint(q), q);
  const { selfAnswer } = await import("./self.ts");
  assert(selfAnswer("Lumen, vad heter appen")!.startsWith("Jag heter EarMind"));
  const { weakLoneCommand } = await import("./lonecmd.ts");
  assert(weakLoneCommand("utveckla det", { stt_confidence: 0.45, utterance_ms: 280, recent_qa: [{}] }));
  const { lengthCaps } = await import("./asklength.ts");
  assertEquals(lengthCaps({ words: 20, atMost: true })!.maxWords, 20);
  assertEquals(lengthCaps({ words: 50 })!.maxWords, Math.round(50 * 1.15));
});

Deno.test("K42.3 the word cap passes whole sentences only and stops within it", async () => {
  const seen: LLMRequest[] = [];
  const long = Array.from({ length: 12 }, (_, i) => `Mening nummer ${["ett", "två", "tre", "fyra", "fem", "sex", "sju", "åtta", "nio", "tio", "elva", "tolv"][i]} har sju ord här.`).join(" ");
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k42b", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "claude-haiku-5-5", stream: (r) => { seen.push(r); return (async function* () { for (const w of long.split(/(?<= )/)) yield { type: "text" as const, text: w }; })(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  const res = await handler(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment: "Förklara fotosyntes med max trettio ord", mode: "push_to_talk", language: "sv", context: {} }) }));
  const said = (await res.text()).split("\n\n").filter((f) => f.startsWith("event: delta")).map((f) => JSON.parse(f.split("data: ")[1]).text).join("");
  const words = (said.match(/[\p{L}\d]+/gu) ?? []).length;
  assert(words <= 30 && words >= 21, `${words}: ${said}`);
  assert(/[.!?]\s*$/.test(said), said);
});

Deno.test("K44 'kan du …?', 'vad kan du göra?', 'vad är EarMind?' and help are answered from the list, without a model call", async () => {
  const ask = async (fragment: string, extra: Record<string, unknown> = {}) => {
    const { handler, seen } = setup();
    const t = await (await handler(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode: "auto", language: "sv", context: {}, ...extra }) }))).text();
    return { said: t.split("\n\n").filter((f) => f.startsWith("event: delta")).map((f) => JSON.parse(f.split("data: ")[1]).text).join(""), calls: seen.length };
  };
  assert((await ask("Kan du sätta en timer på tio minuter?")).said.startsWith("Ja"));
  assert((await ask("Kan du spela musik?")).said.startsWith("Ja"));
  assert((await ask("Kan du lägga in ett möte i min kalender?")).said.startsWith("Ja"));
  assert((await ask("Vad kan du göra?")).said.includes("AI-agent"));
  assert(/AI-agent/.test((await ask("Vad är EarMind?")).said));
  assert((await ask("Hur stänger jag av dig?")).said.includes("Stoppa"));
  assert((await ask("kan du skicka sms")).said.startsWith("Nej"));
  // with the wake word and the tool on the phone, a concrete request goes on to the model with the tool
  const r = await ask("Lumen, kan du sätta en timer på tio minuter", { tools_available: ["timer_start"] });
  assertEquals(r.calls, 1);
  // a real question is the model's
  assertEquals((await ask("kan du förklara fotosyntes")).calls, 1);
});

import { localClockAnswer, sayClock } from "./localclock.ts";
Deno.test("O52 (prio 1): the local time is said by code, right, for 5 phrasings and 3 times", () => {
  const times: [string, string][] = [
    ["2026-11-11T19:57:00Z", "Klockan är tre minuter i nio på kvällen, alltså tjugo och femtiosju."],
    ["2026-11-12T07:15:00Z", "Klockan är kvart över åtta på morgonen, alltså åtta och femton."],
    ["2026-07-01T12:30:00Z", "Klockan är halv tre på eftermiddagen, alltså fjorton och trettio."], // summer time
  ];
  for (const q of ["vad är klockan", "Lumen, vad är klockan?", "kan du säga vad klockan är", "vet du vad klockan är", "hur mycket är klockan nu"]) {
    for (const [iso, want] of times) assertEquals(localClockAnswer(q, new Date(iso)), want, `${q} ${iso}`);
  }
  for (const q of ["vad är klockan i Tokyo", "när börjar lektionen", "vad är en klocka"]) assertEquals(localClockAnswer(q, new Date()), null, q);
  assertEquals(sayClock(9, 25), "Klockan är fem i halv tio på morgonen, alltså nio och tjugofem.");
  assertEquals(sayClock(23, 45), "Klockan är kvart i tolv på kvällen, alltså tjugotre och fyrtiofem.");
});
