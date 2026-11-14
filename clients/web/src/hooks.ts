import { useEffect, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { api, unwrap, type BookSnapshot, type Clock, type Instrument, type Trade } from './api/client';
import { MarketSocket } from './api/socket';
import { INSTRUMENT } from './config';

export function useInstrument() {
  return useQuery({
    queryKey: ['instruments'],
    queryFn: async () => unwrap(await api.GET('/instruments')),
    select: (list: Instrument[]) => list.find((i) => i.id === INSTRUMENT),
    staleTime: Infinity,
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

/** Live market data: REST snapshot first, then WebSocket pushes (book replaced, trades prepended). */
export function useMarket(socket: MarketSocket | null) {
  const [book, setBook] = useState<BookSnapshot | null>(null);
  const [trades, setTrades] = useState<Trade[]>([]);
  const [clock, setClock] = useState<Clock | null>(null);
  const qc = useQueryClient();

  useEffect(() => {
    if (!socket) return;
    const offs = [
      socket.subscribe(`market.${INSTRUMENT}.book`, (d) => setBook(d as BookSnapshot)),
      socket.subscribe(`market.${INSTRUMENT}.trades`, (d) =>
        setTrades((prev) => [...(d as Trade[]).slice().reverse(), ...prev].slice(0, 40)),
      ),
      socket.subscribe('clock', (d) => setClock(d as Clock)),
    ];
    return () => offs.forEach((off) => off());
  }, [socket]);

  // Account nudges: refetch my balances and orders when the server says something changed.
  useEffect(() => {
    if (!socket) return;
    let off = () => {};
    void api.GET('/me').then((r) => {
      if (r.data) {
        off = socket.subscribe(`account.${r.data.accountId}`, () => {
          void qc.invalidateQueries({ queryKey: ['me'] });
          void qc.invalidateQueries({ queryKey: ['orders'] });
        });
      }
    });
    return () => off();
  }, [socket, qc]);

  return { book, trades, clock };
}
