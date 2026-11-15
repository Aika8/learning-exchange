import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, unwrap } from '../api/client';
import { useSavings } from '../hooks';
import { formatMinor, parseToMinor } from '../money';
import { bpsPercent } from '../m2a';

const SCALE = 2; // SPARK

export function Savings() {
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const overview = useSavings().data;
  const [amount, setAmount] = useState('1000');
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const money = (v: number | null | undefined) => (v == null ? '—' : formatMinor(v, SCALE, i18n.language));
  const refresh = () => ['savings', 'me', 'statement'].forEach((k) => void qc.invalidateQueries({ queryKey: [k] }));
  const onError = (e: Error) => setMessage({ ok: false, text: t(`errors.${e instanceof ApiError ? e.code : 'NETWORK'}`) });
  const minor = parseToMinor(amount, SCALE);

  const open = useMutation({
    mutationFn: async () =>
      unwrap(await api.POST('/savings', { params: { header: { 'Idempotency-Key': crypto.randomUUID() } }, body: { amount: minor! } })),
    onSuccess: (d) => {
      setMessage({ ok: true, text: t('savings.opened', { id: d.depositId }) });
      refresh();
    },
    onError,
  });
  const close = useMutation({
    mutationFn: async (id: number) => unwrap(await api.POST('/savings/{depositId}/close', { params: { path: { depositId: id } } })),
    onSettled: refresh,
    onError,
  });

  const p = overview?.product;
  return (
    <>
      <h2>{t('savings.title')}</h2>
      {p && (
        <p className="hint" data-testid="savings-product">
          {t('savings.product', {
            rate: bpsPercent(p.rateBps, i18n.language),
            asset: p.asset,
            seconds: Math.floor(p.dayMillis / 1000),
          })}
        </p>
      )}
      <form
        className="row"
        onSubmit={(e) => {
          e.preventDefault();
          if (minor) open.mutate();
          else setMessage({ ok: false, text: t('form.invalid') });
        }}
      >
        <label>
          {t('savings.amount', { asset: p?.asset ?? 'SPARK' })}
          <input inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} data-testid="savings-amount" />
        </label>
        <button type="submit" disabled={open.isPending} data-testid="savings-open">
          {t('savings.open')}
        </button>
        {message && <p className={message.ok ? 'ok' : 'error'}>{message.text}</p>}
      </form>
      <table data-testid="savings">
        <thead>
          <tr>
            <th>#</th>
            <th>{t('savings.principal')}</th>
            <th>{t('savings.interest')}</th>
            <th>{t('savings.balance')}</th>
            <th>{t('savings.rate')}</th>
            <th>{t('orders.status')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {(overview?.deposits.length ?? 0) === 0 && (
            <tr>
              <td colSpan={7}>{t('savings.empty')}</td>
            </tr>
          )}
          {overview?.deposits.map((d) => (
            <tr key={d.depositId}>
              <td>{d.depositId}</td>
              <td>{money(d.principal)}</td>
              <td className="ok">{money(d.interest)}</td>
              <td>{money(d.balance)}</td>
              <td>{bpsPercent(d.rateBps, i18n.language)}%</td>
              <td>{t(`dstatus.${d.status}`)}</td>
              <td>
                {d.status === 'OPEN' && (
                  <button className="ghost" onClick={() => close.mutate(d.depositId)}>
                    {t('savings.close')}
                  </button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
