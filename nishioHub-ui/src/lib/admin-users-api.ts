import api from './axios';
export interface UserRole { id: number; name: string }
export interface AdminUser {
  id: number; full_name: string; email: string; phone_number: string; affiliation: string; avatar: string | null;
  is_active: boolean; is_verified: boolean; primary_role_id: number | null; roles: UserRole[]; created_at: string | null;
  last_active_at: string | null; lock_version: number;
  capabilities: { update: boolean; status: boolean; password: boolean; sessions: boolean };
}
export interface UserFilters { q: string; role_id: string; role?: string; status: string; sort: string; direction: string; page: number; per_page: number }
export interface UsersWorkspace {
  users: AdminUser[]; roles: UserRole[];
  stats: { total: number; mentors: number; mentees: number; staff: number };
  distribution: { key: string; count: number }[];
  meta: { page: number; per_page: number; total: number; total_pages: number };
}
export interface ManagedRole extends UserRole {
  description: string; permissions: string[]; user_count: number; builtin: boolean; administrative: boolean;
  lock_version: number; capabilities: { edit: boolean; rename: boolean; delete: boolean };
}
export interface RolesWorkspace { roles: ManagedRole[]; permission_catalog: Record<string, string> }
export interface Access { permissions: string[]; super_admin: boolean; permission_catalog: Record<string, string> }
export interface UserPayload {
  full_name: string; email: string; phone_number: string; affiliation: string; role_ids: number[]; primary_role_id: number;
  is_active: boolean; is_verified: boolean; password?: string; lock_version?: number;
}
export interface ImportPreview { rows: { row: number; full_name: string; email: string; role: string; errors: string[] }[]; valid: boolean; ready: number; total: number }
export const getAdminAccess = async () => (await api.get<Access>('/admin/user_access')).data;
export const getAdminUsers = async (params: UserFilters) => (await api.get<UsersWorkspace>('/admin/users', { params })).data;
export const getAdminUser = async (id: number) => (await api.get<{ user: AdminUser; history: { id: number; actor_name: string; action: string; changeset: Record<string, unknown>; created_at: string }[] }>(`/admin/users/${id}`)).data;
export const createAdminUser = async (user: UserPayload) => (await api.post<AdminUser>('/admin/users', { user })).data;
export const updateAdminUser = async ({ id, user }: { id: number; user: UserPayload }) => (await api.patch<AdminUser>(`/admin/users/${id}`, { user })).data;
export const setAdminUserStatus = async ({ id, active, version }: { id: number; active: boolean; version: number }) => (await api.patch<AdminUser>(`/admin/users/${id}/status`, { account: { is_active: active }, lock_version: version })).data;
export const bulkAdminUserStatus = async (payload: { user_ids: number[]; versions: Record<string, number>; account: { is_active: boolean } }) => (await api.post<{ updated: number }>('/admin/users/bulk-status', payload)).data;
export const revokeUserSessions = async ({ id, version }: { id: number; version: number }) => (await api.post<AdminUser>(`/admin/users/${id}/revoke-sessions`, { lock_version: version })).data;
export const resetAdminUserPassword = async ({ id, version, password, password_confirmation }: { id: number; version: number; password: string; password_confirmation: string }) => (await api.post<AdminUser>(`/admin/users/${id}/password`, { lock_version: version, password_change: { password, password_confirmation } })).data;
export const exportAdminUsers = async (params: UserFilters & { user_ids?: number[] }) => (await api.get<Blob>('/admin/users/export', { params, responseType: 'blob' })).data;
export const downloadUserTemplate = async () => (await api.get<Blob>('/admin/users/import-template', { responseType: 'blob' })).data;
export async function previewUserImport(file: File) { const body = new FormData(); body.append('file', file); return (await api.post<ImportPreview>('/admin/users/import-preview', body)).data; }
export async function commitUserImport(file: File) { const body = new FormData(); body.append('file', file); return (await api.post<{ imported: number }>('/admin/users/import', body)).data; }
export const getAdminRoles = async () => (await api.get<RolesWorkspace>('/admin/roles')).data;
export const createAdminRole = async (role: { name: string; description: string; permissions: string[] }) => (await api.post<ManagedRole>('/admin/roles', { role })).data;
export const updateAdminRole = async ({ id, role }: { id: number; role: { name: string; description: string; permissions: string[]; lock_version: number } }) => (await api.patch<ManagedRole>(`/admin/roles/${id}`, { role })).data;
export const deleteAdminRole = async ({ id, version }: { id: number; version: number }) => api.delete(`/admin/roles/${id}`, { data: { lock_version: version } });
export function roleTitle(name: string) { return name.toLowerCase().replace(/[ _-]/g, '') === 'superadmin' ? 'Super Admin' : name.split(/[_ -]/).map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(' '); }
export function roleKind(name: string) { const key = name.toLowerCase().replace(/[ _-]/g, ''); return ['superadmin', 'admin', 'mentor', 'mentee'].includes(key) ? key : 'other'; }
