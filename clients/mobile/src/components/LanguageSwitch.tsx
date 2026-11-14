import { useTranslation } from 'react-i18next';
import { useSession } from '../store/session';
import { Caption, Card, Segmented } from './ui';

/** Runtime language switch (ADR-0014): the store change is observed by i18n, and every screen re-renders. */
export function LanguageSwitch() {
  const { t, i18n } = useTranslation();
  const setLang = useSession((s) => s.setLang);
  return (
    <Card style={{ gap: 8 }}>
      <Caption>{t('settings.language')}</Caption>
      <Segmented
        testIDPrefix="lang"
        value={i18n.language === 'en' ? 'en' : 'ru'}
        onChange={(l) => {
          setLang(l);
          void i18n.changeLanguage(l);
        }}
        options={[
          { value: 'ru', label: t('settings.ru') },
          { value: 'en', label: t('settings.en') },
        ]}
      />
    </Card>
  );
}
