import { useDeferredValue, useRef, useState } from "react";
import { Link, Navigate, useNavigate, useSearchParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  BarChart3,
  BookOpen,
  BriefcaseBusiness,
  CalendarDays,
  Globe2,
  GraduationCap,
  Grid2X2,
  Layers,
  Leaf,
  Lightbulb,
  Monitor,
  Rocket,
  Search,
  ShieldCheck,
  Target,
  Users,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { VideoDialog } from "@/components/media/platform-video";
import { ProgramCardSkeleton } from "@/components/loaders/ProgramCardSkeleton";
import { operationError } from "@/components/admin/dashboard-operations";
import {
  getPublicPrograms,
  programStages,
  programThemes,
  type PublicProgram,
} from "@/lib/public-programs-api";
import { assetUrl, platformDate, usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { hasRole, isPlatformAdmin } from "@/lib/utils";

const outline =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-violet-600 bg-white px-4 py-2 text-sm font-bold text-violet-700 hover:bg-violet-50 focus-visible:outline-violet-600 disabled:opacity-40";
const stageIcons = [Users, BookOpen, GraduationCap, BriefcaseBusiness, Users];
const themeIcons = [
  Target,
  BookOpen,
  Monitor,
  Lightbulb,
  Users,
  Leaf,
  BarChart3,
  Rocket,
];
const subtitles = [
  "(P.1 – P.7)",
  "(S.1 – S.6)",
  "",
  "(Graduates & Job Seekers)",
  "(Working Class)",
];
function ProgramArt({
  program,
  className,
}: {
  program: PublicProgram;
  className: string;
}) {
  const [failed, setFailed] = useState(false);
  const stage = Object.keys(programStages).indexOf(program.audience_stages[0]);
  if (program.image && !failed)
    return (
      <img
        src={assetUrl(program.image)}
        alt={`${program.title} banner`}
        loading='lazy'
        onError={() => setFailed(true)}
        className={`${className} object-cover`}
      />
    );
  if (stage >= 0)
    return (
      <div
        role='img'
        aria-label={`Illustrative ${programStages[program.audience_stages[0] as keyof typeof programStages]} portrait`}
        className={className}
        style={{
          backgroundImage: "url(/images/home/journey-portraits-v2.webp)",
          backgroundSize: "500% auto",
          backgroundPosition: `${stage * 25}% 47%`,
        }}
      />
    );
  return (
    <img
      src='/images/programs/programs-stages-hero.webp'
      alt='Illustrative learners at different stages of their journey'
      loading='lazy'
      className={`${className} object-cover`}
    />
  );
}
export default function PublicPrograms() {
  const platform = usePlatform();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [videoOpen, setVideoOpen] = useState(false);
  const [params, setParams] = useSearchParams();
  const catalog = useRef<HTMLElement>(null);
  const searchField = useRef<HTMLInputElement>(null);
  const stage = params.get("stage") || "";
  const theme = params.get("theme") || "";
  const search = params.get("q") || "";
  const q = useDeferredValue(search);
  const page = /^[1-9]\d{0,3}$/.test(params.get("page") || "")
    ? Number(params.get("page"))
    : 1;
  const all = params.get("view") === "all";
  const selected = params.get("program") || "";
  const programs = useQuery({
    queryKey: ["public-programs", stage, theme, q, page, all],
    queryFn: () =>
      getPublicPrograms({
        stage,
        theme,
        q,
        page,
        featured: false,
        per_page: all ? 8 : 4,
      }),
    staleTime: 30000,
    refetchInterval: 60000,
  });
  const start = user
    ? isPlatformAdmin(user)
      ? "/admin"
      : hasRole(user, "mentee")
        ? "/mentee/dashboard"
        : hasRole(user, "mentor")
          ? "/dashboard"
          : "/profile"
    : platform.registration_enabled
      ? "/register?role=mentee"
      : "/contact";
  function update(values: Record<string, string>, resetPage = true) {
    const next = new URLSearchParams(params);
    if (resetPage) next.delete("page");
    Object.entries(values).forEach(([key, value]) =>
      value ? next.set(key, value) : next.delete(key),
    );
    setParams(next, { replace: true, preventScrollReset: true });
  }
  function explore() {
    catalog.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function reset() {
    setParams({}, { replace: true, preventScrollReset: true });
  }
  const date = (value: string) => platformDate(`${value}T12:00:00Z`, platform);
  if (selected) return <Navigate to={`/programs/${encodeURIComponent(selected)}`} replace/>;
  return (
    <MainLayout>
      <Helmet>
        <title>Programs for Every Stage | {platform.platform_name}</title>
        <meta
          name='description'
          content='Explore NishioHub mentorship programs for primary school, secondary school, university, early career and professional leadership.'
        />
      </Helmet>
      <section className='overflow-hidden bg-[#25134f] text-white'>
        <div className='relative mx-auto max-w-[1440px] lg:min-h-[310px]'>
          <img
            src='/images/programs/programs-stages-hero.webp'
            alt='A primary learner, secondary student, graduate and professional representing stages of growth'
            fetchPriority='high'
            className='h-56 w-full object-cover object-top lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[64%]'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[48%] bg-yellow-400 lg:block'
            style={{ clipPath: "polygon(0 0, 100% 0, 72% 100%, 0 100%)" }}
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[46%] bg-gradient-to-r from-[#241347] to-violet-800 lg:block'
            style={{ clipPath: "polygon(0 0, 100% 0, 73% 100%, 0 100%)" }}
          />
          <div className='relative px-6 py-6 lg:w-[44%] lg:px-10'>
            <p className='mb-3 inline-flex items-center gap-2 rounded-full bg-violet-500/50 px-3 py-1 text-xs font-bold'>
              <Users size={16} />
              Our Programs
            </p>
            <h1 className='text-3xl font-extrabold leading-[1.08] tracking-tight xl:text-[40px]'>
              Mentorship Programs
              <br />
              for <span className='text-yellow-300'>Every Stage</span>
            </h1>
            <p className='mt-3 max-w-sm text-base leading-snug'>
              Structured, age-appropriate programs that provide guidance,
              skills, and real opportunities from primary school to the working
              world.
            </p>
            <div className='mt-5 flex flex-wrap gap-3'>
              <button
                type='button'
                onClick={explore}
                className='inline-flex items-center gap-3 rounded-lg border border-violet-300 bg-gradient-to-b from-violet-500 to-violet-800 px-4 py-2.5 text-sm font-bold hover:brightness-110'
              >
                Explore Programs <ArrowRight size={17} />
              </button>
              <button
                type='button'
                onClick={() => setVideoOpen(true)}
                className='inline-flex items-center rounded-lg border border-white/60 px-4 py-2.5 text-sm font-bold hover:bg-white/10'
              >
                Watch Video
              </button>
              <VideoDialog
                open={videoOpen}
                onOpenChange={setVideoOpen}
                title='Mentorship Programs'
              >
                <video
                  className='w-full'
                  controls
                  src='/images/programs/project.mp4'
                >
                  Your browser does not support video playback.
                </video>
              </VideoDialog>
            </div>
          </div>
        </div>
      </section>
      <section
        aria-label='Program benefits'
        className='border-b border-violet-100 bg-gradient-to-r from-violet-50 to-white'
      >
        <div className='mx-auto grid max-w-[1400px] gap-4 px-6 py-4 sm:grid-cols-2 lg:grid-cols-5'>
          {[
            {
              Icon: Users,
              title: "Multi-Stage Programs",
              text: "Primary to Professionals",
            },
            {
              Icon: GraduationCap,
              title: "Expert Mentors",
              text: "Verified & Experienced",
            },
            {
              Icon: Layers,
              title: "Practical Learning",
              text: "Skills, Projects & Guidance",
            },
            {
              Icon: ShieldCheck,
              title: "Safe & Inclusive",
              text: "For All Learners",
            },
            {
              Icon: Globe2,
              title: "Open to Individuals,",
              text: "Schools & Organizations",
            },
          ].map(({ Icon, title, text }, i) => (
            <div
              key={title}
              className={`flex items-center gap-3 px-3 ${i ? "lg:border-l lg:border-violet-300" : ""}`}
            >
              <Icon size={34} className='shrink-0 text-violet-700' />
              <div>
                <h2 className='text-xs font-extrabold'>{title}</h2>
                <p className='text-xs'>{text}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
      <div className='mx-auto max-w-[1440px] px-5 pb-7 pt-6 lg:px-8'>
        <section ref={catalog} id='explore-programs' className='scroll-mt-24'>
          <header className='text-center'>
            <h2 className='flex items-center justify-center gap-4 text-2xl font-extrabold tracking-tight'>
              <span aria-hidden='true' className='h-0.5 w-10 bg-violet-600' />
              Explore Our Programs
            </h2>
            <p className='mt-2 text-sm'>
              Choose a program that matches your current stage, goals or area of
              interest.
            </p>
          </header>
          <div
            role='group'
            aria-label='Filter programs by stage'
            className='mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6'
          >
            {[["", "All Programs"], ...Object.entries(programStages)].map(
              ([key, label], i) => {
                const Icon = i === 0 ? Grid2X2 : stageIcons[i - 1];
                return (
                  <button
                    type='button'
                    key={key}
                    aria-pressed={stage === key}
                    onClick={() => update({ stage: key })}
                    className={`flex min-h-24 flex-col items-center justify-center rounded-xl border px-2 py-3 text-center transition ${stage === key ? "border-violet-600 bg-gradient-to-b from-violet-500 to-violet-800 text-white shadow-md" : "border-violet-200 bg-gradient-to-br from-white to-violet-50 hover:border-violet-500"}`}
                  >
                    <Icon
                      size={32}
                      className={`mb-2 ${stage === key ? "" : "text-violet-700"}`}
                    />
                    <span className='text-sm font-extrabold leading-tight'>
                      {label}
                    </span>
                    {i > 0 && subtitles[i - 1] && (
                      <span className='mt-1 text-xs'>{subtitles[i - 1]}</span>
                    )}
                  </button>
                );
              },
            )}
          </div>
          <header className='mb-4 mt-6 flex flex-wrap items-center justify-between gap-3'>
            <h2 className='text-2xl font-extrabold tracking-tight'>
              {all
                ? "All Programs"
                : stage
                  ? programStages[stage as keyof typeof programStages] ||
                    "Programs"
                  : programs.data?.items.length &&
                      programs.data.items.every((item) => item.featured)
                    ? "Featured Programs"
                    : "Programs for Every Stage"}
            </h2>
            <button
              type='button'
              onClick={() => {
                update({ view: "all", stage: "", theme: "", q: "" });
                explore();
              }}
              className='inline-flex items-center gap-3 text-sm font-bold text-violet-700 hover:underline'
            >
              View All Programs <ArrowRight size={18} />
            </button>
          </header>
          <div className='mb-4 flex flex-wrap items-center gap-3'>
            <label className='relative min-w-0 flex-1'>
              <Search
                size={17}
                className='absolute left-3 top-2.5 text-violet-700'
              />
              <input
                ref={searchField}
                aria-label='Search programs'
                value={search}
                onChange={(e) => update({ q: e.target.value })}
                placeholder='Search programs by title, description or audience…'
                maxLength={150}
                className='h-9 w-full rounded-lg border border-violet-200 bg-white pl-9 pr-3 text-sm focus:outline-violet-600'
              />
            </label>
            {(stage || theme || search || all) && (
              <button
                type='button'
                className='text-xs font-bold text-violet-700 underline'
                onClick={reset}
              >
                Clear Filters
              </button>
            )}
          </div>
          {programs.isPending ? (
            <div role='status' aria-busy='true'>
              <span className='sr-only'>Loading programs</span>
              <div className='grid gap-4 sm:grid-cols-2 lg:grid-cols-4'>
                {[0, 1, 2, 3].map((i) => (
                  <ProgramCardSkeleton key={i} />
                ))}
              </div>
            </div>
          ) : programs.isError ? (
            <div
              role='alert'
              className='rounded-xl border border-red-100 bg-red-50 p-6 text-center'
            >
              <p className='text-sm'>{operationError(programs.error)}</p>
              <button
                type='button'
                className={`${outline} mt-3`}
                onClick={() => programs.refetch()}
              >
                Retry
              </button>
              <button
                type='button'
                className='ml-3 text-sm text-violet-700 underline'
                onClick={reset}
              >
                Reset Filters
              </button>
            </div>
          ) : (
            <>
              <div className='grid gap-4 sm:grid-cols-2 lg:grid-cols-4'>
                {programs.data.items.map((program) => (
                  <article
                    key={program.id}
                    className='flex min-w-0 flex-col overflow-hidden rounded-xl border border-violet-100 bg-white shadow-sm'
                  >
                    <div className='relative'>
                      <ProgramArt
                        key={`${program.id}-${program.image}`}
                        program={program}
                        className='h-36 w-full'
                      />
                      <span className='absolute bottom-2 left-2 max-w-[90%] truncate rounded-full bg-white/95 px-3 py-1 text-[10px] font-bold text-violet-800'>
                        {program.audience_stages.length
                          ? program.audience_stages
                              .map(
                                (s) =>
                                  programStages[
                                    s as keyof typeof programStages
                                  ],
                              )
                              .join(" · ")
                          : program.category || "Mentorship"}
                      </span>
                    </div>
                    <div className='flex flex-1 flex-col p-3'>
                      <h3 className='text-lg font-extrabold leading-tight tracking-tight'>
                        {program.title}
                      </h3>
                      <p className='mt-1 line-clamp-3 text-sm leading-snug'>
                        {program.description ||
                          "Explore mentorship, skills and growth opportunities with our community."}
                      </p>
                      <div className='mb-3 mt-auto flex flex-wrap items-start justify-between gap-2 pt-3 text-[11px]'>
                        <span className='flex items-center gap-2'>
                          <CalendarDays
                            size={16}
                            className='shrink-0 text-violet-700'
                          />
                          {program.starts_on
                            ? date(program.starts_on)
                            : "Schedule to be confirmed"}
                        </span>
                        <span className='flex items-center gap-2'>
                          <Users
                            size={16}
                            className='shrink-0 text-violet-700'
                          />
                          {program.mode === "in_person"
                            ? "In Person"
                            : program.mode === "hybrid"
                              ? "Online & In Person"
                              : "Online"}
                        </span>
                      </div>
                      <button
                        type='button'
                        className={`${outline} w-full !py-1.5 !text-xs`}
                        aria-label={`Learn more about ${program.title}`}
                        onClick={() =>
                          navigate(`/programs/${program.id}`)
                        }
                      >
                        Learn More <ArrowRight size={16} />
                      </button>
                    </div>
                  </article>
                ))}
              </div>
              {!programs.data.items.length && (
                <div
                  role='status'
                  className='rounded-xl border border-violet-100 bg-white p-8 text-center'
                >
                  <p className='text-sm'>
                    {stage || theme || search
                      ? "No programs match these filters."
                      : "Programs will appear here as they are published."}
                  </p>
                  <button
                    type='button'
                    className={`${outline} mt-4`}
                    onClick={reset}
                  >
                    Show All Programs
                  </button>
                </div>
              )}
              {programs.data.meta.total_pages > 1 && (
                <nav
                  aria-label='Program pagination'
                  className='mt-5 flex flex-wrap items-center justify-center gap-4 text-xs'
                >
                  <button
                    type='button'
                    className={outline}
                    disabled={page <= 1 || programs.isFetching}
                    onClick={() => update({ page: String(page - 1) }, false)}
                  >
                    Previous
                  </button>
                  <span aria-live='polite'>
                    Page {page} of {programs.data.meta.total_pages} ·{" "}
                    {programs.data.meta.total} programs
                  </span>
                  <button
                    type='button'
                    className={outline}
                    disabled={
                      page >= programs.data.meta.total_pages ||
                      programs.isFetching
                    }
                    onClick={() => update({ page: String(page + 1) }, false)}
                  >
                    Next
                  </button>
                </nav>
              )}
            </>
          )}
        </section>
        <section className='mt-7'>
          <h2 className='mb-4 flex items-center gap-3 text-xl font-extrabold tracking-tight'>
            <span aria-hidden='true' className='h-0.5 w-8 bg-violet-600' />
            Program Themes &amp; Focus Areas
          </h2>
          <div
            role='group'
            aria-label='Filter programs by theme'
            className='grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-8'
          >
            {Object.entries(programThemes).map(([id, label], i) => {
              const Icon = themeIcons[i];
              return (
                <button
                  type='button'
                  key={id}
                  aria-pressed={theme === id}
                  onClick={() => {
                    update({ theme: theme === id ? "" : id });
                    explore();
                  }}
                  className={`flex flex-col items-center justify-center gap-2 rounded-xl border px-2 py-3 text-center text-xs transition ${theme === id ? "border-violet-600 bg-violet-700 text-white" : "border-violet-100 bg-gradient-to-br from-white to-violet-50 hover:border-violet-500"}`}
                >
                  <Icon
                    size={31}
                    className={
                      theme === id
                        ? ""
                        : i === 3
                          ? "text-amber-500"
                          : i === 5
                            ? "text-green-600"
                            : "text-violet-700"
                    }
                  />
                  {label}
                </button>
              );
            })}
          </div>
        </section>
      </div>
      <section className='overflow-hidden rounded-[32px] bg-gradient-to-r from-[#2c1354] via-violet-800 to-violet-700 px-10 py-6 m-10 text-white'>
        <div className='mx-auto flex max-w-[1320px] flex-col items-start gap-6 sm:flex-row sm:flex-wrap sm:items-center'>
          <img
            src='/images/home/mentorship-hero.webp'
            alt='Illustrative mentor and learners connecting through technology'
            loading='lazy'
            className='hidden h-28 w-52 rounded-xl object-cover lg:block'
          />
          <div className='min-w-0 w-full flex-1 sm:w-auto'>
            <h2 className='text-2xl font-extrabold tracking-tight'>
              Ready to start your mentorship journey?
            </h2>
            <p className='mt-2 max-w-xl text-sm'>
              Join our community of learners, students and professionals growing
              with {platform.platform_name} programs.
            </p>
          </div>
          <Link
            to={start}
            className='inline-flex items-center gap-4 rounded-xl border border-yellow-200 bg-gradient-to-b from-yellow-200 to-amber-400 px-6 py-3 font-extrabold text-[#1d1036]'
          >
            {user
              ? "Go to My Account"
              : platform.registration_enabled
                ? "Get Started Free"
                : "Contact Our Team"}{" "}
            <ArrowRight size={21} />
          </Link>
        </div>
      </section>
    </MainLayout>
  );
}
