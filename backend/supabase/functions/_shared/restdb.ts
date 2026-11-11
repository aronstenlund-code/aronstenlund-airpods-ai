/**
 * Minimal PostgREST client (fetch only). Replaces supabase-js on the hot path: importing
 * supabase-js costs ~75 ms of isolate boot time and every request here may run in a fresh isolate.
 * Uses the service-role key, which Supabase injects into Edge Functions; it never leaves the function.
 */
import { secret } from "./secrets.ts";
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

  /** Insert one row, silently ignoring a duplicate of the unique column `onConflict` (nothing is overwritten). */
  async insertIgnoreDuplicate(table: string, row: object, onConflict: string): Promise<void> {
    const r = await this.fetchImpl(
      `${this.baseUrl}/rest/v1/${table}?on_conflict=${encodeURIComponent(onConflict)}`,
      {
        method: "POST",
        headers: this.headers({ prefer: "resolution=ignore-duplicates,return=minimal" }),
        body: JSON.stringify(row),
      },
    );
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`insert ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
  }

  /** POST /rest/v1/<table> with an array of rows (no representation back). Throws on non-2xx. */
  async insertMany(table: string, rows: object[]): Promise<void> {
    if (!rows.length) return;
    const r = await this.fetchImpl(`${this.baseUrl}/rest/v1/${table}`, {
      method: "POST",
      headers: this.headers({ prefer: "return=minimal" }),
      body: JSON.stringify(rows),
    });
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`insert ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
  }

  /** Like insertMany, but rows that hit the unique key `onConflict` are skipped (D82). */
  async insertManyIgnoreDuplicates(table: string, rows: object[], onConflict: string): Promise<void> {
    if (!rows.length) return;
    const r = await this.fetchImpl(
      `${this.baseUrl}/rest/v1/${table}?on_conflict=${encodeURIComponent(onConflict)}`,
      {
        method: "POST",
        headers: this.headers({ prefer: "resolution=ignore-duplicates,return=minimal" }),
        body: JSON.stringify(rows),
      },
    );
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`insert ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
  }

  /** DELETE /rest/v1/<table>?<filter>; returns the number of deleted rows. `filter` is a PostgREST query. */
  async deleteWhere(table: string, filter: string): Promise<number> {
    const r = await this.fetchImpl(`${this.baseUrl}/rest/v1/${table}?${filter}`, {
      method: "DELETE",
      headers: this.headers({ prefer: "return=minimal,count=exact" }),
    });
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`delete ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
    const m = /\/(\d+)$/.exec(r.headers.get("content-range") ?? "");
    return m ? Number(m[1]) : 0;
  }

  /** Insert one row, or replace the row with the same unique key `onConflict` (K36: a reconnect). */
  async upsert(table: string, row: object, onConflict: string): Promise<void> {
    const r = await this.fetchImpl(
      `${this.baseUrl}/rest/v1/${table}?on_conflict=${encodeURIComponent(onConflict)}`,
      { method: "POST", headers: this.headers({ prefer: "resolution=merge-duplicates,return=minimal" }), body: JSON.stringify(row) },
    );
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`upsert ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
  }

  /** PATCH /rest/v1/<table>?<filter> with `patch`; returns the number of changed rows. */
  async updateWhere(table: string, filter: string, patch: object): Promise<number> {
    const r = await this.fetchImpl(`${this.baseUrl}/rest/v1/${table}?${filter}`, {
      method: "PATCH",
      headers: this.headers({ prefer: "return=minimal,count=exact" }),
      body: JSON.stringify(patch),
    });
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`update ${table} failed: HTTP ${r.status}`);
    }
    await r.body?.cancel();
    const m = /\/(\d+)$/.exec(r.headers.get("content-range") ?? "");
    return m ? Number(m[1]) : 0;
  }

  /** GET /rest/v1/<table>?<query>; returns the parsed rows. */
  async select(table: string, query: string): Promise<unknown[]> {
    const r = await this.fetchImpl(`${this.baseUrl}/rest/v1/${table}?${query}`, {
      headers: this.headers(),
    });
    if (!r.ok) {
      await r.body?.cancel();
      throw new Error(`select ${table} failed: HTTP ${r.status}`);
    }
    return await r.json();
  }
}

export function restDbFromEnv(env: { get(k: string): string | undefined } = Deno.env): RestDb {
  const url = env.get("SUPABASE_URL");
  const key = secret(env, "SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
  return new RestDb(url.replace(/\/+$/, ""), key);
}
