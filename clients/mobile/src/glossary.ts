// Pure logic of the glossary screen (S10 «Словарь»): search and order of real finance terms.
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.
// Intent 02: the app knows nothing of the game, so lore names are never searched or shown here.

export type Localised = { ru: string; en: string };
export type Term = { id: string; real: Localised; definition: Localised; lore?: Localised | null };
export type Lang = 'ru' | 'en';
export type Row = { id: string; name: string; definition: string };

/** The app's language code («ru-RU», «en», …) to a glossary language; anything not English reads Russian. */
export function langOf(code: string | undefined): Lang {
  return code != null && code.toLowerCase().startsWith('en') ? 'en' : 'ru';
}

/** Lower-case, «ё» as «е», runs of spaces as one, trimmed — so «  СТОП  » finds «Стоп-лосс». */
export function normalise(s: string): string {
  return s.toLowerCase().replace(/ё/g, 'е').replace(/\s+/g, ' ').trim();
}

/**
 * Terms for the screen in `lang`. An empty query shows every term. Otherwise a term matches when the query is part
 * of its real name in either language or of its definition in `lang`; terms matched by name come first (real name
 * first), then those matched only by the definition. Inside each group: by real name in `lang`, then by id.
 */
export function glossaryRows(terms: readonly Term[], query: string, lang: Lang): Row[] {
  const q = normalise(query);
  const byName = (t: Term) => normalise(t.real.ru).includes(q) || normalise(t.real.en).includes(q);
  const rank = (t: Term) => (q === '' || byName(t) ? 0 : normalise(t.definition[lang]).includes(q) ? 1 : -1);
  const collator = new Intl.Collator(lang, { sensitivity: 'base' });
  return terms
    .map((t) => ({ t, r: rank(t) }))
    .filter((x) => x.r >= 0)
    .sort((a, b) => a.r - b.r || collator.compare(a.t.real[lang], b.t.real[lang]) || (a.t.id < b.t.id ? -1 : a.t.id > b.t.id ? 1 : 0))
    .map(({ t }) => ({ id: t.id, name: t.real[lang], definition: t.definition[lang] }));
}
