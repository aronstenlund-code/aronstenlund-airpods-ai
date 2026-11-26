import type { RestDb } from "./restdb.ts";

/** Inserts into public.answer_usage with the service role and keeps the edge worker alive until done. */
export function supabaseUsageSink(db: RestDb) {
  return (rec: object): Promise<void> => {
    const p = db.insert("answer_usage", rec).catch((e) => {
      console.error("usage_insert_failed", e instanceof Error ? e.message : String(e));
    });
    // K123: on the platform the row is written in the background (waitUntil keeps the isolate alive for it), so no
    // answer waits for the insert; without EdgeRuntime (local dev) the caller still waits as before
    // deno-lint-ignore no-explicit-any
    const wu = (globalThis as any).EdgeRuntime?.waitUntil;
    if (typeof wu === "function") {
      // deno-lint-ignore no-explicit-any
      (globalThis as any).EdgeRuntime.waitUntil(p);
      return Promise.resolve();
    }
    return p;
  };
}

export function envInt(
  env: { get(k: string): string | undefined },
  name: string,
  dflt: number,
): number {
  const v = Number(env.get(name));
  return Number.isFinite(v) && v > 0 ? v : dflt;
}
