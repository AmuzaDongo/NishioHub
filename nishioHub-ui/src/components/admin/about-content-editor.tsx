import { useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2 } from 'lucide-react';
import { toast } from 'sonner';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { ButtonLoader } from '@/components/loaders/ButtonLoader';
import { PageLoader } from '@/components/loaders/PageLoader';
import { operationError } from '@/components/admin/dashboard-operations';
import { getSystemSettings, patchSystemSettings, type SystemWorkspace } from '@/lib/system-settings-api';
import type { AboutTeamDraft } from '@/lib/about-api';
import { useAuth } from '@/lib/auth-context';

const input = 'mt-1 w-full rounded-lg border border-violet-200 bg-white p-2 text-sm font-normal focus:border-violet-600 focus:outline-none focus:ring-2 focus:ring-violet-100';
const button = 'rounded-lg border border-violet-300 px-3 py-2 text-sm font-bold text-violet-700 disabled:opacity-50';
export function AboutContentEditor({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { user } = useAuth(); const [saving, setSaving] = useState(false);
  const query = useQuery({ queryKey: ['about-editor', user?.id], queryFn: getSystemSettings, enabled: open, staleTime: 0, refetchOnWindowFocus: false });
  return <Dialog open={open} onOpenChange={next => { if (!next && !saving) onClose(); }}><DialogContent className="max-h-[90vh] max-w-3xl overflow-y-auto"><DialogHeader><DialogTitle>Manage About Content</DialogTitle><DialogDescription>Publish approved leadership profiles and an optional story video. Impact figures come from platform records.</DialogDescription></DialogHeader>{query.isPending ? <PageLoader label="Loading About settings" rows={2}/> : query.isError ? <div role="alert"><p>{operationError(query.error)}</p><button className={button} onClick={() => query.refetch()}>Retry</button></div> : <EditorForm key={`${query.data.lock_version}`} workspace={query.data} onClose={onClose} onSaving={setSaving}/>}</DialogContent></Dialog>;
}
function EditorForm({ workspace, onClose, onSaving }: { workspace: SystemWorkspace; onClose: () => void; onSaving: (value: boolean) => void }) {
  const client = useQueryClient();
  const [video, setVideo] = useState(workspace.settings.about_story_video_url || '');
  const [team, setTeam] = useState<AboutTeamDraft[]>(() => structuredClone(workspace.settings.about_team || []));
  const [error, setError] = useState(''); const [busy, setBusy] = useState(false); const lock = useRef(false);
  function change(index: number, field: string, value: string | boolean) { setTeam(current => current.map((member, i) => i === index ? { ...member, [field]: value } : member)); }
  async function save(event: React.FormEvent) {
    event.preventDefault(); if (lock.current) return;
    lock.current = true; setBusy(true); onSaving(true); setError('');
    try {
      await patchSystemSettings({ lock_version: workspace.lock_version, settings: { about_story_video_url: video.trim(), about_team: team.map(m => ({ ...m, name: m.name.trim(), title: m.title.trim(), bio: m.bio.trim(), photo_url: m.photo_url.trim() })) } });
      await Promise.all([client.invalidateQueries({ queryKey: ['public-about'] }), client.invalidateQueries({ queryKey: ['system-settings'] }), client.invalidateQueries({ queryKey: ['about-editor'] })]);
      toast.success('About content saved'); onClose();
    } catch (failure) { setError(operationError(failure)); } finally { lock.current = false; setBusy(false); onSaving(false); }
  }
  return <form onSubmit={save} className="space-y-4"><fieldset disabled={busy} className="space-y-4"><label className="block text-sm font-bold">Story Video URL (Optional)<input aria-label="Story video URL" type="url" maxLength={2048} value={video} onChange={e => setVideo(e.target.value)} placeholder="https://example.org/our-story.mp4" className={input}/><span className="mt-1 block text-xs font-normal text-slate-500">HTTPS MP4 or WebM. Leave blank to use the illustrated story presentation.</span></label><div className="flex flex-wrap items-center justify-between gap-3"><h3 className="font-bold">Leadership Profiles ({team.length}/20)</h3><button className={button} disabled={team.length >= 20} type="button" onClick={() => setTeam([...team, { name: '', title: '', bio: '', photo_url: '', published: false }])}><Plus size={15} className="mr-1 inline"/>Add Team Member</button></div>{team.map((member, i) => <section key={i} className="space-y-3 rounded-xl border border-violet-100 bg-violet-50 p-4"><div className="flex items-center justify-between gap-3"><h4 className="text-sm font-bold">Team Member {i + 1}</h4><button type="button" className="rounded p-1 text-red-600" aria-label={`Remove team member ${i + 1}`} onClick={() => setTeam(team.filter((_, index) => index !== i))}><Trash2 size={18}/></button></div><div className="grid gap-3 sm:grid-cols-2"><label className="text-xs font-bold">Full Name *<input aria-label={`Team member ${i + 1} name`} required minLength={2} maxLength={100} value={member.name} onChange={e => change(i, 'name', e.target.value)} className={input}/></label><label className="text-xs font-bold">Role / Title *<input aria-label={`Team member ${i + 1} title`} required minLength={2} maxLength={150} value={member.title} onChange={e => change(i, 'title', e.target.value)} className={input}/></label></div><label className="block text-xs font-bold">Photo URL (Optional)<input aria-label={`Team member ${i + 1} photo URL`} type="url" maxLength={2048} value={member.photo_url} onChange={e => change(i, 'photo_url', e.target.value)} placeholder="https://example.org/portrait.jpg" className={input}/></label><label className="block text-xs font-bold">Biography (Optional)<textarea aria-label={`Team member ${i + 1} biography`} maxLength={500} rows={3} value={member.bio} onChange={e => change(i, 'bio', e.target.value)} className={input}/></label><label className="flex items-start gap-2 text-xs"><input aria-label={`Publish team member ${i + 1}`} type="checkbox" checked={member.published} onChange={e => change(i, 'published', e.target.checked)} className="mt-0.5 accent-violet-700"/>Publish this approved profile on the public About page.</label></section>)}{!team.length && <p className="rounded-xl border border-dashed border-violet-200 p-5 text-sm text-slate-600">Add approved team profiles. Staff account details are never published automatically.</p>}</fieldset>{error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}<footer className="flex flex-wrap justify-end gap-3"><button type="button" disabled={busy} className={button} onClick={onClose}>Cancel</button><ButtonLoader type="submit" loading={busy} loadingText="Saving About Content..." className={`${button} inline-flex items-center gap-2 bg-violet-700 !text-white`}>Save About Content</ButtonLoader></footer></form>;
}
