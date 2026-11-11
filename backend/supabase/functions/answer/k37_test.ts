// K37 (D126): "Mina svar": a saved answer is said word for word when the question asks the same thing; false hits avoided.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { parseSavedCheck, rankSaved, readSavedAnswers, type SavedAnswer } from "./savedanswers.ts";

const BANK = JSON.parse(Deno.readTextFileSync(new URL("../../../testdata/k37-saved-answers.json", import.meta.url))) as {
  saved: SavedAnswer[];
  heard: { t: string; expect: string | null; kind: string }[];
};

Deno.test("K37 code layer: never a sure false hit on the bank; most paraphrases sure, the rest go to the check", () => {
  let sureOk = 0, toCheck = 0;
  const pos = BANK.heard.filter((h) => h.expect);
  for (const h of BANK.heard) {
    const r = rankSaved(h.t, BANK.saved, true);
    if (!h.expect) {
      assert(!r[0]?.sure, `false sure hit: "${h.t}" -> ${r[0]?.item.id}`);
      continue;
    }
    assert(!r[0]?.sure || r[0].item.id === h.expect, `wrong sure hit: "${h.t}" -> ${r[0]?.item.id}`);
    if (r[0]?.sure) sureOk++;
    else if (r.slice(0, 3).some((c) => c.item.id === h.expect)) toCheck++;
  }
  assertEquals(sureOk + toCheck, pos.length, "every paraphrase is either sure or among the three the check sees");
  assert(sureOk >= 20, `sure ${sureOk}/${pos.length}`);
});

Deno.test("K37 statements in hands-free mode are never matched; push-to-talk need not be phrased as a question", () => {
  assertEquals(rankSaved("fotosyntesen sker i kloroplasterna", BANK.saved, true), []);
  assertEquals(rankSaved("cellandning", BANK.saved, true), []);
  assert(rankSaved("cellandning", BANK.saved, false).length > 0);
});

Deno.test("K37 saved_answers: malformed entries dropped, capped; the check reply parsed strictly", () => {
  const s = readSavedAnswers([{ id: "a1", q: "Vad är pi?", a: "Ungefär 3,14." }, { id: "", q: "x", a: "y" }, { id: "b<1>", q: "x", a: "y" }, "nope", { id: "c", q: "q" }]);
  assertEquals(s, [{ id: "a1", q: "Vad är pi?", a: "Ungefär 3,14." }]);
  assertEquals(readSavedAnswers(Array.from({ length: 99 }, (_, i) => ({ id: `x${i}`, q: "q", a: "a" }))).length, 60);
  assertEquals([parseSavedCheck("2", 3), parseSavedCheck("0", 3), parseSavedCheck("4", 3), parseSavedCheck("kanske 1", 3), parseSavedCheck(" 1.", 3)], [1, null, null, null, 0]);
});

function setup(chunks: LLMChunk[]) {
  const seen: LLMRequest[] = [];
  const usage: { model?: unknown }[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k37", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "claude-haiku-5-5",
      stream: (r) => {
        seen.push(r);
        return (async function* () {
          for (const c of chunks) yield c;
        })();
      },
    },
    recordUsage: (r) => {
      usage.push(r);
    },
    config: DEFAULT_CONFIG,
  });
  return { handler, seen, usage };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ language: "sv", context: {}, mode: "tutor", saved_answers: BANK.saved, ...b }),
  });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("K37 a sure match is answered word for word without any model call (digits spoken, exact text in done)", async () => {
  const { handler, seen, usage } = setup([{ type: "text", text: "MODEL" }]);
  const ev = await events(await handler(post({ fragment: "Lumen, när började första världskriget?" })));
  assertEquals(seen.length, 0);
  const text = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assertEquals(text, "Första världskriget började nittonhundrafjorton.");
  const done = ev.find((e) => e.event === "done")!.data;
  assertEquals(done.saved_answer, { id: "his1", text: "Första världskriget började 1914.", via: "code" });
  assertEquals(usage[0].model, "saved_answer");
});

Deno.test("K37 a maybe asks the small model once; its number picks the answer, 0 gives the normal answer", async () => {
  {
    const { handler, seen } = setup([{ type: "text", text: "1" }]);
    const ev = await events(await handler(post({ fragment: "när bröt första världskriget ut" })));
    assertEquals(seen.length, 1);
    assert(seen[0].user.includes("<heard>när bröt första världskriget ut</heard>"));
    assertEquals(seen[0].maxTokens, 4);
    assertEquals(ev.find((e) => e.event === "done")!.data.saved_answer.id, "his1");
  }
  {
    const { handler, seen } = setup([{ type: "text", text: "0" }]);
    const ev = await events(await handler(post({ fragment: "när slutade första världskriget" })));
    assert(seen.length >= 2, "the check, then the normal answer");
    assertEquals(ev.find((e) => e.event === "done")?.data.saved_answer, undefined);
  }
});

Deno.test("K37 no saved answer in the demo, in Socialt/Rizz, for the student's own answer, or without saved_answers", async () => {
  for (const extra of [
    { source: "demo", mode: "text" },
    { persona: "social", social: { style: "social", trigger: "other_spoke", transcript: [{ speaker: "other", text: "hej" }] } },
    { turn: "user_answer" },
    { saved_answers: [] },
  ]) {
    const { handler } = setup([{ type: "text", text: "Ett svar." }]);
    const ev = await events(await handler(post({ fragment: "när började första världskriget", ...extra })));
    assertEquals(ev.find((e) => e.event === "done")?.data.saved_answer, undefined, JSON.stringify(extra));
  }
});

Deno.test("K37 Oscar O39 hold-out (written before reading the code, never used to tune): no sure false hit", () => {
  const o = JSON.parse(Deno.readTextFileSync(new URL("../../../../scripts/qa/o39_k37_cases.json", import.meta.url))) as {
    saved: Record<string, SavedAnswer[]>;
    cases: { id: string; exam: string; ask: string; expect: string | null }[];
  };
  for (const c of o.cases) {
    const r = rankSaved(c.ask, o.saved[c.exam] ?? [], true);
    if (r[0]?.sure) assertEquals(r[0].item.id, c.expect, `${c.id}: "${c.ask}" -> ${r[0].item.id}`);
  }
});
