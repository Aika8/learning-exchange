import { useTranslation } from 'react-i18next';
import { api, type Clock } from '../api/client';

const SPEEDS = [1, 5, 20, 60];

/** Simulation clock: pause/resume and speed (ADR-0006). Bots stop while paused. */
export function ClockBar({ clock }: { clock: Clock | null }) {
  const { t, i18n } = useTranslation();
  if (!clock) return null;
  const set = (paused: boolean, speed: number) => void api.PUT('/clock', { body: { paused, speed } });
  const time = new Intl.DateTimeFormat(i18n.language, { dateStyle: 'short', timeStyle: 'medium' }).format(clock.now);
  return (
    <div className="clock" data-testid="clock">
      <span title={t('clock.title')}>
        🕓 {time} {clock.paused && <b>({t('clock.paused')})</b>}
      </span>
      <button className="ghost" onClick={() => set(!clock.paused, clock.speed)} data-testid="clock-toggle">
        {clock.paused ? t('clock.resume') : t('clock.pause')}
      </button>
      <label className="inline">
        {t('clock.speed')}
        <select value={clock.speed} onChange={(e) => set(clock.paused, Number(e.target.value))}>
          {SPEEDS.map((s) => (
            <option key={s} value={s}>
              ×{s}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
