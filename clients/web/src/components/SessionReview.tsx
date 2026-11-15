import { useTranslation } from 'react-i18next';
import type { ReviewGroup } from '../api/client';
import { useSessionReview } from '../hooks';
import { formatMinor } from '../money';
import { rText } from '../m2c';
import { useTime } from './M2bPanels';

const SCALE = 2; // review money is in the quote currency (SPARK)

export function SessionReview() {
  const { t, i18n } = useTranslation();
  const time = useTime();
  const r = useSessionReview().data;
  const money = (v: number) => formatMinor(v, SCALE, i18n.language);
  if (!r) return null;

  const groups = (title: string, ns: 'mood' | 'marketState', list: ReviewGroup[], testId: string) => (
    <div>
      <h3>{title}</h3>
      <table data-testid={testId}>
        <thead>
          <tr><th>{t('review.group')}</th><th>{t('review.orders')}</th><th>{t('review.wins')}</th><th>{t('review.result')}</th><th>{t('review.avgR')}</th></tr>
        </thead>
        <tbody>
          {list.length === 0 && <tr><td colSpan={5}>—</td></tr>}
          {list.map((g) => (
            <tr key={g.key}>
              <td>{t(`${ns}.${g.key}`, g.key)}</td>
              <td>{g.orders}</td>
              <td>{g.wins}</td>
              <td className={g.result < 0 ? 'error' : 'ok'}>{money(g.result)}</td>
              <td>{rText(g.avgRx100, i18n.language)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );

  return (
    <div data-testid="session-review">
      <h2>{t('review.title')}</h2>
      <p className="hint">
        {t('review.summary', {
          orders: r.orders,
          annotated: r.annotated,
          wins: r.wins,
          result: money(r.result),
          currency: r.currency,
          exp: rText(r.expectancyRx100, i18n.language),
        })}
      </p>
      <p className="hint">{t('review.hint')}</p>
      <table data-testid="review-entries">
        <thead>
          <tr>
            <th>{t('statement.time')}</th><th>{t('review.order')}</th><th>{t('review.note')}</th>
            <th>{t('review.result')}</th><th>{t('review.r')}</th>
          </tr>
        </thead>
        <tbody>
          {r.entries.length === 0 && <tr><td colSpan={5}>{t('review.empty')}</td></tr>}
          {r.entries.slice().reverse().map((e) => (
            <tr key={e.orderId}>
              <td>{time(e.placedAt)}</td>
              <td>
                #{e.orderId} {e.instrument} {t(`side.${e.side}`)} {e.filledQty}/{e.qty}
              </td>
              <td>
                {e.note?.why ?? ''}{' '}
                {e.note?.mood && <span className="chip">{t(`mood.${e.note.mood}`)}</span>}
                {e.note?.marketState && <span className="chip">{t(`marketState.${e.note.marketState}`)}</span>}
              </td>
              <td className={e.result < 0 ? 'error' : 'ok'}>{money(e.result)}</td>
              <td>{rText(e.resultRx100, i18n.language)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="split2">
        {groups(t('review.byMood'), 'mood', r.byMood, 'review-by-mood')}
        {groups(t('review.byMarket'), 'marketState', r.byMarketState, 'review-by-market')}
      </div>
    </div>
  );
}
