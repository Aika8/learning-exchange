import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// money.ts is the same file as the web client's; keep them identical until a shared package exists.
test('money.ts matches the web client', () => {
  const read = (p) => readFileSync(new URL(p, import.meta.url), 'utf8');
  assert.equal(read('../src/money.ts'), read('../../web/src/money.ts'));
});
