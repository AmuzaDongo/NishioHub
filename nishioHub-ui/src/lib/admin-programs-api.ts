import type { ProgramPublicDetails, ProgramDiscovery } from './public-programs-api';
import { programRequestBody } from './program-banner';
import api from './axios';
import type { OperationRecord } from './admin-dashboard-api';
export type ProgramStatus = 'active' | 'draft' | 'archived';
export interface ProgramPerson { id: number; name: string; avatar?: string | null; active?: boolean }
export interface AdminProgram extends ProgramDiscovery {
  banner_url?: string | null; banner_filename?: string | null; id: number; title: string; description: string; icon: string; category: { id: number; name: string } | null;
  mentors: ProgramPerson[]; enrolled: number; progress: number; rating: number | null; status: ProgramStatus;
  display_status: ProgramStatus | 'ongoing'; starts_on: string | null; ends_on: string | null; lock_version: number;
}
export interface ProgramFilters { q: string; tab: string; status: string; category_id: string; mentor_id: string; sort: string; direction: string; page: number; per_page: number; months: string; rated_only?: string }
export interface ProgramWorkspace {
  programs: AdminProgram[]; meta: PageMeta; capabilities: { manage: boolean; view_users: boolean };
  stats: { total: number; enrollments: number; active_participants: number; rating: number | null; review_count: number; program_change: number | null; enrollment_change: number | null };
  distribution: { id: number | string | null; name: string; count: number }[]; trend: { month: string; enrollments: number }[]; trend_change: number | null; months: number; timezone: string; top_programs: AdminProgram[];
}
export interface PageMeta { page: number; total: number; total_pages: number; per_page: number }
export interface ProgramDraft extends Partial<ProgramDiscovery> { banner?: File | null; remove_banner?: boolean; title: string; description: string; icon: string; category_id: number | null; status: ProgramStatus; starts_on: string | null; ends_on: string | null; mentor_ids: number[]; lock_version?: number }
export interface Enrollment { id: number; user_id: number; name: string; avatar: string | null; email?: string | null; account_active: boolean; active: boolean; progress: number; completed_at: string | null; joined_at: string; lock_version: number }
export interface ProgramImportPreview { rows: { row: number; title: string; category: string; errors: string[] }[]; valid: boolean; ready: number; total: number }
export const getPrograms = async (params: ProgramFilters) => (await api.get<ProgramWorkspace>('/admin/programs', { params })).data;
export const getProgram = async (id: number) => (await api.get<ProgramDetail>(`/admin/programs/${id}`)).data;
export const programOptions = async (q: string, kind: string, activeOnly: boolean) => (await api.get<{ people: ProgramPerson[]; categories: { id: number; name: string }[] }>('/admin/programs/options', { params: { q, kind, active_only: activeOnly } })).data;
export const saveAdminProgram = async ({ id, program }: { id?: number; program: ProgramDraft & Partial<ProgramDetailsFields> }) => (await (id ? api.patch<AdminProgram>(`/admin/programs/${id}`, programRequestBody(program)) : api.post<AdminProgram>('/admin/programs', programRequestBody(program)))).data;
export const programBulkStatus = async (programs: AdminProgram[], status: ProgramStatus) => (await api.post('/admin/programs/bulk-status', { program_ids: programs.map(p => p.id), versions: Object.fromEntries(programs.map(p => [p.id, p.lock_version])), status })).data;
export const programMembers = async (id: number, page: number, q: string, status: string) => (await api.get<{ items: Enrollment[]; meta: PageMeta }>(`/admin/programs/${id}/members`, { params: { page, q, status } })).data;
export const enrollProgramMembers = async (id: number, user_ids: number[]) => api.post(`/admin/programs/${id}/members`, { user_ids });
export const updateEnrollment = async (id: number, member: Enrollment, progress: number) => api.patch(`/admin/programs/${id}/members/${member.id}`, { enrollment: { progress, lock_version: member.lock_version } });
export const withdrawEnrollment = async (id: number, member: Enrollment) => api.delete(`/admin/programs/${id}/members/${member.id}`, { data: { lock_version: member.lock_version } });
export const programRecords = async (id: number, type: string, page: number) => (await api.get<{ items: OperationRecord[]; meta: PageMeta }>(`/admin/programs/${id}/records/${type}`, { params: { page } })).data;
export const exportPrograms = async (params: ProgramFilters, ids: number[]) => (await api.get<Blob>('/admin/programs/export', { params: { ...params, ...(ids.length ? { program_ids: ids } : {}) }, responseType: 'blob' })).data;
export const programTemplate = async () => (await api.get<Blob>('/admin/programs/import-template', { responseType: 'blob' })).data;
async function csvRequest(file: File, route: string) { const body = new FormData(); body.append('file', file); return api.post(route, body); }
export const previewPrograms = async (file: File) => (await csvRequest(file, '/admin/programs/import-preview')).data as ProgramImportPreview;
export const importPrograms = async (file: File) => (await csvRequest(file, '/admin/programs/import')).data as { imported: number };

export interface ProgramDetailsFields {
  public_details: ProgramPublicDetails;
  capacity: number | null; objectives: string[]; target_audience: string; delivery_mode: 'online' | 'in_person' | 'hybrid';
  registration_starts_on: string | null; registration_ends_on: string | null; evaluation_starts_on: string | null; evaluation_ends_on: string | null;
}
export interface ProgramDetail extends AdminProgram, ProgramDetailsFields {
  sessions: number; resources: number; progress_counts: { completed: number; in_progress: number; not_started: number };
  capabilities: { manage: boolean; view_users: boolean; schedule: boolean };
}
