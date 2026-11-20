import { ProgramCardSkeletonGrid } from "@/components/loaders/ProgramCardSkeleton";
import { useDeferredValue, useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import {
  ArrowRight,
  BookOpen,
  CalendarDays,
  CheckCircle2,
  GraduationCap,
  Search,
} from "lucide-react";
import { Helmet } from "react-helmet-async";
import { HomeAction } from "@/components/layout/home-action";
import {
  getPublicCatalog,
  type CatalogKind,
  type PublicItem,
} from "@/lib/public-home-api";
import { usePlatform, platformDate, assetUrl } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { hasRole, isPlatformAdmin } from "@/lib/utils";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { MainLayout } from "@/components/layout/main-layout";
export default function PublicCatalog({ kind }: { kind: CatalogKind }) {
  const platform = usePlatform();
  const { user } = useAuth();
  const [search, setSearch] = useState("");
  const q = useDeferredValue(search);
  const [page, setPage] = useState(1);
  const [item, setItem] = useState<PublicItem | null>(null);
  const query = useQuery({
    queryKey: ["public-catalog", kind, q, page],
    queryFn: () => getPublicCatalog(kind, q, page),
  });
  const title =
    kind === "programs"
      ? "Mentorship Programs"
      : kind === "learning"
        ? "Learning Resources"
        : "Events & Webinars";
  const Icon =
    kind === "programs"
      ? GraduationCap
      : kind === "learning"
        ? BookOpen
        : CalendarDays;
  const image = (value?: string) =>
    value?.startsWith("/images/") ? value : assetUrl(value);
  const target = (record: PublicItem) =>
    isPlatformAdmin(user)
      ? kind === "programs"
        ? `/admin/programs/${record.id}`
        : kind === "events"
          ? `/admin/events/${record.id}`
          : "/admin/resources"
      : hasRole(user, "mentee")
        ? kind === "learning"
          ? `/learning-area?course=${record.id}`
          : kind === "events"
            ? `/events?event=${record.id}`
            : "/contact?category=mentorship"
        : user
          ? "/contact?category=mentorship"
          : platform.registration_enabled
            ? "/register?role=mentee"
            : "/contact";
  return (
    <MainLayout>
      <Helmet>
        <title>
          {title} — {platform.platform_name}
        </title>
      </Helmet>
      <section className='mx-auto min-h-[60vh] max-w-6xl px-5 py-10'>
        <Link to='/' className='text-sm font-bold text-violet-700'>
          Home
        </Link>
        <header className='my-6'>
          <h1 className='flex items-center gap-3 text-3xl font-extrabold'>
            <Icon className='text-violet-700' />
            {title}
          </h1>
          <p className='mt-2 text-sm'>
            Explore opportunities to learn, connect and grow with{" "}
            {platform.platform_name}.
          </p>
        </header>
        <label className='relative mb-6 block'>
          <Search className='absolute left-3 top-3 text-violet-700' size={20} />
          <input
            aria-label={`Search ${kind}`}
            className='w-full rounded-xl border border-violet-200 bg-white py-3 pl-11 pr-4 text-sm'
            placeholder={`Search ${kind}…`}
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </label>
        {query.isPending ? (
          <ProgramCardSkeletonGrid label={`Loading ${kind}`} />
        ) : query.isError ? (
          <div role='alert' className='py-12 text-center'>
            <p>These opportunities could not be loaded.</p>
            <button
              className='mt-3 font-bold text-violet-700 underline'
              onClick={() => query.refetch()}
            >
              Try Again
            </button>
          </div>
        ) : (
          <>
            <div className='grid gap-5 sm:grid-cols-2 lg:grid-cols-3'>
              {query.data.items.map((record) => (
                <article
                  key={record.id}
                  className='flex flex-col overflow-hidden rounded-2xl border border-violet-100 bg-white shadow-sm'
                >
                  {record.image ? (
                    <img
                      src={image(record.image)}
                      alt=''
                      loading='lazy'
                      className='h-44 w-full object-cover'
                    />
                  ) : (
                    <div className='grid h-32 place-items-center bg-gradient-to-br from-violet-100 to-violet-200 text-violet-700'>
                      <GraduationCap size={56} />
                    </div>
                  )}
                  <div className='flex flex-1 flex-col p-5'>
                    <span className='mb-2 text-xs font-semibold text-violet-700'>
                      {record.category || record.level || "Mentorship"}
                    </span>
                    <h2 className='text-lg font-extrabold'>{record.title}</h2>
                    {record.description && (
                      <p className='mt-2 line-clamp-3 text-sm text-slate-600'>
                        {record.description}
                      </p>
                    )}
                    {record.starts_at && (
                      <p className='mt-3 text-xs'>
                        {platformDate(record.starts_at, platform, true)}
                        <br />
                        {record.location}
                      </p>
                    )}
                    {record.lessons && (
                      <p className='mt-3 text-xs'>{record.lessons} lessons</p>
                    )}
                    <div className='mt-auto flex flex-wrap gap-3 pt-5'>
                      <button
                        className='text-sm font-bold text-violet-700 underline'
                        onClick={() => setItem(record)}
                      >
                        View Details
                      </button>
                      <Link
                        className='ml-auto inline-flex items-center gap-1 text-sm font-bold text-violet-700'
                        to={target(record)}
                      >
                        {user
                          ? "Continue"
                          : kind === "programs"
                            ? "Join the platform"
                            : "Get Started"}
                        <ArrowRight size={16} />
                      </Link>
                    </div>
                  </div>
                </article>
              ))}
            </div>
            {!query.data.items.length && (
              <p className='rounded-2xl border border-violet-100 bg-white p-10 text-center text-sm'>
                {!query.data.enabled
                  ? "Public event listings are currently unavailable."
                  : `No ${kind} match your search. Check back soon for more opportunities.`}
              </p>
            )}
            <div className='mt-6 flex items-center justify-end gap-4 text-sm'>
              <button
                disabled={page <= 1}
                className='rounded-lg border border-violet-200 px-4 py-2 disabled:opacity-40'
                onClick={() => setPage(page - 1)}
              >
                Previous
              </button>
              <span>
                Page {page} · {query.data.meta.total} results
              </span>
              <button
                disabled={page >= query.data.meta.total_pages}
                className='rounded-lg border border-violet-200 px-4 py-2 disabled:opacity-40'
                onClick={() => setPage(page + 1)}
              >
                Next
              </button>
            </div>
          </>
        )}
        <Dialog
          open={!!item}
          onOpenChange={(open) => {
            if (!open) setItem(null);
          }}
        >
          <DialogContent className='max-h-[85vh] overflow-y-auto'>
            <DialogHeader>
              <DialogTitle>{item?.title}</DialogTitle>
              <DialogDescription>
                {item?.category || item?.level || "Explore this opportunity"}
              </DialogDescription>
            </DialogHeader>
            {item?.image && (
              <img
                src={image(item.image)}
                alt={`${item.title} banner`}
                className='h-44 w-full rounded-xl object-cover'
              />
            )}
            {item?.description && (
              <p className='whitespace-pre-line text-sm'>{item.description}</p>
            )}
            {item?.target_audience && (
              <p className='text-sm'>
                <strong>For: </strong>
                {item.target_audience}
              </p>
            )}
            {item?.starts_on && (
              <p className='text-sm'>
                <strong>Starts: </strong>
                {platformDate(`${item.starts_on}T12:00Z`, platform)}
              </p>
            )}
            {item?.ends_on && (
              <p className='text-sm'>
                <strong>Ends: </strong>
                {platformDate(`${item.ends_on}T12:00Z`, platform)}
              </p>
            )}
            {item?.mode && (
              <p className='text-sm capitalize'>
                Format: {item.mode.replace("_", " ")}
              </p>
            )}
            {!!item?.objectives?.length && (
              <ul className='space-y-2 text-sm'>
                {item.objectives.map((objective) => (
                  <li key={objective} className='flex gap-2'>
                    <CheckCircle2
                      size={17}
                      className='shrink-0 text-green-600'
                    />
                    {objective}
                  </li>
                ))}
              </ul>
            )}
            {item?.starts_at && (
              <p className='text-sm'>
                {platformDate(item.starts_at, platform, true)} · {item.location}
              </p>
            )}
            {item?.lessons && (
              <p className='text-sm'>
                {item.lessons} lessons · {item.level}
              </p>
            )}
            {item && (
              <HomeAction to={target(item)}>
                {user ? "Continue" : "Get Started"}
                <ArrowRight size={17} />
              </HomeAction>
            )}
          </DialogContent>
        </Dialog>
      </section>
    </MainLayout>
  );
}
