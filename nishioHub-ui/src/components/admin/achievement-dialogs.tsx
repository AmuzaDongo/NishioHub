import { useDeferredValue, useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { ProgramPicker } from './program-picker';
import { SessionProgramPicker } from './session-program-picker';
import { goalInput as input, goalPrimary as primary, goalOutline as outline, goalLabel } from './goal-ui';
import { operationError } from './dashboard-operations';
import { achievementKinds } from '@/lib/achievement-display';
import { useAuth } from '@/lib/auth-context';
import { getAchievementDefinitions, issueAchievement, saveAchievementDefinition, type AchievementDefinition, type DefinitionDraft } from '@/lib/admin-achievements-api';
const blank: DefinitionDraft = { title: '', description: '', criteria: '', kind: 'special_recognition', icon: 'trophy', color: 'purple' };
function Recipients({ ids, setIds, program, setProgram, date, setDate }: { ids: number[]; setIds: (v: number[]) => void; program: number | null; setProgram: (v: number | null) => void; date: string; setDate: (v: string) => void }) {
  return <div className="space-y-3 rounded-xl border border-violet-100 bg-violet-50/50 p-3">
    <label className="block text-sm font-bold">Learners</label><ProgramPicker kind="mentees" activeOnly multiple label="Select Learners" selected={ids} onChange={setIds} />
    <label className="block text-sm font-bold">Program (optional)</label><SessionProgramPicker activeOnly label="Select Program" value={program} onChange={setProgram} />
    <label className="block text-sm font-bold">Award Date<input className={`${input} mt-1`} type="date" value={date} onChange={e => setDate(e.target.value)} /></label>
    <p className="text-xs text-slate-500">Leave the date empty to use the current time. Backdated awards use midnight in the platform timezone. Up to 100 active mentees can receive an award together.</p>
  </div>;
}
export function AchievementDefinitionDialog({ open, record, badge = false, onClose, onSaved }: { open: boolean; record?: AchievementDefinition; badge?: boolean; onClose: () => void; onSaved: () => Promise<void> }) {
  const [draft, setDraft] = useState<DefinitionDraft>(blank);
  const [ids, setIds] = useState<number[]>([]); const [program, setProgram] = useState<number | null>(null); const [date, setDate] = useState(''); const [error, setError] = useState('');
  useEffect(() => { if (open) { setDraft(record ? { ...record, description: record.description || '', criteria: record.criteria || '' } : { ...blank, kind: badge ? 'skill_badge' : 'special_recognition' }); setIds([]); setProgram(null); setDate(''); setError(''); } }, [open, record, badge]);
  const save = useMutation({ mutationFn: () => saveAchievementDefinition(draft, record, record ? undefined : { user_ids: ids, program_id: program, awarded_on: date }), onSuccess: async () => { onClose(); await onSaved(); }, onError: e => setError(operationError(e)) });
  const set = <K extends keyof DefinitionDraft>(key: K, value: DefinitionDraft[K]) => setDraft(v => ({ ...v, [key]: value }));
  return <Dialog open={open} onOpenChange={v => { if (!v && !save.isPending) onClose(); }}><DialogContent className="max-h-[90dvh] max-w-2xl overflow-y-auto"><DialogHeader><DialogTitle>{record ? 'Edit Achievement' : badge ? 'Create Badge' : 'Create Achievement'}</DialogTitle><DialogDescription>{record ? 'Catalog changes apply to future awards. Existing awards retain their original details.' : 'Save an achievement to the catalog and optionally award it to selected learners.'}</DialogDescription></DialogHeader>
    <form className="space-y-4" onSubmit={e => { e.preventDefault(); setError(''); save.mutate(); }}>
      <label className="block text-sm font-bold">Achievement Title *<input required maxLength={200} className={`${input} mt-1`} value={draft.title} onChange={e => set('title', e.target.value)} /></label>
      <div className="grid gap-3 sm:grid-cols-2"><label className="text-sm font-bold">Type<select className={`${input} mt-1`} disabled={!!record} value={draft.kind} onChange={e => set('kind', e.target.value as DefinitionDraft['kind'])}>{achievementKinds.map(k => <option key={k.key} value={k.key}>{k.label}</option>)}</select></label><label className="text-sm font-bold">Color<select className={`${input} mt-1`} value={draft.color} onChange={e => set('color', e.target.value)}>{['purple', 'blue', 'green', 'gold', 'pink'].map(v => <option key={v} value={v}>{goalLabel(v)}</option>)}</select></label></div>
      <label className="block text-sm font-bold">Description<textarea maxLength={2000} rows={3} className={`${input} mt-1`} value={draft.description} onChange={e => set('description', e.target.value)} /></label>
      <label className="block text-sm font-bold">Award Criteria<textarea maxLength={2000} rows={2} className={`${input} mt-1`} value={draft.criteria} onChange={e => set('criteria', e.target.value)} /></label>
      <label className="block text-sm font-bold">Icon<select className={`${input} mt-1`} value={draft.icon} onChange={e => set('icon', e.target.value)}>{['trophy', 'star', 'code', 'book', 'users', 'rocket', 'certificate', 'graduation', 'target', 'laptop'].map(v => <option key={v} value={v}>{goalLabel(v)}</option>)}</select></label>
      {!record && <Recipients ids={ids} setIds={setIds} program={program} setProgram={setProgram} date={date} setDate={setDate} />}
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700" role="alert">{error}</p>}
      <footer className="flex justify-end gap-2"><button type="button" className={outline} disabled={save.isPending} onClick={onClose}>Cancel</button><button className={primary} disabled={save.isPending}>{save.isPending ? 'Saving…' : record ? 'Save Changes' : ids.length ? 'Create & Award' : 'Save Achievement'}</button></footer>
    </form>
  </DialogContent></Dialog>;
}
export function AchievementAwardDialog({ open, initial, onClose, onSaved }: { open: boolean; initial?: AchievementDefinition; onClose: () => void; onSaved: () => Promise<void> }) {
  const { user } = useAuth(); const [q, setQ] = useState(''); const deferred = useDeferredValue(q); const [page, setPage] = useState(1); const [chosen, setChosen] = useState<AchievementDefinition | null>(null);
  const [ids, setIds] = useState<number[]>([]); const [program, setProgram] = useState<number | null>(null); const [date, setDate] = useState(''); const [error, setError] = useState('');
  useEffect(() => { if (open) { setChosen(initial || null); setQ(''); setPage(1); setIds([]); setProgram(null); setDate(''); setError(''); } }, [open, initial]);
  const query = useQuery({ queryKey: ['achievement-definitions', user?.id, deferred, page], queryFn: () => getAchievementDefinitions(deferred, page), enabled: open && !initial });
  const save = useMutation({ mutationFn: () => issueAchievement(chosen!.definition_id!, ids, program, date), onSuccess: async () => { onClose(); await onSaved(); }, onError: e => setError(operationError(e)) });
  return <Dialog open={open} onOpenChange={v => { if (!v && !save.isPending) onClose(); }}><DialogContent className="max-h-[90dvh] max-w-2xl overflow-y-auto"><DialogHeader><DialogTitle>Award Achievement</DialogTitle><DialogDescription>Issue a saved achievement to learners. Automatic badges are earned through their recorded criteria.</DialogDescription></DialogHeader>
    <form className="space-y-4" onSubmit={e => { e.preventDefault(); setError(''); save.mutate(); }}>
      {initial ? <p className="rounded-lg bg-violet-50 p-3 font-bold">{initial.title}</p> : <div className="space-y-2"><input className={input} aria-label="Search saved achievements" placeholder="Search saved achievements…" value={q} onChange={e => { setQ(e.target.value); setPage(1); }} />{query.isPending ? <p role="status">Loading achievements…</p> : query.isError ? <button type="button" className={outline} onClick={() => query.refetch()}>Retry Choices</button> : <><div className="max-h-40 overflow-y-auto rounded-lg border border-violet-100">{query.data?.items.filter(d => !d.automatic).map(d => <button key={d.id} type="button" aria-pressed={chosen?.id === d.id} className={`block w-full p-2 text-left text-sm ${chosen?.id === d.id ? 'bg-violet-100 font-bold text-violet-800' : 'hover:bg-violet-50'}`} onClick={() => setChosen(d)}>{d.title} · {achievementKinds.find(k => k.key === d.kind)?.label}</button>)}{!query.data?.items.some(d => !d.automatic) && <p className="p-3 text-sm text-slate-500">No custom achievements on this page. Create one or search by title.</p>}</div><div className="flex justify-end gap-2"><button type="button" className={outline} disabled={page <= 1} onClick={() => setPage(v => v - 1)}>Previous</button><button type="button" className={outline} disabled={page >= (query.data?.meta.total_pages || 1)} onClick={() => setPage(v => v + 1)}>Next</button></div></>}{chosen && <p className="text-xs font-bold text-violet-700">Selected: {chosen.title}</p>}</div>}
      <Recipients ids={ids} setIds={setIds} program={program} setProgram={setProgram} date={date} setDate={setDate} />
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700" role="alert">{error}</p>}
      <button className={`${primary} w-full`} disabled={save.isPending || !chosen || !ids.length}>{save.isPending ? 'Awarding…' : `Award to ${ids.length} Learner${ids.length === 1 ? '' : 's'}`}</button>
    </form>
  </DialogContent></Dialog>;
}
