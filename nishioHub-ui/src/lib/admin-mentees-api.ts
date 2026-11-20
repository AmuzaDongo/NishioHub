import api from './axios';
import type { AdminUser, ImportPreview } from './admin-users-api';
export type MenteeStatus = 'active' | 'inactive' | 'graduated' | 'suspended';
export interface ManagedMentee extends AdminUser {
  programs: { id: number; title: string }[];
  status: MenteeStatus; progress: number; completed_sessions: number; profile_version: number;
  education: string | null; interests: string[]; bio: string | null;
  school: string | null; grade: string | null; location: string | null;
  assigned_mentor_id: number | null; primary_program_id: number | null;
  mentor: { id: number; name: string; avatar: string | null; active: boolean } | null;
  program: { id: number; title: string; status: string } | null;
}
export interface MenteeFilters { q: string; tab: string; status: string; program_id: string; mentor_id: string; sort: string; direction: string; page: number; per_page: number }
export interface MenteeWorkspace {
  mentees: ManagedMentee[]; meta: { page: number; per_page: number; total: number; total_pages: number };
  capabilities: Record<'create' | 'update' | 'status' | 'import' | 'export', boolean>;
  stats: { total: number; active: number; new_this_month: number; engaged: number; engagement_rate: number; satisfaction: number | null; review_count: number; total_change: number | null; new_change: number | null };
  statuses: Record<MenteeStatus, number>; distribution: { id: number | string | null; name: string; count: number }[];
  growth: { month: string; total: number }[]; growth_change: number | null; timezone: string;
  engagement: { key: string; label: string; count: number }[];
}
export interface MenteeDetail {
  mentee: ManagedMentee; programs: { id: number; title: string; status: string }[];
  goals: { id: number; title: string; progress: number; completed: boolean; target_date: string | null }[];
  sessions: { id: number; title: string; mentor: string; status: string; scheduled_at: string }[];
  history: { id: number; actor_name: string; action: string; created_at: string }[];
}
export interface MenteeDraft { full_name: string; email: string; phone_number: string; school: string; grade: string; location: string; education?: string; interests?: string[]; bio?: string; password?: string; status?: MenteeStatus; mentor_id?: number | null; program_id?: number | null; lock_version?: number; profile_version?: number }
export const getMentees = async (params: MenteeFilters) => (await api.get<MenteeWorkspace>('/admin/mentees', { params })).data;
export const getMentee = async (id: number) => (await api.get<MenteeDetail>(`/admin/mentees/${id}`)).data;
export const getMenteeOptions = async (q: string, activeOnly = false) => (await api.get<{ mentors: { id: number; name: string }[]; programs: { id: number; name: string }[] }>('/admin/mentees/options', { params: { q, active_only: activeOnly } })).data;
export const saveMentee = async ({ id, mentee }: { id?: number; mentee: MenteeDraft }) => (await (id ? api.patch<ManagedMentee>(`/admin/mentees/${id}`, { mentee }) : api.post<ManagedMentee>('/admin/mentees', { mentee }))).data;
export const setMenteeStatus = async ({ mentee, status }: { mentee: ManagedMentee; status: MenteeStatus }) => (await api.patch<ManagedMentee>(`/admin/mentees/${mentee.id}/status`, { mentee: { status, lock_version: mentee.lock_version, profile_version: mentee.profile_version } })).data;
export const bulkMenteeStatus = async ({ mentees, status }: { mentees: ManagedMentee[]; status: MenteeStatus }) => (await api.post('/admin/mentees/bulk-status', { status, user_ids: mentees.map(m => m.id), versions: Object.fromEntries(mentees.map(m => [m.id, { lock_version: m.lock_version, profile_version: m.profile_version }])) })).data;
export const exportMentees = async (filters: MenteeFilters, userIds: number[]) => (await api.get<Blob>('/admin/mentees/export', { params: { ...filters, ...(userIds.length ? { user_ids: userIds } : {}) }, responseType: 'blob' })).data;
export const menteeTemplate = async () => (await api.get<Blob>('/admin/mentees/import-template', { responseType: 'blob' })).data;
async function importFile(file: File, path: string) { const body = new FormData(); body.append('file', file); return api.post(path, body); }
export const previewMentees = async (file: File) => (await importFile(file, '/admin/mentees/import-preview')).data as ImportPreview;
export const importMentees = async (file: File) => (await importFile(file, '/admin/mentees/import')).data as { imported: number };
