import { Pressable, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, call, type Instrument, type Schemas } from '../api/client';
import { refetchAccount, useConditionalOrders } from '../hooks';
import { formatMinor } from '../money';
import { radius, useColors } from '../theme/theme';
import { Body, Caption, Card } from './ui';

type Cond = Schemas['ConditionalOrder'];
const FIRED = new Set(['TRIGGERED', 'SUBMITTED', 'PARTIALLY_FILLED', 'FILLED', 'UNFILLED', 'REJECTED']);

/** My stops and take-profits for one instrument. A fired rule shows what it fired at and how much of its order filled. */
export function StopsList({ instrument }: { instrument: Instrument }) {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const list = (useConditionalOrders().data ?? []).filter((o) => o.instrument === instrument.id).slice(0, 8);
  const cancel = useMutation({
    mutationFn: (id: number) => call(api.DELETE('/conditional-orders/{conditionalId}', { params: { path: { conditionalId: id } } })),
    onSettled: () => refetchAccount(qc),
  });
  const fmt = (p: number) => formatMinor(p, instrument.priceScale, i18n.language);
  const stateColor = (o: Cond) =>
    o.state === 'FILLED' ? c.positive : o.state === 'REJECTED' || o.state === 'UNFILLED' ? c.negative : FIRED.has(o.state) ? c.accent : c.textSecondary;

  const levels = (o: Cond) => {
    const parts: string[] = [];
    if (o.kind !== 'TRAILING_TP') parts.push(`${t('stops.triggerShort')} ${fmt(o.triggerPrice)}`);
    if (o.kind === 'STOP_LIMIT' || (o.kind === 'TP_SL' && o.limitPrice > 0)) parts.push(`${t('stops.limitShort')} ${fmt(o.limitPrice)}`);
    if (o.kind === 'TRAILING_TP' || o.kind === 'TP_SL') parts.push(`${t('stops.tpShort')} ${fmt(o.activationPrice)} −${fmt(o.offset)}`);
    return parts.join(' · ');
  };

  return (
    <Card style={{ gap: 10 }}>
      {list.length === 0 && <Caption>{t('stops.none')}</Caption>}
      {list.map((o) => (
        <View key={o.conditionalId} testID={`stop-${o.conditionalId}`} style={{ gap: 2, borderBottomWidth: 1, borderBottomColor: c.border, paddingBottom: 8 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
            <Body bold color={o.side === 'BUY' ? c.bid : c.ask}>
              {o.side === 'BUY' ? '▲' : '▼'} {t(`ckind.${o.kind}`)} · {o.qty}
            </Body>
            <View style={{ backgroundColor: c.surfaceAlt, borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2 }}>
              <Caption color={stateColor(o)} testID={`stop-state-${o.conditionalId}`}>{t(`cstate.${o.state}`)}</Caption>
            </View>
          </View>
          <Caption>{levels(o)}</Caption>
          {o.triggerTradePrice != null && (
            <Caption color={c.textPrimary}>
              {t('stops.firedAt', { price: fmt(o.triggerTradePrice) })}
              {o.orderId != null ? ` · ${t('stops.order', { id: o.orderId })}` : ''} · {t('stops.filled', { filled: o.filledQty ?? 0, qty: o.qty })}
            </Caption>
          )}
          {FIRED.has(o.state) && o.state !== 'FILLED' && <Caption color={c.accent}>{t('stops.firedNotFilled')}</Caption>}
          {o.rejection && <Caption color={c.negative}>{t(`errors.${o.rejection}`, { defaultValue: o.rejection })}</Caption>}
          {(o.state === 'WAITING' || o.state === 'ARMED') && (
            <Pressable testID={`stop-cancel-${o.conditionalId}`} onPress={() => cancel.mutate(o.conditionalId)} hitSlop={8} style={{ alignSelf: 'flex-end' }}>
              <Text style={{ color: c.primary, fontWeight: '600' }}>{t('instrument.cancel')}</Text>
            </Pressable>
          )}
        </View>
      ))}
    </Card>
  );
}
