import { Pressable, View } from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { useDisplayName, useFund, useFunds } from '../hooks';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Title } from '../components/ui';
import { Line } from '../components/Field';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';
import { basketGap, gapTone, premiumCaptionKey, premiumTone, sortedHoldings, vsBasketCaptionKey, weightBarPercent } from '../funds';

/** Funds (M2c): the list, and a fund card with TER, NAV vs price (premium), holdings, fees paid and the fund against its own basket. */
export default function FundsScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  return id ? <FundCard id={id} /> : <FundList />;
}

function FundList() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const name = useDisplayName();
  const funds = useFunds();
  return (
    <Screen footer={<TabBar />}>
      <Title>{t('funds.title')}</Title>
      <Caption>{t('funds.intro')}</Caption>
      {!funds.data && <Caption color={funds.error ? c.negative : undefined}>{funds.error ? t('errors.NETWORK') : '…'}</Caption>}
      {funds.data?.length === 0 && <Caption>{t('funds.none')}</Caption>}
      {funds.data?.map((fd) => (
        <Pressable key={fd.instrument} testID={`fund-${fd.instrument}`} onPress={() => router.push({ pathname: '/funds', params: { id: fd.instrument } })}>
          <Card style={{ gap: 4 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body bold>{name(fd.instrument, f.lang)}</Body>
              <Caption color={c.accent}>{t(`fundKind.${fd.kind}`)}</Caption>
            </View>
            <Line label={t('funds.ter')} value={f.pct(fd.terBps)} />
            <Line label={t('funds.navPerUnit')} value={fd.navPerUnit == null ? '—' : f.money(fd.navPerUnit)} />
            <Line label={t('funds.premium')} value={fd.premiumBps == null ? '—' : f.signed(fd.premiumBps)} color={premiumColor(fd.premiumBps, c)} />
          </Card>
        </Pressable>
      ))}
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}

function premiumColor(bps: number | null | undefined, c: ReturnType<typeof useColors>) {
  return c[premiumTone(bps)];
}

function FundCard({ id }: { id: string }) {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const name = useDisplayName();
  const q = useFund(id);
  const fd: Schemas['Fund'] | undefined = q.data;

  const footer = (
    <>
      <View style={{ flexDirection: 'row', gap: 8, padding: 12, backgroundColor: c.bg }}>
        <Button testID="fund-all" title={t('funds.all')} color={c.textSecondary} onPress={() => router.replace('/funds')} />
        <Button testID="fund-trade" title={t('company.trade')} onPress={() => router.push({ pathname: '/instrument', params: { id } })} />
      </View>
      <TabBar />
    </>
  );
  if (!fd) {
    return (
      <Screen footer={footer}>
        <Title>{name(id, f.lang)}</Title>
        <Caption color={q.error ? c.negative : undefined}>{q.error ? t('errors.NETWORK') : '…'}</Caption>
      </Screen>
    );
  }
  const holdings = sortedHoldings(fd.holdings);
  const gap = basketGap(fd.fundReturnBps, fd.basketReturnBps);
  const gapColor = gapTone(gap);

  return (
    <Screen footer={footer}>
      <Title>{name(fd.instrument, f.lang)}</Title>
      <Caption>
        {t(`fundKind.${fd.kind}`)} · {t(`fundKindHint.${fd.kind}`)}
      </Caption>

      <Card style={{ gap: 6 }}>
        <Line label={t('funds.ter')} value={f.pct(fd.terBps)} testID="fund-ter" />
        <Line label={t('funds.feesPaid')} value={f.money(fd.feesPaid)} color={c.negative} testID="fund-fees" />
        {fd.tenYearCostBps != null && <Caption testID="fund-ten-year">{t('funds.tenYear', { ter: f.pct(fd.terBps), cost: f.pct(fd.tenYearCostBps) })}</Caption>}
      </Card>

      <Title>{t('funds.priceVsNav')}</Title>
      <Card style={{ gap: 6 }}>
        <Line label={t('funds.navPerUnit')} value={fd.navPerUnit == null ? '—' : f.money(fd.navPerUnit)} testID="fund-nav-unit" />
        <Line label={t('funds.unitPrice')} value={fd.lastPrice == null ? '—' : f.money(fd.lastPrice)} />
        <Line label={t('funds.premium')} value={fd.premiumBps == null ? '—' : f.signed(fd.premiumBps)} color={premiumColor(fd.premiumBps, c)} testID="fund-premium" />
        <Caption>{t(premiumCaptionKey(fd.premiumBps))}</Caption>
        <Line label={t('funds.nav')} value={f.money(fd.nav)} />
        <Line label={t('funds.units')} value={f.money(fd.unitsOutstanding, 0, '')} />
      </Card>

      <Title>{t('funds.holdings')}</Title>
      <Card style={{ gap: 8 }}>
        {holdings.length === 0 && <Caption>{t('funds.noHoldings')}</Caption>}
        {holdings.map((h) => (
          <View key={h.instrument} style={{ gap: 3 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body>{name(h.instrument, f.lang)}</Body>
              <Body bold num>{f.pct(h.weightBps)}</Body>
            </View>
            <View style={{ height: 4, backgroundColor: c.surfaceAlt, borderRadius: 2 }}>
              <View style={{ height: 4, width: `${weightBarPercent(h.weightBps)}%`, backgroundColor: c.primary, borderRadius: 2 }} />
            </View>
            <Caption>
              {h.qty} × {h.price == null ? '—' : f.money(h.price)} = {f.money(h.value)}
            </Caption>
          </View>
        ))}
        <Line label={t('funds.cash')} value={f.money(fd.cash)} />
      </Card>

      <Title>{t('funds.vsBasket')}</Title>
      <Card style={{ gap: 6 }}>
        <Line label={t('funds.fundReturn')} value={fd.fundReturnBps == null ? '—' : f.signed(fd.fundReturnBps)} testID="fund-return" />
        <Line label={t('funds.basketReturn')} value={fd.basketReturnBps == null ? '—' : f.signed(fd.basketReturnBps)} testID="basket-return" />
        <Line label={t('funds.difference')} value={gap == null ? '—' : f.signed(gap)} color={gapColor && c[gapColor]} />
        <Line label={t('funds.basketValue')} value={f.money(fd.basketValue)} />
        <Caption>{t(vsBasketCaptionKey(gap))}</Caption>
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
