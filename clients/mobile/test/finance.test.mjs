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
