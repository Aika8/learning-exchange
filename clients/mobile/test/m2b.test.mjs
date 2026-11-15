import { test } from 'node:test';
import assert from 'node:assert/strict';
import { bankDaysUntil, formatX100, newIdempotencyKey, scaleCandles, showGapWarning, signedPercent } from '../src/m2b.ts';

test('gap warning: only with my stops and before the report', () => {
  assert.equal(showGapWarning(null, 1000), false);
  assert.equal(showGapWarning({ reportAt: 2000, conditionalIds: [] }, 1000), false);
  assert.equal(showGapWarning({ reportAt: 2000, conditionalIds: [7] }, 1000), true);
  assert.equal(showGapWarning({ reportAt: 2000, conditionalIds: [7] }, 2000), true);
  assert.equal(showGapWarning({ reportAt: 2000, conditionalIds: [7] }, 2001), false);
});

test('ratios × 100 and signed percents without floats', () => {
  assert.equal(formatX100(1250), '12.5'); // P/E 12.5
  assert.equal(formatX100(1205, ','), '12,05');
  assert.equal(formatX100(300), '3');
  assert.equal(formatX100(-305), '−3.05');
  assert.equal(signedPercent(450), '+4.5%');
  assert.equal(signedPercent(-1200), '−12%');
  assert.equal(signedPercent(0), '0%');
});

test('candles scale into the box: highest high at the top, lowest low at the bottom', () => {
  const day = 60_000;
  const candles = [
    { start: 0, open: 100, high: 120, low: 90, close: 110 },
    { start: day, open: 110, high: 130, low: 100, close: 105 },
  ];
  const { bars, min, max, xOf } = scaleCandles(candles, 200, 40);
  assert.equal(min, 90);
  assert.equal(max, 130);
  assert.deepEqual(bars[0], { x: 0, width: 100, top: 10, bottom: 40, bodyTop: 20, bodyBottom: 30, up: true });
  assert.equal(bars[1].top, 0);
  assert.equal(bars[1].up, false);
  // ex-date inside the second day → centre of its slot; outside the range → null
  assert.equal(xOf(day + 5), 150);
  assert.equal(xOf(2 * day), null);
  assert.equal(xOf(-1), null);
  // flat prices do not divide by zero
  assert.equal(scaleCandles([{ start: 0, open: 5, high: 5, low: 5, close: 5 }], 10, 10).bars[0].top, 0);
  assert.deepEqual(scaleCandles([], 10, 10).bars, []);
});

test('bank days until an event', () => {
  assert.equal(bankDaysUntil(120_000, 0), 2);
  assert.equal(bankDaysUntil(60_001, 0), 2);
  assert.equal(bankDaysUntil(10, 20), 0);
});

test('idempotency keys are short and differ', () => {
  const a = newIdempotencyKey();
  assert.ok(a.length <= 64);
  assert.notEqual(a, newIdempotencyKey());
});
