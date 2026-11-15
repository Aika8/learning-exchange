import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, unwrap, type Instrument } from '../api/client';
import { useMyOrders } from '../hooks';
import { formatMinor } from '../money';

export function MyOrders({ instrument }: { instrument: Instrument }) {
  const { t, i18n } = useTranslation();
  const [openOnly, setOpenOnly] = useState(false);
  const orders = (useMyOrders(openOnly).data ?? []).filter((o) => o.instrument === instrument.id);
  const qc = useQueryClient();
  const cancel = useMutation({
    mutationFn: async (id: number) => unwrap(await api.DELETE('/orders/{orderId}', { params: { path: { orderId: id } } })),
    onSettled: () => {
      void qc.invalidateQueries({ queryKey: ['orders'] });
      void qc.invalidateQueries({ queryKey: ['me'] });
    },
  });

  return (
    <>
      <h2>
        {t('orders.title')} · {instrument.id}
        <label className="inline">
          <input type="checkbox" checked={openOnly} onChange={(e) => setOpenOnly(e.target.checked)} /> {t('orders.openOnly')}
        </label>
      </h2>
      <table data-testid="my-orders">
        <thead>
          <tr>
            <th>{t('orders.id')}</th>
            <th>{t('orders.side')}</th>
            <th>{t('orders.type')}</th>
            <th>{t('orders.price')}</th>
            <th>{t('orders.filled')}</th>
            <th>{t('orders.status')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {orders.length === 0 && (
            <tr>
              <td colSpan={7}>{t('orders.empty')}</td>
            </tr>
          )}
          {orders.map((o) => (
            <tr key={o.orderId} data-testid={`order-${o.orderId}`}>
              <td>{o.orderId}</td>
              <td className={o.side === 'BUY' ? 'bid' : 'ask'}>{t(`side.${o.side}`)}</td>
              <td>{t(`type.${o.type}`)}</td>
              <td>{o.type === 'LIMIT' ? formatMinor(o.price, instrument.priceScale, i18n.language) : '—'}</td>
              <td>
                {o.filledQty} / {o.qty}
              </td>
              <td data-testid="order-status">{t(`status.${o.status}`)}</td>
              <td>
                {(o.status === 'NEW' || o.status === 'PARTIALLY_FILLED') && (
                  <button className="ghost" onClick={() => cancel.mutate(o.orderId)} data-testid="cancel-order">
                    {t('orders.cancel')}
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
