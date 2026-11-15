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

/**
 * Position size with the stop set by volatility: stop distance = k × ATR, qty = floor(riskBudget / distance).
 * capital and atr are minor units of the quote; riskBps is basis points of capital (that budget is 1 R);
 * k is given ×100 (150 = 1.5 × ATR) so it stays an integer. The distance is rounded down to a minor unit.
 * Returns null when there is no ATR, no budget or the distance rounds to zero.
 */
export function atrPositionSize(capital: number, riskBps: number, atr: number | null | undefined, kX100: number): { distance: number; qty: number; riskBudget: number; atRisk: number } | null {
  if (!(capital > 0) || !(riskBps > 0) || !(kX100 > 0) || atr == null || !(atr > 0)) return null;
  const distance = Math.floor((atr * kX100) / 100);
  if (distance === 0) return null;
  const riskBudget = Math.floor((capital * riskBps) / 10_000);
  const qty = Math.floor(riskBudget / distance);
  return { distance, qty, riskBudget, atRisk: qty * distance };
}

/** Stop price at `distance` from the entry: below it for a long (BUY), above it for a short (SELL); null if it would be ≤ 0. */
export function stopFromDistance(entry: number, distance: number, side: 'BUY' | 'SELL'): number | null {
  if (!(entry > 0) || !(distance > 0)) return null;
  const stop = side === 'BUY' ? entry - distance : entry + distance;
  return stop > 0 ? stop : null;
}

/** Result in R ×100 as a signed string: −140 → "−1.4 R", 250 → "+2.5 R". */
export function formatR(rX100: number, decimalSep = '.'): string {
  return (rX100 > 0 ? '+' : '') + bpsToPercent(rX100, decimalSep) + ' R';
}
