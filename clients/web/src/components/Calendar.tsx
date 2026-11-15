import { useTranslation } from 'react-i18next';
import type { CalendarEntry } from '../api/client';
import { useCalendar, useMacro } from '../hooks';
import { formatMinor } from '../money';
import { bpsPercent } from '../m2a';
import { useTime } from './M2bPanels';

/** consensus/actual/previous mean different units per kind (contract: CalendarEntry). */
function valueText(e: CalendarEntry, v: number | null | undefined, locale: string): string {
  if (v == null) return '—';
  switch (e.kind) {
    case 'RATE_DECISION':
      return `${bpsPercent(v, locale)}%`;
    case 'STORM':
      return `${v}%`;
    default:
      return formatMinor(v, 2, locale);
  }
}

export function Calendar() {
  const { t, i18n } = useTranslation();
  const time = useTime();
  const entries = useCalendar().data ?? [];
  const m = useMacro().data;
  const pct = (bps: number | null | undefined) => (bps == null ? '—' : `${bpsPercent(bps, i18n.language)}%`);

  return (
    <div data-testid="calendar">
      {m && (
        <table className="totals" data-testid="macro">
          <tbody>
            <tr>
              <th>{t('macro.policyRate')}</th>
              <td>{pct(m.policyRateBps)}</td>
              <th>{t('macro.inflation')}</th>
              <td>{pct(m.inflationBps)}</td>
              <th>{t('macro.realRate')}</th>
              <td className={m.realRateBps < 0 ? 'error' : ''}>{pct(m.realRateBps)}</td>
              <th>{t('macro.depositRate')}</th>
              <td>{pct(m.savingsRateBps)}</td>
              <th>{t('macro.nextDecision')}</th>
              <td>
                {time(m.nextDecisionAt)}
                {m.nextConsensusBps != null && <span className="hint"> · {t('calendar.consensus')} {pct(m.nextConsensusBps)}</span>}
              </td>
              <th>{t('macro.regime')}</th>
              <td>
                <span className={`state ${m.regime === 'STORM' ? 'fired' : 'pending'}`}>{t(`regime.${m.regime}`)}</span>
                {m.regime === 'STORM' && <span className="hint"> {t('macro.volatility', { pct: m.volatilityPct })}</span>}
              </td>
            </tr>
          </tbody>
        </table>
      )}
      <h2>{t('calendar.title')}</h2>
      <table data-testid="calendar-entries">
        <thead>
          <tr>
            <th>{t('statement.time')}</th>
            <th>{t('calendar.event')}</th>
            <th>{t('statement.instrument')}</th>
            <th>{t('calendar.status')}</th>
            <th>{t('calendar.previous')}</th>
            <th>{t('calendar.consensus')}</th>
            <th>{t('calendar.actual')}</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 && (
            <tr>
              <td colSpan={7}>{t('calendar.empty')}</td>
            </tr>
          )}
          {entries.map((e, i) => (
            <tr key={i} className={e.done ? 'done' : ''}>
              <td>{time(e.at)}</td>
              <td>{t(`ckind.${e.kind}`)}</td>
              <td>{e.instrument ?? '—'}</td>
              <td>
                <span className={`state ${e.done ? 'filled' : 'pending'}`}>{t(e.done ? 'calendar.done' : 'calendar.scheduled')}</span>
              </td>
              <td>{valueText(e, e.previous, i18n.language)}</td>
              <td>{valueText(e, e.consensus, i18n.language)}</td>
              <td>{valueText(e, e.actual, i18n.language)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
