import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Instrument } from '../api/client';
import { atrPositionSize, bpsToPercent, positionSize, stopFromDistance } from '../finance';
import { useAtr } from '../hooks';
import { formatMinor, parseToMinor } from '../money';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Segmented, Title } from './ui';
import { Field, Line } from './Field';

const plain = (minor: number, scale: number) => formatMinor(minor, scale, 'en').replace(/,/g, '');
const ATR_PERIOD = 14;
type Mode = 'PRICE' | 'ATR';
type Side = 'BUY' | 'SELL';

/**
 * Position-size helper: how many units so that hitting the stop costs at most risk% of capital (that budget is 1 R).
 * The stop is either a price I type or k × ATR(14) away from the entry. `onRisk` reports the budget so the order
 * ticket can journal it as the planned risk.
 */
export function PositionSize({ instrument, capital, lastPrice, onUse, onRisk }: { instrument: Instrument; capital?: number; lastPrice?: number | null; onUse: (qty: string, stop: string, side: Side) => void; onRisk?: (riskMoney: number | null) => void }) {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const ps = instrument.priceScale;
  const dec = i18n.language.startsWith('ru') ? ',' : '.';
  const [mode, setMode] = useState<Mode>('PRICE');
  const [cap, setCap] = useState('');
  const [risk, setRisk] = useState('1');
  const [entry, setEntry] = useState('');
  const [stop, setStop] = useState('');
  const [k, setK] = useState('2');
  const [side, setSide] = useState<Side>('BUY');
  const atr = useAtr(instrument.id, ATR_PERIOD);
  useEffect(() => {
    if (cap === '' && capital) setCap(plain(capital, 2));
  }, [capital, cap]);
  useEffect(() => {
    if (entry === '' && lastPrice) setEntry(plain(lastPrice, ps));
  }, [lastPrice, entry, ps]);

  const capMinor = parseToMinor(cap, 2) ?? 0;
  const riskBps = parseToMinor(risk, 2) ?? 0;
  const entryMinor = parseToMinor(entry, ps) ?? 0;
  const a = atr.data;
  const atrReady = !!a?.ready && a.atr != null;

  let r: { qty: number; riskBudget: number; atRisk: number; distance: number } | null = null;
  let stopMinor: number | null = null;
  let useSide: Side = side;
  if (mode === 'PRICE') {
    const s = parseToMinor(stop, ps) ?? 0;
    const p = positionSize(capMinor, riskBps, entryMinor, s);
    r = p && { ...p, distance: Math.abs(entryMinor - s) };
    stopMinor = s || null;
    useSide = s < entryMinor ? 'SELL' : 'BUY';
  } else if (atrReady) {
    r = atrPositionSize(capMinor, riskBps, a.atr, parseToMinor(k, 2) ?? 0);
    stopMinor = r ? stopFromDistance(entryMinor, r.distance, side) : null;
    // The protective stop closes the position: a long is protected by a SELL stop.
    useSide = side === 'BUY' ? 'SELL' : 'BUY';
  }
  const riskMoney = r && r.riskBudget > 0 ? r.riskBudget : null;
  useEffect(() => {
    onRisk?.(riskMoney);
  }, [riskMoney, onRisk]);

  const money = (m: number) => `${formatMinor(m, ps, i18n.language)} ${instrument.quote}`;

  return (
    <Card style={{ gap: 10 }}>
      <Title>{t('size.title')}</Title>
      <Segmented testIDPrefix="size-mode" value={mode} onChange={setMode} options={[{ value: 'PRICE', label: t('size.modePrice') }, { value: 'ATR', label: t('size.modeAtr') }]} />
      <Caption>{t(mode === 'PRICE' ? 'size.formula' : 'size.formulaAtr')}</Caption>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Field testID="size-capital" label={t('size.capital', { quote: instrument.quote })} value={cap} onChange={setCap} />
        <Field testID="size-risk" label={t('size.risk')} value={risk} onChange={setRisk} />
      </View>
      {mode === 'PRICE' ? (
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <Field testID="size-entry" label={t('size.entry', { quote: instrument.quote })} value={entry} onChange={setEntry} />
          <Field testID="size-stop" label={t('size.stop', { quote: instrument.quote })} value={stop} onChange={setStop} />
        </View>
      ) : (
        <View style={{ gap: 8 }}>
          <Card style={{ gap: 4, padding: 10 }}>
            {atrReady ? (
              <>
                <Line label={t('size.atr', { period: ATR_PERIOD })} value={money(a.atr!)} testID="size-atr" />
                {a.atrBps != null && <Line label={t('size.atrPct')} value={`${bpsToPercent(a.atrBps, dec)}%`} />}
                <Caption>{t('size.atrHint')}</Caption>
              </>
            ) : (
              <Caption color={c.warning} testID="size-atr-not-ready">
                {atr.error ? t('errors.NETWORK') : a ? t('size.atrNotReady', { have: a.candles, need: a.period + 1 }) : '…'}
              </Caption>
            )}
          </Card>
          <Segmented testIDPrefix="size-side" value={side} onChange={setSide} options={[{ value: 'BUY', label: t('size.long') }, { value: 'SELL', label: t('size.short') }]} />
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <Field testID="size-entry" label={t('size.entry', { quote: instrument.quote })} value={entry} onChange={setEntry} />
            <Field testID="size-k" label={t('size.k')} value={k} onChange={setK} />
          </View>
        </View>
      )}
      {r ? (
        <View style={{ gap: 4 }}>
          <Line label={t('size.budget')} value={money(r.riskBudget)} testID="size-budget" />
          <Line label={t('size.perUnit')} value={money(r.distance)} />
          {mode === 'ATR' && <Line label={t('size.stopAt')} value={stopMinor ? money(stopMinor) : '—'} testID="size-stop-at" />}
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <Body bold>{t('size.qty')}</Body>
            <Body bold num>
              {r.qty} {instrument.base}
            </Body>
          </View>
          <Line label={t('size.atRisk')} value={money(r.atRisk)} color={c.negative} testID="size-at-risk" />
          <Caption>{t('size.oneR')}</Caption>
        </View>
      ) : (
        <Caption>{t(mode === 'PRICE' ? 'size.fill' : 'size.fillAtr')}</Caption>
      )}
      <View style={{ flexDirection: 'row' }}>
        <Button testID="size-use" title={t('size.use')} disabled={!r || r.qty === 0 || !stopMinor} onPress={() => r && stopMinor && onUse(String(r.qty), plain(stopMinor, ps), useSide)} />
      </View>
    </Card>
  );
}
