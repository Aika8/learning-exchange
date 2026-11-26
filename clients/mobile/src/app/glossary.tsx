import { useState } from 'react';
import { TextInput, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { api, call } from '../api/client';
import { glossaryRows, langOf } from '../glossary';
import { radius, useColors } from '../theme/theme';
import { Body, Caption, Card, Screen, Title } from '../components/ui';
import { TabBar } from '../components/TabBar';

/** Design S10 «Словарь»: real finance terms from /bff/mobile/glossary with a search box; the logic is in glossary.ts. */
export default function GlossaryScreen() {
  const c = useColors();
  const { t, i18n } = useTranslation();
  const [query, setQuery] = useState('');
  const terms = useQuery({ queryKey: ['glossary'], queryFn: () => call(api.GET('/bff/mobile/glossary')), staleTime: Infinity }).data;
  const rows = glossaryRows(terms ?? [], query, langOf(i18n.language));
  return (
    <Screen footer={<TabBar />}>
      <Title>{t('glossary.title')}</Title>
      <TextInput
        testID="glossary-search"
        value={query}
        onChangeText={setQuery}
        placeholder={t('glossary.search')}
        placeholderTextColor={c.textSecondary}
        autoCorrect={false}
        style={{ borderWidth: 1, borderColor: c.border, borderRadius: radius.sm, padding: 10, fontSize: 17, color: c.textPrimary, backgroundColor: c.surface }}
      />
      {terms == null && <Caption>…</Caption>}
      {terms != null && rows.length === 0 && <Caption testID="glossary-empty">{t('glossary.empty')}</Caption>}
      {rows.map((r) => (
        <Card key={r.id}>
          <View testID={`term-${r.id}`} style={{ gap: 4 }}>
            <Body bold>{r.name}</Body>
            <Caption>{r.definition}</Caption>
          </View>
        </Card>
      ))}
    </Screen>
  );
}
