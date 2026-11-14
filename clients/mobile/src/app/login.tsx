import { useState } from 'react';
import { TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { useQueryClient } from '@tanstack/react-query';
import { api, ApiError, call } from '../api/client';
import { useSession } from '../store/session';
import { APP_NAME } from '../config';
import { radius, useColors } from '../theme/theme';
import { Body, Button, Caption, Card, PracticeChip, Screen, Title } from '../components/ui';
import { LanguageSwitch } from '../components/LanguageSwitch';

export default function Login() {
  const c = useColors();
  const { t } = useTranslation();
  const qc = useQueryClient();
  const setToken = useSession((s) => s.setToken);
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setError(null);
    try {
      const res = await call(api.POST('/auth/dev-login', { body: { name: name.trim() } }));
      qc.clear();
      setToken(res.token);
      router.replace('/home');
    } catch (e) {
      setError(e instanceof ApiError ? e.code : 'NETWORK');
    }
  };

  return (
    <Screen>
      <View style={{ alignItems: 'center', gap: 6, marginTop: 48, marginBottom: 16 }}>
        <Body color={c.primary} bold>⛵</Body>
        <Title>{APP_NAME}</Title>
        <Caption>{t('login.subtitle')}</Caption>
        <PracticeChip />
      </View>
      <Card style={{ gap: 12 }}>
        <Title>{t('login.title')}</Title>
        <Caption>{t('login.name')}</Caption>
        <TextInput
          testID="login-name"
          value={name}
          onChangeText={setName}
          autoCapitalize="words"
          autoCorrect={false}
          onSubmitEditing={submit}
          style={{ borderWidth: 1, borderColor: c.border, borderRadius: radius.sm, padding: 12, fontSize: 17, color: c.textPrimary }}
        />
        <View style={{ flexDirection: 'row' }}>
          <Button testID="login-submit" title={t('login.submit')} onPress={submit} disabled={!name.trim()} />
        </View>
        <Caption>{t('login.hint')}</Caption>
        {error && <Caption color={c.negative}>{t(`errors.${error}`)}</Caption>}
      </Card>
      <LanguageSwitch />
    </Screen>
  );
}
