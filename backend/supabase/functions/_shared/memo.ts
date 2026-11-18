/** K100: a value read from the database kept for a short while in this instance (settings change rarely). */
export function memo<T>(f: () => Promise<T>, ttlMs = 60_000, now: () => number = Date.now): () => Promise<T> {
  let at = 0;
  let p: Promise<T> | null = null;
  return () => {
    if (p && now() - at < ttlMs) return p;
    at = now();
    p = f().catch((e) => {
      p = null; // a failure is not kept
      throw e;
    });
    return p;
  };
}
