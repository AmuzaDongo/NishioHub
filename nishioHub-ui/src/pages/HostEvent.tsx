import { useQueryClient } from "@tanstack/react-query";
import { MyEventRequests } from "@/components/my-event-requests";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import {
  Calendar,
  CalendarCheck,
  CheckCircle2,
  Handshake,
  Lightbulb,
  MessageCircle,
  Monitor,
  Presentation,
  Send,
  ShieldCheck,
  TrendingUp,
  Users,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { ButtonLoader } from "@/components/loaders/ButtonLoader";
import { PhoneInput } from "@/components/ui/phone-input";
import { operationError } from "@/components/admin/dashboard-operations";
import {
  normalizeApplicationPhone,
  validApplicationPhone,
} from "@/lib/application-phone";
import {
  hostingTypes,
  submitEventHostingRequest,
  resubmitEventHostingRequest,
  hostingRequestFields,
  type HostingRequest,
  type EventHostingFields,
} from "@/lib/event-hosting-api";
import { assetUrl, usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { hasRole } from "@/lib/utils";
import { PageLoader } from "@/components/loaders/PageLoader";

const empty: EventHostingFields = {
  name: "",
  email: "",
  phone_number: "",
  event_type: "",
  title: "",
  description: "",
  preferred_date: "",
  location: "",
  additional_information: "",
  terms_accepted: false,
};
const input =
  "mt-1 block h-9 w-full min-w-0 rounded-lg border border-[#c7c9e6] bg-white px-3 text-sm font-normal outline-none placeholder:text-slate-500 focus:border-violet-600 focus:ring-2 focus:ring-violet-100 disabled:opacity-60";
const benefits = [
  {
    title: "Reach a Wider Audience",
    text: "Connect with learners, parents, mentors and professionals across Uganda and beyond.",
    Icon: Users,
    color: "bg-violet-50 border-violet-100",
    icon: "bg-violet-700",
  },
  {
    title: "Share Your Expertise",
    text: "Showcase your knowledge, skills and experience with an engaged community.",
    Icon: Lightbulb,
    color: "bg-amber-50 border-amber-100",
    icon: "bg-amber-400",
  },
  {
    title: "Build Partnerships",
    text: "Collaborate with schools, organizations and industry leaders for greater impact.",
    Icon: Handshake,
    color: "bg-blue-50 border-blue-100",
    icon: "bg-blue-600",
  },
  {
    title: "Create Lasting Impact",
    text: "Support education, mentorship and career growth for a brighter future.",
    Icon: TrendingUp,
    color: "bg-emerald-50 border-emerald-100",
    icon: "bg-emerald-600",
  },
];
const typeIcons = [Presentation, Monitor, Users, MessageCircle, Users];

function submissionKey() {
  if (crypto.randomUUID) return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function Field({
  name,
  label,
  error,
  children,
  required = true,
}: {
  name: string;
  label: string;
  error?: string;
  children: ReactNode;
  required?: boolean;
}) {
  return (
    <div className='min-w-0'>
      <label htmlFor={`hosting-${name}`} className='block text-xs font-bold'>
        {label}
        {required && <span className='text-red-600'> *</span>}
      </label>
      {children}
      {error && (
        <p id={`hosting-${name}-error`} className='mt-1 text-xs text-red-700'>
          {error}
        </p>
      )}
    </div>
  );
}

export default function HostEvent() {
  const { user } = useAuth();
  return <HostEventPage key={user?.id || "guest"} />;
}

function HostEventPage() {
  const platform = usePlatform();
  const navigate = useNavigate();
  const client = useQueryClient();
  const [editing, setEditing] = useState<HostingRequest | null>(null);
  const { user, isLoading } = useAuth();
  const authenticated = !!user?.access_token;
  const allowed =
    authenticated &&
    ["mentor", "school", "organization"].some((role) => hasRole(user, role));
  const loginTo = "/login?return_to=%2Fhost-an-event";
  const [draft, setDraft] = useState<EventHostingFields>({ ...empty });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [reference, setReference] = useState("");
  const lock = useRef(false);
  const requestKey = useRef("");
  const lastPayload = useRef("");
  const form = useRef<HTMLFormElement>(null);
  const success = useRef<HTMLDivElement>(null);
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: platform.timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  function set<K extends keyof EventHostingFields>(
    name: K,
    value: EventHostingFields[K],
  ) {
    setDraft((current) => ({ ...current, [name]: value }));
    setErrors((current) => ({ ...current, [name]: "" }));
  }
  function accessibility(name: string) {
    return {
      id: `hosting-${name}`,
      name,
      "aria-invalid": !!errors[name],
      "aria-describedby": errors[name] ? `hosting-${name}-error` : undefined,
    };
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (lock.current) return;
    if (!authenticated) {
      navigate(loginTo);
      return;
    }
    if (!allowed) {
      setError(
        "Only mentors and school/organization accounts can submit event requests.",
      );
      return;
    }
    const payload = Object.fromEntries(
      Object.entries(draft).map(([key, value]) => [
        key,
        typeof value === "string" ? value.trim() : value,
      ]),
    ) as unknown as EventHostingFields;
    payload.phone_number = normalizeApplicationPhone(payload.phone_number);
    const invalid: Record<string, string> = {};
    if (payload.name.length < 2 || payload.name.length > 150)
      invalid.name = "Enter a name between 2 and 150 characters.";
    if (
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.email) ||
      payload.email.length > 254
    )
      invalid.email = "Enter a valid email address.";
    if (!validApplicationPhone(payload.phone_number))
      invalid.phone_number =
        "Enter a valid phone number, including your country code.";
    if (!Object.prototype.hasOwnProperty.call(hostingTypes, payload.event_type))
      invalid.event_type = "Choose an event type.";
    if (payload.title.length < 5 || payload.title.length > 150)
      invalid.title = "Enter an event title between 5 and 150 characters.";
    if (payload.description.length < 20 || payload.description.length > 500)
      invalid.description = "Describe your event in 20–500 characters.";
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(payload.preferred_date) ||
      payload.preferred_date < today
    )
      invalid.preferred_date = "Choose today or a future date.";
    if (payload.location.length < 2 || payload.location.length > 150)
      invalid.location =
        "Enter a city or district between 2 and 150 characters.";
    if (payload.additional_information.length > 300)
      invalid.additional_information = "Use no more than 300 characters.";
    if (!payload.terms_accepted)
      invalid.terms_accepted =
        "Agree to the Terms of Service and Privacy Policy to continue.";
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
    const signature = JSON.stringify(payload);
    try {
      if (!requestKey.current || lastPayload.current !== signature) {
        requestKey.current = submissionKey();
        lastPayload.current = signature;
      }
      const result = editing
        ? await resubmitEventHostingRequest(editing.id, {
            ...payload,
            lock_version: editing.lock_version,
          })
        : await submitEventHostingRequest({
            ...payload,
            submission_key: requestKey.current,
          });
      await client.invalidateQueries({
        queryKey: ["my-event-hosting-requests", user?.id],
      });
      setEditing(null);
      setReference(result.reference);
      setDraft({ ...empty });
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
        <title>Host an Event | {platform.platform_name}</title>
        <meta
          name='description'
          content='Host workshops, webinars, mentorship sessions and community events with NishioHub. Submit an event hosting request.'
        />
      </Helmet>
      <section className='relative overflow-hidden bg-[#251752] text-white'>
        <div className='relative mx-auto max-w-[1440px] lg:min-h-[290px]'>
          <img
            src='/images/home/mentorship-hero.webp'
            alt='A mentor sharing knowledge with learners'
            fetchPriority='high'
            className='h-52 w-full object-cover lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[60%] lg:object-[center_35%]'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[54%] bg-violet-700 lg:block'
            style={{ clipPath: "ellipse(100% 160% at 0% 20%)" }}
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[52%] bg-gradient-to-r from-[#201945] via-[#29155a] to-[#572194] lg:block'
            style={{ clipPath: "ellipse(100% 160% at 0% 20%)" }}
          />
          <div className='relative px-6 py-7 lg:w-[48%] lg:px-12'>
            <p className='mb-3 inline-flex items-center gap-2 rounded-full bg-white/20 px-3 py-1 text-sm font-bold'>
              <CalendarCheck size={19} />
              Host an Event
            </p>
            <h1 className='text-4xl font-extrabold leading-[1.1] tracking-tight lg:text-[44px] xl:text-[46px]'>
              Host an Event on
              <br />
              <span className='text-yellow-300'>{platform.platform_name}</span>
            </h1>
            <p className='mt-3 font-bold'>Inspire. Educate. Create Impact.</p>
            <p className='mt-2 max-w-lg text-sm leading-relaxed xl:text-base'>
              Partner with us to host workshops, webinars, mentorship sessions,
              and community events that empower learners, mentors, and
              professionals across all stages of life.
            </p>
          </div>
        </div>
      </section>
      <div className='mx-auto grid max-w-[1440px] gap-8 px-5 py-6 lg:grid-cols-[1.15fr_1fr] lg:px-12'>
        <div>
          <h2 className='flex items-center gap-3 text-2xl font-extrabold'>
            <span
              aria-hidden='true'
              className='h-1 w-8 rounded bg-violet-700'
            />
            Why Host an Event?
          </h2>
          <p className='mt-2 text-sm leading-relaxed lg:pl-11'>
            Events are a powerful way to connect, share knowledge, build
            networks and create lasting opportunities. By hosting an event on{" "}
            {platform.platform_name}, you help grow a community of learners,
            mentors and professionals while promoting your organization or
            initiative.
          </p>
          <div className='mt-5 grid gap-4 sm:grid-cols-2'>
            {benefits.map(({ title, text, Icon, color, icon }) => (
              <article key={title} className={`rounded-xl border p-4 ${color}`}>
                <span
                  className={`mb-3 grid size-12 place-items-center rounded-full text-white ${icon}`}
                >
                  <Icon size={32} />
                </span>
                <h3 className='text-base font-extrabold tracking-tight'>
                  {title}
                </h3>
                <p className='mt-1 text-sm leading-relaxed text-[#24294f]'>
                  {text}
                </p>
              </article>
            ))}
          </div>
          <h2 className='mb-4 mt-7 flex items-center gap-3 text-xl font-extrabold'>
            <span
              aria-hidden='true'
              className='h-1 w-8 rounded bg-violet-700'
            />
            Types of Events You Can Host
          </h2>
          <div className='grid grid-cols-2 gap-2 sm:grid-cols-5'>
            {Object.entries(hostingTypes).map(([key, label], i) => {
              const Icon = typeIcons[i];
              return (
                <div
                  key={key}
                  className='rounded-xl border border-violet-100 bg-white px-2 py-3 text-center'
                >
                  <span
                    className={`mx-auto mb-2 grid size-11 place-items-center rounded-full text-white ${["bg-violet-700", "bg-blue-600", "bg-emerald-600", "bg-amber-400", "bg-violet-700"][i]}`}
                  >
                    <Icon size={26} />
                  </span>
                  <p className='text-[11px] font-bold leading-snug'>{label}</p>
                </div>
              );
            })}
          </div>
          <p className='mt-5 flex items-start gap-2 text-xs leading-relaxed text-slate-600'>
            <ShieldCheck size={20} className='shrink-0 text-[#211852]' />
            All events are reviewed to ensure they align with{" "}
            {platform.platform_name}’s mission and community guidelines.
          </p>
        </div>
        <section className='min-w-0 rounded-xl border border-violet-200 bg-gradient-to-br from-white to-violet-50 p-5'>
          <header className='mb-4 flex items-start gap-4'>
            <Calendar size={40} className='shrink-0 text-violet-700' />
            <div>
              <h2 className='text-2xl font-extrabold tracking-tight'>
                {editing ? "Update Your Event Request" : "Register Your Event"}
              </h2>
              <p className='mt-1 text-sm leading-snug'>
                Fill in the form below and our team will get back to you within
                2–3 business days.
              </p>
            </div>
          </header>
          {isLoading ? (
            <PageLoader label='Loading your account' />
          ) : !authenticated ? (
            <div className='rounded-xl border border-violet-200 bg-white p-5'>
              <h3 className='text-lg font-bold'>Log In to Request an Event</h3>
              <p className='mt-2 text-sm leading-relaxed'>
                Event requests can be submitted by logged-in mentors and
                school/organization accounts.
              </p>
              <Link
                to={loginTo}
                className='mt-4 inline-flex rounded-lg bg-violet-700 px-5 py-2.5 text-sm font-bold text-white'
              >
                Log In to Continue
              </Link>
            </div>
          ) : !allowed ? (
            <div
              role='status'
              className='rounded-xl border border-violet-200 bg-white p-5'
            >
              <h3 className='text-lg font-bold'>
                Mentor or School/Organization Account Required
              </h3>
              <p className='mt-2 text-sm leading-relaxed'>
                To submit an event request, log in with a mentor or
                school/organization account.
              </p>
              <Link
                to='/become-a-mentor'
                className='mt-4 inline-block text-sm font-bold text-violet-700 underline'
              >
                Become a Mentor
              </Link>
            </div>
          ) : reference ? (
            <div
              ref={success}
              tabIndex={-1}
              role='status'
              className='rounded-xl border border-green-200 bg-green-50 p-6 outline-none'
            >
              <CheckCircle2 size={40} className='mb-3 text-green-600' />
              <h3 className='text-xl font-bold'>
                Your event request has been received!
              </h3>
              <p className='mt-3 text-sm'>
                Our team will review your proposal and contact you using the
                details you provided. The team will confirm next steps with you
                before an event is published.
              </p>
              <p className='mt-4 break-all text-sm font-semibold'>
                Reference: {reference}
              </p>
              <Link
                to='/community-events'
                className='mt-5 inline-block font-bold text-violet-700 underline'
              >
                Browse Events
              </Link>
              <button
                type='button'
                className='mt-4 block text-sm font-bold text-violet-700 underline'
                onClick={() => {
                  requestKey.current = "";
                  lastPayload.current = "";
                  setReference("");
                }}
              >
                Submit Another Event Request
              </button>
            </div>
          ) : (
            <form
              id='event-hosting-form'
              ref={form}
              noValidate
              onSubmit={submit}
              className='space-y-3'
            >
              {error && (
                <p
                  role='alert'
                  className='rounded-lg bg-red-50 p-3 text-sm text-red-800'
                >
                  {error} Your details have been kept so you can try again.
                </p>
              )}
              <fieldset disabled={busy} className='min-w-0 space-y-3'>
                <Field
                  name='name'
                  label='Organization / Individual Name'
                  error={errors.name}
                >
                  <input
                    {...accessibility("name")}
                    autoComplete='organization'
                    required
                    maxLength={150}
                    placeholder='e.g. GreenTech Uganda'
                    className={input}
                    value={draft.name}
                    onChange={(e) => set("name", e.target.value)}
                  />
                </Field>
                <Field name='email' label='Email Address' error={errors.email}>
                  <input
                    {...accessibility("email")}
                    type='email'
                    autoComplete='email'
                    required
                    maxLength={254}
                    placeholder='e.g. info@yourorganization.org'
                    className={input}
                    value={draft.email}
                    onChange={(e) => set("email", e.target.value)}
                  />
                </Field>
                <div className='grid gap-3 sm:grid-cols-2'>
                  <Field
                    name='phone_number'
                    label='Phone Number'
                    error={errors.phone_number}
                  >
                    <PhoneInput
                      {...accessibility("phone_number")}
                      className='mt-1'
                      required
                      autoComplete='tel'
                      placeholder='Enter phone number'
                      value={draft.phone_number}
                      onChange={(value) => set("phone_number", value)}
                    />
                  </Field>
                  <Field
                    name='event_type'
                    label='Event Type'
                    error={errors.event_type}
                  >
                    <select
                      {...accessibility("event_type")}
                      required
                      className={input}
                      value={draft.event_type}
                      onChange={(e) => set("event_type", e.target.value)}
                    >
                      <option value=''>Select event type</option>
                      {Object.entries(hostingTypes).map(([value, label]) => (
                        <option key={value} value={value}>
                          {label}
                        </option>
                      ))}
                    </select>
                  </Field>
                </div>
                <Field name='title' label='Event Title' error={errors.title}>
                  <input
                    {...accessibility("title")}
                    required
                    maxLength={150}
                    placeholder='e.g. Digital Skills Workshop'
                    className={input}
                    value={draft.title}
                    onChange={(e) => set("title", e.target.value)}
                  />
                </Field>
                <Field
                  name='description'
                  label='Event Description'
                  error={errors.description}
                >
                  <textarea
                    {...accessibility("description")}
                    required
                    maxLength={500}
                    rows={4}
                    placeholder='Tell us about your event, objectives, target audience, and any special requirements...'
                    className={`${input} h-auto py-2`}
                    value={draft.description}
                    onChange={(e) => set("description", e.target.value)}
                  />
                  <p className='text-right text-[10px] text-slate-500'>
                    {draft.description.length} / 500
                  </p>
                </Field>
                <div className='grid gap-3 sm:grid-cols-2'>
                  <Field
                    name='preferred_date'
                    label='Preferred Date'
                    error={errors.preferred_date}
                  >
                    <input
                      {...accessibility("preferred_date")}
                      type='date'
                      min={today}
                      required
                      className={input}
                      value={draft.preferred_date}
                      onChange={(e) => set("preferred_date", e.target.value)}
                    />
                  </Field>
                  <Field
                    name='location'
                    label='Location (City/District)'
                    error={errors.location}
                  >
                    <input
                      {...accessibility("location")}
                      required
                      maxLength={150}
                      placeholder='e.g. Kampala'
                      className={input}
                      value={draft.location}
                      onChange={(e) => set("location", e.target.value)}
                    />
                  </Field>
                </div>
                <Field
                  name='additional_information'
                  label='Additional Information'
                  required={false}
                  error={errors.additional_information}
                >
                  <textarea
                    {...accessibility("additional_information")}
                    rows={3}
                    maxLength={300}
                    placeholder='Any other details we should know?'
                    className={`${input} h-auto py-2`}
                    value={draft.additional_information}
                    onChange={(e) =>
                      set("additional_information", e.target.value)
                    }
                  />
                  <p className='text-right text-[10px] text-slate-500'>
                    {draft.additional_information.length} / 300
                  </p>
                </Field>
                <div>
                  <label className='flex items-start gap-2 text-xs leading-relaxed'>
                    <input
                      {...accessibility("terms_accepted")}
                      type='checkbox'
                      required
                      checked={draft.terms_accepted}
                      onChange={(e) => set("terms_accepted", e.target.checked)}
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
                      id='hosting-terms_accepted-error'
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
                  editing
                    ? "Resubmitting Event Request..."
                    : "Submitting Event Request..."
                }
                className='inline-flex w-full items-center justify-center gap-2 rounded-lg bg-gradient-to-b from-violet-600 to-violet-800 px-4 py-3 text-sm font-bold text-white hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-60'
              >
                <Send size={18} />
                {editing ? "Resubmit Event Request" : "Submit Event Request"}
              </ButtonLoader>
              {editing && (
                <button
                  type='button'
                  disabled={busy}
                  className='text-sm font-bold text-violet-700 underline'
                  onClick={() => {
                    setEditing(null);
                    setDraft({ ...empty });
                    setErrors({});
                    setError("");
                  }}
                >
                  Cancel Changes
                </button>
              )}
            </form>
          )}
        </section>
      </div>
      {authenticated && (
        <MyEventRequests
          canSubmit={allowed}
          onEdit={(request) => {
            if (busy) return;
            setEditing(request);
            setDraft(hostingRequestFields(request));
            setReference("");
            setErrors({});
            setError("");
            requestAnimationFrame(() =>
              form.current?.scrollIntoView({
                block: "start",
                behavior: "smooth",
              }),
            );
          }}
        />
      )}
    </MainLayout>
  );
}
