import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  BriefcaseBusiness,
  Building2,
  CalendarDays,
  CheckCircle2,
  FileText,
  GraduationCap,
  Handshake,
  Landmark,
  Leaf,
  Lightbulb,
  Presentation,
  Rocket,
  Send,
  TrendingUp,
  Users,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { ButtonLoader } from "@/components/loaders/ButtonLoader";
import { PhoneInput } from "@/components/ui/phone-input";
import { operationError } from "@/components/admin/dashboard-operations";
import { usePlatform } from "@/lib/platform-context";
import {
  normalizeApplicationPhone,
  validApplicationPhone,
} from "@/lib/application-phone";
import { sessionIsoInput } from "@/lib/session-time";
import {
  partnershipFocus,
  submitPartnershipRequest,
  type PartnershipRequest,
} from "@/lib/partnership-api";

const empty: PartnershipRequest = {
  organization_name: "",
  name: "",
  contact_role: "",
  email: "",
  phone_number: "",
  focus: "",
  message: "",
  terms_accepted: false,
  request_kind: "partnership",
};
const input =
  "mt-1 block h-9 w-full min-w-0 rounded-lg border border-[#c7c9e6] bg-white px-3 text-sm font-normal outline-none placeholder:text-slate-500 focus:border-violet-600 focus:ring-2 focus:ring-violet-100 disabled:opacity-60";
const benefits = [
  {
    title: "Expand Your Impact",
    text: "Reach and support more learners and communities.",
    Icon: Users,
    color: "border-violet-100 bg-violet-50",
    icon: "text-violet-700",
  },
  {
    title: "Share Expertise",
    text: "Contribute knowledge, skills and practical experience.",
    Icon: Lightbulb,
    color: "border-amber-100 bg-amber-50",
    icon: "text-amber-500",
  },
  {
    title: "Build Future Talent",
    text: "Nurture skilled, confident and job-ready young people.",
    Icon: TrendingUp,
    color: "border-blue-100 bg-blue-50",
    icon: "text-blue-600",
  },
  {
    title: "Create Shared Value",
    text: "Achieve your goals while advancing inclusive education and opportunity.",
    Icon: Handshake,
    color: "border-emerald-100 bg-emerald-50",
    icon: "text-emerald-600",
  },
];
const focusIcons = [
  GraduationCap,
  Building2,
  BriefcaseBusiness,
  Users,
  Landmark,
  Leaf,
];
const process = [
  {
    title: "Reach Out",
    text: "Send us your partnership inquiry.",
    Icon: FileText,
  },
  {
    title: "Discuss",
    text: "We explore goals, ideas and options.",
    Icon: Presentation,
  },
  {
    title: "Plan Together",
    text: "Agree on activities, roles and timelines.",
    Icon: Handshake,
  },
  {
    title: "Launch & Grow",
    text: "Implement, measure impact and scale.",
    Icon: Rocket,
  },
];
function Heading({ children }: { children: ReactNode }) {
  return (
    <h2 className='flex items-center gap-3 text-xl font-extrabold tracking-tight sm:text-2xl'>
      <span
        aria-hidden='true'
        className='h-1 w-8 shrink-0 rounded bg-violet-700'
      />
      {children}
    </h2>
  );
}
function Field({
  name,
  label,
  error,
  children,
}: {
  name: string;
  label: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <div className='min-w-0'>
      <label htmlFor={`partner-${name}`} className='block text-xs font-bold'>
        {label} <span className='text-red-600'>*</span>
      </label>
      {children}
      {error && (
        <p id={`partner-${name}-error`} className='mt-1 text-xs text-red-700'>
          {error}
        </p>
      )}
    </div>
  );
}
function newKey() {
  if (crypto.randomUUID) return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join(
    "",
  );
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
export default function PartnerWithUs() {
  const platform = usePlatform();
  const navigate = useNavigate();
  const [draft, setDraft] = useState({ ...empty });
  const [preferred, setPreferred] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [receipt, setReceipt] = useState<{
    reference: string;
    meeting: boolean;
  } | null>(null);
  const form = useRef<HTMLFormElement>(null);
  const success = useRef<HTMLDivElement>(null);
  const lock = useRef(false);
  const key = useRef("");
  const signature = useRef("");
  function set<K extends keyof PartnershipRequest>(
    field: K,
    value: PartnershipRequest[K],
  ) {
    setDraft((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: "" }));
  }
  function attrs(name: string) {
    return {
      id: `partner-${name}`,
      name,
      "aria-invalid": !!errors[name],
      "aria-describedby": errors[name] ? `partner-${name}-error` : undefined,
    };
  }
  function goToForm(focus?: string, meeting = false) {
    if (lock.current) return;
    setReceipt(null);
    setError("");
    setErrors({});
    setDraft((current) => ({
      ...current,
      ...(focus ? { focus } : {}),
      request_kind: meeting ? "meeting" : "partnership",
    }));
    requestAnimationFrame(() => {
      document
        .getElementById("partnership-inquiry")
        ?.scrollIntoView({ behavior: "smooth", block: "start" });
      document
        .getElementById(focus ? "partner-focus" : "partner-organization_name")
        ?.focus({ preventScroll: true });
    });
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (lock.current) return;
    const payload = Object.fromEntries(
      Object.entries(draft).map(([k, v]) => [
        k,
        typeof v === "string" ? v.trim() : v,
      ]),
    ) as unknown as PartnershipRequest;
    payload.phone_number = normalizeApplicationPhone(payload.phone_number);
    const invalid: Record<string, string> = {};
    for (const field of ["organization_name", "contact_role"] as const)
      if (payload[field].length < 2 || payload[field].length > 120)
        invalid[field] = "Enter 2–120 characters.";
    if (payload.name.length < 2 || payload.name.length > 150)
      invalid.name = "Enter your full name (2–150 characters).";
    if (
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.email) ||
      payload.email.length > 254
    )
      invalid.email = "Enter a valid email address.";
    if (!validApplicationPhone(payload.phone_number))
      invalid.phone_number = "Enter a valid phone number with country code.";
    if (!Object.prototype.hasOwnProperty.call(partnershipFocus, payload.focus))
      invalid.focus = "Choose a partnership focus.";
    if (payload.message.length < 20 || payload.message.length > 500)
      invalid.message = "Describe your proposal in 20–500 characters.";
    if (!payload.terms_accepted)
      invalid.terms_accepted =
        "Agree to the Terms of Service and Privacy Policy to continue.";
    if (payload.request_kind === "meeting") {
      try {
        payload.preferred_at = sessionIsoInput(preferred, platform.timezone);
        if (new Date(payload.preferred_at) <= new Date()) throw new Error();
      } catch {
        invalid.preferred_at = "Choose a future date and time.";
      }
    }
    setErrors(invalid);
    setError("");
    if (Object.keys(invalid).length) {
      requestAnimationFrame(() =>
        form.current
          ?.querySelector<HTMLElement>('[aria-invalid="true"]')
          ?.focus(),
      );
      return;
    }
    lock.current = true;
    setBusy(true);
    try {
      const nextSignature = JSON.stringify(payload);
      if (!key.current || signature.current !== nextSignature) {
        key.current = newKey();
        signature.current = nextSignature;
      }
      const result = await submitPartnershipRequest({
        ...payload,
        submission_key: key.current,
      });
      setReceipt({
        reference: result.reference,
        meeting: payload.request_kind === "meeting",
      });
      setDraft({ ...empty });
      setPreferred("");
      requestAnimationFrame(() => success.current?.focus());
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  return (
    <MainLayout>
      <Helmet>
        <title>Partner With Us | {platform.platform_name}</title>
        <meta
          name='description'
          content='Partner with NishioHub to expand mentorship, learning and career opportunities. Send a partnership inquiry or request a conversation.'
        />
      </Helmet>
      <section className='overflow-hidden bg-[#251752] text-white'>
        <div className='relative mx-auto max-w-[1440px] lg:min-h-[265px]'>
          <img
            src='/images/partnerships/partnership-hero.webp'
            alt='Two professionals discussing a partnership and shaking hands'
            fetchPriority='high'
            className='h-56 w-full object-cover lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[55%] lg:object-top'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[50%] bg-yellow-400 lg:block'
            style={{ clipPath: "ellipse(100% 170% at 0% 10%)" }}
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[48%] bg-gradient-to-r from-[#24134c] to-violet-800 lg:block'
            style={{ clipPath: "ellipse(100% 170% at 0% 25%)" }}
          />
          <div className='relative px-6 py-7 lg:w-[47%] lg:px-12'>
            <p className='mb-3 inline-flex items-center gap-2 rounded-full bg-purple-400/40 px-4 py-1 text-sm font-bold'>
              <Handshake size={22} />
              Partnership
            </p>
            <h1 className='text-4xl font-extrabold tracking-tight lg:text-5xl'>
              Partner With Us
            </h1>
            <p className='mt-4 max-w-lg text-base leading-relaxed lg:text-lg'>
              Let’s work together to create more learning, mentorship and
              opportunity for learners, schools, and communities across Uganda
              and beyond.
            </p>
          </div>
        </div>
      </section>
      <div className='mx-auto grid max-w-[1440px] gap-7 px-5 py-6 lg:grid-cols-[1.25fr_1fr] lg:px-10'>
        <div className='min-w-0'>
          <Heading>Why Partner With {platform.platform_name}?</Heading>
          <p className='mb-4 mt-2 text-sm leading-relaxed sm:pl-11'>
            We collaborate with schools, universities, organizations and
            industry leaders to expand access to mentorship, skills development,
            and real-world opportunities for learners and professionals.
          </p>
          <div className='grid gap-3 sm:grid-cols-2'>
            {benefits.map(({ title, text, Icon, color, icon }) => (
              <article
                key={title}
                className={`flex items-start gap-3 rounded-xl border p-4 ${color}`}
              >
                <Icon
                  size={44}
                  className={`shrink-0 ${icon}`}
                  aria-hidden='true'
                />
                <div>
                  <h3 className='text-base font-extrabold tracking-tight'>
                    {title}
                  </h3>
                  <p className='mt-1 text-sm leading-snug'>{text}</p>
                </div>
              </article>
            ))}
          </div>
          <section className='mt-6'>
            <Heading>Partnership Opportunities</Heading>
            <div className='mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6'>
              {Object.entries(partnershipFocus).map(([value, label], i) => {
                const Icon = focusIcons[i];
                return (
                  <button
                    key={value}
                    disabled={busy}
                    type='button'
                    onClick={() => goToForm(value)}
                    className='rounded-xl border border-violet-100 bg-white px-2 py-3 text-center shadow-sm transition hover:border-violet-400 hover:bg-violet-50 focus-visible:outline-violet-600 disabled:opacity-50'
                  >
                    <Icon
                      size={34}
                      className={`mx-auto mb-2 ${i === 5 ? "text-green-600" : i === 1 ? "text-blue-600" : "text-violet-700"}`}
                    />
                    <span className='block text-[11px] font-bold leading-tight'>
                      {label}
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
          <section className='mt-6'>
            <Heading>How The Partnership Works</Heading>
            <div className='mt-5 grid grid-cols-2 gap-5 sm:grid-cols-4'>
              {process.map(({ title, text, Icon }, i) => (
                <article
                  key={title}
                  className='relative rounded-xl border border-violet-100 bg-violet-50/50 px-3 py-3 text-center shadow-sm'
                >
                  <span className='absolute -top-2 left-5 grid size-6 place-items-center rounded-full bg-violet-700 text-sm font-bold text-white'>
                    {i + 1}
                  </span>
                  <Icon size={34} className='mx-auto mb-2 text-violet-700' />
                  <h3 className='text-sm font-extrabold'>{title}</h3>
                  <p className='mt-1 text-xs leading-snug'>{text}</p>
                  {i < 3 && (
                    <ArrowRight
                      aria-hidden='true'
                      size={18}
                      className='absolute -right-5 top-1/2 hidden text-violet-700 sm:block'
                    />
                  )}
                </article>
              ))}
            </div>
          </section>
          <section className='mt-6'>
            <Heading>Our Partnership Community</Heading>
            <div className='mt-3 flex flex-wrap items-center justify-center gap-5 rounded-xl border border-violet-100 bg-white px-5 py-5 text-violet-800'>
              {[Building2, GraduationCap, BriefcaseBusiness, Users, Leaf].map(
                (Icon, i) => (
                  <Icon key={i} size={30} aria-hidden='true' />
                ),
              )}
              <p className='basis-full text-center text-xs text-slate-600'>
                Schools, businesses and communities — let’s build more
                opportunities together.
              </p>
            </div>
          </section>
        </div>
        <div className='min-w-0'>
          <section
            id='partnership-inquiry'
            className='scroll-mt-24 rounded-2xl border border-violet-100 bg-gradient-to-br from-white to-violet-50 p-5 shadow-sm'
          >
            <header className='mb-4 flex items-start gap-4'>
              <Handshake size={44} className='shrink-0 text-violet-700' />
              <div>
                <h2 className='text-2xl font-extrabold tracking-tight'>
                  {draft.request_kind === "meeting"
                    ? "Request a Partnership Meeting"
                    : "Send a Partnership Inquiry"}
                </h2>
                <p className='mt-1 text-sm'>
                  Tell us about your organization and how you would like to work
                  with {platform.platform_name}.
                </p>
              </div>
            </header>
            {receipt ? (
              <div
                ref={success}
                tabIndex={-1}
                role='status'
                className='rounded-xl border border-green-200 bg-green-50 p-5 outline-none'
              >
                <CheckCircle2 size={36} className='mb-3 text-green-600' />
                <h3 className='text-xl font-bold'>
                  {receipt.meeting
                    ? "Meeting request received"
                    : "Partnership request received"}
                </h3>
                <p className='mt-2 text-sm'>
                  {receipt.meeting
                    ? "Our team will contact you to confirm availability and arrange your meeting."
                    : "Our team will review your proposal and follow up using your contact details."}
                </p>
                <p className='mt-3 break-all text-xs'>
                  Reference: <strong>{receipt.reference}</strong>
                </p>
                <button
                  type='button'
                  onClick={() => goToForm()}
                  className='mt-4 text-sm font-bold text-violet-700 underline'
                >
                  Send Another Inquiry
                </button>
              </div>
            ) : (
              <form
                ref={form}
                noValidate
                onSubmit={submit}
                className='space-y-3'
              >
                {error && (
                  <p
                    role='alert'
                    className='rounded-lg bg-red-50 p-3 text-sm text-red-700'
                  >
                    {error}
                  </p>
                )}
                <fieldset disabled={busy} className='space-y-3'>
                  <Field
                    name='organization_name'
                    label='Organization / Institution Name'
                    error={errors.organization_name}
                  >
                    <input
                      {...attrs("organization_name")}
                      autoComplete='organization'
                      required
                      maxLength={120}
                      placeholder='e.g. GreenTech Uganda'
                      value={draft.organization_name}
                      onChange={(e) => set("organization_name", e.target.value)}
                      className={input}
                    />
                  </Field>
                  <div className='grid gap-3 sm:grid-cols-2'>
                    <Field
                      name='name'
                      label='Your Full Name'
                      error={errors.name}
                    >
                      <input
                        {...attrs("name")}
                        autoComplete='name'
                        required
                        maxLength={150}
                        placeholder='e.g. Jane Namutebi'
                        value={draft.name}
                        onChange={(e) => set("name", e.target.value)}
                        className={input}
                      />
                    </Field>
                    <Field
                      name='contact_role'
                      label='Your Role / Title'
                      error={errors.contact_role}
                    >
                      <input
                        {...attrs("contact_role")}
                        autoComplete='organization-title'
                        required
                        maxLength={120}
                        placeholder='e.g. Programs Manager'
                        value={draft.contact_role}
                        onChange={(e) => set("contact_role", e.target.value)}
                        className={input}
                      />
                    </Field>
                  </div>
                  <Field
                    name='email'
                    label='Email Address'
                    error={errors.email}
                  >
                    <input
                      {...attrs("email")}
                      type='email'
                      autoComplete='email'
                      required
                      maxLength={254}
                      placeholder='e.g. jane@greentechug.org'
                      value={draft.email}
                      onChange={(e) => set("email", e.target.value)}
                      className={input}
                    />
                  </Field>
                  <Field
                    name='phone_number'
                    label='Phone Number'
                    error={errors.phone_number}
                  >
                    <PhoneInput
                      {...attrs("phone_number")}
                      required
                      autoComplete='tel'
                      className='mt-1'
                      placeholder='Enter phone number'
                      value={draft.phone_number}
                      onChange={(value) => set("phone_number", value)}
                    />
                  </Field>
                  <Field
                    name='focus'
                    label='Partnership Focus / Interest'
                    error={errors.focus}
                  >
                    <select
                      {...attrs("focus")}
                      required
                      value={draft.focus}
                      onChange={(e) => set("focus", e.target.value)}
                      className={input}
                    >
                      <option value=''>Select partnership area</option>
                      {Object.entries(partnershipFocus).map(
                        ([value, label]) => (
                          <option key={value} value={value}>
                            {label}
                          </option>
                        ),
                      )}
                    </select>
                  </Field>
                  {draft.request_kind === "meeting" && (
                    <Field
                      name='preferred_at'
                      label={`Preferred Meeting Date & Time (${platform.timezone})`}
                      error={errors.preferred_at}
                    >
                      <input
                        {...attrs("preferred_at")}
                        type='datetime-local'
                        required
                        value={preferred}
                        onChange={(e) => {
                          setPreferred(e.target.value);
                          setErrors((current) => ({
                            ...current,
                            preferred_at: "",
                          }));
                        }}
                        className={input}
                      />
                      <p className='mt-1 text-xs text-slate-600'>
                        Your preferred time is subject to confirmation by our
                        team.
                      </p>
                    </Field>
                  )}
                  <Field
                    name='message'
                    label='Message / Proposal Details'
                    error={errors.message}
                  >
                    <textarea
                      {...attrs("message")}
                      required
                      maxLength={500}
                      rows={4}
                      placeholder='Tell us about your partnership idea, objectives, and expected outcomes…'
                      value={draft.message}
                      onChange={(e) => set("message", e.target.value)}
                      className={`${input} h-auto py-2`}
                    />
                    <p className='mt-1 text-right text-[10px] text-slate-500'>
                      {draft.message.length} / 500
                    </p>
                  </Field>
                  <div>
                    <label className='flex items-start gap-2 text-xs leading-relaxed'>
                      <input
                        {...attrs("terms_accepted")}
                        type='checkbox'
                        required
                        checked={draft.terms_accepted}
                        onChange={(e) =>
                          set("terms_accepted", e.target.checked)
                        }
                        className='mt-0.5 size-4 shrink-0 accent-violet-700'
                      />
                      <span>
                        I agree to {platform.platform_name}’s{" "}
                        <Link
                          to='/terms-of-service'
                          target='_blank'
                          className='text-violet-700 underline'
                        >
                          Terms of Service
                        </Link>{" "}
                        and{" "}
                        <Link
                          to='/privacy-policy'
                          target='_blank'
                          className='text-violet-700 underline'
                        >
                          Privacy Policy
                        </Link>
                        . <span className='text-red-600'>*</span>
                      </span>
                    </label>
                    {errors.terms_accepted && (
                      <p
                        id='partner-terms_accepted-error'
                        className='mt-1 text-xs text-red-700'
                      >
                        {errors.terms_accepted}
                      </p>
                    )}
                  </div>
                </fieldset>
                <ButtonLoader
                  type='submit'
                  loading={busy}
                  loadingText={
                    draft.request_kind === "meeting"
                      ? "Sending Meeting Request..."
                      : "Sending Partnership Request..."
                  }
                  className='inline-flex w-full items-center justify-center gap-2 rounded-lg bg-gradient-to-b from-violet-600 to-violet-800 px-4 py-3 text-sm font-bold text-white hover:brightness-110 disabled:opacity-60'
                >
                  <Send size={19} />
                  {draft.request_kind === "meeting"
                    ? "Send Meeting Request"
                    : "Send Partnership Request"}
                </ButtonLoader>
                {draft.request_kind === "meeting" && (
                  <button
                    disabled={busy}
                    type='button'
                    className='text-xs font-bold text-violet-700 underline'
                    onClick={() => set("request_kind", "partnership")}
                  >
                    Send an inquiry instead
                  </button>
                )}
              </form>
            )}
          </section>
          <section className='mt-4 rounded-2xl border border-violet-100 bg-gradient-to-br from-white to-violet-50 p-5'>
            <div className='flex items-start gap-4'>
              <CalendarDays size={40} className='shrink-0 text-violet-700' />
              <div>
                <h2 className='text-lg font-extrabold'>
                  Prefer a Conversation?
                </h2>
                <p className='mt-1 text-sm'>
                  Request a quick call with our partnerships team.
                </p>
              </div>
            </div>
            <button
              disabled={busy}
              type='button'
              onClick={() => goToForm(undefined, true)}
              className='mx-auto mt-4 flex items-center justify-center gap-3 rounded-lg border border-violet-600 bg-white px-8 py-2 text-sm font-bold text-violet-700 hover:bg-violet-50 disabled:opacity-50'
            >
              <CalendarDays size={21} />
              Book a Meeting
            </button>
          </section>
        </div>
      </div>
      <section className='relative overflow-hidden bg-gradient-to-r from-[#24134c] via-violet-900 to-violet-800 px-6 py-7 text-white'>
        <div className='mx-auto flex max-w-[1344px] flex-wrap items-center gap-6'>
          <Users size={60} className='shrink-0' />
          <div className='min-w-0 flex-1'>
            <h2 className='text-2xl font-extrabold tracking-tight'>
              Let’s Build More Opportunities{" "}
              <span className='text-yellow-300'>Together</span>
            </h2>
            <p className='mt-2 max-w-2xl text-sm'>
              Partner with {platform.platform_name} to empower learners, mentors
              and communities through mentorship, skills and innovation.
            </p>
          </div>
          <div className='lg:border-l lg:border-white/50 lg:pl-10'>
            <button
              disabled={busy}
              type='button'
              onClick={() => goToForm()}
              className='inline-flex items-center gap-4 rounded-lg bg-white px-6 py-3 text-sm font-extrabold text-[#171039] hover:bg-violet-50 disabled:opacity-50'
            >
              Partner With Us Today <ArrowRight size={21} />
            </button>
          </div>
        </div>
      </section>
    </MainLayout>
  );
}
