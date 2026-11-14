import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useQueryClient } from '@tanstack/react-query';
import { getToken, setToken } from './api/client';
import { MarketSocket } from './api/socket';
import { useInstrument, useMarket } from './hooks';
import { Login } from './components/Login';
import { Ladder } from './components/Ladder';
import { TradesTape } from './components/TradesTape';
import { OrderForm } from './components/OrderForm';
import { MyOrders } from './components/MyOrders';
import { Balances } from './components/Balances';
import { ClockBar } from './components/ClockBar';
import { LangSwitch } from './components/LangSwitch';

export function App() {
  const { t } = useTranslation();
  const [token, setTok] = useState<string | null>(getToken());
  const qc = useQueryClient();
  const socket = useMemo(() => (token ? new MarketSocket(token) : null), [token]);
  useEffect(() => () => socket?.close(), [socket]);
  const { book, trades, clock } = useMarket(socket);
  const instrument = useInstrument().data;

  const login = (tok: string) => {
    setToken(tok);
    setTok(tok);
  };
  const logout = () => {
    setToken(null);
    setTok(null);
    qc.clear();
  };

  return (
    <div className="app">
      <header>
        <h1>{t('app.title')}</h1>
        <span className="chip">{t('app.practice')}</span>
        <div className="spacer" />
        {token && <ClockBar clock={clock} />}
        <LangSwitch />
        {token && (
          <button className="ghost" onClick={logout} data-testid="logout">
            {t('app.logout')}
          </button>
        )}
      </header>
      {!token || !instrument ? (
        !token ? <Login onLogin={login} /> : null
      ) : (
        <main className="grid">
          <section className="card book">
            <Ladder book={book} instrument={instrument} />
          </section>
          <section className="card tape">
            <TradesTape trades={trades} instrument={instrument} />
          </section>
          <section className="card form">
            <OrderForm instrument={instrument} book={book} />
          </section>
          <section className="card balances">
            <Balances />
          </section>
          <section className="card orders">
            <MyOrders instrument={instrument} />
          </section>
        </main>
      )}
    </div>
  );
}
