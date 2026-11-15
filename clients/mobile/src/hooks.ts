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
  for (const key of ['me', 'orders', 'conditional', 'savings', 'statement']) void qc.invalidateQueries({ queryKey: [key] });
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
