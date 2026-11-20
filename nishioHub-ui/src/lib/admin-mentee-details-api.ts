import api from './axios';
import type { ManagedMentee } from './admin-mentees-api';
export type DetailSection = 'sessions' | 'progress' | 'goals' | 'achievements' | 'reviews' | 'activity';
export interface DetailSession { id: number; title: string; mentor: string; status: string; scheduled_at: string; duration: number; updated_at: string; can_complete: boolean }
export interface DetailGoal { id: number; title: string; description: string | null; progress: number; completed: boolean; target_date: string | null; milestone_count: number; milestones: { id: number; title: string; completed: boolean; target_date: string | null }[] }
export interface DetailCourse { id: number; title: string; course_key: string; completed: boolean; progress: number; completed_lessons: number; total_lessons: number; lessons: { id: string; title: string; completed: boolean }[] }
export interface DetailAchievement { id: string; name: string; description: string; icon: string; color: string; earned_at: string; kind: 'badge' | 'certificate' }
export interface DetailReview { id: number; rating: number; comment: string; mentor: string; service: string; created_at: string }
export interface DetailActivity { id: string; kind: string; title: string; description: string; occurred_at: string }
export interface MenteeOverview {
  mentee: ManagedMentee; expected_completion: string | null; satisfaction: { rating: number | null; count: number };
  stats: { sessions_attended: number; completed: number; in_progress: number; resources_used: number; achievements: number; engagement: { percent: number; active_days: number; days: number } };
  profile: { education: string | null; interests: string[]; bio: string | null; location: string; school: string | null; grade: string | null };
  progress: DetailCourse[]; goals: DetailGoal[]; sessions: DetailSession[]; achievements: DetailAchievement[];
  activity_summary: { since: string; sessions_attended: number; resources_accessed: number; mentor_interactions: number; time_on_platform_minutes: null };
  capabilities: { manage_sessions: boolean; message: boolean; export: boolean };
}
export interface SectionItems { sessions: DetailSession; progress: DetailCourse; goals: DetailGoal; achievements: DetailAchievement; reviews: DetailReview; activity: DetailActivity }
export type DetailItem = SectionItems[DetailSection];
export interface DetailPage { items: DetailItem[]; meta: { page: number; total: number; total_pages: number; per_page: number } }
export const getMenteeOverview = async (id: string) => (await api.get<MenteeOverview>(`/admin/mentees/${id}/details`)).data;
export const getMenteeSection = async (id: string, section: DetailSection, page: number, q: string) => (await api.get<DetailPage>(`/admin/mentees/${id}/sections/${section}`, { params: { page, q } })).data;
export async function uploadMenteeAvatar({ id, file, version }: { id: number; file: File; version: number }) { const body = new FormData(); body.append('avatar', file); body.append('lock_version', String(version)); return (await api.post<ManagedMentee>(`/admin/mentees/${id}/avatar`, body)).data; }
export const downloadMenteeCertificate = async (id: string, certificateId: string) => (await api.get<Blob>(`/admin/mentees/${id}/certificates/${certificateId}`, { responseType: 'blob' })).data;
