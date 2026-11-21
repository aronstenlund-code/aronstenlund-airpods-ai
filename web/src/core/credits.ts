/// Credits (D213): 1 credit = 1 character of new sound. Every number comes from the server; these are the shapes.

export interface Quota {
  unit?: string;
  limit: number;
  used?: number;
  remaining?: number;
  left?: number;
  resets?: string;
  resets_day?: string;
  unlimited?: boolean;
}

export function creditsLeft(quota: Quota | null): number | null {
  if (quota === null) return null;
  if (quota.unlimited === true) return Number.MAX_SAFE_INTEGER;
  const left = quota.remaining ?? quota.left ?? quota.limit - (quota.used ?? 0);
  return Math.max(0, left);
}

/// "1 236": thousands with a space that does not break the line (Kelly Ke71).
export function thousands(n: number): string {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

/// The capsule: "1,5k" above a thousand (rounded down, so it never promises more than there is), else the number.
export function short(n: number, decimal: string): string {
  if (n < 1000) return String(Math.max(0, Math.floor(n)));
  const tenths = Math.floor(n / 100) / 10;
  const text = Number.isInteger(tenths) ? String(tenths) : tenths.toFixed(1).replace('.', decimal);
  return `${text}k`;
}
