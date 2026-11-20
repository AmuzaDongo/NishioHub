import {PlatformVideo,VideoDialog} from '@/components/media/platform-video';
import { useState, type ReactNode } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowLeft,
  ArrowRight,
  BookOpen,
  BriefcaseBusiness,
  CalendarDays,
  CheckCircle2,
  Diamond,
  Eye,
  GraduationCap,
  Play,
  School,
  Settings,
  Target,
  Users,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Skeleton } from "@/components/ui/skeleton";
import { AboutContentEditor } from "@/components/admin/about-content-editor";
import { operationError } from "@/components/admin/dashboard-operations";
import { getPublicAbout } from "@/lib/about-api";
import { usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { isPlatformAdmin } from "@/lib/utils";

const outline =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-violet-600 bg-white px-4 py-2 text-sm font-bold text-violet-700 transition hover:bg-violet-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-600 disabled:opacity-40";
const audiences = [
  {
    title: "Primary School",
    subtitle: "(P.1 – P.7)",
    text: "Build confidence, good habits and a love for learning.",
    Icon: GraduationCap,
    to: "/partner-with-us",
  },
  {
    title: "Secondary School",
    subtitle: "(S.1 – S.6)",
    text: "Strengthen academics, explore interests and life skills.",
    Icon: BookOpen,
    to: "/programs",
  },
  {
    title: "University & College",
    subtitle: "",
    text: "Gain industry exposure, practical skills and career guidance.",
    Icon: GraduationCap,
    to: "/programs",
  },
  {
    title: "Early Career",
    subtitle: "(Graduates & Job Seekers)",
    text: "Get workplace skills, mentorship and career opportunities.",
    Icon: BriefcaseBusiness,
    to: "/services",
  },
  {
    title: "Professionals & Leaders",
    subtitle: "(Working Class)",
    text: "Grow your career, lead with impact and mentor others.",
    Icon: Users,
    to: "/become-a-mentor",
  },
];
const values = [
  ["Inclusivity", "opportunities for all."],
  ["Integrity", "trust, safety and accountability."],
  ["Growth", "continuous learning and improvement."],
  ["Collaboration", "stronger together."],
  ["Impact", "real, positive change in people’s lives."],
];
const story = [
  {
    title: "Every journey deserves guidance",
    image: "/images/home/mentorship-hero.webp",
    text: "From the first classroom dream to a new career milestone, everyone deserves guidance, skills and opportunities to unlock their full potential.",
  },
  {
    title: "Connect, learn and grow",
    image: "/images/about/mentorship-about-hero.webp",
    text: "NishioHub brings together experienced mentors, practical learning and a supportive community. Discover your interests, build useful skills and make informed choices about your future.",
  },
  {
    title: "Built for Africa, impacting beyond",
    image: "/images/partnerships/partnership-hero.webp",
    text: "We work toward inclusive opportunities for learners, schools, professionals and communities. Find a mentor, explore a program or partner with us to take the next step.",
  },
];
function Heading({ children }: { children: ReactNode }) {
  return (
    <h2 className='flex items-center gap-3 text-2xl font-extrabold tracking-tight'>
      <span
        aria-hidden='true'
        className='h-1 w-10 shrink-0 rounded bg-violet-700'
      />
      {children}
    </h2>
  );
}
function AfricaMark() {
  return (
    <svg
      aria-hidden='true'
      viewBox='0 0 180 210'
      className='absolute right-0 top-0 h-full w-full text-violet-200'
    >
      <path
        fill='currentColor'
        d='M48 8 66 4 80 10 96 10 111 19 121 38 138 53 146 71 166 68 156 86 140 102 132 120 121 129 115 153 103 170 90 194 80 193 75 173 64 156 62 138 51 118 46 104 29 100 18 89 10 75 14 56 20 46 22 32 35 24 39 14Z'
      />
      <path fill='currentColor' d='m155 137 7-8 3 12-6 23-7 6-1-12Z' />
    </svg>
  );
}
export default function AboutUsPage() {
  const platform = usePlatform();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [params, setParams] = useSearchParams();
  const [step, setStep] = useState(0);
  const [editor, setEditor] = useState(false);
  const [videoFailed, setVideoFailed] = useState(false);
  const about = useQuery({
    queryKey: ["public-about"],
    queryFn: getPublicAbout,
    staleTime: 30000,
    refetchInterval: 60000,
  });
  const view = params.get("view");
  function openView(next?: "story" | "team") {
    const changed = new URLSearchParams(params);
    if (next) changed.set("view", next);
    else changed.delete("view");
    setParams(changed, { replace: true, preventScrollReset: true });
    if (next === "story") {
      setStep(0);
      setVideoFailed(false);
    }
  }
  const canManage =
    !!user &&
    isPlatformAdmin(user) &&
    !!user.management_permissions?.includes("system.manage");
  const metrics = [
    {
      key: "learners",
      label: "Learners & Mentees",
      Icon: Users,
      to: "/programs",
    },
    {
      key: "mentors",
      label: "Verified Mentors",
      Icon: GraduationCap,
      to: "/services",
    },
    {
      key: "resources",
      label: "Learning Resources",
      Icon: BookOpen,
      to: "/learn",
    },
    {
      key: "events",
      label: "Events & Workshops",
      Icon: CalendarDays,
      to: "/community-events",
    },
    {
      key: "organizations",
      label: "School & Organization Accounts",
      Icon: School,
      to: "/partner-with-us",
    },
  ] as const;
  return (
    <MainLayout>
      <Helmet>
        <title>
          About {platform.platform_name} — Mentorship, Learning &amp;
          Opportunity
        </title>
        <meta
          name='description'
          content='Discover NishioHub’s mission, vision, values and community impact. Connecting learners and professionals with mentorship, learning and opportunity.'
        />
      </Helmet>
      <section className='overflow-hidden bg-[#25134f] text-white'>
        <div className='relative mx-auto max-w-[1440px] lg:min-h-[285px]'>
          <img
            src='/images/about/mentorship-about-hero.webp'
            alt='A mentor guiding young learners around a laptop in a school library'
            fetchPriority='high'
            className='h-56 w-full object-cover object-top lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[56%]'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[49%] bg-yellow-400 lg:block'
            style={{ clipPath: "ellipse(100% 150% at 0% 0%)" }}
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[47%] bg-gradient-to-r from-[#26134c] to-violet-800 lg:block'
            style={{ clipPath: "ellipse(100% 160% at 0% 0%)" }}
          />
          <div className='relative px-6 py-5 lg:w-[46%] lg:px-10'>
            <p className='mb-2 inline-flex items-center gap-2 rounded-full bg-violet-500/60 px-3 py-1 text-xs font-bold'>
              <Users size={16} />
              About {platform.platform_name}
            </p>
            <h1 className='text-3xl font-extrabold leading-[1.08] tracking-tight sm:text-4xl lg:text-[36px] xl:text-[38px]'>
              Empowering People
              <br className='hidden xl:block' /> Through Mentorship,
              <br className='hidden xl:block' /> Learning and{" "}
              <span className='text-yellow-300'>Opportunity</span>
            </h1>
            <p className='mt-3 max-w-lg text-sm leading-snug xl:text-base'>
              A safe, inclusive platform that connects learners, students, young
              professionals and leaders with experienced mentors, practical
              learning and real-world opportunities.
            </p>
          </div>
        </div>
      </section>
      <div className='mx-auto max-w-[1440px] px-5 pb-5 lg:px-6'>
        <section
          aria-label='Our mission, vision and values'
          className='grid gap-4 pt-2 md:grid-cols-3'
        >
          {[
            {
              title: "Our Mission",
              Icon: Target,
              text: "To provide accessible, safe and impactful mentorship, learning and career development opportunities for people at every stage of life.",
            },
            {
              title: "Our Vision",
              Icon: Eye,
              text: "A generation of confident, skilled and purpose-driven learners, professionals and leaders transforming communities across Africa and beyond.",
            },
            { title: "Our Values", Icon: Diamond, text: "" },
          ].map(({ title, Icon, text }) => (
            <article
              key={title}
              className='flex items-start gap-4 rounded-2xl border border-violet-100 bg-gradient-to-br from-white to-violet-50 p-5'
            >
              <span className='grid size-14 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-violet-500 to-violet-800 text-white'>
                <Icon size={34} />
              </span>
              <div>
                <h2 className='text-xl font-extrabold tracking-tight'>
                  {title}
                </h2>
                {text ? (
                  <p className='mt-2 text-sm leading-snug'>{text}</p>
                ) : (
                  <ul className='mt-1 space-y-1'>
                    {values.map(([name, detail]) => (
                      <li
                        key={name}
                        className='flex items-start gap-2 text-[11px] leading-snug'
                      >
                        <CheckCircle2
                          size={14}
                          className='shrink-0 fill-violet-700 text-white'
                        />
                        <span>
                          <strong>{name}</strong> – {detail}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </article>
          ))}
        </section>
        <section
          id='story'
          className='mt-6 grid scroll-mt-24 items-center gap-6 md:grid-cols-[1fr_1.35fr] xl:grid-cols-[1fr_1.3fr_.45fr]'
        >
          <button
            type='button'
            aria-label='Watch Our Story'
            onClick={() => openView("story")}
            className='group relative h-56 overflow-hidden rounded-2xl focus-visible:outline-violet-600'
          >
            <img
              src='/images/home/mentorship-hero.webp'
              alt='A mentor and learner exploring an opportunity together'
              loading='lazy'
              className='h-full w-full object-cover transition group-hover:scale-105 motion-reduce:transform-none'
            />
            <span className='absolute inset-0 grid place-items-center bg-black/10'>
              <span className='grid size-14 place-items-center rounded-full border-2 border-white bg-violet-950/60 text-white'>
                <Play size={28} className='ml-1 fill-white' />
              </span>
            </span>
          </button>
          <div>
            <Heading>Our Story</Heading>
            <p className='mt-3 text-sm leading-snug'>
              {platform.platform_name} is built on a simple belief — that
              everyone, from a primary school learner to a working professional,
              deserves guidance, skills and opportunities to unlock their full
              potential.
            </p>
            <p className='mt-3 text-sm leading-snug'>
              We bring together experienced mentors, practical learning, and a
              supportive community to help learners discover their interests,
              build skills, make informed career choices and grow into
              purposeful leaders.
            </p>

          </div>
          <aside className='relative hidden h-52 border-l border-violet-200 pl-6 xl:block'>
            <AfricaMark />
            <p className='absolute bottom-8 left-6 text-lg font-extrabold leading-tight'>
              Built for
              <br />
              Africa,
              <br />
              Impacting
              <br />
              Beyond
            </p>
            <span
              aria-hidden='true'
              className='absolute bottom-4 left-6 h-2 w-20 rounded-[50%] border-t-4 border-amber-400'
            />
          </aside>
        </section>
        <section
          aria-label='Our impact so far'
          className='mt-5 rounded-2xl border border-violet-100 bg-gradient-to-br from-white to-violet-50 px-5 py-4'
        >
          <div className='flex flex-col gap-4 lg:flex-row lg:items-center'>
            <h2 className='shrink-0 text-xl font-extrabold leading-tight text-violet-800'>
              Our Impact
              <br className='hidden lg:block' /> (So Far)
            </h2>
            {about.isError ? (
              <div
                role='alert'
                className='flex flex-wrap items-center gap-3 text-sm'
              >
                <p>Impact figures could not be loaded.</p>
                <button
                  className='font-bold text-violet-700 underline'
                  onClick={() => about.refetch()}
                >
                  Retry
                </button>
              </div>
            ) : (
              <div
                className='grid flex-1 grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5'
                aria-busy={about.isPending}
              >
                {metrics.map(({ key, label, Icon, to }) => (
                  <Link
                    key={key}
                    to={to}
                    className='flex items-center gap-3 rounded px-2 hover:bg-violet-100 focus-visible:outline-violet-600 lg:border-l lg:border-violet-200 lg:pl-5'
                  >
                    <Icon size={37} className='shrink-0 text-violet-700' />
                    <div>
                      {about.isPending ? (
                        <>
                          <Skeleton className='mb-2 h-6 w-16' />
                          <span className='sr-only'>Loading {label}</span>
                        </>
                      ) : (
                        <p className='text-2xl font-extrabold tracking-tight'>
                          {new Intl.NumberFormat(platform.language).format(
                            about.data.impact[key],
                          )}
                        </p>
                      )}
                      <p className='text-[11px] leading-tight'>{label}</p>
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </section>
        <section className='mt-5'>
          <header className='mb-4 flex flex-wrap items-center gap-x-20 gap-y-2'>
            <Heading>Who We Serve</Heading>
            <p className='text-sm'>
              Our programs and mentorship opportunities are designed for every
              stage of your journey.
            </p>
          </header>
          <div className='grid gap-4 sm:grid-cols-2 lg:grid-cols-5'>
            {audiences.map(({ title, subtitle, text, Icon, to }, i) => (
              <Link
                key={title}
                to={to}
                className='group overflow-hidden rounded-2xl border border-violet-100 bg-gradient-to-br from-white to-violet-50 transition hover:border-violet-400 hover:shadow-md'
              >
                <div className='relative h-28'>
                  <div
                    role='img'
                    aria-label={`Illustrative portrait for ${title}`}
                    className='h-full bg-cover'
                    style={{
                      backgroundImage:
                        "url(/images/home/journey-portraits-v2.webp)",
                      backgroundSize: "500% auto",
                      backgroundPosition: `${i * 25}% 47%`,
                    }}
                  />
                  <span className='absolute bottom-2 left-3 grid size-12 place-items-center rounded-full border border-violet-100 bg-white/95 text-violet-700'>
                    <Icon size={30} />
                  </span>
                </div>
                <div className='p-4 pt-2'>
                  <h3 className='text-base font-extrabold leading-tight tracking-tight'>
                    {title}
                  </h3>
                  {subtitle && (
                    <p className='mt-1 text-sm font-semibold leading-tight'>
                      {subtitle}
                    </p>
                  )}
                  <p className='mt-2 text-sm leading-snug'>{text}</p>
                </div>
              </Link>
            ))}
          </div>
        </section>
        <section className='mt-6 grid items-stretch gap-7 lg:grid-cols-[1.55fr_1fr]'>
          <div className='relative overflow-hidden rounded-2xl bg-gradient-to-r from-[#25134e] to-violet-700 px-6 py-5 text-white'>
            <div
              aria-hidden='true'
              className='absolute inset-y-0 right-0 hidden w-1/3 bg-violet-400/40 sm:block'
            />
            <div
              role='img'
              aria-label='Illustrative portrait of a young professional'
              className='absolute inset-y-0 right-0 hidden w-[32%] bg-no-repeat sm:block'
              style={{
                backgroundImage: "url(/images/home/journey-portraits-v2.webp)",
                backgroundSize: "500% auto",
                backgroundPosition: "75% 47%",
              }}
            />
            <div className='relative sm:max-w-[70%]'>
              <h2 className='text-2xl font-extrabold tracking-tight'>
                Why Choose {platform.platform_name}?
              </h2>
              <ul className='mt-3 space-y-2'>
                {[
                  "Mentorship for every stage of life",
                  "Expert and verified mentors",
                  "Practical and real-world learning",
                  "A safe, inclusive and supportive community",
                  "Opportunities for growth, careers and impact",
                ].map((text) => (
                  <li key={text} className='flex items-start gap-2 text-sm'>
                    <CheckCircle2
                      size={18}
                      className='shrink-0 fill-white text-violet-900'
                    />
                    {text}
                  </li>
                ))}
              </ul>
            </div>
          </div>
          <div className='py-3 lg:border-l lg:border-violet-200 lg:pl-7'>
            <h2 className='flex items-center gap-3 text-2xl font-extrabold tracking-tight'>
              <Users size={34} className='text-violet-700' />
              Our Leadership
            </h2>
            <p className='mt-3 max-w-md text-sm leading-snug'>
              A passionate team of educators, technologists and community
              builders committed to creating lasting impact through mentorship
              and learning.
            </p>
            <button
              type='button'
              className={`${outline} mt-5`}
              onClick={() => openView("team")}
            >
              Meet Our Team <ArrowRight size={18} />
            </button>
            {canManage && (
              <button
                type='button'
                onClick={() => setEditor(true)}
                className='mt-3 flex items-center gap-2 text-xs font-bold text-violet-700 underline'
              >
                <Settings size={14} />
                Manage About Content
              </button>
            )}
          </div>
        </section>
      </div>
      <VideoDialog open={view==='story'&&!!about.data?.story_video_url} onOpenChange={open=>{if(!open)openView();}} title="Our Story">{about.data?.story_video_url&&<PlatformVideo src={about.data.story_video_url} title="Our Story" force/>}</VideoDialog>
      <Dialog
        open={view === "story" && !about.data?.story_video_url}
        onOpenChange={(open) => {
          if (!open) openView();
        }}
      >
        <DialogContent className='max-h-[90vh] max-w-3xl overflow-y-auto'>
          <DialogHeader>
            <DialogTitle>Our Story</DialogTitle>
            <DialogDescription>
              Mentorship, learning and opportunity at {platform.platform_name}.
            </DialogDescription>
          </DialogHeader>
          {about.data?.story_video_url && !videoFailed ? (
            <PlatformVideo key={about.data.story_video_url} src={about.data.story_video_url} title="Our Story" force/>
          ) : (
            <>
              <img
                src={story[step].image}
                alt='Illustrative mentorship and community scene'
                className='aspect-[2/1] w-full rounded-xl object-cover'
              />
              {videoFailed && (
                <p role='status' className='text-xs text-slate-600'>
                  The video could not be played. You can explore our story
                  below.
                </p>
              )}
              <div aria-live='polite'>
                <p className='text-xs font-bold text-violet-700'>
                  Chapter {step + 1} of {story.length}
                </p>
                <h3 className='mt-1 text-xl font-extrabold'>
                  {story[step].title}
                </h3>
                <p className='mt-2 text-sm leading-relaxed'>
                  {story[step].text}
                </p>
              </div>
              <div className='flex items-center justify-between gap-3'>
                <button
                  type='button'
                  disabled={step === 0}
                  className={outline}
                  onClick={() => setStep(step - 1)}
                >
                  <ArrowLeft size={17} />
                  Previous
                </button>
                {step < story.length - 1 ? (
                  <button
                    type='button'
                    className={outline}
                    onClick={() => setStep(step + 1)}
                  >
                    Next Chapter <ArrowRight size={17} />
                  </button>
                ) : (
                  <Link to='/partner-with-us' className={outline}>
                    Partner With Us <ArrowRight size={17} />
                  </Link>
                )}
              </div>
            </>
          )}
        </DialogContent>
      </Dialog>
      <Dialog
        open={view === "team"}
        onOpenChange={(open) => {
          if (!open) openView();
        }}
      >
        <DialogContent className='max-h-[90vh] max-w-3xl overflow-y-auto'>
          <DialogHeader>
            <DialogTitle>Meet Our Team</DialogTitle>
            <DialogDescription>
              The people supporting {platform.platform_name}’s mission.
            </DialogDescription>
          </DialogHeader>
          {about.isPending ? (
            <div
              role='status'
              aria-label='Loading team profiles'
              className='grid gap-4 sm:grid-cols-2'
            >
              {[0, 1].map((i) => (
                <Skeleton key={i} className='h-48 rounded-xl' />
              ))}
            </div>
          ) : about.isError ? (
            <div role='alert'>
              <p>{operationError(about.error)}</p>
              <button className={outline} onClick={() => about.refetch()}>
                Retry
              </button>
            </div>
          ) : about.data.team.length ? (
            <div className='grid gap-4 sm:grid-cols-2'>
              {about.data.team.map((member, i) => (
                <article
                  key={`${member.name}-${i}`}
                  className='rounded-xl border border-violet-100 bg-violet-50 p-5'
                >
                  <Avatar className='mb-3 size-20'>
                    <AvatarImage
                      src={member.photo_url || undefined}
                      alt={member.name}
                    />
                    <AvatarFallback className='bg-violet-200 text-xl text-violet-900'>
                      {member.name
                        .split(" ")
                        .map((n) => n[0])
                        .slice(0, 2)
                        .join("")}
                    </AvatarFallback>
                  </Avatar>
                  <h3 className='font-extrabold'>{member.name}</h3>
                  <p className='mt-1 text-sm font-semibold text-violet-700'>
                    {member.title}
                  </p>
                  <p className='mt-3 whitespace-pre-wrap break-words text-sm'>
                    {member.bio}
                  </p>
                </article>
              ))}
            </div>
          ) : (
            <div className='rounded-xl border border-violet-100 bg-violet-50 p-6'>
              <p className='text-sm'>
                Leadership profiles will appear here as they are published. Our
                team is available to discuss mentorship and partnership
                opportunities.
              </p>
              <Link to='/contact' className={`${outline} mt-4`}>
                Contact Our Team <ArrowRight size={17} />
              </Link>
            </div>
          )}
        </DialogContent>
      </Dialog>
      {canManage && (
        <AboutContentEditor open={editor} onClose={() => setEditor(false)} />
      )}
    </MainLayout>
  );
}
