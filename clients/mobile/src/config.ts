import Constants from 'expo-constants';

// One place for product name and backend address (renaming is a one-line change; bundle ids live in app.json).
export const APP_NAME = 'Ветрило';
export const API_URL: string =
  process.env.EXPO_PUBLIC_API_URL ?? (Constants.expoConfig?.extra?.apiUrl as string | undefined) ?? 'http://localhost:8080';
export const WS_URL = API_URL.replace(/^http/, 'ws') + '/ws';
export const INSTRUMENT = 'SILK-SPARK';
