/**
 * Minimal PostgREST client (fetch only). Replaces supabase-js on the hot path: importing
 * supabase-js costs ~75 ms of isolate boot time and every request here may run in a fresh isolate.
 * Uses the service-role key, which Supabase injects into Edge Functions; it never leaves the function.
 */
export class RestDb {
  constructor(
    private baseUrl: string,
    private key: string,
    private fetchImpl: typeof fetch = fetch,
  ) {}

  private headers(extra: Record<string, string> = {}): Record<string, string> {
    return {
      apikey: this.key,
      authorization: `Bearer ${this.key}`,
      "content-type": "application/json",
      ...extra,
    };
  }

  /** POST /rest/v1/rpc/<name>; returns the parsed JSON body. Throws on non-2xx. */
  async rpc(name: string, args: unknown): Promise<unknown> {
    const r = await this.fetchImpl(`${this.baseUrl}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(args),
    });
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`rpc ${name} failed: HTTP ${r.status}`);
    }
    return await r.json();
  }

  /** POST /rest/v1/<table> (insert one row, no representation back). Throws on non-2xx. */
  async insert(table: string, row: object): Promise<void> {
    const r = await this.fetchImpl(`${this.baseUrl}/rest/v1/${table}`, {
      method: "POST",
      headers: this.headers({ prefer: "return=minimal" }),
      body: JSON.stringify(row),
    });
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`insert ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
  }
}

export function restDbFromEnv(env: { get(k: string): string | undefined } = Deno.env): RestDb {
  const url = env.get("SUPABASE_URL");
  const key = env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
  return new RestDb(url.replace(/\/+$/, ""), key);
}
