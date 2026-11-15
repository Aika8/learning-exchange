import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { BookSnapshot, Clock, Instrument } from '../api/client';
import { StopForm } from './StopForm';
import { StopsList } from './StopsList';
import { Margin } from './Margin';
import { StatementPanel } from './StatementPanel';
import { Savings } from './Savings';

type Tab = 'stops' | 'margin' | 'statement' | 'savings';

export function M2aPanels({ instrument, book, clock }: { instrument: Instrument; book: BookSnapshot | null; clock: Clock | null }) {
  const { t } = useTranslation();
  const [tab, setTab] = useState<Tab>('stops');
  const tabs: Tab[] = instrument.maxLeverage > 1 ? ['stops', 'margin', 'statement', 'savings'] : ['stops', 'statement', 'savings'];
  const current = tabs.includes(tab) ? tab : 'stops';

  return (
    <>
      <div className="tabs" role="tablist">
        {tabs.map((x) => (
          <button key={x} role="tab" className={x === current ? 'on' : ''} onClick={() => setTab(x)} data-testid={`tab-${x}`}>
            {t(`tabs.${x}`)}
          </button>
        ))}
      </div>
      {current === 'stops' && (
        <div className="split">
          <StopForm key={instrument.id} instrument={instrument} />
          <div>
            <StopsList instrument={instrument} />
          </div>
        </div>
      )}
      {current === 'margin' && <Margin key={instrument.id} instrument={instrument} book={book} />}
      {current === 'statement' && <StatementPanel clock={clock} />}
      {current === 'savings' && <Savings />}
    </>
  );
}
