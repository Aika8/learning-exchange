import { describe, expect, it } from 'vitest';
import { bpsPercent, canCancel, collateralPreview, equityPercent, fieldsFor, fillText, phaseOf, queriesFor } from './m2a';

describe('conditional orders', () => {
  it('fired is not filled', () => {
    expect(phaseOf('SUBMITTED')).toBe('fired');
    expect(phaseOf('TRIGGERED')).toBe('fired');
    expect(phaseOf('FILLED')).toBe('filled');
    expect(phaseOf('UNFILLED')).toBe('failed');
    expect(phaseOf('ARMED')).toBe('pending');
  });
  it('only a not-yet-fired order can be cancelled', () => {
    expect(canCancel({ state: 'WAITING' })).toBe(true);
    expect(canCancel({ state: 'SUBMITTED' })).toBe(false);
  });
  it('shows fill of the generated order', () => {
    expect(fillText({ orderId: null, filledQty: 0, qty: 5 })).toBeNull();
    expect(fillText({ orderId: 7, filledQty: 2, qty: 5 })).toBe('2 / 5');
  });
  it('asks only for the relevant fields', () => {
    expect(fieldsFor('STOP_MARKET')).toEqual(['triggerPrice']);
    expect(fieldsFor('TRAILING_TP')).not.toContain('triggerPrice');
  });
});

describe('leverage', () => {
  it('collateral is notional / leverage rounded up, in integers', () => {
    expect(collateralPreview(50056, 100, 4)).toBe(1251400);
    expect(collateralPreview(10001, 1, 4)).toBe(2501);
    expect(collateralPreview(10001, 1, 1)).toBe(10001);
  });
  it('equity bar is clamped', () => {
    expect(equityPercent(626951, 1253902)).toBe(50);
    expect(equityPercent(-5, 100)).toBe(0);
    expect(equityPercent(150, 100)).toBe(100);
  });
});

describe('account nudges', () => {
  it('refetch M2a queries by reason', () => {
    expect(queriesFor(['MARGIN'])).toContain('margin');
    expect(queriesFor(['ORDER'])).not.toContain('savings');
  });
});

describe('rates', () => {
  it('formats basis points as percent without trailing zeros', () => {
    expect(bpsPercent(1000, 'en')).toBe('10');
    expect(bpsPercent(1450, 'en')).toBe('14.5');
    expect(bpsPercent(1405, 'ru')).toBe('14,05');
  });
});
