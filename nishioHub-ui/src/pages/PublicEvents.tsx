import {MediaLink} from '@/components/media/platform-video';
import { ProgramCardSkeletonGrid } from "@/components/loaders/ProgramCardSkeleton";
import { useEffect, useMemo, useRef, useState } from "react";
import { Link, Navigate, useNavigate, useSearchParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  BookOpen,
  BriefcaseBusiness,
  CalendarDays,
  CalendarPlus,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock,
  Filter,
  GraduationCap,
  MapPin,
  Monitor,
  Network,
  PlayCircle,
  Search,
  Star,
  Users,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { assetUrl, usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { operationError } from "@/components/admin/dashboard-operations";
import {
  getPublicEventsDiscovery,
  type PublicEvent,
  type PublicEventFilters,
  type PublicEventTab,
} from "@/lib/public-events-api";
const outline =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-violet-500 bg-white px-4 py-2 text-sm font-bold text-violet-800 transition hover:bg-violet-50 disabled:cursor-not-allowed disabled:opacity-50";
const primary = `${outline} !border-transparent bg-gradient-to-b from-violet-600 to-violet-800 !text-white`;
const labels: Record<string, string> = {
  webinar: "Webinar",
  workshop: "Workshop",
  mentorship: "Mentorship Session",
  talk: "Career Talk",
  community: "Community Event",
};
const audiences: Record<string, string> = {
  primary: "Primary Learners",
  secondary: "Secondary Students",
  university: "University & College",
  early_career: "Early Career / Job Seekers",
  professionals: "Professionals & Leaders",
};
const types = [
  { key: "webinar", Icon: PlayCircle },
  { key: "workshop", Icon: BookOpen },
  { key: "mentorship", Icon: Users },
  { key: "talk", Icon: BriefcaseBusiness },
  { key: "community", Icon: Network },
];
const tabs = [
  {
    key: "upcoming",
    title: "Upcoming Events",
    subtitle: "See what’s next",
    Icon: CalendarDays,
  },
  {
    key: "live",
    title: "Live Sessions",
    subtitle: "Join in real time",
    Icon: PlayCircle,
  },
  {
    key: "past",
    title: "Past Events",
    subtitle: "Explore past sessions",
    Icon: Monitor,
  },
  {
    key: "featured",
    title: "Featured Events",
    subtitle: "Don’t miss these",
    Icon: Star,
  },
] as const;
function initial(params: URLSearchParams): PublicEventFilters {
  return {
    tab: (["upcoming", "live", "past", "featured"].includes(
      params.get("tab") || "",
    )
      ? params.get("tab")
      : "upcoming") as PublicEventTab,
    types: params.getAll("type"),
    audiences: params.getAll("audience"),
    mode: params.get("mode") || "all",
    date_range: params.get("date_range") || "all",
    from: params.get("from") || "",
    to: params.get("to") || "",
    q: params.get("q") || "",
    page: Number(params.get("page") || 1),
  };
}
export default function PublicEvents() {
  const { user } = useAuth();
  const platform = usePlatform();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const applied = useMemo(() => initial(params), [params]);
  const [draft, setDraft] = useState<PublicEventFilters>(applied);
  const [searchOpen, setSearchOpen] = useState(!!applied.q);
  const listing = useRef<HTMLElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const selectedId = /^[1-9]\d*$/.test(params.get("event") || "")
    ? Number(params.get("event"))
    : null;
  const query = useQuery({
    queryKey: ["public-events-discovery", user?.id, applied],
    queryFn: () => getPublicEventsDiscovery(applied),
    refetchInterval: 60000,
  });
  useEffect(() => {
    setDraft(applied);
  }, [applied]);
  const data = query.data;
  const timezone = data?.timezone || platform.timezone;
  const hasFilters = !!(
    applied.types.length ||
    applied.audiences.length ||
    applied.mode !== "all" ||
    applied.date_range !== "all" ||
    applied.q ||
    applied.page > 1
  );
  const dates = (value: string) =>
    new Date(value).toLocaleDateString(platform.language, {
      timeZone: timezone,
      weekday: "short",
      day: "numeric",
      month: "short",
      year: "numeric",
    });
  const time = (value: string) =>
    new Date(value).toLocaleTimeString(platform.language, {
      timeZone: timezone,
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short",
    });
  const month = (value: string) =>
    new Date(value)
      .toLocaleDateString(platform.language, {
        timeZone: timezone,
        month: "short",
      })
      .toUpperCase();
  const day = (value: string) =>
    new Date(value).toLocaleDateString(platform.language, {
      timeZone: timezone,
      day: "2-digit",
    });
  const image = (value: string) =>
    value.startsWith("/images/") ? value : assetUrl(value);
  const host = "/host-an-event";
  const filter = (next: PublicEventFilters) => {
    const p = new URLSearchParams();
    if (next.tab !== "upcoming") p.set("tab", next.tab);
    next.types.forEach((v) => p.append("type", v));
    next.audiences.forEach((v) => p.append("audience", v));
    if (next.mode !== "all") p.set("mode", next.mode);
    if (next.date_range !== "all") p.set("date_range", next.date_range);
    if (next.date_range === "custom") {
      p.set("from", next.from);
      p.set("to", next.to);
    }
    if (next.q) p.set("q", next.q);
    if (next.page > 1) p.set("page", String(next.page));
    setParams(p);
    requestAnimationFrame(() =>
      listing.current?.scrollIntoView({ block: "start" }),
    );
  };
  const open = (id: number) => navigate(`/community-events/${id}`);
  const action = (item: PublicEvent) => {
    if (item.display_status === "completed")
      return <button className={`${outline} w-full`} onClick={()=>open(item.id)}>View Event <ArrowRight size={17}/></button>;
    if (item.registered)
      return (
        <button className={`${outline} w-full`} onClick={() => open(item.id)}>
          <CheckCircle2 size={17} />
          Registered · View Details
        </button>
      );
    return (
      <button
        className={`${outline} w-full`}
        disabled={!item.can_register}
        onClick={() => open(item.id)}
      >
        {item.can_register
          ? "Register Free"
          : item.available_places === 0
            ? "Event Full"
            : "Registration Closed"}
        {item.can_register && <ArrowRight size={17} />}
      </button>
    );
  };
  const search = () => {
    setSearchOpen(true);
    requestAnimationFrame(() => {
      listing.current?.scrollIntoView({ block: "start" });
      searchInput.current?.focus();
    });
  };
  if (selectedId)
    return <Navigate to={`/community-events/${selectedId}`} replace />;
  return (
    <MainLayout>
      <Helmet>
        <title>Events — Learn, Grow, Connect | {platform.platform_name}</title>
        <meta
          name='description'
          content='Discover webinars, workshops, mentor sessions, career talks and community events on NishioHub.'
        />
      </Helmet>
      <section className='relative overflow-hidden bg-[#24103e] text-white'>
        <div className='relative mx-auto max-w-[1440px]'>
          <img
            src='/images/events/public-events-hero.webp'
            alt='A learner speaking confidently at a school learning event'
            fetchPriority='high'
            className='h-64 w-full object-cover lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[80%] lg:object-top'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[49%] bg-gradient-to-br from-[#1d1035] via-[#391466] to-violet-800 lg:block'
            style={{ clipPath: "ellipse(100% 115% at 0% 25%)" }}
          />
          <div className='relative px-6 py-6 lg:w-[48%] lg:px-12 lg:py-7'>
            <p className='mb-3 inline-flex items-center gap-2 rounded-full bg-violet-600/75 px-3 py-1 text-xs font-bold'>
              <CalendarDays size={18} />
              Events at {platform.platform_name}
            </p>
            <h1 className='text-[34px] font-extrabold leading-[1.06] tracking-tight xl:text-[40px]'>
              Join Events that Inspire
              <br className='hidden lg:block' /> Learning, Growth and
              <br className='hidden lg:block' />{" "}
              <span className='text-yellow-300'>Opportunity</span>
            </h1>
            <p className='mt-3 max-w-lg text-sm leading-snug xl:text-base'>
              Webinars, mentorship sessions, workshops, career talks and
              community events for learners, students, professionals and
              organizations.
            </p>
            <div className='mt-4 flex flex-wrap gap-4'>
              <button
                className={`${primary} !border !border-violet-300 !px-5 !py-3`}
                onClick={() =>
                  listing.current?.scrollIntoView({ block: "start" })
                }
              >
                Browse Events <ArrowRight size={20} />
              </button>
              <Link
                className='inline-flex items-center gap-2 rounded-lg border border-white px-4 py-3 text-sm font-bold hover:bg-white/10'
                to={host}
              >
                <CalendarPlus size={20} />
                Host an Event
              </Link>
            </div>
          </div>
          <aside className='absolute right-6 top-6 hidden w-52 space-y-4 rounded-2xl border border-violet-100 bg-white/95 p-5 text-violet-950 shadow-xl lg:block'>
            {[
              { Icon: CalendarDays, text: "Live & Online Events" },
              { Icon: Users, text: "Mentor Sessions" },
              { Icon: GraduationCap, text: "Skills Workshops" },
              { Icon: BriefcaseBusiness, text: "Career Talks" },
              { Icon: Network, text: "Networking & Community Events" },
            ].map((i) => (
              <p
                key={i.text}
                className='flex items-center gap-3 text-xs font-bold'
              >
                <i.Icon size={24} className='shrink-0 text-violet-700' />
                {i.text}
              </p>
            ))}
          </aside>
        </div>
      </section>
      <nav
        aria-label='Event discovery sections'
        className='border-b border-violet-100 bg-gradient-to-b from-white to-violet-50'
      >
        <div className='mx-auto flex max-w-[1440px] overflow-x-auto px-4 py-4'>
          {tabs.map((t) => (
            <button
              key={t.key}
              aria-current={applied.tab === t.key ? "page" : undefined}
              className={`flex min-w-[180px] flex-1 items-center justify-center gap-3 border-r border-violet-200 px-4 text-left last:border-0 ${applied.tab === t.key ? "text-violet-800" : "text-[#180d35]"} hover:text-violet-700`}
              onClick={() => filter({ ...applied, tab: t.key, page: 1 })}
            >
              <t.Icon size={35} className='shrink-0 text-violet-700' />
              <span>
                <strong className='block text-sm font-extrabold'>
                  {t.title}
                </strong>
                <small className='text-[11px]'>{t.subtitle}</small>
              </span>
            </button>
          ))}
          <Link
            className='flex min-w-[190px] flex-1 items-center justify-center gap-3 px-4 text-left'
            to={host}
          >
            <CalendarPlus size={35} className='text-violet-700' />
            <span>
              <strong className='block text-sm font-extrabold'>
                Host an Event
              </strong>
              <small className='text-[11px]'>
                For your school or organization
              </small>
            </span>
          </Link>
        </div>
      </nav>
      <section
        ref={listing}
        id='event-list'
        className='mx-auto grid max-w-[1440px] scroll-mt-24 gap-6 px-5 py-7 lg:grid-cols-[250px_1fr] lg:px-6'
      >
        <aside className='self-start rounded-2xl border border-violet-200 bg-gradient-to-br from-white to-violet-50 p-5 shadow-sm'>
          <h2 className='mb-4 flex items-center gap-3 border-b border-violet-100 pb-3 text-xl font-extrabold'>
            <Filter size={28} className='text-violet-700' />
            Filter Events
          </h2>
          <form
            className='space-y-4'
            onSubmit={(e) => {
              e.preventDefault();
              filter({ ...draft, tab: applied.tab, page: 1 });
            }}
          >
            <fieldset>
              <legend className='mb-2 text-sm font-extrabold'>
                Event Type
              </legend>
              <label className='mb-2 flex cursor-pointer items-center gap-3 text-xs'>
                <input
                  type='checkbox'
                  className='size-4 accent-violet-700'
                  checked={!draft.types.length}
                  onChange={() => setDraft((v) => ({ ...v, types: [] }))}
                />
                All Events{" "}
                <span className='ml-auto'>({data?.facets.total ?? 0})</span>
              </label>
              {types.map((t) => (
                <label
                  key={t.key}
                  className='mb-2 flex cursor-pointer items-center gap-3 text-xs'
                >
                  <input
                    type='checkbox'
                    className='size-4 accent-violet-700'
                    checked={draft.types.includes(t.key)}
                    onChange={(e) =>
                      setDraft((v) => ({
                        ...v,
                        types: e.target.checked
                          ? [...v.types, t.key]
                          : v.types.filter((key) => key !== t.key),
                      }))
                    }
                  />
                  {labels[t.key]}
                  <span className='ml-auto'>
                    (
                    {data?.facets.types.find((i) => i.key === t.key)?.count ??
                      0}
                    )
                  </span>
                </label>
              ))}
            </fieldset>
            <fieldset className='border-t border-violet-100 pt-3'>
              <legend className='pt-3 text-sm font-extrabold'>
                Target Audience
              </legend>
              {Object.entries(audiences).map(([key, label]) => (
                <label
                  key={key}
                  className='mt-2 flex cursor-pointer items-center gap-3 text-xs'
                >
                  <input
                    type='checkbox'
                    className='size-4 accent-violet-700'
                    checked={draft.audiences.includes(key)}
                    onChange={(e) =>
                      setDraft((v) => ({
                        ...v,
                        audiences: e.target.checked
                          ? [...v.audiences, key]
                          : v.audiences.filter((i) => i !== key),
                      }))
                    }
                  />
                  {label}
                </label>
              ))}
            </fieldset>
            <fieldset className='border-t border-violet-100 pt-3'>
              <legend className='pt-3 text-sm font-extrabold'>Mode</legend>
              {Object.entries({
                all: "All Modes",
                online: "Online",
                on_site: "In-Person",
                hybrid: "Hybrid",
              }).map(([key, label]) => (
                <label
                  key={key}
                  className='mt-2 flex cursor-pointer items-center gap-3 text-xs'
                >
                  <input
                    type='radio'
                    className='size-4 accent-violet-700'
                    name='public-event-mode'
                    checked={draft.mode === key}
                    onChange={() => setDraft((v) => ({ ...v, mode: key }))}
                  />
                  {label}
                </label>
              ))}
            </fieldset>
            <label className='block border-t border-violet-100 pt-3 text-sm font-extrabold'>
              Date
              <select
                aria-label='Event date range'
                className='mt-2 w-full rounded-lg border border-violet-200 bg-white p-2 text-xs font-normal'
                value={draft.date_range}
                onChange={(e) =>
                  setDraft((v) => ({ ...v, date_range: e.target.value }))
                }
              >
                <option value='all'>Select date range</option>
                <option value='today'>Today</option>
                <option value='week'>Next 7 Days</option>
                <option value='month'>Next 30 Days</option>
                <option value='custom'>Custom Range</option>
              </select>
            </label>
            {draft.date_range === "custom" && (
              <div className='space-y-2'>
                {(["from", "to"] as const).map((key) => (
                  <label key={key} className='block text-xs capitalize'>
                    {key}
                    <input
                      type='date'
                      required
                      aria-label={`Events ${key} date`}
                      className='mt-1 w-full rounded-lg border border-violet-200 p-2'
                      value={draft[key]}
                      onChange={(e) =>
                        setDraft((v) => ({ ...v, [key]: e.target.value }))
                      }
                    />
                  </label>
                ))}
              </div>
            )}
            <button
              className={`${primary} w-full`}
              aria-busy={query.isFetching}
            >
              <Filter size={19} />
              Apply Filters
            </button>
            <button
              type='button'
              className={`${outline} w-full`}
              onClick={() =>
                filter({ ...initial(new URLSearchParams()), tab: applied.tab })
              }
            >
              Clear All
            </button>
          </form>
        </aside>
        <div className='min-w-0'>
          <header className='mb-6 flex flex-wrap items-start justify-between gap-3'>
            <div>
              <h2 className='border-l-4 border-violet-600 pl-3 text-3xl font-extrabold tracking-tight'>
                {tabs.find((t) => t.key === applied.tab)?.title}
              </h2>
              <p className='mt-1 pl-3 text-sm'>
                {applied.tab === "past"
                  ? "Explore past events and available recordings."
                  : applied.tab === "live"
                    ? "Find online and hybrid sessions happening right now."
                    : "Join our upcoming events and be part of a learning and growth community."}
              </p>
            </div>
            <button
              className='flex items-center gap-2 text-sm font-bold text-violet-700'
              onClick={() => filter(initial(new URLSearchParams()))}
            >
              View All Events <ArrowRight size={18} />
            </button>
          </header>
          {searchOpen && (
            <form
              className='mb-5 flex gap-2'
              onSubmit={(e) => {
                e.preventDefault();
                filter({ ...draft, tab: applied.tab, page: 1 });
              }}
            >
              <label className='relative flex-1'>
                <Search
                  size={18}
                  className='absolute left-3 top-3 text-violet-600'
                />
                <input
                  ref={searchInput}
                  aria-label='Search public events'
                  placeholder='Search events by title, topic or location…'
                  className='w-full rounded-lg border border-violet-200 bg-white py-3 pl-10 pr-3 text-sm'
                  value={draft.q}
                  onChange={(e) =>
                    setDraft((v) => ({ ...v, q: e.target.value }))
                  }
                />
              </label>
              <button className={primary}>Search</button>
            </form>
          )}
          {query.isPending ? (
            <ProgramCardSkeletonGrid label='Loading events' />
          ) : query.isError ? (
            <div
              role='alert'
              className='rounded-xl border border-red-100 bg-white p-8 text-center'
            >
              <p>{operationError(query.error)}</p>
              <button
                className={`${outline} mt-4`}
                onClick={() => query.refetch()}
              >
                Retry
              </button>
              <button
                className={`${outline} ml-2 mt-4`}
                onClick={() => filter(initial(new URLSearchParams()))}
              >
                Reset Filters
              </button>
            </div>
          ) : !data?.enabled ? (
            <p className='rounded-xl border border-violet-100 bg-white p-10 text-center'>
              Public event listings are currently unavailable. Please check back
              soon.
            </p>
          ) : (
            <>
              <div className='grid gap-5 md:grid-cols-2 lg:grid-cols-3'>
                {data.items.map((item) => {
                  const Icon =
                    types.find((t) => t.key === item.type)?.Icon ||
                    CalendarDays;
                  return (
                    <article
                      key={item.id}
                      className='flex min-w-0 flex-col overflow-hidden rounded-2xl border border-violet-200 bg-white shadow-sm shadow-violet-200/60'
                    >
                      <div className="relative">
                      <button
                        className='relative block w-full text-left'
                        aria-label={`View ${item.title}`}
                        onClick={() => open(item.id)}
                      >
                        <img
                          src={image(item.image)}
                          alt=''
                          loading='lazy'
                          className='h-40 w-full object-cover'
                        />
                        <span className='absolute left-3 top-3 flex items-center gap-1 rounded-full bg-white/95 px-2 py-1 text-[11px] font-bold text-violet-800'>
                          <Icon size={16} />
                          {labels[item.type]}
                        </span>
                        {item.featured && (
                          <span
                            className='absolute right-3 top-3 rounded-full bg-yellow-100 p-1 text-amber-600'
                            title='Featured'
                          >
                            <Star size={15} />
                          </span>
                        )}
                      </button>{item.display_status==='completed'&&item.recording_url&&<MediaLink video href={item.recording_url} aria-label={`Play ${item.title} recording`} className="absolute left-1/2 top-1/2 grid size-16 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border-2 border-white bg-black/40 text-white hover:bg-violet-700/70"><PlayCircle size={40}/></MediaLink>}</div>
                      <div className='flex flex-1 flex-col p-3'>
                        <div className='mb-3 flex items-start gap-3'>
                          <time className='shrink-0 rounded-md bg-gradient-to-b from-violet-500 to-violet-800 px-2 py-1 text-center text-white'>
                            <span className='block text-[10px] font-bold'>
                              {month(item.starts_at)}
                            </span>
                            <strong className='block text-2xl leading-none'>
                              {day(item.starts_at)}
                            </strong>
                          </time>
                          <h3 className='text-sm font-extrabold leading-tight tracking-tight'>
                            <button
                              className='text-left hover:text-violet-700'
                              onClick={() => open(item.id)}
                            >
                              {item.title}
                            </button>
                          </h3>
                        </div>
                        <p className='mb-2 flex items-start gap-2 text-[11px]'>
                          <Clock
                            size={16}
                            className='shrink-0 text-violet-700'
                          />
                          {dates(item.starts_at)} • {time(item.starts_at)}
                        </p>
                        <p className='mb-2 flex items-start gap-2 text-[11px]'>
                          {item.format === "online" ? (
                            <Monitor
                              size={16}
                              className='shrink-0 text-violet-700'
                            />
                          ) : (
                            <MapPin
                              size={16}
                              className='shrink-0 text-violet-700'
                            />
                          )}
                          {item.location}
                        </p>
                        <p className='mb-4 flex items-start gap-2 text-[11px]'>
                          <Users
                            size={16}
                            className='shrink-0 text-violet-700'
                          />
                          <span>
                            {item.target_audiences.length
                              ? item.target_audiences
                                  .map((a) => audiences[a])
                                  .join(" • ")
                              : "All Audiences"}
                          </span>
                        </p>
                        <div className='mt-auto'>{action(item)}</div>
                      </div>
                    </article>
                  );
                })}
              </div>
              {!data.items.length && (
                <div className='rounded-xl border border-violet-100 bg-white p-10 text-center'>
                  <CalendarDays
                    size={35}
                    className='mx-auto mb-3 text-violet-500'
                  />
                  <p>
                    {hasFilters
                      ? "No events match these filters."
                      : applied.tab === "upcoming"
                        ? "No upcoming events have been published yet."
                        : applied.tab === "live"
                          ? "No live online sessions are running right now."
                          : applied.tab === "featured"
                            ? "No featured events are available right now."
                            : "No past events are available yet."}
                  </p>
                  <div className='mt-4 flex flex-wrap justify-center gap-3'>
                    {hasFilters ? (
                      <button
                        className={outline}
                        onClick={() =>
                          filter({
                            ...initial(new URLSearchParams()),
                            tab: applied.tab,
                          })
                        }
                      >
                        Clear Filters
                      </button>
                    ) : (
                      <button
                        className={outline}
                        onClick={() =>
                          filter({
                            ...initial(new URLSearchParams()),
                            tab: applied.tab === "past" ? "upcoming" : "past",
                          })
                        }
                      >
                        {applied.tab === "past"
                          ? "Browse Upcoming Events"
                          : "Browse Past Events"}
                      </button>
                    )}
                    <Link className={outline} to={host}>
                      Host an Event
                    </Link>
                  </div>
                </div>
              )}
              <footer className='mt-6 flex flex-wrap items-center justify-between gap-3 text-xs'>
                <span>
                  {data.meta.total} events · Times shown in {timezone}
                </span>
                <div className='flex items-center gap-2'>
                  <button
                    className={outline}
                    disabled={applied.page <= 1}
                    onClick={() =>
                      filter({ ...applied, page: applied.page - 1 })
                    }
                  >
                    <ChevronLeft size={16} />
                    Previous
                  </button>
                  <span>
                    Page {applied.page} of {Math.max(1, data.meta.total_pages)}
                  </span>
                  <button
                    className={outline}
                    disabled={applied.page >= data.meta.total_pages}
                    onClick={() =>
                      filter({ ...applied, page: applied.page + 1 })
                    }
                  >
                    Next
                    <ChevronRight size={16} />
                  </button>
                </div>
              </footer>
            </>
          )}
        </div>
      </section>
    </MainLayout>
  );
}
