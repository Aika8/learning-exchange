import { memo, useCallback } from 'react';
import { Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { BookSnapshot, Instrument } from '../api/client';
import { formatMinor } from '../money';
import { useColors, useDepthTints } from '../theme/theme';
import { Caption } from './ui';

type Level = BookSnapshot['bids'][number];

/** Design S03: asks above (▼, ask colour), spread indicator, bids below (▲, bid colour); bars show depth. */
export function OrderBook({ book, instrument, depth = 6 }: { book: BookSnapshot; instrument: Instrument; depth?: number }) {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const asks = book.asks.slice(0, depth).reverse();
  const bids = book.bids.slice(0, depth);
  const max = Math.max(1, ...asks.map((l) => l.qty), ...bids.map((l) => l.qty));
  const bestBid = book.bids[0]?.price;
  const bestAsk = book.asks[0]?.price;
  // Stable formatter: the memoised rows re-render only when their level changes (M4 performance).
  const fmt = useCallback((p: number) => formatMinor(p, instrument.priceScale, i18n.language), [instrument.priceScale, i18n.language]);
  const spread = bestBid !== undefined && bestAsk !== undefined ? bestAsk - bestBid : null;
  const spreadPct = spread !== null && bestAsk ? ((spread * 10000) / bestAsk / 100).toLocaleString(i18n.language, { maximumFractionDigits: 2 }) : null;

  return (
    <View testID="order-book">
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 4 }}>
        <Caption>{t('instrument.book')}</Caption>
        <Caption>{t('instrument.qty')}</Caption>
      </View>
      {asks.map((l) => (
        <Row key={`a${l.price}`} level={l} max={max} side="ask" fmt={fmt} />
      ))}
      <View style={{ paddingVertical: 6, alignItems: 'center', borderTopWidth: 1, borderBottomWidth: 1, borderColor: c.border, marginVertical: 2 }}>
        <Text style={{ color: c.spread, fontWeight: '600', fontVariant: ['tabular-nums'] }} testID="spread">
          {t('instrument.spread')} {spread === null ? '—' : `${fmt(spread)} · ${spreadPct}%`}
        </Text>
      </View>
      {bids.map((l) => (
        <Row key={`b${l.price}`} level={l} max={max} side="bid" fmt={fmt} />
      ))}
    </View>
  );
}

const Row = memo(function Row({ level, max, side, fmt }: { level: Level; max: number; side: 'bid' | 'ask'; fmt: (p: number) => string }) {
  const c = useColors();
  const tint = useDepthTints();
  const color = side === 'bid' ? c.bid : c.ask;
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 3, paddingHorizontal: 4 }} testID={`${side}-row`}>
      <View style={{ position: 'absolute', right: 0, top: 1, bottom: 1, width: `${(level.qty / max) * 100}%`, backgroundColor: side === 'bid' ? tint.bidBg : tint.askBg, borderRadius: 4 }} />
      <Text style={{ color, fontVariant: ['tabular-nums'], fontWeight: '500' }}>
        {side === 'bid' ? '▲' : '▼'} {fmt(level.price)}
      </Text>
      <Text style={{ color: c.textPrimary, fontVariant: ['tabular-nums'] }}>{level.qty}</Text>
    </View>
  );
});
