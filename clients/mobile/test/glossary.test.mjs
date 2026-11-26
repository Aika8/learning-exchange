import { test } from 'node:test';
import assert from 'node:assert/strict';
import { glossaryRows, langOf, normalise } from '../src/glossary.ts';

const term = (id, ru, en, dru, den, lore = null) => ({ id, real: { ru, en }, definition: { ru: dru, en: den }, lore });
const TERMS = [
  term('stop', 'Стоп-лосс', 'Stop-loss', 'Заявка, которая закроет позицию при заданной цене.', 'An order that closes a position at a set price.'),
  term('spread', 'Спред', 'Spread', 'Разница между ценой покупки и продажи.', 'The gap between the buy and the sell price.'),
  term('book', 'Стакан', 'Order book', 'Список заявок на покупку и продажу по ценам.', 'The list of buy and sell orders by price.', { ru: 'Пропасть', en: 'the Chasm' }),
  term('gap', 'Гэп', 'Gap', 'Скачок цены между закрытием и открытием.', 'A price jump between the close and the open.'),
  term('limit', 'Лимитная заявка', 'Limit order', 'Сделка только по вашей цене или лучше.', 'A trade only at your price or better.'),
];
const ids = (rows) => rows.map((r) => r.id);

test('an empty query shows every term, sorted by its real name in the current language', () => {
  assert.deepEqual(ids(glossaryRows(TERMS, '', 'ru')), ['gap', 'limit', 'spread', 'book', 'stop']);
  assert.deepEqual(ids(glossaryRows(TERMS, '   ', 'en')), ['gap', 'limit', 'book', 'spread', 'stop']);
});

test('rows carry the real name and the definition in the current language', () => {
  assert.deepEqual(glossaryRows(TERMS, 'гэп', 'ru')[0], { id: 'gap', name: 'Гэп', definition: 'Скачок цены между закрытием и открытием.' });
  assert.deepEqual(glossaryRows(TERMS, 'gap', 'en')[0], { id: 'gap', name: 'Gap', definition: 'A price jump between the close and the open.' });
});

test('search is case-insensitive and finds a real name in Russian or English whatever the language', () => {
  assert.deepEqual(ids(glossaryRows(TERMS, 'СТОП', 'ru')), ['stop']);
  assert.deepEqual(ids(glossaryRows(TERMS, 'stop-LOSS', 'ru')), ['stop']);
  assert.deepEqual(ids(glossaryRows(TERMS, 'спред', 'en')), ['spread']);
  assert.deepEqual(ids(glossaryRows(TERMS, 'Order Book', 'en')), ['book']);
  assert.deepEqual(ids(glossaryRows(TERMS, 'нет такого', 'ru')), []);
});

test('a term found by its real name comes before one found only by its definition', () => {
  // «заяв»: the name «Лимитная заявка» first, then «Стоп-лосс» and «Стакан» whose definitions mention it
  assert.deepEqual(ids(glossaryRows(TERMS, 'заяв', 'ru')), ['limit', 'book', 'stop']);
  // «order»: names «Order book», «Limit order» first (by name), then «Stop-loss» by its definition
  assert.deepEqual(ids(glossaryRows(TERMS, 'order', 'en')), ['limit', 'book', 'stop']);
});

test('lore names are neither searched nor shown', () => {
  assert.deepEqual(ids(glossaryRows(TERMS, 'пропасть', 'ru')), []);
  assert.deepEqual(ids(glossaryRows(TERMS, 'chasm', 'en')), []);
  for (const r of glossaryRows(TERMS, '', 'en')) assert.ok(!JSON.stringify(r).includes('Chasm'));
});

test('ties on the name keep a stable order by id; «ё» reads as «е»', () => {
  const twins = [term('b', 'Счёт', 'Account', 'x', 'x'), term('a', 'Счёт', 'Account', 'y', 'y')];
  assert.deepEqual(ids(glossaryRows(twins, '', 'ru')), ['a', 'b']);
  assert.deepEqual(ids(glossaryRows(twins, 'счет', 'ru')), ['a', 'b']);
  assert.equal(normalise('  Ёлка   ЁЖ '), 'елка еж');
});

test('the app language maps to a glossary language', () => {
  assert.equal(langOf('en-US'), 'en');
  assert.equal(langOf('ru'), 'ru');
  assert.equal(langOf('kk'), 'ru');
  assert.equal(langOf(undefined), 'ru');
});
