import { test } from 'node:test';
import assert from 'node:assert/strict';
import { drifts, lumpVsDca, lumpVsDcaWindow, rebalanceDue } from '../src/m4.ts';

test('rebalancing is due twice a year (182 bank days) and on first use', () => {
  const day = 60_000;
  assert.equal(rebalanceDue(null, 0, day), true);
  assert.equal(rebalanceDue(0, 181 * day, day), false);
  assert.equal(rebalanceDue(0, 182 * day, day), true);
});

test('only shares that drifted more than 5 p.p. are reported, largest first', () => {
  // 60/40 target; actual 66/34 → +6 / −6 p.p.
  const d = drifts({ STOCKS: 66_000, BONDS: 34_000 }, { STOCKS: 6_000, BONDS: 4_000 });
  assert.deepEqual(d.map((x) => [x.key, x.driftBps]), [['STOCKS', 600], ['BONDS', -600]]);
  // exactly 5 p.p. is not more than 5 p.p.
  assert.deepEqual(drifts({ A: 65, B: 35 }, { A: 6_000, B: 4_000 }), []);
  assert.deepEqual(drifts({}, { A: 10_000 }), []);
});

test('lump sum and DCA: a rising series favours the lump sum, a falling one DCA', () => {
  assert.deepEqual(lumpVsDcaWindow([100, 200, 400], 0, 1_000, 2), { lump: 4_000, dca: 3_000 });
  const up = lumpVsDca([100, 110, 120, 130, 140, 150], 10_000, 3);
  assert.equal(up.windows, 3);
  assert.equal(up.lumpWins, 3);
  assert.ok(up.avgEdgeBps > 0);
  const down = lumpVsDca([150, 140, 130, 120, 110, 100], 10_000, 3);
  assert.equal(down.lumpWins, 0);
  assert.ok(down.worstLumpBps < down.worstDcaBps);
  assert.equal(lumpVsDca([100, 101], 10_000, 3), null);
  assert.equal(lumpVsDca([100, 0, 101, 102], 10_000, 2), null);
});
