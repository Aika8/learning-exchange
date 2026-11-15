import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useFunds } from '../hooks';
import { formatMinor } from '../money';
import { bpsPercent } from '../m2a';
import { signedPercent } from '../m2b';
import { fundGapBps } from '../m2c';

const SCALE = 2; // fund money is in SPARK minor units

/** Funds by their real names (instrument ids); lore names belong to the game BFF only. */
export function Funds() {
  const { t, i18n } = useTranslation();
  const list = useFunds().data ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const f = list.find((x) => x.instrument === picked) ?? list[0];
  const money = (v: number | null | undefined) => (v == null ? '—' : formatMinor(v, SCALE, i18n.language));
  const pct = (bps: number | null | undefined) => (bps == null ? '—' : `${bpsPercent(bps, i18n.language)}%`);
  const signed = (bps: number | null | undefined) => (bps == null ? '—' : `${signedPercent(bps, i18n.language)}%`);

  return (
    <div data-testid="funds">
      <h2>
        {t('funds.title')}
        <div className="segmented small">
          {list.map((x) => (
            <button key={x.instrument} className={x.instrument === f?.instrument ? 'on' : ''} onClick={() => setPicked(x.instrument)}>
              {x.instrument}
            </button>
          ))}
        </div>
      </h2>
      {!f && <p className="hint">{t('funds.empty')}</p>}
      {f && (
        <>
          <p><span className="chip">{t(`funds.kind.${f.kind}`)}</span></p>
          <table className="totals">
            <tbody>
              <tr>
                <th>{t('funds.ter')}</th><td>{pct(f.terBps)}</td>
                <th>{t('funds.nav')}</th><td>{money(f.nav)}</td>
                <th>{t('funds.navPerUnit')}</th><td>{money(f.navPerUnit)}</td>
                <th>{t('funds.unitPrice')}</th><td>{money(f.lastPrice)}</td>
                <th>{t('funds.premium')}</th><td>{signed(f.premiumBps)}</td>
                <th>{t('funds.units')}</th><td>{f.unitsOutstanding}</td>
                <th>{t('funds.cash')}</th><td>{money(f.cash)}</td>
                <th>{t('funds.feesPaid')}</th><td>{money(f.feesPaid)}</td>
              </tr>
            </tbody>
          </table>
          <div className="split2">
            <div>
              <h3>{t('funds.holdings')}</h3>
              <table data-testid="fund-holdings">
                <thead>
                  <tr><th>{t('statement.instrument')}</th><th>{t('companies.qty')}</th><th>{t('companies.price')}</th><th>{t('funds.value')}</th><th>{t('funds.weight')}</th></tr>
                </thead>
                <tbody>
                  {f.holdings.length === 0 && <tr><td colSpan={5}>—</td></tr>}
                  {f.holdings.map((h) => (
                    <tr key={h.instrument}>
                      <td>{h.instrument}</td><td>{h.qty}</td><td>{money(h.price)}</td><td>{money(h.value)}</td><td>{pct(h.weightBps)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div>
              <h3>{t('funds.vsBasket')}</h3>
              <table data-testid="fund-vs-basket">
                <tbody>
                  <tr><th>{t('funds.fundReturn')}</th><td>{signed(f.fundReturnBps)}</td></tr>
                  <tr><th>{t('funds.basketReturn')}</th><td>{signed(f.basketReturnBps)}</td></tr>
                  <tr><th>{t('funds.gap')}</th><td>{signed(fundGapBps(f.fundReturnBps, f.basketReturnBps))}</td></tr>
                  <tr><th>{t('funds.value')}</th><td>{money(f.nav)} / {money(f.basketValue)}</td></tr>
                  <tr><th>{t('funds.tenYear')}</th><td>{pct(f.tenYearCostBps)}</td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
