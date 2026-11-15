import { Pressable, View } from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { useBonds, useDisplayName } from '../hooks';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Title } from '../components/ui';
import { Line } from '../components/Field';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

/** Bonds (M2b): list, and the detail of one (`?id=`) with yield to maturity always shown and modified duration. */
export default function BondsScreen() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const bonds = useBonds().data ?? [];
  const name = useDisplayName();
  const bond = id ? bonds.find((b) => b.instrument === id) : undefined;
  const statusColor = (b: Schemas['Bond']) => (b.status === 'DEFAULTED' ? c.negative : b.status === 'REDEEMED' ? c.textSecondary : c.positive);

  if (bond) {
    return (
      <Screen
        footer={
          <>
            <View style={{ flexDirection: 'row', gap: 8, padding: 12, backgroundColor: c.bg }}>
              <Button testID="bond-back" title={t('bonds.all')} color={c.textSecondary} onPress={() => router.setParams({ id: '' })} />
              {bond.status === 'ACTIVE' && <Button testID="bond-trade" title={t('company.trade')} onPress={() => router.push({ pathname: '/instrument', params: { id: bond.instrument } })} />}
            </View>
            <TabBar />
          </>
        }
      >
        <Title>{name(bond.instrument, f.lang)}</Title>
        <Caption>
          {t('kind.BOND')} · {bond.instrument}
        </Caption>
        <Card style={{ backgroundColor: c.primary, gap: 4 }}>
          <Caption color={c.onPrimary}>{t('bonds.ytm')}</Caption>
          <Body bold color={c.onPrimary}>
            {f.pct(bond.ytmBps)}
          </Body>
          <Caption color={c.onPrimary}>{t('bonds.fairYield', { fair: f.pct(bond.fairYieldBps), rate: f.pct(bond.policyRateBps) })}</Caption>
        </Card>
        <Card style={{ gap: 6 }}>
          <Line label={t('bonds.price')} value={f.money(bond.price)} testID="bond-price" />
          <Line label={t('bonds.face')} value={f.money(bond.faceValue)} />
          <Line label={t('bonds.coupon')} value={`${f.pct(bond.couponBps)} · ${t('bonds.perYear', { count: bond.couponsPerYear })}`} />
          <Line label={t('bonds.couponPerUnit')} value={f.money(bond.couponPerUnit)} />
          <Line label={t('bonds.rating')} value={bond.rating} />
          <Line label={t('bonds.maturity')} value={f.when(bond.maturityAt)} />
          <Line label={t('bonds.status')} value={t(`bondStatus.${bond.status}`)} color={statusColor(bond)} />
          <Line label={t('bonds.duration')} value={t('bonds.years', { v: f.x100(bond.durationX100) })} testID="bond-duration" />
          <Line label={t('bonds.nextCoupon')} value={bond.nextCouponAt == null ? '—' : f.when(bond.nextCouponAt)} />
          <Line label={t('bonds.couponsPaidLeft')} value={`${bond.couponsPaid} / ${bond.couponsLeft}`} />
        </Card>
        <Card style={{ gap: 4 }}>
          <Body bold>{t('bonds.hintTitle')}</Body>
          <Caption color={c.textPrimary}>{t('bonds.hint', { duration: f.x100(bond.durationX100) })}</Caption>
        </Card>
        <Caption>{t('app.notAdvice')}</Caption>
      </Screen>
    );
  }

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('bonds.title')}</Title>
      <Caption>{t('bonds.hintShort')}</Caption>
      {bonds.length === 0 && <Caption>{t('bonds.none')}</Caption>}
      {bonds.map((b) => (
        <Pressable key={b.instrument} testID={`bond-${b.instrument}`} onPress={() => router.setParams({ id: b.instrument })}>
          <Card style={{ gap: 4 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: 8 }}>
              <Body bold>{name(b.instrument, f.lang)}</Body>
              <Caption color={statusColor(b)}>{t(`bondStatus.${b.status}`)}</Caption>
            </View>
            <Line label={t('bonds.ytm')} value={f.pct(b.ytmBps)} />
            <Line label={t('bonds.price')} value={f.money(b.price)} />
            <Line label={`${t('bonds.rating')} · ${t('bonds.coupon')}`} value={`${b.rating} · ${f.pct(b.couponBps)}`} />
            <Line label={t('bonds.duration')} value={t('bonds.years', { v: f.x100(b.durationX100) })} />
          </Card>
        </Pressable>
      ))}
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
