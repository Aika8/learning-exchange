import { useState } from 'react';
import { Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, call } from '../api/client';
import { refetchAccount, useInstrument, useLiveMarket, useMe } from '../hooks';
import { bpsToPercent, fxQuote, spreadInfo } from '../finance';
import { formatMinor, parseToMinor } from '../money';
import { type as typo, useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Segmented, Title } from '../components/ui';
import { Field, Line } from '../components/Field';
import { TabBar } from '../components/TabBar';

const FX = 'AMBER-SPARK';

/** Currency exchange AMBER/SPARK: buy and sell rates from the book, spread and mid, cost of a market order before sending. */
export default function FxScreen() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const inst = useInstrument(FX).data;
  const { book } = useLiveMarket(FX);
  const me = useMe().data;
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');
  const [amount, setAmount] = useState('10');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const bid = book?.bids[0]?.price;
  const ask = book?.asks[0]?.price;
  const s = bid && ask ? spreadInfo(bid, ask) : null;
  const ps = inst?.priceScale ?? 2;
  const qty = parseToMinor(amount, inst?.qtyScale ?? 0);
  const q = bid && ask && qty && inst ? fxQuote(side, qty, bid, ask, inst.feeBps) : null;
  const dec = i18n.language.startsWith('ru') ? ',' : '.';
  const rate = (m?: number) => (m ? formatMinor(m, ps, i18n.language) : '—');
  const money = (m: number) => `${formatMinor(m, ps, i18n.language)} SPARK`;
  const bal = (a: string) => me?.balances.find((b) => b.asset === a)?.available;

  const send = useMutation({
    mutationFn: () =>
      call(
        api.POST('/orders', {
          params: { header: { 'Idempotency-Key': `${Date.now()}-${Math.random().toString(36).slice(2)}` } },
          body: { instrument: FX, side, type: 'MARKET', qty: qty! },
        }),
      ),
    onSuccess: (o) => {
      setMsg({ ok: true, text: t('ticket.placed', { id: o.orderId, status: t(`status.${o.status}`) }) });
      refetchAccount(qc);
    },
    onError: (e) => setMsg({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`, { defaultValue: t('errors.BAD_REQUEST') }) }),
  });

  const big = { fontSize: typo.numericLarge.size, lineHeight: typo.numericLarge.lineHeight, fontWeight: '600' as const, fontVariant: ['tabular-nums' as const] };
  return (
    <Screen footer={<TabBar />}>
      <Title>{t('fx.title')}</Title>
      <Caption>{t('fx.pair')}</Caption>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Card style={{ flex: 1, gap: 2 }}>
          <Caption>{t('fx.buyRate')}</Caption>
          <Text testID="fx-ask" style={[big, { color: c.bid }]}>{rate(ask)}</Text>
          <Caption>{t('fx.buyRateHint')}</Caption>
        </Card>
        <Card style={{ flex: 1, gap: 2 }}>
          <Caption>{t('fx.sellRate')}</Caption>
          <Text testID="fx-bid" style={[big, { color: c.ask }]}>{rate(bid)}</Text>
          <Caption>{t('fx.sellRateHint')}</Caption>
        </Card>
      </View>
      <Card style={{ gap: 4 }}>
        <Line label={t('fx.mid')} value={s ? `${rate(s.mid)} SPARK` : '—'} />
        <Line label={t('fx.spread')} value={s ? `${rate(s.spread)} SPARK · ${bpsToPercent(s.spreadBps, dec)}%` : '—'} testID="fx-spread" />
        <Caption>{t('fx.dealerIncome')}</Caption>
      </Card>
      <Card style={{ gap: 10 }}>
        <Segmented testIDPrefix="fx-side" value={side} onChange={setSide} options={[{ value: 'BUY', label: t('fx.buy') }, { value: 'SELL', label: t('fx.sell') }]} />
        <Field testID="fx-amount" label={t('fx.amount')} value={amount} onChange={setAmount} hint={t('fx.have', { amber: bal('AMBER') ?? 0, spark: money(bal('SPARK') ?? 0) })} />
        {q ? (
          <View style={{ gap: 4 }}>
            <Line label={t('fx.price')} value={`${rate(q.price)} SPARK`} />
            <Line label={t('fx.notional')} value={money(q.notional)} />
            <Line label={`${t('ticket.fee')} · ${inst ? bpsToPercent(inst.feeBps, dec) : ''}%`} value={money(q.fee)} />
            <Line label={t('fx.spreadCost')} value={money(q.spreadCost)} color={c.negative} testID="fx-spread-cost" />
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body bold>{t(side === 'BUY' ? 'fx.totalPay' : 'fx.totalGet')}</Body>
              <Body bold num>
                ≈ {money(q.total)}
              </Body>
            </View>
            <Caption>{t('fx.marketNote')}</Caption>
          </View>
        ) : (
          <Caption>{t('fx.fill')}</Caption>
        )}
        {msg && (
          <Text testID="fx-result" style={{ color: msg.ok ? c.positive : c.negative, fontWeight: '600' }}>
            {msg.text}
          </Text>
        )}
        <View style={{ flexDirection: 'row' }}>
          <Button testID="fx-submit" title={t(side === 'BUY' ? 'fx.ctaBuy' : 'fx.ctaSell')} color={side === 'BUY' ? c.bid : c.ask} disabled={!q || send.isPending} onPress={() => send.mutate()} />
        </View>
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
