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
    default_voice: { voice_id: A, name: "Astrid", in_catalog: false },
  });
  const res2 = await createVoicesHandler(deps({ defaultVoiceId: O }))(get());
  assertEquals((await res2.json()).default_id, O);
});

Deno.test("A140: default_voice names the default with the catalog's name when it is there, else 'Standard'", async () => {
  const cat = [{ voice_id: O, name: "Jonas", review: false }];
  const j = await (await createVoicesHandler(deps({ defaultVoiceId: O, catalog: () => Promise.resolve(cat) }))(get())).json();
  assertEquals(j.default_voice, { voice_id: O, name: "Jonas", in_catalog: true });
  const k = await (await createVoicesHandler(deps({ defaultVoiceId: "ZZZZZZZZZZZZZZZZZZZZ" }))(get())).json();
  assertEquals(k.default_voice.name, "Standard");
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

Deno.test("K96 (D220): the catalog with previews; the library search is only a list (not selectable), limited", async () => {
  const { createVoicesHandler } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const asked: unknown[] = [];
  const h = createVoicesHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    voices: [{ name: "Anna", id: "AAAAAAAAAAAA" }],
    defaultVoiceId: null,
    catalog: () => Promise.resolve([{ voice_id: "BBBBBBBBBBBB", name: "Sara", gender: "female", accent: "swedish", language: "sv", preview_url: "https://example.invalid/p.mp3" }]),
    searchLibrary: (q) => (asked.push(q), Promise.resolve([{ voice_id: "CCCCCCCCCCCC", name: "Erik", accent: "scanian", preview_url: "https://example.invalid/e.mp3" }])),
  });
  const a = await (await h(new Request("http://x/voices"))).json();
  assertEquals(a.catalog[0].name, "Sara");
  assertEquals(a.voices[0].name, "Anna", "the old list is kept");
  const b = await (await h(new Request("http://x/voices?library=1&search=sk%C3%A5nsk%3Cscript%3E&accent=scanian"))).json();
  assertEquals([b.library[0].name, b.selectable], ["Erik", false]);
  assertEquals(asked[0], { search: "skånskscript", accent: "scanian", gender: undefined, page: 0 }, "the search words are cleaned");
  let last = 200;
  for (let i = 0; i < 9; i++) last = (await h(new Request("http://x/voices?library=1"))).status;
  assertEquals([last, (await h(new Request("http://x/voices?library=1"))).status], [200, 429]);
});

Deno.test("K99 (D223): voices under review are shown only to admin", async () => {
  const { createVoicesHandler } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  const mk = (admin: boolean) => createVoicesHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(), voices: [], defaultVoiceId: null,
    catalog: () => Promise.resolve([{ voice_id: "AAAAAAAAAAAA", name: "Sara", preview_url: "https://example.invalid/s.mp3" }, { voice_id: "BBBBBBBBBBBB", name: "Pirat", review: true, preview_url: "https://example.invalid/p.mp3" }]),
    isAdmin: () => Promise.resolve(admin),
  });
  assertEquals((await (await mk(false)(new Request("http://x/voices"))).json()).catalog.map((v: { name: string }) => v.name), ["Sara"]);
  assertEquals((await (await mk(true)(new Request("http://x/voices"))).json()).catalog.map((v: { name: string }) => v.name), ["Sara", "Pirat"]);
});

Deno.test("K114 (D252): the library can be searched for native English voices (lang=en)", async () => {
  const seen: Record<string, unknown>[] = [];
  const h = createVoicesHandler(deps({ searchLibrary: (q: Record<string, unknown>) => (seen.push(q), Promise.resolve([])) }));
  await h(new Request("http://x/voices?library=1&lang=en&gender=female", { method: "GET" }));
  assertEquals(seen[0].language, "en");
  await h(new Request("http://x/voices?library=1&lang=any", { method: "GET" }));
  assertEquals(seen[1].anyLanguage, true);
});

Deno.test("K124 (Oscar G2, D267): a catalog voice without a preview is not listed for ordinary users (admin still sees it)", async () => {
  const cat = [
    { voice_id: A, name: "Astrid", preview_url: "https://storage.googleapis.com/eleven-public-prod/a.mp3" },
    { voice_id: E, name: "Elin", preview_url: null },
    { voice_id: O, name: "Oskar", preview_url: "" },
    { voice_id: "Http0000000000000004", name: "Http", preview_url: "http://example.com/x.mp3" },
  ];
  const j = await (await createVoicesHandler(deps({ catalog: () => Promise.resolve(cat), isAdmin: () => Promise.resolve(false) }))(get())).json();
  assertEquals(j.catalog.map((v: { name: string }) => v.name), ["Astrid"]);
  const admin = await (await createVoicesHandler(deps({ catalog: () => Promise.resolve(cat), isAdmin: () => Promise.resolve(true) }))(get())).json();
  assertEquals(admin.catalog.length, 4, "admin sees every voice, to fix the catalog");
});
