// K32 (D115): fun commands in every mode; "Lumen" first where other people speak.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { funCommand } from "./commands.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";

Deno.test("K32 phrases: sing, rap, joke, a style; the topic as the argument; ordinary sentences are not commands", () => {
  const t = (s: string, name = false) => {
    const c = funCommand(s, name);
    return c ? `${c.task}${c.arg ? ":" + c.arg : ""}` : null;
  };
  assertEquals(t("Lumen, sjung om fotosyntes"), "fun:sing:fotosyntes");
  assertEquals(t("sjung en sång"), "fun:sing");
  assertEquals(t("kan du rappa om andra världskriget"), "fun:rap:andra världskriget");
  assertEquals(t("berätta ett skämt"), "fun:joke");
  assertEquals(t("dra en vits om matte"), "fun:joke:matte");
  assertEquals(t("säg det som en pirat"), "fun:style:pirat");
  assertEquals(t("Lumen, säg det som en sportkommentator"), "fun:style:sportkommentator");
  for (const s of ["vem sjunger Bohemian Rhapsody", "berätta om skämtets historia", "säg det på engelska", "förklara det som för en femåring", "vad är en rap", "jag sjunger i kör"]) {
    assertEquals(t(s), null, s);
  }
  // Auto and the social modes: only after "Lumen"
  assertEquals(t("berätta ett skämt", true), null);
  assertEquals(t("Lumen berätta ett skämt", true), "fun:joke");
});

function setup() {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k32", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "claude-haiku-5-5",
      stream: (r) => {
        seen.push(r);
        return (async function* (): AsyncGenerator<LLMChunk> {
          yield { type: "text", text: "Varför gick tomaten till skolan? För att bli ketchup-smart." };
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
const said = async (r: Response) =>
  (await r.text()).split("\n\n").filter((f) => f.startsWith("event: delta")).map((f) => JSON.parse(/^data: (.*)$/m.exec(f)![1]).text).join("");

Deno.test("K32 in Auto, Provläge and Socialt: the task reaches the model and the answer is spoken, never silence", async () => {
  for (const b of [
    { fragment: "Lumen, berätta ett skämt", mode: "auto" },
    { fragment: "berätta ett skämt", mode: "tutor", persona: "tutor", persona_setup: "Prov i Biologi. Årskurs: Åk 9." },
    { fragment: "berätta ett skämt", mode: "push_to_talk" },
    { fragment: "", mode: "tutor", persona: "social", social: { style: "social", trigger: "other_spoke", transcript: [{ speaker: "other", text: "Hej!" }], calibrate: "Lumen, berätta ett skämt" } },
  ]) {
    const { handler, seen } = setup();
    const text = await said(await handler(post(b)));
    assert(text.includes("ketchup"), JSON.stringify(b));
    assert(seen.at(-1)!.user.includes("<task>fun:joke</task>"), JSON.stringify(b));
  }
  // Auto without "Lumen": a classmate's words are not a command
  const { handler, seen } = setup();
  await (await handler(post({ fragment: "berätta ett skämt", mode: "auto" }))).text();
  assert(!seen.some((r) => r.user.includes("<task>fun:joke</task>")));
});
