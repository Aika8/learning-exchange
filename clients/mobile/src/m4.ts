// Pure helpers for the M4 screens (rebalancing reminder, lump sum vs DCA). Integers only: minor units, basis points.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

/** Twice a year: a check is due when at least half a year (182 bank days) passed since the last one. */
export const HALF_YEAR_DAYS = 182;
export const DRIFT_LIMIT_BPS = 500; // 5 percentage points

export function rebalanceDue(lastCheck: number | null, now: number, dayMillis: number): boolean {
  if (lastCheck == null) return true;
  return now - lastCheck >= HALF_YEAR_DAYS * dayMillis;
}

export type Drift = { key: string; value: number; actualBps: number; targetBps: number; driftBps: number };

/**
 * Shares of the portfolio against the targets (bps, summing to 10 000). Only shares that drifted by more than
 * 5 percentage points are returned, largest drift first. Values are minor units of one currency.
 */
export function drifts(values: Record<string, number>, targetsBps: Record<string, number>, limitBps = DRIFT_LIMIT_BPS): Drift[] {
  const keys = Array.from(new Set([...Object.keys(values), ...Object.keys(targetsBps)]));
  const total = keys.reduce((s, k) => s + Math.max(0, values[k] ?? 0), 0);
  if (total <= 0) return [];
  const out: Drift[] = [];
  for (const key of keys) {
    const value = Math.max(0, values[key] ?? 0);
    const actualBps = Math.floor((value * 10_000 + Math.floor(total / 2)) / total);
    const targetBps = targetsBps[key] ?? 0;
    const driftBps = actualBps - targetBps;
    if (Math.abs(driftBps) > limitBps) out.push({ key, value, actualBps, targetBps, driftBps });
  }
  return out.sort((a, b) => Math.abs(b.driftBps) - Math.abs(a.driftBps));
}

const UNIT = 1_000_000; // units of the asset are counted in millionths to keep integer maths

function valueOf(microUnits: number, price: number): number {
  return Math.floor((microUnits * price) / UNIT);
}

/** One window: invest `amount` at closes[s] (lump sum) or in `parts` equal parts at s, s+1, … (DCA); value at s+parts. */
export function lumpVsDcaWindow(closes: number[], s: number, amount: number, parts: number): { lump: number; dca: number } {
  const end = closes[s + parts] ?? 0;
  const lumpUnits = Math.floor((amount * UNIT) / (closes[s] ?? 1));
  const part = Math.floor(amount / parts);
  let dcaUnits = 0;
  let spent = 0;
  for (let i = 0; i < parts; i++) {
    const cash = i === parts - 1 ? amount - spent : part;
    dcaUnits += Math.floor((cash * UNIT) / (closes[s + i] ?? 1));
    spent += cash;
  }
  return { lump: valueOf(lumpUnits, end), dca: valueOf(dcaUnits, end) };
}

export type LumpVsDca = {
  windows: number;
  lumpWins: number;
  lumpWinsBps: number; // share of windows where the lump sum ended higher
  avgEdgeBps: number; // average (lump − DCA) as bps of the amount; > 0 favours the lump sum on this series
  worstLumpBps: number; // worst result of the lump sum, bps of the amount
  worstDcaBps: number;
};

/**
 * Lump sum against DCA over EVERY start in the price series (not a picked one), so the statistic is honest about
 * this series: how often each won, by how much on average, and the worst outcome of each. Past prices say nothing
 * certain about future ones; the screen says so.
 */
export function lumpVsDca(closes: number[], amount: number, parts: number): LumpVsDca | null {
  if (!(amount > 0) || !(parts >= 2) || closes.some((p) => !(p > 0))) return null;
  const windows = closes.length - parts;
  if (windows < 1) return null;
  let lumpWins = 0;
  let edgeSum = 0;
  let worstLump = Infinity;
  let worstDca = Infinity;
  for (let s = 0; s < windows; s++) {
    const { lump, dca } = lumpVsDcaWindow(closes, s, amount, parts);
    if (lump > dca) lumpWins++;
    edgeSum += lump - dca;
    worstLump = Math.min(worstLump, lump - amount);
    worstDca = Math.min(worstDca, dca - amount);
  }
  const bps = (x: number) => Math.round((x * 10_000) / amount);
  return {
    windows,
    lumpWins,
    lumpWinsBps: Math.round((lumpWins * 10_000) / windows),
    avgEdgeBps: bps(edgeSum / windows),
    worstLumpBps: bps(worstLump),
    worstDcaBps: bps(worstDca),
  };
}
