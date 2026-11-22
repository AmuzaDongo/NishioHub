import { useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  CalendarDays,
  ChartNoAxesCombined,
  Check,
  ClipboardList,
  GraduationCap,
  Handshake,
  LaptopMinimal,
  Play,
  School,
  Settings,
  Users,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { Skeleton } from "@/components/ui/skeleton";
import { VideoDialog, PlatformVideo } from "@/components/media/platform-video";
import { HowItWorksEditor } from "@/components/admin/how-it-works-editor";
import { getHowItWorks } from "@/lib/how-it-works-api";
import { useAuth } from "@/lib/auth-context";
import { usePlatform } from "@/lib/platform-context";
import { hasRole, isPlatformAdmin } from "@/lib/utils";
import { operationError } from "@/components/admin/dashboard-operations";
const audienceIcons = {
  learners: GraduationCap,
  mentors: Users,
  schools: School,
  organizations: Handshake,
};
const audienceLinks = {
  learners: "/programs",
  mentors: "/become-a-mentor",
  schools: "/partner-with-us",
  organizations: "/partner-with-us",
};
const stepIcons = [
  LaptopMinimal,
  ClipboardList,
  CalendarDays,
  ChartNoAxesCombined,
];
const colors = [
  "from-violet-50 to-purple-50 border-violet-200",
  "from-blue-50 to-violet-50 border-blue-200",
  "from-amber-50 to-white border-amber-200",
  "from-emerald-50 to-white border-emerald-200",
];
const badges = ["bg-violet-700", "bg-blue-600", "bg-amber-400", "bg-green-600"];
function Heading({ children }: { children: React.ReactNode }) {
  return (
    <h2 className='mb-9 flex items-center justify-center gap-4 text-center text-2xl font-extrabold tracking-tight md:text-3xl'>
      <span className='h-1 w-10 shrink-0 rounded-full bg-violet-700 md:w-16' />
      {children}
      <span className='h-1 w-10 shrink-0 rounded-full bg-violet-700 md:w-16' />
    </h2>
  );
}
export default function HowItWorksPage() {
  const { user, isLoading } = useAuth();
  const platform = usePlatform();
  const navigate = useNavigate();
  const steps = useRef<HTMLElement>(null);
  const [watch, setWatch] = useState(false);
  const [edit, setEdit] = useState(false);
  const query = useQuery({
    queryKey: ["public-how-it-works"],
    queryFn: getHowItWorks,
    staleTime: 30000,
    refetchInterval: 60000,
  });
  const c = query.data;
  const admin = isPlatformAdmin(user);
  const canManage =
    !!user && admin && user.management_permissions?.includes("system.manage");
  const dashboard = admin
    ? "/admin"
    : hasRole(user, "mentee")
      ? "/mentee/dashboard"
      : "/dashboard";
  const startTo = user
    ? dashboard
    : platform.registration_enabled
      ? "/register"
      : "/contact";
  const startLabel = user
    ? "Go to My Dashboard"
    : platform.registration_enabled
      ? "Get Started Now"
      : "Contact Our Team";
  const targets = [
    startTo,
    user ? "/profile" : startTo,
    "/programs",
    user ? (admin ? "/admin/goals" : "/my-goals") : "/learn",
  ];
  const heading =
    c?.heading === "How NishioHub Works"
      ? `How ${platform.platform_name} Works`
      : c?.heading || "";
  const lastSpace = heading.lastIndexOf(" ");
  return (
    <MainLayout>
      <Helmet>
        <title>How It Works | {platform.platform_name}</title>
        <meta
          name='description'
          content={
            c?.description ||
            "Discover how to join NishioHub, complete your profile, find mentorship and grow your skills."
          }
        />
      </Helmet>
      {query.isPending ? (
        <HowSkeleton />
      ) : query.isError ? (
        <section
          role='alert'
          className='mx-auto my-12 max-w-xl rounded-2xl border border-violet-100 bg-white p-8 text-center'
        >
          <h1 className='text-2xl font-bold'>How It Works</h1>
          <p className='my-4 text-sm'>{operationError(query.error)}</p>
          <button
            className='rounded-lg bg-violet-700 px-5 py-3 font-bold text-white'
            onClick={() => query.refetch()}
          >
            Retry Page
          </button>
        </section>
      ) : (
        c && (
          <>
            <section className='overflow-hidden bg-[#26134d] text-white'>
              <div className='relative mx-auto max-w-[1536px] lg:min-h-[335px]'>
                <img
                  src={c.hero_image}
                  alt='Illustrative mentor helping learners explore opportunities together'
                  fetchPriority='high'
                  className='h-60 w-full object-cover object-center lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[58%]'
                  onError={(e) => {
                    e.currentTarget.onerror = null;
                    e.currentTarget.src = "/images/learning/library-hero.webp";
                  }}
                />
                {c.overview_video_url && (
                  <button
                    type='button'
                    aria-label='Play How It Works overview'
                    onClick={() => setWatch(true)}
                    className='absolute right-1/2 top-28 z-10 grid size-20 -translate-y-1/2 translate-x-1/2 place-items-center rounded-full border-2 border-white bg-black/40 text-white shadow-lg hover:bg-violet-700/70 lg:right-[26%] lg:top-1/2'
                  >
                    <Play size={38} className='ml-1 fill-white' />
                  </button>
                )}
                <div
                  aria-hidden='true'
                  className='absolute inset-y-0 left-0 hidden w-[54%] bg-yellow-400 lg:block'
                  style={{ clipPath: "ellipse(100% 160% at 0% 0%)" }}
                />
                <div
                  aria-hidden='true'
                  className='absolute inset-y-0 left-0 hidden w-[51%] bg-gradient-to-r from-[#251343] to-violet-800 lg:block'
                  style={{ clipPath: "ellipse(100% 180% at 0% 0%)" }}
                />
                <div className='relative px-6 py-7 lg:w-[52%] lg:px-11'>
                  <p className='mb-4 inline-flex items-center gap-3 rounded-full bg-purple-500/75 px-4 py-1.5 text-sm font-bold'>
                    <Settings size={25} />
                    How It Works
                  </p>
                  <h1 className='text-4xl font-extrabold leading-tight tracking-tight xl:text-5xl'>
                    {lastSpace > 0 ? heading.slice(0, lastSpace) : heading}{" "}
                    {lastSpace > 0 && (
                      <span className='text-yellow-300'>
                        {heading.slice(lastSpace + 1)}
                      </span>
                    )}
                  </h1>
                  <p className='mt-3 max-w-lg text-base leading-relaxed md:text-lg'>
                    {c.description}
                  </p>
                  <div className='mt-5 flex flex-wrap gap-3'>
                    <button
                      className='inline-flex items-center gap-3 rounded-lg bg-white px-5 py-3 text-sm font-bold text-violet-800 hover:bg-violet-50'
                      onClick={() =>
                        steps.current?.scrollIntoView({
                          behavior: window.matchMedia(
                            "(prefers-reduced-motion: reduce)",
                          ).matches
                            ? "instant"
                            : "smooth",
                          block: "start",
                        })
                      }
                    >
                      Explore the Steps <ArrowRight size={19} />
                    </button>
                    <Link
                      to={startTo}
                      aria-disabled={isLoading}
                      className='inline-flex items-center gap-3 rounded-lg border-2 border-white px-5 py-2.5 text-sm font-bold hover:bg-white/10'
                    >
                      {startLabel}
                      <ArrowRight size={20} />
                    </Link>
                  </div>
                  {c.overview_video_url && (
                    <p className='mt-3 text-xs text-violet-100'>
                      Play the overview on the banner ·{" "}
                      {Math.ceil(c.overview_seconds / 60)} min
                    </p>
                  )}
                </div>
              </div>
            </section>
            <section
              ref={steps}
              id='getting-started'
              className='mx-auto max-w-[1440px] scroll-mt-24 px-5 pb-3 pt-7 md:px-10'
            >
              <Heading>Get Started in 4 Simple Steps</Heading>
              <ol className='grid gap-x-8 gap-y-10 sm:grid-cols-2 xl:grid-cols-4'>
                {c.steps.map((s, i) => {
                  const Icon = stepIcons[i];
                  return (
                    <li key={i} className='relative'>
                      <Link
                        to={targets[i]}
                        className={`relative flex h-full min-h-[247px] flex-col items-center rounded-2xl border bg-gradient-to-br px-5 pb-5 pt-10 text-center shadow-sm transition hover:-translate-y-1 hover:shadow-md focus-visible:outline-violet-700 ${colors[i]}`}
                      >
                        <span
                          className={`absolute -top-5 grid size-12 place-items-center rounded-full border-2 border-white text-2xl font-extrabold text-white ${badges[i]}`}
                        >
                          {i + 1}
                        </span>
                        <Icon
                          aria-hidden='true'
                          size={82}
                          strokeWidth={1.8}
                          className='mb-4 text-violet-700 drop-shadow-md'
                        />
                        <h3 className='text-lg font-extrabold tracking-tight'>
                          {s.title}
                        </h3>
                        <p className='mt-2 text-sm leading-snug'>
                          {s.description}
                        </p>
                      </Link>
                      {i < 3 && (
                        <ArrowRight
                          aria-hidden='true'
                          className='absolute -right-7 top-1/2 hidden text-violet-600 xl:block'
                          size={25}
                        />
                      )}
                    </li>
                  );
                })}
              </ol>
            </section>
            <section className='mx-auto max-w-[1440px] px-4 pb-7 pt-6'>
              <Heading>It Works for Everyone</Heading>
              <div className='grid gap-4 sm:grid-cols-2 xl:grid-cols-4'>
                {c.audiences.map((a) => {
                  const Icon = audienceIcons[a.id];
                  return (
                    <Link
                      key={a.id}
                      to={audienceLinks[a.id]}
                      className='group flex min-w-0 flex-col overflow-hidden rounded-2xl border border-violet-200 bg-white shadow-sm transition hover:shadow-md'
                    >
                      <div className='h-32 overflow-hidden md:h-36'>
                        <img
                          src={a.image}
                          alt={a.title}
                          loading='lazy'
                          className='size-full object-cover transition group-hover:scale-105 motion-reduce:transform-none'
                          onError={(e) => {
                            e.currentTarget.onerror = null;
                            e.currentTarget.src =
                              "/images/home/mentorship-hero.webp";
                          }}
                        />
                      </div>
                      <div className='relative flex-1 px-5 pb-4 pt-3'>
                        <span className='absolute -top-6 left-3 grid size-14 place-items-center rounded-full border-2 border-white bg-violet-50 text-violet-700'>
                          <Icon size={34} />
                        </span>
                        <h3 className='mb-4 pl-12 text-lg font-extrabold tracking-tight'>
                          {a.title}
                        </h3>
                        <ul className='space-y-2 text-sm'>
                          {a.points.map((p, i) => (
                            <li key={i} className='flex items-start gap-2'>
                              <Check
                                size={20}
                                strokeWidth={3}
                                className='shrink-0 text-violet-700'
                              />
                              <span>{p}</span>
                            </li>
                          ))}
                        </ul>
                      </div>
                    </Link>
                  );
                })}
              </div>
            </section>
            <section className='overflow-hidden bg-gradient-to-r from-violet-900 via-[#351361] to-violet-700 text-white'>
              <div className='mx-auto flex max-w-[1440px] flex-col items-center gap-5 px-6 py-6 text-center md:flex-row md:text-left'>
                <img
                  src='/images/onboarding/graduation-books.webp'
                  alt='Illustrative learning books and graduation cap'
                  className='h-28 w-44 object-contain mix-blend-screen md:w-60'
                />
                <div className='flex-1 md:border-l md:border-white/70 md:pl-7'>
                  <h2 className='text-3xl font-extrabold tracking-tight'>
                    Ready to Get Started?
                  </h2>
                  <p className='mt-2 max-w-lg text-sm md:text-base'>
                    Join a growing community of learners, mentors, schools and
                    partners driving change through learning.
                  </p>
                </div>
                <Link
                  to={startTo}
                  className='inline-flex shrink-0 items-center gap-4 rounded-xl bg-white px-7 py-4 text-lg font-extrabold text-violet-800 shadow-sm hover:bg-violet-50'
                >
                  {user
                    ? "Go to My Dashboard"
                    : platform.registration_enabled
                      ? "Create a Free Account"
                      : "Contact Our Team"}
                  <ArrowRight size={24} />
                </Link>
              </div>
            </section>
            {canManage && (
              <div className='mx-auto flex max-w-[1440px] justify-end px-5 py-4'>
                <button
                  onClick={() => setEdit(true)}
                  className='inline-flex items-center gap-2 rounded-lg border border-violet-200 px-4 py-2 text-sm font-bold text-violet-700'
                >
                  <Settings size={18} />
                  Manage How It Works
                </button>
              </div>
            )}
            <VideoDialog
              open={watch}
              onOpenChange={setWatch}
              title='How It Works overview'
            >
              {c.overview_video_url && (
                <PlatformVideo
                  src={c.overview_video_url}
                  title='How It Works overview'
                  force
                />
              )}
            </VideoDialog>
            {canManage && (
              <HowItWorksEditor open={edit} onClose={() => setEdit(false)} />
            )}
          </>
        )
      )}
    </MainLayout>
  );
}
function HowSkeleton() {
  return (
    <div
      role='status'
      aria-busy='true'
      className='mx-auto max-w-[1440px] space-y-8 p-5'
    >
      <span className='sr-only'>Loading How It Works</span>
      <Skeleton className='h-80 w-full rounded-2xl' />
      <Skeleton className='mx-auto h-8 w-2/3' />
      <div className='grid gap-6 sm:grid-cols-2 xl:grid-cols-4'>
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className='h-60 rounded-2xl' />
        ))}
      </div>
      <Skeleton className='mx-auto h-8 w-2/3' />
      <div className='grid gap-4 sm:grid-cols-2 xl:grid-cols-4'>
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className='h-64 rounded-2xl' />
        ))}
      </div>
    </div>
  );
}
