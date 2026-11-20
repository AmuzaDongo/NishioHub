import { useEffect, useState, type ReactNode } from 'react';
import { GraduationCap, ImagePlus, RotateCcw, Trash2 } from 'lucide-react';
import api from '@/lib/axios';
import { useAuth } from '@/lib/auth-context';
import { assetUrl } from '@/lib/platform-context';
import { cn } from '@/lib/utils';
import { Skeleton } from '@/components/ui/skeleton';

export interface ProgramBannerRecord { id: number; banner_url?: string | null; banner_filename?: string | null }
export function ProgramBanner({ program, className, fallback }: { program: ProgramBannerRecord; className?: string; fallback?: ReactNode }) {
  const { user } = useAuth(); const [url, setUrl] = useState(''); const [pending, setPending] = useState(false);
  useEffect(() => {
    const controller = new AbortController(); let objectUrl = ''; let active = true;
    setUrl(''); setPending(!!program.banner_url);
    if (program.banner_url) api.get<Blob>(assetUrl(program.banner_url)!, { responseType: 'blob', signal: controller.signal }).then(response => {
      if (active) { objectUrl = URL.createObjectURL(response.data); setUrl(objectUrl); }
    }).catch(() => { /* Keep the established icon when a banner is missing or unavailable. */ }).finally(() => { if (active) setPending(false); });
    return () => { active = false; controller.abort(); if (objectUrl) URL.revokeObjectURL(objectUrl); };
  }, [program.banner_url, user?.id, user?.access_token]);
  return <div className={cn('relative grid place-items-center overflow-hidden rounded-xl bg-gradient-to-br from-violet-100 to-violet-200 text-violet-700', className)}>{pending ? <Skeleton aria-label="Loading program banner" className="absolute inset-0 rounded-none bg-violet-100"/> : url ? <img src={url} alt="Program banner" className="absolute inset-0 size-full object-cover" onError={() => setUrl('')}/> : fallback || <GraduationCap size={72} aria-hidden="true"/>}</div>;
}

export function ProgramBannerUpload({ program, file, remove, disabled, onChange }: { program?: ProgramBannerRecord | null; file?: File | null; remove?: boolean; disabled?: boolean; onChange: (value: { banner: File | null; remove_banner: boolean }) => void }) {
  const [preview, setPreview] = useState(''); const [error, setError] = useState('');
  useEffect(() => { if (!file) { setPreview(''); return; } const url = URL.createObjectURL(file); setPreview(url); return () => URL.revokeObjectURL(url); }, [file]);
  return <fieldset disabled={disabled} className="space-y-3 rounded-xl border border-violet-200 bg-violet-50/50 p-4"><legend className="px-1 text-sm font-bold">Program Banner</legend>
    {preview ? <img src={preview} alt="Selected program banner preview" className="h-40 w-full rounded-xl object-cover"/> : program?.banner_url && !remove ? <ProgramBanner program={program} className="h-40 w-full"/> : <div className="grid h-32 place-items-center rounded-xl border border-dashed border-violet-300 bg-white text-violet-600"><ImagePlus size={38} aria-hidden="true"/><span className="text-xs">Add a program cover image</span></div>}
    <label className="block text-sm font-semibold">{program?.banner_url || file ? 'Change Banner' : 'Upload Banner'}<input aria-label="Upload program banner" type="file" accept="image/jpeg,image/png,image/webp" className="mt-2 block w-full min-w-0 text-sm" onChange={event => { const selected = event.target.files?.[0]; event.target.value = ''; if (!selected) return; if (selected.size > 2 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(selected.type)) { setError('Choose a JPEG, PNG or WebP image up to 2 MB.'); return; } setError(''); onChange({ banner: selected, remove_banner: false }); }}/></label>
    <p className="text-xs text-slate-600">JPEG, PNG or WebP, up to 2 MB. A wide image around 1600 × 600 pixels works well. Changes are applied when you save the program.</p>
    {file && <p className="break-all text-xs">Selected: {file.name}</p>}{!file && program?.banner_filename && !remove && <p className="break-all text-xs">Current: {program.banner_filename}</p>}
    {remove ? <div className="flex flex-wrap items-center gap-3 text-xs"><span>The existing banner will be removed when you save.</span><button type="button" className="inline-flex items-center gap-1 font-bold text-violet-700" onClick={() => { setError(''); onChange({ banner: null, remove_banner: false }); }}><RotateCcw size={14}/>Undo Removal</button></div> : (file || program?.banner_url) && <button type="button" className="inline-flex items-center gap-1 text-xs font-bold text-red-700" onClick={() => { setError(''); onChange({ banner: null, remove_banner: !!program?.banner_url }); }}><Trash2 size={14}/>Remove Banner</button>}
    {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
  </fieldset>;
}
