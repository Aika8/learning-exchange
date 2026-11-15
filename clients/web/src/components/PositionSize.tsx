import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Instrument } from '../api/client';
import { useAtr } from '../hooks';
import { formatMinor, parseToMinor } from '../money';
import { atrStopDistance, parseTenths, sizeByRisk } from '../m2c';
import { bpsPercent } from '../m2a';

type Mode = 'price' | 'atr';

/** Position-size helper: 1 R = the money I accept to lose; qty = floor(R / stop distance). Stop by price or k × ATR(14). */
export function PositionSize({
  instrument,
  entry,
  onRisk,
  onQty,
}: {
  instrument: Instrument;
  entry: number | null;
  onRisk: (riskMinor: number | null) => void;
  onQty: (qty: number) => void;
}) {
  const { t, i18n } = useTranslation();
  const [mode, setMode] = useState<Mode>('atr');
  const [risk, setRisk] = useState('');
  const [stop, setStop] = useState('');
  const [k, setK] = useState('2');
  const atr = useAtr(instrument.id).data;
  const money = (v: number) => formatMinor(v, instrument.priceScale, i18n.language);

  const riskMinor = parseToMinor(risk, instrument.priceScale);
  const stopMinor = parseToMinor(stop, instrument.priceScale);
  const kTenths = parseTenths(k);
  const distance =
    mode === 'atr'
      ? atr?.ready && atr.atr != null && kTenths != null
        ? atrStopDistance(atr.atr, kTenths)
        : null
      : entry != null && stopMinor != null
        ? Math.abs(entry - stopMinor)
        : null;
  const qty = riskMinor != null && distance != null ? sizeByRisk(riskMinor, distance) : null;

  return (
    <fieldset data-testid="position-size">
      <legend>{t('psize.title')}</legend>
      <label>
        {t('psize.risk', { quote: instrument.quote })}
        <input
          inputMode="decimal"
          value={risk}
          onChange={(e) => {
            setRisk(e.target.value);
            onRisk(parseToMinor(e.target.value, instrument.priceScale));
          }}
          data-testid="risk"
        />
      </label>
      <div className="segmented small">
        {(['price', 'atr'] as Mode[]).map((m) => (
          <button key={m} type="button" className={m === mode ? 'on' : ''} onClick={() => setMode(m)} data-testid={`psize-${m}`}>
            {t(`psize.mode.${m}`)}
          </button>
        ))}
      </div>
      {mode === 'price' ? (
        <label>
          {t('psize.stopPrice')}
          <input inputMode="decimal" value={stop} onChange={(e) => setStop(e.target.value)} />
        </label>
      ) : (
        <>
          <label>
            {t('psize.k')}
            <input inputMode="decimal" value={k} onChange={(e) => setK(e.target.value)} size={4} data-testid="atr-k" />
          </label>
          <p className="hint" data-testid="atr-value">
            {!atr || !atr.ready || atr.atr == null
              ? t('psize.notReady', { candles: atr?.candles ?? 0, need: (atr?.period ?? 14) + 1 })
              : t('psize.atr', {
                  period: atr.period,
                  atr: money(atr.atr),
                  pct: atr.atrBps == null ? '—' : bpsPercent(atr.atrBps, i18n.language),
                })}
          </p>
        </>
      )}
      {distance != null && <p className="hint">{t('psize.distance', { d: money(distance) })}</p>}
      {qty != null && (
        <p className="hint" data-testid="psize-qty">
          {t('psize.qty', { qty })}{' '}
          {qty > 0 && (
            <button type="button" className="ghost" onClick={() => onQty(qty)}>
              {t('psize.use')}
            </button>
          )}
        </p>
      )}
    </fieldset>
  );
}
