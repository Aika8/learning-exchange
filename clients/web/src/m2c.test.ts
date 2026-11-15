import { describe, expect, it } from 'vitest';
import { atrStopDistance, buildJournal, fundGapBps, parseTenths, rText, sizeByRisk } from './m2c';

describe('parseTenths', () => {
  it('parses k with one decimal', () => {
    expect(parseTenths('2')).toBe(20);
    expect(parseTenths('1.5')).toBe(15);
    expect(parseTenths('1,5')).toBe(15);
    expect(parseTenths('0')).toBeNull();
    expect(parseTenths('1.55')).toBeNull();
    expect(parseTenths('x')).toBeNull();
  });
});

describe('ATR position size', () => {
  it('stop distance = k × ATR, rounded up', () => {
    expect(atrStopDistance(250, 20)).toBe(500);
    expect(atrStopDistance(333, 15)).toBe(500); // 499.5 → 500
  });
  it('qty = floor(risk / stop distance)', () => {
    expect(sizeByRisk(10_000, 500)).toBe(20);
    expect(sizeByRisk(10_499, 500)).toBe(20);
    expect(sizeByRisk(499, 500)).toBe(0);
    expect(sizeByRisk(10_000, 0)).toBe(0);
  });
});

describe('rText', () => {
  it('formats R × 100', () => {
    expect(rText(-150, 'en')).toBe('−1.5 R');
    expect(rText(200, 'en')).toBe('+2 R');
    expect(rText(null, 'en')).toBe('—');
  });
});

describe('buildJournal', () => {
  it('is undefined when empty', () => {
    expect(buildJournal('  ', '', '', null)).toBeUndefined();
  });
  it('keeps filled fields and cuts why to 280', () => {
    const j = buildJournal('x'.repeat(300), 'RANGE', 'FOMO', 1000);
    expect(j).toEqual({ why: 'x'.repeat(280), marketState: 'RANGE', mood: 'FOMO', plannedRisk: 1000 });
  });
});

describe('fundGapBps', () => {
  it('subtracts', () => {
    expect(fundGapBps(480, 500)).toBe(-20);
    expect(fundGapBps(null, 500)).toBeNull();
  });
});
