import api from "@/lib/axios";
export interface AchievementBadge {
  id: string; name: string; description: string; icon: string; color: string;
  earned: boolean; earned_at: string | null; href: string;
}
export interface LearningCertificate {
  id: string; title: string; course_id: string; issued_at: string;
}
export interface AchievementEntry {
  id: string; title: string; description: string; kind: "completed" | "badge" | "certificate";
  icon: string; occurred_at: string; href?: string; certificate_id?: string;
}
export interface AchievementsData {
  name: string; avatar: string | null; vision: string | null;
  summary: { courses: number; badges: number; certificates: number; progress: number };
  badges: AchievementBadge[]; certificates: LearningCertificate[]; achievements: AchievementEntry[];
  milestones: { id: number; title: string; goal_title: string; completed: boolean; target_date: string | null; href: string }[];
}
export const getMyAchievements = async () => (await api.get<AchievementsData>("/me/achievements")).data;
export async function downloadAchievementRecord() {
  return (await api.get<Blob>("/me/achievements/record", { responseType: "blob" })).data;
}
export async function downloadLearningCertificate(id: string) {
  return (await api.get<Blob>(`/me/achievements/certificates/${id}`, { responseType: "blob" })).data;
}
export function saveDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1000);
}
