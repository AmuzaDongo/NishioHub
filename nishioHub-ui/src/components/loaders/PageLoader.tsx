import { Skeleton } from '@/components/ui/skeleton';

export function PageLoader({ label = 'Loading content', rows = 4 }: { label?: string; rows?: number }) {
  return <div role="status" aria-busy="true" className="space-y-5 p-5"><span className="sr-only">{label}</span><Skeleton className="h-7 w-2/5 bg-violet-100"/>{Array.from({ length: rows }, (_, i) => <div key={i} className="flex gap-4 rounded-xl border border-violet-100 p-4"><Skeleton className="size-12 shrink-0 bg-violet-100"/><div className="flex-1 space-y-3"><Skeleton className="h-4 w-2/3"/><Skeleton className="h-3 w-full"/><Skeleton className="h-3 w-1/3"/></div></div>)}</div>;
}
