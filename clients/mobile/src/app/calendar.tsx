import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { useCalendar, useClock, useDisplayName, useMacro } from '../hooks';
import { bankDaysUntil } from '../m2b';
import { useColors } from '../theme/theme';
import { Body, Caption, Card, Screen, Title } from '../components/ui';
import { Line } from '../components/Field';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

/** Economic calendar (M2b): central bank state and every scheduled event, with consensus against the result. */
export default function CalendarScreen() {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  const macro = useMacro().data;
  const entries = useCalendar().data ?? [];
  const now = useClock().data?.now ?? 0;
  const name = useDisplayName();

  // Units per kind: rate decisions in bps, EPS/dividends/coupons/face in SPARK minor units, storms in volatility %.
  const value = (e: Schemas['CalendarEntry'], v: number) => (e.kind === 'RATE_DECISION' ? f.pct(v) : e.kind === 'STORM' ? `${v}%` : f.money(v));

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('calendar.title')}</Title>
      <Caption testID="calendar-teach">{t('calendar.teach')}</Caption>
      <Card style={{ gap: 6 }}>
        <Body bold>{t('calendar.bank')}</Body>
        {macro ? (
          <>
            <Line label={t('calendar.policyRate')} value={f.pct(macro.policyRateBps)} testID="policy-rate" />
            <Line label={t('calendar.inflation')} value={f.pct(macro.inflationBps)} />
            <Line label={t('calendar.realRate')} value={f.pct(macro.realRateBps)} color={macro.realRateBps >= 0 ? c.positive : c.negative} />
            <Line label={t('calendar.depositRate')} value={f.pct(macro.savingsRateBps)} />
            <Line
              label={t('calendar.nextDecision')}
              value={macro.nextDecisionAt == null ? '—' : `${f.when(macro.nextDecisionAt)} · ${t('calendar.inDays', { count: bankDaysUntil(macro.nextDecisionAt, now) })}`}
            />
            <Line label={t('calendar.nextConsensus')} value={macro.nextConsensusBps == null ? t('calendar.notYet') : f.pct(macro.nextConsensusBps)} />
            <Line
              label={t('calendar.regime')}
              value={`${t(`regime.${macro.regime}`)} · ${t('calendar.volatility', { pct: macro.volatilityPct })}`}
              color={macro.regime === 'STORM' ? c.negative : c.textPrimary}
            />
          </>
        ) : (
          <Caption>…</Caption>
        )}
      </Card>
      <Title>{t('calendar.events')}</Title>
      <Card style={{ gap: 10 }}>
        {entries.length === 0 && <Caption>{t('calendar.empty')}</Caption>}
        {entries.map((e, i) => (
          <View key={`${e.at}-${e.kind}-${e.instrument ?? ''}-${i}`} testID={`cal-${e.kind}`} style={{ gap: 2, opacity: e.done ? 0.75 : 1 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: 8 }}>
              <Body bold>
                {t(`calkind.${e.kind}`)}
                {e.instrument ? ` · ${name(e.instrument, f.lang)}` : ''}
              </Body>
              <Caption color={e.done ? c.textSecondary : c.info}>{t(e.done ? 'calendar.done' : 'calendar.scheduled')}</Caption>
            </View>
            <Caption>{f.when(e.at)}</Caption>
            {(e.consensus != null || e.actual != null || e.previous != null) && (
              <Caption color={c.textPrimary}>
                {[
                  e.previous != null ? t('calendar.previous', { v: value(e, e.previous) }) : null,
                  e.consensus != null ? t('calendar.consensus', { v: value(e, e.consensus) }) : null,
                  e.actual != null ? t('calendar.actual', { v: value(e, e.actual) }) : null,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </Caption>
            )}
          </View>
        ))}
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}
