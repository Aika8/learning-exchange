import { test } from 'node:test';
import assert from 'node:assert/strict';
import { availableOf, bestPrices, sideWords } from '../src/fx.ts';
import { fxQuote, spreadInfo } from '../src/finance.ts';
import { parseToMinor } from '../src/money.ts';

test('best prices: top of each side of the book', () => {
  const book = { bids: [{ price: 9_950 }, { price: 9_900 }], asks: [{ price: 10_050 }, { price: 10_100 }] };
  assert.deepEqual(bestPrices(book), { bid: 9_950, ask: 10_050 });
});

test('best prices: an empty side or no book gives undefined, and then no quote', () => {
  assert.deepEqual(bestPrices({ bids: [], asks: [{ price: 10_050 }] }), { bid: undefined, ask: 10_050 });
  assert.deepEqual(bestPrices({ bids: [{ price: 9_950 }], asks: [] }), { bid: 9_950, ask: undefined });
  assert.deepEqual(bestPrices(undefined), { bid: undefined, ask: undefined });
  assert.deepEqual(bestPrices(null), { bid: undefined, ask: undefined });
});

test('side words and colour token', () => {
  assert.deepEqual(sideWords('BUY'), { total: 'fx.totalPay', cta: 'fx.ctaBuy', tone: 'bid' });
  assert.deepEqual(sideWords('SELL'), { total: 'fx.totalGet', cta: 'fx.ctaSell', tone: 'ask' });
});

test('available balance of an asset', () => {
  const balances = [{ asset: 'SPARK', available: 123_456 }, { asset: 'AMBER', available: 0 }];
  assert.equal(availableOf(balances, 'SPARK'), 123_456);
  assert.equal(availableOf(balances, 'AMBER'), 0);
  assert.equal(availableOf(balances, 'SILK'), undefined);
  assert.equal(availableOf(undefined, 'SPARK'), undefined);
});

test('the screen path: book → amount → quote, all in minor units', () => {
  // AMBER/SPARK, price scale 2: bid 99.50, ask 100.50; 10 AMBER (qty scale 0); fee 10 bps.
  const { bid, ask } = bestPrices({ bids: [{ price: 9_950 }], asks: [{ price: 10_050 }] });
  assert.deepEqual(spreadInfo(bid, ask), { spread: 100, mid: 10_000, spreadBps: 100 });
  const qty = parseToMinor('10', 0);
  const buy = fxQuote('BUY', qty, bid, ask, 10);
  // 10 × 100.50 = 1 005.00; fee floor(100 500 × 10 / 10 000) = 100 (1.00); half the spread × 10 = 5.00
  assert.deepEqual(buy, { price: 10_050, notional: 100_500, fee: 100, spreadCost: 500, total: 100_600 });
  const sell = fxQuote('SELL', qty, bid, ask, 10);
  assert.deepEqual(sell, { price: 9_950, notional: 99_500, fee: 99, spreadCost: 500, total: 99_401 });
  // a bad or fractional amount for a whole-unit asset gives no quantity, so the screen shows no quote
  assert.equal(parseToMinor('1,5', 0), null);
  assert.equal(parseToMinor('', 0), null);
});
