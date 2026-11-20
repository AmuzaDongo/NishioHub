import api from "@/lib/axios";

export interface GoalMilestone {
  id: number;
  title: string;
  target_date: string | null;
  completed: boolean;
  mentee_goal_id: number;
}
export interface PersonalGoal {
  id: number;
  title: string;
  description: string | null;
  progress: number;
  target_date: string | null;
  icon: string;
  completed: boolean;
  milestones: GoalMilestone[];
}
export interface GoalDraft {
  title: string;
  description: string;
  progress: number;
  target_date: string | null;
  icon: string;
}
export interface GoalsWorkspace {
  name: string;
  avatar: string | null;
  vision: string | null;
  goals: PersonalGoal[];
  history: { id: number; goal_id: number; goal_title: string; progress: number; note: string; created_at: string }[];
}
export const getMyGoals = async () => (await api.get<GoalsWorkspace>("/me/mentee_goals")).data;
export const saveGoal = async ({ id, goal }: { id?: number; goal: Partial<GoalDraft> }) =>
  (id ? await api.patch(`/me/mentee_goals/${id}`, { goal }) : await api.post("/me/mentee_goals", { goal })).data;
export const deleteGoal = async (id: number) => { await api.delete(`/me/mentee_goals/${id}`); };
export const saveVision = async (vision: string) => (await api.patch("/me/goal_vision", { profile: { vision } })).data;
export const addGoalMilestone = async ({ goalId, title, target_date }: { goalId: number; title: string; target_date: string | null }) =>
  (await api.post(`/me/mentee_goals/${goalId}/milestones`, { milestone: { title, target_date } })).data;
export const updateGoalMilestone = async ({ goalId, id, completed }: { goalId: number; id: number; completed: boolean }) =>
  (await api.patch(`/me/mentee_goals/${goalId}/milestones/${id}`, { milestone: { completed } })).data;
export const deleteGoalMilestone = async ({ goalId, id }: { goalId: number; id: number }) => {
  await api.delete(`/me/mentee_goals/${goalId}/milestones/${id}`);
};
