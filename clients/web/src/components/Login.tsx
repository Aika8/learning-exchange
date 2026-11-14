import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { api, ApiError, unwrap } from '../api/client';

export function Login({ onLogin }: { onLogin: (token: string) => void }) {
  const { t } = useTranslation();
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    try {
      const res = unwrap(await api.POST('/auth/dev-login', { body: { name } }));
      onLogin(res.token);
    } catch (err) {
      setError(err instanceof ApiError ? err.code : 'NETWORK');
    }
  };

  return (
    <form className="card login" onSubmit={submit}>
      <h2>{t('login.title')}</h2>
      <label>
        {t('login.name')}
        <input value={name} onChange={(e) => setName(e.target.value)} data-testid="login-name" autoFocus />
      </label>
      <button type="submit" disabled={!name.trim()} data-testid="login-submit">
        {t('login.submit')}
      </button>
      <p className="hint">{t('login.hint')}</p>
      {error && <p className="error">{t(`errors.${error}`)}</p>}
    </form>
  );
}
