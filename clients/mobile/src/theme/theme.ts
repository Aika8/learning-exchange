import { useColorScheme } from 'react-native';
import tokens from './tokens.json';

// Typed theme from docs/design/tokens.json (copy checked by test/tokens.test.mjs).
export type Colors = typeof tokens.color.light;
export const radius = tokens.radius;
export const space = tokens.spacing;
export const type = tokens.typography.scale;
export const touchMin = tokens.touchTargetMin;

export function useColors(): Colors {
  return useColorScheme() === 'dark' ? tokens.color.dark : tokens.color.light;
}

/** Depth-bar tints from the design canvas (S03): bid/ask backgrounds. */
export function useDepthTints() {
  return useColorScheme() === 'dark'
    ? { bidBg: '#1C2F4A', askBg: '#3A2A1C' }
    : { bidBg: '#E1E9F7', askBg: '#F6E7DA' };
}
