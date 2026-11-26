/**
 * K121: model prices for the cost estimate (USD per million tokens; claude-api reference 2026-11-03: Haiku 5.5
 * $0.10/$0.50, cache reads 0.1x; Sonnet 5.5 $2/$10, cache reads $0.10 = 0.05x). Only the estimate in answer_usage
 * uses these; the model a call runs on is chosen elsewhere.
 */
const PRICES: Record<string, { inPerMTok: number; outPerMTok: number; cacheRead: number }> = {
  "claude-haiku-5-5": { inPerMTok: 0.10, outPerMTok: 0.50, cacheRead: 0.1 },
  "claude-sonnet-5-5": { inPerMTok: 2, outPerMTok: 10, cacheRead: 0.05 },
};

export function modelPrice(model: string): { inPerMTok: number; outPerMTok: number; cacheRead: number } | null {
  return PRICES[model] ?? null;
}

/** The share of the input price a cache read costs (0.1 when the model is not in the table). */
export function cacheReadMultiplier(model: string): number {
  return PRICES[model]?.cacheRead ?? 0.1;
}
