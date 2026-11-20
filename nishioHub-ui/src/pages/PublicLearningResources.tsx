import { useEffect, useRef, useState, type FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  BarChart3,
  BookOpen,
  Bookmark,
  BriefcaseBusiness,
  Clock,
  Eye,
  FileText,
  Filter,
  Flame,
  FlaskConical,
  GraduationCap,
  Home,
  Layers,
  LoaderCircle,
  Monitor,
  PlaySquare,
  Rocket,
  ScrollText,
  Search,
  Star,
  Users,
} from "lucide-react";
import { toast } from "sonner";
import { MainLayout } from "@/components/layout/main-layout";
import { Skeleton } from "@/components/ui/skeleton";
import { ProgramCardSkeleton } from "@/components/loaders/ProgramCardSkeleton";
import { PageLoader } from "@/components/loaders/PageLoader";
import { operationError } from "@/components/admin/dashboard-operations";
import {
  getPublicLibrary,
  getResourceBookmarks,
  setResourceBookmark,
  libraryCategories,
  libraryFormats,
  libraryPaths,
  type PublicLearningResource,
} from "@/lib/public-learning-api";
import { assetUrl, usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";

const outline =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-violet-600 bg-white px-4 py-2 text-sm font-bold text-violet-700 hover:bg-violet-50 disabled:opacity-40";
const categoryIcons = [
  GraduationCap,
  Monitor,
  BriefcaseBusiness,
  BarChart3,
  Users,
  BookOpen,
  FileText,
  FlaskConical,
  Layers,
];
const formatIcons = [
  BookOpen,
  PlaySquare,
  ScrollText,
  BriefcaseBusiness,
  Layers,
];
const pathIcons = [GraduationCap, GraduationCap, GraduationCap, Users, Rocket];
const pathColors = [
  "from-violet-500 to-violet-800",
  "from-blue-500 to-blue-800",
  "from-emerald-500 to-emerald-800",
  "from-amber-400 to-orange-500",
  "from-pink-500 to-pink-700",
];
const pathDescriptions = [
  "Foundational skills & life learning",
  "Study skills, careers & exam prep",
  "Advanced skills, research & careers",
  "Workplace & leadership skills",
  "Business, innovation & growth",
];
const iconFor = (r: PublicLearningResource) =>
  r.format === "video"
    ? PlaySquare
    : r.format === "learning_path"
      ? GraduationCap
      : r.format === "toolkit"
        ? ScrollText
        : BookOpen;
function badge(r: PublicLearningResource) {
  return (
    (
      {
        study_material: "Guide",
        video: "Video",
        toolkit: "Toolkit",
        career_guide: "Guide",
        learning_path: "Course",
        other: "Resource",
      } as Record<string, string>
    )[r.format] || "Resource"
  );
}
function time(seconds: number) {
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}
function coverType(r: PublicLearningResource) {
  if (r.file_type === "application/pdf") return "PDF";
  if (r.file_type?.includes("word")) return "Document";
  if (r.file_type?.includes("sheet")) return "Spreadsheet";
  return badge(r);
}
function Cover({
  resource,
  small = false,
}: {
  resource: PublicLearningResource;
  small?: boolean;
}) {
  const [failed, setFailed] = useState(false);
  const Icon = iconFor(resource);
  return resource.thumbnail && !failed ? (
    <img
      src={assetUrl(resource.thumbnail)}
      alt={`${resource.title} cover`}
      loading='lazy'
      onError={() => setFailed(true)}
      className={
        small
          ? "h-16 w-24 shrink-0 rounded-lg object-cover"
          : "h-40 w-full object-cover"
      }
    />
  ) : (
    <div
      aria-hidden='true'
      className={`grid shrink-0 place-items-center bg-gradient-to-br from-violet-100 via-white to-blue-100 text-violet-700 ${small ? "h-16 w-24 rounded-lg" : "h-40 w-full"}`}
    >
      <Icon size={small ? 32 : 62} />
    </div>
  );
}
function ResourceMeta({ resource: r }: { resource: PublicLearningResource }) {
  return (
    <div className='flex flex-wrap items-center gap-x-4 gap-y-1 text-[10px] font-semibold text-[#24234f]'>
      {r.resource_type === "video" || r.resource_type === "course" ? (
        <span className='inline-flex items-center gap-1'>
          <BarChart3 size={14} />
          {r.level === "all"
            ? "All Levels"
            : r.level[0].toUpperCase() + r.level.slice(1)}
        </span>
      ) : (
        <span className='inline-flex items-center gap-1'>
          <FileText size={14} />
          {coverType(r)}
          {r.page_count
            ? ` · ${r.page_count} ${r.page_count === 1 ? "page" : "pages"}`
            : ""}
        </span>
      )}
      {r.duration_seconds !== null && (
        <span className='inline-flex items-center gap-1'>
          <Clock size={14} />
          {r.duration_seconds >= 60
            ? `${Math.floor(r.duration_seconds / 60)} min`
            : `${r.duration_seconds} sec`}
        </span>
      )}
      <span className='inline-flex items-center gap-1'>
        <Eye size={14} />
        {r.format === "study_material" ||
        r.format === "toolkit" ||
        r.format === "career_guide"
          ? `${r.downloads.toLocaleString()} ${r.downloads === 1 ? "download" : "downloads"}`
          : `${r.accesses.toLocaleString()} ${r.accesses === 1 ? "access" : "accesses"}`}
      </span>
    </div>
  );
}
export default function PublicLearningResources() {
  const platform = usePlatform();
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const client = useQueryClient();
  const [params, setParams] = useSearchParams();
  const searchInput = useRef<HTMLInputElement>(null);
  const results = useRef<HTMLElement>(null);
  const q = params.get("q") || "";
  const category = params.get("category") || "";
  const path = params.get("path") || "";
  const format = params.get("format") || "";
  const sort = params.get("sort") || "featured";
  const saved = params.get("saved") === "true";
  const featured = params.get("featured") === "true";
  const all = params.get("view") === "all";
  const [draft, setDraft] = useState(q);
  useEffect(() => setDraft(q), [q]);
  const expanded =
    all ||
    !!(
      q ||
      category ||
      path ||
      format ||
      saved ||
      featured ||
      sort !== "featured"
    );
  const page = /^[1-9]\d{0,3}$/.test(params.get("page") || "")
    ? Number(params.get("page"))
    : 1;
  useEffect(() => {
    const legacy = params.get("resource");
    if (legacy && /^[1-9]\d{0,11}$/.test(legacy))
      navigate(`/learn/${legacy}`, { replace: true });
  }, [params, navigate]);
  const [busy, setBusy] = useState<number[]>([]);
  const locks = useRef(new Set<number>());
  const library = useQuery({
    queryKey: [
      "public-library",
      saved ? user?.id : null,
      q,
      category,
      path,
      format,
      sort,
      page,
      expanded,
      saved,
      featured,
    ],
    queryFn: () =>
      getPublicLibrary({
        q,
        category,
        path,
        format,
        sort,
        page,
        per_page: expanded ? 9 : 3,
        saved: saved && !!user,
        featured,
      }),
    staleTime: 30000,
    refetchInterval: 60000,
  });
  const bookmarks = useQuery({
    queryKey: ["resource-bookmarks", user?.id],
    queryFn: getResourceBookmarks,
    enabled: !!user,
    staleTime: 30000,
  });
  const bookmarked = new Set(bookmarks.data?.resource_ids || []);
  function update(changes: Record<string, string>, resetPage = true) {
    const next = new URLSearchParams(params);
    if (resetPage) next.delete("page");
    Object.entries(changes).forEach(([key, value]) =>
      value ? next.set(key, value) : next.delete(key),
    );
    setParams(next, { replace: true, preventScrollReset: true });
  }
  function scroll() {
    results.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function filter(changes: Record<string, string>) {
    update(changes);
    requestAnimationFrame(scroll);
  }
  function search(event: FormEvent) {
    event.preventDefault();
    filter({ q: draft.trim(), view: "all" });
  }
  function open(resource: PublicLearningResource) {
    navigate(`/learn/${resource.id}`);
  }
  async function save(resource: PublicLearningResource) {
    if (isLoading || locks.current.has(resource.id)) return;
    if (!user) {
      navigate(
        `/login?return_to=${encodeURIComponent(`/learn/${resource.id}`)}`,
      );
      return;
    }
    if (bookmarks.isPending || bookmarks.isError) {
      toast.error("Saved resources could not be loaded. Please retry.");
      return;
    }
    locks.current.add(resource.id);
    setBusy((ids) => [...ids, resource.id]);
    try {
      await setResourceBookmark(resource.id, !bookmarked.has(resource.id));
      await Promise.all([
        client.invalidateQueries({ queryKey: ["resource-bookmarks", user.id] }),
        client.invalidateQueries({ queryKey: ["public-library"] }),
      ]);
      toast.success(
        bookmarked.has(resource.id)
          ? "Resource removed from saved resources"
          : "Resource saved",
      );
    } catch (error) {
      toast.error(operationError(error));
    } finally {
      locks.current.delete(resource.id);
      setBusy((ids) => ids.filter((id) => id !== resource.id));
    }
  }
  function renderSaveButton({
    resource: r,
  }: {
    resource: PublicLearningResource;
  }) {
    const pending = busy.includes(r.id);
    return (
      <button
        type='button'
        aria-label={`${bookmarked.has(r.id) ? "Unsave" : "Save"} ${r.title}`}
        aria-pressed={bookmarked.has(r.id)}
        aria-busy={pending}
        disabled={pending || isLoading || (!!user && bookmarks.isPending)}
        onClick={() => void save(r)}
        className='grid size-8 shrink-0 place-items-center rounded-lg bg-white/95 text-violet-700 shadow-sm hover:bg-violet-100 focus-visible:outline-violet-600 disabled:opacity-50'
      >
        {pending ? (
          <LoaderCircle
            size={18}
            className='animate-spin motion-reduce:animate-none'
          />
        ) : (
          <Bookmark
            size={21}
            className={bookmarked.has(r.id) ? "fill-violet-700" : ""}
          />
        )}
      </button>
    );
  }
  const heading =
    sort === "recent"
      ? "Recently Added"
      : sort === "popular"
        ? "Popular Resources"
        : saved
          ? "Saved Resources"
          : library.data?.items.length &&
              library.data.items.every((r) => r.featured)
            ? "Featured Resources"
            : "Explore Resources";
  function renderMiniSection({
    title,
    popular = false,
  }: {
    title: string;
    popular?: boolean;
  }) {
    const rows = popular ? library.data?.popular : library.data?.recent;
    const Icon = popular ? Flame : Clock;
    return (
      <section className='min-w-0 rounded-2xl border border-violet-100 bg-white p-4 shadow-sm'>
        <header className='mb-2 flex items-center justify-between gap-3 border-b border-violet-100 pb-3'>
          <h2 className='flex items-center gap-2 text-xl font-extrabold tracking-tight'>
            <Icon size={25} className='shrink-0 text-violet-700' />
            {title}
          </h2>
          <button
            type='button'
            className='inline-flex shrink-0 items-center gap-1 text-xs font-bold text-violet-700'
            onClick={() =>
              filter({
                sort: popular ? "popular" : "recent",
                view: "all",
                featured: "",
              })
            }
          >
            View All <ArrowRight size={15} />
          </button>
        </header>
        {library.isPending ? (
          <div
            role='status'
            aria-label={`Loading ${title}`}
            className='space-y-3'
          >
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className='h-16 w-full rounded-lg' />
            ))}
          </div>
        ) : library.isError ? (
          <p className='p-5 text-sm'>Resources could not be loaded.</p>
        ) : rows?.length ? (
          <div className='divide-y divide-violet-100'>
            {rows.map((r, index) => (
              <article key={r.id} className='flex items-start gap-3 py-3'>
                {popular && (
                  <span className='mt-3 grid size-7 shrink-0 place-items-center rounded-full bg-violet-700 text-sm font-bold text-white'>
                    {index + 1}
                  </span>
                )}
                <button
                  type='button'
                  className='shrink-0 rounded-lg focus-visible:outline-violet-600'
                  aria-label={`Preview ${r.title}`}
                  onClick={() => open(r)}
                >
                  <Cover resource={r} small />
                </button>
                <div className='min-w-0 flex-1'>
                  <button
                    type='button'
                    className='mb-2 text-left text-sm font-extrabold leading-tight hover:text-violet-700'
                    onClick={() => open(r)}
                  >
                    {r.title}
                  </button>
                  <ResourceMeta resource={r} />
                </div>
                {renderSaveButton({ resource: r })}
              </article>
            ))}
          </div>
        ) : (
          <p className='p-6 text-center text-sm text-slate-500'>
            {popular
              ? "Resource activity will appear here as learners open the materials."
              : "No matching resources have been published yet."}
          </p>
        )}
      </section>
    );
  }
  return (
    <MainLayout>
      <Helmet>
        <title>Learning Resources | {platform.platform_name}</title>
        <meta
          name='description'
          content='Explore study materials, video lessons, toolkits, career guides and learning paths on NishioHub.'
        />
      </Helmet>
      <section className='overflow-hidden bg-[#241347] text-white'>
        <div className='relative mx-auto max-w-[1440px] lg:min-h-[275px]'>
          <img
            src='/images/learning/library-hero.webp'
            alt='Illustrative mentor and learners exploring learning materials around a laptop'
            fetchPriority='high'
            className='h-56 w-full object-cover object-top lg:absolute lg:inset-y-0 lg:right-0 lg:h-full lg:w-[58%]'
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[51%] bg-yellow-400 lg:block'
            style={{ clipPath: "ellipse(100% 160% at 0% 0%)" }}
          />
          <div
            aria-hidden='true'
            className='absolute inset-y-0 left-0 hidden w-[48%] bg-gradient-to-r from-[#241347] to-violet-800 lg:block'
            style={{ clipPath: "ellipse(100% 180% at 0% 0%)" }}
          />
          <div className='relative px-6 py-6 lg:w-[47%] lg:px-10'>
            <p className='mb-3 inline-flex items-center gap-2 rounded-full bg-purple-400/50 px-3 py-1 text-sm font-bold'>
              <BookOpen size={22} />
              Learning Resources
            </p>
            <h1 className='text-4xl font-extrabold leading-tight tracking-tight xl:text-5xl'>
              Learning <span className='text-yellow-300'>Resources</span>
            </h1>
            <p className='mt-3 max-w-lg text-base leading-snug'>
              Access quality learning materials, toolkits and guides to build
              your skills, explore careers and achieve your goals.
            </p>
            <form
              onSubmit={search}
              className='mt-5 flex items-center gap-2 rounded-lg border border-violet-100 bg-white p-1.5 text-violet-800'
            >
              <Search size={23} className='ml-1 shrink-0' />
              <input
                ref={searchInput}
                aria-label='Search learning resources'
                maxLength={150}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                placeholder='Search resources (e.g. digital skills, study guide, career)…'
                className='h-9 min-w-0 flex-1 bg-transparent px-1 text-xs text-[#24234f] outline-none placeholder:text-slate-500'
              />
              <button
                type='submit'
                className='rounded-md bg-gradient-to-b from-violet-500 to-violet-800 px-4 py-2 text-sm font-bold text-white hover:brightness-110'
              >
                Search
              </button>
            </form>
          </div>
        </div>
      </section>
      <section
        aria-label='Resource formats'
        className='mx-auto grid max-w-[1440px] gap-3 px-4 py-5 sm:grid-cols-2 lg:grid-cols-5'
      >
        {Object.entries(libraryFormats)
          .filter(([key]) => key !== "other")
          .map(([key, label], i) => {
            const Icon = formatIcons[i];
            return (
              <button
                type='button'
                key={key}
                aria-pressed={format === key}
                onClick={() => filter({ format: format === key ? "" : key })}
                className={`flex items-center gap-3 rounded-xl border px-4 py-3 text-left shadow-sm transition hover:border-violet-500 ${format === key ? "border-violet-600 bg-violet-100" : "border-violet-100 bg-white"}`}
              >
                <Icon size={35} className='shrink-0 text-violet-700' />
                <div>
                  <h2 className='text-xs font-extrabold'>{label}</h2>
                  <p className='mt-1 text-[10px]'>
                    {
                      [
                        "Notes, guides and past papers",
                        "Expert-led learning videos",
                        "Practical resources and templates",
                        "Explore careers and pathways",
                        "Structured resources by goal",
                      ][i]
                    }
                  </p>
                </div>
              </button>
            );
          })}
      </section>
      <div className='mx-auto max-w-[1440px] px-4 pb-7'>
        <div className='grid items-start gap-5 lg:grid-cols-[260px_minmax(0,1fr)]'>
          <aside className='rounded-2xl border border-violet-100 bg-gradient-to-br from-white to-violet-50 p-3 shadow-sm'>
            <h2 className='mb-3 flex items-center gap-2 border-b border-violet-100 px-1 pb-3 text-lg font-extrabold'>
              <Filter size={22} className='text-violet-700' />
              Browse Resources
            </h2>
            <nav aria-label='Resource categories' className='space-y-1'>
              <button
                type='button'
                aria-pressed={!category && !saved}
                onClick={() => filter({ category: "", saved: "" })}
                className={`flex w-full items-center gap-3 rounded-lg px-3 py-3 text-left text-xs font-bold ${!category && !saved ? "bg-gradient-to-b from-violet-500 to-violet-800 text-white" : "hover:bg-violet-100"}`}
              >
                <Home size={23} />
                <span className='flex-1'>All Resources</span>
                <span>
                  {library.isPending ? "…" : `(${library.data?.total ?? 0})`}
                </span>
              </button>
              {Object.entries(libraryCategories)
                .filter(
                  ([key]) =>
                    key !== "general" || !!library.data?.categories.general,
                )
                .map(([key, label], i) => {
                  const Icon = categoryIcons[i];
                  return (
                    <button
                      type='button'
                      key={key}
                      aria-pressed={category === key}
                      onClick={() =>
                        filter({ category: category === key ? "" : key })
                      }
                      className={`flex w-full items-center gap-3 rounded-lg px-3 py-3 text-left text-xs font-bold ${category === key ? "bg-violet-700 text-white" : "hover:bg-violet-100"}`}
                    >
                      <Icon
                        size={23}
                        className={`shrink-0 ${category === key ? "" : "text-violet-700"}`}
                      />
                      <span className='min-w-0 flex-1'>{label}</span>
                      <span>
                        {library.isPending
                          ? "…"
                          : `(${library.data?.categories[key] || 0})`}
                      </span>
                    </button>
                  );
                })}
            </nav>
            <button
              type='button'
              aria-pressed={saved}
              onClick={() => filter({ saved: saved ? "" : "true" })}
              className={`mt-3 flex w-full items-center gap-3 rounded-lg border border-violet-200 px-3 py-3 text-xs font-bold ${saved ? "bg-violet-700 text-white" : "bg-white text-violet-700"}`}
            >
              <Bookmark size={20} />
              Saved Resources
              {user && bookmarks.data && (
                <span className='ml-auto'>
                  ({bookmarks.data.resource_ids.length})
                </span>
              )}
            </button>
            <Link
              to='/learn/courses'
              className='mt-3 flex items-center gap-3 rounded-lg border border-violet-200 bg-white px-3 py-3 text-xs font-bold text-violet-700 hover:bg-violet-50'
            >
              <GraduationCap size={20} />
              Browse Courses <ArrowRight size={15} className='ml-auto' />
            </Link>
            {(q || category || path || format || saved || featured || all) && (
              <button
                type='button'
                className='mt-3 w-full text-center text-xs font-bold text-violet-700 underline'
                onClick={() =>
                  setParams({}, { replace: true, preventScrollReset: true })
                }
              >
                Clear Filters
              </button>
            )}
          </aside>
          <div className='min-w-0'>
            <section ref={results} className='scroll-mt-24'>
              <header className='mb-4 flex flex-wrap items-center justify-between gap-3'>
                <h2 className='flex items-center gap-2 text-2xl font-extrabold tracking-tight'>
                  <Star
                    size={28}
                    className='shrink-0 fill-violet-700 text-violet-700'
                  />
                  {heading}
                </h2>
                <button
                  type='button'
                  className='inline-flex items-center gap-1 text-xs font-bold text-violet-700'
                  onClick={() =>
                    filter({
                      view: "all",
                      featured:
                        !expanded &&
                        library.data?.items.every((r) => r.featured) &&
                        library.data.items.length
                          ? "true"
                          : "",
                    })
                  }
                >
                  {!expanded &&
                  library.data?.items.length &&
                  library.data.items.every((r) => r.featured)
                    ? "View All Featured"
                    : "View All Resources"}{" "}
                  <ArrowRight size={16} />
                </button>
              </header>
              {bookmarks.isError && user && (
                <p
                  role='alert'
                  className='mb-3 rounded-lg bg-amber-50 p-3 text-xs'
                >
                  Saved resources could not be loaded.{" "}
                  <button
                    type='button'
                    className='font-bold underline'
                    onClick={() => bookmarks.refetch()}
                  >
                    Retry Saved Resources
                  </button>
                </p>
              )}
              {saved && !user && isLoading ? (
                <PageLoader label='Loading saved resources' rows={3} />
              ) : saved && !user ? (
                <div className='rounded-xl border border-violet-100 bg-violet-50 p-8 text-center'>
                  <Bookmark
                    className='mx-auto mb-3 text-violet-700'
                    size={32}
                  />
                  <p className='text-sm'>
                    Sign in to view your saved resources.
                  </p>
                  <Link
                    to='/login?return_to=%2Flearn%3Fsaved%3Dtrue'
                    className={`${outline} mt-4`}
                  >
                    Sign In <ArrowRight size={17} />
                  </Link>
                </div>
              ) : library.isPending ? (
                <div role='status' aria-busy='true'>
                  <span className='sr-only'>Loading learning resources</span>
                  <div className='grid gap-4 sm:grid-cols-2 xl:grid-cols-3'>
                    {[0, 1, 2].map((i) => (
                      <ProgramCardSkeleton key={i} />
                    ))}
                  </div>
                </div>
              ) : library.isError ? (
                <div
                  role='alert'
                  className='rounded-xl border border-red-100 bg-red-50 p-6 text-center'
                >
                  <p className='text-sm'>{operationError(library.error)}</p>
                  <button
                    type='button'
                    className={`${outline} mt-3`}
                    onClick={() => library.refetch()}
                  >
                    Retry Resources
                  </button>
                </div>
              ) : (
                <>
                  <div className='grid gap-4 sm:grid-cols-2 xl:grid-cols-3'>
                    {library.data.items.map((r) => {
                      const Icon = iconFor(r);
                      return (
                        <article
                          key={r.id}
                          className='flex min-w-0 flex-col overflow-hidden rounded-xl border border-violet-100 bg-white shadow-sm'
                        >
                          <div className='relative'>
                            <button
                              type='button'
                              aria-label={`Preview ${r.title}`}
                              className='block w-full focus-visible:outline-violet-600'
                              onClick={() => open(r)}
                            >
                              <Cover resource={r} />
                            </button>
                            <div className='absolute right-3 top-3'>
                              {renderSaveButton({ resource: r })}
                            </div>
                            <span className='absolute bottom-0 left-3 inline-flex items-center gap-1 rounded-t-lg bg-white px-3 py-1 text-xs font-bold text-violet-700'>
                              <Icon size={17} />
                              {badge(r)}
                            </span>
                            {r.duration_seconds !== null && (
                              <span className='absolute bottom-2 right-2 rounded bg-[#160c2e]/90 px-2 py-1 text-[10px] font-bold text-white'>
                                {time(r.duration_seconds)}
                              </span>
                            )}
                          </div>
                          <div className='flex flex-1 flex-col p-4'>
                            <button
                              type='button'
                              className='mb-3 text-left text-lg font-extrabold leading-tight tracking-tight hover:text-violet-700'
                              onClick={() => open(r)}
                            >
                              {r.title}
                            </button>
                            <div className='mt-auto'>
                              <ResourceMeta resource={r} />
                            </div>
                          </div>
                        </article>
                      );
                    })}
                  </div>
                  {!library.data.items.length && (
                    <div
                      role='status'
                      className='rounded-xl border border-violet-100 bg-white p-8 text-center text-sm'
                    >
                      <p>
                        {saved
                          ? "No saved resources match these filters."
                          : "No published resources match these filters."}
                      </p>
                      <button
                        type='button'
                        className={`${outline} mt-4`}
                        onClick={() =>
                          setParams(
                            {},
                            { replace: true, preventScrollReset: true },
                          )
                        }
                      >
                        Browse All Resources
                      </button>
                    </div>
                  )}
                  {expanded && library.data.meta.total_pages > 1 && (
                    <nav
                      aria-label='Learning resource pagination'
                      className='mt-5 flex flex-wrap items-center justify-center gap-3 text-xs'
                    >
                      <button
                        type='button'
                        className={outline}
                        disabled={page <= 1 || library.isFetching}
                        onClick={() =>
                          update({ page: String(page - 1) }, false)
                        }
                      >
                        Previous
                      </button>
                      <span>
                        Page {page} of {library.data.meta.total_pages} ·{" "}
                        {library.data.meta.total} resources
                      </span>
                      <button
                        type='button'
                        className={outline}
                        disabled={
                          page >= library.data.meta.total_pages ||
                          library.isFetching
                        }
                        onClick={() =>
                          update({ page: String(page + 1) }, false)
                        }
                      >
                        Next
                      </button>
                    </nav>
                  )}
                </>
              )}
            </section>
            <section className='mt-6'>
              <h2 className='mb-3 flex items-center gap-2 text-xl font-extrabold tracking-tight'>
                <Layers size={27} className='text-violet-700' />
                Explore by Learning Path
              </h2>
              <div className='grid gap-3 sm:grid-cols-2 xl:grid-cols-5'>
                {Object.entries(libraryPaths).map(([key, label], i) => {
                  const Icon = pathIcons[i];
                  return (
                    <button
                      type='button'
                      key={key}
                      aria-pressed={path === key}
                      onClick={() => filter({ path: path === key ? "" : key })}
                      className={`flex min-h-32 flex-col items-start rounded-xl bg-gradient-to-br p-4 text-left text-white transition hover:brightness-110 ${pathColors[i]} ${path === key ? "ring-4 ring-violet-200 ring-offset-2" : ""}`}
                    >
                      <Icon size={35} className='mb-2' />
                      <h3 className='text-sm font-extrabold leading-tight'>
                        {label}
                      </h3>
                      <p className='mt-2 text-xs leading-snug'>
                        {pathDescriptions[i]}
                      </p>
                      <ArrowRight size={20} className='ml-auto mt-auto' />
                    </button>
                  );
                })}
              </div>
            </section>
          </div>
        </div>
        <div className='mt-5 grid gap-4 lg:grid-cols-2'>
          {(!saved || user) && (
            <>
              {renderMiniSection({ title: "Recently Added" })}
              {renderMiniSection({ title: "Popular Resources", popular: true })}
            </>
          )}
        </div>
      </div>
    </MainLayout>
  );
}
