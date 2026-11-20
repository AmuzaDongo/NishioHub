import {videoSource} from '@/lib/video-source';
import {MediaLink,PlatformVideo,VideoDialog} from '@/components/media/platform-video';
import { PageLoader } from "@/components/loaders/PageLoader";
import { useEffect, useState } from "react";
import { Link, Navigate, useParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  BookOpen,
  Download,
  ExternalLink,
  PlayCircle,
  Star,
} from "lucide-react";
import { MainLayout } from "@/components/layout/main-layout";
import { useAuth } from "@/lib/auth-context";
import api from "@/lib/axios";
import {
  getLearnerResource,
  getResourceCaptions,
  submitResourceFeedback,
  updateResourceProgress,
} from "@/lib/resource-details-api";
import { operationError } from "@/components/admin/dashboard-operations";
import { saveDownload } from "@/lib/achievements-api";
import { toast } from "sonner";
const button =
  "inline-flex items-center justify-center gap-2 rounded-lg bg-violet-700 px-4 py-2 text-sm font-bold text-white disabled:opacity-40";
const input = "w-full rounded-lg border border-violet-200 p-3 text-sm";
export default function LearnerResource() {
  const { id: raw } = useParams();
  const id = Number(raw);
  const valid = /^[1-9]\d*$/.test(raw || "") && Number.isSafeInteger(id);
  const { user, isLoading } = useAuth();
  const client = useQueryClient();
  const [percent, setPercent] = useState(0);
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState("");
  const [media, setMedia] = useState<{
    url: string;
    type: string;
    captions?: string;
    start: number;
  } | null>(null);
  const query = useQuery({
    queryKey: ["learner-resource", user?.id, id],
    queryFn: () => getLearnerResource(id),
    enabled: !!user && valid,
  });
  const r = query.data;
  const videoResource=!!r&&(r.resource_type==='video'||!!r.file?.type.startsWith('video/')||!!videoSource(r.url||''));
  useEffect(() => {
    if (r) {
      setPercent(r.progress?.percent || 0);
      setRating(r.feedback?.rating || 5);
      setComment(r.feedback?.comment || "");
    }
  }, [r]);
  useEffect(
    () => () => {
      if (media?.url.startsWith("blob:")) URL.revokeObjectURL(media.url);
      if (media?.captions) URL.revokeObjectURL(media.captions);
    },
    [media?.url, media?.captions],
  );
  const refresh = async () => {
    await Promise.all(
      [
        "learner-resource",
        "resource-overview",
        "resource-section",
        "admin-resources",
        "learning-area",
      ].map((k) => client.invalidateQueries({ queryKey: [k] })),
    );
  };
  const progress = useMutation({
    mutationFn: (value: number) =>
      updateResourceProgress(id, value, r?.progress?.lock_version || 0),
    onSuccess: async () => {
      await refresh();
      toast.success("Progress saved");
    },
    onError: (e) => toast.error(operationError(e)),
  });
  const feedback = useMutation({
    mutationFn: () => submitResourceFeedback(id, rating, comment),
    onSuccess: async () => {
      await refresh();
      toast.success("Feedback saved");
    },
    onError: (e) => toast.error(operationError(e)),
  });
  const preview = useMutation({
    mutationFn: async ({
      start = 0,
      download = false,
    }: {
      start?: number;
      download?: boolean;
    }) => {
      if (!r?.file) throw new Error("No resource file is available");
      const blob = (
        await api.get<Blob>(`/learning/resources/${id}/file`, {
          responseType: "blob",
        })
      ).data;
      if (download || !/^(video|audio|image)\//.test(r.file.type)) {
        saveDownload(blob, r.file.filename);
        return null;
      }
      const caption = r.captions ? await getResourceCaptions(id, true) : null;
      return {
        url: URL.createObjectURL(blob),
        type: r.file.type,
        captions: caption ? URL.createObjectURL(caption) : undefined,
        start,
      };
    },
    onSuccess: async (value) => {
      if (value) setMedia(value);
      await refresh();
    },
    onError: (e) => toast.error(operationError(e)),
  });
  const access = async (content?: number) => {
    try {
      await api.post(
        content
          ? `/learning/resources/${id}/contents/${content}/access`
          : `/learning/resources/${id}/access`,
      );
      await refresh();
    } catch (e) {
      toast.error(operationError(e));
    }
  };
  if (isLoading) return <PageLoader label='Loading resource…' />;
  if (!user)
    return (
      <Navigate
        to={`/login?return_to=${encodeURIComponent(`/learn?resource=${id}`)}`}
        replace
      />
    );
  return (
    <MainLayout>
      <main className='mx-auto max-w-5xl space-y-5 px-4 py-8'>
        <Link className='text-sm font-bold text-violet-700' to='/learn'>
          ← Back to Learning Resources
        </Link>
        {!valid || query.isError ? (
          <section
            className='rounded-2xl border border-violet-100 bg-white p-8'
            role='alert'
          >
            <h1 className='text-2xl font-bold'>Resource unavailable</h1>
            <p className='mt-2'>
              {valid
                ? operationError(query.error)
                : "Choose a learning resource."}
            </p>
            {valid && (
              <button
                className={`${button} mt-4`}
                onClick={() => query.refetch()}
              >
                Retry
              </button>
            )}
          </section>
        ) : query.isPending ? (
          <PageLoader label='Loading learning content…' />
        ) : (
          r && (
            <>
              <section className='space-y-4 rounded-2xl border border-violet-100 bg-white p-6'>
                {videoResource&&<div className="relative grid aspect-[16/9] place-items-center overflow-hidden rounded-xl bg-gradient-to-br from-violet-950 to-violet-600 text-white"><BookOpen size={90} className="opacity-30"/><p className="absolute bottom-5 left-5 right-5 text-xl font-bold">{r.title}</p><button aria-label={`Play ${r.title}`} disabled={preview.isPending} className="absolute left-1/2 top-1/2 grid size-20 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border-2 border-white bg-black/30 disabled:opacity-50" onClick={()=>{if(r.file)preview.mutate({});else if(r.url){setMedia({url:r.url,type:'video/link',start:0});void access();}}}><PlayCircle size={48}/></button></div>}
                <h1 className='flex items-center gap-3 text-3xl font-extrabold'>
                  <BookOpen className='shrink-0 text-violet-700' />
                  {r.title}
                </h1>
                <p className='whitespace-pre-line text-sm'>{r.description}</p>
                <div className='flex flex-wrap gap-2'>
                  {r.tags.map((t, i) => (
                    <span
                      className='rounded-full bg-violet-100 px-3 py-1 text-xs text-violet-700'
                      key={i}
                    >
                      {t}
                    </span>
                  ))}
                </div>
                <div className='flex flex-wrap gap-3'>
                  {r.url && !videoResource && (
                    <MediaLink
                      video={r.resource_type==='video'} href={r.url}
                      target='_blank'
                      rel='noopener noreferrer'
                      className={button}
                      onClick={() => void access()}
                    >
                      <ExternalLink size={17} />
                      Open Resource
                    </MediaLink>
                  )}
                  {r.file && (
                    <>
                      <button
                        className={button}
                        disabled={preview.isPending}
                        onClick={() => preview.mutate({ download: true })}
                      >
                        <Download size={17} />
                        Download File
                      </button>
                      {!videoResource && /^(audio|image)\//.test(r.file.type) && (
                        <button
                          className={button}
                          disabled={preview.isPending}
                          onClick={() => preview.mutate({})}
                        >
                          <PlayCircle size={17} />
                          Preview Resource
                        </button>
                      )}
                    </>
                  )}
                </div>
                {media && !media.type.startsWith('video/') &&
                  (media.type.startsWith("image/") ? (
                    <img
                      src={media.url}
                      alt={r.title}
                      className='max-h-[65vh] w-full object-contain'
                    />
                  ) : (
                    <audio controls src={media.url} className='w-full' />
                  ))}
              </section>
              {r.contents.length > 0 && (
                <section className='rounded-2xl border border-violet-100 bg-white p-6'>
                  <h2 className='mb-4 text-xl font-bold'>Contents</h2>
                  <div className='divide-y divide-violet-100'>
                    {r.contents.map((c) => (
                      <article key={c.id} className='space-y-3 py-4'>
                        <h3 className='font-bold'>
                          {c.position}. {c.title}
                        </h3>
                        <p className='whitespace-pre-line text-sm'>{c.body}</p>
                        <div className='flex flex-wrap gap-3'>
                          {c.url && (
                            <MediaLink
                              className={button}
                              href={c.url}
                              target='_blank'
                              rel='noopener noreferrer'
                              onClick={() => void access(c.id)}
                            >
                              <ExternalLink size={17} />
                              Open Content
                            </MediaLink>
                          )}
                          {c.start_seconds !== null &&
                            r.file?.type.startsWith("video/") && (
                              <button
                                className={button}
                                disabled={preview.isPending}
                                onClick={() =>
                                  preview.mutate({ start: c.start_seconds! })
                                }
                              >
                                <PlayCircle size={17} />
                                Play from {Math.floor(c.start_seconds / 60)}:
                                {String(c.start_seconds % 60).padStart(2, "0")}
                              </button>
                            )}
                        </div>
                      </article>
                    ))}
                  </div>
                </section>
              )}
              <section className='grid gap-5 md:grid-cols-2'>
                <form
                  className='space-y-4 rounded-2xl border border-violet-100 bg-white p-6'
                  onSubmit={(e) => {
                    e.preventDefault();
                    progress.mutate(percent);
                  }}
                >
                  <h2 className='text-xl font-bold'>Your Progress</h2>
                  <p className='text-xs text-slate-500'>
                    Save your progress as you work through this resource.
                  </p>
                  <label className='block text-sm font-semibold'>
                    Progress (%)
                    <input
                      aria-label='Resource progress'
                      type='number'
                      min={0}
                      max={100}
                      step={1}
                      className={`${input} mt-2`}
                      value={percent}
                      disabled={!r.can_participate}
                      onChange={(e) => setPercent(Number(e.target.value))}
                    />
                  </label>
                  <button
                    className={button}
                    disabled={
                      !r.can_participate ||
                      progress.isPending ||
                      query.isFetching ||
                      !Number.isInteger(percent) ||
                      percent < 0 ||
                      percent > 100
                    }
                  >
                    Save Progress
                  </button>
                </form>
                <form
                  className='space-y-4 rounded-2xl border border-violet-100 bg-white p-6'
                  onSubmit={(e) => {
                    e.preventDefault();
                    feedback.mutate();
                  }}
                >
                  <h2 className='flex items-center gap-2 text-xl font-bold'>
                    <Star className='text-amber-500' />
                    Your Feedback
                  </h2>
                  <label className='block text-sm font-semibold'>
                    Rating
                    <select
                      aria-label='Resource rating'
                      className={`${input} mt-2`}
                      value={rating}
                      onChange={(e) => setRating(Number(e.target.value))}
                    >
                      {[5, 4, 3, 2, 1].map((v) => (
                        <option key={v} value={v}>
                          {v} / 5
                        </option>
                      ))}
                    </select>
                  </label>
                  <textarea
                    required
                    rows={4}
                    maxLength={1000}
                    aria-label='Resource feedback'
                    className={input}
                    placeholder='Share your experience…'
                    value={comment}
                    onChange={(e) => setComment(e.target.value)}
                  />
                  <button
                    className={button}
                    disabled={
                      !r.can_participate ||
                      !r.progress?.percent ||
                      !comment.trim() ||
                      feedback.isPending
                    }
                  >
                    Save Feedback
                  </button>
                  {!r.progress?.percent && (
                    <p className='text-xs text-slate-500'>
                      Open or start this resource before submitting feedback.
                    </p>
                  )}
                </form>
              </section>
            </>
          )
        )}
      </main>
      <VideoDialog open={!!media?.type.startsWith('video/')} onOpenChange={open=>{if(!open)setMedia(null);}} title={r?.title}>{media&&<PlatformVideo mimeType={media.type} src={media.url} title={r?.title} force captions={media.captions} language={r?.language} start={media.start}/>}</VideoDialog>
    </MainLayout>
  );
}
