// Secrets read from env, cleaned of what pasting on a phone adds (K0, 2026-11-08):
// leading/trailing whitespace, line breaks, non-breaking or zero-width spaces and surrounding quotes.
// API keys and service keys never contain whitespace, so any whitespace inside is removed too.
// An invalid character in a header value makes fetch throw before any request is sent, which
// showed up as 502 provider_unavailable on every call.

const INVISIBLE = /[\s\u00a0\u1680\u180e\u2000-\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]+/gu;

export function cleanSecret(raw: string | undefined | null): string | null {
  if (raw === undefined || raw === null) return null;
  let s = raw.replace(INVISIBLE, "");
  const q = /^(["'`“”‘’])(.*)\1$/su.exec(s) ?? /^[“‘](.*)[”’]$/su.exec(s);
  if (q) s = q[q.length - 1];
  return s === "" ? null : s;
}

/** Reads a secret from env and cleans it; null when unset or empty. */
export function secret(env: { get(k: string): string | undefined }, name: string): string | null {
  return cleanSecret(env.get(name));
}

/** Removes anything that looks like a key from text before it is logged. */
export function redactSecrets(text: string, ...known: (string | null | undefined)[]): string {
  let out = text;
  for (const k of known) if (k && k.length >= 8) out = out.split(k).join("[redacted]");
  return out
    .replace(/sk-ant-[A-Za-z0-9_-]+/g, "sk-ant-[redacted]")
    .replace(/\bsk_[A-Za-z0-9]{16,}/g, "sk_[redacted]")
    .replace(/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, "[jwt redacted]");
}

/** One log line saying why a provider call failed: status, error name and the first 200 characters
 *  of the message, with keys removed. Never logs the key itself. */
export function logProviderFailure(
  provider: string,
  status: number | null,
  failure: unknown,
  key?: string | null,
  log: (line: string) => void = console.error,
): void {
  const err = failure instanceof Error ? failure : undefined;
  const cause = (err as { cause?: unknown } | undefined)?.cause;
  const text = (err ? err.message : String(failure ?? "")) +
    (cause instanceof Error ? ` (cause: ${cause.name}: ${cause.message})` : "");
  log(JSON.stringify({
    event: "provider_unavailable",
    provider,
    status,
    error: err?.name ?? null,
    message: redactSecrets(text, key).slice(0, 200),
  }));
}
