// Pure helpers for the M2b screens (company card, calendar, bonds, real world). Integers only; no floats for money.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

/** A bank day of simulation time. */
export const BANK_DAY_MS = 60_000;

/**
 * Gap-risk rule for the company card: warn only when the server says a report comes out while the market is closed,
 * I have stops on this instrument that the open may jump through, and the report has not happened yet.
 */
export function showGapWarning(warning: { reportAt: number; conditionalIds: number[] } | null | undefined, now: number): boolean {
  if (!warning) return false;
  return warning.conditionalIds.length > 0 && warning.reportAt >= now;
}

/** A value × 100 as a decimal string with up to two decimals, without floats: 1250 → "12.5", −305 → "−3.05". */
export function formatX100(x100: number, decimalSep = '.'): string {
  const neg = x100 < 0;
  const a = Math.abs(Math.trunc(x100));
  const whole = Math.floor(a / 100);
  const frac = String(a % 100).padStart(2, '0').replace(/0+$/, '');
  return (neg ? '−' : '') + whole + (frac ? decimalSep + frac : '');
}

/** Basis points as a signed percent: 450 → "+4.5%", −1200 → "−12%", 0 → "0%". */
export function signedPercent(bps: number, decimalSep = '.'): string {
  const body = formatX100(bps, decimalSep);
  return (bps > 0 ? '+' : '') + body + '%';
}

export type ChartCandle = { start: number; open: number; high: number; low: number; close: number };
export type ChartBar = { x: number; width: number; top: number; bottom: number; bodyTop: number; bodyBottom: number; up: boolean };

/**
 * Lays daily candles into a box of `width` × `height` px: one equal slot per candle, prices mapped linearly with the
 * highest high at the top. Pixel positions are layout, not money, so they may be fractional.
 * Returns the bars and a function placing a time (e.g. a dividend ex-date) on the x axis, or null outside the range.
 */
export function scaleCandles(candles: ChartCandle[], width: number, height: number, dayMs: number = BANK_DAY_MS): {
  bars: ChartBar[];
  min: number;
  max: number;
  xOf: (t: number) => number | null;
} {
  const head = candles[0];
  const last = candles[candles.length - 1];
  if (!head || !last) return { bars: [], min: 0, max: 0, xOf: () => null };
  let min = head.low;
  let max = head.high;
  for (const c of candles) {
    if (c.low < min) min = c.low;
    if (c.high > max) max = c.high;
  }
  // Before the first layout pass the box has no size: price range is known, positions are not.
  if (!(width > 0) || !(height > 0)) return { bars: [], min, max, xOf: () => null };
  const range = max - min || 1;
  const y = (p: number) => ((max - p) * height) / range;
  const slot = width / candles.length;
  const bars = candles.map((c, i) => ({
    x: i * slot,
    width: slot,
    top: y(c.high),
    bottom: y(c.low),
    bodyTop: y(Math.max(c.open, c.close)),
    bodyBottom: y(Math.min(c.open, c.close)),
    up: c.close >= c.open,
  }));
  const first = head.start;
  const end = last.start + dayMs;
  const xOf = (t: number) => {
    if (t < first || t >= end) return null;
    const i = candles.findIndex((c) => t >= c.start && t < c.start + dayMs);
    // Inside the range but between candles (a day without trades): place it proportionally.
    return i >= 0 ? i * slot + slot / 2 : ((t - first) * width) / (end - first);
  };
  return { bars, min, max, xOf };
}

/** Whole bank days from `now` until `at` (rounded up), or 0 if it has passed. */
export function bankDaysUntil(at: number, now: number, dayMs: number = BANK_DAY_MS): number {
  return at <= now ? 0 : Math.ceil((at - now) / dayMs);
}

/** Random Idempotency-Key (≤ 64 chars) for one user action; a retry of the same action reuses it. */
export function newIdempotencyKey(): string {
  const g = globalThis as { crypto?: { randomUUID?: () => string } };
  if (g.crypto?.randomUUID) return g.crypto.randomUUID();
  let s = '';
  for (let i = 0; i < 32; i++) s += Math.floor(Math.random() * 16).toString(16);
  return s;
}
