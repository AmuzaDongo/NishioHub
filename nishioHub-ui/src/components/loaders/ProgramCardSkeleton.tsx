import { Skeleton } from '@/components/ui/skeleton';

export function ProgramCardSkeleton() {
  return <div aria-hidden="true" className="overflow-hidden rounded-2xl border border-violet-100 bg-white shadow-sm"><Skeleton className="h-44 rounded-none bg-violet-100"/><div className="space-y-4 p-5"><Skeleton className="h-3 w-24"/><Skeleton className="h-6 w-4/5"/><Skeleton className="h-3 w-full"/><Skeleton className="h-3 w-3/4"/><Skeleton className="h-10 w-full"/></div></div>;
}

export function ProgramCardSkeletonGrid({ label = 'Loading opportunities' }: { label?: string }) {
  return <div role="status" aria-busy="true"><span className="sr-only">{label}</span><div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">{Array.from({ length: 6 }, (_, i) => <ProgramCardSkeleton key={i}/>)}</div></div>;
}
