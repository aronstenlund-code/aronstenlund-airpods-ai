// K30 (D116): questions and answers to Aron's private log; masked; only with qa_log: true; never demo or crisis.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { maskNumbers, type QaRow, withQaLog } from "./qalog.ts";

Deno.test("K30 masking: personnummer, samordningsnummer, cards, accounts, IBAN and long digit runs; ordinary numbers stay", () => {
  const m = maskNumbers;
  assertEquals(m("mitt personnummer är 090314-1234"), "mitt personnummer är [personnummer]");
  assertEquals(m("20090314-1234 och 0903141234"), "[personnummer] och [personnummer]");
  assertEquals(m("samordningsnummer 091374-1234"), "samordningsnummer [personnummer]");
  assertEquals(m("kortet 4111 1111 1111 1111 går ut"), "kortet [kortnummer] går ut");
  assertEquals(m("konto 8327-9 123 456 789"), "konto [kontonummer]");
  assertEquals(m("SE45 5000 0000 0583 9825 7466"), "[kontonummer]");
  assertEquals(m("ring 070-123 45 67"), "ring [nummer]");
  for (const t of ["provet är 13 november 2026", "x = 7", "1914 till 1918", "kl 08.15", "12 345 invånare", "3,14"]) {
    assertEquals(m(t), t, t);
  }
});

const sse = (...frames: [string, unknown][]) =>
  new Response(frames.map(([e, d]) => `event: ${e}\ndata: ${JSON.stringify(d)}\n\n`).join(""), {
    headers: { "content-type": "text/event-stream" },
  });
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(b) });

async function run(body: Record<string, unknown>, res: () => Response) {
  const rows: QaRow[] = [];
  const pending: Promise<unknown>[] = [];
  const h = withQaLog(() => Promise.resolve(res()), (r) => {
    rows.push(r);
    return Promise.resolve();
  }, (p) => pending.push(p));
  const out = await (await h(post(body))).text();
  await Promise.all(pending);
  return { rows, out };
}

Deno.test("K30 wrapper: a logged answer with mode and persona; the app still gets the same stream", async () => {
  const stream = () => sse(["meta", { is_question: true }], ["delta", { text: "Den började " }], ["delta", { text: "1789." }], ["more_delta", { text: "Mer om det." }], ["done", { answered: true }]);
  const { rows, out } = await run({ fragment: "när började franska revolutionen 090314-1234", mode: "tutor", persona: "tutor", qa_log: true }, stream);
  assertEquals(rows, [{ mode: "tutor", persona: "tutor", question: "när började franska revolutionen [personnummer]", answer: "Den började 1789.\n\n[utvecklat] Mer om det." }]);
  assertEquals(out, await stream().text());
});

Deno.test("K30 wrapper: nothing without qa_log, from the demo, for crisis, silence or a retracted answer", async () => {
  const ok = () => sse(["delta", { text: "Svar." }], ["done", { answered: true }]);
  assertEquals((await run({ fragment: "fråga", mode: "auto" }, ok)).rows, [], "no flag");
  assertEquals((await run({ fragment: "fråga", mode: "text", source: "demo", qa_log: true }, ok)).rows, [], "demo");
  assertEquals((await run({ fragment: "jag vill dö", mode: "auto", qa_log: true }, () =>
    sse(["meta", { safety: "crisis" }], ["delta", { text: "Det du säger låter riktigt tungt … Självmordslinjen" }], ["done", { answered: true }]))).rows, [], "crisis");
  assertEquals((await run({ fragment: "hej", mode: "auto", qa_log: true }, () => sse(["meta", { is_question: false }], ["done", { answered: false }]))).rows, [], "silence");
  assertEquals((await run({ fragment: "x", mode: "auto", qa_log: true }, () => sse(["delta", { text: "a" }], ["done", { answered: true, retract: true }]))).rows, [], "retracted");
  const sug = await run({ fragment: "", mode: "tutor", persona: "social", qa_log: true }, () => sse(["suggestions", ["A.", "B."]], ["done", { answered: true }]));
  assertEquals(sug.rows, [], "an empty fragment is not a question");
  const s2 = await run({ fragment: "vad säger jag nu", mode: "tutor", persona: "social", qa_log: true }, () => sse(["suggestions", ["A.", "B."]], ["done", { answered: true }]));
  assertEquals(s2.rows[0].answer, "A. / B.");
});
