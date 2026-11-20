import api from './axios';
import type { AdminAchievement } from './admin-achievements-api';
import type { PageMeta } from './admin-programs-api';
export type CriterionCategory = 'modules' | 'assessments' | 'project' | 'other';
export interface AchievementCriterion { id: string; title: string; category: CriterionCategory; completed_units: number; target_units: number; completed_at: string | null; lock_version: number; editable: boolean }
export interface AchievementNote { id: number; body: string; author: string; created_at: string; updated_at: string; lock_version: number }
export interface AchievementGoal { id: number; goal_key: string; title: string; progress: number; status: 'completed' | 'on_track' | 'in_progress' | 'at_risk'; target_date: string | null; archived: boolean; lock_version: number }
export interface AchievementActivity { id: string; title: string; body: string; author: string | null; at: string }
export interface AchievementDetails extends AdminAchievement {
  learner: AdminAchievement['learner'] & { phone: string | null }; cohort: string | null; joined_at: string | null;
  criteria_description: string | null; criteria: AchievementCriterion[];
  metrics: { modules: { completed: number; total: number } | null; assessments: { completed: number; total: number } | null; project: { completed: number; total: number } | null; overall_progress: number | null; final_score: number | null };
  certificate: { id: string; title: string; issued_at: string } | null; can_issue_certificate: boolean;
  notes_count: number; goals_count: number; recent_activity: AchievementActivity[]; recent_notes: AchievementNote[];
  capabilities: { manage: boolean; edit: boolean };
}
export type AchievementSectionItem = AchievementCriterion | AchievementNote | AchievementGoal | AchievementActivity;
export interface AwardCorrection { title: string; description: string; icon: string; color: string; cohort_label: string; criteria_snapshot: string; final_score: number | null; platform_program_id: number | null; lock_version: number }
export const getAchievementDetails = async (id: string) => (await api.get<AchievementDetails>(`/admin/achievements/${id}/details`)).data;
export const getAchievementSection = async (id: string, section: string, page = 1, q = '') => (await api.get<{ items: AchievementSectionItem[]; meta: PageMeta }>(`/admin/achievements/${id}/sections/${section}`, { params: { page, q } })).data;
export const correctAchievement = async (id: string, achievement: AwardCorrection) => { await api.patch(`/admin/achievements/${id}/details`, { achievement }); };
export const saveAchievementCriterion = async (id: string, criterion: Omit<AchievementCriterion, 'id' | 'completed_at' | 'editable'>, item?: AchievementCriterion) => { await api.request({ url: `/admin/achievements/${id}/criteria${item ? `/${item.id}` : ''}`, method: item ? 'patch' : 'post', data: { criterion } }); };
export const removeAchievementCriterion = async (id: string, item: AchievementCriterion) => { await api.delete(`/admin/achievements/${id}/criteria/${item.id}`, { params: { lock_version: item.lock_version } }); };
export const saveAchievementNote = async (id: string, body: string, item?: AchievementNote) => { await api.request({ url: `/admin/achievements/${id}/notes${item ? `/${item.id}` : ''}`, method: item ? 'patch' : 'post', data: { note: { body, ...(item ? { lock_version: item.lock_version } : {}) } } }); };
export const removeAchievementNote = async (id: string, item: AchievementNote) => { await api.delete(`/admin/achievements/${id}/notes/${item.id}`, { params: { lock_version: item.lock_version } }); };
export const getEligibleAchievementGoals = async (id: string, q: string, page = 1) => (await api.get<{ items: { id: number; title: string; progress: number; goal_key: string }[]; meta: PageMeta }>(`/admin/achievements/${id}/eligible_goals`, { params: { q, page } })).data;
export const linkAchievementGoal = async (id: string, goal_id: number) => { await api.post(`/admin/achievements/${id}/goals`, { goal_id }); };
export const unlinkAchievementGoal = async (id: string, item: AchievementGoal) => { await api.delete(`/admin/achievements/${id}/goals/${item.id}`, { params: { lock_version: item.lock_version } }); };
export const getAchievementCertificate = async (id: string) => (await api.get<Blob>(`/admin/achievements/${id}/details/certificate`, { responseType: 'blob' })).data;
export const issueMissingAchievementCertificate = async (id: string) => { await api.post(`/admin/achievements/${id}/details/certificate`); };
export const downloadAchievementDetailsRecord = async (id: string) => (await api.get<Blob>(`/admin/achievements/${id}/record`, { responseType: 'blob' })).data;
