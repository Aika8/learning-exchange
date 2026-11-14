import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { getLocales } from 'expo-localization';
import ru from './ru.json';
import en from './en.json';
import { useSession } from '../store/session';

// ADR-0014: keys only; the device language is the first guess, the user's choice wins; ru is the fallback.
const device = getLocales()[0]?.languageCode === 'en' ? 'en' : 'ru';

void i18n.use(initReactI18next).init({
  resources: { ru: { translation: ru }, en: { translation: en } },
  lng: device,
  fallbackLng: 'ru',
  interpolation: { escapeValue: false },
});

// Observer: when the stored choice arrives or changes, the UI re-renders through react-i18next.
useSession.subscribe((s) => {
  if (s.lang && s.lang !== i18n.language) void i18n.changeLanguage(s.lang);
});

export default i18n;
