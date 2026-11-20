import api from "@/lib/axios";
export type EventCategory = "workshop" | "talk" | "challenge" | "mentorship";
export interface CommunityEvent {
  status: "draft" | "published" | "cancelled"; display_status: string; id: number; title: string; description: string; category: EventCategory;
  starts_at: string; ends_at: string; location: string; image: string;
  capacity: number | null; available_places: number | null; meeting_url: string | null;
  organizer: { id: number; name: string }; can_manage: boolean;
  registration: { id: number; status: "registered" | "cancelled"; attended_at: string | null; reminder_minutes: number } | null;
}
export interface EventsWorkspaceData {
  name: string; avatar: string | null; events: CommunityEvent[]; registrations: CommunityEvent[];
  hosted_events: CommunityEvent[]; suggestions: { id: number; title: string; category: string; created_at: string }[];
  summary: { registered: number; attended: number; upcoming: number };
}
export interface EventDraft { title: string; description: string; category: EventCategory; starts_at: string; ends_at: string; location: string; meeting_url?: string; capacity: number | null }
export interface EventAttendee { id: number; name: string; attended: boolean }
export const getEventsWorkspace = async () => (await api.get<EventsWorkspaceData>("/events")).data;
export const getCommunityEvent = async (id: number) => (await api.get<CommunityEvent>(`/events/${id}`)).data;
export const createCommunityEvent = async (event: EventDraft) => (await api.post<CommunityEvent>("/events", { event })).data;
export const suggestCommunityEvent = async (suggestion: Pick<EventDraft, "title" | "description" | "category">) => (await api.post("/events/suggestions", { suggestion })).data;
export const registerForEvent = async (id: number) => (await api.post(`/events/${id}/registration`)).data;
export const cancelEventRegistration = async (id: number) => { await api.delete(`/events/${id}/registration`); };
export const updateEventReminder = async ({ id, minutes }: { id: number; minutes: number }) => (await api.patch(`/events/${id}/registration`, { registration: { reminder_minutes: minutes } })).data;
export const downloadEventCalendar = async (id: number) => (await api.get<Blob>(`/events/${id}/calendar`, { responseType: "blob" })).data;
export const getEventAttendees = async (id: number) => (await api.get<EventAttendee[]>(`/events/${id}/attendees`)).data;
export const recordEventAttendance = async ({ eventId, id, attended }: { eventId: number; id: number; attended: boolean }) => (await api.patch(`/events/${eventId}/attendees/${id}`, { registration: { attended } })).data;
