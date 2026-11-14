import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import ru from './ru.json';
import en from './en.json';

// ADR-0014: keys only in UI code; ru is the fallback; the choice is remembered; switching re-renders (Observer).
const saved = localStorage.getItem('lang');
void i18n.use(initReactI18next).init({
  resources: { ru: { translation: ru }, en: { translation: en } },
  lng: saved === 'en' || saved === 'ru' ? saved : navigator.language.startsWith('ru') ? 'ru' : 'en',
  fallbackLng: 'ru',
  interpolation: { escapeValue: false },
});
i18n.on('languageChanged', (lng) => {
  localStorage.setItem('lang', lng);
  document.documentElement.lang = lng;
});

export default i18n;
