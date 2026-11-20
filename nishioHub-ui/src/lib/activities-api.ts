import api from "@/lib/axios";
export type ActivityStatus = "completed" | "in_progress" | "upcoming" | "cancelled";
export type ActivityCategory = "learning" | "mentorship" | "events" | "challenges";
export interface LearnerActivity {
  id: string;
  category: ActivityCategory;
  icon: "book" | "play" | "laptop" | "users" | "target" | "trophy" | "calendar";
  title: string;
  description: string;
  status: ActivityStatus;
  occurred_at: string;
  href: string;
}
export interface MyActivitiesData {
  name: string;
  avatar: string | null;
  activities: LearnerActivity[];
  stats: { total: number; completed: number; in_progress: number; upcoming: number };
}
export async function getMyActivities() {
  return (await api.get<MyActivitiesData>("/me/activities")).data;
}
