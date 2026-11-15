import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, unwrap, type BookSnapshot, type Instrument, type MarginPosition } from '../api/client';
import { useMarginPositions } from '../hooks';
import { collateralPreview, equityPercent } from '../m2a';
import { formatMinor, parseToMinor } from '../money';

export function Margin({ instrument, book }: { instrument: Instrument; book: BookSnapshot | null }) {
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY');
  const [qty, setQty] = useState('100');
  const [leverage, setLeverage] = useState(instrument.maxLeverage);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const positions = (useMarginPositions().data ?? []).filter((p) => p.instrument === instrument.id);
  const money = (v: number | null | undefined) => (v == null ? '—' : formatMinor(v, instrument.priceScale, i18n.language));

  const qtyUnits = parseToMinor(qty, instrument.qtyScale);
  const ref = (side === 'BUY' ? book?.asks[0]?.price : book?.bids[0]?.price) ?? book?.lastPrice ?? null;
  const collateral = ref && qtyUnits ? collateralPreview(ref, qtyUnits, leverage) : null;
  const refresh = () => ['margin', 'me', 'statement'].forEach((k) => void qc.invalidateQueries({ queryKey: [k] }));
  const onError = (e: Error) => setMessage({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`) });

  const open = useMutation({
    mutationFn: async () =>
      unwrap(
        await api.POST('/margin/positions', {
          
          body: { instrument: instrument.id, side, qty: qtyUnits!, leverage },
        }),
      ),
    onSuccess: (p) => {
      setMessage({ ok: true, text: t('margin.opened', { id: p.positionId }) });
      refresh();
    },
    onError,
  });
  const close = useMutation({
    mutationFn: async (id: number) =>
      unwrap(await api.POST('/margin/positions/{positionId}/close', { params: { path: { positionId: id } } })),
    onSettled: refresh,
    onError,
  });

  return (
    <>
      <h2>{t('margin.title')}</h2>
      <p className="hint">{t('margin.stopOutHint')}</p>
      <form
        className="row"
        onSubmit={(e) => {
          e.preventDefault();
          if (qtyUnits) open.mutate();
          else setMessage({ ok: false, text: t('form.invalid') });
        }}
      >
        <div className="segmented">
          <button type="button" className={side === 'BUY' ? 'on buy' : ''} onClick={() => setSide('BUY')}>
            {t('margin.long')}
          </button>
          <button type="button" className={side === 'SELL' ? 'on sell' : ''} onClick={() => setSide('SELL')}>
            {t('margin.short')}
          </button>
        </div>
        <label>
          {t('form.qty', { base: instrument.base })}
          <input inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} data-testid="margin-qty" />
        </label>
        <label>
          {t('margin.leverage')}
          <div className="segmented small">
            {Array.from({ length: instrument.maxLeverage }, (_, i) => i + 1).map((l) => (
              <button type="button" key={l} className={l === leverage ? 'on' : ''} onClick={() => setLeverage(l)}>
                ×{l}
              </button>
            ))}
          </div>
        </label>
        <p className="hint">
          {collateral !== null
            ? t('margin.preview', { collateral: money(collateral), loan: money(collateral * (leverage - 1)), quote: instrument.quote })
            : t('margin.noPrice')}
        </p>
        <button type="submit" className={side === 'BUY' ? 'buy' : 'sell'} disabled={open.isPending} data-testid="margin-open">
          {t('margin.open')}
        </button>
        {message && <p className={message.ok ? 'ok' : 'error'}>{message.text}</p>}
      </form>
      <table data-testid="margin-positions">
        <thead>
          <tr>
            <th>#</th>
            <th>{t('orders.side')}</th>
            <th>{t('margin.qtyLev')}</th>
            <th>{t('margin.collateral')}</th>
            <th>{t('margin.loan')}</th>
            <th>{t('margin.entry')}</th>
            <th>{t('margin.last')}</th>
            <th>{t('margin.equity')}</th>
            <th>{t('margin.stopOut')}</th>
            <th>{t('orders.status')}</th>
            <th>{t('margin.result')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {positions.length === 0 && (
            <tr>
              <td colSpan={12}>{t('margin.empty')}</td>
            </tr>
          )}
          {positions.map((p) => (
            <Row key={p.positionId} p={p} money={money} base={instrument.base} onClose={() => close.mutate(p.positionId)} />
          ))}
        </tbody>
      </table>
    </>
  );
}

function Row({ p, money, base, onClose }: { p: MarginPosition; money: (v: number | null | undefined) => string; base: string; onClose: () => void }) {
  const { t } = useTranslation();
  const pct = equityPercent(p.equity, p.collateral);
  return (
    <tr data-testid={`position-${p.positionId}`}>
      <td>{p.positionId}</td>
      <td className={p.side === 'BUY' ? 'bid' : 'ask'}>{t(p.side === 'BUY' ? 'margin.long' : 'margin.short')}</td>
      <td>
        {p.qty} {base} ×{p.leverage}
      </td>
      <td>{money(p.collateral)}</td>
      <td>{p.loanBase > 0 ? `${p.loanBase} ${base}` : money(p.loanQuote)}</td>
      <td>{money(p.entryPrice)}</td>
      <td>{money(p.lastPrice)}</td>
      <td>
        {money(p.equity)}
        {p.status !== 'CLOSED' && (
          <div className="meter" title={`${pct}%`}>
            <div className={pct <= 60 ? 'fill danger' : 'fill'} style={{ width: `${pct}%` }} />
            <div className="mark" />
          </div>
        )}
      </td>
      <td>
        {money(p.stopOutEquity)}
        <br />
        <span className="hint">{t('margin.atPrice', { price: money(p.stopOutPrice) })}</span>
      </td>
      <td>
        {t(`mstatus.${p.status}`)}
        {p.closeReason && <span className={p.closeReason === 'STOP_OUT' ? 'error' : ''}> · {t(`mreason.${p.closeReason}`)}</span>}
      </td>
      <td>
        {p.returned != null && t('margin.returned', { v: money(p.returned) })}
        {p.realisedPnl != null && (
          <span className={p.realisedPnl < 0 ? 'error' : 'ok'}> {t('margin.pnl', { v: money(p.realisedPnl) })}</span>
        )}
        {!!p.badDebt && <span className="error"> {t('margin.badDebt', { v: money(p.badDebt) })}</span>}
      </td>
      <td>
        {p.status === 'OPEN' && (
          <button className="ghost" onClick={onClose} data-testid="margin-close">
            {t('margin.close')}
          </button>
        )}
      </td>
    </tr>
  );
}
