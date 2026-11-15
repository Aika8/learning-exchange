import { TextInput, View } from 'react-native';
import { radius, useColors } from '../theme/theme';
import { Caption } from './ui';

/** Labelled numeric text field in the ticket style. */
export function Field({ label, value, onChange, testID, hint }: { label: string; value: string; onChange: (v: string) => void; testID?: string; hint?: string }) {
  const c = useColors();
  return (
    <View style={{ gap: 4, flex: 1 }}>
      <Caption>{label}</Caption>
      <TextInput
        testID={testID}
        value={value}
        onChangeText={onChange}
        keyboardType="decimal-pad"
        style={{ borderWidth: 1, borderColor: c.border, borderRadius: radius.sm, padding: 10, fontSize: 17, color: c.textPrimary, backgroundColor: c.surface, fontVariant: ['tabular-nums'] }}
      />
      {hint ? <Caption>{hint}</Caption> : null}
    </View>
  );
}

/** Label on the left, value on the right. */
export function Line({ label, value, color, testID }: { label: string; value: string; color?: string; testID?: string }) {
  const c = useColors();
  return (
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: 8 }}>
      <Caption>{label}</Caption>
      <Caption color={color ?? c.textPrimary} testID={testID}>
        {value}
      </Caption>
    </View>
  );
}
