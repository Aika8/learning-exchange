import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, unwrap, type ConditionalKind, type Instrument } from '../api/client';
import { fieldsFor, type ConditionalField } from '../m2a';
import { parseToMinor } from '../money';

const KINDS: ConditionalKind[] = ['STOP_LIMIT', 'STOP_MARKET', 'TRAILING_TP', 'TP_SL'];
/** Fields that may stay empty (TP_SL stop leg limit = market; protective spread = backend default). */
const OPTIONAL: ConditionalField[] = ['protectiveSpread'];

export function StopForm({ instrument }: { instrument: Instrument }) {
  const { t } = useTranslation();
  const qc = useQueryClient();
  const [kind, setKind] = useState<ConditionalKind>('STOP_LIMIT');
  const [side, setSide] = useState<'BUY' | 'SELL'>('SELL');
  const [qty, setQty] = useState('1');
  const [values, setValues] = useState<Partial<Record<ConditionalField, string>>>({});
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const fields = fieldsFor(kind);
  const optional = (f: ConditionalField) => OPTIONAL.includes(f) || (kind === 'TP_SL' && f === 'limitPrice');
  const parsed = Object.fromEntries(
    fields.map((f) => [f, values[f]?.trim() ? parseToMinor(values[f]!, instrument.priceScale) : undefined]),
  ) as Partial<Record<ConditionalField, number | null>>;
  const qtyUnits = parseToMinor(qty, instrument.qtyScale);
  const valid = qtyUnits !== null && fields.every((f) => parsed[f] !== null && (parsed[f] !== undefined || optional(f)));

  const place = useMutation({
    mutationFn: async () => {
      const prices = Object.fromEntries(Object.entries(parsed).filter(([, v]) => v != null)) as Record<string, number>;
      return unwrap(
        await api.POST('/conditional-orders', {
          params: { header: { 'Idempotency-Key': crypto.randomUUID() } },
          body: { instrument: instrument.id, kind, side, qty: qtyUnits!, ...prices },
        }),
      );
    },
    onSuccess: (c) => {
      setMessage({ ok: true, text: t('stops.placed', { id: c.conditionalId, state: t(`cstate.${c.state}`) }) });
      void qc.invalidateQueries({ queryKey: ['conditional'] });
    },
    onError: (e) => setMessage({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`) }),
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (valid) place.mutate();
        else setMessage({ ok: false, text: t('form.invalid') });
      }}
      data-testid="stop-form"
    >
      <h2>{t('stops.formTitle')}</h2>
      <label>
        {t('stops.kind')}
        <select value={kind} onChange={(e) => setKind(e.target.value as ConditionalKind)} data-testid="stop-kind">
          {KINDS.map((k) => (
            <option key={k} value={k}>
              {t(`ckind.${k}`)}
            </option>
          ))}
        </select>
      </label>
      <p className="hint">{t(`ckindHint.${kind}`)}</p>
      <div className="segmented">
        <button type="button" className={side === 'BUY' ? 'on buy' : ''} onClick={() => setSide('BUY')}>
          {t('form.buy')}
        </button>
        <button type="button" className={side === 'SELL' ? 'on sell' : ''} onClick={() => setSide('SELL')}>
          {t('form.sell')}
        </button>
      </div>
      {fields.map((f) => (
        <label key={f}>
          {t(`stops.${f}`, { quote: instrument.quote })}
          {optional(f) ? ` (${t('stops.optional')})` : ''}
          <input
            inputMode="decimal"
            value={values[f] ?? ''}
            onChange={(e) => setValues({ ...values, [f]: e.target.value })}
            data-testid={`stop-${f}`}
          />
        </label>
      ))}
      <label>
        {t('form.qty', { base: instrument.base })}
        <input inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} data-testid="stop-qty" />
      </label>
      <p className="hint">{t('stops.lastTradeHint')}</p>
      <button type="submit" className={side === 'BUY' ? 'buy' : 'sell'} disabled={place.isPending} data-testid="stop-submit">
        {t('stops.submit')}
      </button>
      {message && <p className={message.ok ? 'ok' : 'error'}>{message.text}</p>}
    </form>
  );
}
