// Pure helpers for the deposits screen (src/app/deposits.tsx): which deposits to list, interest earned to date,
// the rule-of-72 years as text and the length of a bank day in the largest whole unit. Integers only (minor units).
// The rate and the rule of 72 themselves live in src/finance.ts; this file does not repeat them.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

/** How many closed deposits the screen lists under the open ones (most recent first, as the server sends them). */
export const CLOSED_SHOWN = 5;

/** The fields of a deposit these helpers read (a subset of Schemas['SavingsDeposit']). */
export type DepositLike = { principal: number; balance: number; interest?: number | null; status: 'OPEN' | 'CLOSED' };

/** Open deposits, and the first `closedShown` closed ones; a missing list is an empty one. */
export function splitDeposits<T extends { status: 'OPEN' | 'CLOSED' }>(list: T[] | null | undefined, closedShown: number = CLOSED_SHOWN): { open: T[]; closed: T[] } {
  const all = list ?? [];
  return { open: all.filter((d) => d.status === 'OPEN'), closed: all.filter((d) => d.status === 'CLOSED').slice(0, Math.max(0, closedShown)) };
}

/** Interest earned so far: the server's `interest` when sent, otherwise balance − principal. */
export function interestToDate(d: DepositLike): number {
  return d.interest ?? d.balance - d.principal;
}

/** Tenths of a year as text: 51 → "5.1" (or "5,1"); null (no rate) → "—". */
export function tenthsText(tenths: number | null | undefined, decimalSep = '.'): string {
  if (tenths == null) return '—';
  return `${Math.floor(tenths / 10)}${decimalSep}${tenths % 10}`;
}

export type DurationUnit = 'hours' | 'minutes' | 'seconds';

/**
 * Length of one bank day in the largest unit that divides it exactly: 3 600 000 ms → 1 hour, 60 000 ms → 1 minute,
 * 90 000 ms → 90 seconds. The unit is the i18n key under `units.`.
 */
export function bankDayLength(dayMillis: number): { unit: DurationUnit; count: number } {
  const sec = Math.floor(dayMillis / 1000);
  if (sec >= 3600 && sec % 3600 === 0) return { unit: 'hours', count: sec / 3600 };
  if (sec >= 60 && sec % 60 === 0) return { unit: 'minutes', count: sec / 60 };
  return { unit: 'seconds', count: sec };
}
