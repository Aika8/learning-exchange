import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// ADR-0014: each language is really in its language — English has no Cyrillic letters,
// and a Russian value is not the English one left untranslated.
const load = (l) => JSON.parse(readFileSync(new URL(`../src/i18n/${l}.json`, import.meta.url)));
const flat = (o, p = '') =>
  Object.entries(o).flatMap(([k, v]) => (typeof v === 'object' ? flat(v, `${p}${k}.`) : [[`${p}${k}`, String(v)]]));

const CYRILLIC = /[Ѐ-ӿԀ-ԯ]/;

// Keys whose ru value may equal the en value: language names, tickers, abbreviations that are
// the same in both languages. Add a key here only when the term is not translated on purpose.
const SAME_IN_BOTH = new Set([
  'settings.en', // "English" — a language is named in its own language in the switch
  'stops.tpsl', // "TP + SL"
  'ckind.TP_SL', // "TP + SL"
  'size.k', // "k (× ATR)"
  'company.pe', // "P/E"
  'company.eps', // "EPS"
]);

test('no English value contains a Cyrillic letter', () => {
  const bad = flat(load('en')).filter(([, v]) => CYRILLIC.test(v));
  assert.deepEqual(bad, [], `en.json has Cyrillic in: ${bad.map(([k]) => k).join(', ')}`);
});

test('a Russian value equal to its English value is only allowed for the listed keys', () => {
  const en = Object.fromEntries(flat(load('en')));
  const same = flat(load('ru'))
    .filter(([k, v]) => en[k] === v && !SAME_IN_BOTH.has(k))
    .map(([k]) => k);
  assert.deepEqual(same, [], `ru.json left in English: ${same.join(', ')}`);
});

test('the allow-list has no stale keys', () => {
  const en = Object.fromEntries(flat(load('en')));
  const ru = Object.fromEntries(flat(load('ru')));
  const stale = [...SAME_IN_BOTH].filter((k) => !(k in ru) || ru[k] !== en[k]);
  assert.deepEqual(stale, [], `remove from SAME_IN_BOTH: ${stale.join(', ')}`);
});
