// Pure helpers for the funds screen (src/app/funds.tsx): premium colour and caption, the holdings order and bar
// width, and the fund against its own basket. TER, NAV, premium, fees paid, the 10-year TER cost and both returns
// come from the server (engine, M2c); the only arithmetic here is the display difference fund − basket.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

/** Colour token of the premium; the screen maps it to c.textPrimary / c.warning / c.info. */
export type PremiumTone = 'textPrimary' | 'warning' | 'info';

/** Price above NAV (premium) is a warning, below (discount) is info; none or zero is plain. */
export function premiumTone(bps: number | null | undefined): PremiumTone {
  if (bps == null || bps === 0) return 'textPrimary';
  return bps > 0 ? 'warning' : 'info';
}

/** Translation key of the sentence under the premium. */
export function premiumCaptionKey(bps: number | null | undefined): string {
  if (bps == null) return 'funds.premiumNone';
  if (bps > 0) return 'funds.premiumAbove';
  if (bps < 0) return 'funds.premiumBelow';
  return 'funds.premiumZero';
}

/** Holdings, heaviest first; the input is left untouched. */
export function sortedHoldings<T extends { weightBps: number }>(holdings: readonly T[]): T[] {
  return holdings.slice().sort((a, b) => b.weightBps - a.weightBps);
}

/** Width of a holding's weight bar in percent of the row, clamped to 0..100 (layout only, not money). */
export function weightBarPercent(weightBps: number): number {
  return Math.min(100, Math.max(0, weightBps / 100));
}

/**
 * Fund return minus its basket's return, in basis points — display only: both returns are the server's, and this
 * difference is how far fees and cash drag put the fund behind (or ahead of) what it holds. Null until both are known.
 */
export function basketGap(fundReturnBps: number | null | undefined, basketReturnBps: number | null | undefined): number | null {
  return fundReturnBps != null && basketReturnBps != null ? fundReturnBps - basketReturnBps : null;
}

/** Colour token of the gap: zero or ahead is positive, behind is negative, unknown has no colour. */
export function gapTone(gap: number | null): 'positive' | 'negative' | undefined {
  if (gap == null) return undefined;
  return gap >= 0 ? 'positive' : 'negative';
}

/** Translation key of the sentence under the comparison. */
export function vsBasketCaptionKey(gap: number | null): string {
  return gap == null ? 'funds.vsBasketLater' : 'funds.vsBasketHint';
}
