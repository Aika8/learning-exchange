import { useEffect } from 'react';
import { router } from 'expo-router';
import { View } from 'react-native';
import { useSession } from '../store/session';

/** Entry: logged in → home, otherwise → login (waits for the persisted session to load). */
export default function Index() {
  const token = useSession((s) => s.token);
  const hydrated = useSession.persist.hasHydrated();
  useEffect(() => {
    const go = () => router.replace(useSession.getState().token ? '/home' : '/login');
    if (hydrated) go();
    else return useSession.persist.onFinishHydration(go);
  }, [hydrated, token]);
  return <View />;
}
