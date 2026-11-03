import { assertEquals } from "jsr:@std/assert@1.0.8";
import { findObjectEnd, ResponseParser, sanitizeForSpeech } from "./parser.ts";

const HEADER =
  '{"is_question":true,"reconstructed_question":"Vad är fem plus två?","confidence":0.97}';

function run(mode: "auto" | "push_to_talk" | "text", chunks: string[], fragment = "fem plus två") {
  const p = new ResponseParser(mode, fragment, 0.6);
  const ev = chunks.flatMap((c) => p.push(c));
  ev.push(...p.finish());
  return { ev, p };
}
const text = (ev: ReturnType<typeof run>["ev"]) =>
  ev.filter((e) => e.type === "delta").map((e) => (e as { text: string }).text).join("");

Deno.test("meta first, then deltas, regardless of chunking", () => {
  const full = `${HEADER}\nFem plus två är sju.`;
  for (const size of [1, 2, 3, 7, 1000]) {
    const chunks = [];
    for (let i = 0; i < full.length; i += size) chunks.push(full.slice(i, i + size));
    const { ev } = run("auto", chunks);
    assertEquals(ev[0].type, "meta", `size ${size}`);
    assertEquals(ev.filter((e) => e.type === "meta").length, 1);
    assertEquals(text(ev), "Fem plus två är sju.", `size ${size}`);
  }
});

Deno.test("meta fields are parsed and confidence clamped", () => {
  const { ev } = run("auto", [
    '{"is_question":true,"reconstructed_question":" Q? ","confidence":7}\nA.',
  ]);
  const m = ev[0] as unknown as { meta: Record<string, unknown> };
  assertEquals(m.meta, {
    reconstructed_question: "Q?",
    confidence: 1,
    is_question: true,
    needs_confirmation: false,
  });
});

Deno.test("low confidence sets needs_confirmation", () => {
  const { p } = run("push_to_talk", [
    '{"is_question":true,"reconstructed_question":"Vad är roten ur hundra?","confidence":0.4}\nMenar du roten ur hundra?',
  ]);
  assertEquals(p.meta?.needs_confirmation, true);
});

Deno.test("auto mode with is_question=false emits only meta", () => {
  const { ev } = run("auto", [
    '{"is_question":false,"reconstructed_question":"","confidence":0.9}',
  ]);
  assertEquals(ev.length, 1);
  assertEquals(
    (ev[0] as { meta: { is_question: boolean; reconstructed_question: string } }).meta.is_question,
    false,
  );
  assertEquals(
    (ev[0] as { meta: { reconstructed_question: string } }).meta.reconstructed_question,
    "fem plus två",
    "falls back to the fragment",
  );
});

Deno.test("explicit modes ignore a model that says is_question=false", () => {
  for (const mode of ["push_to_talk", "text"] as const) {
    const { p } = run(mode, [
      '{"is_question":false,"reconstructed_question":"x","confidence":0.9}\nSvar.',
    ]);
    assertEquals(p.meta?.is_question, true);
  }
});

Deno.test("missing header: auto mode fails closed, explicit modes still answer", () => {
  const a = run("auto", ["Fem plus två är sju."]);
  assertEquals(a.p.meta?.is_question, false);
  assertEquals(a.p.headerFailed, true);
  const b = run("push_to_talk", ["Fem plus två är sju."]);
  assertEquals(b.p.meta?.is_question, true);
  assertEquals(text(b.ev), "Fem plus två är sju.");
});

Deno.test("invalid or truncated header does not throw", () => {
  const a = run("push_to_talk", ['{"is_question": tru\nSvar']);
  assertEquals(a.ev[0].type, "meta");
  const b = run("push_to_talk", ['{"is_question":true,"recon']);
  assertEquals(b.ev[0].type, "meta");
  assertEquals(b.p.headerFailed, true);
  const c = run("auto", []);
  assertEquals(c.ev.length, 1);
});

Deno.test("tolerates code fences and leading whitespace", () => {
  const { ev } = run("auto", ["\n```json\n" + HEADER + "\n```\nFem plus två är sju."]);
  assertEquals(ev[0].type, "meta");
  assertEquals(text(ev), "Fem plus två är sju.");
});

Deno.test("braces inside strings do not end the header early", () => {
  const h = '{"is_question":true,"reconstructed_question":"Vad betyder } här?","confidence":0.9}';
  assertEquals(findObjectEnd(h + "xyz"), h.length - 1);
  const { ev } = run("auto", [h + "\nSvar."]);
  assertEquals(
    (ev[0] as { meta: { reconstructed_question: string } }).meta.reconstructed_question,
    "Vad betyder } här?",
  );
  assertEquals(text(ev), "Svar.");
});

Deno.test("markdown/TTS-hostile characters are stripped from the answer", () => {
  assertEquals(sanitizeForSpeech("**Sju** `x` #1_a"), "Sju x 1a");
  const { ev } = run("push_to_talk", [HEADER + "\n**Sju.**"]);
  assertEquals(text(ev), "Sju.");
});
