import { useTranslation } from 'react-i18next';
import type { Instrument } from '../api/client';

export function InstrumentSwitch({ list, value, onChange }: { list: Instrument[]; value: string; onChange: (id: string) => void }) {
  const { t } = useTranslation();
  return (
    <div className="segmented small" role="group" aria-label={t('instrument.label')} data-testid="instrument-switch">
      {list.map((i) => (
        <button key={i.id} className={i.id === value ? 'on' : ''} onClick={() => onChange(i.id)} data-testid={`instrument-${i.id}`}>
          {i.id}
          {i.maxLeverage > 1 ? ` · ${t('instrument.leverageUpTo', { n: i.maxLeverage })}` : ''}
        </button>
      ))}
    </div>
  );
}
