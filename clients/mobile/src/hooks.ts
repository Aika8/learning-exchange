import { createContext, useContext, useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api, call, type BookSnapshot, type Instrument, type Trade } from './api/client';
import type { MarketSocket } from './api/socket';
import { INSTRUMENT } from './config';

export const SocketContext = createContext<MarketSocket | null>(null);

export function useInstrument() {
  return useQuery({
    queryKey: ['instruments'],
    queryFn: () => call(api.GET('/instruments')),
    select: (list: Instrument[]) => list.find((i) => i.id === INSTRUMENT),
    staleTime: Infinity,
  });
}

export function useMe() {
  return useQuery({ queryKey: ['me'], queryFn: () => call(api.GET('/me')) });
}

export function useOpenOrders() {
  return useQuery({
    queryKey: ['orders', true],
    queryFn: () => call(api.GET('/orders', { params: { query: { open: true, limit: 20 } } })),
  });
}

/** REST is the first picture; the WebSocket keeps it live. Account nudges refetch balances and orders. */
export function useLiveMarket() {
  const socket = useContext(SocketContext);
  const qc = useQueryClient();
  const me = useMe().data;
  const [book, setBook] = useState<BookSnapshot | null>(null);
  const [trades, setTrades] = useState<Trade[]>([]);

  useEffect(() => {
    if (!socket) return;
    const offs = [
      socket.subscribe(`market.${INSTRUMENT}.book`, (d) => setBook(d as BookSnapshot)),
      socket.subscribe(`market.${INSTRUMENT}.trades`, (d) =>
        setTrades((prev) => [...(d as Trade[]).slice().reverse(), ...prev].slice(0, 20)),
      ),
    ];
    return () => offs.forEach((off) => off());
  }, [socket]);

  useEffect(() => {
    if (!socket || !me) return;
    return socket.subscribe(`account.${me.accountId}`, () => {
      void qc.invalidateQueries({ queryKey: ['me'] });
      void qc.invalidateQueries({ queryKey: ['orders'] });
    });
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
    return socket.subscribe(`account.${me.accountId}`, () => {
      void qc.invalidateQueries({ queryKey: ['me'] });
      void qc.invalidateQueries({ queryKey: ['orders'] });
    });
  }, [socket, me, qc]);
}
