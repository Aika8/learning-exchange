import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { EarningsReport, Instrument } from '../api/client';
import { useCompanies, useConditionals } from '../hooks';
import { formatMinor } from '../money';
import { bpsPercent } from '../m2a';
import { gapRisk, signedPercent, x100 } from '../m2b';
import { useTime } from './M2bPanels';

const SCALE = 2; // company figures are in SPARK minor units

export function Companies({ current, now }: { current: Instrument; now: number | undefined }) {
  const { t, i18n } = useTranslation();
  const time = useTime();
  const list = useCompanies().data ?? [];
  const stops = useConditionals().data ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const id = picked ?? (list.some((c) => c.instrument === current.id) ? current.id : list[0]?.instrument);
  const c = list.find((x) => x.instrument === id);
  const money = (v: number | null | undefined) => (v == null ? '—' : formatMinor(v, SCALE, i18n.language));
  const pct = (bps: number | null | undefined) => (bps == null ? '—' : `${bpsPercent(bps, i18n.language)}%`);
  const rep: EarningsReport | null | undefined = c?.lastReport;

  return (
    <div data-testid="companies">
      <h2>
        {t('companies.title')}
        <div className="segmented small">
          {list.map((x) => (
            <button key={x.instrument} className={x.instrument === id ? 'on' : ''} onClick={() => setPicked(x.instrument)}>
              {x.instrument}
            </button>
          ))}
        </div>
      </h2>
      {!c && <p className="hint">{t('companies.empty')}</p>}
      {c && (
        <>
          {!c.tradingOpen && <p className="badge warn">{t('instrument.halted')}</p>}
          {gapRisk(c.instrument, c.nextReportAt, now, stops) && (
            <p className="badge warn" data-testid="gap-warning">
              {t('companies.gapWarning')}
            </p>
          )}
          <table className="totals">
            <tbody>
              <tr>
                <th>{t('companies.lastPrice')}</th>
                <td>{money(c.lastPrice)}</td>
                <th>{t('companies.epsTtm')}</th>
                <td>{money(c.epsTtm)}</td>
                <th>{t('companies.pe')}</th>
                <td>{c.peX100 == null ? '—' : x100(c.peX100, i18n.language)}</td>
                <th>{t('companies.debtToProfit')}</th>
                <td>{c.debtToProfitX100 == null ? '—' : x100(c.debtToProfitX100, i18n.language)}</td>
                <th>{t('companies.dividendYield')}</th>
                <td>{pct(c.dividendYieldBps)}</td>
                <th>{t('companies.nextReport')}</th>
                <td>{time(c.nextReportAt)}</td>
              </tr>
            </tbody>
          </table>
          <div className="split2">
            <div>
              <h3>{t('companies.lastReport')}</h3>
              {!rep ? (
                <p className="hint">{t('companies.noReport')}</p>
              ) : (
                <>
                  <p className="hint">
                    {t('companies.season', { n: rep.season, at: time(rep.ts) })}{' '}
                    {c.surpriseBps != null && (
                      <span className={c.surpriseBps < 0 ? 'error' : 'ok'}>
                        {t('companies.surprise', { pct: signedPercent(c.surpriseBps, i18n.language) })}
                      </span>
                    )}
                  </p>
                  <table>
                    <tbody>
                      <tr><th>{t('companies.revenue')}</th><td>{money(rep.revenue)}</td></tr>
                      <tr><th>{t('companies.netProfit')}</th><td>{money(rep.netProfit)}</td></tr>
                      <tr><th>{t('companies.eps')}</th><td>{money(rep.eps)} <span className="hint">({t('companies.consensusShort')} {money(rep.consensusEps)})</span></td></tr>
                      <tr><th>{t('companies.debt')}</th><td>{money(rep.debt)}</td></tr>
                      <tr><th>{t('companies.ocf')}</th><td>{money(rep.operatingCashFlow)}</td></tr>
                      <tr><th>{t('companies.dividend')}</th><td>{money(rep.dividendPerShare)}</td></tr>
                      <tr><th>{t('companies.guidance')}</th><td>{money(rep.guidanceEps)}</td></tr>
                    </tbody>
                  </table>
                </>
              )}
            </div>
            <div>
              <h3>{t('companies.consensus')}</h3>
              {!c.consensus ? (
                <p className="hint">{t('companies.noConsensus')}</p>
              ) : (
                <table>
                  <tbody>
                    <tr><th>{t('companies.reportAt')}</th><td>{time(c.consensus.reportAt)}</td></tr>
                    <tr><th>{t('companies.revenue')}</th><td>{money(c.consensus.revenue)}</td></tr>
                    <tr><th>{t('companies.netProfit')}</th><td>{money(c.consensus.netProfit)}</td></tr>
                    <tr><th>{t('companies.eps')}</th><td>{money(c.consensus.eps)}</td></tr>
                  </tbody>
                </table>
              )}
              <h3>{t('companies.dividends')}</h3>
              <table>
                <thead>
                  <tr><th>{t('companies.exDate')}</th><th>{t('companies.perShare')}</th><th>{t('companies.paid')}</th></tr>
                </thead>
                <tbody>
                  {c.dividends.length === 0 && <tr><td colSpan={3}>—</td></tr>}
                  {c.dividends.map((d, i) => (
                    <tr key={i}>
                      <td>{time(d.exDate)}</td>
                      <td>{money(d.perShare)}</td>
                      <td>{d.paid ? t('common.yes') : t('common.no')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          <h3>{t('companies.insiders')}</h3>
          <table data-testid="insider-trades">
            <thead>
              <tr>
                <th>{t('statement.time')}</th><th>{t('companies.insider')}</th><th>{t('companies.role')}</th>
                <th>{t('orders.side')}</th><th>{t('companies.qty')}</th><th>{t('companies.price')}</th>
              </tr>
            </thead>
            <tbody>
              {c.insiderTrades.length === 0 && <tr><td colSpan={6}>—</td></tr>}
              {c.insiderTrades.slice().reverse().map((x, i) => (
                <tr key={i}>
                  <td>{time(x.ts)}</td><td>{x.insider}</td><td>{t(`role.${x.role}`)}</td>
                  <td className={x.side === 'BUY' ? 'bid' : 'ask'}>{t(`side.${x.side}`)}</td>
                  <td>{x.qty}</td><td>{money(x.price)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}
