/**
 * A key is a service key when the database treats it as one: a read of a table that only the service role may read
 * (RLS on, no grants to anon/authenticated) answers 200. The runtime's injected SUPABASE_SERVICE_ROLE_KEY and the
 * project's legacy service_role JWT (the repo secret the workflows use) are both service keys but different strings,
 * so an exact match alone refuses one of them (Reported cases 401 since 2026-11-15; voice-lab K6 solved it the same
 * way). Only accepted keys are remembered, so random keys never fill the memory.
 */
export function serviceKeyVerifier(baseUrl: string, fetchFn: typeof fetch = fetch): (key: string) => Promise<boolean> {
  const ok = new Set<string>();
  const base = baseUrl.replace(/\/+$/, "");
  return async (key: string) => {
    if (ok.has(key)) return true;
    if (!base || !/^(?:sb_secret_[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.test(key)) return false;
    const headers: Record<string, string> = { apikey: key };
    if (key.startsWith("eyJ")) headers.authorization = `Bearer ${key}`;
    const r = await fetchFn(`${base}/rest/v1/drill_audio_files?select=hash&limit=1`, { headers, signal: AbortSignal.timeout(5000) }).catch(() => null);
    await r?.body?.cancel();
    if (r?.status !== 200) return false;
    ok.add(key);
    return true;
  };
}
