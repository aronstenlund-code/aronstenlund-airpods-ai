import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.8";
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

Deno.test("D36/D37: mode tutor, goals and commands are accepted, trimmed and defaulted", () => {
  const r = validateAnswerRequest({
    ...ok,
    mode: "tutor",
    goals: "  Kursen handlar om cellbiologi.  ",
    commands: [{ keyword: " mitos ", instruction: " förklara mitos " }],
  });
  assertEquals([r.mode, r.goals], ["tutor", "Kursen handlar om cellbiologi."]);
  assertEquals(r.commands, [{ keyword: "mitos", instruction: "förklara mitos" }]);
  const d = validateAnswerRequest(ok);
  assertEquals([d.goals, d.commands], ["", []]);
});

Deno.test("D37: goals / commands limits and shapes", () => {
  assertEquals(
    assertThrows(
      () => validateAnswerRequest({ ...ok, goals: "a".repeat(LIMITS.goals + 1) }),
      HttpError,
    ).status,
    413,
  );
  assertEquals(
    assertThrows(() =>
      validateAnswerRequest({
        ...ok,
        commands: Array(LIMITS.commands + 1).fill({ keyword: "a", instruction: "b" }),
      }), HttpError).status,
    413,
  );
  assertEquals(
    assertThrows(() =>
      validateAnswerRequest({
        ...ok,
        commands: [{ keyword: "a", instruction: "b".repeat(LIMITS.commandInstruction + 1) }],
      }), HttpError).status,
    413,
  );
  assertEquals(
    assertThrows(() =>
      validateAnswerRequest({
        ...ok,
        commands: [{ keyword: "k".repeat(LIMITS.commandKeyword + 1), instruction: "b" }],
      }), HttpError).status,
    413,
  );
  for (
    const bad of ["x", [{ keyword: "", instruction: "b" }], [{ keyword: "a" }], [null], [{
      keyword: 1,
      instruction: "b",
    }], { goals: 5 }]
  ) {
    const body = Array.isArray(bad) || typeof bad === "string"
      ? { ...ok, commands: bad }
      : { ...ok, ...bad };
    assertEquals(assertThrows(() => validateAnswerRequest(body), HttpError).status, 400);
  }
  assertEquals(
    assertThrows(() => validateAnswerRequest({ ...ok, mode: "exam" }), HttpError).status,
    400,
  );
});

Deno.test("D37: the largest legal request still fits the body limit", () => {
  const big = {
    ...ok,
    goals: "å".repeat(LIMITS.goals),
    commands: Array(LIMITS.commands).fill({
      keyword: "ö".repeat(60),
      instruction: "å".repeat(300),
    }),
    context: {
      transcript: "ä".repeat(LIMITS.transcript),
      recent_qa: Array(LIMITS.recentQa).fill({
        q: "å".repeat(400),
        a: "ö".repeat(LIMITS.qaAnswer),
      }),
      prep_terms: Array(LIMITS.prepTerms).fill("ä".repeat(60)),
    },
  };
  assert(new TextEncoder().encode(JSON.stringify(big)).length < LIMITS.bodyBytes);
});
