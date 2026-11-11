// Oscar O41 BLOCKER: the app sends Standardläge as mode "auto"; addressed phone requests must get the tools there.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { isAddressedAction, validatePhoneInput } from "./phonetools.ts";
import { rewriteLeadIn } from "./speech.ts";

const TA = ["calendar_add", "timer_start", "call_contact", "music_open", "reminder_add"];
function setup(chunks: LLMChunk[]) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k41", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "claude-haiku-5-5", stream: (r) => { seen.push(r); return (async function* () { for (const c of chunks) yield c; })(); } },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", context: {}, mode: "auto", tools_available: TA, ...b }) });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("O41 + O42: in Auto only requests addressed to Lumen are actions", () => {
  for (const t of ["Lumen, ring mamma", "Lumen, sätt en timer på fem minuter", "Lumen, kan du spela lite musik",
    "Lumen, kör lite Håkan Hellström", "Lumen, sätt på lite musik av Veronica Maggio", "okej Lumen, påminn mig om läxan"]) assert(isAddressedAction(t), t);
  // O42: Auto hears everyone; without the wake word nothing is done (a friend saying "ring mamma" to someone else)
  for (const t of ["ring mamma", "sätt en timer på tio minuter", "mamma ringde nyss", "igår sa hon att jag skulle ringa mamma",
    "vi ska spela teater", "vad är en timer", "läraren sa att vi ska sätta en timer"]) assert(!isAddressedAction(t), t);
  assert(isAddressedAction("sätt en timer", true), "the app's voice instruction counts as addressed");
  assertEquals(validatePhoneInput("call_contact", { number: "112" }, "Lumen, ring 112"), { number: "112" });
});

Deno.test("O42: help lines and plain music are recognised for the code's own call", async () => {
  const { helpLineCall, plainMusicRequest } = await import("./phonetools.ts");
  assertEquals([helpLineCall("ring Bris"), helpLineCall("Lumen, ring självmordslinjen"), helpLineCall("ring 1177"), helpLineCall("kan du ringa 112")],
    ["116111", "90101", "1177", "112"]);
  assertEquals(helpLineCall("vad är Bris"), null);
  assertEquals(helpLineCall("ring mamma"), null);
  assertEquals([plainMusicRequest("spela musik"), plainMusicRequest("Lumen, spela lite musik"), plainMusicRequest("sätt på musik av Veronica Maggio")],
    ["musik", "musik", "Veronica Maggio"]);
  assertEquals(plainMusicRequest("vilken musik spelar de"), null);
});

Deno.test("O42: 'ring Bris' where the model does nothing: the code sends call_contact 116111", async () => {
  const { handler } = setup([{ type: "text", text: "" }]);
  const ev = await events(await handler(post({ fragment: "ring Bris", mode: "push_to_talk" })));
  const tc = ev.find((e) => e.event === "tool_call")!;
  assertEquals([tc.data.name, tc.data.input, tc.data.confirm], ["call_contact", { number: "116111" }, null]);
  assertEquals(ev.find((e) => e.event === "done")!.data.tool_pending, true);
  const m = setup([{ type: "text", text: "Jag öppnar musikappen." }]);
  const ev2 = await events(await m.handler(post({ fragment: "Lumen, spela musik", mode: "auto" })));
  assertEquals(ev2.find((e) => e.event === "tool_call")?.data.input, { query: "musik" }, "what was said is now true");
});

Deno.test("O41: Standardläge (auto) offers the phone tools for 'Lumen, sätt en timer…' and runs the tool round", async () => {
  const call: LLMChunk = { type: "tool_use", id: "toolu_t", name: "timer_start", input: { seconds: 300 } };
  const { handler, seen } = setup([call]);
  const ev = await events(await handler(post({ fragment: "Lumen, sätt en timer på fem minuter" })));
  assertEquals(ev.find((e) => e.event === "tool_call")?.data.name, "timer_start");
  assert((seen[0].tools as { name: string }[]).some((t) => t.name === "timer_start"));
  const r2 = setup([{ type: "text", text: "Klart, timern går." }]);
  const ev2 = await events(await r2.handler(post({
    fragment: "Lumen, sätt en timer på fem minuter",
    tool_round: { call: { id: "toolu_t", name: "timer_start", input: { seconds: 300 } }, status: "ok", result: { ok: true } },
  })));
  assert(r2.seen[0].messages, "the tool round messages are sent");
  assertEquals(ev2.filter((e) => e.event === "delta").map((e) => e.data.text).join(""), "Klart, timern går.");
  // overheard: no tools in auto
  const s3 = setup([{ type: "text", text: "Hej." }]);
  await events(await s3.handler(post({ fragment: "läraren sa att vi ska sätta en timer" })));
  assert(!((s3.seen[0]?.tools ?? []) as { name: string }[]).some((t) => t.name === "timer_start"));
});

Deno.test("O41: a meta sentence about the request is never spoken first", () => {
  assertEquals(rewriteLeadIn("The request is to play music, so I'll open the music app with a lofi search.", "kör lofi"), "");
  assertEquals(rewriteLeadIn("Det är en statement, inte en fråga eller uppgift, så jag svarar kort och vänligt.", "att spela teater är roligt"), "");
  assertEquals(rewriteLeadIn("Det är en fråga om vem Alexander Graham Bell ringde till först.", "x"), "");
  assertEquals(rewriteLeadIn("Det här är en musikförfrågan, så jag öppnar musikappen med lofi.", "kör lofi"), "");
  assertEquals(rewriteLeadIn("Det låter kul!", "x"), "Det låter kul!");
});

Deno.test("O41: digits said as words count as said (B6 guard), articles do not", async () => {
  const { spokenDigits } = await import("./phonetools.ts");
  assertEquals(spokenDigits("ring noll sju tre, fyra fem sex, sjuttioåtta nittio"), "0734567890");
  assertEquals(validatePhoneInput("call_contact", { number: "073-456 78 90" }, "ring noll sju tre, fyra fem sex, sjuttioåtta nittio"), { number: "073-456 78 90" });
  assertEquals(validatePhoneInput("call_contact", { number: "0701234567" }, "ring en kompis"), null);
});

Deno.test("O41: 'ett' next to numbers is a digit", async () => {
  const { spokenDigits } = await import("./phonetools.ts");
  assertEquals(spokenDigits("ring noll åtta, ett två tre fyra fem sex sju"), "081234567");
  assertEquals(spokenDigits("ring noll sju noll, ett två tre, fyrtiofem sextiosju"), "0701234567");
  assertEquals(spokenDigits("ring en kompis"), "");
});

Deno.test("O41: +46 written by the model is the 0 the user said", () => {
  assertEquals(validatePhoneInput("call_contact", { number: "+46701234567" }, "Lumen, ring noll sju noll, ett två tre, fyrtiofem sextiosju"), { number: "0701234567" });
  assertEquals(validatePhoneInput("call_contact", { number: "+46701234567" }, "ring mamma"), null);
});

Deno.test("O41: with phone tools in Swedish, the model's English reasoning is not spoken", async () => {
  const { AnswerPost } = await import("./speech.ts");
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, dropEnglish: true });
  const out = p.push("The user asks to call a friend, but gave no name. I need a name to call, so I should ask who. Vem vill du att jag ska ringa? ") + p.finish();
  assertEquals(out.trim(), "Vem vill du att jag ska ringa?");
});

Deno.test("O41: a question about a number never starts a call", () => {
  assertEquals(validatePhoneInput("call_contact", { name: "pappa" }, "vad är numret till pappa"), null);
  assertEquals(validatePhoneInput("call_contact", { name: "mamma" }, "vad har mamma för nummer"), null);
  assertEquals(validatePhoneInput("call_contact", { name: "pappa" }, "ring pappa, vad är numret till honom förresten"), { name: "pappa" });
});

Deno.test("O41: a phone request that ends in nothing gets one Swedish question, not silence", async () => {
  const { handler } = setup([{ type: "text", text: "The user asks to call a friend, but gave no name. I need a name to call, so I should ask who." }]);
  const ev = await events(await handler(post({ fragment: "ring en kompis", mode: "push_to_talk" })));
  assertEquals(ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("").trim(), "Vem vill du att jag ska ringa?");
});

Deno.test("O41: a short English note is dropped in the tool path; Swedish with English names stays", async () => {
  const { AnswerPost } = await import("./speech.ts");
  const p = new AnswerPost({ previousAnswers: [], trimQuestion: false, dropEnglish: true });
  const out = p.push("A brief reply is needed.\n\nVilken kompis vill du ringa? Spela The Weeknd nu. ") + p.finish();
  assertEquals(out.trim(), "Vilken kompis vill du ringa? Spela The Weeknd nu.");
});

Deno.test("O42: a stray crisis marker on a short phone command is ignored; a real crisis sign still gets the crisis answer", async () => {
  const s = setup([{ type: "text", text: "[[KRIS]]" }]);
  const ev = await events(await s.handler(post({ fragment: "Lumen, spela musik", mode: "auto" })));
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assert(!/tungt|Självmordslinjen|112/.test(said), said);
  assertEquals(ev.find((e) => e.event === "tool_call")?.data.name, "music_open");
  const c = setup([{ type: "text", text: "Hej." }]);
  const ev2 = await events(await c.handler(post({ fragment: "Lumen, ring mamma, jag vill inte leva längre", mode: "auto" })));
  const said2 = ev2.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assert(/112|Självmordslinjen|90101|nittio/i.test(said2), said2);
});
