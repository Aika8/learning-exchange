import { useState } from 'react';
import { Modal, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { api, ApiError, call, type BookSnapshot, type Instrument, type Schemas } from '../api/client';
import { formatMinor, parseToMinor } from '../money';
import { radius, useColors } from '../theme/theme';
import { Body, Button, Caption, Chips, Segmented, Title } from './ui';

const MARKET_STATES: Schemas['MarketState'][] = ['TREND_UP', 'TREND_DOWN', 'RANGE', 'VOLATILE', 'NEWS'];
const MOODS: Schemas['Mood'][] = ['CALM', 'CONFIDENT', 'ANXIOUS', 'FOMO', 'REVENGE', 'BORED'];
const WHY_MAX = 280;

type Side = 'BUY' | 'SELL';
type Form = { type: 'LIMIT' | 'MARKET'; price: string; qty: string };

/**
 * Design S04 (order ticket): limit/market, price, quantity, fee and total before sending, plus an optional trade-journal
 * note (why, market state, mood, planned risk = 1 R from the position-size helper) sent with the order.
 */
export function OrderTicket({ side, instrument, book, onClose, plannedRisk }: { side: Side; instrument: Instrument; book: BookSnapshot | null; onClose: () => void; plannedRisk?: number | null }) {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);
  const [why, setWhy] = useState('');
  const [marketState, setMarketState] = useState<Schemas['MarketState'] | null>(null);
  const [mood, setMood] = useState<Schemas['Mood'] | null>(null);
  const [risk, setRisk] = useState(plannedRisk ? formatMinor(plannedRisk, instrument.priceScale, 'en').replace(/,/g, '') : '');
  const riskMinor = risk.trim() === '' ? null : parseToMinor(risk, instrument.priceScale);
  const journal: Schemas['TradeNote'] | null =
    why.trim() || marketState || mood || riskMinor
      ? { why: why.trim() || null, marketState, mood, plannedRisk: riskMinor && riskMinor > 0 ? riskMinor : null }
      : null;
  const best = side === 'BUY' ? book?.asks[0]?.price : book?.bids[0]?.price;

  // Zod checks the text fields; amounts become integer minor units, never floats.
  const schema = z
    .object({ type: z.enum(['LIMIT', 'MARKET']), price: z.string(), qty: z.string() })
    .superRefine((v, ctx) => {
      if (v.type === 'LIMIT' && parseToMinor(v.price, instrument.priceScale) === null) ctx.addIssue({ code: 'custom', path: ['price'], message: 'ticket.errPrice' });
      if (parseToMinor(v.qty, instrument.qtyScale) === null) ctx.addIssue({ code: 'custom', path: ['qty'], message: 'ticket.errQty' });
    });
  const { control, watch, handleSubmit, formState, setError } = useForm<Form>({
    defaultValues: { type: 'LIMIT', price: best ? formatMinor(best, instrument.priceScale, 'en').replace(/,/g, '') : '', qty: '1' },
  });
  const v = watch();
  const priceMinor = v.type === 'LIMIT' ? parseToMinor(v.price, instrument.priceScale) : best ?? null;
  const qty = parseToMinor(v.qty, instrument.qtyScale);
  const notional = priceMinor && qty ? priceMinor * qty : null;
  const fee = notional !== null ? Math.floor((notional * instrument.feeBps) / 10_000) : null;
  const money = (m: number) => `${formatMinor(m, instrument.priceScale, i18n.language)} ${instrument.quote}`;

  const place = useMutation({
    mutationFn: (f: Form) =>
      call(
        api.POST('/orders', {
          params: { header: { 'Idempotency-Key': `${Date.now()}-${Math.random().toString(36).slice(2)}` } },
          body: {
            instrument: instrument.id,
            side,
            type: f.type,
            qty: parseToMinor(f.qty, instrument.qtyScale)!,
            ...(f.type === 'LIMIT' ? { price: parseToMinor(f.price, instrument.priceScale)! } : {}),
            ...(journal ? { journal } : {}),
          },
        }),
      ),
    onSuccess: (o) => {
      setResult({ ok: true, text: t('ticket.placed', { id: o.orderId, status: t(`status.${o.status}`) }) });
      void qc.invalidateQueries({ queryKey: ['me'] });
      void qc.invalidateQueries({ queryKey: ['orders'] });
      void qc.invalidateQueries({ queryKey: ['session-review'] });
    },
    onError: (e) => setResult({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`) }),
  });

  const submit = handleSubmit((f) => {
    if (risk.trim() !== '' && !(riskMinor && riskMinor > 0)) {
      setResult({ ok: false, text: t('journal.errRisk') });
      return;
    }
    const parsed = schema.safeParse(f);
    if (!parsed.success) {
      parsed.error.issues.forEach((i) => setError(i.path[0] as keyof Form, { message: i.message }));
      return;
    }
    place.mutate(f);
  });

  const input = { borderWidth: 1, borderColor: c.border, borderRadius: radius.sm, padding: 12, fontSize: 17, color: c.textPrimary, backgroundColor: c.surface, fontVariant: ['tabular-nums' as const] };
  const sideColor = side === 'BUY' ? c.bid : c.ask;

  return (
    <Modal transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={{ flex: 1, backgroundColor: 'rgba(5,9,12,0.45)' }} onPress={onClose} />
      <View style={{ backgroundColor: c.surface, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, maxHeight: '90%' }} testID="order-ticket">
      <ScrollView contentContainerStyle={{ padding: 20, gap: 12 }} keyboardShouldPersistTaps="handled">
        <Title>{t(side === 'BUY' ? 'ticket.titleBuy' : 'ticket.titleSell', { base: instrument.base })}</Title>
        <Controller
          control={control}
          name="type"
          render={({ field }) => (
            <Segmented testIDPrefix="ticket-type" value={field.value} onChange={field.onChange} options={[{ value: 'LIMIT', label: t('ticket.limit') }, { value: 'MARKET', label: t('ticket.market') }]} />
          )}
        />
        {v.type === 'LIMIT' ? (
          <View style={{ gap: 4 }}>
            <Caption>{t('ticket.price', { quote: instrument.quote })}</Caption>
            <Controller control={control} name="price" render={({ field }) => <TextInput testID="ticket-price" style={input} keyboardType="decimal-pad" value={field.value} onChangeText={field.onChange} />} />
            {formState.errors.price?.message && <Caption color={c.negative}>{t(formState.errors.price.message)}</Caption>}
          </View>
        ) : (
          <Caption>{t('ticket.marketHint')}</Caption>
        )}
        <View style={{ gap: 4 }}>
          <Caption>{t('ticket.qty', { base: instrument.base })}</Caption>
          <Controller control={control} name="qty" render={({ field }) => <TextInput testID="ticket-qty" style={input} keyboardType="number-pad" value={field.value} onChangeText={field.onChange} />} />
          {formState.errors.qty?.message && <Caption color={c.negative}>{t(formState.errors.qty.message)}</Caption>}
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Caption>{t('ticket.total')}</Caption>
          <Body num>{notional !== null ? `≈ ${money(notional)}` : '—'}</Body>
        </View>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Caption>{t('ticket.fee')} · {(instrument.feeBps / 100).toLocaleString(i18n.language)}%</Caption>
          <Body num>{fee !== null ? `≈ ${money(fee)}` : '—'}</Body>
        </View>
        <View style={{ gap: 8, borderTopWidth: 1, borderTopColor: c.border, paddingTop: 10 }} testID="ticket-journal">
          <Body bold>{t('journal.title')}</Body>
          <Caption>{t('journal.hint')}</Caption>
          <Caption>{t('journal.why')}</Caption>
          <TextInput testID="journal-why" style={[input, { fontSize: 15, minHeight: 64, textAlignVertical: 'top' }]} multiline maxLength={WHY_MAX} value={why} onChangeText={setWhy} placeholder={t('journal.whyPlaceholder')} placeholderTextColor={c.textSecondary} />
          <Caption>{`${why.length}/${WHY_MAX}`}</Caption>
          <Caption>{t('journal.marketState')}</Caption>
          <Chips testIDPrefix="journal-state" value={marketState} onChange={setMarketState} options={MARKET_STATES.map((m) => ({ value: m, label: t(`marketState.${m}`) }))} />
          <Caption>{t('journal.mood')}</Caption>
          <Chips testIDPrefix="journal-mood" value={mood} onChange={setMood} options={MOODS.map((m) => ({ value: m, label: t(`mood.${m}`) }))} />
          <Caption>{t('journal.plannedRisk', { quote: instrument.quote })}</Caption>
          <TextInput testID="journal-risk" style={input} keyboardType="decimal-pad" value={risk} onChangeText={setRisk} />
          <Caption>{t(plannedRisk ? 'journal.riskFromHelper' : 'journal.riskHint')}</Caption>
        </View>
        {result && (
          <Text testID="ticket-result" style={{ color: result.ok ? c.positive : c.negative, fontWeight: '600' }}>
            {result.text}
          </Text>
        )}
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Button testID="ticket-close" title={t('ticket.close')} onPress={onClose} color={c.textSecondary} />
          <Button testID="ticket-submit" title={t('ticket.cta')} onPress={submit} color={sideColor} disabled={place.isPending} />
        </View>
        <Caption>{t('app.notAdvice')}</Caption>
      </ScrollView>
      </View>
    </Modal>
  );
}
