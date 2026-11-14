import { describe, expect, it } from 'vitest';
import { formatMinor, parseToMinor } from './money';

describe('money', () => {
  it('formats minor units without floating point', () => {
    expect(formatMinor(1234567, 2, 'en')).toBe('12,345.67');
    expect(formatMinor(5, 2, 'en')).toBe('0.05');
    expect(formatMinor(-10050, 2, 'en')).toBe('−100.50');
    expect(formatMinor(1000, 0, 'en')).toBe('1,000');
  });

  it('parses decimals into exact minor units', () => {
    expect(parseToMinor('100.5', 2)).toBe(10050);
    expect(parseToMinor('100,05', 2)).toBe(10005);
    expect(parseToMinor('0.1', 2)).toBe(10);
    expect(parseToMinor('7', 0)).toBe(7);
    expect(parseToMinor('1.234', 2)).toBeNull();
    expect(parseToMinor('-1', 2)).toBeNull();
    expect(parseToMinor('abc', 2)).toBeNull();
    expect(parseToMinor('0', 2)).toBeNull();
  });
});
