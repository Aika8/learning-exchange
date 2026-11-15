import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { formatR } from '../finance';
import { useSessionReview } from '../hooks';
import { useColors } from '../theme/theme';
import { Body, Caption, Card, Screen, Title } from '../components/ui';
import { Line } from '../components/Field';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

/** Session review (M2c): my orders grouped by the mood and market state I noted in the journal, with the average R. */
export default function ReviewScreen() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const q = useSessionReview();
  const r = q.data;
  const R = (x: number | null | undefined) => (x == null ? '—' : formatR(x, f.dec));
  const rColor = (x: number | null | undefined) => (x == null || x === 0 ? c.textPrimary : x > 0 ? c.positive : c.negative);

  const group = (g: Schemas['ReviewGroup'], prefix: 'mood' | 'marketState') => (
    <View key={g.key} testID={`review-${prefix}-${g.key}`} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
      <View style={{ flex: 1 }}>
        <Body>{g.key === 'NONE' ? t('review.none') : t(`${prefix}.${g.key}`)}</Body>
        <Caption>
          {t('review.orders', { count: g.orders })} · {t('review.wins', { count: g.wins })} · {f.money(g.result, 2, r?.currency ?? 'SPARK')}
        </Caption>
      </View>
      <Body bold num color={rColor(g.avgRx100)}>
        {R(g.avgRx100)}
      </Body>
    </View>
  );

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('review.title')}</Title>
      <Caption>{t('review.intro')}</Caption>
      {!r && <Caption color={q.error ? c.negative : undefined}>{q.error ? t('errors.NETWORK') : '…'}</Caption>}
      {r && (
        <>
          <Card style={{ gap: 6 }}>
            <Line label={t('review.total')} value={String(r.orders)} />
            <Line label={t('review.annotated')} value={String(r.annotated)} />
            <Line label={t('review.winsLabel')} value={String(r.wins)} />
            <Line label={t('review.result')} value={f.money(r.result, 2, r.currency)} color={rColor(r.result)} testID="review-result" />
            <Line label={t('review.expectancy')} value={R(r.expectancyRx100)} color={rColor(r.expectancyRx100)} testID="review-expectancy" />
            <Caption>{t('review.rHint')}</Caption>
          </Card>
          <Title>{t('review.byMood')}</Title>
          <Card style={{ gap: 10 }}>
            {r.byMood.length === 0 ? <Caption>{t('review.empty')}</Caption> : r.byMood.map((g) => group(g, 'mood'))}
          </Card>
          <Title>{t('review.byMarketState')}</Title>
          <Card style={{ gap: 10 }}>
            {r.byMarketState.length === 0 ? <Caption>{t('review.empty')}</Caption> : r.byMarketState.map((g) => group(g, 'marketState'))}
          </Card>
        </>
      )}
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
