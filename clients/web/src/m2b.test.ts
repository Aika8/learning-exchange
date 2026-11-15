import { describe, expect, it } from 'vitest';
import { bankDaysUntil, gapRisk, signedPercent, x100 } from './m2b';

describe('x100', () => {
  it('formats ×100 integers', () => {
    expect(x100(1250, 'en')).toBe('12.5');
    expect(x100(1205, 'en')).toBe('12.05');
    expect(x100(300, 'en')).toBe('3');
    expect(x100(1250, 'ru')).toBe('12,5');
    expect(x100(-50, 'en')).toBe('−0.5');
  });
});

describe('signedPercent', () => {
  it('adds a sign', () => {
    expect(signedPercent(1250, 'en')).toBe('+12.5');
    expect(signedPercent(-300, 'en')).toBe('−3');
    expect(signedPercent(0, 'en')).toBe('0');
  });
});

describe('gapRisk', () => {
  const live = [{ instrument: 'A', state: 'ARMED' as const }];
  it('warns for a live stop when the report is within one bank day', () => {
    expect(gapRisk('A', 1_060_000, 1_000_000, live)).toBe(true);
    expect(gapRisk('A', 1_030_000, 1_000_000, [{ instrument: 'A', state: 'WAITING' }])).toBe(true);
  });
  it('stays quiet otherwise', () => {
    expect(gapRisk('A', 1_060_001, 1_000_000, live)).toBe(false);
    expect(gapRisk('A', 900_000, 1_000_000, live)).toBe(false);
    expect(gapRisk('B', 1_030_000, 1_000_000, live)).toBe(false);
    expect(gapRisk('A', 1_030_000, 1_000_000, [{ instrument: 'A', state: 'FILLED' }])).toBe(false);
    expect(gapRisk('A', null, 1_000_000, live)).toBe(false);
  });
});

describe('bankDaysUntil', () => {
  it('rounds up', () => {
    expect(bankDaysUntil(60_001, 0)).toBe(2);
    expect(bankDaysUntil(60_000, 0)).toBe(1);
    expect(bankDaysUntil(0, 5)).toBe(0);
  });
});
