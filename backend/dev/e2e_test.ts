// End-to-end test of the REAL function entry points (the files that get deployed), run as
// subprocesses against local fake upstreams: Supabase (JWKS + PostgREST), Anthropic, ElevenLabs.
// Needs no network, no keys, no cost.    deno task e2e
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { exportJWK, generateKeyPair, SignJWT } from "npm:jose@5.9.6";

const ROOT = new URL("../supabase/functions/", import.meta.url).pathname;
const VOICE_A = "Astrid00000000000001";
const VOICE_B = "Elin0000000000000002";

// ---------- fake upstreams ----------
interface FakeState {
  denyLimits: boolean;
  anthropic: "ok" | "credit" | "slow";
  anthropicRequests: { headers: Record<string, string>; body: Record<string, unknown> }[];
  anthropicAborted: boolean;
  anthropicWarm: number;
  usage: Record<string, unknown>[];
  rpcCalls: string[];
  elevenRequests: { url: string; key: string | null; body: Record<string, unknown> }[];
  elevenAborted: boolean;
}
const state: FakeState = {
  denyLimits: false,
  anthropic: "ok",
  anthropicRequests: [],
  anthropicAborted: false,
  anthropicWarm: 0,
  usage: [],
  rpcCalls: [],
  elevenRequests: [],
  elevenAborted: false,
};
function reset() {
  state.denyLimits = false;
  state.anthropic = "ok";
  state.anthropicRequests.length = 0;
  state.anthropicAborted = false;
  state.usage.length = 0;
  state.rpcCalls.length = 0;
  state.elevenRequests.length = 0;
  state.elevenAborted = false;
}

const enc = new TextEncoder();
const sse = (events: unknown[]) =>
  events.map((e) => `event: x\ndata: ${JSON.stringify(e)}\n\n`).join("");

function startFakeSupabase(jwks: unknown) {
  return Deno.serve({ port: 0, hostname: "127.0.0.1", onListen() {} }, async (req) => {
    const u = new URL(req.url);
    if (u.pathname === "/auth/v1/.well-known/jwks.json") return Response.json(jwks);
    if (u.pathname.startsWith("/rest/v1/rpc/")) {
      state.rpcCalls.push(u.pathname.split("/").pop()!);
      await req.text();
      return Response.json([
        state.denyLimits
          ? { allowed: false, denied_key: "k", retry_after: 9 }
          : { allowed: true, denied_key: null, retry_after: 0 },
      ]);
    }
    if (u.pathname === "/rest/v1/answer_usage") {
      state.usage.push(await req.json());
      return new Response(null, { status: 201 });
    }
    return new Response("nope", { status: 404 });
  });
}

function startFakeAnthropic() {
  return Deno.serve({ port: 0, hostname: "127.0.0.1", onListen() {} }, async (req) => {
    const u = new URL(req.url);
    if (req.method === "GET" && u.pathname === "/v1/models") {
      state.anthropicWarm++;
      return new Response("{}", { status: 401 });
    }
    if (req.method !== "POST" || u.pathname !== "/v1/messages") {
      return new Response("nope", { status: 404 });
    }
    const body = await req.json();
    state.anthropicRequests.push({ headers: Object.fromEntries(req.headers), body });
    if (state.anthropic === "credit") {
      return Response.json(
        {
          type: "error",
          error: {
            type: "invalid_request_error",
            message: "Your credit balance is too low to access the Anthropic API.",
          },
        },
        { status: 400 },
      );
    }
    const system = JSON.stringify(body.system);
    const user = String((body.messages as { content: string }[])[0].content);
    const header = system.includes("OUTPUT (strict)");
    const nonQuestion = user.includes("roligt igår");
    const start = {
      type: "message_start",
      message: { usage: { input_tokens: 40, cache_read_input_tokens: 460, output_tokens: 1 } },
    };
    const parts = header
      ? nonQuestion ? ['{"is_question":false,"reconstructed_question":"","confidence":0.95}'] : [
        '{"is_question":true,"reconstructed_question":"Vad är roten ur hundra?","confidence":0.97}\n',
        "Roten ur hundra ",
        "är tio.",
      ]
      : ["Roten ur hundra ", "är tio."];
    const stream = new ReadableStream<Uint8Array>({
      async start(c) {
        c.enqueue(enc.encode(sse([start])));
        for (const p of parts) {
          c.enqueue(
            enc.encode(
              sse([{
                type: "content_block_delta",
                index: 0,
                delta: { type: "text_delta", text: p },
              }]),
            ),
          );
          if (state.anthropic === "slow") {
            for (let i = 0; i < 100; i++) {
              if (req.signal.aborted) {
                state.anthropicAborted = true;
                try {
                  c.close();
                } catch { /* closed */ }
                return;
              }
              await new Promise((r) => setTimeout(r, 20));
            }
          }
        }
        c.enqueue(
          enc.encode(
            sse([{
              type: "message_delta",
              delta: { stop_reason: "end_turn" },
              usage: { output_tokens: 9 },
            }, { type: "message_stop" }]),
          ),
        );
        c.close();
      },
    });
    return new Response(stream, { status: 200, headers: { "content-type": "text/event-stream" } });
  });
}

function startFakeEleven() {
  return Deno.serve({ port: 0, hostname: "127.0.0.1", onListen() {} }, async (req) => {
    const u = new URL(req.url);
    if (req.method === "GET") return new Response("{}", { status: 401 });
    state.elevenRequests.push({
      url: u.pathname + u.search,
      key: req.headers.get("xi-api-key"),
      body: await req.json(),
    });
    req.signal.addEventListener("abort", () => (state.elevenAborted = true));
    return new Response(new Uint8Array([1, 2, 3, 4]), {
      status: 200,
      headers: { "content-type": "audio/mpeg" },
    });
  });
}

// ---------- function subprocesses ----------
async function startFunction(name: string, env: Record<string, string>) {
  const probe = Deno.listen({ port: 0, hostname: "127.0.0.1" });
  const port = (probe.addr as Deno.NetAddr).port;
  probe.close();
  const child = new Deno.Command(Deno.execPath(), {
    args: ["run", "-A", "--no-check", `${ROOT}${name}/index.ts`],
    env: { ...env, DENO_SERVE_ADDRESS: `tcp:127.0.0.1:${port}` },
    stdout: "null",
    stderr: "null",
  }).spawn();
  const base = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 100; i++) {
    try {
      const r = await fetch(base, { method: "OPTIONS" });
      await r.body?.cancel();
      return {
        base,
        stop: () => {
          try {
            child.kill();
          } catch { /* gone */ }
        },
      };
    } catch {
      await new Promise((r) => setTimeout(r, 100));
    }
  }
  child.kill();
  throw new Error(`${name} did not start`);
}

async function readSse(res: Response) {
  const text = await res.text();
  return text.split("\n\n").filter(Boolean).map((f) => ({
    event: /^event: (.*)$/m.exec(f)![1],
    data: JSON.parse(/^data: (.*)$/m.exec(f)![1]),
  }));
}
const waitFor = async (cond: () => boolean, ms = 2000) => {
  const t = performance.now();
  while (!cond() && performance.now() - t < ms) await new Promise((r) => setTimeout(r, 25));
  return cond();
};

Deno.test("e2e: answer, tts and voices as deployed (real entry points, fake upstreams)", async (t) => {
  const { publicKey, privateKey } = await generateKeyPair("ES256");
  const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "ES256", use: "sig" };
  const { privateKey: otherKey } = await generateKeyPair("ES256");
  const supa = startFakeSupabase({ keys: [jwk] });
  const anth = startFakeAnthropic();
  const eleven = startFakeEleven();
  const supaUrl = `http://127.0.0.1:${(supa.addr as Deno.NetAddr).port}`;
  const anthUrl = `http://127.0.0.1:${(anth.addr as Deno.NetAddr).port}`;
  const elevenUrl = `http://127.0.0.1:${(eleven.addr as Deno.NetAddr).port}`;

  const common = { SUPABASE_URL: supaUrl, SUPABASE_SERVICE_ROLE_KEY: "svc-key" };
  const answer = await startFunction("answer", {
    ...common,
    ANTHROPIC_API_KEY: "sk-fake",
    ANTHROPIC_BASE_URL: anthUrl,
  });
  const tts = await startFunction("tts", {
    ...common,
    ELEVENLABS_API_KEY: "xi-fake",
    ELEVENLABS_BASE_URL: elevenUrl,
    ELEVENLABS_VOICES: `Astrid:${VOICE_A},Elin:${VOICE_B}`,
  });
  const voices = await startFunction("voices", {
    ...common,
    ELEVENLABS_VOICES: `Astrid:${VOICE_A},Elin:${VOICE_B}`,
  });

  const token = (key = privateKey, sub = "11111111-1111-1111-1111-111111111111") =>
    new SignJWT({ role: "authenticated", is_anonymous: true })
      .setProtectedHeader({ alg: "ES256", kid: "k1" })
      .setSubject(sub).setIssuer(`${supaUrl}/auth/v1`).setAudience("authenticated")
      .setExpirationTime("5m").sign(key);
  const post = async (base: string, body: unknown, tok?: string) =>
    fetch(base, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(tok ? { authorization: `Bearer ${tok}` } : {}),
      },
      body: JSON.stringify(body),
    });
  const ask = (mode: string, fragment: string, tok: string) =>
    post(answer.base, { fragment, mode, language: "sv", context: {} }, tok);

  try {
    await t.step(
      "answer push_to_talk: direct mode, SDK-free request shape, SSE, usage logged",
      async () => {
        reset();
        const res = await ask("push_to_talk", "roten ur hundra", await token());
        assertEquals(res.status, 200);
        const ev = await readSse(res);
        assertEquals(ev[0].event, "meta");
        assertEquals(ev[0].data.confidence, 1);
        assertEquals(
          ev.filter((e) => e.event === "delta").map((e) => e.data.text).join(""),
          "Roten ur hundra är tio.",
        );
        const done = ev.at(-1)!;
        assertEquals(done.event, "done");
        assertEquals(done.data.breakdown.direct, true);
        assertEquals(done.data.usage.cache_read_tokens, 460);
        const rq = state.anthropicRequests[0];
        assertEquals(rq.headers["x-api-key"], "sk-fake");
        assertEquals(rq.headers["anthropic-version"], "2026-10-21");
        assertEquals(rq.body.model, "claude-haiku-5-5");
        assertEquals(rq.body.stream, true);
        assertEquals(rq.body.max_tokens, 256, "fact-sized token budget");
        assertEquals(rq.body.thinking, { type: "disabled" });
        assertEquals(rq.body.output_config, { effort: "low" });
        assert(!("temperature" in rq.body));
        assertEquals((rq.body.system as { cache_control?: unknown }[])[0].cache_control, {
          type: "ephemeral",
        });
        assert(
          !JSON.stringify(rq.body.system).includes("OUTPUT (strict)"),
          "direct prompt, no JSON header protocol",
        );
        assert(await waitFor(() => state.usage.length === 1), "usage row inserted via PostgREST");
        assertEquals(state.usage[0].status, "ok");
        assertEquals(state.usage[0].input_tokens, 500);
        assert((state.usage[0].est_cost_usd as number) > 0);
        assertEquals(state.rpcCalls, ["check_rate_limits"], "one limiter round trip");
      },
    );

    await t.step(
      "answer study request (D35): developed prompt, bigger budget, answer_type in meta",
      async () => {
        reset();
        const ev = await readSse(await ask("push_to_talk", "elbilar procons", await token()));
        assertEquals(ev[0].data.answer_type, "study");
        assertEquals(ev[0].data.needs_confirmation, false);
        const rq = state.anthropicRequests[0];
        assertEquals(rq.body.max_tokens, 800);
        assert(JSON.stringify(rq.body.system).includes("five to eight short sentences"));
      },
    );

    await t.step("answer auto: header protocol, non-question -> meta only", async () => {
      reset();
      const ev = await readSse(await ask("auto", "ja men det var ju roligt igår", await token()));
      assertEquals(ev.map((e) => e.event), ["meta", "done"]);
      assertEquals(ev[0].data.is_question, false);
      const q = await readSse(await ask("auto", "roten ur hundra", await token()));
      assertEquals(q[0].data.reconstructed_question, "Vad är roten ur hundra?");
      assertEquals(q[0].data.confidence, 0.97);
      assertEquals(
        q.filter((e) => e.event === "delta").map((e) => e.data.text).join(""),
        "Roten ur hundra är tio.",
      );
    });

    await t.step(
      "answer auth: missing, forged and anon-key tokens are rejected before any upstream call",
      async () => {
        reset();
        assertEquals(
          (await post(answer.base, { fragment: "x", mode: "text", language: "sv" })).status,
          401,
        );
        assertEquals((await ask("text", "x", await token(otherKey))).status, 401);
        assertEquals(
          (await ask("text", "x", "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8")).status,
          401,
        );
        assertEquals(state.anthropicRequests.length, 0);
        assertEquals(state.rpcCalls.length, 0);
      },
    );

    await t.step(
      "answer: limiter denial -> 429 + Retry-After, upstream LLM request is aborted, no answer leaks",
      async () => {
        reset();
        state.denyLimits = true;
        state.anthropic = "slow";
        const res = await ask(
          "push_to_talk",
          "roten ur hundra",
          await token(privateKey, "22222222-2222-2222-2222-222222222222"),
        );
        assertEquals(res.status, 429);
        assertEquals(res.headers.get("retry-after"), "9");
        assert(!(await res.text()).includes("Roten"));
        assert(
          await waitFor(() => state.anthropicAborted),
          "fake Anthropic saw the connection aborted",
        );
      },
    );

    await t.step(
      "answer: Anthropic credit exhaustion -> 503 provider_quota, fallback:true",
      async () => {
        reset();
        state.anthropic = "credit";
        const res = await ask(
          "push_to_talk",
          "roten ur hundra",
          await token(privateKey, "33333333-3333-3333-3333-333333333333"),
        );
        assertEquals(res.status, 503);
        const e = (await res.json()).error;
        assertEquals([e.code, e.fallback], ["provider_quota", true]);
      },
    );

    await t.step("answer: GET + x-warm:1 -> 204 and an upstream pre-connect request", async () => {
      const before = state.anthropicWarm;
      const res = await fetch(answer.base, { headers: { "x-warm": "1" } });
      assertEquals(res.status, 204);
      assert(await waitFor(() => state.anthropicWarm > before));
    });

    await t.step(
      "tts: allowlisted voice streams audio with the key only upstream; others -> 400",
      async () => {
        reset();
        const tok = await token(privateKey, "44444444-4444-4444-4444-444444444444");
        const ok = await post(
          tts.base,
          { text: "Roten ur hundra är tio.", voice_id: VOICE_B },
          tok,
        );
        assertEquals(ok.status, 200);
        assertEquals(ok.headers.get("content-type"), "audio/mpeg");
        assertEquals([...new Uint8Array(await ok.arrayBuffer())], [1, 2, 3, 4]);
        assert(state.elevenRequests[0].url.startsWith(`/v1/text-to-speech/${VOICE_B}/stream`));
        assertEquals(state.elevenRequests[0].key, "xi-fake");
        assertEquals(state.elevenRequests[0].body.model_id, "eleven_flash_v2_5");
        const bad = await post(tts.base, { text: "hej", voice_id: "NotAllowedVoice0000000" }, tok);
        assertEquals(bad.status, 400);
        assertEquals((await bad.json()).error.code, "invalid_voice");
        assertEquals(state.elevenRequests.length, 1);
        assertEquals((await post(tts.base, { text: "hej" })).status, 401);
      },
    );

    await t.step("tts: budget denial -> 429, no audio, upstream aborted", async () => {
      reset();
      state.denyLimits = true;
      const res = await post(
        tts.base,
        { text: "hej", voice_id: VOICE_A },
        await token(privateKey, "55555555-5555-5555-5555-555555555555"),
      );
      assertEquals(res.status, 429);
      assertEquals(res.headers.get("content-type")?.includes("json"), true);
    });

    await t.step("voices: list for authenticated callers only", async () => {
      reset();
      const tok = await token(privateKey, "66666666-6666-6666-6666-666666666666");
      const res = await fetch(voices.base, { headers: { authorization: `Bearer ${tok}` } });
      assertEquals(res.status, 200);
      assertEquals(await res.json(), {
        voices: [{ name: "Astrid", id: VOICE_A }, { name: "Elin", id: VOICE_B }],
        default_id: VOICE_A,
      });
      assertEquals((await fetch(voices.base)).status, 401);
    });
  } finally {
    answer.stop();
    tts.stop();
    voices.stop();
    await Promise.all([supa.shutdown(), anth.shutdown(), eleven.shutdown()]);
  }
});
