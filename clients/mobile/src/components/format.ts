import { useTranslation } from 'react-i18next';
import { bpsToPercent } from '../finance';
import { formatX100, signedPercent } from '../m2b';
import { formatMinor } from '../money';

/** Shared formatters for the M2b screens: SPARK money (scale 2), percents from bps, ×100 ratios, simulation dates. */
export function useFmt() {
  const { i18n } = useTranslation();
  const lang = i18n.language;
  const dec = lang.startsWith('ru') ? ',' : '.';
  const dt = new Intl.DateTimeFormat(lang, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  const d = new Intl.DateTimeFormat(lang, { day: 'numeric', month: 'short', year: 'numeric' });
  return {
    lang,
    dec,
    money: (m: number, scale = 2, cur = 'SPARK') => `${formatMinor(m, scale, lang)}${cur ? ` ${cur}` : ''}`,
    pct: (bps: number) => `${bpsToPercent(bps, dec)}%`,
    signed: (bps: number) => signedPercent(bps, dec),
    x100: (v: number) => formatX100(v, dec),
    when: (ms: number) => dt.format(ms),
    date: (ms: number) => d.format(ms),
  };
}
