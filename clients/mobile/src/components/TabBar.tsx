import { Pressable, Text, View } from 'react-native';
import { router, usePathname } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { touchMin, useColors } from '../theme/theme';

// The design's tab bar (Главная · Инвестиции · Ещё), drawn here because the router ships stacks only.
const TABS = [
  { href: '/home', icon: '⌂', key: 'tabs.home' },
  { href: '/instrument', icon: '▲', key: 'tabs.invest' },
  { href: '/settings', icon: '⋯', key: 'tabs.more' },
] as const;

export function TabBar() {
  const c = useColors();
  const { t } = useTranslation();
  const path = usePathname();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ flexDirection: 'row', backgroundColor: c.surface, borderTopWidth: 1, borderTopColor: c.border, paddingBottom: insets.bottom }}>
      {TABS.map((tab) => {
        const on = path === tab.href;
        return (
          <Pressable key={tab.href} testID={`tab-${tab.href.slice(1)}`} onPress={() => router.replace(tab.href)} style={{ flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: touchMin + 8 }}>
            <Text style={{ fontSize: 18, color: on ? c.primary : c.textSecondary }}>{tab.icon}</Text>
            <Text style={{ fontSize: 11, color: on ? c.primary : c.textSecondary, fontWeight: on ? '600' : '400' }}>{t(tab.key)}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}
