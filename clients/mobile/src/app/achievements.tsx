import { memo } from 'react';
import { View } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { Schemas } from '../api/client';
import { useAchievements } from '../hooks';
import { useColors } from '../theme/theme';
import { Body, Caption, Card, Screen, Title } from '../components/ui';
import { TabBar } from '../components/TabBar';
import { useFmt } from '../components/format';

/** Achievements (M4): the same list the game shows, built from the same account's events. */
export default function AchievementsScreen() {
  const { t } = useTranslation();
  const q = useAchievements();
  return (
    <Screen footer={<TabBar />}>
      <Title>{t('achievements.title')}</Title>
      <Caption>{t('achievements.intro')}</Caption>
      <Card style={{ gap: 12 }}>
        {(q.data ?? []).map((a) => (
          <AchievementRow key={a.id} a={a} />
        ))}
        {!q.data && <Caption>…</Caption>}
      </Card>
    </Screen>
  );
}

const AchievementRow = memo(function AchievementRow({ a }: { a: Schemas['Achievement'] }) {
  const c = useColors();
  const { t } = useTranslation();
  const f = useFmt();
  return (
    <View testID={`achievement-${a.id}`} style={{ flexDirection: 'row', gap: 10, alignItems: 'center', opacity: a.unlocked ? 1 : 0.55 }}>
      <Body color={a.unlocked ? c.positive : c.textSecondary}>{a.unlocked ? '★' : '☆'}</Body>
      <View style={{ flex: 1 }}>
        <Body bold>{t(`achievements.${a.id}.title`)}</Body>
        <Caption>{t(`achievements.${a.id}.desc`)}</Caption>
      </View>
      <Caption>{a.unlocked && a.at != null ? f.date(a.at) : `${a.progress}/${a.target}`}</Caption>
    </View>
  );
});
