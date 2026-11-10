import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { CRISIS_OTHER, CRISIS_SELF, crisisLevel } from "./crisis.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";

import CASES from "../../../../scripts/k21-crisis-cases.json" with { type: "json" };

Deno.test("K21 code layer: every crisis case is strong or weak (never nothing); no everyday case is strong", () => {
  const pos = [...CASES.positive, ...CASES.positive_o17, ...CASES.positive_o17b, ...CASES.positive_o17c];
  const neg = [...CASES.negative, ...CASES.negative_o17, ...CASES.negative_o17b, ...CASES.negative_o17c];
  assertEquals(pos.filter((t: string) => !crisisLevel(t)), [], "missed by both layers");
  assertEquals(neg.filter((t: string) => crisisLevel(t) === "strong"), [], "strong false alarms");
  const strong = pos.filter((t: string) => crisisLevel(t) === "strong").length;
  assert(strong >= pos.length - 4, `strong ${strong}/${pos.length}`); // K34: "inte vara kvar på måndag", "inte vara med längre" are weak on purpose (the check decides)
});

/** A fake model: the yes/no check answers `check`; every other call returns a not-a-question meta line. */
function h(check: string | Error = "nej") {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k21", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "s",
      stream: (r) => {
        seen.push(r);
        const isCheck = r.system.startsWith("You check ONE utterance");
        return (async function* (): AsyncGenerator<LLMChunk> {
          if (isCheck && check instanceof Error) throw check;
          yield { type: "text", text: isCheck ? String(check) : '{"is_question":false,"reconstructed_question":"x","confidence":0.2}\n' };
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", context: {}, ...b }) });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}
const said = (ev: { event: string; data: Record<string, unknown> }[]) => ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");

Deno.test("K21 strong: Auto, Frågor, Provläge, the demo: the warm answer at once, no model call", async () => {
  for (const b of [
    { fragment: "Jag mår skit och orkar inte leva.", mode: "auto" },
    { fragment: "jag orkar inte leva", mode: "push_to_talk" },
    { fragment: "jag vill dö", mode: "tutor", persona: "tutor", persona_setup: "Prov i Biologi. Årskurs: Åk 9." },
    { fragment: "jag vill inte leva mer", mode: "text", source: "demo" },
  ]) {
    const { handler, seen } = h();
    const ev = await events(await handler(post(b)));
    assertEquals(said(ev), CRISIS_SELF, JSON.stringify(b));
    assertEquals(seen.length, 0, "decided in code");
    assert(said(ev).includes("ett ett två") && said(ev).includes("nittio ett noll ett") && said(ev).includes("ett ett sex ett ett ett"));
    assertEquals(ev.find((e) => e.event === "done")!.data.summary, null, "never stored");
  }
});

Deno.test("K21 weak: the small model's 'ja' gives the answer, 'nej' the normal path, a failed check the answer", async () => {
  const yes = h("ja");
  const ev = await events(await yes.handler(post({ fragment: "jag vill bara försvinna", mode: "auto" })));
  assertEquals(said(ev), CRISIS_SELF);
  assertEquals(yes.seen.length, 1, "only the check");
  const no = h("nej");
  await events(await no.handler(post({ fragment: "jag vill inte leva i Stockholm när jag blir stor", mode: "push_to_talk" })));
  assertEquals(no.seen.length, 2, "check, then the normal answer");
  const fail = h(new Error("timeout"));
  assertEquals(said(await events(await fail.handler(post({ fragment: "jag vill bara försvinna", mode: "auto" })))), CRISIS_SELF, "fail safe");
});

Deno.test("K21 when someone else says it (Socialt): a line to the user about how to help", async () => {
  const { handler } = h();
  const ev = await events(await handler(post({
    fragment: "",
    mode: "tutor",
    persona: "social",
    social: { style: "social", trigger: "other_spoke", transcript: [{ speaker: "Talare 1", text: "ärligt talat orkar jag inte leva längre" }], speaker: "Talare 1" },
  })));
  const sug = ev.find((e) => e.event === "suggestions");
  assert(sug && JSON.stringify(sug.data).includes(CRISIS_OTHER.slice(0, 30)), JSON.stringify(ev.map((e) => e.event)));
});

Deno.test("K21 an ordinary sentence without first person and risk words goes to the model as before", async () => {
  const { handler, seen } = h();
  await events(await handler(post({ fragment: "när dog Gustav Vasa", mode: "push_to_talk" })));
  assertEquals(seen.length, 1);
  assert(!seen[0].system.startsWith("You check ONE utterance"));
});

Deno.test("K21 'min kompis säger att han inte vill leva' gives the line on how to help someone else", async () => {
  const { handler } = h();
  const ev = await events(await handler(post({ fragment: "min kompis säger att han inte vill leva längre", mode: "push_to_talk" })));
  assertEquals(said(ev), CRISIS_OTHER);
});

/** A fake model that answers `reply` to everything except the yes/no check ("nej"). */
function model(reply: string) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k23", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "s",
      stream: (r) => {
        seen.push(r);
        const isCheck = r.system.startsWith("You check ONE utterance");
        return (async function* (): AsyncGenerator<LLMChunk> {
          const t = isCheck ? "nej" : reply;
          for (let k = 0; k < t.length; k += 6) yield { type: "text", text: t.slice(k, k + 6) };
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
  });
  return { handler, seen };
}

Deno.test("K23 the model's own layer: [[KRIS]] in a direct mode gives the crisis answer, also in Provläge", async () => {
  for (const b of [
    { fragment: "jag tänker på något som jag inte vill säga", mode: "push_to_talk" },
    { fragment: "jag tänker på något som jag inte vill säga", mode: "tutor", persona: "tutor", persona_setup: "Prov i Biologi. Årskurs: Åk 9." },
  ]) {
    const { handler } = model("[[KRIS]]");
    const ev = await events(await handler(post(b)));
    assertEquals(said(ev), CRISIS_SELF, b.mode);
    assertEquals(ev.find((e) => e.event === "done")!.data.safety, "crisis");
    assertEquals(ev.find((e) => e.event === "done")!.data.summary, null);
  }
});

Deno.test("K23 Auto: the self_harm_risk flag gives the crisis answer even when is_question is false", async () => {
  const { handler } = model('{"is_question":false,"self_harm_risk":true,"reconstructed_question":"x","confidence":0.9}\n');
  const ev = await events(await handler(post({ fragment: "jag har skrivit ett brev som ingen får läsa än", mode: "auto" })));
  assertEquals(said(ev), CRISIS_SELF);
  assert(ev.some((e) => e.event === "meta" && e.data.safety === "crisis"));
});

Deno.test("K23 a late [[KRIS]] is never read aloud; the crisis answer follows", async () => {
  const { handler } = model("Det låter tungt. [[KRIS]]");
  const out = said(await events(await handler(post({ fragment: "allt känns meningslöst nu", mode: "push_to_talk" }))));
  assert(!out.includes("[[") && out.includes("nittio ett noll ett"), out);
});

Deno.test("K23 an ordinary answer is not held or changed by the marker check", async () => {
  const { handler } = model("Fotosyntes är när växter gör socker av ljus.");
  assertEquals(said(await events(await handler(post({ fragment: "vad är fotosyntes", mode: "push_to_talk" })))), "Fotosyntes är när växter gör socker av ljus.");
});
