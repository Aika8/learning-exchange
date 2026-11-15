// Pure finance helpers for the M2a screens. Integers only (minor units, basis points); no floats for money.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

/**
 * Position size from a risk budget: qty = floor(capital × risk / |entry − stop|).
 * capital, entry and stop are minor units of the quote; riskBps is basis points (100 = 1%).
 * Returns null when the inputs cannot give a size (no distance to the stop, nothing to risk).
 */
export function positionSize(capital: number, riskBps: number, entry: number, stop: number): { qty: number; riskBudget: number; atRisk: number } | null {
  if (!(capital > 0) || !(riskBps > 0) || !(entry > 0) || !(stop > 0)) return null;
  const distance = Math.abs(entry - stop);
  if (distance === 0) return null;
  const riskBudget = Math.floor((capital * riskBps) / 10_000);
  const qty = Math.floor(riskBudget / distance);
  return { qty, riskBudget, atRisk: qty * distance };
}

/**
 * Rule of 72: years to double ≈ 72 / rate%. rateBps 1400 (14%) → 72 / 14 ≈ 5.1.
 * Returned in tenths of a year, rounded half up, to stay in integers: 1400 → 51.
 */
export function ruleOf72Tenths(rateBps: number): number | null {
  if (!(rateBps > 0)) return null;
  // 72 / (rateBps / 100) years = 7200 / rateBps years = 72000 / rateBps tenths.
  return Math.floor((72_000 * 2 + rateBps) / (2 * rateBps));
}

/** Spread of a two-sided quote: absolute, mid (rounded down) and in basis points of the mid (rounded half up). */
export function spreadInfo(bid: number, ask: number): { spread: number; mid: number; spreadBps: number } | null {
  if (!(bid > 0) || !(ask > 0) || ask < bid) return null;
  const spread = ask - bid;
  const mid = Math.floor((bid + ask) / 2);
  const spreadBps = Math.floor((spread * 10_000 * 2 + mid) / (2 * mid));
  return { spread, mid, spreadBps };
}

/**
 * Cost of an FX market order of `qty` units at the best price (buy at ask, sell at bid):
 * notional, fee (floor of notional × feeBps), cost of the spread against the mid, and the total money moved.
 */
export function fxQuote(side: 'BUY' | 'SELL', qty: number, bid: number, ask: number, feeBps: number): { price: number; notional: number; fee: number; spreadCost: number; total: number } | null {
  const s = spreadInfo(bid, ask);
  if (!s || !(qty > 0)) return null;
  const price = side === 'BUY' ? ask : bid;
  const notional = price * qty;
  const fee = Math.floor((notional * feeBps) / 10_000);
  const spreadCost = (side === 'BUY' ? price - s.mid : s.mid - price) * qty;
  const total = side === 'BUY' ? notional + fee : notional - fee;
  return { price, notional, fee, spreadCost, total };
}

/** Basis points as a percent string with up to two decimals, without floats: 1400 → "14", 5 → "0.05". */
export function bpsToPercent(bps: number, decimalSep = '.'): string {
  const neg = bps < 0;
  const a = Math.abs(Math.trunc(bps));
  const whole = Math.floor(a / 100);
  const frac = String(a % 100).padStart(2, '0').replace(/0+$/, '');
  return (neg ? '−' : '') + whole + (frac ? decimalSep + frac : '');
}
