import { useState } from 'react';
import { Modal, Pressable, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, call, type Instrument, type Schemas } from '../api/client';
import { refetchAccount } from '../hooks';
import { parseToMinor } from '../money';
import { radius, useColors } from '../theme/theme';
import { Button, Caption, Segmented, Title } from './ui';
import { Field } from './Field';

type Kind = Schemas['ConditionalKind'];
type Mode = 'SL' | 'TP' | 'TPSL';
type Side = 'BUY' | 'SELL';

/** Ticket for conditional orders: stop-loss (stop-limit / stop-market), trailing take-profit, TP+SL (OCO). */
export function StopTicket({ instrument, initial, onClose }: { instrument: Instrument; initial?: { qty?: string; trigger?: string; side?: Side }; onClose: () => void }) {
  const c = useColors();
  const { t } = useTranslation();
  const qc = useQueryClient();
  const [mode, setMode] = useState<Mode>('SL');
  const [slKind, setSlKind] = useState<'STOP_LIMIT' | 'STOP_MARKET'>('STOP_MARKET');
  const [side, setSide] = useState<Side>(initial?.side ?? 'SELL');
  const [qty, setQty] = useState(initial?.qty ?? '1');
  const [trigger, setTrigger] = useState(initial?.trigger ?? '');
  const [limit, setLimit] = useState('');
  const [activation, setActivation] = useState('');
  const [offset, setOffset] = useState('');
  const [protective, setProtective] = useState('');
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);
  const ps = instrument.priceScale;
  const price = (s: string) => parseToMinor(s, ps);
  const kind: Kind = mode === 'SL' ? slKind : mode === 'TP' ? 'TRAILING_TP' : 'TP_SL';

  const body = (): Schemas['PlaceConditionalRequest'] | null => {
    const q = parseToMinor(qty, instrument.qtyScale);
    if (q === null) return null;
    const base = { instrument: instrument.id, kind, side, qty: q };
    if (kind === 'STOP_MARKET') return price(trigger) ? { ...base, triggerPrice: price(trigger)! } : null;
    if (kind === 'STOP_LIMIT') return price(trigger) && price(limit) ? { ...base, triggerPrice: price(trigger)!, limitPrice: price(limit)! } : null;
    const tp = { activationPrice: price(activation), offset: offset.trim() === '' ? 0 : price(offset), protectiveSpread: protective.trim() === '' ? 0 : price(protective) };
    if (!tp.activationPrice || tp.offset === null || tp.protectiveSpread === null) return null;
    if (kind === 'TRAILING_TP') return { ...base, activationPrice: tp.activationPrice, offset: tp.offset, protectiveSpread: tp.protectiveSpread };
    return price(trigger) ? { ...base, triggerPrice: price(trigger)!, limitPrice: limit.trim() === '' ? 0 : (price(limit) ?? 0), activationPrice: tp.activationPrice, offset: tp.offset, protectiveSpread: tp.protectiveSpread } : null;
  };

  const place = useMutation({
    mutationFn: (b: Schemas['PlaceConditionalRequest']) => call(api.POST('/conditional-orders', { body: b })),
    onSuccess: (o) => {
      setResult({ ok: true, text: t('stops.placed', { id: o.conditionalId, state: t(`cstate.${o.state}`) }) });
      refetchAccount(qc);
    },
    onError: (e) => setResult({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`, { defaultValue: t('errors.BAD_REQUEST') }) }),
  });

  const submit = () => {
    const b = body();
    if (!b) return setResult({ ok: false, text: t('stops.errFields') });
    place.mutate(b);
  };
  const q = instrument.quote;

  return (
    <Modal transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={{ flex: 1, backgroundColor: 'rgba(5,9,12,0.45)' }} onPress={onClose} />
      <View style={{ backgroundColor: c.surface, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, padding: 20, gap: 10 }} testID="stop-ticket">
        <Title>{t('stops.ticketTitle', { base: instrument.base })}</Title>
        <Segmented testIDPrefix="stop-mode" value={mode} onChange={setMode} options={[{ value: 'SL', label: t('stops.stopLoss') }, { value: 'TP', label: t('stops.takeProfit') }, { value: 'TPSL', label: t('stops.tpsl') }]} />
        <Segmented testIDPrefix="stop-side" value={side} onChange={setSide} options={[{ value: 'SELL', label: t('instrument.sell') }, { value: 'BUY', label: t('instrument.buy') }]} />
        {mode === 'SL' && (
          <Segmented testIDPrefix="stop-kind" value={slKind} onChange={setSlKind} options={[{ value: 'STOP_MARKET', label: t('ckind.STOP_MARKET') }, { value: 'STOP_LIMIT', label: t('ckind.STOP_LIMIT') }]} />
        )}
        <Caption>{t(`stops.hint${mode}`)}</Caption>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Field testID="stop-qty" label={t('ticket.qty', { base: instrument.base })} value={qty} onChange={setQty} />
          {mode !== 'TP' && <Field testID="stop-trigger" label={t('stops.trigger', { quote: q })} value={trigger} onChange={setTrigger} />}
        </View>
        {(mode === 'TPSL' || (mode === 'SL' && slKind === 'STOP_LIMIT')) && (
          <Field testID="stop-limit" label={t(mode === 'TPSL' ? 'stops.limitOptional' : 'stops.limit', { quote: q })} value={limit} onChange={setLimit} />
        )}
        {mode !== 'SL' && (
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Field testID="stop-activation" label={t('stops.activation', { quote: q })} value={activation} onChange={setActivation} />
            <Field testID="stop-offset" label={t('stops.offset', { quote: q })} value={offset} onChange={setOffset} />
            <Field testID="stop-protective" label={t('stops.protective', { quote: q })} value={protective} onChange={setProtective} />
          </View>
        )}
        <Caption>{t('stops.lastTradeNote')}</Caption>
        {result && (
          <Text testID="stop-result" style={{ color: result.ok ? c.positive : c.negative, fontWeight: '600' }}>
            {result.text}
          </Text>
        )}
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Button testID="stop-close" title={t('ticket.close')} onPress={onClose} color={c.textSecondary} />
          <Button testID="stop-submit" title={t('stops.cta')} onPress={submit} disabled={place.isPending} />
        </View>
        <Caption>{t('app.notAdvice')}</Caption>
      </View>
    </Modal>
  );
}
