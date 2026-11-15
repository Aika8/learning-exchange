import { useState } from 'react';
import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { api, call, type Schemas } from '../api/client';
import { useAccountNudges, useClock } from '../hooks';
import { formatMinor } from '../money';
import { useColors } from '../theme/theme';
import { Body, Caption, Card, Screen, Segmented, Title } from '../components/ui';
import { Line } from '../components/Field';
import { TabBar } from '../components/TabBar';

type Period = 'ALL' | 'TODAY';
const SCALE: Record<string, number> = { SPARK: 2, SILK: 0, AMBER: 0 };

/** Statement: every operation with fee and spread paid against the mid, totals with realised profit and 10% tax. */
export default function StatementScreen() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  useAccountNudges();
  const [period, setPeriod] = useState<Period>('ALL');
  const now = useClock().data?.now;
  // «Today» = since midnight of the simulation clock's day (device time zone).
  const from = period === 'TODAY' && now ? new Date(new Date(now).setHours(0, 0, 0, 0)).getTime() : undefined;
  const st = useQuery({
    queryKey: ['statement', period, from ?? 0],
    queryFn: () => call(api.GET('/statement', { params: { query: from !== undefined ? { from } : {} } })),
    enabled: period === 'ALL' || from !== undefined,
  });
  const data = st.data;
  const cur = data?.currency ?? 'SPARK';
  const money = (m: number, asset = cur) => `${formatMinor(m, SCALE[asset] ?? 0, i18n.language)} ${asset}`;
  const time = new Intl.DateTimeFormat(i18n.language, { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
  const lines = (data?.lines ?? []).slice().reverse().slice(0, 40);

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('statement.title')}</Title>
      <Segmented testIDPrefix="period" value={period} onChange={setPeriod} options={[{ value: 'ALL', label: t('statement.all') }, { value: 'TODAY', label: t('statement.today') }]} />
      {data && (
        <Card style={{ gap: 6 }} >
          <Body bold>{t('statement.totals')}</Body>
          <Line label={t('statement.fees')} value={money(data.totals.fees)} />
          <Line label={t('statement.spreadPaid')} value={money(data.totals.spreadPaid)} />
          <Line label={t('statement.realised')} value={money(data.totals.realisedPnl)} color={data.totals.realisedPnl >= 0 ? c.positive : c.negative} testID="total-pnl" />
          <Line label={t('statement.tax', { rate: data.totals.taxRateBps / 100 })} value={money(data.totals.tax)} testID="total-tax" />
          <Line label={t('statement.payouts')} value={money(data.totals.payouts)} color={c.positive} testID="total-payouts" />
          <Line label={t('statement.taxWithheld')} value={money(data.totals.taxWithheld)} testID="total-tax-withheld" />
          <Line label={t('statement.interest')} value={money(data.totals.interest)} color={c.positive} />
          <Caption>{t('statement.spreadNote')}</Caption>
          <Caption>{t('statement.taxNote')}</Caption>
        </Card>
      )}
      <Title>{t('statement.operations')}</Title>
      <Card style={{ gap: 10 }}>
        {data && lines.length === 0 && <Caption>{t('statement.none')}</Caption>}
        {lines.map((l, i) => (
          <StatementRow key={`${l.ts}-${i}`} l={l} money={money} time={time.format(l.ts)} />
        ))}
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}

function StatementRow({ l, money, time }: { l: Schemas['StatementLine']; money: (m: number, a?: string) => string; time: string }) {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const p = (m: number) => formatMinor(m, 2, i18n.language);
  const title = l.kind === 'TRADE' ? `${t(l.side === 'BUY' ? 'statement.buy' : 'statement.sell')} ${l.instrument ?? ''}${l.margin ? ` · ${t('statement.margin')}` : ''}` : t(`skind.${l.kind}`);
  return (
    <View style={{ gap: 2, borderBottomWidth: 1, borderBottomColor: c.border, paddingBottom: 8 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Body>{title}</Body>
        <Body bold num color={l.kind === 'DIVIDEND_TAX' ? c.negative : l.amount >= 0 ? c.positive : c.textPrimary}>
          {l.amount > 0 ? '+' : ''}
          {money(l.amount, l.asset)}
        </Body>
      </View>
      <Caption>
        {time}
        {l.price != null && l.qty != null ? ` · ${l.qty} × ${p(l.price)}` : ''}
        {l.mid != null ? ` · ${t('statement.mid')} ${p(l.mid)}` : ''}
      </Caption>
      {(l.fee !== 0 || l.spreadPaid !== 0) && (
        <Caption>
          {t('statement.fee')} {money(l.fee)} · {t(l.spreadPaid < 0 ? 'statement.spreadEarned' : 'statement.spread')} {money(Math.abs(l.spreadPaid))}
        </Caption>
      )}
      {l.kind === 'DIVIDEND_TAX' && <Caption>{t('statement.withheldHint', { instrument: l.instrument ?? '' })}</Caption>}
      {l.realisedPnl !== 0 && <Caption color={l.realisedPnl > 0 ? c.positive : c.negative}>{t('statement.pnl')} {money(l.realisedPnl)}</Caption>}
    </View>
  );
}
