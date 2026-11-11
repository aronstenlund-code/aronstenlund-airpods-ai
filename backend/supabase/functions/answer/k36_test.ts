// K36 (D125): Spotify (server tools, OAuth, encrypted tokens) and calls (phone tool) — no network, no model.
import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { b64, TokenCrypto } from "../_shared/crypto.ts";
import { accessToken, type ConnectionRow, type ConnectionStore } from "../_shared/spotify.ts";
import { createConnectHandler } from "../connect/handler.ts";
import { createHandler, DEFAULT_CONFIG } from "./handler.ts";
import { type LLMChunk, type LLMRequest } from "./llm/types.ts";
import { confirmText, phoneToolDefs, validatePhoneInput } from "./phonetools.ts";
import { runSpotify, validateSpotifyInput } from "./spotifytools.ts";

const KEY = b64(new Uint8Array(32).map((_, i) => i * 7 + 1));
const app = { clientId: "cid", clientSecret: "csecret", redirectUri: "https://x.supabase.co/functions/v1/connect/callback" };

function memStore() {
  const rows = new Map<string, ConnectionRow>();
  const store: ConnectionStore = {
    get: (u, p) => Promise.resolve(rows.get(`${u}|${p}`) ?? null),
    upsert: (r) => {
      rows.set(`${r.user_id}|${r.provider}`, r);
      return Promise.resolve();
    },
    remove: (u, p) => Promise.resolve(rows.delete(`${u}|${p}`) ? 1 : 0),
    list: (u) => Promise.resolve([...rows.values()].filter((r) => r.user_id === u).map((r) => ({ provider: r.provider, premium: r.premium }))),
  };
  return { rows, store };
}

Deno.test("K36 crypto: tokens sealed with a fresh IV and opened again; the state is signed, expires, cannot be changed", async () => {
  const tc = await TokenCrypto.fromBase64(KEY);
  const a = await tc.seal("BQD-secret-token"), b = await tc.seal("BQD-secret-token");
  assertNotEquals(a, b);
  assert(!a.includes("secret"));
  assertEquals(await tc.open(a), "BQD-secret-token");
  const st = await tc.signState({ u: "user-1", p: "spotify", exp: 2_000 });
  assertEquals((await tc.verifyState(st, 1_000))?.u, "user-1");
  assertEquals(await tc.verifyState(st, 3_000), null, "expired");
  const forged = (await tc.signState({ u: "user-2", p: "spotify", exp: 2_000 })).split(".")[0] + "." + st.split(".")[1];
  assertEquals(await tc.verifyState(forged, 1_000), null, "another user's payload with this signature");
  const other = await TokenCrypto.fromBase64(b64(new Uint8Array(32).fill(9)));
  assertEquals(await other.verifyState(st, 1_000), null, "another key");
  let threw = false;
  try {
    await TokenCrypto.fromBase64("c2hvcnQ=");
  } catch {
    threw = true;
  }
  assert(threw, "a short key is refused");
});

Deno.test("K36 connect: authorize URL with a signed state; the callback stores only encrypted tokens and redirects to the app", async () => {
  const tc = await TokenCrypto.fromBase64(KEY);
  const { rows, store } = memStore();
  const fetchImpl = ((u: string) =>
    Promise.resolve(new Response(JSON.stringify(String(u).endsWith("/me") ? { product: "premium" } : {}), { status: 200 }))) as typeof fetch;
  const h = createConnectHandler({
    authenticate: () => Promise.resolve({ id: "user-1", isAnonymous: true }),
    store,
    crypto: tc,
    spotify: app,
    fetchImpl,
    now: () => 1_000_000,
    exchange: (code) => Promise.resolve({ access_token: `acc-${code}`, refresh_token: "ref-1", expires_in: 3600, scope: "user-modify-playback-state" }),
  });
  const r = await (await h(new Request("http://x/connect", { method: "POST", body: JSON.stringify({ provider: "spotify" }) }))).json();
  const u = new URL(r.url);
  assertEquals(u.origin + u.pathname, "https://accounts.spotify.com/authorize");
  assertEquals(u.searchParams.get("redirect_uri"), app.redirectUri);
  assert(u.searchParams.get("scope")!.includes("user-modify-playback-state"));
  const state = u.searchParams.get("state")!;
  const cb = await h(new Request(`http://x/connect/callback?code=abc&state=${encodeURIComponent(state)}`));
  assertEquals(cb.status, 302);
  assertEquals(cb.headers.get("location"), "lumen://connect?provider=spotify&status=ok");
  const row = rows.get("user-1|spotify")!;
  assert(!JSON.stringify(row).includes("acc-abc") && !JSON.stringify(row).includes("ref-1"), "no plain token stored");
  assertEquals(await tc.open(row.access_enc), "acc-abc");
  assertEquals(row.premium, true);
  assertEquals(row.expires_at, new Date(1_000_000 + 3540 * 1000).toISOString());
  assertEquals(await (await h(new Request("http://x/connect"))).json(), { connections: [{ provider: "spotify", premium: true }], available: { spotify: true } });
  // a bad or missing state, or the user saying no, never stores anything
  for (const q of ["code=abc&state=forged.x", "code=abc", "error=access_denied&state=" + encodeURIComponent(state)]) {
    const res = await h(new Request(`http://x/connect/callback?${q}`));
    assert(/status=(?:error|denied)/.test(res.headers.get("location")!), q);
  }
  assertEquals(await (await h(new Request("http://x/connect?provider=spotify", { method: "DELETE" }))).json(), { removed: 1 });
  assertEquals(rows.size, 0);
  const off = createConnectHandler({ authenticate: () => Promise.resolve({ id: "u", isAnonymous: true }), store, crypto: null, spotify: null });
  assertEquals((await off(new Request("http://x/connect", { method: "POST", body: JSON.stringify({ provider: "spotify" }) }))).status, 503);
});

Deno.test("K36 tokens: an expired access token is refreshed and stored again (encrypted)", async () => {
  const tc = await TokenCrypto.fromBase64(KEY);
  const { rows, store } = memStore();
  await store.upsert({ user_id: "u", provider: "spotify", access_enc: await tc.seal("old"), refresh_enc: await tc.seal("ref"), expires_at: new Date(0).toISOString(), scope: null, premium: true });
  const fetchImpl = ((_u: string, init: RequestInit) => {
    assert(String(init.body).includes("grant_type=refresh_token&refresh_token=ref"));
    return Promise.resolve(new Response(JSON.stringify({ access_token: "new", expires_in: 3600 }), { status: 200 }));
  }) as unknown as typeof fetch;
  const t = await accessToken("u", { store, crypto: tc, app, fetchImpl, now: () => 5_000 });
  assertEquals(t, { token: "new", premium: true });
  assertEquals(await tc.open(rows.get("u|spotify")!.access_enc), "new");
  assertEquals(await tc.open(rows.get("u|spotify")!.refresh_enc!), "ref", "the old refresh token is kept");
  assertEquals(await accessToken("nobody", { store, crypto: tc, app }), null);
});

function spotifyFake(handlers: Record<string, (init: RequestInit) => [number, unknown]>) {
  const calls: string[] = [];
  const f = ((u: string, init: RequestInit = {}) => {
    const path = `${init.method ?? "GET"} ${String(u).replace("https://api.spotify.com/v1", "")}`;
    calls.push(path);
    const k = Object.keys(handlers).find((x) => path.startsWith(x));
    const [s, b] = k ? handlers[k](init) : [404, {}];
    return Promise.resolve(new Response(s === 204 ? null : JSON.stringify(b), { status: s }));
  }) as unknown as typeof fetch;
  return { f, calls };
}
const conn = { token: "t", premium: true };

Deno.test("K36 Spotify: own playlist first, then search; pause/next; no device -> the phone; Premium and errors in plain Swedish", async () => {
  {
    const { f, calls } = spotifyFake({
      "GET /me/playlists": () => [200, { items: [{ name: "Plugg 2026", uri: "spotify:playlist:p1" }] }],
      "PUT /me/player/play": (i) => [String(i.body).includes("spotify:playlist:p1") ? 204 : 400, {}],
    });
    const r = await runSpotify("spotify_play", { query: "plugg 2026", kind: "playlist" }, conn, f);
    assertEquals(r, { status: "ok", say: "Nu spelas spellistan Plugg 2026.", playing: "spellistan Plugg 2026" });
    assert(!calls.some((c) => c.includes("/search")), "own playlist: no search");
  }
  {
    const { f, calls } = spotifyFake({
      "GET /me/playlists": () => [200, { items: [] }],
      "GET /search": () => [200, { tracks: { items: [{ name: "Blinding Lights", uri: "spotify:track:t1", artists: [{ name: "The Weeknd" }] }] } }],
      "PUT /me/player/play?device_id=ph": (i) => [String(i.body).includes("spotify:track:t1") ? 204 : 400, {}],
      "PUT /me/player/play": () => [404, { error: { reason: "NO_ACTIVE_DEVICE" } }],
      "GET /me/player/devices": () => [200, { devices: [{ id: "pc", type: "Computer" }, { id: "ph", type: "Smartphone" }] }],
    });
    const r = await runSpotify("spotify_play", { query: "blinding lights" }, conn, f);
    assertEquals(r.say, "Nu spelas Blinding Lights med The Weeknd.");
    assert(calls.some((c) => c.startsWith("GET /search?q=blinding+lights&type=track%2Cplaylist%2Calbum%2Cartist&limit=5")));
    assert(calls.includes("PUT /me/player/play?device_id=ph"), "the phone is chosen");
  }
  assertEquals((await runSpotify("spotify_pause", {}, conn, spotifyFake({ "PUT /me/player/pause": () => [204, null] }).f)).say, "Jag pausade musiken.");
  assertEquals((await runSpotify("spotify_next", {}, conn, spotifyFake({ "POST /me/player/next": () => [204, null] }).f)).say, "Nästa låt.");
  assertEquals((await runSpotify("spotify_pause", {}, conn, spotifyFake({ "PUT /me/player/pause": () => [403, { error: { reason: "PREMIUM_REQUIRED" } }] }).f)).status, "premium_required");
  assertEquals((await runSpotify("spotify_play", {}, { token: "t", premium: false }, spotifyFake({}).f)).status, "premium_required");
  assertEquals((await runSpotify("spotify_play", {}, null, spotifyFake({}).f)).status, "not_connected");
  const none = spotifyFake({ "PUT /me/player/play": () => [404, {}], "GET /me/player/devices": () => [200, { devices: [] }] });
  assertEquals((await runSpotify("spotify_play", {}, conn, none.f)).status, "no_device");
  const nf = spotifyFake({ "GET /me/playlists": () => [200, { items: [] }], "GET /search": () => [200, {}] });
  assertEquals((await runSpotify("spotify_play", { query: "xyzzy" }, conn, nf.f)).say, "Jag hittade inte xyzzy på Spotify.");
  assertEquals(validateSpotifyInput("spotify_play", { query: "x".repeat(200) }), null);
  assertEquals(validateSpotifyInput("spotify_play", { kind: "podcast" }), null);
});

Deno.test("K36 calls: the number must have been said (B6), a name is fine, iOS confirms (no Lumen question); music_open", () => {
  assertEquals(validatePhoneInput("call_contact", { name: "mamma" }, "ring mamma"), { name: "mamma" });
  assertEquals(validatePhoneInput("call_contact", { number: "070-123 45 67" }, "ring 070 123 45 67"), { number: "070-123 45 67" });
  assertEquals(validatePhoneInput("call_contact", { number: "0701234567" }, "ring tandläkaren"), null, "an invented number is never dialled");
  assertEquals(validatePhoneInput("call_contact", { name: "Tandläkaren", number: "0812345678" }, "ring tandläkaren"), { name: "Tandläkaren" });
  assertEquals(validatePhoneInput("call_contact", {}, "ring"), null);
  assertEquals(confirmText("call_contact", { name: "mamma" }), null);
  assertEquals(validatePhoneInput("music_open", { query: "lugn pluggmusik" }), { query: "lugn pluggmusik" });
  assertEquals((phoneToolDefs(["call_contact", "music_open"]) as { name: string }[]).map((d) => d.name), ["call_contact", "music_open"]);
});

function setup(chunks: LLMChunk[], runs: { name: string; input: unknown }[]) {
  const seen: LLMRequest[] = [];
  const handler = createHandler({
    authenticate: () => Promise.resolve({ id: "u-k36", isAnonymous: true }),
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
    recordUsage: () => {},
    config: DEFAULT_CONFIG,
    runSpotify: (_u, name, input) => {
      runs.push({ name, input });
      return Promise.resolve({ status: "ok", say: "Nu spelas spellistan Plugg.", playing: "spellistan Plugg" });
    },
  });
  return { handler, seen };
}
const post = (b: Record<string, unknown>) =>
  new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ language: "sv", context: {}, mode: "push_to_talk", ...b }) });
async function events(res: Response) {
  return (await res.text()).split("\n\n").filter(Boolean).map((f) => ({ event: /^event: (.*)$/m.exec(f)![1], data: JSON.parse(/^data: (.*)$/m.exec(f)![1]) }));
}

Deno.test("K36 /answer: Spotify tools only with connections: [spotify]; the server runs the call and says one sentence", async () => {
  const runs: { name: string; input: unknown }[] = [];
  const call: LLMChunk = { type: "tool_use", id: "toolu_s", name: "spotify_play", input: { query: "Plugg", kind: "playlist" } };
  const { handler, seen } = setup([call], runs);
  const ev = await events(await handler(post({ fragment: "kör spellistan plugg", connections: ["spotify"] })));
  assertEquals(runs, [{ name: "spotify_play", input: { query: "Plugg", kind: "playlist" } }]);
  assertEquals(ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""), "Nu spelas spellistan Plugg.");
  const done = ev.find((e) => e.event === "done")!.data;
  assertEquals(done.server_tool, { name: "spotify_play", status: "ok", playing: "spellistan Plugg" });
  assertEquals(done.answered, true);
  assert(!ev.some((e) => e.event === "tool_call"), "nothing for the app to run");
  assert((seen[0].tools as { name: string }[]).some((t) => t.name === "spotify_play"));
  assert(seen[0].system.includes("Spotify tools (K36)"));
  for (const extra of [{}, { connections: ["spotify"], source: "demo", mode: "text" }, { connections: ["spotify"], mode: "auto" }]) {
    const s = setup([{ type: "text", text: "Hej." }], []);
    await events(await s.handler(post({ fragment: "kör spellistan plugg", ...extra })));
    assert(!((s.seen[0]?.tools ?? []) as { name: string }[]).some((t) => t.name.startsWith("spotify")), JSON.stringify(extra));
  }
});

Deno.test("K36 key: CONNECTIONS_KEY when set, else derived from the service role key (same key every time)", async () => {
  const env = (m: Record<string, string>) => ({ get: (k: string) => m[k] });
  assertEquals(await TokenCrypto.fromEnv(env({})), null);
  const a = await TokenCrypto.fromEnv(env({ SUPABASE_SERVICE_ROLE_KEY: "sb_secret_x" }));
  const b = await TokenCrypto.fromEnv(env({ SUPABASE_SERVICE_ROLE_KEY: "sb_secret_x" }));
  assertEquals(await b!.open(await a!.seal("tok")), "tok");
  const own = await TokenCrypto.fromEnv(env({ SUPABASE_SERVICE_ROLE_KEY: "sb_secret_x", CONNECTIONS_KEY: KEY }));
  let opened = true;
  try {
    await own!.open(await a!.seal("tok"));
  } catch {
    opened = false;
  }
  assert(!opened, "the own key is a different key");
});
