import { useTranslation } from 'react-i18next';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api, unwrap, type ConditionalOrder, type Instrument } from '../api/client';
import { useConditionals } from '../hooks';
import { canCancel, fieldsFor, fillText, phaseOf } from '../m2a';
import { formatMinor } from '../money';

export function StopsList({ instrument }: { instrument: Instrument }) {
  const { t, i18n } = useTranslation();
  const qc = useQueryClient();
  const list = (useConditionals().data ?? []).filter((c) => c.instrument === instrument.id);
  const cancel = useMutation({
    mutationFn: async (id: number) =>
      unwrap(await api.DELETE('/conditional-orders/{conditionalId}', { params: { path: { conditionalId: id } } })),
    onSettled: () => void qc.invalidateQueries({ queryKey: ['conditional'] }),
  });
  const money = (v: number | null | undefined) => (v == null ? '—' : formatMinor(v, instrument.priceScale, i18n.language));

  const params = (c: ConditionalOrder) =>
    fieldsFor(c.kind)
      .filter((f) => c[f] > 0)
      .map((f) => `${t(`stops.short.${f}`)} ${money(c[f])}`)
      .join(' · ');

  return (
    <>
      <h2>{t('stops.title')}</h2>
      <p className="hint">{t('stops.firedHint')}</p>
      <table data-testid="stops">
        <thead>
          <tr>
            <th>#</th>
            <th>{t('stops.kind')}</th>
            <th>{t('orders.side')}</th>
            <th>{t('stops.params')}</th>
            <th>{t('stops.state')}</th>
            <th>{t('stops.triggerTrade')}</th>
            <th>{t('stops.order')}</th>
            <th>{t('orders.filled')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {list.length === 0 && (
            <tr>
              <td colSpan={9}>{t('stops.empty')}</td>
            </tr>
          )}
          {list.map((c) => (
            <tr key={c.conditionalId} data-testid={`stop-${c.conditionalId}`}>
              <td>{c.conditionalId}</td>
              <td>{t(`ckind.${c.kind}`)}</td>
              <td className={c.side === 'BUY' ? 'bid' : 'ask'}>{t(`side.${c.side}`)}</td>
              <td>
                {params(c)}
                {c.bestPrice != null && ` · ${t('stops.best')} ${money(c.bestPrice)}`}
              </td>
              <td>
                <span className={`state ${phaseOf(c.state)}`} data-testid="stop-state">
                  {t(`cstate.${c.state}`)}
                </span>
                {c.rejection && <span className="error"> · {t(`errors.${c.rejection}`, { defaultValue: c.rejection })}</span>}
              </td>
              <td>{money(c.triggerTradePrice)}</td>
              <td>{c.orderId ?? '—'}</td>
              <td>{fillText(c) ?? '—'}</td>
              <td>
                {canCancel(c) && (
                  <button className="ghost" onClick={() => cancel.mutate(c.conditionalId)}>
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
