// Product name and backend address live here and only here.
export const APP_NAME = 'learning-exchange · debug';
export const API_URL: string = import.meta.env.VITE_API_URL ?? 'http://localhost:8080';
export const WS_URL = API_URL.replace(/^http/, 'ws') + '/ws';
/** Instrument selected on first load; the user can switch in the header. */
export const DEFAULT_INSTRUMENT = 'SILK-SPARK';
