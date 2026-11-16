import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

// M4 rebalancing reminder: my target shares (bps per asset) and when I last checked (simulation ms). Local UI state.
type Plan = {
  targetsBps: Record<string, number>;
  lastCheck: number | null;
  setTarget: (asset: string, bps: number) => void;
  markChecked: (now: number) => void;
};

export const usePlan = create<Plan>()(
  persist(
    (set) => ({
      targetsBps: {},
      lastCheck: null,
      setTarget: (asset, bps) => set((s) => ({ targetsBps: { ...s.targetsBps, [asset]: bps } })),
      markChecked: (now) => set({ lastCheck: now }),
    }),
    { name: 'vetrilo-plan', storage: createJSONStorage(() => AsyncStorage) },
  ),
);
