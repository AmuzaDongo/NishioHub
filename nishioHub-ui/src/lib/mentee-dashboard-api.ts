import api from "@/lib/axios";
import type { Booking, Category, User } from "@/types";

export interface MenteeProfile {
  name: string;
  school: string | null;
  grade: string | null;
  location: string | null;
  bio: string | null;
  avatar: string | null;
}
export interface MenteeGoal { id: number; title: string; completed: boolean }
export interface MenteeDashboard {
  profile: MenteeProfile;
  mentor: User | null;
  next_session: Booking | null;
  completed_sessions: number;
  upcoming_sessions: number;
  milestone: number;
  session_progress: number;
  goal_progress: number;
  goals: MenteeGoal[];
  achievements: string[];
  learning_areas: Category[];
}
export const getMenteeDashboard = async () => (await api.get<MenteeDashboard>("/me/mentee_dashboard")).data;
export const saveMenteeProfile = async (profile: Partial<MenteeProfile>) =>
  (await api.patch("/me/mentee_profile", { profile })).data;
export const createMenteeGoal = async (title: string) =>
  (await api.post("/me/mentee_goals", { goal: { title } })).data;
export const updateMenteeGoal = async (id: number, completed: boolean) =>
  (await api.patch(`/me/mentee_goals/${id}`, { goal: { completed } })).data;
