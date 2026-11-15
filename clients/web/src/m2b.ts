// Pure helpers for the M2b panels (companies, calendar, bonds, real world). Integers only; ratios come as ×100 integers.
import type { ConditionalOrder } from './api/client';
import { bpsPercent } from './m2a';

/** One bank day of simulation time, ms. */
export const BANK_DAY_MS = 60_000;

/** A ×100 integer as a decimal: 1250 → "12.5", 1205 → "12.05", −50 → "−0.5" (same rules as basis points to %). */
export function x100(value: number, locale: string): string {
  return (value < 0 ? '−' : '') + bpsPercent(Math.abs(value), locale);
}

/** Surprise in basis points as a signed percent: 1250 → "+12.5", −300 → "−3". */
export function signedPercent(bps: number, locale: string): string {
  const s = bpsPercent(Math.abs(bps), locale);
  return bps > 0 ? `+${s}` : bps < 0 ? `−${s}` : s;
}

/**
 * Gap-risk warning: the next report comes within one bank day and I have a stop that has not fired yet
 * (WAITING/ARMED) on that instrument — the market is closed on the report night, so the open may jump past it.
 */
export function gapRisk(
  instrument: string,
  nextReportAt: number | null | undefined,
  now: number | null | undefined,
  stops: Pick<ConditionalOrder, 'instrument' | 'state'>[],
): boolean {
  if (nextReportAt == null || now == null) return false;
  if (nextReportAt < now || nextReportAt - now > BANK_DAY_MS) return false;
  return stops.some((c) => c.instrument === instrument && (c.state === 'WAITING' || c.state === 'ARMED'));
}

/** Bank days (rounded up) until `at`, 0 if past. */
export function bankDaysUntil(at: number, now: number): number {
  return at <= now ? 0 : Math.ceil((at - now) / BANK_DAY_MS);
}
