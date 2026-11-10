import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { aboutTopic, domainOf, isResourceRequest, NO_RESOURCE, resourceTopic } from "./resource.ts";

Deno.test("K19 a request for a film or page; the topic", () => {
  for (const f of ["har du en film om fotosyntes", "finns det någon bra sida om franska revolutionen", "kan du skicka en länk", "har du någon video om det här"]) {
    assert(isResourceRequest(f), f);
  }
  for (const f of ["vad är fotosyntes", "jag såg en film igår", "vilken film vann en oscar"]) assert(!isResourceRequest(f), f);
  assertEquals(resourceTopic("har du en film om fotosyntes?"), "fotosyntes");
  assertEquals(resourceTopic("har du en film om det här", "vad är cellandning"), "cellandning");
  assertEquals(domainOf("https://www.urplay.se/program/1"), "urplay.se");
  assertEquals(domainOf("https://example.com/x"), null);
  assert(aboutTopic("fotosyntes", "Fotosyntesen", "", "https://urplay.se/program/1"));
  assert(!aboutTopic("fotosyntes", "Vikingatiden", "Vikingatiden | UR Play", "https://urplay.se/program/2"));
});

function h(reply: string, page: { status: number; html: string }) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k19", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "s",
      model: "s",
      stream: (r) => {
        seen.push(r);
        return (async function* (): AsyncGenerator<LLMChunk> {
          yield { type: "text", text: reply };
        })();
      },
    },
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
    fetchImpl: () => Promise.resolve(new Response(page.html, { status: page.status })),
  });
  return { handler, seen };
}
const ask = (fragment: string) =>
  new Request("http://x/answer", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ fragment, mode: "tutor", language: "sv", persona: "tutor", persona_setup: "Prov i Biologi. Årskurs: Åk 8. Ämne: Biologi.", context: {} }),
  });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("K19 a checked link is passed on with one spoken sentence", async () => {
  const { handler, seen } = h(
    "LÄNK: https://urplay.se/program/123-fotosyntesen | Fotosyntesen\nJag skickade en länk till en film om fotosyntes från UR Play, säg till om du vill ha en annan.",
    { status: 200, html: "<html><title>Fotosyntesen | UR Play</title></html>" },
  );
  const ev = await events(await handler(ask("har du en film om fotosyntes")));
  const done = ev.find((e) => e.event === "done")!.data;
  assertEquals((done.resource as { url: string }).url, "https://urplay.se/program/123-fotosyntesen");
  assertEquals((done.resource as { source: string }).source, "UR Play");
  const said = ev.filter((e) => e.event === "delta").map((e) => e.data.text).join("");
  assert(said.startsWith("Jag skickade en länk") && !said.includes("http"), said);
  assert(JSON.stringify(seen[0].tools).includes("urplay.se"));
});

Deno.test("K19 an invented address, a dead link or another topic is never passed on", async () => {
  for (const [reply, page] of [
    ["LÄNK: https://example.com/fotosyntes | Fotosyntes", { status: 200, html: "<title>Fotosyntes</title>" }],
    ["LÄNK: https://urplay.se/program/999 | Fotosyntesen", { status: 404, html: "" }],
    ["LÄNK: https://urplay.se/program/5 | Vikingatiden", { status: 200, html: "<title>Vikingatiden | UR Play</title>" }],
    ["INGEN LÄNK", { status: 200, html: "" }],
  ] as const) {
    const { handler } = h(reply, page);
    const ev = await events(await handler(ask("har du en film om fotosyntes")));
    assertEquals(ev.find((e) => e.event === "done")!.data.resource, null, reply);
    assertEquals(ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""), NO_RESOURCE);
  }
});
