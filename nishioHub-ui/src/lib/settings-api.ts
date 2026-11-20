import api from "@/lib/axios";
import type { NotificationPreferences } from "@/lib/notifications-api";
export interface AccountPreferences {
  appearance: "light" | "dark" | "system";
  show_online_status: boolean;
  allow_contact_requests: boolean;
  learning_format: "mixed" | "reading" | "video" | "practical";
  weekly_learning_minutes: number;
  session_preference: "online" | "in_person" | "either";
  mentorship_focus: string;
}
export interface SettingsProfile { full_name: string; email: string; phone_number: string; school: string; grade: string; bio: string }
export interface EditableSettingsProfile {full_name?:string;email?:string;phone_number?:string;school?:string;grade?:string;bio?:string;location?:string;website?:string;current_password?:string;title?:string;years_of_experience?:number;hourly_rate?:number|null;languages?:string[];skills?:string[]}
export interface SettingsWorkspace {
  user: { id: number; full_name: string; email: string; phone_number: string; avatar: string | null; is_active: boolean; bio?:string|null;location?:string|null;website?:string|null;roles?:{id:number;name:string}[];management_permissions?:string[]; role: { id: number; name: string } | null };
  profile: { school: string; grade: string; bio: string };
  professional?:{title:string;years_of_experience:number;hourly_rate:number|null;currency:string;skills:string[];languages:string[]}|null;
  preferences: AccountPreferences;
  notifications: NotificationPreferences;
  session?: { access_token: string; refresh_token: string };
}
export const getSettings = async () => (await api.get<SettingsWorkspace>("/me/settings")).data;
export const saveSettingsProfile = async (profile: EditableSettingsProfile) => (await api.patch<SettingsWorkspace>("/me/settings/profile", { profile })).data;
export const saveAccountPreferences = async (preferences: Partial<AccountPreferences>) => (await api.patch<SettingsWorkspace>("/me/settings/preferences", { preferences })).data;
export const changeAccountPassword = async (password_change: { current_password: string; new_password: string; password_confirmation: string }) => (await api.patch<{ session: { access_token: string; refresh_token: string } }>("/me/settings/password", { password_change })).data;
export const uploadSettingsAvatar = async (avatar: File) => { const body = new FormData(); body.append("avatar", avatar); return (await api.post<SettingsWorkspace>("/me/settings/avatar", body)).data; };
export const exportAccountData = async () => (await api.get<Blob>("/me/settings/export", { responseType: "blob" })).data;
export const deactivateAccount = async (account: { current_password: string; confirmation: string }) => (await api.post("/me/settings/deactivate", { account })).data;

export const removeSettingsAvatar=async()=>(await api.delete<SettingsWorkspace>('/me/settings/avatar')).data;
