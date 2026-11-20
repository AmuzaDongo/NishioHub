import type { AchievementKind } from './admin-achievements-api';

export const achievementKinds: { key: AchievementKind; label: string; color: string; tone: string }[] = [
  { key: 'course_completion', label: 'Course Completion', color: '#7900ff', tone: 'bg-violet-100 text-violet-800' },
  { key: 'program_completion', label: 'Program Completion', color: '#0084ff', tone: 'bg-blue-100 text-blue-800' },
  { key: 'skill_badge', label: 'Skill Badge', color: '#00af16', tone: 'bg-green-100 text-green-800' },
  { key: 'special_recognition', label: 'Recognition', color: '#ffba00', tone: 'bg-amber-100 text-amber-800' },
  { key: 'certificate', label: 'Certificate', color: '#fb288d', tone: 'bg-pink-100 text-pink-800' },
  { key: 'other', label: 'Other', color: '#b9b5cd', tone: 'bg-slate-100 text-slate-700' },
];
