import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  amountSign,
  amountTone,
  hasCosts,
  periodFrom,
  recentLines,
  rowPnlTone,
  scaleOf,
  spreadCaption,
  statementEnabled,
  statementQuery,
  titleKey,
  totalPnlTone,
} from '../src/statement.ts';

const line = (o) => ({ ts: 0, kind: 'TRADE', asset: 'SPARK', amount: 0, fee: 0, spreadPaid: 0, realisedPnl: 0, ...o });

test('period: «All» has no lower bound, «Today» starts at local midnight of the clock', () => {
  const now = new Date(2026, 10, 28, 15, 42, 7, 123).getTime();
  assert.equal(periodFrom('ALL', now), undefined);
  assert.equal(periodFrom('TODAY', now), new Date(2026, 10, 28).getTime());
  assert.equal(periodFrom('TODAY', new Date(now).toISOString()), new Date(2026, 10, 28).getTime());
  // the clock is not known yet → no start, and the «Today» query waits
  assert.equal(periodFrom('TODAY', undefined), undefined);
  assert.equal(statementEnabled('TODAY', undefined), false);
  assert.equal(statementEnabled('TODAY', 1), true);
  assert.equal(statementEnabled('ALL', undefined), true);
});

test('statement query sends `from` only when there is one', () => {
  assert.deepEqual(statementQuery(undefined), {});
  assert.deepEqual(statementQuery(0), { from: 0 });
  assert.deepEqual(statementQuery(1_700_000_000_000), { from: 1_700_000_000_000 });
});

test('recent lines: newest first, at most 40, input untouched; empty statement gives no rows', () => {
  assert.deepEqual(recentLines(undefined), []);
  assert.deepEqual(recentLines(null), []);
  assert.deepEqual(recentLines([]), []);
  const all = Array.from({ length: 45 }, (_, i) => line({ ts: i }));
  const shown = recentLines(all);
  assert.equal(shown.length, 40);
  assert.equal(shown[0].ts, 44);
  assert.equal(shown[39].ts, 5);
  assert.equal(all[0].ts, 0); // not reversed in place
  assert.deepEqual(recentLines([1, 2, 3], 2), [3, 2]);
});

test('scale of an asset: SPARK in hundredths, the others whole, unknown whole', () => {
  assert.equal(scaleOf('SPARK'), 2);
  assert.equal(scaleOf('SILK'), 0);
  assert.equal(scaleOf('AMBER'), 0);
  assert.equal(scaleOf('NOPE'), 0);
});

test('amount sign and colour of a row', () => {
  assert.equal(amountSign(1), '+');
  assert.equal(amountSign(0), '');
  assert.equal(amountSign(-1), ''); // the formatter writes the minus
  assert.equal(amountTone(line({ amount: 12_345 })), 'positive');
  assert.equal(amountTone(line({ amount: 0 })), 'positive');
  assert.equal(amountTone(line({ amount: -12_345 })), 'textPrimary');
  // withheld dividend tax is red whatever its sign
  assert.equal(amountTone(line({ kind: 'DIVIDEND_TAX', amount: -500 })), 'negative');
  assert.equal(amountTone(line({ kind: 'DIVIDEND_TAX', amount: 0 })), 'negative');
});

test('a line with only a fee shows the cost caption; spread paid vs earned', () => {
  assert.equal(hasCosts(line({})), false);
  assert.equal(hasCosts(line({ amount: -235, fee: 235 })), true);
  assert.equal(hasCosts(line({ spreadPaid: -100 })), true);
  assert.deepEqual(spreadCaption(1_000), { key: 'statement.spread', amount: 1_000 });
  assert.deepEqual(spreadCaption(0), { key: 'statement.spread', amount: 0 });
  assert.deepEqual(spreadCaption(-1_000), { key: 'statement.spreadEarned', amount: 1_000 });
});

test('realised profit: total colour (zero is positive), row colour hidden at zero', () => {
  assert.equal(totalPnlTone(0), 'positive');
  assert.equal(totalPnlTone(1), 'positive');
  assert.equal(totalPnlTone(-150_000), 'negative'); // a loss overall
  assert.equal(rowPnlTone(0), null);
  assert.equal(rowPnlTone(250), 'positive');
  assert.equal(rowPnlTone(-250), 'negative');
});

test('row title key', () => {
  assert.equal(titleKey({ kind: 'TRADE', side: 'BUY' }), 'statement.buy');
  assert.equal(titleKey({ kind: 'TRADE', side: 'SELL' }), 'statement.sell');
  assert.equal(titleKey({ kind: 'TRADE', side: null }), 'statement.sell');
  assert.equal(titleKey({ kind: 'DIVIDEND' }), 'skind.DIVIDEND');
});
