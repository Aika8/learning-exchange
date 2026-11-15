import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Instrument } from '../api/client';
import { positionSize } from '../finance';
import { formatMinor, parseToMinor } from '../money';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Title } from './ui';
import { Field, Line } from './Field';

const plain = (minor: number, scale: number) => formatMinor(minor, scale, 'en').replace(/,/g, '');

/** Position-size helper: how many units so that hitting the stop costs at most risk% of capital. */
export function PositionSize({ instrument, capital, lastPrice, onUse }: { instrument: Instrument; capital?: number; lastPrice?: number | null; onUse: (qty: string, stop: string, side: 'BUY' | 'SELL') => void }) {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const ps = instrument.priceScale;
  const [cap, setCap] = useState('');
  const [risk, setRisk] = useState('1');
  const [entry, setEntry] = useState('');
  const [stop, setStop] = useState('');
  useEffect(() => {
    if (cap === '' && capital) setCap(plain(capital, 2));
  }, [capital, cap]);
  useEffect(() => {
    if (entry === '' && lastPrice) setEntry(plain(lastPrice, ps));
  }, [lastPrice, entry, ps]);

  const r = positionSize(parseToMinor(cap, 2) ?? 0, parseToMinor(risk, 2) ?? 0, parseToMinor(entry, ps) ?? 0, parseToMinor(stop, ps) ?? 0);
  const money = (m: number) => `${formatMinor(m, ps, i18n.language)} ${instrument.quote}`;

  return (
    <Card style={{ gap: 10 }}>
      <Title>{t('size.title')}</Title>
      <Caption>{t('size.formula')}</Caption>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Field testID="size-capital" label={t('size.capital', { quote: instrument.quote })} value={cap} onChange={setCap} />
        <Field testID="size-risk" label={t('size.risk')} value={risk} onChange={setRisk} />
      </View>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Field testID="size-entry" label={t('size.entry', { quote: instrument.quote })} value={entry} onChange={setEntry} />
        <Field testID="size-stop" label={t('size.stop', { quote: instrument.quote })} value={stop} onChange={setStop} />
      </View>
      {r ? (
        <View style={{ gap: 4 }}>
          <Line label={t('size.budget')} value={money(r.riskBudget)} />
          <Line label={t('size.perUnit')} value={money(Math.abs((parseToMinor(entry, ps) ?? 0) - (parseToMinor(stop, ps) ?? 0)))} />
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <Body bold>{t('size.qty')}</Body>
            <Body bold num>
              {r.qty} {instrument.base}
            </Body>
          </View>
          <Line label={t('size.atRisk')} value={money(r.atRisk)} color={c.negative} testID="size-at-risk" />
        </View>
      ) : (
        <Caption>{t('size.fill')}</Caption>
      )}
      <View style={{ flexDirection: 'row' }}>
        <Button testID="size-use" title={t('size.use')} disabled={!r || r.qty === 0} onPress={() => r && onUse(String(r.qty), stop, (parseToMinor(stop, ps) ?? 0) < (parseToMinor(entry, ps) ?? 0) ? 'SELL' : 'BUY')} />
      </View>
    </Card>
  );
}
