// Pure helpers for the currency exchange screen (src/app/fx.tsx): the best prices of the book and the words and
// colour of the chosen side. The quote itself (spread, mid, fee, cost of the spread, total) is fxQuote and
// spreadInfo in src/finance.ts, and parsing an amount is parseToMinor in src/money.ts; this file does not repeat them.
// Colours are returned as theme token names, not values, so the screen picks them from useColors().
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

export type Side = 'BUY' | 'SELL';

/** The part of a book snapshot read here (a subset of Schemas['BookSnapshot']). */
export type BookLike = { bids: { price: number }[]; asks: { price: number }[] };

/** Best bid (the rate the dealer buys at) and best ask (the rate it sells at); undefined for an empty side or no book. */
export function bestPrices(book: BookLike | null | undefined): { bid: number | undefined; ask: number | undefined } {
  return { bid: book?.bids[0]?.price, ask: book?.asks[0]?.price };
}

/** i18n keys and colour token of a side: a buy pays and is shown in the bid colour, a sell gets and is in the ask colour. */
export function sideWords(side: Side): { total: 'fx.totalPay' | 'fx.totalGet'; cta: 'fx.ctaBuy' | 'fx.ctaSell'; tone: 'bid' | 'ask' } {
  return side === 'BUY' ? { total: 'fx.totalPay', cta: 'fx.ctaBuy', tone: 'bid' } : { total: 'fx.totalGet', cta: 'fx.ctaSell', tone: 'ask' };
}

/** The available amount of `asset` among the balances, or undefined when it is not there (or not loaded yet). */
export function availableOf(balances: { asset: string; available: number }[] | null | undefined, asset: string): number | undefined {
  return balances?.find((b) => b.asset === asset)?.available;
}
