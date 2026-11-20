import api from '@/lib/axios';
import type { AboutTeamDraft } from './about-api';
export interface PlatformSettings {
  about_story_video_url: string; about_team: AboutTeamDraft[];
  platform_name: string; tagline: string; organization_name: string; support_email: string; support_phone: string;
  timezone: string; language: string; date_format: string; currency: string; platform_mode: 'live' | 'staging' | 'maintenance';
  registration_enabled: boolean; require_email_verification: boolean; matching_enabled: boolean; public_events_enabled: boolean;
  notifications_enabled: boolean; learning_enrollment_enabled: boolean; event_registration_enabled: boolean;
  default_registration_role: string; access_token_minutes: number; refresh_token_days: number; password_min_length: number;
  max_upload_mb: number; maintenance_message: string; allowed_meeting_hosts: string[]; support_url: string;
}
export interface PlatformAssets { logo_url: string | null; favicon_url: string | null; favicon_content_type: string | null }
export interface SystemWorkspace {
  settings: PlatformSettings; defaults: PlatformSettings; lock_version: number; assets: PlatformAssets;
  updated_at: string; updated_by: string | null;
  runtime: { environment: string; email_configured: boolean; storage: string; database: string; calendar: string; backup_scope: string };
}
export interface AuditPage {
  entries: { id: number; actor_name: string; action: string; changeset: Record<string, unknown>; revision: number; created_at: string }[];
  meta: { page: number; total: number; total_pages: number };
}
export interface ConfigBackup { id: number; label: string; checksum: string; revision: number; created_at: string; created_by: string | null }
export interface ConfigDocument { format: 'nishiohub-system-settings'; schema_version: 1; values: PlatformSettings; checksum: string; created_at: string }
export const getSystemSettings = async () => (await api.get<SystemWorkspace>('/admin/system_settings')).data;
export const patchSystemSettings = async (payload: { settings: Partial<PlatformSettings>; lock_version: number }) => (await api.patch<SystemWorkspace>('/admin/system_settings', payload)).data;
export const uploadPlatformAsset = async ({ kind, file, revision }: { kind: 'logo' | 'favicon'; file: File; revision: number }) => { const body = new FormData(); body.append('file', file); body.append('lock_version', String(revision)); return (await api.post<SystemWorkspace>(`/admin/system_settings/assets/${kind}`, body)).data; };
export const removePlatformAsset = async ({ kind, revision }: { kind: 'logo' | 'favicon'; revision: number }) => (await api.delete<SystemWorkspace>(`/admin/system_settings/assets/${kind}`, { data: { lock_version: revision } })).data;
export const getSystemAudit = async (page: number) => (await api.get<AuditPage>('/admin/system_settings/audit', { params: { page } })).data;
export const getConfigBackups = async () => (await api.get<ConfigBackup[]>('/admin/system_settings/backups')).data;
export const createConfigBackup = async (payload: { label: string; lock_version: number }) => (await api.post<ConfigBackup>('/admin/system_settings/backups', payload)).data;
export const downloadConfigBackup = async (id: number) => (await api.get<Blob>(`/admin/system_settings/backups/${id}`, { responseType: 'blob' })).data;
export const restoreConfigBackup = async (payload: { document: ConfigDocument; confirmation: string; lock_version: number }) => (await api.post<SystemWorkspace>('/admin/system_settings/restore', payload)).data;
export const sendPlatformTestEmail = async () => (await api.post<{ detail: string }>('/admin/system_settings/test-email')).data;
export type PublicPlatformConfig = Pick<PlatformSettings, 'platform_name' | 'tagline' | 'organization_name' | 'support_email' | 'support_phone' | 'timezone' | 'language' | 'date_format' | 'currency' | 'platform_mode' | 'registration_enabled' | 'require_email_verification' | 'default_registration_role' | 'matching_enabled' | 'public_events_enabled' | 'support_url' | 'maintenance_message' | 'password_min_length'> & PlatformAssets;
export const getPublicPlatformConfig = async () => (await api.get<PublicPlatformConfig>('/platform/config')).data;
export interface PublicEvent { id: number; title: string; description: string; starts_at: string; image: string; location: string }
export const getPublicEvents = async () => (await api.get<PublicEvent[]>('/platform/events')).data;
