import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, call, type Schemas } from '../api/client';
import { usePaperPositions, useRealWorld } from '../hooks';
import { newIdempotencyKey } from '../m2b';
import { parseToMinor } from '../money';
import { radius, useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Segmented, Title } from '../components/ui';
import { Field, Line } from '../components/Field';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

/** «Real world» tab (M2b, ADR-0015): real quotes with source and time, the base rate, paper («учебные») positions. */
export default function RealWorldScreen() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const qc = useQueryClient();
  const real = useRealWorld();
  const paper = usePaperPositions().data ?? [];
  const quotes = real.data?.quotes ?? [];
  const base = real.data?.baseRate;
  const [symbol, setSymbol] = useState<string | null>(null);
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');
  const [qty, setQty] = useState('1');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const sym = symbol ?? quotes[0]?.symbol ?? null;
  const scaleOf = (s: string) => quotes.find((q) => q.symbol === s)?.scale ?? 2;
  const curOf = (s: string) => quotes.find((q) => q.symbol === s)?.quoteCurrency ?? '';
  const err = (e: unknown) => setMsg({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`, { defaultValue: t('errors.BAD_REQUEST') }) });
  const refresh = () => void qc.invalidateQueries({ queryKey: ['paper'] });

  const open = useMutation({
    mutationFn: (b: Schemas['OpenPaperRequest']) => call(api.POST('/real-world/paper-positions', { params: { header: { 'Idempotency-Key': newIdempotencyKey() } }, body: b })),
    onSuccess: (p) => {
      setMsg({ ok: true, text: t('real.opened', { id: p.paperId }) });
      refresh();
    },
    onError: err,
  });
  const close = useMutation({
    mutationFn: (id: number) => call(api.POST('/real-world/paper-positions/{paperId}/close', { params: { path: { paperId: id } } })),
    onSuccess: refresh,
    onError: err,
  });

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('real.title')}</Title>
      <Caption>{t('real.subtitle')}</Caption>
      {real.error && <Caption color={c.negative}>{t('errors.NETWORK')}</Caption>}
      {quotes.map((q) => (
        <Card key={q.symbol} style={{ gap: 4 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
            <Body bold>{q.symbol}</Body>
            {q.source.sample && <Badge text={t('real.sample')} color={c.warning} />}
          </View>
          <Text testID={`quote-${q.symbol}`} style={{ fontSize: 24, fontWeight: '600', color: c.textPrimary, fontVariant: ['tabular-nums'] }}>
            {f.money(q.price, q.scale, q.quoteCurrency)}
          </Text>
          <Caption>{t('real.source', { source: q.source.name, time: f.when(q.asOf) })}</Caption>
          {q.source.delayed && <Caption>{t('real.delayed')}</Caption>}
        </Card>
      ))}
      {base && (
        <Card style={{ gap: 6 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
            <Body bold>{t('real.baseRate', { bank: base.bank })}</Body>
            {base.source.sample && <Badge text={t('real.sample')} color={c.warning} />}
          </View>
          <Text testID="real-base-rate" style={{ fontSize: 24, fontWeight: '600', color: c.textPrimary }}>
            {f.pct(base.rateBps)}
          </Text>
          <Caption>{t('real.source', { source: base.source.name, time: f.date(base.asOf) })}</Caption>
          <Caption>{t('real.decisions')}</Caption>
          {base.history
            .slice()
            .sort((a, b) => b.date - a.date)
            .slice(0, 6)
            .map((d) => (
              <Line key={d.date} label={f.date(d.date)} value={f.pct(d.rateBps)} />
            ))}
          {base.upcoming.length > 0 && <Caption>{t('real.upcoming', { dates: base.upcoming.map((d) => f.date(d)).join(', ') })}</Caption>}
        </Card>
      )}

      <Title>{t('real.paperTitle')}</Title>
      <Caption>{t('real.paperHint')}</Caption>
      <Card style={{ gap: 10 }}>
        {paper.length === 0 && <Caption>{t('real.noPaper')}</Caption>}
        {paper.map((p) => {
          const sc = scaleOf(p.symbol);
          const cur = curOf(p.symbol);
          return (
            <View key={p.paperId} testID={`paper-${p.paperId}`} style={{ gap: 2 }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                <Badge text={t('real.paperBadge')} color={c.accent} />
                <Caption>{t(p.open ? 'real.open' : 'real.closed')}</Caption>
              </View>
              <Body bold>
                {p.symbol} · {t(p.side === 'BUY' ? 'real.long' : 'real.short')} · {p.qty}
              </Body>
              <Line label={t('real.entry')} value={f.money(p.entryPrice, sc, cur)} />
              <Line label={t(p.open ? 'real.current' : 'real.exit')} value={f.money(p.exitPrice ?? p.currentPrice, sc, cur)} />
              <Line label={t('real.pnl')} value={`${p.pnl > 0 ? '+' : ''}${f.money(p.pnl, sc, cur)}`} color={p.pnl >= 0 ? c.positive : c.negative} testID={`paper-pnl-${p.paperId}`} />
              <Caption>{t('real.quoted', { source: p.source, time: f.when(p.quotedAt) })}</Caption>
              {p.open && (
                <Pressable testID={`paper-close-${p.paperId}`} onPress={() => close.mutate(p.paperId)} hitSlop={8} style={{ alignSelf: 'flex-end' }}>
                  <Text style={{ color: c.primary, fontWeight: '600' }}>{t('real.close')}</Text>
                </Pressable>
              )}
            </View>
          );
        })}
      </Card>
      {quotes.length > 0 && sym && (
        <Card style={{ gap: 10 }}>
          <Body bold>{t('real.openTitle')}</Body>
          <Segmented value={sym} onChange={setSymbol} options={quotes.map((q) => ({ value: q.symbol, label: q.symbol }))} testIDPrefix="paper-symbol" />
          <Segmented
            value={side}
            onChange={setSide}
            testIDPrefix="paper-side"
            options={[
              { value: 'BUY', label: t('real.long') },
              { value: 'SELL', label: t('real.short') },
            ]}
          />
          <Field testID="paper-qty" label={t('real.qty')} value={qty} onChange={setQty} />
          {msg && <Text style={{ color: msg.ok ? c.positive : c.negative, fontWeight: '600' }}>{msg.text}</Text>}
          <View style={{ flexDirection: 'row' }}>
            <Button
              testID="paper-open"
              title={t('real.openButton')}
              disabled={open.isPending}
              onPress={() => {
                const q = parseToMinor(qty, 0);
                if (q === null) return setMsg({ ok: false, text: t('errors.INVALID_AMOUNT') });
                open.mutate({ symbol: sym, side, qty: q });
              }}
            />
          </View>
        </Card>
      )}
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}

function Badge({ text, color }: { text: string; color: string }) {
  const c = useColors();
  return (
    <View style={{ borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2, borderWidth: 1, borderColor: color, backgroundColor: c.surface }}>
      <Caption color={color}>{text}</Caption>
    </View>
  );
}
