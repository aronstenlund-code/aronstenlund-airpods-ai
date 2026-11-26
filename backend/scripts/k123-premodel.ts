/**
 * K123 (Deangelo 23:38): time on the server BEFORE the model starts (and to the first byte of answers the server
 * gives itself), measured locally with every database round trip simulated at DB_MS (default 60 ms). No network,
 * no model, 0 ElevenLabs. Usage: deno run --allow-read --allow-env scripts/k123-premodel.ts [DB_MS]
 */
import { MemoryRateLimiter } from "../supabase/functions/_shared/ratelimit.ts";
import { createHandler, DEFAULT_CONFIG } from "../supabase/functions/answer/handler.ts";
import type { LLMChunk, LLMProvider } from "../supabase/functions/answer/llm/types.ts";

const DB = Number(Deno.args[0] ?? 60);
const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
console.log = console.warn = console.error = () => {};
const out = (s: string) => Deno.stdout.writeSync(new TextEncoder().encode(s + "\n"));

function limiter() {
  const mem = new MemoryRateLimiter();
  return {
    check: async (k: string, l: number, w: number, c?: number) => (await wait(DB), mem.check(k, l, w, c)),
    checkMany: async (cs: { key: string; limit: number; windowSec: number }[], c?: number) => {
      await wait(DB);
      let last = await mem.check(cs[0].key, cs[0].limit, cs[0].windowSec, c);
      for (const x of cs.slice(1)) if (last.allowed) last = await mem.check(x.key, x.limit, x.windowSec, c);
      return last;
    },
  } as unknown as InstanceType<typeof MemoryRateLimiter>;
}

async function run(label: string, body: Record<string, unknown>, usageBlocks: boolean, silent = false) {
  let modelAt: number | null = null;
  const t0 = performance.now();
  const provider: LLMProvider = {
    name: "f", model: "f",
    stream: () => {
      modelAt ??= performance.now() - t0;
      return (async function* (): AsyncGenerator<LLMChunk> { yield { type: "text", text: "Svaret." }; })();
    },
  };
  const h = createHandler({
    authenticate: () => Promise.resolve({ id: `u-${label}-${Math.random()}`, isAnonymous: false }),
    rateLimiter: limiter(), localLimiter: new MemoryRateLimiter(), provider,
    recordUsage: () => (usageBlocks ? wait(DB) : undefined) as void,
    fetchImpl: () => Promise.reject(new Error("no network")),
    config: DEFAULT_CONFIG,
  });
  const res = await h(new Request("http://x/answer", { method: "POST", headers: { "content-type": "application/json", "x-forwarded-for": "198.51.100.7" }, body: JSON.stringify({ language: "sv", context: {}, ...body }) }));
  const reader = res.body!.getReader();
  await reader.read();
  const firstByte = performance.now() - t0;
  while (!(await reader.read()).done) { /* drain */ }
  if (!silent) out(`${label.padEnd(34)} model start ${modelAt === null ? "  –   " : `${Math.round(modelAt)} ms`.padStart(6)}   first byte ${`${Math.round(firstByte)} ms`.padStart(6)}`);
}

// warm-up: the first call compiles the handler's code paths (a cold isolate pays that once; not measured here)
{
  const keep = out;
  // deno-lint-ignore no-explicit-any
  (globalThis as any).__quiet = true;
  for (const f of ["vad heter Norges huvudstad", "recept på pannkakor", "vad är 23 gånger 19", "jag vill inte leva längre"]) await run("warm", { fragment: f, mode: "push_to_talk" }, false, true);
  void keep;
}
out(`database round trip simulated at ${DB} ms`);
for (const blocks of [true, false]) {
  out(blocks ? "-- usage row written before the answer (before K123)" : "-- usage row in the background (K123)");
  await run("fakta (tryck och prata)", { fragment: "vad heter Norges huvudstad", mode: "push_to_talk" }, blocks);
  await run("Provläge", { fragment: "vad är fotosyntes", mode: "tutor", goals: "Biologi 1" }, blocks);
  await run("webb (recept)", { fragment: "recept på pannkakor", mode: "push_to_talk" }, blocks);
  await run("räkning i koden", { fragment: "vad är 23 gånger 19", mode: "push_to_talk" }, blocks);
  await run("krissvar i koden", { fragment: "jag vill inte leva längre", mode: "push_to_talk" }, blocks);
}
