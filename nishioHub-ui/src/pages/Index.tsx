import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  BarChart3,
  BookOpen,
  BriefcaseBusiness,
  CalendarDays,
  CheckCircle2,
  Circle,
  GraduationCap,
  LockKeyhole,
  Rocket,
  School,
  Search,
  ShieldCheck,
  Target,
  Trophy,
  UserPlus,
  Users,
} from "lucide-react";
import {MainLayout} from "@/components/layout/main-layout";
import { HomeAction } from "@/components/layout/home-action";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { getPublicHome } from "@/lib/public-home-api";
import { getMyGoals } from "@/lib/goals-api";
import { useAuth } from "@/lib/auth-context";
import { assetUrl, platformDate, usePlatform } from "@/lib/platform-context";
import { hasRole, isPlatformAdmin } from "@/lib/utils";
const journeys = [
  {
    id: "primary",
    title: "Primary School",
    description:
      "Build confidence, good habits and big dreams with caring, age-appropriate mentors.",
    tag: "With School & Parent Support",
    Icon: GraduationCap,
  },
  {
    id: "secondary",
    title: "Secondary School",
    description:
      "Get academic support, career exposure and life skills for the future.",
    tag: "Explore • Learn • Plan",
    Icon: BookOpen,
  },
  {
    id: "university",
    title: "University & College",
    description:
      "Gain career guidance, industry exposure and practical skills.",
    tag: "Skills • Internships • Opportunities",
    Icon: GraduationCap,
  },
  {
    id: "career",
    title: "Early Career",
    description:
      "Get workplace guidance, mentorship and support to grow in your first jobs.",
    tag: "Transition • Grow • Lead",
    Icon: BriefcaseBusiness,
  },
  {
    id: "professionals",
    title: "Professionals & Founders",
    description:
      "Learn from experienced leaders, scale your career or business and give back as a mentor.",
    tag: "Lead • Innovate • Mentor Others",
    Icon: Rocket,
  },
];
function SectionHeading({
  eyebrow,
  children,
  description,
}: {
  eyebrow: string;
  children: React.ReactNode;
  description?: string;
}) {
  return (
    <header className='mb-5 text-center'>
      <p className='mb-1 flex items-center justify-center gap-4 text-[11px] font-extrabold uppercase tracking-wider text-violet-800'>
        <span className='h-px w-12 bg-violet-600' />
        {eyebrow}
        <span className='h-px w-12 bg-violet-600' />
      </p>
      <h2 className='text-2xl font-extrabold tracking-tight md:text-3xl'>
        {children}
      </h2>
      {description && <p className='mt-1 text-xs md:text-sm'>{description}</p>}
    </header>
  );
}
export default function HomePage() {
  const platform = usePlatform();
  const { user } = useAuth();
  const home = useQuery({
    queryKey: ["public-home"],
    queryFn: getPublicHome,
    staleTime: 30000,
    refetchInterval: 60000,
  });
  const personal = !!user && hasRole(user, "mentee");
  const goals = useQuery({
    queryKey: ["homepage-goals", user?.id],
    queryFn: getMyGoals,
    enabled: personal,
  });
  const account = isPlatformAdmin(user)
    ? "/admin"
    : hasRole(user, "mentor")
      ? "/dashboard"
      : personal
        ? "/mentee/dashboard"
        : "/profile";
  const start = user
    ? account
    : platform.registration_enabled
      ? "/register?role=mentee"
      : "/contact";
  const mentorStart = "/become-a-mentor";
  const actual = goals.data?.goals;
  const percentage = actual?.length
    ? Math.round(
        actual.reduce((total, g) => total + g.progress, 0) / actual.length,
      )
    : 0;
  const features = [
    {
      title: "1-on-1 & Group Mentorship",
      text: "Get personalized guidance from trusted mentors.",
      Icon: Users,
      to: "/services",
      gold: false,
    },
    {
      title: "Goal Tracking",
      text: "Set goals, track progress and stay accountable.",
      Icon: Target,
      to: personal ? "/my-goals" : start,
      gold: true,
    },
    {
      title: "Learning Resources",
      text: "Access articles, guides, courses and career tools.",
      Icon: BookOpen,
      to: "/learn",
      gold: false,
    },
    {
      title: "Events & Webinars",
      text: "Join talks, workshops and mentoring sessions.",
      Icon: CalendarDays,
      to: "/community-events",
      gold: false,
    },
    {
      title: "Achievements",
      text: "Earn badges, certificates and showcase your growth.",
      Icon: Trophy,
      to: personal ? "/my-achievements" : start,
      gold: true,
    },
  ];
  return (
    <MainLayout>
      <Helmet>
        <title>
          {platform.platform_name} — Guidance for every stage of your journey
        </title>
        <meta
          name='description'
          content='Find mentors, explore learning opportunities and build your future with NishioHub—from primary school to professional leadership.'
        />
      </Helmet>
      <section
        aria-labelledby='home-title'
        className='relative overflow-hidden bg-[#f3efff]'
      >
        <div className='relative mx-auto max-w-[1440px] lg:min-h-[350px] xl:min-h-[440px]'>
          <img
            src='/images/home/mentorship-hero.webp'
            alt='A mentor helping two young learners collaborate with technology in a library'
            fetchPriority='high'
            className='h-72 w-full object-cover object-center lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[64%] lg:object-top'
          />
          <div className='pointer-events-none absolute inset-0 hidden bg-[linear-gradient(90deg,#f4efff_0%,#f4efff_34%,rgba(244,239,255,0.97)_38%,transparent_47%)] lg:block' />
          <div className='relative z-10 px-6 pb-7 pt-6 lg:w-[48%] lg:px-10 lg:py-6 xl:py-8'>
            <p className='mb-3 inline-block rounded-full bg-violet-200/80 px-4 py-1 text-[10px] font-semibold text-violet-950'>
              Mentorship <span className='px-1 text-violet-600'>•</span>{" "}
              Learning <span className='px-1 text-violet-600'>•</span> Career{" "}
              <span className='px-1 text-violet-600'>•</span> Leadership
            </p>
            <h1
              id='home-title'
              className='text-[36px] font-extrabold leading-[1.05] tracking-[-1.5px] xl:text-[49px]'
            >
              Guidance for every
              <br className='hidden xl:block' /> stage of{" "}
              <span className='text-violet-700'>your journey.</span>
            </h1>
            <p className='mt-3 max-w-lg text-base leading-[1.2] xl:text-lg'>
              From the first classroom dream to your next career milestone—grow
              with mentors who believe in your potential.
            </p>
            <div className='mt-4 flex flex-wrap gap-3'>
              <HomeAction to='/services'>
                <Search size={19} />
                Find a Mentor <ArrowRight size={17} />
              </HomeAction>
              <HomeAction to={mentorStart} outline>
                <Users size={20} />
                Become a Mentor
              </HomeAction>
            </div>
            <Link
              className='mt-3 inline-flex items-center gap-2 border-b border-violet-200 pb-1 text-sm font-bold text-violet-800'
              to='/#schools'
            >
              <School size={19} />
              For Schools &amp; Organizations <ArrowRight size={17} />
            </Link>
            <div className='mt-5 grid grid-cols-2 gap-3 text-[9px] leading-tight lg:grid-cols-4'>
              {[
                {
                  Icon: ShieldCheck,
                  title: "Safe & Inclusive",
                  detail: "for All Learners",
                },
                {
                  Icon: Users,
                  title: "Guardian & School",
                  detail: "Involvement (Minors)",
                },
                { Icon: LockKeyhole, title: "Verified", detail: "Mentors" },
                {
                  Icon: BarChart3,
                  title: "Skills, Career",
                  detail: "& Life Growth",
                },
              ].map((t) => (
                <div key={t.title} className='flex items-center gap-2'>
                  <t.Icon className='shrink-0 text-violet-800' size={23} />
                  <span>
                    {t.title}
                    <br />
                    {t.detail}
                  </span>
                </div>
              ))}
            </div>
          </div>
          <aside
            aria-label={personal ? "Your goals" : "Example learning goals"}
            className='absolute right-4 top-4 z-20 w-40 rounded-2xl border border-violet-100 bg-white/95 p-3 shadow-md lg:right-8 lg:top-7 lg:w-48'
          >
            <h2 className='mb-2 flex items-center gap-2 text-xs font-bold'>
              <Target size={16} className='text-violet-700' />
              My Goals
            </h2>
            {personal ? (
              goals.isPending ? (
                <p className='text-[10px]' role='status'>
                  Loading your goals…
                </p>
              ) : goals.isError ? (
                <Link
                  to='/my-goals'
                  className='text-[10px] text-violet-700 underline'
                >
                  Open My Goals
                </Link>
              ) : actual?.length ? (
                actual.slice(0, 3).map((goal) => (
                  <Link
                    to='/my-goals'
                    key={goal.id}
                    className='mb-1 flex items-start gap-2 text-[10px]'
                  >
                    {goal.completed ? (
                      <CheckCircle2
                        size={14}
                        className='shrink-0 text-green-600'
                      />
                    ) : (
                      <Circle size={14} className='shrink-0 text-violet-400' />
                    )}
                    <span className='line-clamp-2'>{goal.title}</span>
                  </Link>
                ))
              ) : (
                <Link to='/my-goals' className='text-[10px] text-violet-700'>
                  Set your first learning goal{" "}
                  <ArrowRight size={11} className='inline' />
                </Link>
              )
            ) : (
              [
                "Improve my grades",
                "Build digital skills",
                "Get career guidance",
              ].map((title, i) => (
                <p
                  key={title}
                  className='mb-1 flex items-center gap-2 text-[10px]'
                >
                  {i === 0 ? (
                    <CheckCircle2 size={14} className='text-green-600' />
                  ) : (
                    <Circle size={14} className='text-violet-400' />
                  )}
                  {title}
                </p>
              ))
            )}
          </aside>
          <div className='absolute left-4 top-52 z-20 w-44 rounded-xl border border-violet-100 bg-white/95 p-3 shadow-md lg:bottom-5 lg:left-[55%] lg:top-auto'>
            <p className='flex items-center gap-2 text-xs font-bold'>
              <BarChart3 size={18} className='text-violet-700' />
              My Progress
            </p>
            <p className='mt-1 text-right text-[10px] font-bold'>
              {personal ? (goals.data ? `${percentage}%` : "—") : "60%"}
            </p>
            <div
              className='mt-1 h-2 overflow-hidden rounded-full bg-violet-200'
              aria-hidden='true'
            >
              <div
                className='h-full rounded-full bg-gradient-to-r from-violet-500 to-violet-800'
                style={{
                  width: `${personal ? (goals.data ? percentage : 0) : 60}%`,
                }}
              />
            </div>
          </div>
        </div>
      </section>
      <div className='mx-auto max-w-[1440px] px-5 py-7 lg:px-8'>
        <section className='scroll-mt-24' id='journeys'>
          <SectionHeading
            eyebrow='Our Focus'
            description='Structured, age-appropriate mentorship that grows with you—from primary school to professional leadership.'
          >
            Mentorship for{" "}
            <span className='text-violet-700'>every chapter</span>
          </SectionHeading>
          <div className='grid gap-3 sm:grid-cols-2 lg:grid-cols-5'>
            {journeys.map((j, i) => (
              <article
                key={j.id}
                id={j.id}
                className='scroll-mt-28 flex flex-col overflow-hidden rounded-2xl border border-violet-100 bg-violet-50'
              >
                <div
                  role='img'
                  aria-label={`Illustrative portrait for ${j.title}`}
                  className='h-44 bg-cover xl:h-72'
                  style={{
                    backgroundImage:
                      "url(/images/home/journey-portraits-v2.webp)",
                    backgroundSize: "500% auto",
                    backgroundPosition: `${i * 25}% 47%`,
                  }}
                />
                <div className='relative -mt-12 flex min-h-[144px] flex-1 flex-col rounded-t-[28px] bg-gradient-to-br from-white/95 to-violet-100 p-3 xl:p-4'>
                  <span className='absolute -top-6 left-3 grid size-11 place-items-center rounded-full border-2 border-violet-200 bg-white text-violet-800'>
                    <j.Icon size={27} />
                  </span>
                  <h3 className='mt-1 text-[13px] font-extrabold tracking-tight xl:text-sm'>
                    {j.title}
                  </h3>
                  <p className='mb-2 mt-2 min-h-[60px] text-xs leading-snug'>
                    {j.description}
                  </p>
                  <p className='mt-auto rounded-full bg-violet-200/90 px-2 py-1 text-center text-[9px] font-medium text-violet-950'>
                    {j.tag}
                  </p>
                </div>
              </article>
            ))}
          </div>
        </section>
        <section className='mt-6' id='how-it-works'>
          <SectionHeading
            eyebrow='How It Works'
            description='A simple and effective way to get the guidance, skills and support you need.'
          >
            How {platform.platform_name} works
          </SectionHeading>
          <div className='flex flex-col gap-3 md:flex-row'>
            {[
              {
                title: "1. Discover",
                description:
                  "Create your profile and tell us about your goals, interests and stage.",
                Icon: UserPlus,
                to: start,
              },
              {
                title: "2. Connect",
                description:
                  "Find and connect with the right mentors, programs and community.",
                Icon: Users,
                to: "/services",
              },
              {
                title: "3. Grow",
                description:
                  "Learn, get guidance, track your goals and achieve real progress.",
                Icon: BarChart3,
                to: personal ? "/my-goals" : "/learn",
              },
            ].map((step, i) => (
              <div key={step.title} className='contents'>
                <Link
                  className='flex flex-1 items-center gap-4 rounded-2xl border border-violet-200 bg-white/70 px-5 py-3 transition hover:border-violet-500 hover:shadow-md'
                  to={step.to}
                >
                  <span className='grid size-14 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-violet-400 to-violet-800 text-white'>
                    <step.Icon size={32} />
                  </span>
                  <div>
                    <h3 className='text-base font-extrabold'>{step.title}</h3>
                    <p className='text-[11px] leading-snug'>
                      {step.description}
                    </p>
                  </div>
                </Link>
                {i < 2 && (
                  <ArrowRight
                    size={25}
                    className='hidden shrink-0 self-center text-violet-800 md:block'
                  />
                )}
              </div>
            ))}
          </div>
        </section>
        <section className='mt-6'>
          <SectionHeading eyebrow='Platform Features'>
            Everything you need to learn, grow and succeed
          </SectionHeading>
          <div className='grid gap-3 sm:grid-cols-2 lg:grid-cols-5'>
            {features.map((f) => (
              <Link
                key={f.title}
                to={f.to}
                className='flex items-start gap-3 rounded-xl border border-violet-200 bg-gradient-to-br from-white to-violet-50 p-3 transition hover:-translate-y-1 hover:shadow-md'
              >
                <span
                  className={`grid size-12 shrink-0 place-items-center rounded-full ${f.gold ? "bg-gradient-to-br from-yellow-100 to-amber-400 text-amber-700" : "bg-gradient-to-br from-violet-400 to-violet-800 text-white"}`}
                >
                  <f.Icon size={27} />
                </span>
                <div>
                  <h3 className='text-xs font-extrabold leading-tight'>
                    {f.title}
                  </h3>
                  <p className='mt-1 text-[10px] leading-snug'>{f.text}</p>
                </div>
              </Link>
            ))}
          </div>
        </section>
        <section className='mt-5 rounded-2xl bg-white/80 p-4' id='mentors'>
          <header className='mb-3 flex flex-wrap items-start justify-between gap-4'>
            <div className='min-w-0 flex-1 basis-64'>
              <h2 className='text-2xl font-extrabold tracking-tight'>
                Meet our Mentors
              </h2>
              <p className='max-w-lg text-xs leading-snug'>
                Learn from experienced professionals, educators and
                entrepreneurs
                <br className='hidden md:block' /> who are passionate about
                mentoring the next generation.
              </p>
            </div>
            <Link
              to='/services'
              className='inline-flex shrink-0 items-center gap-1 text-xs font-bold text-violet-700'
            >
              View All Mentors <ArrowRight size={16} />
            </Link>
          </header>
          {home.isPending ? (
            <p role='status' className='py-8 text-center text-sm'>
              Loading mentors…
            </p>
          ) : home.isError ? (
            <div className='flex flex-wrap items-center justify-center gap-3 py-6 text-sm'>
              <p>Mentor profiles could not be loaded.</p>
              <button
                className='font-bold text-violet-700 underline'
                onClick={() => home.refetch()}
              >
                Try Again
              </button>
            </div>
          ) : home.data.mentors.length ? (
            <div className='grid gap-3 sm:grid-cols-2 lg:grid-cols-4'>
              {home.data.mentors.map((mentor) => (
                <Link
                  to={`/mentors/${mentor.id}`}
                  key={mentor.id}
                  className='flex items-center gap-3 rounded-xl border border-violet-200 bg-violet-50/60 p-3 hover:border-violet-500'
                >
                  <div className='relative'>
                    <Avatar className='size-16 border-2 border-white'>
                      <AvatarImage
                        alt={mentor.name}
                        src={
                          mentor.avatar?.startsWith("/images/")
                            ? mentor.avatar
                            : assetUrl(mentor.avatar)
                        }
                      />
                      <AvatarFallback className='bg-violet-200 text-lg text-violet-900'>
                        {mentor.name
                          .split(" ")
                          .map((p) => p[0])
                          .slice(0, 2)
                          .join("")}
                      </AvatarFallback>
                    </Avatar>
                    <CheckCircle2
                      className='absolute bottom-0 right-0 rounded-full bg-white text-green-600'
                      size={17}
                      aria-label='Verified mentor'
                    />
                  </div>
                  <div className='min-w-0'>
                    <h3 className='truncate text-sm font-extrabold'>
                      {mentor.name}
                    </h3>
                    <p className='mt-1 line-clamp-2 text-[10px]'>
                      {mentor.title}
                    </p>
                    <span className='mt-1 inline-block rounded-full bg-violet-200 px-3 py-0.5 text-[10px] text-violet-900'>
                      Mentor
                    </span>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <p className='py-7 text-center text-sm'>
              Mentor profiles will appear here as verified mentors join.{" "}
              <Link
                to={mentorStart}
                className='font-bold text-violet-700 underline'
              >
                Become a mentor
              </Link>
            </p>
          )}
        </section>
        {platform.public_events_enabled && !!home.data?.events.length && (
          <section className='mt-5 rounded-2xl border border-violet-100 bg-white p-4'>
            <header className='mb-3 flex items-center justify-between'>
              <h2 className='text-xl font-extrabold'>Upcoming Events</h2>
              <Link
                to='/community-events'
                className='text-xs font-bold text-violet-700'
              >
                View All Events →
              </Link>
            </header>
            <div className='grid gap-3 md:grid-cols-3'>
              {home.data.events.map((event) => (
                <Link
                  key={event.id}
                  to={`/community-events?event=${event.id}`}
                  className='rounded-xl border border-violet-100 p-3 hover:border-violet-500'
                >
                  <p className='text-sm font-bold'>{event.title}</p>
                  <p className='mt-2 text-xs'>
                    {platformDate(event.starts_at!, platform, true)} ·{" "}
                    {event.location}
                  </p>
                </Link>
              ))}
            </div>
          </section>
        )}
      </div>
      <section
        id='schools'
        className='scroll-mt-24 overflow-hidden bg-white'
      >
        <div className='mx-auto grid max-w-[1440px] items-center gap-6 lg:grid-cols-[.9fr_1.1fr]'>
          <img
            src='/images/home/mentorship-hero.webp'
            alt='Mentor and learners collaborating in a school library'
            loading='lazy'
            className='h-56 w-full border-r-[12px] border-amber-400 object-cover object-center lg:h-80'
          />
          <div className='flex flex-wrap items-center gap-5 px-6 py-6 lg:pr-10'>
            <div className='min-w-0 basis-full flex-1 sm:basis-[280px]'>
              <h2 className='flex items-center gap-3 text-xl font-extrabold tracking-tight md:text-2xl'>
                <School size={35} className='shrink-0 text-violet-700' />
                For Schools &amp; Organizations
              </h2>
              <p className='mt-2 max-w-lg text-xs'>
                Partner with {platform.platform_name} to provide structured,
                safe and impactful mentorship for your learners, students or
                team.
              </p>
              <ul className='mt-3 space-y-1 text-xs'>
                {[
                  "School and organization partnerships",
                  "Discuss guardian and school involvement",
                  "Mentor guidance and program opportunities",
                  "Support for learner engagement and progress",
                ].map((t) => (
                  <li key={t} className='flex items-center gap-2'>
                    <CheckCircle2 size={15} className='text-green-600' />
                    {t}
                  </li>
                ))}
              </ul>
            </div>
            <HomeAction to='/partner-with-us' outline>
              Partner With Us <ArrowRight size={18} />
            </HomeAction>
          </div>
        </div>
      </section>
      <section className='relative overflow-hidden bg-gradient-to-r from-[#502080] via-violet-700 to-[#6022a1] px-6 py-5 text-white'>
        <span
          aria-hidden='true'
          className='absolute -bottom-24 -left-10 size-40 rounded-full border-[25px] border-amber-300/45'
        />
        <div className='relative mx-auto flex max-w-[1120px] flex-wrap items-center justify-center gap-5 md:justify-between py-10'>
          <div className='text-center'>
            <h2 className='text-2xl font-extrabold tracking-tight md:text-3xl'>
              Ready to <span className='text-yellow-200'>grow</span> with a
              mentor?
            </h2>
            <p className='mt-1 text-xs'>
              Join {platform.platform_name} today and take the next step in your
              learning, career and life journey.
            </p>
          </div>
          <HomeAction
            to={start}
            className='!border-yellow-200 !bg-gradient-to-b !from-yellow-100 !to-amber-300 !text-violet-950'
          >
            <UserPlus size={18} />
            {user
              ? "Go to My Account"
              : platform.registration_enabled
                ? "Get Started Free"
                : "Contact Our Team"}{" "}
            <ArrowRight size={20} />
          </HomeAction>
        </div>
      </section>
    </MainLayout>
  );
}
