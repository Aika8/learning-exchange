import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Local UI state (ADR-0010: Zustand). Server state stays in TanStack Query.
type Session = {
  token: string | null;
  lang: 'ru' | 'en' | null;
  setToken: (token: string | null) => void;
  setLang: (lang: 'ru' | 'en') => void;
};

export const useSession = create<Session>()(
  persist(
    (set) => ({
      token: null,
      lang: null,
      setToken: (token) => set({ token }),
      setLang: (lang) => set({ lang }),
    }),
    { name: 'vetrilo-session', storage: createJSONStorage(() => AsyncStorage) },
  ),
);
