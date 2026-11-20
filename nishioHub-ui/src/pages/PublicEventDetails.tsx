import {MediaLink} from '@/components/media/platform-video';
import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  Link,
  useNavigate,
  useParams,
  useSearchParams,
} from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import { isAxiosError } from "axios";
import { toast } from "sonner";
import {
  ArrowRight,
  BookOpen,
  BriefcaseBusiness,
  CalendarDays,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  CircleHelp,
  Clock,
  Code2,
  Download,
  Home,
  Info,
  Laptop,
  MapPin,
  Mic,
  Monitor,
  Rocket,
  Share2,
  Sprout,
  Users,
  UserPlus,
  Video,
  PlayCircle,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { ButtonLoader } from "@/components/loaders/ButtonLoader";
import { DashboardSkeleton } from "@/components/loaders/DashboardSkeleton";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { PublicEventRegistrationControls } from "@/components/public-event-registration-controls";
import { useAuth } from "@/lib/auth-context";
import { assetUrl, usePlatform } from "@/lib/platform-context";
import { operationError } from "@/components/admin/dashboard-operations";
import { registerForEvent, cancelEventRegistration } from "@/lib/events-api";
import { saveDownload } from "@/lib/achievements-api";
import {
  getPublicEventDetails,
  getPublicEventCalendar,
  downloadPublicEventMaterial,
  type PublicEventDetails as EventData,
} from "@/lib/public-events-api";

const outline =
  "inline-flex items-center justify-center gap-2 rounded-xl border border-violet-500 bg-white px-4 py-2.5 text-sm font-bold text-violet-800 hover:bg-violet-50 disabled:cursor-not-allowed disabled:opacity-50";
const primary = `${outline} !border-transparent bg-gradient-to-b from-violet-600 to-violet-800 !text-white`;
const panel =
  "rounded-xl border border-violet-100 bg-white p-4 shadow-sm shadow-violet-100";
const audienceLabels: Record<string, string> = {
  primary: "Primary Learners",
  secondary: "Secondary Students",
  university: "University & College",
  early_career: "Early Career / Job Seekers",
  professionals: "Professionals & Leaders",
};
const modes: Record<string, string> = {
  online: "Online",
  on_site: "Onsite",
  hybrid: "Onsite & Online (Hybrid)",
};
const tabs = [
  { key: "overview", label: "Overview", Icon: Info },
  { key: "agenda", label: "Agenda", Icon: CalendarDays },
  { key: "speakers", label: "Speakers", Icon: Users },
  { key: "venue", label: "Venue", Icon: MapPin },
  { key: "resources", label: "Resources", Icon: BookOpen },
  { key: "faqs", label: "FAQs", Icon: CircleHelp },
] as const;
type Tab = (typeof tabs)[number]["key"];
function title(value: string) {
  return value
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}
function eventImage(value: string | null | undefined) {
  return value?.startsWith("/images/")
    ? value
    : assetUrl(value) || "/images/event-coding.png";
}

function Countdown({ startsAt, endsAt }: { startsAt: string; endsAt: string }) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, []);
  const seconds = Math.max(
    0,
    Math.floor((new Date(startsAt).getTime() - now) / 1000),
  );
  if (new Date(endsAt).getTime() <= now)
    return (
      <p className='rounded-xl bg-violet-50 p-4 text-center font-bold text-violet-800'>
        This event has ended
      </p>
    );
  if (new Date(startsAt).getTime() <= now)
    return (
      <p className='rounded-xl bg-green-50 p-4 text-center font-bold text-green-700'>
        This event is happening now
      </p>
    );
  return (
    <div
      aria-label='Time until the event starts'
      className='grid grid-cols-4 gap-2'
    >
      {[
        [Math.floor(seconds / 86400), "Days"],
        [Math.floor(seconds / 3600) % 24, "Hours"],
        [Math.floor(seconds / 60) % 60, "Minutes"],
        [seconds % 60, "Seconds"],
      ].map(([value, label]) => (
        <div
          key={label}
          className='rounded-xl bg-violet-100 px-1 py-3 text-center'
        >
          <strong className='block text-3xl font-extrabold text-violet-800'>
            {String(value).padStart(2, "0")}
          </strong>
          <span className='text-xs'>{label}</span>
        </div>
      ))}
    </div>
  );
}
function Heading({
  children,
  action,
}: {
  children: ReactNode;
  action?: ReactNode;
}) {
  return (
    <header className='mb-3 flex flex-wrap items-center justify-between gap-2'>
      <h2 className='flex items-center gap-2 text-lg font-extrabold'>
        <span aria-hidden='true' className='h-1 w-7 rounded bg-violet-700' />
        {children}
      </h2>
      {action}
    </header>
  );
}
function SpeakerCard({
  speaker,
  full = false,
}: {
  speaker: EventData["speakers"][number];
  full?: boolean;
}) {
  const [failed, setFailed] = useState(false);
  return (
    <article className='min-w-0 overflow-hidden rounded-xl border border-violet-200 bg-gradient-to-b from-slate-100 to-white'>
      <div className='grid h-28 place-items-center overflow-hidden bg-violet-50'>
        {speaker.avatar_url && !failed ? (
          <img
            src={speaker.avatar_url}
            alt={speaker.name}
            className='h-full w-full object-cover object-top'
            loading='lazy'
            onError={() => setFailed(true)}
          />
        ) : (
          <Users aria-hidden='true' size={54} className='text-violet-400' />
        )}
      </div>
      <div className='p-3'>
        <h3 className='break-words text-sm font-extrabold'>{speaker.name}</h3>
        <p className='mt-1 text-xs'>{speaker.title}</p>
        <span className='mt-3 inline-block rounded-full bg-violet-100 px-3 py-1 text-[11px] font-bold text-violet-800'>
          {speaker.role || "Speaker"}
        </span>
        {full && speaker.bio && (
          <p className='mt-3 whitespace-pre-wrap text-sm text-slate-600'>
            {speaker.bio}
          </p>
        )}
      </div>
    </article>
  );
}
function LearningIllustration() {
  return (
    <div
      aria-hidden='true'
      className='relative hidden h-36 w-48 shrink-0 rounded-[50%_40%_15%_30%] bg-violet-100 sm:block'
    >
      <Laptop
        size={125}
        className='absolute bottom-0 left-2 fill-violet-600 text-violet-950'
      />
      <Code2 size={48} className='absolute bottom-12 left-11 text-white' />
      <Sprout
        size={70}
        className='absolute right-1 top-0 fill-green-200 text-green-600'
      />
      <BookOpen
        size={62}
        className='absolute bottom-0 right-0 fill-amber-200 text-amber-500'
      />
    </div>
  );
}

export default function PublicEventDetails() {
  const { id: rawId } = useParams();
  const numericId = Number(rawId);
  const id =
    /^[1-9]\d*$/.test(rawId || "") && Number.isSafeInteger(numericId)
      ? numericId
      : 0;
  const { user } = useAuth();
  const platform = usePlatform();
  const client = useQueryClient();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const selected = params.get("section");
  const tab: Tab = tabs.some((item) => item.key === selected)
    ? (selected as Tab)
    : "overview";
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [cancelOpen, setCancelOpen] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);
  const [reminders, setReminders] = useState(false);
  const lock = useRef(false);
  const content = useRef<HTMLElement>(null);
  const query = useQuery({
    queryKey: ["public-event-detail", user?.id, id],
    queryFn: () => getPublicEventDetails(id),
    enabled: !!id,
    refetchInterval: 30000,
  });
  const event = query.data;
  const returnTo = `/community-events/${id}`;
  const loginTo = `/login?${new URLSearchParams({ return_to: returnTo })}`;
  useEffect(() => {
    setError("");
    setCancelOpen(false);
    setReminders(false);
  }, [id, user?.id]);
  const timezone = event?.timezone || platform.timezone;
  const date = (value: string) =>
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
    });
  function select(value: Tab) {
    const next = new URLSearchParams(params);
    if (value === "overview") next.delete("section");
    else next.set("section", value);
    setParams(next, { replace: true });
    requestAnimationFrame(() =>
      content.current?.scrollIntoView({ block: "start" }),
    );
  }
  async function refresh() {
    await Promise.all(
      [
        "public-event-detail",
        "public-events-discovery",
        "events",
        "mentee-dashboard",
        "public-home",
      ].map((key) => client.invalidateQueries({ queryKey: [key] })),
    );
  }
  async function perform(name: string, work: () => Promise<void>) {
    if (lock.current) return;
    lock.current = true;
    setPending(name);
    setError("");
    try {
      await work();
    } catch (failure) {
      if (isAxiosError(failure) && failure.response?.status === 401)
        navigate(loginTo);
      else setError(operationError(failure));
      if (name === "register" || name === "cancel") await refresh();
    } finally {
      lock.current = false;
      setPending(null);
    }
  }
  const shareUrl = `${window.location.origin}${returnTo}`;
  async function share() {
    try {
      if (navigator.share)
        await navigator.share({ title: event?.title, url: shareUrl });
      else {
        await navigator.clipboard.writeText(shareUrl);
        toast.success("Event link copied");
      }
    } catch (failure) {
      if (!(failure instanceof DOMException && failure.name === "AbortError"))
        setShareOpen(true);
    }
  }
  const labels = event?.title.trim().split(/\s+/) || [];
  const highlight = labels.length > 2 ? labels.slice(-2).join(" ") : "";
  const faqs = event?.faqs.length
    ? event.faqs
    : [
        {
          question: "How do I register?",
          answer:
            "Log in or create an account, then select Register for This Event. Your registration is confirmed when the page shows You’re registered.",
        },
        {
          question: "Is registration free?",
          answer: "Registration for this event is free.",
        },
        {
          question: "How do I access event resources?",
          answer:
            "Register for the event and open the Resources tab. Published materials become available to registered participants.",
        },
      ];
  const more = (label: string, target: Tab) => (
    <button
      className='inline-flex items-center gap-1 text-xs font-bold text-violet-700'
      onClick={() => select(target)}
    >
      {label}
      <ArrowRight size={15} />
    </button>
  );
  return (
    <MainLayout>
      <Helmet>
        <title>
          {event?.title || "Event Details"} | {platform.platform_name}
        </title>
        <meta
          name='description'
          content={
            event?.description.slice(0, 160) ||
            "Explore event details, speakers, agenda and registration."
          }
        />
      </Helmet>
      <div className='mx-auto max-w-[1440px] px-3 pb-6 lg:px-10'>
        <nav
          aria-label='Breadcrumb'
          className='flex items-center gap-3 py-5 text-xs font-semibold'
        >
          <Link to='/' aria-label='Home'>
            <Home size={18} className='text-violet-700' />
          </Link>
          <ChevronRight size={14} />
          <Link to='/community-events'>Events</Link>
          <ChevronRight size={14} />
          <span>Event Details</span>
        </nav>
        {!id ? (
          <div role='alert' className={panel}>
            <h1 className='text-xl font-bold'>Invalid Event</h1>
            <Link to='/community-events' className='text-violet-700 underline'>
              Browse Events
            </Link>
          </div>
        ) : query.isPending ? (
          <DashboardSkeleton variant='details' />
        ) : query.isError || !event ? (
          <div role='alert' className={`${panel} space-y-4`}>
            <h1 className='text-xl font-bold'>Event unavailable</h1>
            <p>
              This event may be unpublished, removed, or temporarily
              unavailable.
            </p>
            <button className={outline} onClick={() => query.refetch()}>
              Retry Event Details
            </button>
            <Link className={`${outline} ml-2`} to='/community-events'>
              Browse Events
            </Link>
          </div>
        ) : (
          <div className='grid gap-5 lg:grid-cols-[minmax(0,2.15fr)_minmax(300px,1fr)]'>
            <div className='min-w-0'>
              <section className='relative overflow-hidden rounded-2xl bg-[#2a1459] text-white'>
                <img
                  src={eventImage(event.image)}
                  alt=''
                  fetchPriority='high'
                  className='h-52 w-full object-cover lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[58%]'
                />
                {event.display_status==='completed'&&event.recording_url&&<MediaLink video href={event.recording_url} aria-label="Play event recording" className="absolute right-1/2 top-24 z-10 grid size-20 -translate-y-1/2 translate-x-1/2 place-items-center rounded-full border-2 border-white bg-black/40 text-white lg:right-[27%] lg:top-1/2"><PlayCircle size={48}/></MediaLink>}
                <div
                  aria-hidden='true'
                  className='absolute inset-y-0 left-0 hidden w-[65%] bg-yellow-300 lg:block'
                  style={{ clipPath: "ellipse(100% 150% at 0% 20%)" }}
                />
                <div
                  aria-hidden='true'
                  className='absolute inset-y-0 left-0 hidden w-[60%] bg-gradient-to-r from-[#281052] to-violet-800 lg:block'
                  style={{ clipPath: "ellipse(100% 150% at 0% 20%)" }}
                />
                <div className='relative px-6 py-5 lg:w-[58%]'>
                  <p className='mb-4 inline-flex items-center gap-2 rounded-full bg-violet-600 px-3 py-1.5 text-sm font-bold'>
                    <CalendarDays size={21} />
                    {event.display_status === "completed"
                      ? "Past Event"
                      : event.display_status === "ongoing"
                        ? "Live Event"
                        : "Upcoming Event"}
                  </p>
                  <h2 className='text-3xl font-extrabold leading-tight tracking-tight xl:text-[36px]'>
                    {highlight ? (
                      <>
                        {labels.slice(0, -2).join(" ")}
                        <br />
                        <span className='text-yellow-300'>{highlight}</span>
                      </>
                    ) : (
                      event.title
                    )}
                  </h2>
                  <p className='mt-4 line-clamp-2 text-sm leading-relaxed'>
                    {event.description}
                  </p>
                  <div className='mt-5 grid grid-cols-3 divide-x divide-white/20 text-center text-[10px] font-bold'>
                    {[
                      { Icon: Laptop, text: title(event.event_type) },
                      { Icon: BriefcaseBusiness, text: modes[event.format] },
                      { Icon: Rocket, text: "Learn & Connect" },
                    ].map(({ Icon, text }) => (
                      <div key={text} className='px-1'>
                        <Icon size={28} className='mx-auto mb-2' />
                        {text}
                      </div>
                    ))}
                  </div>
                </div>
              </section>
              <header className='my-4'>
                <h1 className='text-2xl font-extrabold tracking-tight xl:text-[29px]'>
                  {event.title}
                </h1>
                <div className='mt-3 flex flex-wrap items-center gap-x-4 gap-y-3 text-[11px] font-semibold'>
                  <span className='flex items-center gap-2'>
                    <CalendarDays size={19} className='text-violet-700' />
                    {date(event.starts_at)}
                  </span>
                  <span className='flex items-center gap-2'>
                    <Clock size={19} className='text-violet-700' />
                    {time(event.starts_at)} – {time(event.ends_at)}
                  </span>
                  <span className='flex items-center gap-2'>
                    <MapPin size={19} className='text-violet-700' />
                    {event.location}
                  </span>
                  <span className='flex items-center gap-2'>
                    <Users size={19} className='text-violet-700' />
                    {modes[event.format]}
                  </span>
                  <button
                    className={`${outline} ml-auto !px-3 !py-2 !text-xs`}
                    onClick={share}
                  >
                    <Share2 size={16} />
                    Share
                  </button>
                </div>
                <p className='mt-2 text-[10px] text-slate-500'>
                  Times shown in {timezone}
                  {date(event.starts_at) !== date(event.ends_at)
                    ? ` · Ends ${date(event.ends_at)}`
                    : ""}
                </p>
              </header>
              <section ref={content} className='scroll-mt-24'>
                <nav
                  aria-label='Event details sections'
                  className='mb-3 flex overflow-x-auto rounded-xl border border-violet-200 bg-white'
                >
                  {tabs.map(({ key, label, Icon }) => (
                    <button
                      key={key}
                      aria-current={tab === key ? "page" : undefined}
                      className={`flex min-w-fit flex-1 items-center justify-center gap-2 border-r border-violet-100 px-4 py-3 text-xs font-bold last:border-0 ${tab === key ? "rounded-lg bg-gradient-to-b from-violet-600 to-violet-800 text-white" : "text-violet-950 hover:bg-violet-50"}`}
                      onClick={() => select(key)}
                    >
                      <Icon size={20} />
                      {label}
                    </button>
                  ))}
                </nav>
                {tab === "overview" && (
                  <div className={panel}>
                    <Heading>About the Event</Heading>
                    <p className='whitespace-pre-wrap text-sm leading-relaxed'>
                      {event.description}
                    </p>
                    {!!event.objectives.length && (
                      <div className='mt-5'>
                        <Heading>What You Will Gain</Heading>
                        <div className='flex items-end gap-3'>
                          <ul className='flex-1 space-y-2 text-sm'>
                            {event.objectives.map((item, index) => (
                              <li
                                key={index}
                                className='flex items-start gap-2'
                              >
                                <CheckCircle2
                                  size={18}
                                  className='shrink-0 fill-violet-700 text-white'
                                />
                                {item}
                              </li>
                            ))}
                          </ul>
                          <LearningIllustration />
                        </div>
                      </div>
                    )}
                    <div className='mt-5 border-t border-violet-100 pt-4'>
                      <Heading action={more("View All Speakers", "speakers")}>
                        Featured Speakers
                      </Heading>
                      {event.speakers.length ? (
                        <div className='grid gap-3 sm:grid-cols-2 lg:grid-cols-4'>
                          {event.speakers.slice(0, 4).map((speaker) => (
                            <SpeakerCard key={speaker.id} speaker={speaker} />
                          ))}
                        </div>
                      ) : (
                        <p className='py-4 text-sm text-slate-500'>
                          Speakers will be announced here.
                        </p>
                      )}
                    </div>
                  </div>
                )}
                {tab === "agenda" && (
                  <div className={panel}>
                    <Heading>Event Agenda</Heading>
                    {event.agenda.length ? (
                      <ol className='space-y-4'>
                        {event.agenda.map((item) => (
                          <li
                            key={item.id}
                            className='flex gap-4 rounded-lg border border-violet-100 p-3'
                          >
                            <CalendarDays
                              size={24}
                              className='shrink-0 text-violet-700'
                            />
                            <div>
                              <time className='text-xs font-bold text-violet-700'>
                                {date(item.starts_at)} · {time(item.starts_at)}{" "}
                                – {time(item.ends_at)}
                              </time>
                              <h3 className='mt-1 font-bold'>{item.title}</h3>
                              {item.description && (
                                <p className='mt-2 whitespace-pre-wrap text-sm'>
                                  {item.description}
                                </p>
                              )}
                            </div>
                          </li>
                        ))}
                      </ol>
                    ) : (
                      <p className='py-4 text-sm'>
                        The agenda has not been published yet.
                      </p>
                    )}
                  </div>
                )}
                {tab === "speakers" && (
                  <div className={panel}>
                    <Heading>Event Speakers</Heading>
                    {event.speakers.length ? (
                      <div className='grid gap-4 sm:grid-cols-2'>
                        {event.speakers.map((speaker) => (
                          <SpeakerCard
                            key={speaker.id}
                            speaker={speaker}
                            full
                          />
                        ))}
                      </div>
                    ) : (
                      <p className='py-4 text-sm'>
                        Speakers will be announced here.
                      </p>
                    )}
                  </div>
                )}
                {tab === "venue" && (
                  <div className={`${panel} space-y-4`}>
                    <Heading>Venue &amp; Joining Information</Heading>
                    <p className='flex items-center gap-2 font-bold'>
                      <MapPin className='text-violet-700' />
                      {event.location}
                    </p>
                    <p className='text-sm'>
                      {modes[event.format]} · {date(event.starts_at)} ·{" "}
                      {time(event.starts_at)} – {time(event.ends_at)} (
                      {timezone})
                    </p>
                    {event.format !== "online" && (
                      <MediaLink
                        className={outline}
                        href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(event.location)}`}
                        target='_blank'
                        rel='noopener noreferrer'
                      >
                        Open Location in Maps
                        <ArrowRight size={16} />
                      </MediaLink>
                    )}
                    {event.format !== "on_site" &&
                      (event.meeting_url ? (
                        <MediaLink
                          className={primary}
                          href={event.meeting_url}
                          target='_blank'
                          rel='noopener noreferrer'
                        >
                          <Video size={18} />
                          Open Meeting
                        </MediaLink>
                      ) : (
                        <p className='rounded-lg bg-violet-50 p-3 text-sm'>
                          {event.display_status === "completed"
                            ? "This event has ended. Check the Resources tab and any published recording for follow-up materials."
                            : event.registered
                              ? "The organizer will add online joining information when it is ready."
                              : "Register to access online joining information."}
                        </p>
                      ))}
                  </div>
                )}
                {tab === "resources" && (
                  <div className={panel}>
                    <Heading>Event Resources</Heading>
                    {error && (
                      <p
                        role='alert'
                        className='mb-3 rounded-lg bg-red-50 p-3 text-sm text-red-700'
                      >
                        {error}
                      </p>
                    )}
                    {event.resources_locked ? (
                      <div className='rounded-xl bg-violet-50 p-5 text-sm'>
                        <p>
                          Register for this event to access its learning
                          resources.
                        </p>
                        {!user && (
                          <Link
                            to={loginTo}
                            className='mt-3 inline-block font-bold text-violet-700 underline'
                          >
                            Log In to Register
                          </Link>
                        )}
                      </div>
                    ) : event.materials.length ? (
                      <div className='space-y-3'>
                        {event.materials.map((material) => (
                          <article
                            key={material.id}
                            className='rounded-lg border border-violet-100 p-4'
                          >
                            <h3 className='font-bold'>{material.title}</h3>
                            <p className='my-2 whitespace-pre-wrap text-sm'>
                              {material.description}
                            </p>
                            {material.file ? (
                              <ButtonLoader
                                className={outline}
                                loading={pending === `file-${material.id}`}
                                disabled={!!pending}
                                loadingText='Downloading...'
                                onClick={() =>
                                  perform(`file-${material.id}`, async () =>
                                    saveDownload(
                                      await downloadPublicEventMaterial(
                                        id,
                                        material.id,
                                      ),
                                      material.file!.filename,
                                    ),
                                  )
                                }
                              >
                                <Download size={16} />
                                {material.file.filename}
                              </ButtonLoader>
                            ) : (
                              material.url && (
                                <MediaLink
                                  className={outline}
                                  href={material.url}
                                  target='_blank'
                                  rel='noopener noreferrer'
                                >
                                  Open Resource
                                  <ArrowRight size={16} />
                                </MediaLink>
                              )
                            )}
                          </article>
                        ))}
                      </div>
                    ) : (
                      <p className='py-4 text-sm'>
                        No resources have been published yet.
                      </p>
                    )}
                  </div>
                )}
                {tab === "faqs" && (
                  <div className={panel}>
                    <Heading>Frequently Asked Questions</Heading>
                    <div className='space-y-3'>
                      {faqs.map((faq, index) => (
                        <details
                          key={index}
                          className='rounded-lg border border-violet-100 p-4'
                        >
                          <summary className='cursor-pointer text-sm font-bold'>
                            {faq.question}
                          </summary>
                          <p className='mt-3 whitespace-pre-wrap text-sm leading-relaxed'>
                            {faq.answer}
                          </p>
                        </details>
                      ))}
                    </div>
                  </div>
                )}
              </section>
              <section className='mt-5'>
                <Heading action={more("View Full Agenda", "agenda")}>
                  Event Agenda (Summary)
                </Heading>
                {event.agenda.length ? (
                  <div className='grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6'>
                    {event.agenda.slice(0, 6).map((item, index) => {
                      const Icon = [
                        Users,
                        Mic,
                        Monitor,
                        Users,
                        BriefcaseBusiness,
                        Rocket,
                      ][index];
                      return (
                        <button
                          key={item.id}
                          className={`${panel} flex flex-col items-center gap-2 !p-3 text-center hover:border-violet-400`}
                          onClick={() => select("agenda")}
                        >
                          <Icon size={22} className='text-violet-700' />
                          <time className='text-xs font-extrabold text-violet-700'>
                            {time(item.starts_at)}
                          </time>
                          <span className='text-xs'>{item.title}</span>
                        </button>
                      );
                    })}
                  </div>
                ) : (
                  <p className={`${panel} text-sm text-slate-500`}>
                    The event schedule will appear here when published.
                  </p>
                )}
              </section>
            </div>
            <aside className='min-w-0 space-y-4'>
              <section className={`${panel} space-y-5`}>
                <h2 className='flex items-center gap-3 text-lg font-extrabold'>
                  <Clock size={29} className='text-violet-700' />
                  Event Countdown
                </h2>
                <Countdown startsAt={event.starts_at} endsAt={event.ends_at} />
                {event.display_status === "completed" ? (
                  event.recording_url ? (
                    <p className="text-sm text-violet-700">Play the recording from the event banner.</p>
                  ) : (
                    <p className='rounded-lg bg-violet-50 p-3 text-sm'>
                      This event has ended. No public recording is available.
                    </p>
                  )
                ) : event.registered ? (
                  <div className='space-y-3'>
                    <p className='flex items-center justify-center gap-2 font-bold text-green-700'>
                      <CheckCircle2 size={21} />
                      You’re registered
                    </p>
                    {event.meeting_url && (
                      <MediaLink
                        className={`${primary} w-full`}
                        href={event.meeting_url}
                        target='_blank'
                        rel='noopener noreferrer'
                      >
                        <Video size={18} />
                        Open Meeting
                      </MediaLink>
                    )}
                    {event.can_cancel && (
                      <button
                        className={`${outline} w-full`}
                        disabled={!!pending}
                        onClick={() => setCancelOpen(true)}
                      >
                        Cancel Registration
                      </button>
                    )}
                  </div>
                ) : !event.can_register ? (
                  <button className={`${outline} w-full`} disabled>
                    {event.available_places === 0
                      ? "Event Full"
                      : "Registration Closed"}
                  </button>
                ) : user ? (
                  <ButtonLoader
                    className={`${primary} w-full`}
                    loading={pending === "register"}
                    disabled={!!pending}
                    loadingText='Registering...'
                    onClick={() =>
                      perform("register", async () => {
                        await registerForEvent(id);
                        await refresh();
                        toast.success("You are registered for this event");
                      })
                    }
                  >
                    <UserPlus size={21} />
                    Register for This Event
                  </ButtonLoader>
                ) : (
                  <Link className={`${primary} w-full`} to={loginTo}>
                    <UserPlus size={21} />
                    Register for This Event
                  </Link>
                )}
                <details className='relative'>
                  <summary
                    className={`${outline} w-full cursor-pointer list-none`}
                  >
                    <CalendarDays size={22} />
                    Add to Calendar
                    <ChevronDown size={16} />
                  </summary>
                  <div className='mt-2 space-y-2 rounded-lg border border-violet-100 p-3'>
                    <ButtonLoader
                      className={`${outline} w-full`}
                      loading={pending === "calendar"}
                      disabled={!!pending}
                      loadingText='Preparing Calendar...'
                      onClick={() =>
                        perform("calendar", async () =>
                          saveDownload(
                            await getPublicEventCalendar(id),
                            `nishiohub-event-${id}.ics`,
                          ),
                        )
                      }
                    >
                      <Download size={16} />
                      Download Calendar (.ics)
                    </ButtonLoader>
                    {event.registered &&
                      event.display_status !== "completed" && (
                        <button
                          className='text-sm font-bold text-violet-700'
                          onClick={() => setReminders(!reminders)}
                        >
                          Calendar Reminder Settings
                        </button>
                      )}
                  </div>
                </details>
                {reminders && event.registered && (
                  <PublicEventRegistrationControls
                    eventId={id}
                    reminderMinutes={event.reminder_minutes ?? 30}
                    disabled={!!pending}
                    onRefresh={refresh}
                  />
                )}
                {error && tab !== "resources" && (
                  <p
                    role='alert'
                    className='rounded-lg bg-red-50 p-3 text-sm text-red-700'
                  >
                    {error}
                  </p>
                )}
              </section>
              <section className={panel}>
                <dl className='divide-y divide-violet-100'>
                  {[
                    {
                      Icon: CalendarDays,
                      label: "Event Type",
                      value: title(event.event_type),
                    },
                    {
                      Icon: Users,
                      label: "Target Audience",
                      value: event.target_audiences.length
                        ? event.target_audiences
                            .map((key) => audienceLabels[key])
                            .join(", ")
                        : "All Learners & Professionals",
                    },
                    {
                      Icon: Monitor,
                      label: "Mode",
                      value: modes[event.format],
                    },
                    {
                      Icon: UserPlus,
                      label: "Capacity",
                      value:
                        event.capacity === null
                          ? "Open registration · No capacity limit"
                          : `${event.capacity.toLocaleString()} participants · ${event.available_places?.toLocaleString()} places available`,
                    },
                  ].map(({ Icon, label, value }) => (
                    <div key={label} className='flex gap-4 py-3 first:pt-0'>
                      <Icon size={26} className='shrink-0 text-violet-700' />
                      <div>
                        <dt className='text-xs font-bold'>{label}</dt>
                        <dd className='mt-1 text-sm'>{value}</dd>
                      </div>
                    </div>
                  ))}
                  <div className='flex items-center justify-between py-3'>
                    <dt className='text-sm font-bold'>Registration Fee</dt>
                    <dd className='rounded-xl bg-green-100 px-5 py-2 text-sm font-bold text-green-700'>
                      Free
                    </dd>
                  </div>
                </dl>
              </section>
              <section className={panel}>
                <h2 className='mb-3 text-sm font-bold'>Organized By</h2>
                <img
                  src={
                    assetUrl(platform.logo_url) || "/assets/learning-logo.svg"
                  }
                  alt={platform.platform_name}
                  className='mx-auto h-16 max-w-full object-contain'
                />
                <p className='mt-2 text-center text-sm font-semibold'>
                  {event.organizer}
                </p>
              </section>
              <section className={panel}>
                <header className='mb-4 flex items-center justify-between'>
                  <h2 className='text-lg font-extrabold'>Related Events</h2>
                  <Link
                    to='/community-events'
                    className='text-xs font-bold text-violet-700'
                  >
                    View More →
                  </Link>
                </header>
                {event.related_events.length ? (
                  event.related_events.map((item) => (
                    <Link
                      key={item.id}
                      to={`/community-events/${item.id}`}
                      className='flex items-center gap-3 border-t border-violet-100 py-3'
                    >
                      <img
                        src={eventImage(item.image)}
                        alt=''
                        loading='lazy'
                        className='h-20 w-24 shrink-0 rounded-xl object-cover'
                      />
                      <div className='min-w-0'>
                        <h3 className='text-sm font-extrabold'>{item.title}</h3>
                        <p className='mt-2 flex items-center gap-1 text-xs'>
                          <CalendarDays
                            size={15}
                            className='shrink-0 text-violet-700'
                          />
                          {date(item.starts_at)}
                        </p>
                        <p className='mt-1 flex items-center gap-1 text-xs'>
                          <MapPin
                            size={15}
                            className='shrink-0 text-violet-700'
                          />
                          {item.location}
                        </p>
                      </div>
                      <ChevronRight
                        size={20}
                        className='ml-auto shrink-0 text-violet-700'
                      />
                    </Link>
                  ))
                ) : (
                  <p className='text-sm text-slate-500'>
                    More events will appear here when published.
                  </p>
                )}
              </section>
            </aside>
          </div>
        )}
      </div>
      <Dialog
        open={cancelOpen}
        onOpenChange={(value) => {
          if (!pending) setCancelOpen(value);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cancel your registration?</DialogTitle>
            <DialogDescription>
              Your place will be released. You can register again if places
              remain.
            </DialogDescription>
          </DialogHeader>
          <div className='flex justify-end gap-3'>
            <button
              className={outline}
              disabled={!!pending}
              onClick={() => setCancelOpen(false)}
            >
              Keep Registration
            </button>
            <ButtonLoader
              className={primary}
              loading={pending === "cancel"}
              disabled={!!pending}
              loadingText='Cancelling...'
              onClick={() =>
                perform("cancel", async () => {
                  await cancelEventRegistration(id);
                  setCancelOpen(false);
                  await refresh();
                  toast.success("Registration cancelled");
                })
              }
            >
              Cancel Registration
            </ButtonLoader>
          </div>
        </DialogContent>
      </Dialog>
      <Dialog open={shareOpen} onOpenChange={setShareOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Share This Event</DialogTitle>
            <DialogDescription>
              Copy this link to share the event.
            </DialogDescription>
          </DialogHeader>
          <input
            aria-label='Event share link'
            readOnly
            className='w-full rounded-lg border border-violet-200 p-3 text-sm'
            value={shareUrl}
            onFocus={(e) => e.target.select()}
          />
        </DialogContent>
      </Dialog>
    </MainLayout>
  );
}
