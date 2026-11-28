import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  basketGap,
  gapTone,
  premiumCaptionKey,
  premiumTone,
  sortedHoldings,
  vsBasketCaptionKey,
  weightBarPercent,
} from '../src/funds.ts';

test('premium: above NAV warns, below informs, none or zero is plain', () => {
  assert.equal(premiumTone(150), 'warning');
  assert.equal(premiumTone(-80), 'info');
  assert.equal(premiumTone(0), 'textPrimary');
  assert.equal(premiumTone(null), 'textPrimary');
  assert.equal(premiumTone(undefined), 'textPrimary');
  assert.equal(premiumCaptionKey(150), 'funds.premiumAbove');
  assert.equal(premiumCaptionKey(-80), 'funds.premiumBelow');
  assert.equal(premiumCaptionKey(0), 'funds.premiumZero');
  assert.equal(premiumCaptionKey(null), 'funds.premiumNone');
});

test('holdings: heaviest first, input untouched; bar width clamped to 0..100', () => {
  const h = [{ i: 'A', weightBps: 2_000 }, { i: 'B', weightBps: 5_000 }, { i: 'C', weightBps: 3_000 }];
  assert.deepEqual(sortedHoldings(h).map((x) => x.i), ['B', 'C', 'A']);
  assert.deepEqual(h.map((x) => x.i), ['A', 'B', 'C']);
  assert.deepEqual(sortedHoldings([]), []);
  assert.equal(weightBarPercent(5_000), 50);
  assert.equal(weightBarPercent(12_345), 100);
  assert.equal(weightBarPercent(-10), 0);
});

test('fund vs its basket: index fund behind by its fees, active fund ahead, unknown until both returns exist', () => {
  // an index fund trails its basket by the costs (TER, cash drag)
  assert.equal(basketGap(780, 800), -20);
  assert.equal(gapTone(-20), 'negative');
  // an active fund that beat what it holds
  assert.equal(basketGap(1_200, 900), 300);
  assert.equal(gapTone(300), 'positive');
  assert.equal(gapTone(0), 'positive');
  assert.equal(basketGap(null, 800), null);
  assert.equal(basketGap(780, undefined), null);
  assert.equal(gapTone(null), undefined);
  assert.equal(vsBasketCaptionKey(null), 'funds.vsBasketLater');
  assert.equal(vsBasketCaptionKey(-20), 'funds.vsBasketHint');
});
