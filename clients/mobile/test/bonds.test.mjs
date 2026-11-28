import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canTrade, couponsPaidLeft, nextCoupon, selectedBond, statusTone } from '../src/bonds.ts';

const bond = (o) => ({ instrument: 'GBND-SPARK', status: 'ACTIVE', couponsPaid: 0, couponsLeft: 4, nextCouponAt: 1_000, ...o });

test('status badge: a default is red, redeemed is grey, a live bond is green', () => {
  assert.equal(statusTone('DEFAULTED'), 'negative');
  assert.equal(statusTone('REDEEMED'), 'textSecondary');
  assert.equal(statusTone('ACTIVE'), 'positive');
});

test('only a live bond can be traded', () => {
  assert.equal(canTrade('ACTIVE'), true);
  assert.equal(canTrade('DEFAULTED'), false);
  assert.equal(canTrade('REDEEMED'), false);
});

test('detail view: the bond of `?id=`, none for an empty or unknown id', () => {
  const list = [bond({}), bond({ instrument: 'CBND-AMBER' })];
  assert.equal(selectedBond(list, 'CBND-AMBER'), list[1]);
  assert.equal(selectedBond(list, ''), undefined);
  assert.equal(selectedBond(list, undefined), undefined);
  assert.equal(selectedBond(list, 'NOPE'), undefined);
  assert.equal(selectedBond([], 'GBND-SPARK'), undefined);
});

test('coupon schedule: paid / left as the server counts them, next coupon or none', () => {
  assert.equal(couponsPaidLeft(bond({ couponsPaid: 1, couponsLeft: 3 })), '1 / 3');
  assert.equal(couponsPaidLeft(bond({ couponsPaid: 4, couponsLeft: 0 })), '4 / 0');
  assert.equal(nextCoupon(bond({ nextCouponAt: 1_700_000_000_000 })), 1_700_000_000_000);
  assert.equal(nextCoupon(bond({ nextCouponAt: null })), null);
  assert.equal(nextCoupon({}), null);
});
