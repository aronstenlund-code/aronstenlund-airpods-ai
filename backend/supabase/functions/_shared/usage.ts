import type { RestDb } from "./restdb.ts";

/** Inserts into public.answer_usage with the service role and keeps the edge worker alive until done. */
export function supabaseUsageSink(db: RestDb) {
  return (rec: object): Promise<void> => {
    const p = db.insert("answer_usage", rec).catch((e) => {
      console.error("usage_insert_failed", e instanceof Error ? e.message : String(e));
    });
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(p);
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
