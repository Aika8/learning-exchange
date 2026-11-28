import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CLOSED_SHOWN, bankDayLength, interestToDate, splitDeposits, tenthsText } from '../src/deposits.ts';
import { ruleOf72Tenths } from '../src/finance.ts';

const dep = (id, status, principal = 10_000, balance = principal, interest) => ({ depositId: id, status, principal, balance, ...(interest === undefined ? {} : { interest }) });

test('split: open ones all, closed ones only the first five, order kept', () => {
  const list = [dep(1, 'OPEN'), ...[2, 3, 4, 5, 6, 7, 8].map((i) => dep(i, 'CLOSED')), dep(9, 'OPEN')];
  const { open, closed } = splitDeposits(list);
  assert.deepEqual(open.map((d) => d.depositId), [1, 9]);
  assert.deepEqual(closed.map((d) => d.depositId), [2, 3, 4, 5, 6]);
  assert.equal(CLOSED_SHOWN, 5);
  assert.equal(splitDeposits(list, 0).closed.length, 0);
});

test('split: no deposits or not loaded yet → two empty lists', () => {
  assert.deepEqual(splitDeposits(undefined), { open: [], closed: [] });
  assert.deepEqual(splitDeposits(null), { open: [], closed: [] });
  assert.deepEqual(splitDeposits([]), { open: [], closed: [] });
});

test('interest to date: the server value wins, else balance − principal, in minor units', () => {
  // 1 000.00 SPARK grew to 1 003.84
  assert.equal(interestToDate(dep(1, 'OPEN', 100_000, 100_384)), 384);
  // the server's own figure is used even when it differs from the difference
  assert.equal(interestToDate(dep(1, 'OPEN', 100_000, 100_384, 383)), 383);
  // zero interest sent explicitly is not replaced by the difference
  assert.equal(interestToDate(dep(1, 'OPEN', 100_000, 100_384, 0)), 0);
  // just opened: nothing earned yet
  assert.equal(interestToDate(dep(1, 'OPEN', 100_000, 100_000)), 0);
  // a null interest falls back too
  assert.equal(interestToDate({ status: 'OPEN', principal: 500, balance: 512, interest: null }), 12);
});

test('rule-of-72 years as text, with the locale decimal separator', () => {
  assert.equal(tenthsText(ruleOf72Tenths(1400)), '5.1');
  assert.equal(tenthsText(ruleOf72Tenths(1400), ','), '5,1');
  assert.equal(tenthsText(90), '9.0');
  assert.equal(tenthsText(7), '0.7');
  assert.equal(tenthsText(720, ','), '72,0');
  assert.equal(tenthsText(ruleOf72Tenths(0)), '—');
  assert.equal(tenthsText(undefined), '—');
});

test('bank day length in the largest whole unit', () => {
  assert.deepEqual(bankDayLength(60_000), { unit: 'minutes', count: 1 });
  assert.deepEqual(bankDayLength(3_600_000), { unit: 'hours', count: 1 });
  assert.deepEqual(bankDayLength(7_200_000), { unit: 'hours', count: 2 });
  // 90 minutes is not a whole number of hours
  assert.deepEqual(bankDayLength(5_400_000), { unit: 'minutes', count: 90 });
  // 90 seconds is not a whole number of minutes
  assert.deepEqual(bankDayLength(90_000), { unit: 'seconds', count: 90 });
  assert.deepEqual(bankDayLength(30_000), { unit: 'seconds', count: 30 });
  // milliseconds below a second are dropped
  assert.deepEqual(bankDayLength(60_999), { unit: 'minutes', count: 1 });
  assert.deepEqual(bankDayLength(0), { unit: 'seconds', count: 0 });
});
