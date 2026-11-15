// Pure helpers for the M2c panels (ATR position size, trade journal, session review, funds). Integers only, no floats for money.
import type { Schemas } from './api/client';
import { x100 } from './m2b';

/** "2" or "1.5" or "1,5" → k in tenths (20, 15); null for anything that is not a positive number with ≤ 1 decimal. */
export function parseTenths(text: string): number | null {
  const m = /^(\d+)(?:[.,](\d)?)?$/.exec(text.trim());
  if (!m) return null;
  const v = Number(m[1]) * 10 + Number(m[2] ?? '0');
  return Number.isSafeInteger(v) && v > 0 ? v : null;
}

/** Stop distance = k × ATR, k in tenths; rounded up so the real risk is never above the planned one. */
export function atrStopDistance(atrMinor: number, kTenths: number): number {
  return Math.ceil((atrMinor * kTenths) / 10);
}

/** Position size: qty = floor(risk / stop distance), so a stop-out loses at most 1 R. 0 when the inputs make no sense. */
export function sizeByRisk(riskMinor: number, stopDistanceMinor: number): number {
  if (riskMinor <= 0 || stopDistanceMinor <= 0) return 0;
  return Math.floor(riskMinor / stopDistanceMinor);
}

/** R × 100 as text: −150 → "−1.5 R". */
export function rText(rx100: number | null | undefined, locale: string): string {
  return rx100 == null ? '—' : `${rx100 > 0 ? '+' : ''}${x100(rx100, locale)} R`;
}

/** The journal note for POST /orders, or undefined when nothing was filled in. */
export function buildJournal(
  why: string,
  marketState: Schemas['MarketState'] | '',
  mood: Schemas['Mood'] | '',
  plannedRisk: number | null,
): Schemas['TradeNote'] | undefined {
  const note: Schemas['TradeNote'] = {};
  const w = why.trim().slice(0, 280);
  if (w) note.why = w;
  if (marketState) note.marketState = marketState;
  if (mood) note.mood = mood;
  if (plannedRisk != null && plannedRisk > 0) note.plannedRisk = plannedRisk;
  return Object.keys(note).length ? note : undefined;
}

/** Fund return minus basket return, bps (what the fund cost over the same time); null when either is unknown. */
export function fundGapBps(fundBps: number | null | undefined, basketBps: number | null | undefined): number | null {
  return fundBps == null || basketBps == null ? null : fundBps - basketBps;
}
