import { Skeleton } from '@/components/ui/skeleton';

export function TableSkeletonRows({ rows = 5, columns = 6 }: { rows?: number; columns?: number }) {
  return <>{Array.from({ length: rows }, (_, i) => <tr key={i}>{Array.from({ length: columns }, (_, j) => <td key={j} className="p-3"><Skeleton className="h-5 min-w-12"/></td>)}</tr>)}</>;
}

export function TableSkeleton({ rows = 5, columns = 6, label = 'Loading records' }: { rows?: number; columns?: number; label?: string }) {
  return <div role="status" aria-busy="true" className="overflow-x-auto rounded-xl border border-violet-100 bg-white"><span className="sr-only">{label}</span><table aria-hidden="true" className="w-full"><thead className="bg-violet-50"><TableSkeletonRows rows={1} columns={columns}/></thead><tbody><TableSkeletonRows rows={rows} columns={columns}/></tbody></table></div>;
}
