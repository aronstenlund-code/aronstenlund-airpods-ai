import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import type { LLMChunk, LLMProvider, LLMRequest } from "../answer/llm/types.ts";
import { createProfileHandler, parseProfileReply } from "./handler.ts";

class FakeLLM implements LLMProvider {
  readonly name = "fake";
  readonly model = "fake-1";
  calls: LLMRequest[] = [];
  constructor(private reply: string) {}
  async *stream(req: LLMRequest): AsyncIterable<LLMChunk> {
    this.calls.push(req);
    yield { type: "text", text: this.reply };
    yield { type: "usage", inputTokens: 500, outputTokens: 300 };
  }
}
const post = (b: unknown) =>
  new Request("http://x/study-profile", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": "1.2.3.4" },
    body: JSON.stringify(b),
  });

Deno.test("D84 study profile: spoken text -> profile + terms; <now> for absolute dates", async () => {
  const llm = new FakeLLM(JSON.stringify({
    profile: { grade: "y9", course: null, subject: "Biologi", exam_date: "2026-11-13", no_exam: false, topic: null },
    terms: ["fotosyntes", "cellandning", "Fotosyntes", "evolution.", "ekosystem"],
  }));
  const h = createProfileHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: llm,
    now: () => new Date("2026-11-08T12:00:00Z"),
  });
  const r = await h(post({ text: "jag går i åk 9 och ska ha prov i biologi på fredag" }));
  assertEquals(r.status, 200);
  const j = await r.json();
  assertEquals(j.profile, { grade: "y9", course: null, subject: "Biologi", exam_date: "2026-11-13", no_exam: false, topic: null });
  assertEquals(j.terms, ["fotosyntes", "cellandning", "ekosystem"], "duplicates and sentences dropped");
  assert(llm.calls[0].user.includes("<now>söndag 8 november 2026"));
  assertEquals((await h(post({}))).status, 400);
});

Deno.test("D84 study profile: unknown grade and a bad date become null", () => {
  const r = parseProfileReply('{"profile":{"grade":"åk9","exam_date":"fredag"},"terms":[]}');
  assertEquals(r.profile.grade, null);
  assertEquals(r.profile.exam_date, null);
  assertEquals(parseProfileReply("nej").terms, []);
});

Deno.test("K40 study profile: the exam's topic is kept, and a topic of names puts the names in the terms", async () => {
  const { parseProfileReply, SYSTEM_PROMPT_PROFILE } = await import("./handler.ts");
  const r = parseProfileReply('{"profile": {"grade": "y8", "subject": "Geografi", "topic": "50 mest kända sjöar, floder och kuststäder"}, "terms": ["Nilen", "Seine", "Loire", "Rhen"]}');
  assertEquals(r.profile.topic, "50 mest kända sjöar, floder och kuststäder");
  assertEquals(r.terms.slice(0, 2), ["Nilen", "Seine"]);
  assert(SYSTEM_PROMPT_PROFILE.includes("the terms are first those names themselves"));
});
