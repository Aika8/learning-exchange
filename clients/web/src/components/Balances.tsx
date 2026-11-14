import { useTranslation } from 'react-i18next';
import { useMe } from '../hooks';
import { formatMinor } from '../money';

const SCALE: Record<string, number> = { SPARK: 2, SILK: 0 };

export function Balances() {
  const { t, i18n } = useTranslation();
  const me = useMe().data;
  return (
    <>
      <h2>
        {t('balances.title')} · <span data-testid="account-name">{me?.name}</span>
      </h2>
      <table data-testid="balances">
        <thead>
          <tr>
            <th>{t('balances.asset')}</th>
            <th>{t('balances.available')}</th>
            <th>{t('balances.reserved')}</th>
          </tr>
        </thead>
        <tbody>
          {me?.balances.map((b) => (
            <tr key={b.asset} data-testid={`balance-${b.asset}`}>
              <td>{b.asset}</td>
              <td>{formatMinor(b.available, SCALE[b.asset] ?? 0, i18n.language)}</td>
              <td>{formatMinor(b.reserved, SCALE[b.asset] ?? 0, i18n.language)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
