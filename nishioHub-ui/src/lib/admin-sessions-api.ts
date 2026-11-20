import api from './axios';
import type { ProgramPerson, PageMeta } from './admin-programs-api';
export type SessionFormat = 'online' | 'live' | 'on_site';
export interface AdminSession {
  id: number; title: string; description: string; program: { id: number; title: string } | null;
  mentor: ProgramPerson; category_id: number; scheduled_at: string; ends_at: string; duration: number;
  format: SessionFormat; status: string; display_status: string; attendees: number; attended: number;
  location: string | null; meeting_url: string | null; updated_at: string; can_edit: boolean; can_complete: boolean; can_attend: boolean;
}
export interface SessionDetail extends AdminSession { participants: ProgramPerson[] }
export interface SessionDraft { title: string; description: string; mentor_id: number | null; category_id: number | null; program_id: number | null; mentee_ids: number[]; scheduled_at: string; duration: number; format: SessionFormat; location: string; meeting_url: string; updated_at?: string }
export interface SessionFilters { q: string; tab: string; program_id: string; mentor_id: string; format: string; status: string; sort: string; direction: string; page: number; per_page: number; months: string }
export interface SessionWorkspace { items: AdminSession[]; meta: PageMeta; capabilities: { manage: boolean; schedule: boolean }; stats: { total: number; completed: number; upcoming: number; attendees: number; growth: number | null }; distribution: { key: string; count: number }[]; trend: { month: string; attendance: number }[]; trend_change: number | null; top_programs: { id: number; title: string; count: number }[] }
export interface SessionParticipant { id: number; user_id: number; name: string; avatar: string | null; registered_at?: string; attended: boolean | null; recorded_at: string | null }
export interface SessionPreview { valid: boolean; ready: number; total: number; rows: { row: number; title: string; errors: string[] }[] }
export const getAdminSessions = async (params: SessionFilters) => (await api.get<SessionWorkspace>('/admin/sessions', { params })).data;
export const getAdminSession = async (id: number) => (await api.get<SessionDetail>(`/admin/sessions/${id}`)).data;
export const saveAdminSession = async (id: number | undefined, session: SessionDraft) => (await (id ? api.patch<AdminSession>(`/admin/sessions/${id}`, { session }) : api.post<AdminSession>('/admin/sessions', { session }))).data;
export const changeSessionStatus = async (session: AdminSession, status: string) => (await api.patch<AdminSession>(`/admin/sessions/${session.id}/status`, { session: { status, updated_at: session.updated_at } })).data;
export const getSessionParticipants = async (id: number, page: number, q = '') => (await api.get<{ items: SessionParticipant[]; meta: PageMeta }>(`/admin/sessions/${id}/participants`, { params: { page, q } })).data;
export const recordSessionAttendance = async (session: AdminSession, participant: number, attended: boolean | null) => api.patch(`/admin/sessions/${session.id}/participants/${participant}`, { attendance: { attended, updated_at: session.updated_at } });
export const sessionProgramOptions = async (q: string, activeOnly: boolean) => (await api.get<{ programs: { id: number; title: string }[] }>('/admin/sessions/options', { params: { q, active_only: activeOnly } })).data;
export const exportSessions = async (params: SessionFilters, ids: number[]) => (await api.get<Blob>('/admin/sessions/export', { params: { ...params, ...(ids.length ? { session_ids: ids } : {}) }, responseType: 'blob' })).data;
export const sessionTemplate = async () => (await api.get<Blob>('/admin/sessions/import-template', { responseType: 'blob' })).data;
export async function sessionCsv(file: File, commit: boolean): Promise<SessionPreview | { imported: number }> { const form = new FormData(); form.append('file', file); return (await api.post(commit ? '/admin/sessions/import' : '/admin/sessions/import-preview', form)).data; }
