import { programRequestBody } from './program-banner';
import api from './axios';
export interface ReportingFilter { period: string; from?: string; to?: string; q?: string }
export interface PageMeta { page: number; total: number; total_pages: number; per_page?: number }
export interface DashboardActivity { id: string; entity_id: number; kind: string; title: string; description: string; occurred_at: string }
export interface DashboardReport {
  period: { from: string; to: string; days: number; timezone: string };
  metrics: { key: string; value: number; previous: number; change: number | null }[];
  growth: { date: string; users: number }[];
  distribution: { key: string; count: number }[];
  activities: DashboardActivity[]; top_programs: { id: number; title: string; members: number }[];
  upcoming_events: { id: number; title: string; starts_at: string; ends_at: string; registrations: number }[];
  insights: { user_growth: number | null; new_users: number; previous_new_users: number; goal_completion: number | null; goal_count: number; session_rating: number | null; review_count: number };
  capabilities: { view_users: boolean; manage: boolean; add_user: boolean; schedule: boolean };
  search_results: { id: number; kind: string; title: string; description: string }[];
}
export interface PlatformHealth {
  checked_at: string; uptime_seconds: number | null; uptime_scope: string;
  checks: { key: string; label: string; status: 'ok' | 'attention' | 'unknown'; value: string; detail: string }[];
}
export type RecordType = 'programs' | 'sessions' | 'events' | 'resources' | 'activities';
export interface OperationRecord {
  banner_url?: string | null; banner_filename?: string | null; id: number; kind: 'program' | 'session' | 'event' | 'resource'; title: string; description: string; status: string; created_at: string;
  starts_on?: string | null; ends_on?: string | null; member_count?: number; session_count?: number; lock_version?: number;
  scheduled_at?: string; duration?: number; updated_at?: string; mentor?: { id: number; name: string }; mentee?: { id: number; name: string };
  program?: { id: number; title: string } | null; can_complete?: boolean;
  starts_at?: string; ends_at?: string; category?: string; location?: string; meeting_url?: string | null; capacity?: number | null; registrations?: number;
  published?: boolean; url?: string | null; platform_program_id?: number | null; file?: { filename: string; byte_size: number; download_path: string } | null;
}
export interface DashboardOptions {
  people: { id: number; name: string; mentor: boolean; mentee: boolean }[];
  services: { id: number; title: string; mentor_id: number; mentor_name: string; duration: number; price: number }[];
  programs: { id: number; title: string }[]; categories: { id: number; name: string }[];
}
export interface ProgramDraft { banner?: File | null; remove_banner?: boolean; title: string; description: string; status: string; starts_on: string | null; ends_on: string | null; participant_ids?: number[]; lock_version?: number }
export interface EventDraft { title: string; description: string; category: string; starts_at: string; ends_at: string; location: string; meeting_url: string; capacity: number | null; updated_at?: string }
export interface SessionDraft { service_id?: number; mentor_id?: number; mentee_id: number; scheduled_at: string; platform_program_id: number | null; title?: string; description?: string; duration?: number; price?: number; category_id?: number }
export interface ResourceDraft { title: string; description: string; url: string; published: boolean; platform_program_id: number | null; file?: File | null; lock_version?: number }
export const getAdminDashboard = async (params: ReportingFilter) => (await api.get<DashboardReport>('/admin/dashboard', { params })).data;
export const searchDashboard = async (q: string) => (await api.get<DashboardReport['search_results']>('/admin/dashboard/search', { params: { q } })).data;
export const getDashboardHealth = async () => (await api.get<PlatformHealth>('/admin/dashboard/health')).data;
export const getOperationRecords = async (type: RecordType, page: number, filters: ReportingFilter & { status?: string; window?: string }) => (await api.get<{ items: (OperationRecord | DashboardActivity)[]; meta: PageMeta }>('/admin/dashboard/records', { params: { ...filters, type, page } })).data;
export const getOperationRecord = async (type: Exclude<RecordType, 'activities'>, id: number) => (await api.get<OperationRecord>(`/admin/dashboard/${type}/${id}`)).data;
export const getDashboardOptions = async (q: string) => (await api.get<DashboardOptions>('/admin/dashboard/options', { params: { q } })).data;
export const saveProgram = async ({ id, program }: { id?: number; program: ProgramDraft }) => (await (id ? api.patch<OperationRecord>(`/admin/dashboard/programs/${id}`, programRequestBody(program)) : api.post<OperationRecord>('/admin/dashboard/programs', programRequestBody(program)))).data;
export const getProgramMembers = async (id: number, page: number) => (await api.get<{ items: { id: number; name: string; roles: string[]; active: boolean }[]; meta: PageMeta }>(`/admin/dashboard/programs/${id}/members`, { params: { page } })).data;
export const addProgramMembers = async ({ id, user_ids }: { id: number; user_ids: number[] }) => (await api.post<OperationRecord>(`/admin/dashboard/programs/${id}/members`, { user_ids })).data;
export const removeProgramMember = async ({ id, userId }: { id: number; userId: number }) => api.delete(`/admin/dashboard/programs/${id}/members/${userId}`);
export const createAdminSession = async (session: SessionDraft) => (await api.post<OperationRecord>('/admin/dashboard/sessions', { session })).data;
export const changeAdminSession = async ({ id, status, updated_at }: { id: number; status: string; updated_at: string }) => (await api.patch<OperationRecord>(`/admin/dashboard/sessions/${id}`, { session: { status, updated_at } })).data;
export const saveAdminEvent = async ({ id, event }: { id?: number; event: EventDraft }) => (await (id ? api.patch<OperationRecord>(`/admin/dashboard/events/${id}`, { event }) : api.post<OperationRecord>('/admin/dashboard/events', { event }))).data;
export async function savePlatformResource({ id, resource }: { id?: number; resource: ResourceDraft }) {
  const body = new FormData();
  body.append('resource[title]', resource.title); body.append('resource[description]', resource.description);
  body.append('resource[url]', resource.url); body.append('resource[published]', String(resource.published));
  body.append('resource[platform_program_id]', resource.platform_program_id === null ? '' : String(resource.platform_program_id));
  if (resource.file) body.append('resource[file]', resource.file);
  if (resource.lock_version !== undefined) body.append('resource[lock_version]', String(resource.lock_version));
  return (await (id ? api.patch<OperationRecord>(`/admin/dashboard/resources/${id}`, body) : api.post<OperationRecord>('/admin/dashboard/resources', body))).data;
}
export const downloadPlatformResource = async (path: string) => (await api.get<Blob>(path, { responseType: 'blob' })).data;
