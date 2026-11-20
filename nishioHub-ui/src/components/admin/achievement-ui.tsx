import type { ReactNode } from 'react';
import { Award, BookOpen, Code2, FileBadge, GraduationCap, Laptop, Rocket, Star, Target, Trophy, Users } from 'lucide-react';
import type { AchievementKind } from '@/lib/admin-achievements-api';
import { goalPanel } from './goal-ui';
import { achievementKinds } from '@/lib/achievement-display';
export function KindPill({ kind }: { kind: AchievementKind }) {
  const info = achievementKinds.find(k => k.key === kind)!;
  return <span className={`inline-block whitespace-nowrap rounded-full px-3 py-1 text-[10px] font-bold ${info.tone}`}>{info.label}</span>;
}
const icons = { trophy: Trophy, star: Star, code: Code2, book: BookOpen, users: Users, rocket: Rocket, certificate: FileBadge, graduation: GraduationCap, target: Target, laptop: Laptop };
export function AchievementGlyph({ icon, color, size = 23, compact = false }: { icon: string; color: string; size?: number; compact?: boolean }) {
  const Icon = icons[icon as keyof typeof icons] || Award;
  const tones: Record<string, string> = { purple: 'text-violet-700 bg-violet-100', blue: 'text-blue-600 bg-blue-100', green: 'text-green-600 bg-green-100', gold: 'text-amber-500 bg-amber-50', pink: 'text-pink-600 bg-pink-100' };
  return <span className={`inline-flex shrink-0 items-center justify-center rounded-full ${compact ? 'p-1' : 'p-2'} ${tones[color] || tones.purple}`}><Icon size={size} /></span>;
}
export function AchievementPanel({ title, Icon = Trophy, action, children, className = '' }: { title: string; Icon?: typeof Trophy; action?: ReactNode; children: ReactNode; className?: string }) {
  return <section className={`${goalPanel} min-w-0 p-3 ${className}`}><header className="mb-3 flex flex-wrap items-center justify-between gap-2"><h2 className="flex items-center gap-2 text-base font-extrabold tracking-tight"><Icon className="shrink-0 text-violet-700" size={24} />{title}</h2>{action}</header>{children}</section>;
}
