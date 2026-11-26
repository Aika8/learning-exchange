import { View } from 'react-native';
import { router } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { useQueryClient } from '@tanstack/react-query';
import { useMe } from '../hooks';
import { useSession } from '../store/session';
import { useColors } from '../theme/theme';
import { Body, Button, Caption, Card, Screen, Title } from '../components/ui';
import { LanguageSwitch } from '../components/LanguageSwitch';
import { TabBar } from '../components/TabBar';

/** Design S10b (settings), skeleton: language switch ru/en at runtime, account, log out. */
export default function Settings() {
  const c = useColors();
  const { t } = useTranslation();
  const me = useMe().data;
  const qc = useQueryClient();
  const setToken = useSession((s) => s.setToken);
  return (
    <Screen footer={<TabBar />}>
      <Title>{t('settings.title')}</Title>
      <LanguageSwitch />
      <Card style={{ gap: 8 }}>
        <Caption>{t('settings.account')}</Caption>
        <Body>{me?.name ?? '—'}</Body>
        <Caption>{me?.accountId}</Caption>
      </Card>
      <View style={{ flexDirection: 'row' }}>
        <Button testID="open-statement" title={t('home.statement')} onPress={() => router.push('/statement')} />
      </View>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <Button testID="open-calendar" title={t('calendar.title')} color={c.accent} onPress={() => router.push('/calendar')} />
        <Button testID="open-bonds" title={t('bonds.title')} color={c.accent} onPress={() => router.push('/bonds')} />
      </View>
      <View style={{ flexDirection: 'row' }}>
        <Button testID="open-glossary" title={t('glossary.title')} color={c.accent} onPress={() => router.push('/glossary')} />
      </View>
      <View style={{ flexDirection: 'row' }}>
        <Button
          testID="logout"
          title={t('settings.logout')}
          color={c.negative}
          onPress={() => {
            setToken(null);
            qc.clear();
            router.replace('/login');
          }}
        />
      </View>
      <Caption>{t('settings.footer')}</Caption>
    </Screen>
  );
}
