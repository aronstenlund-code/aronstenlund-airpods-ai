import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

/** Inserts into public.answer_usage with the service role and keeps the edge worker alive until done. */
export function supabaseUsageSink(db: SupabaseClient) {
  return (rec: object): Promise<void> => {
    const p = Promise.resolve(db.from("answer_usage").insert(rec)).then(({ error }) => {
      if (error) console.error("usage_insert_failed", error.message);
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
