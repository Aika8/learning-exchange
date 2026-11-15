import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Clock } from '../api/client';
import { useStatement } from '../hooks';
import { formatMinor } from '../money';
import { bpsPercent } from '../m2a';

const SCALE = 2; // statement money is in the quote currency (SPARK)
const PERIODS = { all: null, hour: 3_600_000, day: 86_400_000 } as const;
type Period = keyof typeof PERIODS;

export function StatementPanel({ clock }: { clock: Clock | null }) {
  const { t, i18n } = useTranslation();
  const [period, setPeriod] = useState<Period>('all');
  const [anchor, setAnchor] = useState<number | undefined>(undefined);
  const span = PERIODS[period];
  const from = span !== null && anchor !== undefined ? anchor - span : undefined;
  const st = useStatement(from, undefined).data;
  const money = (v: number | null | undefined) => (v == null ? '—' : formatMinor(v, SCALE, i18n.language));
  const time = (ts: number) => new Date(ts).toLocaleString(i18n.language, { dateStyle: 'short', timeStyle: 'medium' });
  const choose = (p: Period) => {
    setPeriod(p);
    setAnchor(clock?.now);
  };

  return (
    <>
      <h2>
        {t('statement.title')}
        <div className="segmented small">
          {(Object.keys(PERIODS) as Period[]).map((p) => (
            <button key={p} className={p === period ? 'on' : ''} onClick={() => choose(p)} data-testid={`period-${p}`}>
              {t(`statement.period.${p}`)}
            </button>
          ))}
        </div>
      </h2>
      {st && (
        <>
          <p className="hint">{t('statement.range', { from: time(st.from), to: time(st.to), currency: st.currency })}</p>
          <table className="totals" data-testid="statement-totals">
            <tbody>
              <tr>
                <th>{t('statement.fees')}</th>
                <td>{money(st.totals.fees)}</td>
                <th>{t('statement.spread')}</th>
                <td>{money(st.totals.spreadPaid)}</td>
                <th>{t('statement.pnl')}</th>
                <td className={st.totals.realisedPnl < 0 ? 'error' : 'ok'}>{money(st.totals.realisedPnl)}</td>
                <th>{t('statement.tax', { rate: bpsPercent(st.totals.taxRateBps, i18n.language) })}</th>
                <td>{money(st.totals.tax)}</td>
                <th>{t('statement.interest')}</th>
                <td className="ok">{money(st.totals.interest)}</td>
                <th>{t('statement.payouts')}</th>
                <td className="ok" data-testid="statement-payouts">{money(st.totals.payouts)}</td>
              </tr>
            </tbody>
          </table>
          <p className="hint">{t('statement.hint')}</p>
          <table data-testid="statement-lines">
            <thead>
              <tr>
                <th>{t('statement.time')}</th>
                <th>{t('statement.kind')}</th>
                <th>{t('statement.instrument')}</th>
                <th>{t('statement.priceQty')}</th>
                <th>{t('statement.mid')}</th>
                <th>{t('statement.amount')}</th>
                <th>{t('statement.fee')}</th>
                <th>{t('statement.spreadCol')}</th>
                <th>{t('statement.pnlCol')}</th>
              </tr>
            </thead>
            <tbody>
              {st.lines.length === 0 && (
                <tr>
                  <td colSpan={9}>{t('statement.empty')}</td>
                </tr>
              )}
              {st.lines
                .slice()
                .reverse()
                .map((l, i) => (
                  <tr key={i}>
                    <td>{time(l.ts)}</td>
                    <td>
                      {t(`skind.${l.kind}`)}
                      {l.margin && <span className="chip">{t('statement.marginFlag')}</span>}
                    </td>
                    <td>
                      {l.instrument ?? '—'} {l.side ? t(`side.${l.side}`) : ''}
                    </td>
                    <td>{l.price != null ? `${money(l.price)} × ${l.qty}` : l.qty ?? '—'}</td>
                    <td>{money(l.mid)}</td>
                    <td className={l.amount < 0 ? 'error' : 'ok'}>
                      {formatMinor(l.amount, l.asset === 'SPARK' ? SCALE : 0, i18n.language)} {l.asset}
                    </td>
                    <td>{l.fee ? money(l.fee) : '—'}</td>
                    <td>{l.spreadPaid ? money(l.spreadPaid) : '—'}</td>
                    <td>{l.realisedPnl ? money(l.realisedPnl) : '—'}</td>
                  </tr>
                ))}
            </tbody>
          </table>
        </>
      )}
    </>
  );
}
