import { memo } from 'react';
import { View } from 'react-native';
import { router } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { useAccountNudges, useMe } from '../hooks';
import { formatMinor } from '../money';
import { type as typo, useColors } from '../theme/theme';
import { Body, Button, Caption, Card, PracticeChip, Screen, Title } from '../components/ui';
import { TabBar } from '../components/TabBar';
import { Text } from 'react-native';

const SCALE: Record<string, number> = { SPARK: 2, SILK: 0, AMBER: 0 };

/** Design S01 (home), skeleton: greeting, cash balance with the practice badge, accounts, one quick action. */
export default function Home() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const me = useMe();
  useAccountNudges();
  const cash = me.data?.balances.find((b) => b.asset === 'SPARK');
  const silk = me.data?.balances.find((b) => b.asset === 'SILK');
  const fmt = (v: number, asset: string) => formatMinor(v, SCALE[asset] ?? 0, i18n.language);

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('home.hello', { name: me.data?.name ?? '…' })}</Title>
      {me.error && <Caption color={c.negative}>{t(`errors.${(me.error as Error).message}`, { defaultValue: t('errors.NETWORK') })}</Caption>}
      <Card style={{ backgroundColor: c.primary, gap: 6 }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Caption color={c.onPrimary}>{t('home.total')}</Caption>
          <PracticeChip />
        </View>
        <Text testID="cash-total" style={{ color: c.onPrimary, fontSize: typo.numericLarge.size, lineHeight: typo.numericLarge.lineHeight, fontWeight: '600', fontVariant: ['tabular-nums'] }}>
          {cash ? `${fmt(cash.available + cash.reserved, 'SPARK')} SPARK` : '—'}
        </Text>
      </Card>
      <Caption>{t('home.accounts')}</Caption>
      <Card style={{ gap: 14 }}>
        <Row title={t('home.current')} value={cash ? `${fmt(cash.available, 'SPARK')} SPARK` : '—'} sub={cash && cash.reserved > 0 ? t('home.inOrders', { amount: fmt(cash.reserved, 'SPARK') }) : undefined} testID="balance-SPARK" />
        <View style={{ height: 1, backgroundColor: c.border }} />
        <Row title={t('home.fxAccount')} value={`AMBER · ${t('home.pcs', { count: me.data?.balances.find((b) => b.asset === 'AMBER')?.available ?? 0 })}`} testID="balance-AMBER" />
        <View style={{ height: 1, backgroundColor: c.border }} />
        <Row title={t('home.broker')} value={silk ? `SILK · ${t('home.pcs', { count: silk.available })}` : '—'} sub={silk && silk.reserved > 0 ? t('home.inOrders', { amount: fmt(silk.reserved, 'SILK') }) : undefined} testID="balance-SILK" />
      </Card>
      <View style={{ flexDirection: 'row' }}>
        <Button testID="go-trade" title={t('home.trade')} onPress={() => router.replace('/instrument')} />
      </View>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Button testID="go-fx" title={t('home.fx')} color={c.accent} onPress={() => router.replace('/fx')} />
        <Button testID="go-statement" title={t('home.statement')} color={c.textSecondary} onPress={() => router.push('/statement')} />
      </View>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Button testID="go-funds" title={t('home.funds')} color={c.primary} onPress={() => router.push('/funds')} />
        <Button testID="go-review" title={t('home.review')} color={c.textSecondary} onPress={() => router.push('/review')} />
      </View>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Button testID="go-assistant" title={t('home.assistant')} color={c.accent} onPress={() => router.push('/assistant')} />
        <Button testID="go-achievements" title={t('home.achievements')} color={c.textSecondary} onPress={() => router.push('/achievements')} />
        <Button testID="go-plan" title={t('home.plan')} color={c.textSecondary} onPress={() => router.push('/plan')} />
      </View>
    </Screen>
  );
}

const Row = memo(function Row({ title, value, sub, testID }: { title: string; value: string; sub?: string; testID: string }) {
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
      <Body>{title}</Body>
      <View style={{ alignItems: 'flex-end' }}>
        <Body bold num>
          <Text testID={testID}>{value}</Text>
        </Body>
        {sub && <Caption>{sub}</Caption>}
      </View>
    </View>
  );
});
