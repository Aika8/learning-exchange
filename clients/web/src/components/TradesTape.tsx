import { useTranslation } from 'react-i18next';
import type { Instrument, Trade } from '../api/client';
import { formatMinor } from '../money';

export function TradesTape({ trades, instrument }: { trades: Trade[]; instrument: Instrument }) {
  const { t, i18n } = useTranslation();
  const time = new Intl.DateTimeFormat(i18n.language, { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  return (
    <>
      <h2>{t('tape.title')}</h2>
      <table data-testid="tape">
        <thead>
          <tr>
            <th>{t('tape.time')}</th>
            <th>{t('tape.price')}</th>
            <th>{t('tape.qty')}</th>
          </tr>
        </thead>
        <tbody>
          {trades.length === 0 && (
            <tr>
              <td colSpan={3}>{t('tape.empty')}</td>
            </tr>
          )}
          {trades.slice(0, 20).map((tr) => (
            <tr key={tr.tradeId} className={tr.aggressorSide === 'BUY' ? 'bid' : 'ask'} data-testid="tape-row">
              <td>{time.format(tr.ts)}</td>
              <td>
                {tr.aggressorSide === 'BUY' ? '▲' : '▼'} {formatMinor(tr.price, instrument.priceScale, i18n.language)}
              </td>
              <td>{tr.qty}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
