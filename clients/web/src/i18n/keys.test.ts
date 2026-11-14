import { describe, expect, it } from 'vitest';
import ru from './ru.json';
import en from './en.json';

// ADR-0014: every key exists in both locales, and no value is empty.
function keys(o: object, prefix = ''): string[] {
  return Object.entries(o).flatMap(([k, v]) =>
    typeof v === 'object' && v !== null ? keys(v, `${prefix}${k}.`) : [`${prefix}${k}`],
  );
}

describe('i18n catalogues', () => {
  it('ru and en have the same keys', () => {
    expect(keys(en).sort()).toEqual(keys(ru).sort());
  });

  it('no value is empty', () => {
    const values = (o: object): unknown[] =>
      Object.values(o).flatMap((v) => (typeof v === 'object' && v !== null ? values(v) : [v]));
    for (const v of [...values(ru), ...values(en)]) expect(String(v).trim()).not.toBe('');
  });
});
