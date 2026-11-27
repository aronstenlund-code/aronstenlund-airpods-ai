// O106 L1 / D272: in the listening mode (auto) a clear question ("Vad ska vi äta ikväll?") no longer skips the gate.
// The gate runs IN PARALLEL with the direct answer (K68's path stays as fast): nothing is said until it says yes;
// "nej" = silence (is_question false). Addressed questions (the name, the activation words = push_to_talk) never wait.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG, LISTEN_GATE_PROMPT } from "./handler.ts";
import type { LLMChunk, LLMRequest } from "./llm/types.ts";

function world(gate: string | Error, gateMs = 0, answerMs = 0) {
  const seen: LLMRequest[] = [];
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: "u-o106", isAnonymous: false }), rateLimiter: new MemoryRateLimiter(),
    provider: {
      name: "f", model: "f",
      stream: (r) => {
        seen.push(r);
        const isGate = r.system === LISTEN_GATE_PROMPT;
        return (async function* (): AsyncGenerator<LLMChunk> {
          await new Promise((ok) => setTimeout(ok, isGate ? gateMs : answerMs));
          if (isGate && gate instanceof Error) throw gate;
          yield { type: "text", text: isGate ? String(gate) : "Det var 1914." };
        })();
      },
    },
    recordUsage: () => {}, config: DEFAULT_CONFIG,
  });
  const ask = async (fragment: string, mode = "auto") => {
    const t0 = performance.now();
    const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.6" }, body: JSON.stringify({ fragment, mode, language: "sv", context: {} }) }));
    const text = await res.text();
    const said = [...text.matchAll(/event: delta\ndata: (.*)/g)].map((m) => JSON.parse(m[1]).text).join("");
    const done = JSON.parse(/event: done\ndata: (.*)/.exec(text)?.[1] ?? "{}");
    return { said, done, ms: performance.now() - t0, gates: seen.filter((r) => r.system === LISTEN_GATE_PROMPT) };
  };
  return { ask };
}


Deno.test("O106 L1: everyday questions between people are not answered in the listening mode (the gate says nej)", async () => {
  for (const q of ["Vad ska vi äta ikväll?", "Hur mår din mamma nu?", "Var lade du mina nycklar?"]) {
    const r = await world("nej").ask(q);
    assertEquals(r.said, "", q);
    assertEquals(r.done.answered, false, q);
    assertEquals(r.gates.length, 1);
    assert(r.gates[0].user.includes(q), "the gate hears the utterance");
  }
});

Deno.test("O106 L1: a real question is answered, and the gate costs no time when it is the faster one", async () => {
  const r = await world("ja", 50, 200).ask("Vilket år började första världskriget?");
  assertEquals(r.said.includes("nittonhundrafjorton"), true, r.said);
  assert(r.ms < 330, `${Math.round(r.ms)} ms: the gate ran alongside the answer (50 ms + 200 ms one after the other = 250+)`);
});

Deno.test("O106 L1: a failing gate answers as before; addressed questions (push_to_talk, the name) never ask the gate", async () => {
  assertEquals((await world(new Error("timeout")).ask("Vilket år började första världskriget?")).said.length > 0, true);
  const ptt = await world("nej").ask("Vad ska vi äta ikväll?", "push_to_talk");
  assertEquals([ptt.gates.length, ptt.said.length > 0], [0, true]);
  const named = await world("nej").ask("Lumen, vilket år började första världskriget?");
  assertEquals(named.gates.length, 0);
});
