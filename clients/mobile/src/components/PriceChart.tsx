import { useState } from 'react';
import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { scaleCandles } from '../m2b';
import { useColors } from '../theme/theme';
import { Caption } from './ui';
import { useFmt } from './format';

const HEIGHT = 140;

/** Daily candles drawn with plain Views (no chart library), with dividend ex-dates marked as vertical lines. */
export function PriceChart({ candles, exDates, priceScale }: { candles: Schemas['Candle'][]; exDates: { at: number; perShare: number }[]; priceScale: number }) {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const [width, setWidth] = useState(0);
  const { bars, min, max, xOf } = scaleCandles(candles, width, HEIGHT);
  const marks = exDates.map((e) => ({ ...e, x: xOf(e.at) })).filter((e): e is { at: number; perShare: number; x: number } => e.x !== null);
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
          <View key={m.at} testID="exdate-mark" style={{ position: 'absolute', left: m.x, top: 0, height: HEIGHT, width: 0, borderLeftWidth: 1, borderStyle: 'dashed', borderColor: c.info }}>
            <View style={{ position: 'absolute', top: 0, left: 2, backgroundColor: c.info, borderRadius: 4, paddingHorizontal: 3 }}>
              <Caption color={c.onPrimary}>{t('chart.exShort')}</Caption>
            </View>
          </View>
        ))}
      </View>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Caption>{f.money(min, priceScale)}</Caption>
        <Caption>{f.date(candles[candles.length - 1]?.start ?? 0)}</Caption>
      </View>
      {marks.map((m) => (
        <Caption key={m.at} color={c.info}>
          {t('chart.exDate', { date: f.when(m.at), amount: f.money(m.perShare, priceScale) })}
        </Caption>
      ))}
    </View>
  );
}
