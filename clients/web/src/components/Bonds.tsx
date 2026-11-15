import { useTranslation } from 'react-i18next';
import { useBonds } from '../hooks';
import { formatMinor } from '../money';
import { bpsPercent } from '../m2a';
import { x100 } from '../m2b';
import { useTime } from './M2bPanels';

const SCALE = 2; // bond money is in SPARK minor units

export function Bonds() {
  const { t, i18n } = useTranslation();
  const time = useTime();
  const bonds = useBonds().data ?? [];
  const money = (v: number) => formatMinor(v, SCALE, i18n.language);
  const pct = (bps: number) => `${bpsPercent(bps, i18n.language)}%`;

  return (
    <div data-testid="bonds">
      <h2>{t('bonds.title')}</h2>
      <table>
        <thead>
          <tr>
            <th>{t('statement.instrument')}</th>
            <th>{t('bonds.face')}</th>
            <th>{t('bonds.coupon')}</th>
            <th>{t('bonds.rating')}</th>
            <th>{t('bonds.maturity')}</th>
            <th>{t('bonds.status')}</th>
            <th>{t('bonds.price')}</th>
            <th>{t('bonds.ytm')}</th>
            <th>{t('bonds.duration')}</th>
            <th>{t('bonds.nextCoupon')}</th>
            <th>{t('bonds.coupons')}</th>
          </tr>
        </thead>
        <tbody>
          {bonds.length === 0 && (
            <tr>
              <td colSpan={11}>{t('bonds.empty')}</td>
            </tr>
          )}
          {bonds.map((b) => (
            <tr key={b.instrument}>
              <td>{b.instrument}</td>
              <td>{money(b.faceValue)}</td>
              <td>
                {pct(b.couponBps)} <span className="hint">({money(b.couponPerUnit)} × {b.couponsPerYear})</span>
              </td>
              <td>{b.rating}</td>
              <td>{time(b.maturityAt)}</td>
              <td>
                <span className={`state ${b.status === 'DEFAULTED' ? 'failed' : b.status === 'REDEEMED' ? 'filled' : 'pending'}`}>
                  {t(`bstatus.${b.status}`)}
                </span>
              </td>
              <td>
                {money(b.price)}
                {b.lastPrice == null && <span className="hint"> {t('bonds.fair')}</span>}
              </td>
              <td data-testid={`ytm-${b.instrument}`}>
                <b>{pct(b.ytmBps)}</b> <span className="hint">({t('bonds.fairYield')} {pct(b.fairYieldBps)})</span>
              </td>
              <td>{t('bonds.years', { n: x100(b.durationX100, i18n.language) })}</td>
              <td>{time(b.nextCouponAt)}</td>
              <td>
                {b.couponsPaid} / {b.couponsLeft}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="hint">{t('bonds.hint')}</p>
    </div>
  );
}
