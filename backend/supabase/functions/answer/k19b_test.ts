// K19 after Oscar O34 grupp 14: links from the search results (UR Play answers checks with 403), Auto for direct requests.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk } from "./llm/types.ts";
import { isDirectResourceRequest, resourceTopic, sameUrl } from "./resource.ts";

function setup(chunks: LLMChunk[], status: number) {
  const fetched: string[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k19b", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: { name: "s", model: "claude-haiku-5-5", stream: () => (async function* () { for (const c of chunks) yield c; })() },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
    fetchImpl: ((u: string) => {
      fetched.push(String(u));
      return Promise.resolve(new Response(status === 200 ? "<title>Franska revolutionen</title>" : "", { status }));
    }) as typeof fetch,
  });
  return { handler, fetched };
}
const post = (fragment: string, mode = "push_to_talk") =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ fragment, mode, language: "sv", context: {} }) });
async function done(res: Response) {
  const f = (await res.text()).split("\n\n").filter(Boolean).map((x) => ({ e: /^event: (.*)$/m.exec(x)![1], d: JSON.parse(/^data: (.*)$/m.exec(x)![1]) }));
  return f.find((x) => x.e === "done")!.d;
}
const URL1 = "https://urplay.se/program/232838-plugga-historia-franska-revolutionen";

Deno.test("K19b: a blocked check (403) passes only for a URL the search returned; the search's own result is used when the model says INGEN LÄNK", async () => {
  const src: LLMChunk = { type: "source", url: URL1, title: "Plugga historia: Franska revolutionen" };
  {
    const { handler } = setup([src, { type: "text", text: `LÄNK: ${URL1} | Franska revolutionen\nJag skickade en länk.` }], 403);
    assertEquals((await done(await handler(post("har du en film om franska revolutionen")))).resource?.url, URL1);
  }
  {
    const { handler } = setup([{ type: "text", text: `LÄNK: ${URL1} | Franska revolutionen` }], 403);
    assertEquals((await done(await handler(post("har du en film om franska revolutionen")))).resource ?? null, null, "the model's own URL must answer 200");
  }
  {
    const { handler } = setup([src, { type: "text", text: "INGEN LÄNK" }], 403);
    assertEquals((await done(await handler(post("har du en film om franska revolutionen")))).resource?.url, URL1, "the search found one");
  }
  {
    const off: LLMChunk = { type: "source", url: "https://urplay.se/program/1-matte-derivata", title: "Derivata" };
    const { handler } = setup([off, { type: "text", text: "INGEN LÄNK" }], 403);
    assertEquals((await done(await handler(post("har du en film om franska revolutionen")))).resource ?? null, null, "not about the topic");
  }
});

Deno.test("K19b: in Auto only a request that starts the utterance; topic after the last 'om'", async () => {
  assert(isDirectResourceRequest("kan du hitta en film om cellen"));
  assert(isDirectResourceRequest("Lumen, någon youtube om derivata"));
  assert(isDirectResourceRequest("jag vill se en film om vulkaner"));
  assert(!isDirectResourceRequest("igår sa hon att hon har en film om vulkaner"));
  assert(!isDirectResourceRequest("vi såg en film om vulkaner"));
  assertEquals(resourceTopic("har du nåt bra på UR om demokrati"), "demokrati");
  assert(sameUrl("https://www.urplay.se/program/1/", "https://urplay.se/program/1?x=1"));
  const { handler } = setup([{ type: "text", text: "Hej." }], 200);
  assertEquals((await done(await handler(post("vi pratade om en film om vulkaner", "auto")))).resource ?? null, null);
});
