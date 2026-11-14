import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// ADR-0014: every key exists in ru and en, and no value is empty.
const load = (l) => JSON.parse(readFileSync(new URL(`../src/i18n/${l}.json`, import.meta.url)));
const keys = (o, p = '') => Object.entries(o).flatMap(([k, v]) => (typeof v === 'object' ? keys(v, `${p}${k}.`) : [`${p}${k}`]));

test('ru and en have the same keys', () => {
  assert.deepEqual(keys(load('en')).sort(), keys(load('ru')).sort());
});

test('no empty translations', () => {
  for (const l of ['ru', 'en']) {
    const flat = (o) => Object.values(o).flatMap((v) => (typeof v === 'object' ? flat(v) : [v]));
    for (const v of flat(load(l))) assert.notEqual(String(v).trim(), '', `${l} has an empty value`);
  }
});

test('every t("…") key used in the code exists', async () => {
  const { readdirSync, statSync } = await import('node:fs');
  const { join } = await import('node:path');
  const root = new URL('../src', import.meta.url).pathname;
  const files = [];
  const walk = (d) => readdirSync(d).forEach((f) => (statSync(join(d, f)).isDirectory() ? walk(join(d, f)) : f.endsWith('.tsx') && files.push(join(d, f))));
  walk(decodeURIComponent(root));
  const known = new Set(keys(load('ru')));
  for (const f of files) {
    for (const m of readFileSync(f, 'utf8').matchAll(/\bt\('([a-zA-Z0-9_.]+)'/g)) {
      assert.ok(known.has(m[1]), `${f}: missing key ${m[1]}`);
    }
  }
});
