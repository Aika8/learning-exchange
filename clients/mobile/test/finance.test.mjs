import { test } from 'node:test';
import assert from 'node:assert/strict';
import { bpsToPercent, fxQuote, positionSize, ruleOf72Tenths, spreadInfo } from '../src/finance.ts';

test('position size: floor(capital × risk / |entry − stop|) in minor units', () => {
  // 10 000.00 SPARK, 1% risk = 100.00; entry 105.00, stop 100.00 → 5.00 per unit → 20 units.
  assert.deepEqual(positionSize(1_000_000, 100, 10_500, 10_000), { qty: 20, riskBudget: 10_000, atRisk: 10_000 });
  // works for a short (stop above entry) and rounds down
  assert.deepEqual(positionSize(1_000_000, 100, 10_000, 10_300), { qty: 33, riskBudget: 10_000, atRisk: 9_900 });
  assert.equal(positionSize(1_000_000, 100, 10_000, 10_000), null);
  assert.equal(positionSize(0, 100, 10_500, 10_000), null);
  assert.equal(positionSize(1_000, 100, 10_500, 10_000).qty, 0);
});

test('rule of 72 in tenths of a year', () => {
  assert.equal(ruleOf72Tenths(1400), 51); // 14% → ≈ 5.1 years
  assert.equal(ruleOf72Tenths(800), 90);
  assert.equal(ruleOf72Tenths(0), null);
});

test('spread, mid and spread in bps', () => {
  assert.deepEqual(spreadInfo(46_900, 47_100), { spread: 200, mid: 47_000, spreadBps: 43 });
  assert.equal(spreadInfo(10, 9), null);
});

test('fx quote: fee and spread cost against the mid', () => {
  assert.deepEqual(fxQuote('BUY', 10, 46_900, 47_100, 5), { price: 47_100, notional: 471_000, fee: 235, spreadCost: 1_000, total: 471_235 });
  assert.deepEqual(fxQuote('SELL', 10, 46_900, 47_100, 5), { price: 46_900, notional: 469_000, fee: 234, spreadCost: 1_000, total: 468_766 });
});

test('bps to percent', () => {
  assert.equal(bpsToPercent(1400), '14');
  assert.equal(bpsToPercent(5), '0.05');
  assert.equal(bpsToPercent(43, ','), '0,43');
});

test('ATR position size: stop = k × ATR, qty = floor(budget / distance)', async () => {
  const { atrPositionSize, stopFromDistance, formatR } = await import('../src/finance.ts');
  // 10 000.00 capital, 1% = 100.00 budget; ATR 3.20, k = 2 → distance 6.40 → 15 units, 96.00 at risk.
  assert.deepEqual(atrPositionSize(1_000_000, 100, 320, 200), { distance: 640, qty: 15, riskBudget: 10_000, atRisk: 9_600 });
  // k = 1.5 → 4.80 per unit; distance rounds down to a minor unit (ATR 333 × 1.5 = 499.5 → 499).
  assert.equal(atrPositionSize(1_000_000, 100, 320, 150).distance, 480);
  assert.equal(atrPositionSize(1_000_000, 100, 333, 150).distance, 499);
  // not enough data / nothing to risk
  assert.equal(atrPositionSize(1_000_000, 100, null, 200), null);
  assert.equal(atrPositionSize(1_000_000, 100, 0, 200), null);
  assert.equal(atrPositionSize(1_000_000, 0, 320, 200), null);
  assert.equal(atrPositionSize(1_000_000, 100, 1, 50), null);
  // results stay integers
  const r = atrPositionSize(777_777, 137, 291, 175);
  for (const v of Object.values(r)) assert.ok(Number.isInteger(v));
  assert.equal(stopFromDistance(10_000, 640, 'BUY'), 9_360);
  assert.equal(stopFromDistance(10_000, 640, 'SELL'), 10_640);
  assert.equal(stopFromDistance(500, 640, 'BUY'), null);
  assert.equal(formatR(-140), '−1.4 R');
  assert.equal(formatR(250, ','), '+2,5 R');
  assert.equal(formatR(0), '0 R');
});
