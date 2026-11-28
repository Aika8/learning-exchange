import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, call } from '../api/client';
import { refetchAccount, useAccountNudges, useMe, useSavings } from '../hooks';
import { bpsToPercent, ruleOf72Tenths } from '../finance';
import { formatMinor, parseToMinor } from '../money';
import { newIdempotencyKey } from '../m2b';
import { bankDayLength, interestToDate, splitDeposits, tenthsText } from '../deposits';
import { availableOf } from '../fx';
import { type as typo, useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Title } from '../components/ui';
import { Field, Line } from '../components/Field';
import { TabBar } from '../components/TabBar';

/** Savings deposits: product rate, open and close, balance with daily compound interest, rule of 72. */
export default function Deposits() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  useAccountNudges();
  const savings = useSavings();
  const me = useMe().data;
  const [amount, setAmount] = useState('');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const product = savings.data?.product;
  const { open, closed } = splitDeposits(savings.data?.deposits);
  const cash = availableOf(me?.balances, 'SPARK');
  const dec = i18n.language.startsWith('ru') ? ',' : '.';
  const fmt = (m: number) => `${formatMinor(m, 2, i18n.language)} SPARK`;
  const err = (e: unknown) => setMsg({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`, { defaultValue: t('errors.BAD_REQUEST') }) });

  const openDeposit = useMutation({
    mutationFn: (minor: number) => call(api.POST('/savings', { params: { header: { 'Idempotency-Key': newIdempotencyKey() } }, body: { amount: minor } })),
    onSuccess: (d) => {
      setMsg({ ok: true, text: t('deposits.opened', { id: d.depositId }) });
      setAmount('');
      refetchAccount(qc);
    },
    onError: err,
  });
  const close = useMutation({
    mutationFn: (id: number) => call(api.POST('/savings/{depositId}/close', { params: { path: { depositId: id } } })),
    onSuccess: (d) => {
      setMsg({ ok: true, text: t('deposits.closed', { amount: fmt(d.balance) }) });
      refetchAccount(qc);
    },
    onError: err,
  });

  const years = product ? ruleOf72Tenths(product.rateBps) : null;
  const day = bankDayLength(product ? product.dayMillis : 0);
  const dayLen = t(`units.${day.unit}`, { count: day.count });

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('deposits.title')}</Title>
      <Card style={{ backgroundColor: c.primary, gap: 4 }}>
        <Caption color={c.onPrimary}>{t('deposits.product')}</Caption>
        <Text testID="savings-rate" style={{ color: c.onPrimary, fontSize: typo.numericLarge.size, lineHeight: typo.numericLarge.lineHeight, fontWeight: '600' }}>
          {product ? t('deposits.rate', { rate: bpsToPercent(product.rateBps, dec) }) : '—'}
        </Text>
        <Caption color={c.onPrimary}>{t('deposits.compound')}</Caption>
      </Card>
      {product && (
        <Card style={{ gap: 6 }}>
          <Body bold>{t('deposits.rule72Title')}</Body>
          <Caption color={c.textPrimary}>
            {t('deposits.rule72', { rate: bpsToPercent(product.rateBps, dec), years: tenthsText(years, dec) })}
          </Caption>
          <Caption testID="bank-day">{t('deposits.bankDay', { duration: dayLen })}</Caption>
        </Card>
      )}
      <Title>{t('deposits.mine')}</Title>
      <Card style={{ gap: 12 }}>
        {open.length === 0 && <Caption>{t('deposits.none')}</Caption>}
        {open.map((d) => (
          <View key={d.depositId} testID={`deposit-${d.depositId}`} style={{ gap: 4 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <Body>{t('deposits.number', { id: d.depositId })}</Body>
              <Body bold num>
                {fmt(d.balance)}
              </Body>
            </View>
            <Line label={t('deposits.principal')} value={fmt(d.principal)} />
            <Line label={t('deposits.interest')} value={`+${fmt(interestToDate(d))}`} color={c.positive} />
            <Pressable testID={`deposit-close-${d.depositId}`} onPress={() => close.mutate(d.depositId)} hitSlop={8} style={{ alignSelf: 'flex-end' }}>
              <Text style={{ color: c.primary, fontWeight: '600' }}>{t('deposits.close')}</Text>
            </Pressable>
          </View>
        ))}
        {closed.map((d) => (
          <Line key={d.depositId} label={`${t('deposits.number', { id: d.depositId })} · ${t('deposits.statusClosed')}`} value={fmt(d.balance)} />
        ))}
      </Card>
      <Title>{t('deposits.openTitle')}</Title>
      <Card style={{ gap: 10 }}>
        <Field testID="deposit-amount" label={t('deposits.amount')} value={amount} onChange={setAmount} hint={cash !== undefined ? t('deposits.available', { amount: fmt(cash) }) : undefined} />
        {msg && (
          <Text testID="deposit-result" style={{ color: msg.ok ? c.positive : c.negative, fontWeight: '600' }}>
            {msg.text}
          </Text>
        )}
        <View style={{ flexDirection: 'row' }}>
          <Button
            testID="deposit-open"
            title={t('deposits.open')}
            disabled={openDeposit.isPending}
            onPress={() => {
              const m = parseToMinor(amount, 2);
              if (m === null) return setMsg({ ok: false, text: t('errors.INVALID_AMOUNT') });
              openDeposit.mutate(m);
            }}
          />
        </View>
      </Card>
      <Caption>{t('app.notAdvice')}</Caption>
    </Screen>
  );
}

