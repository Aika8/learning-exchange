import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// The app's theme is a copy of the design tokens; this keeps them from drifting.
test('theme tokens equal docs/design/tokens.json', () => {
  const read = (p) => JSON.parse(readFileSync(new URL(p, import.meta.url)));
  assert.deepEqual(read('../src/theme/tokens.json'), read('../../../docs/design/tokens.json'));
});
