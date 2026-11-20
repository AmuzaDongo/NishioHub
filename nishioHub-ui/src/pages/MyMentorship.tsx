import { PageLoader } from '@/components/loaders/PageLoader';
import { useState, type ReactNode } from "react";
import { Link, Navigate } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Award, ArrowRight, Bell, BookOpen, CalendarDays, CheckCircle2, ChevronRight, Clock, Copy, ExternalLink, Eye, GraduationCap, Handshake, Home, LayoutGrid, MapPin, Menu, MessageSquare, PlusCircle, Search, Settings, Star, Target, Trash2, TrendingUp, Users, X, Zap } from "lucide-react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { usePlatform, assetUrl } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { useUnreadNotifications } from "@/hooks/use-unread-notifications";
import { hasRole, roleName } from "@/lib/utils";
import { useServices } from "@/lib/services-context";
import { createMentorGoal, createMentorshipResource, deleteMentorshipResource, getMyMentorship, updateMentorGoal, updateMentorshipSession, type MentorshipMentee, type MentorshipResource } from "@/lib/mentorship-api";
import type { Booking } from "@/types";
import { toast } from "sonner";
import "./my-mentorship.css";

type Tab = "mentees" | "sessions" | "requests" | "programmes" | "resources";
const tabs = [
  { id: "mentees", label: "My Mentees", icon: Users },
  { id: "sessions", label: "Sessions", icon: CalendarDays },
  { id: "requests", label: "Mentorship Requests", icon: Handshake },
  { id: "programmes", label: "Programmes", icon: GraduationCap },
  { id: "resources", label: "Resources", icon: BookOpen },
] as const;

function Portrait({ name, src, large = false }: { name: string; src?: string | null; large?: boolean }) {
  const base = (import.meta.env.VITE_API_BASE_URL || "https://api.nishiohub.com/api/v1").replace(/\/api\/v1\/?$/, "");
  const url = src && !/^(https?:|blob:|data:)/.test(src) ? new URL(src.replace(/^\//, ""), `${base}/`).href : src;
  return <Avatar className={large ? "mentorship-portrait" : "h-12 w-12 shrink-0"}>
    <AvatarImage src={url || undefined} alt={name} />
    <AvatarFallback>{name.split(" ").map(part => part[0]).slice(0, 2).join("")}</AvatarFallback>
  </Avatar>;
}
function Panel({ children, className = "", id }: { children: ReactNode; className?: string; id?: string }) {
  return <section id={id} className={`mentorship-panel ${className}`}>{children}</section>;
}
function Empty({ children }: { children: ReactNode }) {
  return <div className="mentorship-empty"><GraduationCap size={30} /><p>{children}</p></div>;
}
function Heading({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return <div className="mentorship-section-heading"><h2>{children}</h2>{action}</div>;
}
function SessionDate({ value }: { value: Date | string }) {
  const date = new Date(value);
  return <div className="mentorship-date"><span>{date.toLocaleDateString(undefined, { month: "short" })}</span><strong>{date.getDate()}</strong></div>;
}
function sessionTime(session: Booking) {
  const start = new Date(session.scheduledAt);
  const end = new Date(start.getTime() + session.duration * 60000);
  return `${start.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric", year: "numeric" })} · ${start.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })} – ${end.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
}
function apiError(error: unknown) {
  const detail = (error as { response?: { data?: { detail?: string | string[] } } })?.response?.data?.detail;
  toast.error(Array.isArray(detail) ? detail.join(", ") : detail || "Could not save your changes. Please try again.");
}

export default function MyMentorshipPage() {
  const unreadNotifications = useUnreadNotifications();
  const { user, isLoading: authLoading } = useAuth();
  const platform = usePlatform();
  const { refresh: refreshServices } = useServices();
  const [tab, setTab] = useState<Tab>("mentees");
  const [search, setSearch] = useState("");
  const [mobileOpen, setMobileOpen] = useState(false);
  const [allMentees, setAllMentees] = useState(false);
  const [selectedMentee, setSelectedMentee] = useState<MentorshipMentee | null>(null);
  const [sessionFilter, setSessionFilter] = useState("upcoming");
  const [goalTitle, setGoalTitle] = useState("");
  const [resourceOpen, setResourceOpen] = useState(false);
  const [resourceTitle, setResourceTitle] = useState("");
  const [resourceUrl, setResourceUrl] = useState("");
  const [deleting, setDeleting] = useState<MentorshipResource | null>(null);
  const client = useQueryClient();
  const queryKey = ["my-mentorship", user?.id];
  const query = useQuery({ queryKey, queryFn: getMyMentorship, enabled: !!user && hasRole(user, "mentor") });
  const refresh = () => client.invalidateQueries({ queryKey });
  const goalMutation = useMutation({ mutationFn: createMentorGoal, onSuccess: () => { setGoalTitle(""); refresh(); toast.success("Goal added"); }, onError: apiError });
  const goalUpdate = useMutation({ mutationFn: updateMentorGoal, onSuccess: refresh, onError: apiError });
  const sessionUpdate = useMutation({ mutationFn: updateMentorshipSession, onSuccess: async () => {
    await Promise.all([refresh(), refreshServices()]);
    toast.success("Session updated");
  }, onError: apiError });
  const resourceMutation = useMutation({ mutationFn: createMentorshipResource, onSuccess: () => { refresh(); setResourceOpen(false); setResourceTitle(""); setResourceUrl(""); toast.success("Resource saved to your library"); }, onError: apiError });
  const resourceDelete = useMutation({ mutationFn: deleteMentorshipResource, onSuccess: () => { refresh(); setDeleting(null); toast.success("Resource removed"); }, onError: apiError });
  if (authLoading) return <PageLoader label="Loading your mentorship…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!hasRole(user, "mentor")) return <Navigate to="/dashboard" replace />;
  const data = query.data;
  const mentor = data?.mentor;
  const name = mentor?.name || user.full_name;
  const now = Date.now();
  const upcoming = data?.sessions.filter(session => session.status === "confirmed" && new Date(session.scheduledAt).getTime() >= now) || [];
  const requests = data?.sessions.filter(session => session.status === "pending") || [];
  const matches = (value: string) => value.toLowerCase().includes(search.trim().toLowerCase());
  const mentees = data?.mentees.filter(mentee => matches(`${mentee.name} ${mentee.school || ""}`)) || [];
  const sessions = data?.sessions.filter(session => matches(`${session.service?.title || ""} ${session.mentee?.name || ""}`) && (tab === "requests" ? session.status === "pending" : sessionFilter === "all" || (sessionFilter === "upcoming" ? session.status === "confirmed" && new Date(session.scheduledAt).getTime() >= now : session.status === sessionFilter))) || [];
  const programmes = data?.programmes.filter(programme => matches(`${programme.title} ${programme.description}`)) || [];
  const resources = data?.resources.filter(resource => matches(resource.title)) || [];
  const switchTab = (next: Tab) => { setTab(next); setMobileOpen(false); };
  const invite = async () => {
    try { await navigator.clipboard.writeText(`${window.location.origin}/mentors/${user.id}`); toast.success("Public profile link copied. Share it to invite a mentee to book."); }
    catch { toast.error("Could not copy the link. Use View Public Profile to share your profile."); }
  };
  const navigation = [
    { label: "Overview", icon: Home, to: "/dashboard" },
    { label: "My Profile", icon: Users, to: "/mentor/profile" },
    { label: "My Mentorship", icon: Handshake, to: "/mentor/mentorship" },
    { label: "My Programmes", icon: LayoutGrid, tab: "programmes" as Tab },
    { label: "Learning Resources", icon: BookOpen, tab: "resources" as Tab },
    { label: "My Sessions", icon: CalendarDays, tab: "sessions" as Tab },
    { label: "My Goals", icon: Target, to: "#mentor-goals" },
    { label: "My Impact", icon: Award, to: "#mentor-impact" },
    { label: "Messages", icon: MessageSquare, to: "/messages" },
    { label: "Notifications", icon: Bell, to: "/notifications" },
    { label: "Settings", icon: Settings, to: "/settings" },
  ];
  function renderSession(session: Booking) {
    const expired = new Date(session.scheduledAt).getTime() <= now;
    return <article key={session.id} className="mentorship-session-row"><SessionDate value={session.scheduledAt} /><div className="mentorship-session-body"><h3>{session.service?.title || "Mentorship session"}</h3><p><Clock size={13} />{sessionTime(session)}</p><p><Users size={13} />With {session.mentee?.name || "your mentee"}</p><span className={`mentorship-status status-${session.status}`}>{session.status}</span></div><div className="mentorship-session-actions">
      {session.status === "pending" && !expired && <Button size="sm" disabled={sessionUpdate.isPending} onClick={() => sessionUpdate.mutate({ id: session.id, status: "confirmed" })}>Accept</Button>}
      {session.status === "pending" && <Button size="sm" variant="outline" disabled={sessionUpdate.isPending} onClick={() => sessionUpdate.mutate({ id: session.id, status: "cancelled" })}>Decline</Button>}
      {session.status === "confirmed" && expired && <Button size="sm" disabled={sessionUpdate.isPending} onClick={() => sessionUpdate.mutate({ id: session.id, status: "completed" })}>Mark Complete</Button>}
      {session.status === "pending" && expired && <span className="mentorship-muted text-xs">Date has passed</span>}
    </div></article>;
  }
  return <div className="mentorship-shell">
    <header className="mentorship-header"><Link to="/" aria-label="NishioHub home"><img src={assetUrl(platform.logo_url) || "/logo.png"} alt={platform.platform_name} /></Link><div className="mentorship-search"><Search size={20} /><input aria-label="Search this mentorship page" placeholder="Search mentees, sessions, resources, or programmes…" value={search} onChange={event => setSearch(event.target.value)} />{search && <button aria-label="Clear search" onClick={() => setSearch("")}><X size={16} /></button>}</div><div className="mentorship-account"><Link to="/notifications" className="workspace-notification-bell" aria-label={`Notifications, ${unreadNotifications} unread`}><Bell size={24} />{unreadNotifications > 0 && <span>{unreadNotifications > 99 ? "99+" : unreadNotifications}</span>}</Link><Link to="/mentor/profile" className="mentorship-account-profile"><Portrait name={name} src={mentor?.avatar} /><span><strong>{name}</strong><small>Mentor</small></span></Link><button className="mentorship-menu-toggle" aria-label="Toggle navigation" aria-expanded={mobileOpen} onClick={() => setMobileOpen(!mobileOpen)}>{mobileOpen ? <X /> : <Menu />}</button></div></header>
    <aside className={`mentorship-sidebar ${mobileOpen ? "is-open" : ""}`}><nav aria-label="Mentor navigation">{navigation.map(item => item.tab ? <button key={item.label} onClick={() => switchTab(item.tab!)}><item.icon size={21} />{item.label}</button> : item.to?.startsWith("#") ? <a key={item.label} href={item.to} onClick={() => setMobileOpen(false)}><item.icon size={21} />{item.label}</a> : <Link key={item.label} to={item.to!} className={item.label === "My Mentorship" ? "active" : ""} aria-current={item.label === "My Mentorship" ? "page" : undefined} onClick={() => setMobileOpen(false)}><item.icon size={21} />{item.label}</Link>)}</nav><div className="mentorship-invite"><GraduationCap size={49} /><h3>Mentor the<br />Next Generation</h3><p>Share your knowledge, experience and network.</p><button onClick={invite}>Invite a Mentee<ArrowRight size={17} /></button></div></aside>
    <main className="mentorship-main"><div className="mentorship-breadcrumb"><Link to="/dashboard" aria-label="Dashboard"><Home size={18} /></Link><ChevronRight size={14} /><span>My Mentorship</span></div><div className="mentorship-page-heading"><div><div className="flex flex-wrap items-center gap-3"><h1>My Mentorship</h1><span className="mentorship-role">Mentor</span>{mentor?.isVerified && <Award className="text-violet-600" aria-label="Verified mentor" />}</div><p>Guide, support and grow the next generation of learners and professionals.</p></div><div className="flex flex-wrap gap-3"><Button asChild variant="outline"><Link to={`/mentors/${user.id}`}><Eye size={17} className="mr-2" />View Public Profile</Link></Button><Button asChild><Link to="/services/create"><PlusCircle size={17} className="mr-2" />Create Mentorship Programme</Link></Button></div></div>
      <div className="mentorship-mobile-search"><Search size={18} /><input aria-label="Search mentorship" placeholder="Search this mentorship page…" value={search} onChange={event => setSearch(event.target.value)} />{search && <button aria-label="Clear search" onClick={() => setSearch("")}><X size={16} /></button>}</div>
      {query.isPending ? <Panel><PageLoader label="Loading your mentorship…"/></Panel> : query.isError ? <Panel><h2>We couldn’t load your mentorship</h2><p className="mentorship-muted my-3">Please check your connection and try again.</p><Button onClick={() => query.refetch()}>Try Again</Button></Panel> : data && <>
        <Panel className="mentorship-summary"><div className="mentorship-identity"><div className="mentorship-avatar-wrap"><Portrait name={name} src={mentor?.avatar} large />{mentor?.isVerified && <CheckCircle2 className="mentorship-verified" />}</div><div><h2>{name}</h2><p className="mentorship-headline">{mentor?.title || "Mentor · Helping you discover your potential"}</p>{mentor?.location && <p className="mentorship-location"><MapPin size={17} />{mentor.location}</p>}<span className="mentorship-experience"><Award size={15} />{mentor?.yearsOfExperience || 0} years experience</span></div></div><div className="mentorship-stats">{[
          { icon: Users, value: data.stats.mentees, label: "Mentees", color: "purple" },
          { icon: CalendarDays, value: data.stats.sessions, label: "Sessions Completed", color: "blue" },
          { icon: Clock, value: data.stats.hours, label: "Hours Mentored", color: "green" },
          { icon: Target, value: data.stats.active_goals, label: "Goals Active", color: "amber" },
        ].map(stat => <div key={stat.label} className={`mentorship-stat ${stat.color}`}><stat.icon size={29} /><strong>{stat.value}</strong><span>{stat.label}</span></div>)}</div></Panel>
        <div className="mentorship-tabs" role="tablist" aria-label="Mentorship sections">{tabs.map(({ id, label, icon: Icon }, index) => <button id={`mentorship-tab-${id}`} aria-controls="mentorship-tabpanel" role="tab" aria-selected={tab === id} tabIndex={tab === id ? 0 : -1} key={id} onClick={() => setTab(id)} onKeyDown={event => { if (["ArrowRight", "ArrowLeft", "Home", "End"].includes(event.key)) { event.preventDefault(); const next = event.key === "Home" ? 0 : event.key === "End" ? tabs.length - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + tabs.length) % tabs.length; setTab(tabs[next].id); document.getElementById(`mentorship-tab-${tabs[next].id}`)?.focus(); } }}><Icon size={22} />{label}{id === "requests" && requests.length > 0 && <span className="mentorship-request-count">{requests.length}</span>}</button>)}</div>
        <div id="mentorship-tabpanel" role="tabpanel" aria-labelledby={`mentorship-tab-${tab}`}>
          {tab === "mentees" ? <div className="mentorship-content-grid"><Panel><Heading action={<button className="mentorship-text-action" onClick={() => setAllMentees(!allMentees)}>{allMentees ? "Show Less" : "View All"}<ArrowRight size={15} /></button>}><Users size={21} />My Mentees ({mentees.length})</Heading>{mentees.length ? <><div className="mentorship-mentee-list">{(allMentees ? mentees : mentees.slice(0, 3)).map(mentee => <article key={mentee.id} className="mentorship-mentee-row"><Portrait name={mentee.name} src={mentee.avatar} /><div className="mentorship-mentee-name"><h3>{mentee.name}</h3><p>{mentee.school || `${mentee.completed_sessions} sessions completed`}</p></div><div className="mentorship-progress-group"><div className="mentorship-progress" role="progressbar" aria-label={`${mentee.name}: booked sessions completed`} aria-valuenow={mentee.progress} aria-valuemin={0} aria-valuemax={100}><span style={{ width: `${mentee.progress}%` }} /></div><strong>{mentee.progress}%</strong></div><Button size="sm" variant="outline" onClick={() => setSelectedMentee(mentee)}>View Profile</Button></article>)}</div><p className="mentorship-progress-note">Progress shows completed sessions out of non-cancelled bookings with you.</p></> : <Empty>{search ? "No mentees match your search." : "Your mentees will appear here when they request a session. Share your public profile to get started."}</Empty>}</Panel><Panel><Heading action={<button className="mentorship-text-action" onClick={() => switchTab("sessions")}>View All<ArrowRight size={15} /></button>}><CalendarDays size={21} />Upcoming Sessions</Heading>{upcoming.filter(session => matches(`${session.service?.title} ${session.mentee?.name}`)).slice(0, 3).map(session => <article className="mentorship-upcoming-row" key={session.id}><SessionDate value={session.scheduledAt} /><div><h3>{session.service?.title}</h3><p><Clock size={13} />{sessionTime(session)}</p><p><Users size={13} />With {session.mentee?.name}</p></div></article>)}{!upcoming.filter(session => matches(`${session.service?.title} ${session.mentee?.name}`)).length && <Empty>{search ? "No upcoming sessions match your search." : "No confirmed sessions coming up. Review your requests to plan your next conversation."}</Empty>}</Panel><Panel className="mentorship-quick"><Heading><Zap size={25} />Quick Actions</Heading><Link to="/mentor/profile"><CalendarDays size={20} />Manage Availability<ChevronRight size={17} /></Link><button onClick={invite}><Users size={20} />Invite a Mentee<ChevronRight size={17} /></button><button onClick={() => switchTab("requests")}><Handshake size={20} />Review Requests {requests.length > 0 && <span>({requests.length})</span>}<ChevronRight size={17} /></button><button onClick={() => { switchTab("resources"); setResourceOpen(true); }}><BookOpen size={20} />Add a Resource<ChevronRight size={17} /></button></Panel></div>
          : tab === "sessions" || tab === "requests" ? <Panel><Heading action={tab === "sessions" && <select aria-label="Filter sessions" value={sessionFilter} onChange={event => setSessionFilter(event.target.value)} className="mentorship-select"><option value="upcoming">Upcoming</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option><option value="all">All Sessions</option></select>}><CalendarDays size={22} />{tab === "requests" ? "Mentorship Requests" : "My Sessions"}</Heading>{sessions.length ? sessions.map(renderSession) : <Empty>{search ? "No sessions match your search." : tab === "requests" ? "You’re all caught up. New booking requests will appear here." : "No sessions in this view yet."}</Empty>}</Panel>
          : tab === "programmes" ? <Panel><Heading action={<Link className="mentorship-text-action" to="/services/create"><PlusCircle size={16} />Create Programme</Link>}><GraduationCap size={22} />My Programmes</Heading><p className="mentorship-muted mt-2">Your active mentoring services, available for mentees to book.</p>{programmes.length ? <div className="mentorship-programmes">{programmes.map(programme => <Link to={`/services/${programme.id}`} key={programme.id}><GraduationCap size={30} /><h3>{programme.title}</h3><p>{programme.description}</p><span><Clock size={14} />{programme.duration} min<ArrowRight size={16} /></span></Link>)}</div> : <Empty>{search ? "No programmes match your search." : "Create your first programme to help mentees discover what you offer."}</Empty>}</Panel>
          : <Panel><Heading action={<Button size="sm" onClick={() => setResourceOpen(true)}><PlusCircle size={16} className="mr-2" />Add Resource</Button>}><BookOpen size={22} />My Resource Library</Heading><p className="mentorship-muted mt-2">Save useful links, then copy them to share with mentees in a message.</p>{resources.length ? <div className="mentorship-resource-list">{resources.map(resource => <article key={resource.id}><BookOpen size={24} /><div><a href={resource.url} target="_blank" rel="noopener noreferrer">{resource.title}<ExternalLink size={14} /></a><p>{resource.url}</p></div><Button size="icon" variant="ghost" aria-label={`Copy link for ${resource.title}`} onClick={async () => { try { await navigator.clipboard.writeText(resource.url); toast.success("Resource link copied"); } catch { toast.error("Could not copy the link"); } }}><Copy size={17} /></Button><Button size="icon" variant="ghost" aria-label={`Remove ${resource.title}`} onClick={() => setDeleting(resource)}><Trash2 size={17} /></Button></article>)}</div> : <Empty>{search ? "No resources match your search." : "Build your library with articles, videos, and tools that inspire learning."}</Empty>}</Panel>}
        </div>
        <div className="mentorship-bottom-grid"><Panel id="mentor-goals"><Heading><Target size={24} />Mentorship Goals</Heading>{data.goals.length ? <ul className="mentorship-goals">{data.goals.map(goal => <li key={goal.id}><label><input type="checkbox" checked={goal.completed} disabled={goalUpdate.isPending} onChange={event => goalUpdate.mutate({ id: goal.id, completed: event.target.checked })} /><span className={goal.completed ? "is-complete" : ""}>{goal.title}</span>{goal.completed && <small>Completed</small>}</label></li>)}</ul> : <p className="mentorship-muted my-5">Set an intention for your mentoring journey.</p>}<form className="mentorship-goal-form" onSubmit={event => { event.preventDefault(); if (goalTitle.trim()) goalMutation.mutate(goalTitle.trim()); }}><Input aria-label="New mentorship goal" placeholder="What would you like to achieve?" maxLength={200} value={goalTitle} onChange={event => setGoalTitle(event.target.value)} required /><Button type="submit" disabled={goalMutation.isPending || !goalTitle.trim()}>{goalMutation.isPending ? "Adding…" : "Add Goal"}</Button></form></Panel><Panel className="mentorship-impact" id="mentor-impact"><Heading><TrendingUp size={24} />My Mentorship Impact</Heading><div className="mentorship-impact-stats"><div><Users /><strong>{data.stats.mentees}</strong><span>Mentees<br />Supported</span></div><div><GraduationCap /><strong>{data.stats.completed_goals}</strong><span>Mentor Goals<br />Completed</span></div><div><Star /><strong>{data.stats.rating ?? "—"}</strong><span>Average Rating<br />{data.stats.review_count} reviews · out of 5</span></div><div><TrendingUp /><strong>{data.stats.hours}</strong><span>Hours<br />Mentored</span></div></div></Panel></div>
      </>}
    </main>
    <Dialog open={!!selectedMentee} onOpenChange={open => { if (!open) setSelectedMentee(null); }}><DialogContent><DialogHeader><DialogTitle>Mentee Overview</DialogTitle><DialogDescription>Your mentorship sessions with this learner.</DialogDescription></DialogHeader>{selectedMentee && <div className="space-y-4"><div className="flex items-center gap-4"><Portrait name={selectedMentee.name} src={selectedMentee.avatar} /><div><h3 className="font-semibold text-lg">{selectedMentee.name}</h3><p className="mentorship-muted">{[selectedMentee.school, selectedMentee.grade].filter(Boolean).join(" · ") || "School details not added"}</p></div></div><p>{selectedMentee.completed_sessions} of {selectedMentee.total_sessions} booked sessions completed with you.</p><Button onClick={() => { setSearch(selectedMentee.name); setSessionFilter("all"); setTab("sessions"); setSelectedMentee(null); }}>View Sessions<ArrowRight size={16} className="ml-2" /></Button></div>}</DialogContent></Dialog>
    <Dialog open={resourceOpen} onOpenChange={setResourceOpen}><DialogContent><DialogHeader><DialogTitle>Add a Learning Resource</DialogTitle><DialogDescription>Save a useful link to your personal resource library.</DialogDescription></DialogHeader><form className="space-y-4" onSubmit={event => { event.preventDefault(); resourceMutation.mutate({ title: resourceTitle.trim(), url: resourceUrl.trim() }); }}><div><Label htmlFor="resource-title">Title</Label><Input id="resource-title" value={resourceTitle} onChange={event => setResourceTitle(event.target.value)} maxLength={200} required /></div><div><Label htmlFor="resource-url">Link</Label><Input id="resource-url" type="url" placeholder="https://…" pattern="https?://.+" maxLength={2000} value={resourceUrl} onChange={event => setResourceUrl(event.target.value)} required /></div><Button type="submit" disabled={resourceMutation.isPending || !resourceTitle.trim() || !resourceUrl.trim()}>{resourceMutation.isPending ? "Saving…" : "Save Resource"}</Button></form></DialogContent></Dialog>
    <AlertDialog open={!!deleting} onOpenChange={open => { if (!open) setDeleting(null); }}><AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Remove this resource?</AlertDialogTitle><AlertDialogDescription>“{deleting?.title}” will be removed from your library. Links already shared with mentees will still work.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Keep Resource</AlertDialogCancel><AlertDialogAction disabled={resourceDelete.isPending} onClick={event => { event.preventDefault(); if (deleting) resourceDelete.mutate(deleting.id); }}>{resourceDelete.isPending ? "Removing…" : "Remove Resource"}</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog>
  </div>;
}
