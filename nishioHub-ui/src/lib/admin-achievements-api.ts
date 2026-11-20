import api from './axios';
import type { PageMeta, ProgramPerson } from './admin-programs-api';
export type AchievementKind = 'course_completion' | 'program_completion' | 'skill_badge' | 'special_recognition' | 'certificate' | 'other';
export interface AdminAchievement {
  id: string; source: 'automatic' | 'manual'; kind: AchievementKind; title: string; description: string | null;
  icon: string; color: string; awarded_at: string; definition_key: string | null; certificate_id: string | null;
  lock_version: number; revoked_at: string | null; revocation_reason: string | null; issuer: string | null;
  learner: ProgramPerson & { email: string }; program: { id: number; title: string; status: string } | null;
}
export interface AchievementDefinition {
  id: string; definition_id: number | null; title: string; description: string | null; criteria: string | null;
  kind: AchievementKind; icon: string; color: string; active: boolean; lock_version: number; automatic: boolean; awarded: number;
}
export interface AwardedPerson extends ProgramPerson { email: string; count: number; latest_at: string }
export interface AchievementFilters {
  q: string; tab: string; kind: string; status: string; program_id: string; user_id: string; definition_key: string;
  page: number; per_page: number; months: string; sort: string; direction: string; include_archived: string;
}
export interface AchievementWorkspace {
  mode: 'awards' | 'badges' | 'people'; items: (AdminAchievement | AchievementDefinition | AwardedPerson)[]; meta: PageMeta;
  capabilities: { manage: boolean }; stats: { total: number; learners: number; badges: number; certificates: number; changes: Record<string, number | null> };
  distribution: { kind: AchievementKind; count: number }[]; trend: { month: string; count: number }[]; trend_change: number | null;
  top_badges: { key: string; title: string; icon: string; color: string; count: number }[];
  top_programs: { id: number; title: string; count: number }[]; timezone: string;
}
export interface DefinitionDraft { title: string; description: string; criteria: string; kind: AchievementKind; icon: string; color: string }
export const getAdminAchievements = async (params: AchievementFilters) => (await api.get<AchievementWorkspace>('/admin/achievements', { params })).data;
export const getAdminAchievement = async (id: string) => (await api.get<AdminAchievement>(`/admin/achievements/${id}`)).data;
export const getAchievementDefinitions = async (q: string, page = 1) => (await api.get<{ items: AchievementDefinition[]; meta: PageMeta }>('/admin/achievements/definitions', { params: { q, page, per_page: 20, custom_only: true } })).data;
export const saveAchievementDefinition = async (definition: DefinitionDraft, record?: AchievementDefinition, issuance?: { user_ids: number[]; program_id: number | null; awarded_on: string }) => {
  await api.request({ url: record ? `/admin/achievements/definitions/${record.definition_id}` : '/admin/achievements', method: record ? 'patch' : 'post', data: { definition: { ...definition, ...(record ? { lock_version: record.lock_version } : {}) }, ...issuance } });
};
export const setAchievementDefinitionActive = async (record: AchievementDefinition) => { await api.patch(`/admin/achievements/definitions/${record.definition_id}`, { definition: { is_active: !record.active, lock_version: record.lock_version } }); };
export const issueAchievement = async (id: number, user_ids: number[], program_id: number | null, awarded_on: string) => { await api.post(`/admin/achievements/definitions/${id}/award`, { user_ids, program_id, awarded_on }); };
export const revokeAchievement = async (record: AdminAchievement, reason: string) => { await api.post(`/admin/achievements/${record.id}/revoke`, { reason, lock_version: record.lock_version }); };
export const downloadAdminCertificate = async (id: string) => (await api.get<Blob>(`/admin/achievements/${id}/certificate`, { responseType: 'blob' })).data;
export const exportAdminAchievements = async (params: AchievementFilters, award_ids: string[], report = false) => (await api.get<Blob>(`/admin/achievements/${report ? 'report' : 'export'}`, { params: { ...params, ...(award_ids.length ? { award_ids } : {}) }, responseType: 'blob' })).data;
