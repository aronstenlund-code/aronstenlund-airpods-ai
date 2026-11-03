import { assertEquals } from "jsr:@std/assert@1.0.8";
import { HttpError } from "../_shared/errors.ts";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { parseVoices } from "../tts/voices.ts";
import { createVoicesHandler } from "./handler.ts";

const A = "Astrid00000000000001", E = "Elin0000000000000002", O = "Oskar000000000000003";

Deno.test("parseVoices: the documented format", () => {
  const r = parseVoices(`Astrid:${A},Elin:${E},Oskar:${O}`);
  assertEquals(r.errors, []);
  assertEquals(r.voices, [{ name: "Astrid", id: A }, { name: "Elin", id: E }, {
    name: "Oskar",
    id: O,
  }]);
});

Deno.test("parseVoices: tolerates spaces/newlines/trailing comma, Swedish letters and spaces in names", () => {
  const r = parseVoices(` Åsa Lind : ${A} ,\n Örjan:${E},\n`);
  assertEquals(r.errors, []);
  assertEquals(r.voices.map((v) => v.name), ["Åsa Lind", "Örjan"]);
});

Deno.test("parseVoices: bad entries are skipped and reported without echoing ids", () => {
  const r = parseVoices(`NoColon,Foo:x,Good:${A},Dup:${A},Short:abc,Bad Name!:${E},:${O}`);
  assertEquals(r.voices, [{ name: "Good", id: A }]);
  assertEquals(r.errors.length, 6);
  assertEquals(r.errors.some((e) => e.includes(A)), false);
});

Deno.test("parseVoices: empty / undefined", () => {
  assertEquals(parseVoices(undefined).voices, []);
  assertEquals(parseVoices("  ").voices, []);
});

const deps = (over = {}) => ({
  authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
  rateLimiter: new MemoryRateLimiter(),
  voices: [{ name: "Astrid", id: A }, { name: "Elin", id: E }],
  defaultVoiceId: null,
  ...over,
});
const get = () => new Request("http://x/voices", { method: "GET" });

Deno.test("GET /voices returns names + ids and a default, nothing else", async () => {
  const res = await createVoicesHandler(deps())(get());
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    voices: [{ name: "Astrid", id: A }, { name: "Elin", id: E }],
    default_id: A,
  });
  const res2 = await createVoicesHandler(deps({ defaultVoiceId: O }))(get());
  assertEquals((await res2.json()).default_id, O);
});

Deno.test("GET /voices: auth required, GET only, empty list is fine", async () => {
  const noAuth = createVoicesHandler(
    deps({ authenticate: () => Promise.reject(new HttpError(401, "unauthorized", "no")) }),
  );
  assertEquals((await noAuth(get())).status, 401);
  assertEquals(
    (await createVoicesHandler(deps())(new Request("http://x", { method: "POST" }))).status,
    405,
  );
  const empty = await createVoicesHandler(deps({ voices: [] }))(get());
  assertEquals(await empty.json(), { voices: [], default_id: null });
});
