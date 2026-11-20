import { Skeleton } from '@/components/ui/skeleton';

export function MentorCardSkeleton() {
  return <div data-mentor-skeleton aria-hidden="true" className="overflow-hidden rounded-xl border border-violet-100 bg-white shadow-sm"><Skeleton className="aspect-[3/2] rounded-none bg-violet-100"/><div className="space-y-4 p-5"><div className="flex items-center gap-3"><Skeleton className="size-8 rounded-full"/><Skeleton className="h-4 w-1/2"/></div><Skeleton className="h-6 w-4/5"/><Skeleton className="h-3 w-full"/><Skeleton className="h-3 w-3/4"/><div className="flex gap-2"><Skeleton className="h-5 w-16 rounded-full"/><Skeleton className="h-5 w-20 rounded-full"/></div><div className="flex justify-between border-t pt-4"><Skeleton className="h-8 w-20"/><Skeleton className="h-9 w-28"/></div></div></div>;
}

export function MentorCardSkeletonGrid() {
  return <div role="status" aria-busy="true"><span className="sr-only">Loading mentors</span><div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">{Array.from({ length: 6 }, (_, i) => <MentorCardSkeleton key={i}/>)}</div></div>;
}
