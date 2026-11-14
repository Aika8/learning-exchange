import { useTranslation } from 'react-i18next';
import type { BookSnapshot, Instrument } from '../api/client';
import { formatMinor } from '../money';

/** Ladder view: asks on top (highest first), spread in the middle, bids below; bars show relative depth. */
export function Ladder({ book, instrument }: { book: BookSnapshot | null; instrument: Instrument }) {
  const { t, i18n } = useTranslation();
  const fmt = (p: number) => formatMinor(p, instrument.priceScale, i18n.language);
  if (!book) return <h2>{t('book.title')}</h2>;
  const asks = book.asks.slice(0, 10).reverse();
  const bids = book.bids.slice(0, 10);
  const max = Math.max(1, ...asks.map((l) => l.qty), ...bids.map((l) => l.qty));
  const bestBid = book.bids[0]?.price;
  const bestAsk = book.asks[0]?.price;
  const spread = bestBid !== undefined && bestAsk !== undefined ? bestAsk - bestBid : null;

  return (
    <>
      <h2>
        {t('book.title')} · {instrument.base}/{instrument.quote}
      </h2>
      <table className="ladder" data-testid="ladder">
        <thead>
          <tr>
            <th>{t('book.price')}</th>
            <th>{t('book.qty')}</th>
            <th>{t('book.orders')}</th>
          </tr>
        </thead>
        <tbody>
          {asks.map((l) => (
            <tr key={`a${l.price}`} className="ask" data-testid="ask-row">
              <td>▼ {fmt(l.price)}</td>
              <td className="bar" style={{ ['--w' as string]: `${(l.qty / max) * 100}%` }}>{l.qty}</td>
              <td>{l.orders}</td>
            </tr>
          ))}
          <tr className="spread">
            <td colSpan={3}>
              {t('book.spread')}: {spread === null ? '—' : fmt(spread)} · {t('book.last')}:{' '}
              <b data-testid="last-price">{book.lastPrice == null ? '—' : fmt(book.lastPrice)}</b>
            </td>
          </tr>
          {bids.map((l) => (
            <tr key={`b${l.price}`} className="bid" data-testid="bid-row">
              <td>▲ {fmt(l.price)}</td>
              <td className="bar" style={{ ['--w' as string]: `${(l.qty / max) * 100}%` }}>{l.qty}</td>
              <td>{l.orders}</td>
            </tr>
          ))}
          {asks.length + bids.length === 0 && (
            <tr>
              <td colSpan={3}>{t('book.empty')}</td>
            </tr>
          )}
        </tbody>
      </table>
    </>
  );
}
