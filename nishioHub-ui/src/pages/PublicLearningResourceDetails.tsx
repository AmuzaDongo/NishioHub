import {videoSource} from '@/lib/video-source';
import {MediaLink,PlatformVideo,VideoDialog} from '@/components/media/platform-video';
import { useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Helmet } from "react-helmet-async";
import {
  ArrowRight,
  BarChart3,
  Bookmark,
  BookOpen,
  Calendar,
  CheckCircle2,
  ChevronRight,
  Clock,
  Download,
  ExternalLink,
  Eye,
  Home,
  Info,
  Layers,
  Lightbulb,
  MessageSquare,
  Play,
  Target,
  User,
  Users,
} from "lucide-react";
import { toast } from "sonner";
import { MainLayout } from "@/components/layout/main-layout";
import { Skeleton } from "@/components/ui/skeleton";
import { ResourceComments } from "@/components/resource-comments";
import { operationError } from "@/components/admin/dashboard-operations";
import { getPublicResourcePage } from "@/lib/resource-page-api";
import {
  getLearnerResource,
  getResourceCaptions,
} from "@/lib/resource-details-api";
import {
  getResourceBookmarks,
  setResourceBookmark,
  libraryCategories,
  libraryFormats,
} from "@/lib/public-learning-api";
import { assetUrl, platformDate, usePlatform } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { saveDownload } from "@/lib/achievements-api";
import api from "@/lib/axios";
const panel = "rounded-2xl border border-violet-100 bg-white p-5 shadow-sm";
const primary =
  "inline-flex items-center justify-center gap-2 rounded-lg bg-gradient-to-b from-violet-500 to-violet-800 px-5 py-2.5 text-sm font-bold text-white hover:brightness-110 disabled:opacity-50";
const outline =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-violet-600 bg-white px-4 py-2 text-sm font-bold text-violet-700 hover:bg-violet-50 disabled:opacity-50";
const bytes = (n: number) =>
  n >= 1048576 ? `${(n / 1048576).toFixed(1)} MB` : `${Math.ceil(n / 1024)} KB`;
export default function PublicLearningResourceDetails() {
  const { id: raw } = useParams();
  const id = Number(raw);
  const valid = /^[1-9]\d{0,11}$/.test(raw || "");
  const navigate = useNavigate();
  const { user, isLoading } = useAuth();
  const platform = usePlatform();
  const client = useQueryClient();
  const [tab, setTab] = useState("overview");
  const [busy, setBusy] = useState("");
  const lock = useRef(false);
  const [media, setMedia] = useState<{
    url: string;
    type: string;
    captions?: string;
  } | null>(null);
  const page = useQuery({
    queryKey: ["public-library-resource", id],
    queryFn: () => getPublicResourcePage(id),
    enabled: valid,
  });
  const access = useQuery({
    queryKey: ["learner-resource", user?.id, id],
    queryFn: () => getLearnerResource(id),
    enabled: valid && !!user && !!page.data,
  });
  const bookmarks = useQuery({
    queryKey: ["resource-bookmarks", user?.id],
    queryFn: getResourceBookmarks,
    enabled: !!user,
  });
  const r = page.data;
  const linkedVideo = r?.resource_type==='video'||!!r?.file_type?.startsWith('video/')||!!(access.data?.url&&videoSource(access.data.url));
  const saved = bookmarks.data?.resource_ids.includes(id) || false;
  useEffect(
    () => () => {
      if (media) {
        URL.revokeObjectURL(media.url);
        if (media.captions) URL.revokeObjectURL(media.captions);
      }
    },
    [media],
  );
  useEffect(() => {
    setMedia(null);
    setTab("overview");
  }, [id, user?.id]);
  function requireLogin() {
    if (isLoading) return false;
    if (!user) {
      navigate(`/login?return_to=${encodeURIComponent(`/learn/${id}`)}`);
      return false;
    }
    return true;
  }
  async function action(kind: string, run: () => Promise<void>) {
    if (!requireLogin() || lock.current) return;
    lock.current = true;
    setBusy(kind);
    try {
      await run();
      await client.invalidateQueries({
        queryKey: ["public-library-resource", id],
      });
    } catch (e) {
      toast.error(operationError(e));
    } finally {
      lock.current = false;
      setBusy("");
    }
  }
  async function file(download: boolean, contentId?: number) {
    await action(
      contentId ? `file-${contentId}` : download ? "download" : "watch",
      async () => {
        const detail = access.data || (await getLearnerResource(id));
        const fileInfo = contentId
          ? detail.contents.find((c) => c.id === contentId)?.file
          : detail.file;
        if (!fileInfo) {
          if(!download&&!contentId&&detail.url){await api.post(`/learning/resources/${id}/access`);setMedia({url:detail.url,type:'video/link'});return;}
          throw new Error("No file is available for this resource.");
        }
        const blob = (
          await api.get<Blob>(
            contentId
              ? `/learning/resources/${id}/contents/${contentId}/file`
              : `/learning/resources/${id}/file`,
            {
              params: download ? undefined : { preview: true },
              responseType: "blob",
            },
          )
        ).data;
        if (download) {
          saveDownload(blob, fileInfo.filename);
          return;
        }
        if (
          !/^(video|audio|image)\//.test(fileInfo.type) &&
          fileInfo.type !== "application/pdf"
        ) {
          saveDownload(blob, fileInfo.filename);
          return;
        }
        const captions = detail.captions
          ? await getResourceCaptions(id, true).catch(() => null)
          : null;
        setMedia({
          url: URL.createObjectURL(blob),
          type: fileInfo.type,
          captions: captions ? URL.createObjectURL(captions) : undefined,
        });
      },
    );
  }
  function bookmark() {
    void action("save", async () => {
      if (!bookmarks.data)
        throw new Error("Saved resources are still loading. Please retry.");
      await setResourceBookmark(id, !saved);
      await client.invalidateQueries({
        queryKey: ["resource-bookmarks", user?.id],
      });
      toast.success(
        saved ? "Resource removed from saved resources" : "Resource saved",
      );
    });
  }
  const d = r?.page_details;
  const title = (text: string, Icon = Info) => (
    <h2 className='mb-4 flex items-center gap-2 text-xl font-extrabold tracking-tight'>
      <Icon className='shrink-0 text-violet-700' size={25} />
      {text}
    </h2>
  );
  const downloads = r && (
    <section className={panel}>
      {title("Downloadable Resources", Download)}
      <div className='grid gap-3 md:grid-cols-3'>
        {r.supporting_resources.map((c) => (
          <article
            className='flex items-center gap-3 rounded-xl border border-violet-200 p-3'
            key={c.id}
          >
            <FileIcon type={c.file_type} />
            <div className='min-w-0 flex-1'>
              <h3 className='text-xs font-bold'>{c.title}</h3>
              <p className='mt-1 text-[11px] text-slate-500'>
                {c.size !== null ? bytes(c.size) : "External resource"}
              </p>
            </div>
            {c.has_file ? (
              <button
                className='text-violet-700 disabled:opacity-50'
                aria-label={`Download ${c.title}`}
                disabled={!!busy}
                onClick={() => void file(true, c.id)}
              >
                <Download size={20} />
              </button>
            ) : !user ? (
              <button
                className='text-violet-700'
                aria-label={`Open ${c.title}`}
                onClick={requireLogin}
              >
                <ExternalLink size={20} />
              </button>
            ) : access.data?.contents.find((x) => x.id === c.id)?.url ? (
              <MediaLink
                aria-label={`Open ${c.title}`}
                href={access.data.contents.find((x) => x.id === c.id)!.url!}
                target='_blank'
                rel='noopener noreferrer'
                className='text-violet-700'
                onClick={() => {
                  void api
                    .post(`/learning/resources/${id}/contents/${c.id}/access`)
                    .catch(() =>
                      toast.error("Could not record resource access"),
                    );
                }}
              >
                <ExternalLink size={20} />
              </MediaLink>
            ) : (
              <span className='text-xs'>
                {access.isPending ? "Loading…" : "Unavailable"}
              </span>
            )}
          </article>
        ))}
      </div>
      {!r.supporting_resources.length && (
        <p className='text-sm text-slate-500'>
          No additional downloads have been added.
        </p>
      )}
    </section>
  );
  return (
    <MainLayout>
      <Helmet>
        <title>
          {r?.title || "Resource Details"} | {platform.platform_name}
        </title>
      </Helmet>
      <div className='mx-auto max-w-[1440px] px-4 pb-8 text-[#171136]'>
        <nav
          aria-label='Breadcrumb'
          className='flex flex-wrap items-center gap-3 py-6 text-xs font-semibold'
        >
          <Link to='/' aria-label='Home'>
            <Home size={18} className='text-violet-700' />
          </Link>
          <ChevronRight size={14} />
          <Link to='/learn'>Learning Resources</Link>
          {r && (
            <>
              <ChevronRight size={14} />
              <Link to={`/learn?category=${r.category}`}>
                {libraryCategories[r.category]}
              </Link>
            </>
          )}
          <ChevronRight size={14} />
          <span>Resource Details</span>
        </nav>
        {!valid || page.isError ? (
          <section role='alert' className={panel}>
            <h1 className='text-2xl font-bold'>Resource unavailable</h1>
            <p className='my-3'>
              {valid
                ? operationError(page.error)
                : "Choose a valid learning resource."}
            </p>
            <Link to='/learn' className={outline}>
              Browse Resources
            </Link>
            {valid && (
              <button
                onClick={() => page.refetch()}
                className={`${outline} ml-3`}
              >
                Retry
              </button>
            )}
          </section>
        ) : page.isPending ? (
          <ResourceDetailsSkeleton />
        ) : (
          r &&
          d && (
            <div className='grid items-start gap-5 lg:grid-cols-[minmax(0,1fr)_320px]'>
              <div className='min-w-0 space-y-4'>
                <section className='grid items-center gap-5 md:grid-cols-[1.2fr_1fr]'>
                  <div className='relative overflow-hidden rounded-2xl bg-[#27174e]'>
                    {media && !media.type.startsWith('video/') ? (
                      media.type.startsWith("audio/") ? (
                        <div className='flex aspect-video items-center p-5'>
                          <audio
                            controls
                            autoPlay
                            src={media.url}
                            className='w-full'
                          />
                        </div>
                      ) : media.type === "application/pdf" ? (
                        <iframe
                          title={r.title}
                          src={media.url}
                          className='h-80 w-full'
                        />
                      ) : (
                        <img
                          src={media.url}
                          alt={r.title}
                          className='aspect-video w-full object-contain'
                        />
                      )
                    ) : (
                      <>
                        <img
                          src={
                            r.thumbnail
                              ? assetUrl(r.thumbnail)
                              : "/images/learning/library-hero.webp"
                          }
                          alt={r.title}
                          className='aspect-[1.4] w-full object-cover'
                        />
                        <div className='absolute inset-0 bg-gradient-to-t from-[#1f103b]/70 to-transparent' />
                        {(r.has_file || linkedVideo) && (
                          <button
                            className='absolute left-1/2 top-1/2 grid size-20 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border-4 border-white bg-black/20 text-white disabled:opacity-50'
                            disabled={!!busy || isLoading}
                            aria-label={`${linkedVideo?'Play':'Preview'} ${r.title}`}
                            onClick={() => void file(false)}
                          >
                            {busy==='watch'?<span className='text-xs font-bold'>Loading…</span>:<Play size={35} />}
                          </button>
                        )}
                        <p className='absolute inset-x-4 bottom-4 text-xl font-extrabold text-white'>
                          {r.title}
                        </p>
                      </>
                    )}
                  </div>
                  <div>
                    <div className='mb-3 flex flex-wrap gap-2 text-xs font-bold'>
                      <span className='rounded-full bg-violet-100 px-3 py-1 text-violet-700'>
                        {libraryFormats[r.format] || r.resource_type}
                      </span>
                      <span className='rounded-full bg-slate-100 px-3 py-1 capitalize'>
                        {r.level === "all" ? "All Levels" : r.level}
                      </span>
                    </div>
                    <h1 className='text-2xl font-extrabold leading-tight tracking-tight xl:text-3xl'>
                      {r.title}
                    </h1>
                    <p className='my-4 whitespace-pre-line text-sm leading-relaxed'>
                      {r.description}
                    </p>
                    <div className='mb-4 grid grid-cols-2 gap-3 text-xs'>
                      <span className='flex items-center gap-2'>
                        <Calendar size={19} className='text-violet-700' />
                        Updated: {platformDate(r.updated_at, platform)}
                      </span>
                      <span className='flex items-center gap-2'>
                        <Eye size={19} className='text-violet-700' />
                        {r.accesses.toLocaleString()} accesses
                      </span>
                      <span className='flex items-center gap-2'>
                        <Download size={19} className='text-violet-700' />
                        {r.downloads.toLocaleString()} downloads
                      </span>
                      {r.duration_seconds !== null && (
                        <span className='flex items-center gap-2'>
                          <Clock size={19} className='text-violet-700' />
                          {Math.ceil(r.duration_seconds / 60)} minutes
                        </span>
                      )}
                    </div>
                    <div className='space-y-2'>
                      {r.has_link && !linkedVideo &&
                        (!user ? (
                          <button
                            className={`${primary} w-full`}
                            onClick={requireLogin}
                          >
                            Sign In to Open Resource
                          </button>
                        ) : access.data?.url ? (
                          <MediaLink
                            video={r.resource_type === 'video'} href={access.data.url}
                            target='_blank'
                            rel='noopener noreferrer'
                            className={`${primary} w-full`}
                            onClick={() => {
                              void api
                                .post(`/learning/resources/${id}/access`)
                                .catch(() =>
                                  toast.error(
                                    "Could not record resource access",
                                  ),
                                );
                            }}
                          >
                            <ExternalLink size={18} />
                            Open Resource
                          </MediaLink>
                        ) : (
                          <p className='text-xs'>
                            {access.isPending
                              ? "Loading resource access…"
                              : "Resource link unavailable"}
                          </p>
                        ))}
                      <div className='flex gap-3'>
                        {r.has_file && (
                          <button
                            className={`${outline} flex-1`}
                            disabled={!!busy || isLoading}
                            onClick={() => void file(true)}
                          >
                            <Download size={18} />
                            {busy === "download"
                              ? "Downloading…"
                              : "Download Resource"}
                          </button>
                        )}
                        <button
                          aria-label={
                            saved ? "Unsave resource" : "Save resource"
                          }
                          aria-pressed={saved}
                          disabled={
                            !!busy ||
                            isLoading ||
                            (!!user && bookmarks.isPending)
                          }
                          onClick={bookmark}
                          className={outline}
                        >
                          <Bookmark
                            size={21}
                            className={saved ? "fill-violet-700" : ""}
                          />
                        </button>
                      </div>
                      {user && access.data?.can_participate && (
                        <Link
                          to={`/learning/resources/${id}`}
                          className='block pt-1 text-xs font-bold text-violet-700 underline'
                        >
                          Track your progress & feedback
                        </Link>
                      )}
                      {access.isError && (
                        <p role='alert' className='text-xs text-red-600'>
                          {operationError(access.error)}{" "}
                          <button
                            className='underline'
                            onClick={() => access.refetch()}
                          >
                            Retry access
                          </button>
                        </p>
                      )}
                    </div>
                  </div>
                </section>
                <nav
                  aria-label='Resource sections'
                  className='flex overflow-x-auto rounded-xl border border-violet-100 bg-white shadow-sm'
                >
                  {[
                    { key: "overview", label: "Overview", Icon: Info },
                    {
                      key: "resources",
                      label: `Resources (${r.supporting_resources.length})`,
                      Icon: Layers,
                    },
                    {
                      key: "takeaways",
                      label: "Key Takeaways",
                      Icon: CheckCircle2,
                    },
                    {
                      key: "comments",
                      label: `Comments (${r.comments_count})`,
                      Icon: MessageSquare,
                    },
                  ].map((t) => (
                    <button
                      key={t.key}
                      aria-current={tab === t.key ? "page" : undefined}
                      onClick={() => setTab(t.key)}
                      className={`flex flex-1 items-center justify-center gap-2 whitespace-nowrap px-4 py-3 text-sm font-bold ${tab === t.key ? "rounded-lg bg-gradient-to-b from-violet-500 to-violet-800 text-white" : "text-[#171136] hover:bg-violet-50"}`}
                    >
                      <t.Icon size={21} />
                      {t.label}
                    </button>
                  ))}
                </nav>
                {(tab === "overview" || tab === "takeaways") && (
                  <section className={panel}>
                    {tab === "overview" && (
                      <>
                        <h2 className='mb-3 text-xl font-extrabold'>
                          About This Resource
                        </h2>
                        <p className='mb-6 whitespace-pre-line text-sm leading-relaxed'>
                          {r.description ||
                            "Explore this learning resource at your own pace."}
                        </p>
                        {d.learning_outcomes.length > 0 && (
                          <>
                            {title("What You Will Learn", Target)}
                            <CheckList items={d.learning_outcomes} />
                          </>
                        )}
                      </>
                    )}
                    <div className='mt-5 grid gap-4 md:grid-cols-2'>
                      <div className='rounded-xl bg-amber-50 p-4'>
                        {title("Key Takeaways", Lightbulb)}
                        {d.takeaways.length ? (
                          <CheckList items={d.takeaways} />
                        ) : (
                          <p className='text-sm text-slate-500'>
                            Takeaways have not been added yet.
                          </p>
                        )}
                      </div>
                      <div className='rounded-xl bg-violet-50 p-4'>
                        {title("Who This Is For", Users)}
                        {d.audiences.length ? (
                          <CheckList items={d.audiences} />
                        ) : (
                          <p className='text-sm'>
                            {r.target_audience ||
                              "Learners interested in this subject."}
                          </p>
                        )}
                      </div>
                    </div>
                  </section>
                )}
                {(tab === "overview" || tab === "resources") && downloads}
                {(tab === "overview" || tab === "comments") && (
                  <ResourceComments key={`${id}-${user?.id}`} id={id} />
                )}
              </div>
              <aside className='space-y-4'>
                <section className={panel}>
                  {title("Resource Information")}
                  <dl className='divide-y divide-violet-100 text-xs'>
                    {[
                      ["Category", libraryCategories[r.category]],
                      ["Topic", d.topic || "General"],
                      ["Format", libraryFormats[r.format]],
                      ["Level", r.level === "all" ? "All Levels" : r.level],
                      [
                        "Language",
                        (
                          {
                            en: "English",
                            fr: "French",
                            sw: "Kiswahili",
                            lg: "Luganda",
                          } as Record<string, string>
                        )[r.language] || r.language,
                      ],
                      ["License", d.license_label || "Contact the publisher"],
                    ].map(([label, value]) => (
                      <div
                        key={label}
                        className='flex justify-between gap-4 py-3'
                      >
                        <dt className='font-bold'>{label}</dt>
                        <dd
                          className={`text-right capitalize ${label === "License" ? "rounded-lg bg-green-100 px-2 py-1 text-green-800" : ""}`}
                        >
                          {value}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </section>
                <section className={panel}>
                  {title("About the Author", User)}
                  <div className='mb-4 flex items-center gap-3'>
                    {d.author_photo_url ? (
                      <img
                        src={d.author_photo_url}
                        alt={d.author_name || "Resource author"}
                        className='size-20 rounded-full object-cover'
                      />
                    ) : (
                      <div className='grid size-16 shrink-0 place-items-center rounded-full bg-violet-100 text-violet-700'>
                        <User size={32} />
                      </div>
                    )}
                    <div>
                      <h3 className='font-extrabold'>
                        {d.author_name || platform.platform_name}
                      </h3>
                      {d.author_title && (
                        <p className='mt-1 text-xs'>{d.author_title}</p>
                      )}
                    </div>
                  </div>
                  <p className='whitespace-pre-line text-sm leading-relaxed'>
                    {d.author_bio ||
                      "Learning materials shared by the platform community."}
                  </p>
                  {d.author_profile_url && (
                    <MediaLink
                      href={d.author_profile_url}
                      target='_blank'
                      rel='noopener noreferrer'
                      className={`${outline} mt-4 w-full`}
                    >
                      View Profile <ExternalLink size={15} />
                    </MediaLink>
                  )}
                </section>
                <section className={panel}>
                  {title("Related Resources", BookOpen)}
                  <div className='divide-y divide-violet-100'>
                    {r.related.map((related) => (
                      <Link
                        key={related.id}
                        to={`/learn/${related.id}`}
                        className='flex items-center gap-3 py-3 hover:text-violet-700'
                      >
                        {related.thumbnail ? (
                          <img
                            src={assetUrl(related.thumbnail)}
                            alt=''
                            className='h-16 w-20 rounded-lg object-cover'
                          />
                        ) : (
                          <BookOpen className='size-12 shrink-0 rounded-lg bg-violet-50 p-2 text-violet-700' />
                        )}
                        <div>
                          <h3 className='text-xs font-bold'>{related.title}</h3>
                          <p className='mt-2 text-[10px]'>
                            {libraryFormats[related.format]}
                          </p>
                        </div>
                      </Link>
                    ))}
                  </div>
                  {!r.related.length && (
                    <p className='text-sm text-slate-500'>
                      More resources will appear here as they are published.
                    </p>
                  )}
                </section>
                <Link
                  className={`${panel} flex items-center gap-3 bg-violet-50 font-bold text-violet-700`}
                  to={`/learn?category=${r.category}`}
                >
                  <BarChart3 size={28} />
                  Explore More {libraryCategories[r.category]} Resources
                  <ArrowRight className='shrink-0' size={22} />
                </Link>
              </aside>
            </div>
          )
        )}
      </div>
      <VideoDialog open={!!media?.type.startsWith('video/')} onOpenChange={open=>{if(!open)setMedia(null);}} title={r?.title}>
        {media&&<PlatformVideo key={media.url} mimeType={media.type} src={media.url} title={r?.title} force captions={media.captions} language={r?.language}/>}
      </VideoDialog>
    </MainLayout>
  );
}
function CheckList({ items }: { items: string[] }) {
  return (
    <ul className='space-y-2 text-sm'>
      {items.map((item, i) => (
        <li className='flex items-start gap-2' key={i}>
          <CheckCircle2
            size={18}
            className='mt-0.5 shrink-0 fill-violet-700 text-white'
          />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}
function FileIcon({ type }: { type: string | null }) {
  return (
    <span
      className={`grid size-10 shrink-0 place-items-center rounded text-[10px] font-bold text-white ${type?.includes("sheet") ? "bg-green-600" : "bg-red-500"}`}
    >
      {type?.includes("sheet")
        ? "XLSX"
        : type === "application/pdf"
          ? "PDF"
          : "FILE"}
    </span>
  );
}

function ResourceDetailsSkeleton() {
  return (
    <div
      role='status'
      aria-busy='true'
      className='grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]'
    >
      <span className='sr-only'>Loading resource details</span>
      <div className='space-y-5'>
        <div className='grid gap-5 md:grid-cols-2'>
          <Skeleton className='aspect-[1.4] w-full rounded-2xl' />
          <div className='space-y-4 py-4'>
            <Skeleton className='h-7 w-2/3' />
            <Skeleton className='h-16 w-full' />
            <Skeleton className='h-20 w-full' />
            <Skeleton className='h-10 w-full' />
          </div>
        </div>
        <Skeleton className='h-12 w-full rounded-xl' />
        <Skeleton className='h-72 w-full rounded-xl' />
        <Skeleton className='h-40 w-full rounded-xl' />
      </div>
      <div className='space-y-5'>
        <Skeleton className='h-72 w-full rounded-2xl' />
        <Skeleton className='h-64 w-full rounded-2xl' />
        <Skeleton className='h-48 w-full rounded-2xl' />
      </div>
    </div>
  );
}
