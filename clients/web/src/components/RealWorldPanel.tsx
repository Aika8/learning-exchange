import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, unwrap, type RealSource } from '../api/client';
import { usePaperPositions, useRealWorld } from '../hooks';
import { formatMinor, parseToMinor } from '../money';
import { bpsPercent } from '../m2a';
import { useTime } from './M2bPanels';

function SourceBadge({ s }: { s: RealSource }) {
  const { t } = useTranslation();
  return (
    <>
      <span className="hint">
        {s.url ? <a href={s.url} target="_blank" rel="noreferrer">{s.name}</a> : s.name}
      </span>
      {s.sample && <span className="badge warn small" data-testid="sample-badge">{t('real.sample')}</span>}
      {s.delayed && <span className="chip">{t('real.delayed')}</span>}
    </>
  );
}

export function RealWorldPanel() {
  const { t, i18n } = useTranslation();
  const time = useTime();
  const qc = useQueryClient();
  const rw = useRealWorld().data;
  const papers = usePaperPositions().data ?? [];
  const [symbol, setSymbol] = useState('');
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');
  const [qty, setQty] = useState('1');
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const sym = symbol || rw?.quotes[0]?.symbol || '';
  const qtyUnits = parseToMinor(qty, 0);
  const scaleOf = (s: string) => rw?.quotes.find((q) => q.symbol === s)?.scale ?? 2;
  const quoteOf = (s: string) => rw?.quotes.find((q) => q.symbol === s)?.quoteCurrency ?? '';
  const pct = (bps: number) => `${bpsPercent(bps, i18n.language)}%`;
  const onError = (e: Error) => setMessage({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`) });
  const refresh = () => void qc.invalidateQueries({ queryKey: ['paper'] });

  const open = useMutation({
    mutationFn: async () =>
      unwrap(
        await api.POST('/real-world/paper-positions', {
          params: { header: { 'Idempotency-Key': crypto.randomUUID() } },
          body: { symbol: sym, side, qty: qtyUnits! },
        }),
      ),
    onSuccess: (p) => {
      setMessage({ ok: true, text: t('real.opened', { id: p.paperId }) });
      refresh();
    },
    onError,
  });
  const close = useMutation({
    mutationFn: async (id: number) =>
      unwrap(await api.POST('/real-world/paper-positions/{paperId}/close', { params: { path: { paperId: id } } })),
    onSuccess: refresh,
    onError,
  });

  return (
    <div data-testid="real-world">
      <h2>{t('real.title')}</h2>
      <p className="hint">{t('real.hint')}</p>
      <table>
        <thead>
          <tr>
            <th>{t('real.symbol')}</th>
            <th>{t('real.price')}</th>
            <th>{t('real.asOf')}</th>
            <th>{t('real.source')}</th>
          </tr>
        </thead>
        <tbody>
          {rw?.quotes.map((q) => (
            <tr key={q.symbol}>
              <td>{q.symbol}</td>
              <td>
                {formatMinor(q.price, q.scale, i18n.language)} {q.quoteCurrency}
              </td>
              <td>{time(q.asOf)}</td>
              <td>
                <SourceBadge s={q.source} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {rw?.baseRate && (
        <>
          <h3>
            {t('real.baseRate', { bank: rw.baseRate.bank })}: {pct(rw.baseRate.rateBps)}{' '}
            <span className="hint">{t('real.asOfShort', { at: time(rw.baseRate.asOf) })}</span> <SourceBadge s={rw.baseRate.source} />
          </h3>
          <p className="hint">
            {t('real.history')}:{' '}
            {rw.baseRate.history
              .slice()
              .reverse()
              .map((d) => `${new Date(d.date).toLocaleDateString(i18n.language)} — ${pct(d.rateBps)}`)
              .join(' · ')}
            {rw.baseRate.upcoming.length > 0 && (
              <>
                {' '}| {t('real.upcoming')}: {rw.baseRate.upcoming.map((d) => new Date(d).toLocaleDateString(i18n.language)).join(', ')}
              </>
            )}
          </p>
        </>
      )}
      <h3>
        {t('real.papers')} <span className="badge small">{t('real.paperLabel')}</span>
      </h3>
      <form
        className="row"
        onSubmit={(e) => {
          e.preventDefault();
          setMessage(null);
          open.mutate();
        }}
      >
        <label>
          {t('real.symbol')}
          <select value={sym} onChange={(e) => setSymbol(e.target.value)}>
            {rw?.quotes.map((q) => (
              <option key={q.symbol}>{q.symbol}</option>
            ))}
          </select>
        </label>
        <div className="segmented small">
          {(['BUY', 'SELL'] as const).map((s) => (
            <button type="button" key={s} className={s === side ? `on ${s === 'BUY' ? 'buy' : 'sell'}` : ''} onClick={() => setSide(s)}>
              {t(`side.${s}`)}
            </button>
          ))}
        </div>
        <label>
          {t('real.qty')}
          <input value={qty} onChange={(e) => setQty(e.target.value)} inputMode="numeric" size={6} />
        </label>
        <button type="submit" disabled={!sym || qtyUnits === null || open.isPending} data-testid="paper-open">
          {t('real.open')}
        </button>
        {message && <p className={message.ok ? 'ok' : 'error'}>{message.text}</p>}
      </form>
      <table data-testid="paper-positions">
        <thead>
          <tr>
            <th>#</th>
            <th>{t('real.symbol')}</th>
            <th>{t('orders.side')}</th>
            <th>{t('real.qty')}</th>
            <th>{t('real.entry')}</th>
            <th>{t('real.current')}</th>
            <th>{t('real.pnl')}</th>
            <th>{t('real.quotedAt')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {papers.length === 0 && (
            <tr>
              <td colSpan={9}>{t('real.noPapers')}</td>
            </tr>
          )}
          {papers.map((p) => {
            const sc = scaleOf(p.symbol);
            return (
              <tr key={p.paperId}>
                <td>
                  {p.paperId} <span className="chip">{t('real.paperLabel')}</span>
                </td>
                <td>{p.symbol}</td>
                <td className={p.side === 'BUY' ? 'bid' : 'ask'}>{t(`side.${p.side}`)}</td>
                <td>{p.qty}</td>
                <td>{formatMinor(p.entryPrice, sc, i18n.language)}</td>
                <td>{formatMinor(p.open ? p.currentPrice : (p.exitPrice ?? p.currentPrice), sc, i18n.language)}</td>
                <td className={p.pnl < 0 ? 'error' : 'ok'}>
                  {formatMinor(p.pnl, sc, i18n.language)} {quoteOf(p.symbol)}
                </td>
                <td>
                  {time(p.quotedAt)} <span className="hint">{p.source}</span>
                </td>
                <td>
                  {p.open ? (
                    <button className="ghost" onClick={() => close.mutate(p.paperId)} disabled={close.isPending}>
                      {t('real.close')}
                    </button>
                  ) : (
                    <span className="hint">{t('real.closed')}</span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
