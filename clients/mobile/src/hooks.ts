import { createContext, useContext, useEffect, useState } from 'react';
import { type QueryClient, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, call, type BookSnapshot, type Instrument, type Trade } from './api/client';
import type { MarketSocket } from './api/socket';
import { INSTRUMENT } from './config';

export const SocketContext = createContext<MarketSocket | null>(null);

export function useInstrument(id: string = INSTRUMENT) {
  return useQuery({
    queryKey: ['instruments'],
    queryFn: () => call(api.GET('/instruments')),
    select: (list: Instrument[]) => list.find((i) => i.id === id),
    staleTime: Infinity,
  });
}

export function useMe() {
  return useQuery({ queryKey: ['me'], queryFn: () => call(api.GET('/me')) });
}

/** Account nudges (ORDER, TRADE, DEPOSIT, CONDITIONAL, MARGIN, SAVINGS) all mean «refetch what the account shows». */
export function refetchAccount(qc: QueryClient) {
  for (const key of ['me', 'orders', 'conditional', 'savings', 'statement', 'achievements']) void qc.invalidateQueries({ queryKey: [key] });
}

export function useConditionalOrders() {
  return useQuery({ queryKey: ['conditional'], queryFn: () => call(api.GET('/conditional-orders')) });
}

export function useSavings() {
  return useQuery({ queryKey: ['savings'], queryFn: () => call(api.GET('/savings')) });
}

export function useClock() {
  return useQuery({ queryKey: ['clock'], queryFn: () => call(api.GET('/clock')), refetchInterval: 5000 });
}

export function useOpenOrders() {
  return useQuery({
    queryKey: ['orders', true],
    queryFn: () => call(api.GET('/orders', { params: { query: { open: true, limit: 20 } } })),
  });
}

/** REST is the first picture; the WebSocket keeps it live. Account nudges refetch balances and orders. */
export function useLiveMarket(instrumentId: string = INSTRUMENT) {
  const socket = useContext(SocketContext);
  const qc = useQueryClient();
  const me = useMe().data;
  const [book, setBook] = useState<BookSnapshot | null>(null);
  const [trades, setTrades] = useState<Trade[]>([]);

  useEffect(() => {
    if (!socket) return;
    setBook(null);
    setTrades([]);
    const offs = [
      socket.subscribe(`market.${instrumentId}.book`, (d) => setBook(d as BookSnapshot)),
      socket.subscribe(`market.${instrumentId}.trades`, (d) =>
        setTrades((prev) => [...(d as Trade[]).slice().reverse(), ...prev].slice(0, 20)),
      ),
    ];
    return () => offs.forEach((off) => off());
  }, [socket, instrumentId]);

  useEffect(() => {
    if (!socket || !me) return;
    return socket.subscribe(`account.${me.accountId}`, () => refetchAccount(qc));
  }, [socket, me, qc]);

  return { book, trades };
}

/** Account nudges only (home screen): keeps balances fresh when an order fills elsewhere. */
export function useAccountNudges() {
  const socket = useContext(SocketContext);
  const qc = useQueryClient();
  const me = useMe().data;
  useEffect(() => {
    if (!socket || !me) return;
    return socket.subscribe(`account.${me.accountId}`, () => refetchAccount(qc));
  }, [socket, me, qc]);
}

// ---- M2b: catalogue (real names only), companies, economy, bonds, real world ----

export function useInstruments() {
  return useQuery({ queryKey: ['instruments'], queryFn: () => call(api.GET('/instruments')), refetchInterval: 10_000 });
}

/** Mobile BFF catalogue: real display names only; the app never asks the game BFF. */
export function useCatalogue() {
  return useQuery({ queryKey: ['catalogue'], queryFn: () => call(api.GET('/bff/mobile/catalogue')), staleTime: Infinity });
}

/** Display name of an instrument in the current language, falling back to its id. */
export function useDisplayName() {
  const list = useCatalogue().data;
  return (id: string, lang: string) => {
    const item = list?.find((i) => i.instrument === id);
    return item ? (lang.startsWith('ru') ? item.real.ru : item.real.en) : id;
  };
}

export function useCompanyCard(id: string) {
  return useQuery({ queryKey: ['company', id], queryFn: () => call(api.GET('/bff/mobile/companies/{instrumentId}', { params: { path: { instrumentId: id } } })), refetchInterval: 5000 });
}

export function useCandles(id: string, limit = 60) {
  return useQuery({ queryKey: ['candles', id, limit], queryFn: () => call(api.GET('/instruments/{instrumentId}/candles', { params: { path: { instrumentId: id }, query: { limit } } })), refetchInterval: 10_000 });
}

export function useCalendar() {
  return useQuery({ queryKey: ['calendar'], queryFn: () => call(api.GET('/economy/calendar')), refetchInterval: 5000 });
}

export function useMacro() {
  return useQuery({ queryKey: ['macro'], queryFn: () => call(api.GET('/economy/rates')), refetchInterval: 5000 });
}

export function useBonds() {
  return useQuery({ queryKey: ['bonds'], queryFn: () => call(api.GET('/bonds')), refetchInterval: 5000 });
}

export function useRealWorld() {
  return useQuery({ queryKey: ['real-world'], queryFn: () => call(api.GET('/real-world')), refetchInterval: 60_000 });
}

export function usePaperPositions() {
  return useQuery({ queryKey: ['paper'], queryFn: () => call(api.GET('/real-world/paper-positions')), refetchInterval: 30_000 });
}

// ---- M2c: ATR, funds, session review ----

export function useAtr(id: string, period = 14) {
  return useQuery({ queryKey: ['atr', id, period], queryFn: () => call(api.GET('/instruments/{instrumentId}/atr', { params: { path: { instrumentId: id }, query: { period } } })), refetchInterval: 30_000 });
}

export function useFunds() {
  return useQuery({ queryKey: ['funds'], queryFn: () => call(api.GET('/funds')), refetchInterval: 10_000 });
}

export function useFund(id: string) {
  return useQuery({ queryKey: ['fund', id], queryFn: () => call(api.GET('/funds/{instrumentId}', { params: { path: { instrumentId: id } } })), refetchInterval: 10_000 });
}

export function useSessionReview() {
  return useQuery({ queryKey: ['session-review'], queryFn: () => call(api.GET('/session-review')), refetchInterval: 15_000 });
}

/** M4: achievements shared with the game (a projection of the same account's events). */
export function useAchievements() {
  return useQuery({ queryKey: ['achievements'], queryFn: () => call(api.GET('/achievements')) });
}
