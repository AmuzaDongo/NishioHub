import { createContext, useContext, useEffect, type ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from './auth-context';
import { isPlatformAdmin } from './utils';
import { getPublicPlatformConfig, type PublicPlatformConfig } from './system-settings-api';
const defaults: PublicPlatformConfig = {
  platform_name: 'NishioHub', tagline: 'Discover. Learn. Grow.', organization_name: 'NishioHub Limited',
  support_email: 'support@nishiohub.com', support_phone: '', timezone: 'Africa/Kampala', language: 'en-UG',
  date_format: 'medium', currency: 'UGX', platform_mode: 'live', registration_enabled: true,
  require_email_verification: false, default_registration_role: 'mentee', matching_enabled: true, public_events_enabled: false, support_url: '',
  maintenance_message: 'The platform is undergoing maintenance.', password_min_length: 8, logo_url: null, favicon_url: null, favicon_content_type: null,
};
const PlatformContext = createContext(defaults);
export const usePlatform = () => useContext(PlatformContext);
export function assetUrl(value?: string | null) {
  if (!value || /^(https?:|blob:|data:)/.test(value)) return value || undefined;
  const base = (import.meta.env.VITE_API_BASE_URL || 'https://api.nishiohub.com/api/v1').replace(/\/api\/v1\/?$/, '');
  return new URL(value.replace(/^\//, ''), `${base}/`).href;
}
export function platformDate(value: string, config: Pick<PublicPlatformConfig, 'timezone' | 'language' | 'date_format'>, time = false) {
  const date = new Date(value);
  if (config.date_format === 'iso' && !time) return new Intl.DateTimeFormat('en-CA', { timeZone: config.timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
  return new Intl.DateTimeFormat(config.date_format === 'day_first' ? 'en-GB' : config.language, { timeZone: config.timezone, year: 'numeric', month: config.date_format === 'medium' ? 'short' : '2-digit', day: 'numeric', ...(time ? { hour: 'numeric', minute: '2-digit' } as const : {}) }).format(date);
}
export function PlatformProvider({ children }: { children: ReactNode }) {
  const { data } = useQuery({ queryKey: ['public-platform-config'], queryFn: getPublicPlatformConfig, staleTime: 30000, refetchInterval: 60000 });
  useEffect(() => {
    if (!data) return;
    let icon = document.querySelector<HTMLLinkElement>('link[rel="icon"]');
    if (!icon) { icon = document.createElement('link'); icon.rel = 'icon'; document.head.appendChild(icon); }
    icon.type = data.favicon_url ? (data.favicon_content_type || '') : 'image/svg+xml';
    icon.href = assetUrl(data.favicon_url) || '/assets/platform-icon.svg';
    document.documentElement.lang = data.language;
  }, [data]);
  return <PlatformContext.Provider value={data || defaults}>{children}</PlatformContext.Provider>;
}
export function PlatformBoundary({ children }: { children: ReactNode }) {
  const config = usePlatform();
  const { user } = useAuth();
  const location = useLocation();
  if (config.platform_mode === 'maintenance' && !isPlatformAdmin(user) && location.pathname !== '/login') return <main className="min-h-screen flex flex-col items-center justify-center gap-5 p-8 text-center bg-violet-50"><img src={assetUrl(config.logo_url) || '/assets/learning-logo.svg'} alt={config.platform_name} className="w-56" /><h1 className="text-3xl font-bold">We’ll be back soon</h1><p className="max-w-lg">{config.maintenance_message}</p><a href={`mailto:${config.support_email}`} className="text-violet-700">Contact support</a><Link to="/login" className="text-sm underline">Administrator sign in</Link></main>;
  return <>{config.platform_mode === 'staging' && <div className="bg-amber-100 text-amber-950 text-center text-sm py-2" role="status">Staging mode — {config.platform_name}</div>}{children}</>;
}
