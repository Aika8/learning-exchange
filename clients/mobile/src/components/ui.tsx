import type { ReactNode } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTranslation } from 'react-i18next';
import { radius, touchMin, type as typo, useColors } from '../theme/theme';

export function Screen({ children, footer }: { children: ReactNode; footer?: ReactNode }) {
  const c = useColors();
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.bg }} edges={['top', 'left', 'right']}>
      <ScrollView contentContainerStyle={{ padding: 16, gap: 12 }}>{children}</ScrollView>
      {footer}
    </SafeAreaView>
  );
}

export function Card({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  const c = useColors();
  return (
    <View style={[{ backgroundColor: c.surface, borderRadius: radius.md, padding: 16, borderWidth: StyleSheet.hairlineWidth, borderColor: c.border }, style]}>
      {children}
    </View>
  );
}

export function Title({ children }: { children: ReactNode }) {
  const c = useColors();
  return <Text style={{ fontSize: typo.title.size, lineHeight: typo.title.lineHeight, fontWeight: '600', color: c.textPrimary }}>{children}</Text>;
}

export function Caption({ children, color, testID }: { children: ReactNode; color?: string; testID?: string }) {
  const c = useColors();
  return <Text testID={testID} style={{ fontSize: typo.caption.size, lineHeight: typo.caption.lineHeight, fontWeight: '500', color: color ?? c.textSecondary }}>{children}</Text>;
}

export function Body({ children, color, bold, num }: { children: ReactNode; color?: string; bold?: boolean; num?: boolean }) {
  const c = useColors();
  return (
    <Text style={{ fontSize: typo.body.size, lineHeight: typo.body.lineHeight, color: color ?? c.textPrimary, fontWeight: bold ? '600' : '400', fontVariant: num ? ['tabular-nums'] : undefined }}>
      {children}
    </Text>
  );
}

/** «учебные деньги» badge from the design system. */
export function PracticeChip() {
  const c = useColors();
  const { t } = useTranslation();
  return (
    <View style={{ backgroundColor: c.surfaceAlt, borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 2 }}>
      <Caption color={c.accent}>{t('app.practice')}</Caption>
    </View>
  );
}

export function Button({ title, onPress, color, disabled, testID }: { title: string; onPress: () => void; color?: string; disabled?: boolean; testID?: string }) {
  const c = useColors();
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => ({ backgroundColor: color ?? c.primary, borderRadius: radius.md, minHeight: touchMin + 4, alignItems: 'center', justifyContent: 'center', opacity: disabled ? 0.5 : pressed ? 0.85 : 1, flex: 1 })}
    >
      <Text style={{ color: c.onPrimary, fontSize: typo.headline.size, fontWeight: '600' }}>{title}</Text>
    </Pressable>
  );
}

export function Segmented<T extends string>({ value, options, onChange, testIDPrefix }: { value: T; options: { value: T; label: string }[]; onChange: (v: T) => void; testIDPrefix?: string }) {
  const c = useColors();
  return (
    <View style={{ flexDirection: 'row', backgroundColor: c.surfaceAlt, borderRadius: radius.sm, padding: 2 }}>
      {options.map((o) => (
        <Pressable
          key={o.value}
          testID={testIDPrefix ? `${testIDPrefix}-${o.value}` : undefined}
          accessibilityRole="button"
          accessibilityState={{ selected: o.value === value }}
          onPress={() => onChange(o.value)}
          style={{ flex: 1, minHeight: touchMin - 8, alignItems: 'center', justifyContent: 'center', borderRadius: radius.sm - 2, backgroundColor: o.value === value ? c.surface : 'transparent' }}
        >
          <Text style={{ color: o.value === value ? c.textPrimary : c.textSecondary, fontWeight: '600' }}>{o.label}</Text>
        </Pressable>
      ))}
    </View>
  );
}
