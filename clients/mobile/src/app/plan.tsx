import { useMemo, useState } from 'react';
import { View } from 'react-native';
import { useQueries } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { api, call } from '../api/client';
import { useCandles, useClock, useInstruments, useMe, useSavings } from '../hooks';
import { drifts, lumpVsDca, rebalanceDue } from '../m4';
import { parseToMinor } from '../money';
import { usePlan } from '../store/plan';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Chips, Screen, Segmented, Title } from '../components/ui';
import { Field, Line } from '../components/Field';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

const DCA_INSTRUMENTS = ['IDX-SPARK', 'SILK-SPARK', 'FORGE-SPARK'] as const;

/**
 * My plan (M4): the rebalancing reminder (twice a year, when a share drifted more than 5 p.p. from my target) and the
 * lump sum vs DCA calculator over every start in the price history. Both describe; neither advises.
 */
export default function PlanScreen() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const me = useMe().data;
  const instruments = useInstruments().data ?? [];
  const clock = useClock().data;
  const dayMillis = useSavings().data?.product.dayMillis ?? 60_000;
  const { targetsBps, lastCheck, setTarget, markChecked } = usePlan();

  // Portfolio value per asset in SPARK minor units: cash + each holding × its last price.
  const held = (me?.balances ?? []).filter((b) => b.asset !== 'SPARK' && b.available + b.reserved > 0);
  const priced = held.map((b) => instruments.find((i) => i.id === `${b.asset}-SPARK`)).filter((i) => i != null);
  const books = useQueries({
    queries: priced.map((i) => ({
      queryKey: ['book1', i.id],
      queryFn: () => call(api.GET('/instruments/{instrumentId}/book', { params: { path: { instrumentId: i.id }, query: { depth: 1 } } })),
      staleTime: 10_000,
    })),
  });
  const values = useMemo(() => {
    const out: Record<string, number> = {};
    const cash = me?.balances.find((b) => b.asset === 'SPARK');
    if (cash) out.SPARK = cash.available + cash.reserved;
    priced.forEach((i, n) => {
      const last = books[n]?.data?.lastPrice;
      const b = held.find((x) => `${x.asset}-SPARK` === i.id);
      if (last != null && b) out[b.asset] = Math.floor(((b.available + b.reserved) * last) / 10 ** i.qtyScale);
    });
    return out;
  }, [me, books.map((b) => b.data?.lastPrice).join(','), instruments.length]); // eslint-disable-line react-hooks/exhaustive-deps

  const total = Object.values(values).reduce((s, v) => s + v, 0);
  const due = clock ? rebalanceDue(lastCheck, clock.now, dayMillis) : false;
  const drifted = drifts(values, targetsBps);
  const hasTargets = Object.keys(targetsBps).length > 0;

  // Lump sum vs DCA
  const [inst, setInst] = useState<(typeof DCA_INSTRUMENTS)[number]>('IDX-SPARK');
  const [amountText, setAmountText] = useState('10000');
  const [parts, setParts] = useState<'3' | '6' | '12'>('6');
  const candles = useCandles(inst, 180).data ?? [];
  const amount = parseToMinor(amountText, 2);
  const stats = amount ? lumpVsDca(candles.map((k) => k.close), amount, Number(parts)) : null;

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('plan.rebalanceTitle')}</Title>
      <Caption>{t('plan.rebalanceIntro')}</Caption>
      <Card style={{ gap: 8 }}>
        {Object.entries(values).map(([asset, v]) => {
          const actual = total > 0 ? Math.round((v * 10_000) / total) : 0;
          return (
            <View key={asset} style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <Body bold>{asset}</Body>
              <Caption>{t('plan.actual', { pct: f.pct(actual) })}</Caption>
              <View style={{ flex: 1 }}>
                <Field
                  label={t('plan.target')}
                  testID={`target-${asset}`}
                  value={targetsBps[asset] != null ? String(targetsBps[asset] / 100) : ''}
                  onChange={(s) => setTarget(asset, Math.max(0, Math.min(100, Math.floor(Number(s.replace(',', '.')) || 0))) * 100)}
                />
              </View>
            </View>
          );
        })}
        {!hasTargets && <Caption>{t('plan.noTargets')}</Caption>}
        {hasTargets && due && drifted.length > 0 && (
          <Caption color={c.negative} testID="rebalance-due">
            {t('plan.due', { list: drifted.map((d) => `${d.key} ${f.signed(d.driftBps)}`).join(', ') })}
          </Caption>
        )}
        {hasTargets && (!due || drifted.length === 0) && (
          <Caption testID="rebalance-ok">{due ? t('plan.withinBand') : t('plan.notYet', { date: lastCheck != null ? f.date(lastCheck + 182 * dayMillis) : '—' })}</Caption>
        )}
        <Button testID="rebalance-checked" title={t('plan.checked')} color={c.textSecondary} disabled={!clock} onPress={() => clock && markChecked(clock.now)} />
      </Card>

      <Title>{t('plan.dcaTitle')}</Title>
      <Caption>{t('plan.dcaIntro')}</Caption>
      <Card style={{ gap: 8 }}>
        <Chips value={inst} options={DCA_INSTRUMENTS.map((i) => ({ value: i, label: i }))} onChange={(v) => v && setInst(v)} testIDPrefix="dca-inst" />
        <Field label={t('plan.amount')} value={amountText} onChange={setAmountText} testID="dca-amount" />
        <Segmented value={parts} options={(['3', '6', '12'] as const).map((p) => ({ value: p, label: t('plan.parts', { count: Number(p) }) }))} onChange={setParts} testIDPrefix="dca-parts" />
        {stats ? (
          <>
            <Line label={t('plan.windows')} value={String(stats.windows)} testID="dca-windows" />
            <Line label={t('plan.lumpWins')} value={`${stats.lumpWins} / ${stats.windows} (${f.pct(stats.lumpWinsBps)})`} testID="dca-lump-wins" />
            <Line label={t('plan.avgEdge')} value={f.signed(stats.avgEdgeBps)} />
            <Line label={t('plan.worstLump')} value={f.signed(stats.worstLumpBps)} color={c.negative} />
            <Line label={t('plan.worstDca')} value={f.signed(stats.worstDcaBps)} color={c.negative} />
          </>
        ) : (
          <Caption>{t('plan.notEnough', { count: candles.length })}</Caption>
        )}
        <Caption>{t('plan.honest')}</Caption>
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
