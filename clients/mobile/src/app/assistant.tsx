import { useState } from 'react';
import { Text, TextInput, View } from 'react-native';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { api, call, type Schemas } from '../api/client';
import { radius, useColors } from '../theme/theme';
import { Button, Caption, Card, Screen, Title } from '../components/ui';
import { TabBar } from '../components/TabBar';

const QUICK = ['assistant.q.expectations', 'assistant.q.costs', 'assistant.q.session'] as const;

/** «Помощник» (M4, ADR-0013): questions about my own facts. Numbers come from the server; the model only narrates. */
export default function AssistantScreen() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const [question, setQuestion] = useState('');
  const ask = useMutation({
    mutationFn: (q: string) =>
      call(api.POST('/assistant/ask', { body: { question: q, lang: i18n.language.startsWith('en') ? 'en' : 'ru', persona: 'HELPER' } })),
  });
  const a: Schemas['AssistantAnswer'] | undefined = ask.data;
  const send = (q: string) => {
    if (q.trim()) ask.mutate(q.trim());
  };

  return (
    <Screen footer={<TabBar />}>
      <Title>{t('assistant.title')}</Title>
      <Caption>{t('assistant.intro')}</Caption>
      <View style={{ gap: 8 }}>
        {QUICK.map((k) => (
          <Button key={k} testID={`ask-${k.split('.').pop()}`} title={t(k)} color={c.textSecondary} onPress={() => { setQuestion(t(k)); send(t(k)); }} />
        ))}
      </View>
      <TextInput
        testID="assistant-question"
        value={question}
        onChangeText={setQuestion}
        placeholder={t('assistant.placeholder')}
        maxLength={500}
        multiline
        style={{ borderWidth: 1, borderColor: c.border, borderRadius: radius.sm, padding: 10, fontSize: 16, color: c.textPrimary, backgroundColor: c.surface, minHeight: 60 }}
      />
      <Button testID="assistant-ask" title={t('assistant.ask')} disabled={ask.isPending || !question.trim()} onPress={() => send(question)} />
      {ask.isPending && <Caption>…</Caption>}
      {ask.error && <Caption color={c.negative}>{t('errors.NETWORK')}</Caption>}
      {a && (
        <Card style={{ gap: 8 }}>
          <Text testID="assistant-answer" style={{ color: c.textPrimary, fontSize: 16, lineHeight: 22 }}>{a.answer}</Text>
          <Caption testID="assistant-source">
            {a.source === 'CLAUDE' ? t('assistant.sourceModel', { model: a.model ?? '' }) : t('assistant.sourceTemplate')}
            {a.guarded ? ` · ${t('assistant.guarded')}` : ''}
          </Caption>
          <Caption color={c.textSecondary} testID="assistant-disclaimer">{a.disclaimer}</Caption>
        </Card>
      )}
    </Screen>
  );
}
