import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function roleName(user: { role?: unknown } | null | undefined): string | undefined {
  const role = user?.role;
  if (!role) return undefined;
  if (typeof role === "string") return role;
  if (typeof role === "object" && "name" in role) {
    return String((role as { name?: unknown }).name ?? "");
  }
  return undefined;
}

export function hasRole(user: { role?: unknown; roles?: unknown } | null | undefined, name: string): boolean {
  const names = [roleName(user), ...(Array.isArray(user?.roles) ? user.roles.map(role => typeof role === 'string' ? role : role?.name) : [])];
  const normalize = (value: string) => value.toLowerCase().replace(/[ _-]/g, '');
  return names.some(value => typeof value === 'string' && normalize(value) === normalize(name));
}

export function isPlatformAdmin(user: { role?: unknown; roles?: unknown } | null | undefined): boolean {
  return hasRole(user, 'admin') || hasRole(user, 'super_admin');
}
