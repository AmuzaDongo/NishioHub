import api from "@/lib/axios";
export type NotificationCategory = "mentorship" | "learning" | "events" | "system";
export type NotificationTopic = "mentorship" | "learning" | "events" | "goals" | "platform";
export type NotificationPreferences = Record<NotificationTopic, boolean>;
export interface UserNotification {
  id: number; title: string; message: string; read: boolean; category: NotificationCategory;
  topic: NotificationTopic; icon: string; href: string; created_at: string;
}
export interface NotificationsWorkspaceData {
  name: string; avatar: string | null; notifications: UserNotification[];
  counts: Record<NotificationCategory | "all" | "unread", number>;
  preferences: NotificationPreferences;
  meta: { page: number; total: number; total_pages: number };
}
export async function getNotificationsWorkspace(options: { page: number; category: string; q: string; unread: boolean }) {
  return (await api.get<NotificationsWorkspaceData>("/me/notifications", { params: options })).data;
}
export const setNotificationRead = async ({ id, read }: { id: number; read: boolean }) =>
  (await api.patch(`/notifications/${id}`, { notification: { read } })).data;
export const markAllNotificationsRead = async () => (await api.patch("/notifications/read-all")).data;
export const updateNotificationPreferences = async (preferences: Partial<NotificationPreferences>) =>
  (await api.patch<NotificationPreferences>("/me/notification_preferences", { preferences })).data;
export const getUnreadNotificationCount = async () => (await api.get<{ unread: number }>("/notifications/unread-count")).data;
