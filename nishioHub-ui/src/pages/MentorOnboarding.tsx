import { useState } from "react";
import { Link } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  CheckCircle2,
  ClipboardList,
  Gem,
  FileText,
  FileUp,
  PlayCircle,
  Rocket,
  ShieldCheck,
  Target,
  UserRound,
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
import { usePlatform } from "@/lib/platform-context";
const onboardingSteps = [
  {
    title: "Create Your Account",
    text: "Sign up or log in to start your application.",
    Icon: FileText,
  },
  {
    title: "Complete Your Profile",
    text: "Add your background, expertise and areas of mentorship.",
    Icon: UserRound,
  },
  {
    title: "Submit Requirements",
    text: "Provide the required documents and references.",
    Icon: FileUp,
  },
  {
    title: "Verification & Approval",
    text: "Our team reviews and verifies your application (1–3 days).",
    Icon: ShieldCheck,
  },
  {
    title: "Start Mentoring",
    text: "Get onboarded, set your availability and begin supporting learners.",
    Icon: Rocket,
  },
];
const apply =
  "inline-flex items-center justify-center gap-2 rounded-xl border border-violet-300 bg-gradient-to-b from-violet-500 via-violet-700 to-violet-800 px-6 py-3 text-base font-bold text-white shadow-md hover:brightness-110";
export default function MentorOnboarding() {
  const platform = usePlatform();
  const [walkthrough, setWalkthrough] = useState(false);
  const panels = [
    {
      title: "Who Can Be a Mentor?",
      Icon: Target,
      intro:
        "We welcome passionate and experienced individuals who want to guide and support the next generation, including:",
      items: [
        "Educators and school staff",
        "University students and recent graduates",
        "Working professionals from various industries",
        "Entrepreneurs and business leaders",
        "Alumni and community role models",
      ],
    },
    {
      title: "Requirements",
      Icon: ClipboardList,
      intro:
        "To ensure a safe and high-quality mentorship experience, please have the following:",
      items: [
        "Valid government ID (National ID or Passport)",
        "Updated professional/academic CV",
        "Proof of qualifications or relevant experience",
        "A short statement of why you want to mentor",
        "References (e.g., employer, school or community leader)",
        `Agree to ${platform.platform_name}’s Mentorship Code of Conduct and Child Safeguarding Policy`,
      ],
    },
    {
      title: "Benefits of Mentoring",
      Icon: Gem,
      intro:
        "Be part of a purpose-driven community and grow while making an impact.",
      items: [
        "Create Real Impact — shape the future of learners and young professionals.",
        "Build Your Network — connect with peers, schools and organizations.",
        "Enhance Your Profile — gain recognition and leadership visibility.",
        `Access Resources — use ${platform.platform_name}’s learning and mentorship tools.`,
        "Give Back — contribute to your community and national development.",
      ],
    },
  ];
  return (
    <MainLayout>
      <Helmet>
        <title>Become a Mentor | {platform.platform_name}</title>
        <meta
          name='description'
          content='Share your knowledge and guide the next generation. Apply to become a verified NishioHub mentor.'
        />
      </Helmet>
      <section className='relative overflow-hidden bg-[#24103e] text-white'>
        <div className='relative mx-auto max-w-[1440px]'>
          <img
            src='/images/onboarding/mentor-hero.webp'
            alt='A welcoming professional mentor at a laptop'
            fetchPriority='high'
            className='h-64 w-full object-cover object-[center_30%] lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[75%] lg:object-[center_12%]'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[54%] bg-gradient-to-br from-[#211439] via-[#381361] to-violet-800 lg:block'
            style={{ clipPath: "ellipse(100% 130% at 0% 15%)" }}
          />
          <svg
            aria-hidden='true'
            viewBox='0 0 80 80'
            className='absolute left-[56%] top-5 hidden h-20 w-20 text-yellow-300 lg:block'
            fill='none'
            stroke='currentColor'
            strokeWidth='7'
            strokeLinecap='round'
          >
            <path d='M10 35 36 51M35 10 48 38M8 65 33 65' />
          </svg>
          <div className='relative px-6 py-7 lg:w-[55%] lg:px-12 lg:py-8 xl:py-8'>
            <p className='mb-3 inline-flex items-center gap-2 rounded-full bg-violet-600/90 px-4 py-1 text-sm font-bold'>
              <Users size={24} />
              Become a Mentor
            </p>
            <h1 className='text-4xl font-extrabold leading-[1.07] tracking-tight lg:text-[42px] xl:text-[44px]'>
              Share Your Knowledge.
              <br />
              Guide the{" "}
              <span className='text-yellow-300'>Next Generation.</span>
            </h1>
            <p className='mt-3 max-w-lg text-base leading-snug'>
              Join {platform.platform_name}’s community of trusted mentors and
              help learners, students, and young professionals discover their
              potential, build skills, and achieve their goals.
            </p>
            <div className='mt-5 flex flex-wrap gap-4'>
              <Link to='/mentor/application' className={apply}>
                Apply to Be a Mentor <ArrowRight size={22} />
              </Link>
              <button
                className='inline-flex items-center gap-2 rounded-xl border border-white px-4 py-3 font-semibold hover:bg-white/10'
                onClick={() => setWalkthrough(true)}
              >
                <PlayCircle size={27} />
                Watch How It Works
              </button>
            </div>
          </div>
          <aside className='absolute right-5 top-14 hidden w-56 space-y-4 rounded-2xl bg-white/95 p-4 text-sm font-semibold text-violet-950 shadow-lg lg:block'>
            {[
              "Guide & Inspire Learners",
              "Share Real-World Experience",
              "Build Future Leaders",
              "Make a Lasting Impact",
            ].map((text) => (
              <p className='flex items-center gap-2' key={text}>
                <CheckCircle2 size={23} className='shrink-0 text-green-700' />
                {text}
              </p>
            ))}
          </aside>
        </div>
      </section>
      <div className='mx-auto max-w-[1440px] px-4 py-6 lg:px-7'>
        <header className='mb-8 flex items-start gap-4'>
          <span className='mt-5 h-1 w-14 shrink-0 bg-violet-600' />
          <div>
            <h2 className='text-2xl font-extrabold tracking-tight md:text-3xl'>
              Mentor On-Boarding Process
            </h2>
            <p className='mt-1 text-sm md:text-base'>
              A simple and guided process to become a verified mentor on{" "}
              {platform.platform_name}.
            </p>
          </div>
        </header>
        <ol className='grid gap-5 md:grid-cols-3 lg:grid-cols-5 lg:gap-10'>
          {onboardingSteps.map((step, i) => (
            <li
              key={step.title}
              className='relative rounded-2xl border border-violet-200 bg-gradient-to-br from-white to-violet-50 px-4 pb-4 pt-3 lg:px-3'
            >
              <span className='absolute -top-3 left-6 flex size-9 items-center justify-center rounded-full bg-gradient-to-b from-violet-500 to-violet-800 text-xl font-bold text-white'>
                {i + 1}
              </span>
              <step.Icon size={53} className='mx-auto mb-3 text-violet-700' />
              <h3 className='mb-2 text-base font-extrabold tracking-tight'>
                {step.title}
              </h3>
              <p className='text-sm leading-snug'>{step.text}</p>
              {i < 4 && (
                <ArrowRight
                  size={27}
                  className='absolute -right-9 top-1/2 hidden text-violet-600 lg:block'
                />
              )}
            </li>
          ))}
        </ol>
        <div className='mt-9 grid gap-4 lg:grid-cols-3'>
          {panels.map((panel, index) => (
            <section
              key={panel.title}
              className='relative overflow-hidden rounded-2xl border border-violet-200 bg-gradient-to-br from-white to-violet-50 p-5'
            >
              <h2 className='mb-3 flex items-center gap-3 text-2xl font-extrabold tracking-tight'>
                <panel.Icon size={43} className='shrink-0 text-violet-700' />
                {panel.title}
              </h2>
              <p className='mb-5 text-sm leading-snug'>{panel.intro}</p>
              <ul className={`space-y-3 ${index === 0 ? "pb-16" : ""}`}>
                {panel.items.map((text) => (
                  <li
                    key={text}
                    className='flex items-start gap-3 text-sm leading-snug'
                  >
                    <CheckCircle2
                      size={19}
                      fill='currentColor'
                      className='mt-0.5 shrink-0 text-violet-600 stroke-white'
                    />
                    <span>{text}</span>
                  </li>
                ))}
              </ul>
              {index === 0 && (
                <img
                  src='/images/onboarding/graduation-books.webp'
                  alt=''
                  loading='lazy'
                  className='absolute bottom-0 right-3 h-24 w-32 object-contain'
                />
              )}
            </section>
          ))}
        </div>
        <section className='mt-10 flex flex-wrap items-center justify-between gap-5 rounded-[26px] bg-gradient-to-r from-[#35145d] via-violet-800 to-violet-700 px-7 py-6 text-white lg:px-12'>
          <Users
            size={80}
            fill='currentColor'
            className='hidden shrink-0 border-r border-white/70 pr-5 sm:block'
          />
          <div className='flex-1'>
            <h2 className='text-3xl font-extrabold tracking-tight'>
              Ready to{" "}
              <span className='text-yellow-300'>Make a Difference?</span>
            </h2>
            <p className='mt-2 text-sm'>
              Join {platform.platform_name} today and mentor learners from
              primary school to the working class.
            </p>
          </div>
          <Link
            to='/mentor/application'
            className='inline-flex items-center gap-3 rounded-xl border border-yellow-100 bg-gradient-to-b from-yellow-200 to-yellow-400 px-6 py-3 text-lg font-extrabold text-black shadow-lg hover:brightness-105'
          >
            Apply to Be a Mentor <ArrowRight />
          </Link>
        </section>
      </div>
      <Dialog open={walkthrough} onOpenChange={setWalkthrough}>
        <DialogContent className='max-h-[90vh] max-w-xl overflow-y-auto'>
          <DialogHeader>
            <DialogTitle>How mentor onboarding works</DialogTitle>
            <DialogDescription>
              Save your progress, submit your documents and follow the team’s
              review. The 1–3 day review time is an estimate.
            </DialogDescription>
          </DialogHeader>
          <ol className='space-y-4'>
            {onboardingSteps.map((step, i) => (
              <li key={step.title} className='flex gap-3'>
                <span className='flex size-8 shrink-0 items-center justify-center rounded-full bg-violet-100 font-bold text-violet-800'>
                  {i + 1}
                </span>
                <div>
                  <h3 className='font-bold'>{step.title}</h3>
                  <p className='text-sm text-muted-foreground'>{step.text}</p>
                </div>
              </li>
            ))}
          </ol>
          <Link to='/mentor/application' className={apply}>
            Start My Application <ArrowRight size={19} />
          </Link>
        </DialogContent>
      </Dialog>
    </MainLayout>
  );
}
