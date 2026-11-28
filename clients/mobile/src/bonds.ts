// Pure helpers for the bonds screen (src/app/bonds.tsx): which bond the detail shows, the status badge colour, and
// whether it can still be traded. Yield to maturity, modified duration and the coupon schedule are computed by the
// server (engine, M2b) and only displayed here — no finance formula is repeated on the client.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

export type BondStatus = 'ACTIVE' | 'DEFAULTED' | 'REDEEMED';

/** Colour token of the status badge; the screen maps it to c.negative / c.textSecondary / c.positive. */
export type StatusTone = 'negative' | 'textSecondary' | 'positive';

/** A default is red, a redeemed bond is greyed out, a live one is green. */
export function statusTone(status: string): StatusTone {
  if (status === 'DEFAULTED') return 'negative';
  if (status === 'REDEEMED') return 'textSecondary';
  return 'positive';
}

/** Only a live bond can be traded; a defaulted or redeemed one has no trade button. */
export function canTrade(status: string): boolean {
  return status === 'ACTIVE';
}

/** The bond of the detail view (`?id=`); none for a missing or empty id or an unknown instrument. */
export function selectedBond<T extends { instrument: string }>(bonds: readonly T[], id: string | undefined | null): T | undefined {
  return id ? bonds.find((b) => b.instrument === id) : undefined;
}

/** «paid / left» of the coupon schedule, as the server counts them. */
export function couponsPaidLeft(b: { couponsPaid: number; couponsLeft: number }): string {
  return `${b.couponsPaid} / ${b.couponsLeft}`;
}

/** The next coupon date, or null when there is none (redeemed, defaulted, or the last one paid). */
export function nextCoupon(b: { nextCouponAt?: number | null }): number | null {
  return b.nextCouponAt ?? null;
}
