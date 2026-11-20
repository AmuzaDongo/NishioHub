import { PageLoader } from "@/components/loaders/PageLoader";
import { ProgressLoader } from "@/components/loaders/ProgressLoader";
import { ButtonLoader } from "@/components/loaders/ButtonLoader";
import { useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  ClipboardList,
  Download,
  GraduationCap,
  Save,
  Send,
  ShieldCheck,
  Trash2,
  Users,
} from "lucide-react";
import { toast } from "sonner";
import {  MainLayout } from "@/components/layout/main-layout";
import { MentorApplicationFields } from "@/components/mentor-application-fields";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { operationError } from "@/components/admin/dashboard-operations";
import { saveDownload } from "@/lib/achievements-api";
import { useAuth } from "@/lib/auth-context";
import { usePlatform } from "@/lib/platform-context";
import { hasRole } from "@/lib/utils";
import api from "@/lib/axios";
import {
  applicationFields,
  applicationFormErrors,
  emptyApplication,
  experienceOptions,
  learnerOptions,
  qualificationOptions,
} from "@/lib/mentor-application-form";
import {
  applicationDocuments,
  downloadApplicationDocument,
  getMentorApplication,
  removeApplicationDocument,
  saveMentorApplication,
  submitMentorApplication,
  uploadApplicationDocument,
  type ApplicationFields,
  type ApplicationUpload,
  type MentorApplication as Application,
} from "@/lib/mentor-onboarding-api";
import { HomeAction } from "@/components/layout/home-action";
const button =
  "inline-flex items-center justify-center gap-2 rounded-xl border border-violet-500 bg-white px-5 py-2.5 text-sm font-bold text-violet-800 transition hover:bg-violet-50 disabled:cursor-not-allowed disabled:opacity-50";
const primary = `${button} !border-transparent bg-gradient-to-b from-violet-600 to-violet-800 !text-white`;
const steps = [
  "Personal Information",
  "Professional Details",
  "Experience & Expertise",
  "Review & Submit",
];
const why = [
  "Make a real impact in lives",
  "Share your expertise and experience",
  "Grow your professional network",
  "Gain recognition and a verified mentor profile",
  "Access learning and mentorship resources",
  "Be part of a purpose-driven community",
];
const who = [
  "Educators and school staff",
  "University students and recent graduates",
  "Professionals from various industries",
  "Entrepreneurs and business leaders",
  "Alumni and community role models",
];
export default function MentorApplication() {
  const { user, updateUser, isLoading } = useAuth();
  const platform = usePlatform();
  const navigate = useNavigate();
  const client = useQueryClient();
  const key = ["mentor-application", user?.id];
  const query = useQuery({
    queryKey: key,
    queryFn: getMentorApplication,
    enabled: !!user?.access_token,
    refetchOnWindowFocus: false,
    refetchInterval: (q) =>
      q.state.data?.status === "submitted" ? 30000 : false,
  });
  const submissionLock = useRef(false);
  const currentUserId = useRef(user?.id);
  currentUserId.current = user?.id;
  const data = query.data;
  const [draft, setDraft] = useState<ApplicationFields>({
    ...emptyApplication,
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [review, setReview] = useState(false);
  const [step, setStep] = useState(1);
  const [confirm, setConfirm] = useState(false);
  const [photoUrl, setPhotoUrl] = useState("");
  const card = useRef<HTMLElement>(null);
  useEffect(() => {
    if (data) {
      const values = applicationFields(data);
      if (data.form_version === 1 && data.editable) {
        values.full_name ||= user?.full_name || "";
        values.contact_email ||= user?.email || "";
      }
      setDraft(values);
      if (!data.editable) {
        setReview(true);
        setStep(4);
      }
    }
  }, [data, user?.full_name, user?.email]);
  useEffect(() => {
    if (data?.status === "approved" && !hasRole(user, "mentor")) {
      let cancelled = false;
      api
        .get("/users/me")
        .then((res) => {
          if (!cancelled) updateUser(res.data);
        })
        .catch(() => {
          /* A new sign-in also refreshes granted roles. */
        });
      return () => {
        cancelled = true;
      };
    }
  }, [data?.status, user, updateUser]);
  useEffect(() => {
    if (!user?.id) {
      setDraft({ ...emptyApplication });
      setReview(false);
      setStep(1);
      setError("");
      setErrors({});
      setConfirm(false);
    }
  }, [user?.id]);
  const photoStamp = data?.profile_photo?.uploaded_at;
  const photoName = data?.profile_photo?.filename;
  useEffect(() => {
    let cancelled = false;
    let url = "";
    setPhotoUrl("");
    if (photoName && user?.access_token) {
      downloadApplicationDocument("profile_photo")
        .then((blob) => {
          if (!cancelled) {
            url = URL.createObjectURL(blob);
            setPhotoUrl(url);
          }
        })
        .catch(() => {
          if (!cancelled)
            setError(
              "The photo preview could not load. Reload the application to retry.",
            );
        });
    }
    return () => {
      cancelled = true;
      if (url) URL.revokeObjectURL(url);
    };
  }, [photoStamp, photoName, user?.access_token]);
  const editable = !!user && !!data?.editable && !data.profile_verified;
  const dirty =
    !!data && JSON.stringify(applicationFields(data)) !== JSON.stringify(draft);
  const set = <K extends keyof ApplicationFields>(
    name: K,
    value: ApplicationFields[K],
  ) => {
    setDraft((current) => ({
      ...current,
      [name]: value,
      ...(name === "expertise_tags"
        ? { expertise: (value as string[]).join(", ") }
        : {}),
    }));
    setErrors((current) => ({ ...current, [name]: "" }));
  };
  const accept = (next: Application) => {
    client.setQueryData(key, next);
    if (currentUserId.current !== user?.id) return next;
    setDraft(applicationFields(next));
    setError("");
    return next;
  };
  async function persist() {
    if (!data) throw new Error("Sign in to save your application");
    return dirty
      ? accept(await saveMentorApplication(draft, data.lock_version))
      : data;
  }
  async function save() {
    if (!user) {
      navigate("/login?return_to=%2Fmentor%2Fapplication");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await persist();
      toast.success("Application draft saved");
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      setBusy(false);
    }
  }
  function scrollCard() {
    requestAnimationFrame(() =>
      card.current?.scrollIntoView({ block: "start" }),
    );
  }
  async function next() {
    if (!user) {
      navigate("/login?return_to=%2Fmentor%2Fapplication");
      return;
    }
    const invalid = applicationFormErrors(draft, !!data?.profile_photo);
    setErrors(invalid);
    if (Object.keys(invalid).length) {
      setError(
        "Complete the highlighted fields before reviewing your application.",
      );
      scrollCard();
      return;
    }
    setBusy(true);
    setError("");
    try {
      await persist();
      if (currentUserId.current !== user?.id) return;
      setReview(true);
      setStep(4);
      scrollCard();
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      setBusy(false);
    }
  }
  async function upload(kind: ApplicationUpload, file: File) {
    const photo = kind === "profile_photo";
    if (
      file.size > (photo ? 2 : 5) * 1024 * 1024 ||
      !(
        photo
          ? ["image/jpeg", "image/png"]
          : ["application/pdf", "image/jpeg", "image/png"]
      ).includes(file.type)
    ) {
      setError(
        photo
          ? "Choose a JPG or PNG profile photo up to 2 MB."
          : "Choose a PDF, JPG or PNG document up to 5 MB.",
      );
      return;
    }
    setBusy(true);
    setError("");
    try {
      const saved = await persist();
      if (currentUserId.current !== user?.id) return;
      accept(await uploadApplicationDocument(kind, file, saved.lock_version));
      setErrors((current) => ({ ...current, [kind]: "" }));
      toast.success(photo ? "Profile photo uploaded" : "Document uploaded");
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      setBusy(false);
    }
  }
  async function remove(kind: ApplicationUpload) {
    setBusy(true);
    setError("");
    try {
      const saved = await persist();
      if (currentUserId.current !== user?.id) return;
      accept(await removeApplicationDocument(kind, saved.lock_version));
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      setBusy(false);
    }
  }
  async function download(kind: ApplicationUpload, filename: string) {
    setBusy(true);
    try {
      saveDownload(await downloadApplicationDocument(kind), filename);
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      setBusy(false);
    }
  }
  async function prepareSubmit() {
    const invalid = applicationFormErrors(draft, !!data?.profile_photo);
    if (!draft.references_text.trim())
      invalid.references_text =
        "Include at least one reference, with permission to contact them.";
    if (data && Object.values(data.documents).some((value) => !value))
      invalid.documents = "Upload all three supporting documents.";
    if (Object.keys(invalid).length) {
      setErrors(invalid);
      setError("Complete the missing requirements before submitting.");
      scrollCard();
      return;
    }
    setBusy(true);
    setError("");
    try {
      const saved = await persist();
      if (currentUserId.current !== user?.id) return;
      if (saved.missing_requirements.length) {
        setError(saved.missing_requirements.join(". "));
        return;
      }
      setConfirm(true);
    } catch (failure) {
      setError(operationError(failure));
    } finally {
      setBusy(false);
    }
  }
  const navigateStep = (value: number) => {
    if (busy) return;
    if (value === 4) {
      if (editable) next();
      else {
        setReview(true);
        setStep(4);
      }
      return;
    }
    setReview(false);
    setStep(value);
    requestAnimationFrame(() =>
      document
        .getElementById(
          [
            "application-personal",
            "application-professional",
            "application-expertise",
          ][value - 1],
        )
        ?.scrollIntoView({ block: "start" }),
    );
  };
  const invalidFields = applicationFormErrors(draft, !!data?.profile_photo);
  const requiredFields = [
    "full_name",
    "contact_email",
    "phone_number",
    "location",
    "gender",
    "date_of_birth",
    "highest_qualification",
    "headline",
    "experience_range",
    "profile_photo",
    "expertise_tags",
    "target_learners",
    "background",
    "terms_accepted",
  ];
  const completed =
    requiredFields.filter((name) => !invalidFields[name]).length +
    Object.values(data?.documents || {}).filter(Boolean).length +
    (draft.references_text.trim() ? 1 : 0);
  const completion = !data
    ? 0
    : !data.editable && !data.missing_requirements.length
      ? 100
      : Math.round((completed / 18) * 100);
  async function submit() {
    if (!data || submissionLock.current) return;
    submissionLock.current = true;
    setBusy(true);
    setError("");
    try {
      accept(await submitMentorApplication(data));
      setConfirm(false);
      toast.success("Mentor application submitted");
    } catch (failure) {
      setError(operationError(failure));
      setConfirm(false);
    } finally {
      submissionLock.current = false;
      setBusy(false);
    }
  }
  const summary = [
    ["Full Name", draft.full_name],
    ["Email Address", draft.contact_email],
    ["Phone Number", draft.phone_number],
    ["Location", draft.location],
    ["Gender", draft.gender.replace(/_/g, " ")],
    ["Date of Birth", draft.date_of_birth],
    [
      "Highest Qualification",
      qualificationOptions[
        draft.highest_qualification as keyof typeof qualificationOptions
      ] || draft.highest_qualification,
    ],
    ["Current Occupation / Role", draft.headline],
    ["Organization / Institution", draft.organization],
    [
      "Years of Experience",
      experienceOptions[
        draft.experience_range as keyof typeof experienceOptions
      ] || String(draft.years_of_experience),
    ],
    ["Areas of Expertise", draft.expertise_tags.join(", ") || draft.expertise],
    [
      "Target Learners",
      draft.target_learners
        .map((value) => learnerOptions[value as keyof typeof learnerOptions])
        .join(", "),
    ],
    ["Short Bio", draft.background],
  ];
  return (
    <MainLayout>
      <Helmet>
        <title>Mentor Application | {platform.platform_name}</title>
        <meta
          name='description'
          content='Apply to become a mentor. Share your experience, expertise and passion for supporting the next generation.'
        />
      </Helmet>
      <section className='relative overflow-hidden bg-[#27103e] text-white'>
        <div className='relative mx-auto min-h-[225px] max-w-[1440px]'>
          <img
            src='/images/onboarding/mentor-hero.webp'
            alt='A welcoming professional mentor'
            fetchPriority='high'
            className='h-52 w-full object-cover object-[center_12%] lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[70%]'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[53%] bg-yellow-400 lg:block'
            style={{ clipPath: "ellipse(100% 140% at 0% 40%)" }}
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[51%] bg-gradient-to-r from-[#291345] to-violet-800 lg:block'
            style={{ clipPath: "ellipse(100% 140% at 0% 70%)" }}
          />
          <div className='relative px-6 py-5 lg:w-[50%] lg:px-10'>
            <Link
              to='/become-a-mentor'
              className='mb-2 inline-flex items-center gap-2 rounded-full bg-violet-500 px-4 py-1 text-sm font-bold'
            >
              <Users size={23} />
              Become a Mentor
            </Link>
            <h1 className='text-4xl font-extrabold tracking-tight lg:text-[42px] xl:text-[44px]'>
              Apply to Be a Mentor
            </h1>
            <p className='mt-2 max-w-lg text-base font-medium leading-snug lg:text-lg'>
              Share your knowledge, experience and passion to inspire and guide
              learners, students and young professionals on{" "}
              {platform.platform_name}.
            </p>
          </div>
          <blockquote className='absolute right-5 top-8 hidden w-56 rounded-[22px] bg-white/95 p-5 text-base font-bold leading-tight text-[#160b33] shadow-lg lg:block'>
            <span
              aria-hidden='true'
              className='block h-7 text-5xl leading-none text-violet-700'
            >
              “
            </span>
            “Mentorship creates opportunities, builds confidence and shapes the
            next generation.”
            <span
              aria-hidden='true'
              className='mx-auto mt-3 block h-2 w-28 rounded-t-[100%] border-t-4 border-yellow-400'
            />
          </blockquote>
        </div>
      </section>
      <div className='mx-auto grid max-w-[1440px] gap-4 px-4 py-4 lg:grid-cols-[300px_minmax(0,1fr)]'>
        <aside className='order-2 space-y-6 lg:order-1'>
          {[
            {
              title: `Why Mentor on ${platform.platform_name}?`,
              Icon: Users,
              items: why,
            },
            { title: "Who Can Apply?", Icon: GraduationCap, items: who },
          ].map((panel) => (
            <section
              key={panel.title}
              className='rounded-2xl border border-violet-200 bg-gradient-to-br from-white to-violet-50 p-5 shadow-sm shadow-violet-100'
            >
              <h2 className='mb-5 flex items-center gap-3 text-xl font-extrabold leading-tight tracking-tight'>
                <panel.Icon size={48} className='shrink-0 text-violet-700' />
                {panel.title}
              </h2>
              <ul className='space-y-4'>
                {panel.items.map((value) => (
                  <li
                    key={value}
                    className='flex items-start gap-3 text-sm font-medium leading-snug'
                  >
                    <CheckCircle2
                      size={21}
                      fill='currentColor'
                      className='mt-0.5 shrink-0 text-violet-700 stroke-white'
                    />
                    <span>{value}</span>
                  </li>
                ))}
              </ul>
            </section>
          ))}
          <img
            src='/images/onboarding/graduation-books.webp'
            alt=''
            loading='lazy'
            className='mx-auto hidden h-52 w-72 object-contain lg:block'
          />
        </aside>
        <section
          ref={card}
          className='order-1 min-w-0 scroll-mt-24 rounded-2xl lg:order-2 border border-violet-200 bg-white p-4 shadow-sm shadow-violet-100 md:p-5'
        >
          <header className='mb-5 flex items-start gap-3'>
            <ClipboardList size={47} className='shrink-0 text-violet-700' />
            <div>
              <h2 className='text-2xl font-extrabold tracking-tight'>
                Mentor Application Form
              </h2>
              <p className='text-sm'>
                Complete the form below to join our verified mentor community.
              </p>
            </div>
          </header>
          <ProgressLoader
            steps={steps}
            currentStep={step}
            progress={completion}
            disabled={busy}
            onStepChange={navigateStep}
          />
          {isLoading || (user && query.isPending) ? (
            <PageLoader label='Loading your application' />
          ) : query.isError && user ? (
            <div role='alert' className='rounded-lg bg-red-50 p-4 text-sm'>
              <p>{operationError(query.error)}</p>
              <button
                className={`${button} mt-3`}
                onClick={() => query.refetch()}
              >
                Reload Application
              </button>
            </div>
          ) : (
            <>
              {data &&
                (!data.editable ||
                  data.status === "changes_requested" ||
                  data.profile_verified) && (
                  <div className='mb-5 rounded-xl bg-violet-50 p-4 text-sm'>
                    <p className='flex items-center gap-2 font-bold capitalize'>
                      <ShieldCheck className='text-violet-700' />
                      {data.profile_verified || data.status === "approved"
                        ? "Approved — Ready to Mentor"
                        : data.status.replace(/_/g, " ")}
                    </p>
                    {data.status === "submitted" && (
                      <p className='mt-2'>
                        Your application is under review. Allow approximately
                        1–3 days; timing can vary. You’ll receive an in-app
                        notification when the review is complete.
                      </p>
                    )}
                    {data.review_note && (
                      <p className='mt-2 whitespace-pre-wrap'>
                        <strong>Reviewer feedback: </strong>
                        {data.review_note}
                      </p>
                    )}
                    {(data.profile_verified || data.status === "approved") && (
                      <div className='mt-3'>
                        <HomeAction to='/mentor/profile'>
                          Complete Mentor Profile & Availability
                        </HomeAction>
                        <p className='mt-2 text-xs'>
                          Set your availability and publish your profile when
                          ready. Sign in again if your new mentor role has not
                          appeared yet.
                        </p>
                      </div>
                    )}
                    {data.status === "rejected" && (
                      <Link
                        to='/contact?category=mentorship'
                        className='mt-2 inline-block text-violet-700 underline'
                      >
                        Contact support about the decision
                      </Link>
                    )}
                  </div>
                )}
              {error && user && (
                <div
                  role='alert'
                  className='mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-800'
                >
                  <p>{error}</p>
                  {data && (
                    <button
                      type='button'
                      className='mt-2 underline'
                      disabled={busy}
                      onClick={() => {
                        setError("");
                        setErrors({});
                        query.refetch();
                      }}
                    >
                      Reload Saved Application (replaces unsaved changes)
                    </button>
                  )}
                </div>
              )}
              {!review || !user ? (
                <form
                  noValidate
                  onSubmit={(event) => {
                    event.preventDefault();
                    save();
                  }}
                >
                  <MentorApplicationFields
                    key={user?.id || "guest"}
                    draft={user ? draft : emptyApplication}
                    set={set}
                    errors={errors}
                    disabled={!editable || busy}
                    photoUrl={user ? photoUrl : ""}
                    hasPhoto={!!data?.profile_photo}
                    onPhoto={(file) => upload("profile_photo", file)}
                    onRemovePhoto={() => remove("profile_photo")}
                    onStep={setStep}
                  />
                  {!user && (
                    <p className='mt-4 text-xs text-violet-900'>
                      Sign in to save your application and upload documents
                      privately.{" "}
                      <Link
                        className='font-bold underline'
                        to='/login?return_to=%2Fmentor%2Fapplication'
                      >
                        Log In to Apply
                      </Link>
                      {platform.registration_enabled && (
                        <>
                          {" "}
                          or{" "}
                          <Link
                            className='font-bold underline'
                            to='/register?role=mentor&return_to=%2Fmentor%2Fapplication'
                          >
                            Create Mentor Account
                          </Link>
                        </>
                      )}
                      .
                      {!platform.registration_enabled && (
                        <>
                          {" "}
                          New registration is closed;{" "}
                          <Link
                            className='underline'
                            to='/contact?category=mentorship'
                          >
                            contact the team
                          </Link>{" "}
                          for help.
                        </>
                      )}
                    </p>
                  )}
                  <footer className='mt-6 flex flex-wrap items-center justify-between gap-3'>
                    <button
                      type='submit'
                      className={button}
                      disabled={busy || (!!user && !editable)}
                    >
                      <Save size={19} />
                      {busy ? "Saving…" : "Save Draft"}
                    </button>
                    <button
                      type='button'
                      className={primary}
                      disabled={busy || (!!user && !editable)}
                      onClick={next}
                    >
                      Next: Review & Submit <ArrowRight size={20} />
                    </button>
                  </footer>
                  {data && (
                    <p role='status' className='mt-3 text-xs text-slate-500'>
                      {dirty ? "Unsaved changes" : "Your progress is saved"}
                    </p>
                  )}
                </form>
              ) : (
                <div className='space-y-5'>
                  <h3 className='rounded-lg bg-violet-100 px-3 py-2 text-lg font-extrabold'>
                    4 · Review & Submit
                  </h3>
                  <div className='grid gap-x-5 gap-y-3 rounded-xl border border-violet-100 p-4 text-sm sm:grid-cols-2'>
                    {summary.map(([label, value]) => (
                      <div
                        key={label}
                        className={label === "Short Bio" ? "sm:col-span-2" : ""}
                      >
                        <p className='font-bold'>{label}</p>
                        <p className='whitespace-pre-wrap break-words text-slate-700'>
                          {value || "Not provided"}
                        </p>
                      </div>
                    ))}
                  </div>
                  {photoUrl && (
                    <img
                      src={photoUrl}
                      alt='Your application profile photo'
                      className='size-24 rounded-xl object-cover'
                    />
                  )}
                  <section>
                    <h3 className='mb-2 text-lg font-bold'>
                      Supporting Documents & References
                    </h3>
                    <p className='mb-4 text-xs text-slate-600'>
                      PDF, JPEG or PNG, up to 5 MB each. Identity and supporting
                      documents stay private. Your draft is saved before each
                      upload.
                    </p>
                    <div className='space-y-3'>
                      {Object.entries(applicationDocuments).map(
                        ([kind, label]) => {
                          const typed =
                            kind as keyof typeof applicationDocuments;
                          const file = data?.documents[typed];
                          return (
                            <div
                              key={kind}
                              className='rounded-lg border border-violet-200 p-3'
                            >
                              <p className='flex items-center gap-2 text-sm font-bold'>
                                {file && (
                                  <CheckCircle2
                                    size={17}
                                    className='text-green-600'
                                  />
                                )}
                                {label}
                              </p>
                              {file && (
                                <div className='mt-2 flex flex-wrap items-center gap-3 text-xs'>
                                  <span className='break-all'>
                                    {file.filename} ·{" "}
                                    {(file.size / 1024).toFixed(0)} KB
                                  </span>
                                  <button
                                    type='button'
                                    className='inline-flex items-center gap-1 font-bold text-violet-700'
                                    disabled={busy}
                                    onClick={() =>
                                      download(typed, file.filename)
                                    }
                                  >
                                    <Download size={15} />
                                    Download
                                  </button>
                                  {editable && (
                                    <button
                                      type='button'
                                      className='inline-flex items-center gap-1 font-bold text-red-600'
                                      disabled={busy}
                                      onClick={() => remove(typed)}
                                    >
                                      <Trash2 size={15} />
                                      Remove
                                    </button>
                                  )}
                                </div>
                              )}
                              {editable && (
                                <label className='mt-2 block text-xs'>
                                  {file
                                    ? "Replace document"
                                    : "Upload document"}
                                  <input
                                    aria-label={`Upload ${label}`}
                                    type='file'
                                    accept='application/pdf,image/jpeg,image/png'
                                    className='mt-1 w-full rounded border border-violet-100 p-2'
                                    disabled={busy}
                                    onChange={(e) => {
                                      const selected = e.target.files?.[0];
                                      e.target.value = "";
                                      if (selected) upload(typed, selected);
                                    }}
                                  />
                                </label>
                              )}
                            </div>
                          );
                        },
                      )}
                    </div>
                    {errors.documents && (
                      <p role='alert' className='mt-2 text-xs text-red-700'>
                        {errors.documents}
                      </p>
                    )}
                    <label className='mt-4 block text-sm font-bold'>
                      Professional / Community References{" "}
                      <span className='text-red-600'>*</span>
                      <textarea
                        name='references_text'
                        maxLength={2000}
                        rows={3}
                        disabled={!editable || busy}
                        className='mt-1 w-full rounded-lg border border-violet-200 p-3 text-sm font-normal'
                        placeholder='Include a reference’s name, relationship and contact details, with permission to contact them.'
                        value={draft.references_text}
                        onChange={(e) => set("references_text", e.target.value)}
                      />
                    </label>
                    {errors.references_text && (
                      <p role='alert' className='mt-1 text-xs text-red-700'>
                        {errors.references_text}
                      </p>
                    )}
                  </section>
                  {data?.missing_requirements.length ? (
                    <div className='rounded-lg bg-violet-50 p-3 text-sm'>
                      <p className='mb-1 font-bold'>
                        Saved application requirements remaining
                      </p>
                      <ul className='list-inside list-disc space-y-1'>
                        {data.missing_requirements.map((value) => (
                          <li key={value}>{value}</li>
                        ))}
                      </ul>
                    </div>
                  ) : null}
                  <footer className='flex flex-wrap justify-between gap-3'>
                    <button
                      type='button'
                      className={button}
                      disabled={busy}
                      onClick={() => navigateStep(1)}
                    >
                      <ArrowLeft size={17} />
                      Back to Form
                    </button>
                    {editable && (
                      <div className='flex gap-3'>
                        <button
                          type='button'
                          className={button}
                          disabled={busy}
                          onClick={save}
                        >
                          <Save size={17} />
                          Save Draft
                        </button>
                        <button
                          type='button'
                          className={primary}
                          disabled={busy}
                          onClick={prepareSubmit}
                        >
                          <Send size={17} />
                          Submit Application
                        </button>
                      </div>
                    )}
                  </footer>
                  <p className='text-xs text-slate-500'>
                    Contact details are saved with this application. Policy
                    version {data?.policy_version_current}.
                  </p>
                </div>
              )}
            </>
          )}
        </section>
      </div>
      <Dialog
        open={confirm}
        onOpenChange={(value) => {
          if (!busy) setConfirm(value);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Submit your mentor application?</DialogTitle>
            <DialogDescription>
              Your application and documents will be locked during review. You
              confirm the information is accurate and accept the Code of
              Conduct, Safeguarding Policy and Terms of Service.
            </DialogDescription>
          </DialogHeader>
          <div className='flex justify-end gap-3'>
            <button
              className={button}
              disabled={busy}
              onClick={() => setConfirm(false)}
            >
              Keep Editing
            </button>
            <ButtonLoader
              className={primary}
              loading={busy}
              loadingText='Submitting Application...'
              onClick={submit}
            >
              Apply to Be a Mentor
            </ButtonLoader>
          </div>
        </DialogContent>
      </Dialog>
    </MainLayout>
  );
}
