import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@/lib/auth-context";
import {
  getMyEventHostingRequests,
  hostingRequestLabel,
  type HostingRequest,
} from "@/lib/event-hosting-api";
import { operationError } from "@/components/admin/dashboard-operations";
import { PageLoader } from "@/components/loaders/PageLoader";

export function MyEventRequests({
  canSubmit,
  onEdit,
}: {
  canSubmit: boolean;
  onEdit: (request: HostingRequest) => void;
}) {
  const { user } = useAuth();
  const [page, setPage] = useState(1);
  const query = useQuery({
    queryKey: ["my-event-hosting-requests", user?.id, page],
    queryFn: () => getMyEventHostingRequests(page),
    enabled: !!user?.access_token,
    refetchInterval: 30000,
  });
  return (
    <section
      id='my-event-requests'
      className='mx-auto mb-18 max-w-[1344px] scroll-mt-24 px-5 lg:px-12'
    >
      <div className='rounded-2xl border border-violet-200 bg-white p-5'>
        <header className='mb-4 flex flex-wrap items-center justify-between gap-3'>
          <h2 className='text-xl font-extrabold'>My Event Requests</h2>
          <button
            className='text-sm font-bold text-violet-700 disabled:opacity-50'
            disabled={query.isFetching}
            onClick={() => query.refetch()}
          >
            Refresh Requests
          </button>
        </header>
        {query.isPending ? (
          <PageLoader label='Loading your event requests' rows={2} />
        ) : query.isError ? (
          <p role='alert' className='text-sm text-red-700'>
            {operationError(query.error)}
          </p>
        ) : (
          <>
            <div className='space-y-3'>
              {query.data.items.map((item) => (
                <article
                  key={item.id}
                  className='rounded-xl border border-violet-100 p-4'
                >
                  <header className='flex flex-wrap justify-between gap-2'>
                    <h3 className='font-bold'>{item.subject}</h3>
                    <span className='rounded-full bg-violet-100 px-3 py-1 text-xs font-bold text-violet-800'>
                      {hostingRequestLabel[item.status]}
                    </span>
                  </header>
                  <p className='mt-2 text-xs text-slate-500'>
                    Reference: {item.reference} · Preferred date:{" "}
                    {item.event_details.preferred_date}
                  </p>
                  <p className='mt-2 whitespace-pre-wrap break-words text-sm'>
                    {item.message}
                  </p>
                  {item.review_note && (
                    <p className='mt-3 whitespace-pre-wrap rounded-lg bg-violet-50 p-3 text-sm'>
                      <strong>Staff feedback: </strong>
                      {item.review_note}
                    </p>
                  )}
                  {item.status === "pending" && (
                    <p className='mt-3 text-sm text-slate-600'>
                      Your request is awaiting staff review.
                    </p>
                  )}
                  {item.status === "changes_requested" && canSubmit && (
                    <button
                      className='mt-3 rounded-lg bg-violet-700 px-4 py-2 text-sm font-bold text-white'
                      onClick={() => onEdit(item)}
                    >
                      Update &amp; Resubmit Request
                    </button>
                  )}
                  {item.status === "rejected" && (
                    <p className='mt-3 text-sm text-slate-600'>
                      This request was declined. You can submit a new proposal
                      using the form above.
                    </p>
                  )}
                  {item.status === "approved" && (
                    <div className='mt-3 text-sm'>
                      {item.event?.status === "published" ? (
                        <Link
                          to={`/community-events/${item.event.id}`}
                          className='font-bold text-violet-700 underline'
                        >
                          View Published Event
                        </Link>
                      ) : item.event?.status === "cancelled" ? (
                        <p>The linked event has been cancelled.</p>
                      ) : (
                        <p>
                          Your request is approved. Staff are preparing the
                          draft event and will notify you when it is published.
                        </p>
                      )}
                    </div>
                  )}
                </article>
              ))}
            </div>
            {!query.data.items.length && (
              <p className='py-6 text-sm text-slate-600'>
                Your submitted event requests will appear here.
              </p>
            )}
            <footer className='mt-4 flex justify-end gap-3 text-sm'>
              <button disabled={page <= 1} onClick={() => setPage(page - 1)}>
                Previous
              </button>
              <span>Page {page}</span>
              <button
                disabled={page * 20 >= query.data.total}
                onClick={() => setPage(page + 1)}
              >
                Next
              </button>
            </footer>
          </>
        )}
      </div>
    </section>
  );
}
