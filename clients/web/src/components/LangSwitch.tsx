import { useTranslation } from 'react-i18next';

export function LangSwitch() {
  const { t, i18n } = useTranslation();
  return (
    <div className="segmented small" aria-label={t('lang.label')}>
      {(['ru', 'en'] as const).map((l) => (
        <button key={l} className={i18n.language === l ? 'on' : ''} onClick={() => void i18n.changeLanguage(l)} data-testid={`lang-${l}`}>
          {t(`lang.${l}`)}
        </button>
      ))}
    </div>
  );
}
