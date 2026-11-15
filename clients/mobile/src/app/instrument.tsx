import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, call } from '../api/client';
import { useInstrument, useLiveMarket, useMe, useOpenOrders } from '../hooks';
import { formatMinor } from '../money';
import { type as typo, useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Segmented, Title } from '../components/ui';
import { PositionSize } from '../components/PositionSize';
import { StopsList } from '../components/StopsList';
import { StopTicket } from '../components/StopTicket';
import { OrderBook } from '../components/OrderBook';
import { OrderTicket } from '../components/OrderTicket';
import { TabBar } from '../components/TabBar';

/** Design S03 (instrument): instrument switch, last price, order book with spread, stops and take-profits, position-size helper, trades tape, Buy/Sell opening the ticket (S04). */
export default function InstrumentScreen() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const [instrumentId, setInstrumentId] = useState<'SILK-SPARK' | 'AMBER-SPARK'>('SILK-SPARK');
  const instrument = useInstrument(instrumentId).data;
  const { book, trades } = useLiveMarket(instrumentId);
  const orders = (useOpenOrders().data ?? []).filter((o) => o.instrument === instrumentId);
  const spark = useMe().data?.balances.find((b) => b.asset === 'SPARK');
  const [ticket, setTicket] = useState<'BUY' | 'SELL' | null>(null);
  const [stopTicket, setStopTicket] = useState<{ qty?: string; trigger?: string; side?: 'BUY' | 'SELL' } | null>(null);
  const qc = useQueryClient();
  const cancel = useMutation({
    mutationFn: (id: number) => call(api.DELETE('/orders/{orderId}', { params: { path: { orderId: id } } })),
    onSettled: () => {
      void qc.invalidateQueries({ queryKey: ['orders'] });
      void qc.invalidateQueries({ queryKey: ['me'] });
    },
  });
  if (!instrument) return <Screen footer={<TabBar />}>{null}</Screen>;
  const fmt = (p: number) => formatMinor(p, instrument.priceScale, i18n.language);
  const time = new Intl.DateTimeFormat(i18n.language, { hour: '2-digit', minute: '2-digit', second: '2-digit' });

  return (
    <Screen
      footer={
        <>
          <View style={{ flexDirection: 'row', gap: 8, padding: 12, backgroundColor: c.bg }}>
            <Button testID="buy" title={t('instrument.buy')} color={c.bid} onPress={() => setTicket('BUY')} />
            <Button testID="sell" title={t('instrument.sell')} color={c.ask} onPress={() => setTicket('SELL')} />
          </View>
          <TabBar />
        </>
      }
    >
      <Segmented
        testIDPrefix="instrument"
        value={instrumentId}
        onChange={setInstrumentId}
        options={[
          { value: 'SILK-SPARK', label: t('instrument.stock') },
          { value: 'AMBER-SPARK', label: t('instrument.fx') },
        ]}
      />
      <Caption>
        {t(instrumentId === 'AMBER-SPARK' ? 'instrument.kindFx' : 'instrument.kind')} · {instrument.base}/{instrument.quote}
      </Caption>
      <Text testID="last-price" style={{ fontSize: typo.display.size, lineHeight: typo.display.lineHeight, fontWeight: '700', color: c.textPrimary, fontVariant: ['tabular-nums'] }}>
        {book?.lastPrice != null ? `${fmt(book.lastPrice)} ${instrument.quote}` : '—'}
      </Text>
      <Caption>{t('instrument.last')}</Caption>
      <Card>{book && <OrderBook book={book} instrument={instrument} />}</Card>
      <Title>{t('instrument.myOrders')}</Title>
      <Card style={{ gap: 8 }}>
        {orders.length === 0 && <Caption>{t('instrument.noOrders')}</Caption>}
        {orders.map((o) => (
          <View key={o.orderId} testID={`my-order-${o.orderId}`} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
            <Body color={o.side === 'BUY' ? c.bid : c.ask} num>
              {o.side === 'BUY' ? '▲' : '▼'} {o.remainingQty} × {fmt(o.price)}
            </Body>
            <Caption>{t(`status.${o.status}`)}</Caption>
            <Pressable testID={`cancel-${o.orderId}`} onPress={() => cancel.mutate(o.orderId)} hitSlop={8}>
              <Text style={{ color: c.primary, fontWeight: '600' }}>{t('instrument.cancel')}</Text>
            </Pressable>
          </View>
        ))}
      </Card>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
        <Title>{t('stops.title')}</Title>
        <Pressable testID="stop-new" onPress={() => setStopTicket({})} hitSlop={8}>
          <Text style={{ color: c.primary, fontWeight: '600' }}>{t('stops.new')}</Text>
        </Pressable>
      </View>
      <StopsList instrument={instrument} />
      <PositionSize instrument={instrument} capital={spark?.available} lastPrice={book?.lastPrice} onUse={(qty, trigger, side) => setStopTicket({ qty, trigger, side })} />
      <Title>{t('instrument.tape')}</Title>
      <Card style={{ gap: 4 }}>
        {trades.length === 0 && <Caption>{t('instrument.noTrades')}</Caption>}
        {trades.slice(0, 8).map((tr) => (
          <View key={tr.tradeId} style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <Caption>{time.format(tr.ts)}</Caption>
            <Body num color={tr.aggressorSide === 'BUY' ? c.bid : c.ask}>
              {fmt(tr.price)}
            </Body>
            <Body num>{tr.qty}</Body>
          </View>
        ))}
      </Card>
      {stopTicket && <StopTicket key={instrumentId} instrument={instrument} initial={stopTicket} onClose={() => setStopTicket(null)} />}
      {ticket && <OrderTicket key={instrumentId} side={ticket} instrument={instrument} book={book} onClose={() => setTicket(null)} />}
    </Screen>
  );
}
