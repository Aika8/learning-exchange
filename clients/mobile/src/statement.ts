// Pure helpers for the statement screen (src/app/statement.tsx): which period to ask for, which lines to show,
// and the sign / colour / caption choices of a row. Integers only (minor units); colours are returned as
// theme token names, not values, so the screen picks them from useColors().
// Kept free of imports and non-erasable TS so `node --test` can load this file directly.

export type Period = 'ALL' | 'TODAY';

/** Decimal places of each asset's minor unit; unknown assets show as whole units. */
export const SCALE: Record<string, number> = { SPARK: 2, SILK: 0, AMBER: 0 };

export function scaleOf(asset: string): number {
  return SCALE[asset] ?? 0;
}

/** The fields of a statement line these helpers read (a subset of Schemas['StatementLine']). */
export type LineLike = {
  ts: number;
  kind: string;
  amount: number;
  fee: number;
  spreadPaid: number;
  realisedPnl: number;
  price?: number | null;
  qty?: number | null;
  mid?: number | null;
};

/** Colour token of a value; the screen maps it to c.positive / c.negative / c.textPrimary. */
export type Tone = 'positive' | 'negative' | 'textPrimary';

/**
 * Start of the period in epoch ms: «Today» = since midnight of the simulation clock's day (device time zone);
 * «All» = no lower bound. Undefined also while the clock is not known yet.
 */
export function periodFrom(period: Period, now: number | string | undefined | null): number | undefined {
  if (period !== 'TODAY' || !now) return undefined;
  return new Date(new Date(now).setHours(0, 0, 0, 0)).getTime();
}

/** The query is sent for «All» at once, for «Today» only once its start is known. */
export function statementEnabled(period: Period, from: number | undefined): boolean {
  return period === 'ALL' || from !== undefined;
}

/** Query parameters of GET /statement. */
export function statementQuery(from: number | undefined): { from?: number } {
  return from !== undefined ? { from } : {};
}

/** Newest first, at most `limit` lines; the input is left untouched. */
export function recentLines<T>(lines: readonly T[] | undefined | null, limit = 40): T[] {
  return (lines ?? []).slice().reverse().slice(0, limit);
}

/** Realised profit total: zero counts as positive. */
export function totalPnlTone(realisedPnl: number): Tone {
  return realisedPnl >= 0 ? 'positive' : 'negative';
}

/** Amount of a row: withheld dividend tax is always negative; otherwise money in is positive, money out is plain. */
export function amountTone(l: Pick<LineLike, 'kind' | 'amount'>): Tone {
  if (l.kind === 'DIVIDEND_TAX') return 'negative';
  return l.amount >= 0 ? 'positive' : 'textPrimary';
}

/** «+» before a strictly positive amount; a negative one carries its own minus from the formatter. */
export function amountSign(amount: number): string {
  return amount > 0 ? '+' : '';
}

/** A row shows the fee / spread caption only when either is non-zero. */
export function hasCosts(l: Pick<LineLike, 'fee' | 'spreadPaid'>): boolean {
  return l.fee !== 0 || l.spreadPaid !== 0;
}

/** A negative spreadPaid is spread earned (the price was better than the mid); shown as its absolute value. */
export function spreadCaption(spreadPaid: number): { key: 'statement.spread' | 'statement.spreadEarned'; amount: number } {
  return { key: spreadPaid < 0 ? 'statement.spreadEarned' : 'statement.spread', amount: Math.abs(spreadPaid) };
}

/** Realised profit of a row: hidden when zero, else its colour. */
export function rowPnlTone(realisedPnl: number): Tone | null {
  if (realisedPnl === 0) return null;
  return realisedPnl > 0 ? 'positive' : 'negative';
}

/** Translation key of a row's title: buy / sell for trades, the kind otherwise. */
export function titleKey(l: { kind: string; side?: string | null }): string {
  if (l.kind === 'TRADE') return l.side === 'BUY' ? 'statement.buy' : 'statement.sell';
  return `skind.${l.kind}`;
}
