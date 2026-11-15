import { useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api, unwrap, type AccountChanged, type BookSnapshot, type Clock, type Trade } from './api/client';
import { MarketSocket } from './api/socket';
import { queriesFor } from './m2a';

export function useInstruments() {
  return useQuery({
    queryKey: ['instruments'],
    queryFn: async () => unwrap(await api.GET('/instruments')),
    refetchInterval: 5_000, // tradingOpen changes on report nights
  });
}

export function useMe() {
  return useQuery({ queryKey: ['me'], queryFn: async () => unwrap(await api.GET('/me')) });
}

export function useMyOrders(openOnly: boolean) {
  return useQuery({
    queryKey: ['orders', openOnly],
    queryFn: async () => unwrap(await api.GET('/orders', { params: { query: { open: openOnly, limit: 30 } } })),
  });
}

export function useConditionals() {
  return useQuery({ queryKey: ['conditional'], queryFn: async () => unwrap(await api.GET('/conditional-orders')) });
}

export function useMarginPositions() {
  return useQuery({ queryKey: ['margin'], queryFn: async () => unwrap(await api.GET('/margin/positions')) });
}

export function useSavings() {
  return useQuery({ queryKey: ['savings'], queryFn: async () => unwrap(await api.GET('/savings')) });
}

export function useStatement(from: number | undefined, to: number | undefined) {
  return useQuery({
    queryKey: ['statement', from, to],
    queryFn: async () => unwrap(await api.GET('/statement', { params: { query: { from, to } } })),
  });
}

/** Live market data for one instrument: WebSocket pushes (book replaced, trades prepended); reset on switch. */
export function useMarket(socket: MarketSocket | null, instrumentId: string) {
  const [book, setBook] = useState<BookSnapshot | null>(null);
  const [trades, setTrades] = useState<Trade[]>([]);
  const [clock, setClock] = useState<Clock | null>(null);
  const qc = useQueryClient();

  useEffect(() => {
    if (!socket) return;
    setBook(null);
    setTrades([]);
    const offs = [
      socket.subscribe(`market.${instrumentId}.book`, (d) => setBook(d as BookSnapshot)),
      socket.subscribe(`market.${instrumentId}.trades`, (d) =>
        setTrades((prev) => [...(d as Trade[]).slice().reverse(), ...prev].slice(0, 40)),
      ),
    ];
    return () => offs.forEach((off) => off());
  }, [socket, instrumentId]);

  useEffect(() => (socket ? socket.subscribe('clock', (d) => setClock(d as Clock)) : undefined), [socket]);

  // Account nudges: refetch what the server says changed (balances and orders always, plus M2a parts by reason).
  useEffect(() => {
    if (!socket) return;
    let off = () => {};
    void api.GET('/me').then((r) => {
      if (r.data) {
        off = socket.subscribe(`account.${r.data.accountId}`, (d) => {
          for (const key of queriesFor((d as AccountChanged | undefined)?.reasons ?? [])) {
            void qc.invalidateQueries({ queryKey: [key] });
          }
        });
      }
    });
    return () => off();
  }, [socket, qc]);

  return { book, trades, clock };
}

// M2b: public market data refreshes on a short interval (reports, decisions and coupons arrive with simulation time).
const LIVE = { refetchInterval: 5_000 };

export function useCompanies() {
  return useQuery({ queryKey: ['companies'], queryFn: async () => unwrap(await api.GET('/companies')), ...LIVE });
}

export function useCalendar() {
  return useQuery({ queryKey: ['calendar'], queryFn: async () => unwrap(await api.GET('/economy/calendar')), ...LIVE });
}

export function useMacro() {
  return useQuery({ queryKey: ['macro'], queryFn: async () => unwrap(await api.GET('/economy/rates')), ...LIVE });
}

export function useBonds() {
  return useQuery({ queryKey: ['bonds'], queryFn: async () => unwrap(await api.GET('/bonds')), ...LIVE });
}

export function useRealWorld() {
  return useQuery({ queryKey: ['realWorld'], queryFn: async () => unwrap(await api.GET('/real-world')), refetchInterval: 30_000 });
}

export function usePaperPositions() {
  return useQuery({ queryKey: ['paper'], queryFn: async () => unwrap(await api.GET('/real-world/paper-positions')), ...LIVE });
}

// M2c
export function useAtr(instrumentId: string, period = 14) {
  return useQuery({
    queryKey: ['atr', instrumentId, period],
    queryFn: async () => unwrap(await api.GET('/instruments/{instrumentId}/atr', { params: { path: { instrumentId }, query: { period } } })),
    ...LIVE,
  });
}

export function useSessionReview() {
  return useQuery({ queryKey: ['review'], queryFn: async () => unwrap(await api.GET('/session-review')), ...LIVE });
}

export function useFunds() {
  return useQuery({ queryKey: ['funds'], queryFn: async () => unwrap(await api.GET('/funds')), ...LIVE });
}
