import { type LLMChunk, type LLMProvider, LLMProviderError, type LLMRequest } from "./types.ts";

/**
 * K11 (Oscar O5: one Provläge call gave nothing for 90 s): no answer may hang. The first text must come within
 * `firstTextMs`; otherwise the call is aborted and the same request goes to `fallbackModel` without thinking.
 * A provider error before any text (5xx, overloaded, upstream 429) falls back the same way. Once text has come,
 * a stream that stays silent for `idleMs` ends there, with what was already said.
 */
export interface DeadlineOptions {
  firstTextMs: number;
  idleMs: number;
  /** Model for the second try; none = the request fails as "unavailable" (the app has its own fallback). */
  fallbackModel?: string;
  log?: (event: string, data: Record<string, unknown>) => void;
}

const TIMEOUT = Symbol("timeout");

function race<T>(p: Promise<T>, ms: number): Promise<T | typeof TIMEOUT> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const t = new Promise<typeof TIMEOUT>((resolve) => {
    timer = setTimeout(() => resolve(TIMEOUT), Math.max(0, ms));
  });
  return Promise.race([p, t]).finally(() => clearTimeout(timer));
}

const RETRYABLE = new Set(["unavailable", "rate_limited"]);

export function withDeadline(p: LLMProvider, o: DeadlineOptions): LLMProvider {
  return { name: p.name, model: p.model, stream: (req) => deadlineStream(p, req, o) };
}

async function* deadlineStream(p: LLMProvider, req: LLMRequest, o: DeadlineOptions): AsyncIterable<LLMChunk> {
  const inner = new AbortController();
  const signal = req.signal ? AbortSignal.any([req.signal, inner.signal]) : inner.signal;
  const it = p.stream({ ...req, signal })[Symbol.asyncIterator]();
  const held: LLMChunk[] = [];
  let sawText = false;
  const t0 = Date.now();
  const model = req.model ?? p.model;
  const fallback = async function* (why: string, err?: LLMProviderError): AsyncIterable<LLMChunk> {
    inner.abort();
    it.return?.()?.catch?.(() => {});
    // an error on the fallback model itself is passed on as it is (a second call would fail the same way);
    // a hang is retried once even on the same model
    if (!o.fallbackModel || req.signal?.aborted || (err && o.fallbackModel === model)) {
      throw err ?? new LLMProviderError("unavailable", `No first text (${why})`, 504);
    }
    o.log?.("llm_fallback", { model, fallback: o.fallbackModel, why, ms: Date.now() - t0 });
    yield* p.stream({ ...req, model: o.fallbackModel, noThinking: true, think: false });
  };
  try {
    let pending = it.next();
    while (true) {
      let r: IteratorResult<LLMChunk> | typeof TIMEOUT;
      try {
        r = await race(pending, sawText ? o.idleMs : o.firstTextMs - (Date.now() - t0));
      } catch (e) {
        if (!sawText && e instanceof LLMProviderError && RETRYABLE.has(e.kind)) {
          yield* fallback(e.kind, e);
          return;
        }
        throw e;
      }
      if (r === TIMEOUT) {
        pending.catch(() => {});
        if (!sawText) {
          yield* fallback("timeout");
          return;
        }
        o.log?.("llm_stalled", { model, ms: Date.now() - t0 });
        inner.abort();
        it.return?.()?.catch?.(() => {});
        return; // what was said stays; the answer ends here
      }
      if (r.done) {
        for (const h of held) yield h;
        return;
      }
      const c = r.value;
      if (!sawText && c.type !== "text") {
        held.push(c); // usage before the first word: passed on with it (a timeout drops it with the call)
      } else {
        if (!sawText) {
          sawText = true;
          for (const h of held) yield h;
          held.length = 0;
        }
        yield c;
      }
      pending = it.next();
    }
  } finally {
    inner.abort();
  }
}
