import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, unwrap, type BookSnapshot, type Instrument } from '../api/client';
import { formatMinor, parseToMinor } from '../money';
import type { MarketState, Mood } from '../api/client';
import { buildJournal } from '../m2c';
import { PositionSize } from './PositionSize';

const MARKET_STATES: MarketState[] = ['TREND_UP', 'TREND_DOWN', 'RANGE', 'VOLATILE', 'NEWS'];
const MOODS: Mood[] = ['CALM', 'CONFIDENT', 'ANXIOUS', 'FOMO', 'REVENGE', 'BORED'];

export function OrderForm({ instrument, book }: { instrument: Instrument; book: BookSnapshot | null }) {
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');
  const [type, setType] = useState<'LIMIT' | 'MARKET'>('LIMIT');
  const [price, setPrice] = useState('');
  const [qty, setQty] = useState('1');
  const [why, setWhy] = useState('');
  const [marketState, setMarketState] = useState<MarketState | ''>('');
  const [mood, setMood] = useState<Mood | ''>('');
  const [riskMinor, setRiskMinor] = useState<number | null>(null);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const priceMinor = type === 'LIMIT' ? parseToMinor(price, instrument.priceScale) : null;
  const qtyUnits = parseToMinor(qty, instrument.qtyScale);
  const refPrice = type === 'LIMIT' ? priceMinor : (side === 'BUY' ? book?.asks[0]?.price : book?.bids[0]?.price) ?? null;
  const notional = refPrice && qtyUnits ? refPrice * qtyUnits : null;
  const fee = notional ? Math.floor((notional * instrument.feeBps) / 10_000) : null;
  const valid = qtyUnits !== null && (type === 'MARKET' || priceMinor !== null);

  const place = useMutation({
    mutationFn: async () =>
      unwrap(
        await api.POST('/orders', {
          params: { header: { 'Idempotency-Key': crypto.randomUUID() } },
          body: { instrument: instrument.id, side, type, qty: qtyUnits!,
            journal: buildJournal(why, marketState, mood, riskMinor),
            ...(type === 'LIMIT' ? { price: priceMinor! } : {}) },
        }),
      ),
    onSuccess: (o) => {
      setMessage({ ok: true, text: t('form.placed', { id: o.orderId, status: t(`status.${o.status}`) }) });
      void qc.invalidateQueries({ queryKey: ['orders'] });
      void qc.invalidateQueries({ queryKey: ['me'] });
    },
    onError: (e) => setMessage({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`) }),
  });

  const fill = (p: number | undefined) => p !== undefined && setPrice(formatMinor(p, instrument.priceScale, 'en').replace(/,/g, ''));

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (valid) place.mutate();
        else setMessage({ ok: false, text: t('form.invalid') });
      }}
    >
      <h2>{t('form.title')}</h2>
      <div className="segmented">
        <button type="button" className={side === 'BUY' ? 'on buy' : ''} onClick={() => setSide('BUY')} data-testid="side-buy">
          {t('form.buy')}
        </button>
        <button type="button" className={side === 'SELL' ? 'on sell' : ''} onClick={() => setSide('SELL')} data-testid="side-sell">
          {t('form.sell')}
        </button>
      </div>
      <div className="segmented">
        <button type="button" className={type === 'LIMIT' ? 'on' : ''} onClick={() => setType('LIMIT')} data-testid="type-limit">
          {t('form.limit')}
        </button>
        <button type="button" className={type === 'MARKET' ? 'on' : ''} onClick={() => setType('MARKET')} data-testid="type-market">
          {t('form.market')}
        </button>
      </div>
      {type === 'LIMIT' ? (
        <label>
          {t('form.price', { quote: instrument.quote })}
          <input inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} data-testid="price" />
          <span className="quick">
            <button type="button" className="ghost" onClick={() => fill(book?.bids[0]?.price)}>{t('form.bestBid')}</button>
            <button type="button" className="ghost" onClick={() => fill(book?.asks[0]?.price)}>{t('form.bestAsk')}</button>
          </span>
        </label>
      ) : (
        <p className="hint">{t('form.marketHint')}</p>
      )}
      <label>
        {t('form.qty', { base: instrument.base })}
        <input inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} data-testid="qty" />
      </label>
      <PositionSize instrument={instrument} entry={refPrice} onRisk={setRiskMinor} onQty={(q) => setQty(formatMinor(q, instrument.qtyScale, 'en').replace(/,/g, ''))} />
      <fieldset data-testid="journal">
        <legend>{t('journal.title')}</legend>
        <label>
          {t('journal.why')}
          <textarea maxLength={280} rows={2} value={why} onChange={(e) => setWhy(e.target.value)} data-testid="journal-why" />
        </label>
        <label>
          {t('journal.marketState')}
          <select value={marketState} onChange={(e) => setMarketState(e.target.value as MarketState | '')} data-testid="journal-market">
            <option value="">—</option>
            {MARKET_STATES.map((m) => (
              <option key={m} value={m}>{t(`marketState.${m}`)}</option>
            ))}
          </select>
        </label>
        <label>
          {t('journal.mood')}
          <select value={mood} onChange={(e) => setMood(e.target.value as Mood | '')} data-testid="journal-mood">
            <option value="">—</option>
            {MOODS.map((m) => (
              <option key={m} value={m}>{t(`mood.${m}`)}</option>
            ))}
          </select>
        </label>
        <p className="hint">{riskMinor != null ? t('journal.plannedRisk', { r: formatMinor(riskMinor, instrument.priceScale, i18n.language), quote: instrument.quote }) : t('journal.noRisk')}</p>
      </fieldset>
      {notional !== null && fee !== null && (
        <p className="hint">
          {t('form.estimate', {
            amount: formatMinor(notional, instrument.priceScale, i18n.language),
            fee: formatMinor(fee, instrument.priceScale, i18n.language),
            quote: instrument.quote,
          })}
        </p>
      )}
      <button type="submit" className={side === 'BUY' ? 'buy' : 'sell'} disabled={place.isPending} data-testid="submit-order">
        {t('form.submit')}
      </button>
      {message && (
        <p className={message.ok ? 'ok' : 'error'} data-testid="order-message">
          {message.text}
        </p>
      )}
    </form>
  );
}
