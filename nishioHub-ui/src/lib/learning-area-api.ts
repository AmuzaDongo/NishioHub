import api from "@/lib/axios";

export interface LearningLesson {
  id: string;
  title: string;
  content: string;
  practice: string;
  minutes: number;
}
export interface LearningCourse {
  id: string;
  title: string;
  category_id: string;
  level: string;
  featured: boolean;
  image: string;
  enrolled: boolean;
  completed_lesson_ids: string[];
  lessons: LearningLesson[];
}
export interface LearningCategory {
  id: string;
  name: string;
  icon: string;
  color: string;
}
export interface SharedLearningResource {
  id: number; title: string; description: string | null; url: string | null;
  program: string | null; filename: string | null; download_path: string | null;
}
export interface LearningAreaData {
  shared_resources: SharedLearningResource[];
  name: string;
  avatar: string | null;
  categories: LearningCategory[];
  courses: LearningCourse[];
  progress: { enrolled: number; completed: number; percent: number; hours: number; streak: number };
  upcoming_sessions: { id: number; title: string; scheduled_at: string; duration: number }[];
}
export async function getLearningArea() {
  return (await api.get<LearningAreaData>("/me/learning_area")).data;
}
export async function enrollInCourse(courseId: string) {
  return (await api.post(`/me/learning_area/${courseId}/enroll`)).data;
}
export async function completeLearningLesson({ courseId, lessonId }: { courseId: string; lessonId: string }) {
  return (await api.post(`/me/learning_area/${courseId}/lessons/${lessonId}/complete`)).data;
}
