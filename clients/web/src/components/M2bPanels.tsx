import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { Clock, Instrument } from '../api/client';
import { Companies } from './Companies';
import { Calendar } from './Calendar';
import { Bonds } from './Bonds';
import { RealWorldPanel } from './RealWorldPanel';

type Tab = 'companies' | 'calendar' | 'bonds' | 'realWorld';
const TABS: Tab[] = ['companies', 'calendar', 'bonds', 'realWorld'];

export function M2bPanels({ instrument, clock }: { instrument: Instrument; clock: Clock | null }) {
  const { t } = useTranslation();
  const [tab, setTab] = useState<Tab>('companies');
  return (
    <>
      <div className="tabs" role="tablist">
        {TABS.map((x) => (
          <button key={x} role="tab" className={x === tab ? 'on' : ''} onClick={() => setTab(x)} data-testid={`tab-${x}`}>
            {t(`tabs.${x}`)}
          </button>
        ))}
      </div>
      {tab === 'companies' && <Companies current={instrument} now={clock?.now} />}
      {tab === 'calendar' && <Calendar />}
      {tab === 'bonds' && <Bonds />}
      {tab === 'realWorld' && <RealWorldPanel />}
    </>
  );
}

/** Simulation or real time (ms) as a short local date-time. */
export function useTime() {
  const { i18n } = useTranslation();
  return (ts: number | null | undefined) =>
    ts == null ? '—' : new Date(ts).toLocaleString(i18n.language, { dateStyle: 'short', timeStyle: 'short' });
}
