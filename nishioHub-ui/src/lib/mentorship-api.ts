import api from "@/lib/axios";
import type { Booking, Service, User } from "@/types";

export interface MentorshipMentee {
  id: number;
  name: string;
  avatar: string | null;
  school: string | null;
  grade: string | null;
  completed_sessions: number;
  total_sessions: number;
  progress: number;
}
export interface MentorGoal { id: number; title: string; completed: boolean }
export interface MentorshipResource { id: number; title: string; url: string }
export interface MentorshipSummary {
  mentor: User;
  stats: {
    mentees: number;
    sessions: number;
    hours: number;
    active_goals: number;
    completed_goals: number;
    rating: number | null;
    review_count: number;
  };
  mentees: MentorshipMentee[];
  sessions: Booking[];
  programmes: Service[];
  goals: MentorGoal[];
  resources: MentorshipResource[];
}
export async function getMyMentorship() {
  return (await api.get<MentorshipSummary>("/me/mentorship")).data;
}
export async function createMentorGoal(title: string) {
  return (await api.post("/me/mentorship/goals", { goal: { title } })).data;
}
export async function updateMentorGoal({ id, completed }: { id: number; completed: boolean }) {
  return (await api.patch(`/me/mentorship/goals/${id}`, { goal: { completed } })).data;
}
export async function createMentorshipResource(resource: { title: string; url: string }) {
  return (await api.post("/me/mentorship/resources", { resource })).data;
}
export async function deleteMentorshipResource(id: number) {
  await api.delete(`/me/mentorship/resources/${id}`);
}
export async function updateMentorshipSession({ id, status }: { id: string; status: "confirmed" | "completed" | "cancelled" }) {
  return (await api.patch(`/bookings/${id}`, { status })).data;
}
