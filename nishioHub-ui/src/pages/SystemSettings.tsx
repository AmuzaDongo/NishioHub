import { PageLoader } from '@/components/loaders/PageLoader';
import type { PublicPlatformConfig } from '@/lib/system-settings-api';
import { ArrowRight } from 'lucide-react';
import { useRef, useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Activity, ArrowLeftRight, Award, Bell, BookOpen, CalendarDays, Check, ChevronDown, ChevronRight, CircleHelp, Crown, Database, Download, FileUp, Globe, GraduationCap, Home, Info, KeyRound, Layers, Link2, Mail, Menu, MessageSquare, Paintbrush, Phone, RotateCcw, Save, Search, Settings, ShieldCheck, SlidersHorizontal, Trash2, Upload, Users, Wrench, X } from 'lucide-react';
import { AdminWorkspace } from '@/components/layout/admin-workspace';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Switch } from '@/components/ui/switch';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { useAuth } from '@/lib/auth-context';
import { isPlatformAdmin, roleName } from '@/lib/utils';
import { assetUrl, platformDate } from '@/lib/platform-context';
import { useUnreadNotifications } from '@/hooks/use-unread-notifications';
import { saveDownload } from '@/lib/achievements-api';
import { createConfigBackup, downloadConfigBackup, getConfigBackups, getSystemAudit, getSystemSettings, patchSystemSettings, removePlatformAsset, restoreConfigBackup, sendPlatformTestEmail, uploadPlatformAsset, type ConfigDocument, type PlatformSettings, type SystemWorkspace } from '@/lib/system-settings-api';
import { toast } from 'sonner';
import './system-settings.css';

const menu = [
  { id: 'general', title: 'General Settings', description: 'Platform, branding and basic information', icon: Settings, tab: 'general' },
  { id: 'branding', title: 'Branding & Appearance', description: 'Logo, favicon and platform identity', icon: Paintbrush, tab: 'general' },
  { id: 'users', title: 'User Management', description: 'Registration, verification and policies', icon: Users, tab: 'users' },
  { id: 'notifications', title: 'Email & Notifications', description: 'Email delivery and in-app alerts', icon: Mail, tab: 'notifications' },
  { id: 'configuration', title: 'System Configuration', description: 'Platform behaviour and defaults', icon: Settings, tab: 'advanced' },
  { id: 'security', title: 'Security Settings', description: 'Authentication, sessions and audit', icon: ShieldCheck, tab: 'security' },
  { id: 'localization', title: 'Localization', description: 'Language, timezone and formats', icon: Globe, tab: 'general' },
  { id: 'storage', title: 'Storage & Files', description: 'File uploads, limits and providers', icon: FileUp, tab: 'advanced' },
  { id: 'maintenance', title: 'Maintenance', description: 'System mode and maintenance notice', icon: Wrench, tab: 'advanced' },
  { id: 'programs', title: 'Programs', description: 'Mentorship, learning and event access', icon: GraduationCap, tab: 'programs' },
  { id: 'integrations', title: 'Integrations', description: 'Meeting providers and service status', icon: Link2, tab: 'integrations' },
  { id: 'backup', title: 'Backup & Recovery', description: 'Configuration snapshots and restoration', icon: Database, tab: 'backup' },
] as const;
type Section = typeof menu[number]['id'];
const tabs = [
  { id: 'general', label: 'General', icon: Settings, section: 'general' },
  { id: 'users', label: 'Users & Access', icon: Users, section: 'users' },
  { id: 'programs', label: 'Programs', icon: GraduationCap, section: 'programs' },
  { id: 'notifications', label: 'Notifications', icon: Bell, section: 'notifications' },
  { id: 'integrations', label: 'Integrations', icon: Link2, section: 'integrations' },
  { id: 'security', label: 'Security & Audit', icon: ShieldCheck, section: 'security' },
  { id: 'backup', label: 'Backup & Recovery', icon: Database, section: 'backup' },
  { id: 'advanced', label: 'Advanced', icon: SlidersHorizontal, section: 'configuration' },
] as const;
const coreKeys: (keyof PlatformSettings)[] = ['platform_name', 'tagline', 'organization_name', 'support_email', 'support_phone', 'timezone', 'language', 'date_format', 'currency', 'platform_mode', 'registration_enabled', 'require_email_verification', 'matching_enabled', 'public_events_enabled', 'notifications_enabled'];
const sectionKeys: Partial<Record<Section, (keyof PlatformSettings)[]>> = {
  general: coreKeys, branding: ['platform_name', 'tagline'], users: ['registration_enabled', 'require_email_verification', 'default_registration_role'],
  notifications: ['notifications_enabled'], configuration: ['matching_enabled', 'public_events_enabled', 'learning_enrollment_enabled', 'event_registration_enabled'],
  security: ['password_min_length', 'access_token_minutes', 'refresh_token_days'], localization: ['timezone', 'language', 'date_format', 'currency'],
  storage: ['max_upload_mb'], maintenance: ['platform_mode', 'maintenance_message'], programs: ['matching_enabled', 'learning_enrollment_enabled', 'event_registration_enabled'],
  integrations: ['allowed_meeting_hosts', 'support_url'],
};
function apiError(error: unknown) {
  const detail = (error as { response?: { data?: { detail?: string | string[] } } })?.response?.data?.detail;
  return Array.isArray(detail) ? detail.join(', ') : detail || 'Could not complete this action. Please try again.';
}
export default function SystemSettings() {
  const { user, isLoading: authLoading, logout } = useAuth();
  const navigate = useNavigate();
  const client = useQueryClient();
  const unread = useUnreadNotifications();
  const [params] = useSearchParams();
  const [section, setSection] = useState<Section>(menu.some(item => item.id === params.get('section')) ? params.get('section') as Section : 'general');
  const [search, setSearch] = useState('');
  const [draft, setDraft] = useState<Partial<PlatformSettings>>({});
  const [hostsText, setHostsText] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [conflict, setConflict] = useState(false);
  const [error, setError] = useState('');
  const [auditPage, setAuditPage] = useState(1);
  const [backupLabel, setBackupLabel] = useState('');
  const [restoreDocument, setRestoreDocument] = useState<ConfigDocument | null>(null);
  const [confirmation, setConfirmation] = useState('');
  const assetKind = useRef<'logo' | 'favicon'>('logo');
  const assetInput = useRef<HTMLInputElement>(null);
  const importInput = useRef<HTMLInputElement>(null);
  const panel = useRef<HTMLElement>(null);
  const authorized = !!user?.access_token && isPlatformAdmin(user);
  const queryKey = ['system-settings', user?.id];
  const query = useQuery({ queryKey, queryFn: getSystemSettings, enabled: authorized, refetchOnWindowFocus: false });
  const audits = useQuery({ queryKey: ['system-settings-audit', user?.id, auditPage], queryFn: () => getSystemAudit(auditPage), enabled: authorized && section === 'security' });
  const backups = useQuery({ queryKey: ['system-settings-backups', user?.id], queryFn: getConfigBackups, enabled: authorized && section === 'backup' });
  const failed = (failure: unknown) => { setError(apiError(failure)); if ((failure as { response?: { status?: number } })?.response?.status === 409) setConflict(true); };
  const accept = (workspace: SystemWorkspace) => {
    client.setQueryData(queryKey, workspace);
    client.setQueryData<PublicPlatformConfig>(['public-platform-config'], current => current ? { ...current, ...workspace.assets } : current);
    setError(''); setConflict(false);
    void client.invalidateQueries({ queryKey: ['public-platform-config'] });
    for (const key of ['public-events', 'public-events-discovery', 'public-event-detail', 'public-home']) {
      void client.invalidateQueries({ queryKey: [key] });
    }
    void client.invalidateQueries({ queryKey: ['system-settings-audit'] });
    void client.invalidateQueries({ queryKey: ['system-settings-backups'] });
  };
  const save = useMutation({ mutationFn: patchSystemSettings, onSuccess: (data, payload) => {
    accept(data);
    setDraft(current => Object.fromEntries(Object.entries(current).filter(([key, value]) => JSON.stringify(value) !== JSON.stringify(payload.settings[key as keyof PlatformSettings]))));
    setHostsText(null); toast.success('System settings saved');
  }, onError: failed });
  const upload = useMutation({ mutationFn: uploadPlatformAsset, onSuccess: data => { accept(data); toast.success('Branding image updated'); }, onError: failed });
  const remove = useMutation({ mutationFn: removePlatformAsset, onSuccess: data => { accept(data); toast.success('Default branding restored'); }, onError: failed });
  const backup = useMutation({ mutationFn: createConfigBackup, onSuccess: () => { setBackupLabel(''); void client.invalidateQueries({ queryKey: ['system-settings-backups'] }); void client.invalidateQueries({ queryKey: ['system-settings-audit'] }); toast.success('Configuration backup created'); }, onError: failed });
  const restore = useMutation({ mutationFn: restoreConfigBackup, onSuccess: data => { accept(data); setDraft({}); setHostsText(null); setRestoreDocument(null); setConfirmation(''); toast.success('Configuration restored. A backup of the previous configuration was saved.'); }, onError: failed });
  const testEmail = useMutation({ mutationFn: sendPlatformTestEmail, onSuccess: data => { toast.success(data.detail); void client.invalidateQueries({ queryKey: ['system-settings-audit'] }); }, onError: failed });
  const download = useMutation({ mutationFn: async ({ id, restore: restoring }: { id: number; restore?: boolean }) => {
    const file = await downloadConfigBackup(id);
    if (restoring) openRestore(await file.text()); else saveDownload(file, `nishiohub-settings-${id}.json`);
  }, onError: failed });
  if (authLoading) return <PageLoader label="Loading system settings…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!authorized) return <main className="p-12 text-center space-y-5"><ShieldCheck className="mx-auto text-violet-700" size={45} /><h1 className="text-2xl font-bold">Administrator access required</h1><p>System Settings is available to administrators and super administrators.</p><Link to="/" className="text-violet-700 underline">Return home</Link></main>;
  const data = query.data;
  const values = data ? { ...data.settings, ...draft } : null;
  const active = menu.find(item => item.id === section)!;
  const Icon = active.icon;
  const adminLabel = (roleName(user) || '').toLowerCase().replace(/[ _-]/g, '') === 'superadmin' ? 'Super Admin' : 'Admin';
  const pending = save.isPending || upload.isPending || remove.isPending || restore.isPending;
  const matchesSearch = (item: typeof menu[number]) => `${item.title} ${item.description} ${(sectionKeys[item.id] || []).join(' ').replace(/_/g, ' ')}`.toLowerCase().includes(search.toLowerCase());
  const chooseSection = (value: Section) => { setSection(value); setMenuOpen(false); requestAnimationFrame(() => panel.current?.focus({ preventScroll: true })); };
  function edit<K extends keyof PlatformSettings>(key: K, value: PlatformSettings[K]) { setDraft(current => ({ ...current, [key]: value })); }
  function openRestore(raw: string) {
    try {
      const document = JSON.parse(raw) as ConfigDocument;
      if (document.format !== 'nishiohub-system-settings' || document.schema_version !== 1 || !document.values || Array.isArray(document.values) || typeof document.values !== 'object' || typeof document.checksum !== 'string') throw new Error();
      setConfirmation(''); setRestoreDocument(document);
    } catch { toast.error('Choose a valid NishioHub configuration backup JSON file'); }
  }
  async function reload() { const result = await query.refetch(); if (result.data) { setDraft({}); setHostsText(null); setError(''); setConflict(false); } }
  function submit(event: FormEvent) { event.preventDefault(); if (!data) return; save.mutate({ settings: draft, lock_version: data.lock_version }); }
  function field(key: keyof PlatformSettings, label: string, options: { type?: string; required?: boolean; min?: number; max?: number; icon?: typeof Mail; choices?: [string, string][]; hint?: string } = {}) {
    if (!values) return null;
    const FieldIcon = options.icon;
    return <label className="system-field" key={key}><span>{label}{options.required && <em> *</em>}</span><div className={FieldIcon ? 'system-input-with-icon' : ''}>{FieldIcon && <FieldIcon size={18} />}{options.choices ? <select aria-label={label} value={String(values[key])} onChange={event => edit(key, event.target.value as never)}>{options.choices.map(([value, text]) => <option key={value} value={value}>{text}</option>)}</select> : <input aria-label={label} type={options.type || 'text'} value={String(values[key])} required={options.required} min={options.min} max={options.max} maxLength={key === 'support_url' ? 2048 : 150} onChange={event => edit(key, (options.type === 'number' ? Number(event.target.value) : event.target.value) as never)} />}</div>{options.hint && <small>{options.hint}</small>}</label>;
  }
  const switches: { key: keyof PlatformSettings; label: string; hint: string }[] = [
    { key: 'registration_enabled', label: 'Allow new user registration', hint: 'Closes public sign-up when disabled. Existing accounts can still sign in.' },
    { key: 'require_email_verification', label: 'Require email verification', hint: 'Unverified members must verify before signing in. Administrators retain access. Requires server email delivery.' },
    { key: 'matching_enabled', label: 'Enable learner–mentor matching', hint: 'Allows mentees to make new mentorship bookings.' },
    { key: 'public_events_enabled', label: 'Show events on public pages', hint: 'Shows published events on the public home and Events pages. Member event access is preserved.' },
    { key: 'notifications_enabled', label: 'Enable in-app notifications', hint: 'Controls creation of new platform alerts; existing alerts remain readable.' },
    { key: 'learning_enrollment_enabled', label: 'Allow new course enrollments', hint: 'Existing learners can continue lessons when new enrollment is paused.' },
    { key: 'event_registration_enabled', label: 'Allow new event registrations', hint: 'Existing registrations and event history remain available.' },
  ];
  const toggle = (key: keyof PlatformSettings) => { const item = switches.find(row => row.key === key)!; return <label className="system-toggle" key={key}><span>{item.label} <Info size={13} tabIndex={0} aria-label={item.hint}><title>{item.hint}</title></Info></span><Switch aria-label={item.label} checked={values?.[key] === true} disabled={pending || key === 'require_email_verification' && !data?.runtime.email_configured} onCheckedChange={checked => edit(key, checked as never)} /></label>; };
  const localeFields = () => <>{field('timezone', 'Default Timezone', { icon: Globe, choices: [['Africa/Kampala', '(EAT) Africa/Kampala'], ['Africa/Nairobi', '(EAT) Africa/Nairobi'], ['Africa/Kigali', '(CAT) Africa/Kigali'], ['UTC', 'UTC']] })}{field('language', 'Default Language', { icon: Globe, choices: [['en-UG', 'English (UG)'], ['en-US', 'English (US)'], ['en-GB', 'English (UK)']] })}{field('date_format', 'Date Format', { icon: CalendarDays, choices: [['medium', 'Feb 26, 2026'], ['day_first', '26/02/2026'], ['iso', '2026-02-26']] })}{field('currency', 'Currency', { choices: [['UGX', 'UGX – Ugandan Shilling (USh)'], ['USD', 'USD – US Dollar'], ['KES', 'KES – Kenyan Shilling'], ['TZS', 'TZS – Tanzanian Shilling'], ['RWF', 'RWF – Rwandan Franc'], ['EUR', 'EUR – Euro'], ['GBP', 'GBP – British Pound']] })}</>;
  const mode = () => <div className="system-mode"><h3>Platform Mode</h3><div role="group" aria-label="Platform mode">{[{ id: 'live', name: 'Live (Production)', icon: Activity }, { id: 'staging', name: 'Staging', icon: Layers }, { id: 'maintenance', name: 'Maintenance', icon: Wrench }].map(({ id, name, icon: ModeIcon }) => <button key={id} type="button" aria-pressed={values?.platform_mode === id} onClick={() => edit('platform_mode', id as PlatformSettings['platform_mode'])}><ModeIcon size={16} />{name}</button>)}</div></div>;
  const branding = (kind: 'logo' | 'favicon') => <div className={`system-branding ${kind}`}><h3>{kind === 'logo' ? 'Platform Logo' : 'Favicon'} <Info size={14} aria-label={kind === 'logo' ? 'PNG, JPEG or WebP image up to 2 MB' : 'PNG or ICO image up to 2 MB'} /></h3><div className="system-branding-content"><img src={assetUrl(data?.assets[`${kind}_url`]) || (kind === 'logo' ? '/assets/learning-logo.svg' : '/assets/platform-icon.svg')} alt={kind === 'logo' ? values?.platform_name : 'Platform favicon'} /><div><button className="system-outline" type="button" disabled={pending} onClick={() => { assetKind.current = kind; if (assetInput.current) { assetInput.current.accept = kind === 'logo' ? 'image/png,image/jpeg,image/webp' : 'image/png,image/vnd.microsoft.icon,image/x-icon'; assetInput.current.click(); } }}><Upload size={16} />{kind === 'logo' ? 'Change Logo' : 'Change'}</button><button className="system-danger-outline" type="button" disabled={pending || !data?.assets[`${kind}_url`]} onClick={() => data && remove.mutate({ kind, revision: data.lock_version })}><Trash2 size={16} />Remove</button></div></div><small>{kind === 'logo' ? 'PNG, JPG or WebP (max 2 MB). Recommended: 512 × 512 px' : 'Recommended: 32 × 32 px (ICO, PNG)'}</small></div>;
  const navItems = [
    { label: 'Dashboard', icon: Home, to: '/admin' }, { label: 'Users & Roles', icon: Users, to: '/admin?tab=users' },
    { label: 'Mentors', icon: Users, to: '/admin?tab=users&role=mentor' }, { label: 'Mentees', icon: Users, to: '/admin?tab=users&role=mentee' },
    { label: 'Programs', icon: GraduationCap, action: () => chooseSection('programs') }, { label: 'Sessions', icon: CalendarDays, to: '/admin?tab=bookings' },
    { label: 'Learning Resources', icon: BookOpen, to: '/admin?tab=categories' }, { label: 'Events', icon: CalendarDays, to: '/events' },
    { label: 'Goals & Progress', icon: Activity }, { label: 'Achievements', icon: Award },
    { label: 'Messages', icon: MessageSquare, to: '/messages' }, { label: 'Reports & Analytics', icon: Activity, to: '/admin' },
  ];
  return <AdminWorkspace active="settings" search={search} onSearch={setSearch} searchPlaceholder="Search programs, users, settings or anything..." brandName={values?.platform_name} logo={data?.assets.logo_url} onSystemSection={id => chooseSection(id as Section)}>
    <div className="system-breadcrumb"><Link to="/admin" aria-label="Admin dashboard"><Home size={19} fill="currentColor" /></Link><ChevronRight size={15} /><span>{adminLabel}</span><ChevronRight size={15} /><span>System Settings</span></div><div className="system-page-title"><Settings size={40} fill="currentColor" /><div><h1>System Settings</h1><p>Configure and manage platform preferences, security, integrations and operations.</p></div></div>
      <div className="system-top-tabs" role="tablist" aria-label="System settings categories">{tabs.map(({ id, label, icon: TabIcon, section: next }) => <button key={id} role="tab" aria-selected={active.tab === id} onClick={() => chooseSection(next)}><TabIcon size={21} />{label}</button>)}</div>
      {error && <div className="system-error" role="alert"><p>{error}</p>{conflict && <button type="button" onClick={reload}>Discard edits &amp; reload latest settings</button>}</div>}
      {query.isPending ? <PageLoader label="Loading platform configuration…"/> : query.isError ? <div className="system-loading" role="alert"><p>{apiError(query.error)}</p><button className="system-outline" onClick={() => query.refetch()}>Try Again</button></div> : data && values && <form onSubmit={submit} className="system-settings-frame"><div className="system-content-grid"><nav className="system-section-menu" aria-label="Configuration sections">{menu.filter(item => (search ? matchesSearch(item) : !['programs', 'integrations', 'backup'].includes(item.id))).map(({ id, title, description, icon: SectionIcon }) => <button type="button" key={id} aria-current={section === id ? 'page' : undefined} onClick={() => chooseSection(id)}><SectionIcon size={29} /><span><strong>{title}</strong><small>{description}</small></span><ChevronRight size={18} /></button>)}{search && !menu.some(item => matchesSearch(item)) && <p className="system-note">No matching settings.</p>}</nav>
      <section className="system-form-card" tabIndex={-1} ref={panel} aria-label={active.title}><header className="system-section-heading"><Icon size={35} /><div><h2>{active.title}</h2><p>{section === 'general' ? 'Configure core platform information and global preferences.' : active.description}</p></div>{sectionKeys[section] && <button className="system-outline system-reset" type="button" disabled={pending} onClick={() => { setDraft(current => ({ ...current, ...Object.fromEntries(sectionKeys[section]!.map(key => [key, data.defaults[key]])) })); if (section === 'integrations') setHostsText(''); toast.info('Default values loaded for this section. Save Changes to apply.'); }}><RotateCcw size={15} />Reset to Defaults</button>}</header>
      <fieldset disabled={pending}>
      {section === 'general' && <div className="system-general-grid"><div>{field('platform_name', 'Platform Name', { required: true })}{field('tagline', 'Tagline')}{field('organization_name', 'Organization Name', { required: true })}{field('support_email', 'Support Email', { type: 'email', required: true, icon: Mail })}{field('support_phone', 'Support Phone', { type: 'tel', icon: Phone })}{localeFields()}</div><div>{branding('logo')}{branding('favicon')}{mode()}<div className="system-general-toggles">{switches.slice(0, 5).map(item => toggle(item.key))}</div></div></div>}
      {section === 'branding' && <div className="system-general-grid"><div>{field('platform_name', 'Platform Name', { required: true })}{field('tagline', 'Tagline')}<p className="system-note">Custom images update platform headers and the browser favicon. Removing an image restores the built-in branding.</p></div><div>{branding('logo')}{branding('favicon')}</div></div>}
      {section === 'users' && <div className="system-panel-fields">{toggle('registration_enabled')}{toggle('require_email_verification')}{field('default_registration_role', 'Default Registration Role', { choices: [['mentee', 'Mentee'], ['mentor', 'Mentor']] })}<p className="system-note">Public registration can select Mentor or Mentee. Admin and Super Admin roles cannot be obtained through sign-up. The default applies when the registration request does not specify a role.</p>{!data.runtime.email_configured && <p className="system-note">Email verification requires SMTP_ADDRESS and MAIL_FROM on the server before it can be enabled.</p>}</div>}
      {section === 'notifications' && <div className="system-panel-fields">{toggle('notifications_enabled')}{field('support_email', 'Support Email', { type: 'email', required: true })}<div className="system-runtime-card"><Mail /><div><h3>Email Delivery</h3><p>{data.runtime.email_configured ? 'Configured on the server' : 'Not configured on the server'}</p><small>SMTP credentials are managed through deployment environment variables and are never returned to this page.</small></div></div><button type="button" className="system-outline" disabled={!data.runtime.email_configured || testEmail.isPending} onClick={() => testEmail.mutate()}><Mail size={17} />{testEmail.isPending ? 'Sending…' : 'Send Test Email to My Account'}</button><p className="system-note">Verification emails are sent when verification is required. In-app alert delivery also respects each member’s notification preferences.</p></div>}
      {(section === 'configuration' || section === 'programs') && <div className="system-panel-fields">{['matching_enabled', 'learning_enrollment_enabled', 'event_registration_enabled', ...(section === 'configuration' ? ['public_events_enabled'] : [])].map(key => toggle(key as keyof PlatformSettings))}<p className="system-note">Feature switches affect new bookings, enrollments and registrations immediately. Existing records remain available.</p></div>}
      {section === 'localization' && <div className="system-panel-fields">{localeFields()}<p className="system-note">These defaults format public event dates and administrator timestamps. English regional variants are supported; these controls do not translate course content or convert existing service prices.</p><p className="system-note">Preview: {platformDate(new Date().toISOString(), values)} · {new Intl.NumberFormat(values.language, { style: 'currency', currency: values.currency }).format(10000)}</p></div>}
      {section === 'storage' && <div className="system-panel-fields">{field('max_upload_mb', 'Maximum Upload Size (MB)', { type: 'number', required: true, min: 1, max: 20 })}<div className="system-runtime-card"><Database /><div><h3>Active Storage Provider</h3><p>{data.runtime.storage}</p><small>The deployment selects the provider. This setting does not move or delete existing files.</small></div></div><p className="system-note">The global limit applies to new uploads. Feature limits still apply: branding up to 2 MB, profile photos up to 5 MB, and chat attachments up to 10 MB.</p></div>}
      {section === 'maintenance' && <div className="system-panel-fields">{mode()}<label className="system-field"><span>Maintenance Message</span><textarea aria-label="Maintenance Message" rows={4} required maxLength={500} value={values.maintenance_message} onChange={event => edit('maintenance_message', event.target.value)} /></label><p className="system-note">Maintenance mode shows this notice to members and blocks their API access. Admins and Super Admins retain access so they can restore Live mode. Staging shows a visible banner; it does not change the deployment environment ({data.runtime.environment}).</p></div>}
      {section === 'integrations' && <div className="system-panel-fields"><Link to="/admin/integrations" className="system-outline">Manage Provider Integrations <ArrowRight size={16} /></Link><label className="system-field"><span>Allowed Meeting Providers</span><textarea aria-label="Allowed Meeting Providers" rows={4} placeholder={'zoom.us\nmeet.google.com'} value={hostsText ?? values.allowed_meeting_hosts.join('\n')} onChange={event => { setHostsText(event.target.value); edit('allowed_meeting_hosts', event.target.value.split(/[,\n]/).map(host => host.trim().toLowerCase()).filter(Boolean)); }} /><small>One host per line. Leave empty to allow all HTTP/HTTPS meeting links. Applies when events are created or updated.</small></label>{field('support_url', 'Support Portal URL', { type: 'url', hint: 'Optional HTTP/HTTPS link used in the public footer.' })}<div className="system-runtime-card"><CalendarDays /><div><h3>Calendar Integration</h3><p>ICS calendar downloads available</p><small>Members can export registered events to their calendar. No external account connection is required.</small></div></div><div className="system-runtime-card"><Mail /><div><h3>Email Integration</h3><p>{data.runtime.email_configured ? 'Configured' : 'Not configured'}</p><small>Managed on the server; credentials are not exposed.</small></div></div></div>}
      {section === 'security' && <div className="system-panel-fields">{field('password_min_length', 'Minimum Password Length', { type: 'number', required: true, min: 8, max: 64 })}{field('access_token_minutes', 'Access Token Lifetime (minutes)', { type: 'number', required: true, min: 5, max: 240 })}{field('refresh_token_days', 'Refresh Token Lifetime (days)', { type: 'number', required: true, min: 1, max: 30 })}<p className="system-note">Password rules apply to registration and password changes. Token lifetimes apply to newly issued tokens. These controls do not promote users or silently reset existing passwords.</p><h3 className="system-subtitle">Settings Audit Trail</h3>{audits.isPending ? <PageLoader label="Loading audit trail…"/> : audits.isError ? <button type="button" className="system-outline" onClick={() => audits.refetch()}>Retry Audit Trail</button> : audits.data?.entries.length ? <><div className="system-audit-list">{audits.data.entries.map(entry => <details key={entry.id}><summary><span><strong>{entry.action.replace(/[._]/g, ' ')}</strong><small>{entry.actor_name} · {platformDate(entry.created_at, values, true)} · Revision {entry.revision}</small></span><ChevronDown size={16} /></summary><pre>{JSON.stringify(entry.changeset, null, 2)}</pre></details>)}</div><div className="system-pagination"><button type="button" disabled={auditPage <= 1} onClick={() => setAuditPage(current => current - 1)}>Previous</button><span>Page {auditPage} of {audits.data.meta.total_pages}</span><button type="button" disabled={auditPage >= audits.data.meta.total_pages} onClick={() => setAuditPage(current => current + 1)}>Next</button></div></> : <p className="system-note">No administrator changes have been recorded yet.</p>}</div>}
      {section === 'backup' && <div className="system-panel-fields"><p className="system-note">Configuration backups contain platform settings only. User records, messages, uploaded images, credentials and the full database are excluded. Restoring saves a backup of the previous configuration first.</p><label className="system-field"><span>Backup Label</span><input aria-label="Backup Label" maxLength={100} placeholder="Before platform updates" value={backupLabel} onChange={event => setBackupLabel(event.target.value)} /></label><div className="system-backup-actions"><button type="button" className="system-primary" disabled={backup.isPending || !!Object.keys(draft).length} onClick={() => backup.mutate({ label: backupLabel, lock_version: data.lock_version })}><Database size={17} />{backup.isPending ? 'Creating…' : 'Create Configuration Backup'}</button><button type="button" className="system-outline" onClick={() => importInput.current?.click()}><Upload size={17} />Import Backup</button></div>{!!Object.keys(draft).length && <p className="system-note">Save your pending edits before creating a backup.</p>}<h3 className="system-subtitle">Saved Configuration Backups</h3>{backups.isPending ? <PageLoader label="Loading backups…"/> : backups.isError ? <button type="button" className="system-outline" onClick={() => backups.refetch()}>Retry Backups</button> : backups.data?.length ? backups.data.map(item => <div className="system-backup-row" key={item.id}><Database size={25} /><div><strong>{item.label}</strong><small>{platformDate(item.created_at, values, true)} · {item.created_by || 'Former administrator'} · Revision {item.revision}</small></div><button type="button" className="system-outline" disabled={download.isPending} aria-label={`Download ${item.label}`} onClick={() => download.mutate({ id: item.id })}><Download size={16} /></button><button type="button" className="system-outline" disabled={download.isPending} onClick={() => download.mutate({ id: item.id, restore: true })}>Restore</button></div>) : <p className="system-note">No configuration backups yet.</p>}</div>}
      </fieldset></section></div>
      <footer className="system-save-bar"><div><span className="system-saved-icon"><Check size={18} /></span><span>{data.updated_by ? `Last updated: ${platformDate(data.updated_at, values, true)} by ${data.updated_by}` : 'Default configuration. No administrator changes yet.'}{Object.keys(draft).length > 0 && <small>Unsaved changes · Revision {data.lock_version}</small>}</span></div><button className="system-primary" type="submit" disabled={pending || !Object.keys(draft).length || conflict}><Save size={19} />{save.isPending ? 'Saving…' : 'Save Changes'}</button></footer></form>}
      <input className="sr-only" ref={assetInput} type="file" aria-label="Upload platform branding" onChange={event => { const file = event.target.files?.[0]; if (file && data) { if (file.size > 2 * 1024 * 1024) toast.error('Choose an image up to 2 MB'); else upload.mutate({ kind: assetKind.current, file, revision: data.lock_version }); } event.target.value = ''; }} />
      <input className="sr-only" ref={importInput} type="file" accept="application/json,.json" aria-label="Import configuration backup" onChange={async event => { const file = event.target.files?.[0]; event.target.value = ''; if (!file) return; if (file.size > 256 * 1024) return toast.error('Configuration backups must be smaller than 256 KB'); openRestore(await file.text()); }} />
    <Dialog open={!!restoreDocument} onOpenChange={open => { if (!restore.isPending && !open) { setRestoreDocument(null); setConfirmation(''); } }}><DialogContent className="system-restore-dialog"><DialogHeader><DialogTitle>Restore platform configuration?</DialogTitle><DialogDescription>This replaces the saved platform settings. A backup of the current configuration is saved first. Uploaded branding images and member data are preserved. Unsaved edits will be discarded.</DialogDescription></DialogHeader><p className="system-note">Backup created: {restoreDocument?.created_at || 'Unknown'}. The server validates the backup format, checksum, values and your current revision.</p><form onSubmit={event => { event.preventDefault(); if (data && restoreDocument) restore.mutate({ document: restoreDocument, confirmation, lock_version: data.lock_version }); }}><label className="system-field"><span>Type RESTORE to confirm</span><input aria-label="Restore confirmation" autoComplete="off" required value={confirmation} onChange={event => setConfirmation(event.target.value)} /></label><button className="system-primary" disabled={restore.isPending || confirmation !== 'RESTORE'}>{restore.isPending ? 'Restoring…' : 'Restore Configuration'}</button></form></DialogContent></Dialog>
  </AdminWorkspace>;
}
