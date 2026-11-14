import { useEffect, useMemo } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import '../i18n/i18n';
import { MarketSocket } from '../api/socket';
import { SocketContext } from '../hooks';
import { useSession } from '../store/session';

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 1 } } });

export default function RootLayout() {
  const token = useSession((s) => s.token);
  const socket = useMemo(() => (token ? new MarketSocket(token) : null), [token]);
  useEffect(() => () => socket?.close(), [socket]);

  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <SocketContext.Provider value={socket}>
          <StatusBar style="auto" />
          <Stack screenOptions={{ headerShown: false, animation: 'none' }} />
        </SocketContext.Provider>
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}
