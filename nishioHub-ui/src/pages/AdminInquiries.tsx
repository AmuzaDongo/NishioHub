import { useRef, useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { AdminWorkspace } from '@/components/layout/admin-workspace';
import { PageLoader } from '@/components/loaders/PageLoader';
import { DashboardSkeleton } from '@/components/loaders/DashboardSkeleton';
import { ButtonLoader } from '@/components/loaders/ButtonLoader';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { operationError } from '@/components/admin/dashboard-operations';
import { usePlatform } from '@/lib/platform-context';
import { sessionIsoInput } from '@/lib/session-time';
import { useAuth } from '@/lib/auth-context';
import { isPlatformAdmin } from '@/lib/utils';
import { getPublicInquiries, reviewPublicInquiry, type PublicInquiry } from '@/lib/public-home-api';
import { partnershipFocus } from '@/lib/partnership-api';
import { hostingTypes, hostingRequestLabel, reviewEventHostingRequest, type HostingDecision, type HostingReview } from '@/lib/event-hosting-api';

const button = 'rounded-lg border border-violet-200 px-3 py-2 text-xs font-bold text-violet-700 disabled:cursor-not-allowed disabled:opacity-40';
const input = 'mt-1 w-full rounded-lg border border-violet-200 bg-white p-2 text-sm font-normal';
export default function AdminInquiries() {
  const { user, isLoading } = useAuth(); const platform = usePlatform(); const client = useQueryClient();
  const [page, setPage] = useState(1); const [search, setSearch] = useState(''); const [busy, setBusy] = useState(false);
  const [decision, setDecision] = useState<{ request: PublicInquiry; value: HostingDecision } | null>(null);
  const [note, setNote] = useState(''); const [error, setError] = useState('');
  const [schedule, setSchedule] = useState({ date: '', start: '', end: '', format: 'on_site', location: '', capacity: '' });
  const lock = useRef(false); const allowed = !!user && isPlatformAdmin(user);
  const query = useQuery({ queryKey: ['admin-inquiries', user?.id, page], queryFn: () => getPublicInquiries(page), enabled: allowed, refetchInterval: 30000 });
  const canApprove = !!user?.management_permissions?.includes('dashboard.manage') && !!user?.management_permissions?.includes('dashboard.read');
  function open(request: PublicInquiry, value: HostingDecision) {
    setDecision({ request, value }); setNote(''); setError('');
    setSchedule({ date: request.event_details?.preferred_date || '', start: '', end: '', format: request.event_details?.event_type === 'webinar' ? 'online' : 'on_site', location: request.event_details?.location || '', capacity: '' });
  }
  async function decide() {
    if (!decision || lock.current) return;
    const review: HostingReview = { decision: decision.value, note, lock_version: decision.request.lock_version };
    if (decision.value === 'approved') {
      let start: Date, end: Date;
      try { start = new Date(sessionIsoInput(`${schedule.date}T${schedule.start}`, platform.timezone)); end = new Date(sessionIsoInput(`${schedule.date}T${schedule.end}`, platform.timezone)); }
      catch { setError('Choose valid start and end times in the platform timezone.'); return; }
      if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime()) || end <= start || start <= new Date()) { setError('Choose a future start time and an end time after it.'); return; }
      const capacity = schedule.capacity.trim() ? Number(schedule.capacity) : null;
      if (capacity !== null && (!Number.isInteger(capacity) || capacity < 1 || capacity > 5000)) { setError('Capacity must be between 1 and 5000, or left blank.'); return; }
      review.event = { starts_at: start.toISOString(), ends_at: end.toISOString(), format: schedule.format, location: schedule.location, capacity };
    } else if (!note.trim()) { setError('Include feedback for the requester.'); return; }
    lock.current = true; setBusy(true); setError('');
    try {
      await reviewEventHostingRequest(decision.request.id, review);
      await Promise.all([client.invalidateQueries({ queryKey: ['admin-inquiries'] }), client.invalidateQueries({ queryKey: ['admin-events'] }), client.invalidateQueries({ queryKey: ['admin-dashboard'] })]);
      setDecision(null); toast.success(decision.value === 'approved' ? 'Request approved and draft event created' : 'Decision saved and requester notified');
    } catch (failure) { setError(operationError(failure)); } finally { lock.current = false; setBusy(false); }
  }
  if (isLoading) return <PageLoader label="Loading requests"/>;
  if (!user) return <Navigate to="/login" replace/>;
  if (!allowed) return <Navigate to="/" replace/>;
  const records = query.data?.items.filter(item => `${item.name} ${item.email} ${item.subject} ${item.reference} ${item.partnership_details?.organization_name || ''}`.toLowerCase().includes(search.toLowerCase())) || [];
  return <AdminWorkspace active="messages" search={search} onSearch={setSearch} searchPlaceholder="Search requests on this page…">
    <Link to="/admin/messages" className="text-sm text-violet-700">Back to Messages</Link><h1 className="my-4 text-3xl font-extrabold">Contact, Partnership &amp; Event Requests</h1>
    {query.isPending ? <DashboardSkeleton variant="list"/> : query.isError ? <div role="alert"><p>{operationError(query.error)}</p><button className={button} onClick={() => query.refetch()}>Retry</button></div> : <>
      <div className="space-y-4">{records.map(item => <article key={item.id} className="rounded-2xl border border-violet-100 bg-white p-5">
        <header className="flex flex-wrap items-center justify-between gap-3"><h2 className="text-lg font-bold">{item.subject}</h2>{item.category === 'event_hosting' ? <span className="rounded-full bg-violet-100 px-3 py-1 text-xs font-bold text-violet-800">{hostingRequestLabel[item.status]}</span> : <button disabled={busy} className={button} onClick={async () => { setBusy(true); try { await reviewPublicInquiry(item.id, !item.reviewed); await client.invalidateQueries({ queryKey: ['admin-inquiries'] }); } catch (failure) { toast.error(operationError(failure)); } finally { setBusy(false); } }}>{item.reviewed ? 'Mark Unreviewed' : 'Mark Reviewed'}</button>}</header>
        <p className="mt-2 text-sm">{item.name} · <a className="text-violet-700 underline" href={`mailto:${item.email}`}>{item.email}</a> · {item.category === 'event_hosting' ? 'Event Hosting' : item.category}</p><p className="mt-4 whitespace-pre-wrap break-words text-sm">{item.message}</p>
        {item.program_details?.id && <p className="mt-3 rounded-xl bg-violet-50 p-3 text-sm"><strong>{item.program_details.interest_type === 'school' ? 'School program inquiry: ' : 'Program inquiry: '}</strong>{item.program_details.title} · <Link className="font-bold text-violet-700 underline" to={`/admin/programs/${item.program_details.id}`}>Manage Program &amp; Enrollments</Link><span className="mt-1 block text-xs">Contact the requester about eligibility before creating an enrollment.</span></p>}
        {item.category === 'partnership'  && item.partnership_details?.organization_name && <dl className="mt-4 grid gap-3 rounded-xl bg-violet-50 p-4 text-sm sm:grid-cols-2">{Object.entries({ Organization: item.partnership_details.organization_name, 'Contact Role': item.partnership_details.contact_role, Phone: item.partnership_details.phone_number, Focus: partnershipFocus[item.partnership_details.focus as keyof typeof partnershipFocus] || item.partnership_details.focus, 'Request Type': item.partnership_details.request_kind === 'meeting' ? 'Meeting request — staff confirmation required' : 'Partnership inquiry', ...(item.partnership_details.preferred_at ? { 'Preferred Meeting': `${new Date(item.partnership_details.preferred_at).toLocaleString(undefined, { timeZone: platform.timezone })} (${platform.timezone})` } : {}) }).map(([label, value]) => <div key={label}><dt className="font-bold">{label}</dt><dd className="break-words">{label === 'Phone' ? <a className="text-violet-700 underline" href={`tel:${value}`}>{value}</a> : value}</dd></div>)}</dl>}
        {item.category === 'event_hosting' && item.event_details && <>
          <dl className="mt-4 grid gap-3 rounded-xl bg-violet-50 p-4 text-sm sm:grid-cols-2">{Object.entries({ Phone: item.event_details.phone_number, 'Event Type': hostingTypes[item.event_details.event_type as keyof typeof hostingTypes] || item.event_details.event_type, 'Preferred Date': item.event_details.preferred_date, Location: item.event_details.location, 'Additional Information': item.event_details.additional_information || 'None' }).map(([label, value]) => <div key={label}><dt className="font-bold">{label}</dt><dd className="whitespace-pre-wrap break-words">{value}</dd></div>)}</dl>
          {item.review_note && <p className="mt-3 whitespace-pre-wrap rounded-lg bg-violet-50 p-3 text-sm"><strong>Feedback: </strong>{item.review_note}</p>}
          {item.reviewed_at && <p className="mt-2 text-xs text-slate-500">Decision by {item.reviewed_by || 'staff'} · {new Date(item.reviewed_at).toLocaleString()}</p>}
          {item.status === 'pending' && <div className="mt-4 flex flex-wrap gap-2"><button className={`${button} bg-violet-700 !text-white`} disabled={busy || !canApprove || !item.requester_id} onClick={() => open(item, 'approved')}>Approve &amp; Create Draft</button><button className={button} disabled={busy} onClick={() => open(item, 'changes_requested')}>Request Changes</button><button className={`${button} !text-red-700`} disabled={busy} onClick={() => open(item, 'rejected')}>Reject Request</button></div>}
          {item.status === 'pending' && !item.requester_id && <p className="mt-2 text-xs text-amber-800">This legacy request has no linked host account. Contact the organizer before proceeding.</p>}
          {item.event && <Link to={`/admin/events/${item.event.id}`} className="mt-4 inline-block text-sm font-bold text-violet-700 underline">{item.event.status === 'draft' ? 'Finalize Draft Event' : 'Manage Linked Event'}</Link>}
        </>}
        <p className="mt-4 text-xs text-slate-500">Reference: {item.reference} · {new Date(item.created_at).toLocaleString()}</p>
      </article>)}</div>{!records.length && <p className="p-10 text-center">{search ? 'No requests match this search.' : 'No requests yet.'}</p>}
      <div className="mt-5 flex justify-end gap-3"><button disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button><span>Page {page}</span><button disabled={page * 20 >= query.data.total} onClick={() => setPage(page + 1)}>Next</button></div>
    </>}
    <Dialog open={!!decision} onOpenChange={open => { if (!open && !busy) setDecision(null); }}><DialogContent className="max-h-[90vh] overflow-y-auto"><DialogHeader><DialogTitle>{decision?.value === 'approved' ? 'Approve Event Request' : decision?.value === 'rejected' ? 'Reject Event Request' : 'Request Event Changes'}</DialogTitle><DialogDescription>{decision?.value === 'approved' ? `Confirm a provisional schedule. This creates a private draft for staff to finalize and publish. Times use ${platform.timezone}.` : 'Explain your decision. The requester can read this feedback in My Event Requests.'}</DialogDescription></DialogHeader>
      {decision?.value === 'approved' && <fieldset disabled={busy} className="grid gap-3 sm:grid-cols-2"><label className="text-sm font-bold sm:col-span-2">Event Date<input aria-label="Approval event date" type="date" className={input} value={schedule.date} onChange={e => setSchedule({ ...schedule, date: e.target.value })}/></label>{(['start', 'end'] as const).map(key => <label key={key} className="text-sm font-bold">{key === 'start' ? 'Start Time' : 'End Time'}<input aria-label={`Approval ${key} time`} type="time" className={input} value={schedule[key]} onChange={e => setSchedule({ ...schedule, [key]: e.target.value })}/></label>)}<label className="text-sm font-bold">Format<select aria-label="Approval format" className={input} value={schedule.format} onChange={e => setSchedule({ ...schedule, format: e.target.value })}><option value="on_site">In Person</option><option value="online">Online</option><option value="hybrid">Hybrid</option></select></label><label className="text-sm font-bold">Capacity (Optional)<input aria-label="Approval capacity" type="number" min={1} max={5000} className={input} value={schedule.capacity} onChange={e => setSchedule({ ...schedule, capacity: e.target.value })}/></label><label className="text-sm font-bold sm:col-span-2">Location<input aria-label="Approval location" maxLength={200} className={input} value={schedule.location} onChange={e => setSchedule({ ...schedule, location: e.target.value })}/></label></fieldset>}
      <label className="text-sm font-bold">Feedback {decision?.value === 'approved' ? '(Optional)' : '(Required)'}<textarea aria-label="Decision feedback" rows={4} maxLength={2000} className={input} disabled={busy} value={note} onChange={e => setNote(e.target.value)}/></label>{error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}<footer className="flex justify-end gap-3"><button className={button} disabled={busy} onClick={() => setDecision(null)}>Cancel</button><ButtonLoader className={`${button} inline-flex items-center gap-2 bg-violet-700 !text-white`} loading={busy} loadingText="Saving Decision..." onClick={decide}>{decision?.value === 'approved' ? 'Confirm Approval & Create Draft' : 'Send Decision'}</ButtonLoader></footer>
    </DialogContent></Dialog>
  </AdminWorkspace>;
}
