import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// ADR-0014: ru and en carry the same {{placeholders}} for every key, and i18next plural families are complete
// (ru: one/few/many/other, en: one/other) wherever a key uses any plural suffix.
const load = (l) => JSON.parse(readFileSync(new URL(`../src/i18n/${l}.json`, import.meta.url)));
const flatten = (o, p = '') =>
  Object.entries(o).flatMap(([k, v]) => (v && typeof v === 'object' ? flatten(v, `${p}${k}.`) : [[`${p}${k}`, String(v)]]));

// `{{name}}` and `{{name, format}}` both name the variable `name`.
const placeholders = (s) => [...new Set([...s.matchAll(/\{\{\s*([^},\s]+)[^}]*\}\}/g)].map((m) => m[1]))].sort();

const SUFFIXES = ['zero', 'one', 'two', 'few', 'many', 'other'];
const REQUIRED = { ru: ['one', 'few', 'many', 'other'], en: ['one', 'other'] };
const pluralBase = (key) => {
  const m = key.match(/^(.*)_([a-z]+)$/);
  return m && SUFFIXES.includes(m[2]) ? m[1] : null;
};

const ru = new Map(flatten(load('ru')));
const en = new Map(flatten(load('en')));

test('placeholder sets match between ru and en for every shared key', () => {
  const bad = [];
  for (const [key, ruValue] of ru) {
    if (!en.has(key)) continue;
    const a = placeholders(ruValue);
    const b = placeholders(en.get(key));
    if (a.join() !== b.join()) bad.push(`${key}: ru {${a}} vs en {${b}}`);
  }
  assert.deepEqual(bad, []);
});

test('ru-only plural forms carry the same placeholders as the ru _other form', () => {
  const bad = [];
  for (const [key, value] of ru) {
    const base = pluralBase(key);
    if (!base || en.has(key) || !ru.has(`${base}_other`)) continue;
    const a = placeholders(value);
    const b = placeholders(ru.get(`${base}_other`));
    if (a.join() !== b.join()) bad.push(`${key}: {${a}} vs ${base}_other {${b}}`);
  }
  assert.deepEqual(bad, []);
});

test('plural families are complete in both languages', () => {
  const bases = new Set([...ru.keys(), ...en.keys()].map(pluralBase).filter(Boolean));
  const missing = [];
  for (const base of bases) {
    for (const [lang, map] of [['ru', ru], ['en', en]]) {
      for (const form of REQUIRED[lang]) {
        if (!map.has(`${base}_${form}`)) missing.push(`${lang}: ${base}_${form}`);
      }
    }
  }
  assert.deepEqual(missing, []);
});

test('the placeholder parser reads plain and formatted placeholders', () => {
  assert.deepEqual(placeholders('в заявках {{amount}}'), ['amount']);
  assert.deepEqual(placeholders('{{ n }} of {{total, number}} and {{n}}'), ['n', 'total']);
  assert.deepEqual(placeholders('no placeholders'), []);
  assert.equal(pluralBase('home.pcs_few'), 'home.pcs');
  assert.equal(pluralBase('home.pcs'), null);
  assert.equal(pluralBase('home.my_plan'), null);
});
