import { View } from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { useCandles, useClock, useCompanyCard, useInstrument } from '../hooks';
import { showGapWarning } from '../m2b';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Title } from '../components/ui';
import { Line } from '../components/Field';
import { PriceChart } from '../components/PriceChart';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

/** Company card (M2b): key metrics, last report vs consensus, earnings calendar, gap-risk warning, insider trades, price chart with ex-dates. */
export default function CompanyScreen() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const { id = 'SILK-SPARK' } = useLocalSearchParams<{ id?: string }>();
  const card = useCompanyCard(id);
  const candles = useCandles(id, 180).data ?? [];
  const instrument = useInstrument(id).data;
  const now = useClock().data?.now ?? 0;
  const ps = instrument?.priceScale ?? 2;
  const m = (v: number | null | undefined) => (v == null ? '—' : f.money(v, ps));

  if (!card.data) {
    return (
      <Screen footer={<TabBar />}>
        <Title>{t('company.title')}</Title>
        <Caption color={card.error ? c.negative : undefined}>{card.error ? t('errors.NETWORK') : '…'}</Caption>
      </Screen>
    );
  }
  const { company: co, name, gapWarning } = card.data;
  const r = co.lastReport;
  const pastReports = co.reports.slice().sort((a, b) => b.ts - a.ts);

  return (
    <Screen
      footer={
        <>
          <View style={{ flexDirection: 'row', gap: 8, padding: 12, backgroundColor: c.bg }}>
            <Button testID="company-trade" title={t('company.trade')} onPress={() => router.push({ pathname: '/instrument', params: { id } })} />
          </View>
          <TabBar />
        </>
      }
    >
      <Title>{f.lang.startsWith('ru') ? name.ru : name.en}</Title>
      <Caption>
        {t('company.subtitle')} · {co.instrument}
      </Caption>
      {!co.tradingOpen && (
        <Card style={{ borderColor: c.warning, borderWidth: 1 }}>
          <Body bold color={c.warning}>{t('instrument.halted')}</Body>
          <Caption>{t('instrument.haltedHint')}</Caption>
        </Card>
      )}
      {showGapWarning(gapWarning, now) && gapWarning && (
        <Card style={{ backgroundColor: c.negative, gap: 4 }}>
          <Body bold color={c.onPrimary}>
            {t('company.gapWarning')}
          </Body>
          <Caption color={c.onPrimary}>{t('company.gapHint', { count: gapWarning.conditionalIds.length, time: f.when(gapWarning.reportAt) })}</Caption>
        </Card>
      )}

      <Title>{t('company.metrics')}</Title>
      <Card style={{ gap: 6 }}>
        <Line label={t('company.price')} value={m(co.lastPrice)} testID="co-price" />
        <Line label={t('company.epsTtm')} value={m(co.epsTtm)} />
        <Line label={t('company.pe')} value={co.peX100 == null ? t('company.peNone') : f.x100(co.peX100)} testID="co-pe" />
        <Line label={t('company.debtToProfit')} value={co.debtToProfitX100 == null ? '—' : f.x100(co.debtToProfitX100)} />
        <Line label={t('company.divYield')} value={co.dividendYieldBps == null ? '—' : f.pct(co.dividendYieldBps)} />
        <Line label={t('company.shares')} value={f.money(co.sharesOutstanding, 0, '')} />
      </Card>

      <Title>{t('company.chart')}</Title>
      <Card>
        <PriceChart candles={candles} priceScale={ps} exDates={co.dividends.flatMap((d) => [
            { at: d.exDate, perShare: d.perShare, kind: 'ex' as const },
            ...(d.recordDate != null ? [{ at: d.recordDate, perShare: d.perShare, kind: 'record' as const }] : []),
            ...(d.payDate != null ? [{ at: d.payDate, perShare: d.perShare, kind: 'pay' as const }] : []),
          ])} />
      </Card>

      <Title>{t('company.lastReport')}</Title>
      <Card style={{ gap: 6 }}>
        {!r && <Caption>{t('company.noReport')}</Caption>}
        {r && (
          <>
            <Caption>{t('company.reportOf', { season: r.season, date: f.when(r.ts) })}</Caption>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Caption>{''}</Caption>
              <Caption>{t('company.factVsConsensus')}</Caption>
            </View>
            <Line label={t('company.eps')} value={`${m(r.eps)} / ${m(r.consensusEps)}`} />
            {co.surpriseBps != null && (
              <Line label={t('company.surprise')} value={f.signed(co.surpriseBps)} color={co.surpriseBps >= 0 ? c.positive : c.negative} testID="co-surprise" />
            )}
            <Line label={t('company.revenue')} value={m(r.revenue)} />
            <Line label={t('company.netProfit')} value={m(r.netProfit)} />
            <Line label={t('company.debt')} value={m(r.debt)} />
            <Line label={t('company.ocf')} value={m(r.operatingCashFlow)} />
            <Line label={t('company.dividend')} value={m(r.dividendPerShare)} />
            <Line label={t('company.guidance')} value={m(r.guidanceEps)} />
          </>
        )}
      </Card>

      <Title>{t('company.earnings')}</Title>
      <Card style={{ gap: 6 }}>
        <Line label={t('company.nextReport')} value={co.nextReportAt == null ? '—' : f.when(co.nextReportAt)} testID="co-next-report" />
        {co.consensus ? (
          <>
            <Line label={t('company.consensusEps')} value={m(co.consensus.eps)} />
            <Line label={t('company.consensusRevenue')} value={m(co.consensus.revenue)} />
            <Line label={t('company.consensusProfit')} value={m(co.consensus.netProfit)} />
          </>
        ) : (
          <Caption>{t('company.consensusLater')}</Caption>
        )}
        <Caption>{t('company.pastReports')}</Caption>
        {pastReports.length === 0 && <Caption>{t('company.noReport')}</Caption>}
        {pastReports.map((p) => (
          <Line key={p.ts} label={`${t('company.season', { season: p.season })} · ${f.date(p.ts)}`} value={`${m(p.eps)} / ${m(p.consensusEps)}`} color={p.eps >= p.consensusEps ? c.positive : c.negative} />
        ))}
      </Card>

      <Title>{t('company.dividends')}</Title>
      <Card style={{ gap: 6 }}>
        {co.dividends.length === 0 && <Caption>{t('company.noDividends')}</Caption>}
        {co.dividends.map((d) => (
          <View key={d.exDate} testID="dividend-row" style={{ gap: 2, borderBottomWidth: 1, borderBottomColor: c.border, paddingBottom: 6 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body bold num>{m(d.perShare)}</Body>
              <Caption color={d.paid ? c.positive : c.warning}>{t(d.paid ? 'company.paid' : 'company.planned')}</Caption>
            </View>
            <Line label={t('company.exDate')} value={f.when(d.exDate)} color={c.info} />
            <Line label={t('company.recordDate')} value={d.recordDate == null ? '—' : f.when(d.recordDate)} />
            <Line label={t('company.payDate')} value={d.payDate == null ? t('company.payAtEx') : f.when(d.payDate)} />
          </View>
        ))}
        <Caption>{t('company.exHint')}</Caption>
        <Caption>{t('company.recordHint')}</Caption>
      </Card>

      <Title>{t('company.insiders')}</Title>
      <Card style={{ gap: 6 }}>
        {co.insiderTrades.length === 0 && <Caption>{t('company.noInsiders')}</Caption>}
        {co.insiderTrades.map((it, i) => (
          <View key={`${it.ts}-${i}`} style={{ flexDirection: 'row', justifyContent: 'space-between', gap: 8 }}>
            <Caption>
              {t(`role.${it.role}`)} · {f.date(it.ts)}
            </Caption>
            <Caption color={it.side === 'BUY' ? c.bid : c.ask}>
              {t(it.side === 'BUY' ? 'company.insiderBuy' : 'company.insiderSell')} {it.qty} × {m(it.price)}
            </Caption>
          </View>
        ))}
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
