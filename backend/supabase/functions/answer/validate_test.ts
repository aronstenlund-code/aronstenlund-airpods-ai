import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import { LIMITS, readLimitedJson, validateAnswerRequest } from "./validate.ts";

const ok = { fragment: " fotosyntes ", mode: "auto", language: "sv" };

Deno.test("valid minimal request, defaults and trimming", () => {
  const r = validateAnswerRequest(ok);
  assertEquals(r.fragment, "fotosyntes");
  assertEquals(r.context, { transcript: "", recent_qa: [], prep_terms: [] });
});

Deno.test("rejects bad shapes with 400", () => {
  for (
    const bad of [
      null,
      [],
      "x",
      { ...ok, mode: "voice" },
      { ...ok, language: "de" },
      { ...ok, fragment: "  " },
      { ...ok, fragment: 5 },
      { ...ok, context: { recent_qa: "no" } },
      { ...ok, context: { prep_terms: [1] } },
    ]
  ) {
    const e = assertThrows(() => validateAnswerRequest(bad), HttpError);
    assertEquals(e.status, 400);
  }
});

Deno.test("rejects oversized fields with 413", () => {
  const cases = [
    { ...ok, fragment: "a".repeat(LIMITS.fragment + 1) },
    { ...ok, context: { transcript: "a".repeat(LIMITS.transcript + 1) } },
    { ...ok, context: { recent_qa: Array(LIMITS.recentQa + 1).fill({ q: "a", a: "b" }) } },
    { ...ok, context: { prep_terms: Array(LIMITS.prepTerms + 1).fill("a") } },
    { ...ok, context: { prep_terms: ["a".repeat(LIMITS.prepTerm + 1)] } },
  ];
  for (const c of cases) {
    assertEquals(assertThrows(() => validateAnswerRequest(c), HttpError).status, 413);
  }
});

Deno.test("body reader enforces the byte cap even without Content-Length", async () => {
  const big = new Request("http://x", {
    method: "POST",
    body: JSON.stringify({ a: "x".repeat(2000) }),
  });
  const e = await assertRejects(() => readLimitedJson(big, 500), HttpError);
  assertEquals(e.status, 413);
  const good = new Request("http://x", { method: "POST", body: '{"a":1}' });
  assertEquals(await readLimitedJson(good, 500), { a: 1 });
  const junk = new Request("http://x", { method: "POST", body: "{nope" });
  assertEquals((await assertRejects(() => readLimitedJson(junk, 500), HttpError)).status, 400);
});
