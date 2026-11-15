import { useState } from 'react';
import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { scaleCandles } from '../m2b';
import { useColors } from '../theme/theme';
import { Caption } from './ui';
import { useFmt } from './format';

const HEIGHT = 140;

export type DividendMarkKind = 'ex' | 'record' | 'pay';
export type DividendMark = { at: number; perShare: number; kind: DividendMarkKind };

/**
 * Daily candles drawn with plain Views (no chart library), with dividend dates marked as vertical lines:
 * ex-date (the cut-off: from that open the share trades without the dividend), record date and pay date.
 */
export function PriceChart({ candles, exDates, priceScale }: { candles: Schemas['Candle'][]; exDates: DividendMark[]; priceScale: number }) {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const [width, setWidth] = useState(0);
  const { bars, min, max, xOf } = scaleCandles(candles, width, HEIGHT);
  const marks = exDates.map((e) => ({ ...e, x: xOf(e.at) })).filter((e): e is DividendMark & { x: number } => e.x !== null);
  const color = (k: DividendMarkKind) => (k === 'ex' ? c.info : k === 'record' ? c.warning : c.positive);
  if (candles.length === 0) return <Caption>{t('chart.empty')}</Caption>;
  return (
    <View style={{ gap: 4 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Caption>{f.money(max, priceScale)}</Caption>
        <Caption>{t('chart.days', { count: candles.length })}</Caption>
      </View>
      <View testID="price-chart" onLayout={(e) => setWidth(e.nativeEvent.layout.width)} style={{ height: HEIGHT, position: 'relative' }}>
        {bars.map((b, i) => {
          const color = b.up ? c.positive : c.negative;
          const body = Math.max(1, b.bodyBottom - b.bodyTop);
          return (
            <View key={i} style={{ position: 'absolute', left: b.x, width: b.width, top: 0, height: HEIGHT, alignItems: 'center' }}>
              <View style={{ position: 'absolute', top: b.top, height: Math.max(1, b.bottom - b.top), width: 1, backgroundColor: color }} />
              <View style={{ position: 'absolute', top: b.bodyTop, height: body, width: Math.max(1, b.width * 0.6), backgroundColor: color }} />
            </View>
          );
        })}
        {marks.map((m) => (
          <View key={`${m.kind}-${m.at}`} testID={`${m.kind}date-mark`} style={{ position: 'absolute', left: m.x, top: 0, height: HEIGHT, width: 0, borderLeftWidth: m.kind === 'ex' ? 2 : 1, borderStyle: m.kind === 'ex' ? 'solid' : 'dashed', borderColor: color(m.kind) }}>
            <View style={{ position: 'absolute', top: m.kind === 'ex' ? 0 : m.kind === 'record' ? 18 : 36, left: 2, backgroundColor: color(m.kind), borderRadius: 4, paddingHorizontal: 3 }}>
              <Caption color={c.onPrimary}>{t(`chart.${m.kind}Short`)}</Caption>
            </View>
          </View>
        ))}
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Caption>{f.money(min, priceScale)}</Caption>
        <Caption>{f.date(candles[candles.length - 1]?.start ?? 0)}</Caption>
      </View>
      {marks.map((m) => (
        <Caption key={`${m.kind}-${m.at}`} color={color(m.kind)}>
          {t(`chart.${m.kind}Date`, { date: f.when(m.at), amount: f.money(m.perShare, priceScale) })}
        </Caption>
      ))}
    </View>
  );
}
