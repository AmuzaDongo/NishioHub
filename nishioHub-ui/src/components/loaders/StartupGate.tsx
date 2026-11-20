import { useEffect, useState, type ReactNode } from 'react';
import { useIsFetching } from '@tanstack/react-query';
import { useAuth } from '@/lib/auth-context';
import { assetUrl, usePlatform } from '@/lib/platform-context';
import { BrandLoader } from './BrandLoader';

export function StartupGate({ children }: { children: ReactNode }) {
  const { isLoading } = useAuth();
  const platform = usePlatform();
  const fetching = useIsFetching({ queryKey: ['public-platform-config'], exact: true });
  const [ready, setReady] = useState(false);
  const [timedOut, setTimedOut] = useState(false);
  useEffect(() => { const timer = window.setTimeout(() => setTimedOut(true), 2000); return () => window.clearTimeout(timer); }, []);
  useEffect(() => { if (!isLoading && (!fetching || timedOut)) setReady(true); }, [isLoading, fetching, timedOut]);
  return ready ? children : <BrandLoader logo={platform.logo_url ? assetUrl(platform.logo_url) : undefined} tagline={platform.tagline}/>;
}
