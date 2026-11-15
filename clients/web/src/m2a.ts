// Pure helpers for the M2a panels (stops, leverage, savings, statement). Integers only, no floats for money.
import type { AccountChanged, ConditionalKind, ConditionalOrder, ConditionalState } from './api/client';

type Reason = AccountChanged['reasons'][number];

/** Query keys to refetch for an account nudge. Balances, orders and the statement change with almost anything. */
export function queriesFor(reasons: Reason[]): string[] {
  const keys = new Set(['me', 'orders', 'statement']);
  if (reasons.includes('CONDITIONAL')) keys.add('conditional');
  if (reasons.includes('MARGIN')) keys.add('margin');
  if (reasons.includes('SAVINGS')) keys.add('savings');
  return [...keys];
}

export type ConditionalField = 'triggerPrice' | 'limitPrice' | 'activationPrice' | 'offset' | 'protectiveSpread';

/** Which price fields a conditional order kind needs (contract: PlaceConditionalRequest). */
export function fieldsFor(kind: ConditionalKind): ConditionalField[] {
  switch (kind) {
    case 'STOP_LIMIT':
      return ['triggerPrice', 'limitPrice'];
    case 'STOP_MARKET':
      return ['triggerPrice'];
    case 'TRAILING_TP':
      return ['activationPrice', 'offset', 'protectiveSpread'];
    case 'TP_SL':
      return ['triggerPrice', 'limitPrice', 'activationPrice', 'offset', 'protectiveSpread'];
  }
}

/**
 * Phase of a conditional order, so the UI can show that "fired" is not "filled":
 * pending (not fired yet), fired (rule fired, its order not fully filled yet), filled, failed, cancelled.
 */
export type Phase = 'pending' | 'fired' | 'filled' | 'failed' | 'cancelled';

export function phaseOf(state: ConditionalState): Phase {
  switch (state) {
    case 'WAITING':
    case 'ARMED':
      return 'pending';
    case 'TRIGGERED':
    case 'SUBMITTED':
    case 'PARTIALLY_FILLED':
      return 'fired';
    case 'FILLED':
      return 'filled';
    case 'UNFILLED':
    case 'REJECTED':
      return 'failed';
    case 'CANCELLED':
      return 'cancelled';
  }
}

/** Only an order that has not fired can be cancelled here; a fired one is cancelled as a normal order. */
export const canCancel = (c: Pick<ConditionalOrder, 'state'>) => phaseOf(c.state) === 'pending';

/** "filled / qty" of the generated order, or null when nothing was generated yet. */
export function fillText(c: Pick<ConditionalOrder, 'orderId' | 'filledQty' | 'qty'>): string | null {
  return c.orderId == null ? null : `${c.filledQty ?? 0} / ${c.qty}`;
}

/** Collateral ≈ notional / leverage, rounded up (price in minor units × whole base units). */
export function collateralPreview(priceMinor: number, qty: number, leverage: number): number {
  const notional = priceMinor * qty;
  return Math.floor((notional + leverage - 1) / leverage);
}

/** Equity as a whole percent of collateral, clamped to 0..100, for the bar (stop-out is at 50). */
export function equityPercent(equity: number, collateral: number): number {
  if (collateral <= 0) return 0;
  return Math.max(0, Math.min(100, Math.floor((equity * 100) / collateral)));
}
