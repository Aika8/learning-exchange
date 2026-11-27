import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// LE-408: the glossary is reachable from the home screen, and the settings entry stays.
const read = (f) => readFileSync(new URL(`../src/app/${f}`, import.meta.url), 'utf8');
const buttonWith = (src, testID) => src.split(/<Button\b/).slice(1).map((b) => b.split('/>')[0]).find((b) => b.includes(`testID="${testID}"`));

test('home has a button that pushes /glossary', () => {
  const b = buttonWith(read('home.tsx'), 'open-glossary-home');
  assert.ok(b, 'home.tsx has no Button with testID="open-glossary-home"');
  assert.match(b, /router\.push\('\/glossary'\)/);
  assert.match(b, /t\('glossary\.title'\)/);
});

test('settings still opens the glossary', () => {
  const b = buttonWith(read('settings.tsx'), 'open-glossary');
  assert.ok(b, 'settings.tsx lost its glossary entry');
  assert.match(b, /router\.push\('\/glossary'\)/);
});
