import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { api, unwrap, type Schemas } from '../api/client';

/** M4: «Помощник» over my own facts (ADR-0013) and the achievements shared with the game. */
export function M4Panels() {
  const { t, i18n } = useTranslation();
  const [q, setQ] = useState('');
  const ask = useMutation({
    mutationFn: async (question: string) =>
      unwrap(await api.POST('/assistant/ask', { body: { question, lang: i18n.language.startsWith('en') ? 'en' : 'ru', persona: 'HELPER' } })),
  });
  const achievements = useQuery({ queryKey: ['achievements'], queryFn: async () => unwrap(await api.GET('/achievements')), refetchInterval: 5000 });
  const a: Schemas['AssistantAnswer'] | undefined = ask.data;
  const send = (text: string) => text.trim() && ask.mutate(text.trim());

  return (
    <div className="m4">
      <div data-testid="assistant">
        <h2>{t('assistant.title')}</h2>
        <p className="hint">{t('assistant.intro')}</p>
        <div className="row">
          {(['expectations', 'costs', 'session'] as const).map((k) => (
            <button key={k} data-testid={`ask-${k}`} onClick={() => { setQ(t(`assistant.q.${k}`)); send(t(`assistant.q.${k}`)); }}>
              {t(`assistant.q.${k}`)}
            </button>
          ))}
        </div>
        <form className="row" onSubmit={(e) => { e.preventDefault(); send(q); }}>
          <input data-testid="assistant-question" value={q} maxLength={500} onChange={(e) => setQ(e.target.value)} placeholder={t('assistant.placeholder')} />
          <button type="submit" disabled={ask.isPending || !q.trim()}>{t('assistant.ask')}</button>
        </form>
        {ask.isError && <p className="error">{t('errors.NETWORK', 'Network error')}</p>}
        {a && (
          <div className="answer">
            <p data-testid="assistant-answer">{a.answer}</p>
            <p className="hint" data-testid="assistant-source">
              {a.source === 'CLAUDE' ? t('assistant.sourceModel', { model: a.model ?? '' }) : t('assistant.sourceTemplate')}
              {a.guarded ? ` · ${t('assistant.guarded')}` : ''}
            </p>
            <p className="hint" data-testid="assistant-disclaimer">{a.disclaimer}</p>
          </div>
        )}
      </div>
      <div data-testid="achievements">
        <h2>{t('achievements.title')}</h2>
        <ul>
          {(achievements.data ?? []).map((x) => (
            <li key={x.id} className={x.unlocked ? 'ok' : 'hint'}>
              {x.unlocked ? '★' : '☆'} {t(`achievements.${x.id}`)} — {x.unlocked ? t('achievements.done') : `${x.progress}/${x.target}`}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
