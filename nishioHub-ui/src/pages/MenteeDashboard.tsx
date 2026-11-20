import { PageLoader } from '@/components/loaders/PageLoader';
import { useState, type FormEvent, type ReactNode } from "react";
import { Link, Navigate } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowRight, Bell, BookOpen, CalendarDays, CheckCircle2, GraduationCap, HelpCircle, Home, MapPin, Menu, MessageSquare, Pencil, Search, Settings, Sparkles, Star, Target, Trophy, UserRound, Users, X } from "lucide-react";
import { usePlatform, assetUrl } from "@/lib/platform-context";
import { useAuth } from "@/lib/auth-context";
import { useUnreadNotifications } from "@/hooks/use-unread-notifications";
import { hasRole, roleName } from "@/lib/utils";
import { createMenteeGoal, getMenteeDashboard, saveMenteeProfile, updateMenteeGoal, type MenteeProfile } from "@/lib/mentee-dashboard-api";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { toast } from "sonner";
import "./mentee-dashboard.css";

function Panel({ children, className = "", id }: { children: ReactNode; className?: string; id?: string }) {
  return <section id={id} className={`mentee-panel ${className}`}>{children}</section>;
}
function Action({ to, children }: { to: string; children: ReactNode }) {
  return <Link className="mentee-action" to={to}>{children}<ArrowRight size={17} /></Link>;
}
function Progress({ value, label }: { value: number; label: string }) {
  return <div className="mentee-progress-row"><div role="progressbar" aria-label={label} aria-valuenow={value} aria-valuemin={0} aria-valuemax={100} className="mentee-progress"><span style={{ width: `${value}%` }} /></div><strong>{value}%</strong></div>;
}
function PersonAvatar({ name, src, large = false }: { name: string; src?: string | null; large?: boolean }) {
  const url = src && !/^(https?:|data:|blob:)/.test(src)
    ? new URL(src.replace(/^\//, ""), `${(import.meta.env.VITE_API_BASE_URL || "https://api.nishiohub.com/api/v1").replace(/\/api\/v1\/?$/, "")}/`).href : src;
  return <Avatar className={large ? "mentee-portrait" : "h-16 w-16 shrink-0"}><AvatarImage src={url || undefined} alt={name} /><AvatarFallback className="bg-violet-100 text-violet-800">{name.split(" ").map(part => part[0]).slice(0, 2).join("")}</AvatarFallback></Avatar>;
}

export default function MenteeDashboardPage() {
  const unreadNotifications = useUnreadNotifications();
  const { user, isLoading: authLoading } = useAuth();
  const platform = usePlatform();
  const [menuOpen, setMenuOpen] = useState(false);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<Partial<MenteeProfile>>({});
  const [goalTitle, setGoalTitle] = useState("");
  const queryClient = useQueryClient();
  const queryKey = ["mentee-dashboard", user?.id];
  const query = useQuery({ queryKey, queryFn: getMenteeDashboard, enabled: !!user && hasRole(user, "mentee") });
  const refresh = () => queryClient.invalidateQueries({ queryKey });
  const profileMutation = useMutation({ mutationFn: saveMenteeProfile, onSuccess: () => { refresh(); setEditing(false); toast.success("Profile saved"); }, onError: () => toast.error("Could not save your profile. Please try again.") });
  const goalMutation = useMutation({ mutationFn: createMenteeGoal, onSuccess: () => { refresh(); setGoalTitle(""); toast.success("Goal added"); }, onError: () => toast.error("Could not add your goal. Please try again.") });
  const completeMutation = useMutation({ mutationFn: ({ id, completed }: { id: number; completed: boolean }) => updateMenteeGoal(id, completed), onSuccess: refresh, onError: () => toast.error("Could not update your goal. Please try again.") });
  if (authLoading) return <PageLoader label="Loading your dashboard…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!hasRole(user, "mentee")) return <Navigate to="/dashboard" replace />;
  const data = query.data;
  const profile = data?.profile;
  const name = profile?.name || user.full_name;
  const mentor = data?.mentor;
  const session = data?.next_session;
  const activeGoals = data?.goals.filter(goal => !goal.completed).length || 0;
  const navigation = [
    { label: "Overview", to: "/mentee/dashboard", icon: Home },
    { label: "My Profile", to: "#my-profile", icon: UserRound },
    { label: "My Mentorship", to: "#mentorship", icon: Users },
    { label: "Find a Mentor", to: "/services", icon: Search },
    { label: "Learning Area", to: "/learning-area", icon: BookOpen },
    { label: "My Goals", to: "/my-goals", icon: Target },
    { label: "My Activities", to: "/my-activities", icon: CalendarDays },
    { label: "My Achievements", to: "/my-achievements", icon: Trophy },
    { label: "Events", to: "/events", icon: CalendarDays },
    { label: "Messages", to: "/messages", icon: MessageSquare },
    { label: "Notifications", to: "/notifications", icon: Bell },
    { label: "Help and Support", to: "/help", icon: HelpCircle },
    { label: "Account Settings", to: "/settings", icon: Settings },
  ];
  const closeMenu = () => setMenuOpen(false);
  return <div className="mentee-shell">
    <header className="mentee-header">
      <Link to="/" aria-label="NishioHub home"><img src={assetUrl(platform.logo_url) || "/logo.png"} alt={platform.platform_name} className="mentee-logo" /></Link>
      <form action="/services" className="mentee-search"><Search size={21} /><input aria-label="Search mentors and services" name="q" placeholder="Search mentors, skills, or learning opportunities…" /></form>
      <div className="flex items-center gap-3"><Link to="/notifications" aria-label={`Notifications, ${unreadNotifications} unread`} className="p-2 workspace-notification-bell"><Bell size={25} />{unreadNotifications > 0 && <span>{unreadNotifications > 99 ? "99+" : unreadNotifications}</span>}</Link><PersonAvatar name={name} src={profile?.avatar} /><button className="mentee-menu" aria-label={menuOpen ? "Close navigation" : "Open navigation"} aria-expanded={menuOpen} onClick={() => setMenuOpen(!menuOpen)}>{menuOpen ? <X /> : <Menu />}</button></div>
    </header>
    <aside className={`mentee-sidebar ${menuOpen ? "is-open" : ""}`}><p className="mentee-nav-caption">YOUR LEARNING SPACE</p><nav aria-label="Mentee navigation">{navigation.map(({ label, to, icon: Icon }, index) => to.startsWith("#") ? <a key={label} href={to} onClick={closeMenu}><Icon size={20} />{label}</a> : <Link key={label} to={to} onClick={closeMenu} className={index === 0 ? "is-active" : ""} aria-current={index === 0 ? "page" : undefined}><Icon size={20} />{label}</Link>)}</nav><div className="mentee-sidebar-note"><Sparkles size={22} /><p>Small steps.<br /><strong>Bright futures.</strong></p></div></aside>
    <main className="mentee-main">
      <div className="mentee-welcome"><div><p className="mentee-eyebrow">DISCOVER. LEARN. GROW.</p><h1>Your next chapter starts here.</h1></div><span className="mentee-welcome-tag"><Sparkles size={16} /> Your mentee dashboard</span></div>
      {query.isPending ? <Panel><PageLoader label="Loading your learning journey…"/></Panel> : query.isError ? <Panel><h2>We couldn’t load your dashboard</h2><p className="mentee-muted">Please check your connection and try again.</p><Button onClick={() => query.refetch()} className="mt-4">Try again</Button></Panel> : data && <>
        <div className="mentee-hero-grid">
          <Panel id="my-profile" className="mentee-profile-card"><PersonAvatar name={name} src={profile?.avatar} large /><div className="min-w-0"><div className="flex flex-wrap items-center gap-3"><h2 className="mentee-name">{name}</h2><span className="mentee-role">Mentee</span></div><p className="mentee-school"><GraduationCap size={22} />{profile?.school || "Add your school"}</p><div className="mentee-profile-meta"><span><BookOpen size={18} />Class: {profile?.grade || "Not added"}</span><span><MapPin size={18} />{profile?.location || "Add your location"}</span></div><p className="mentee-bio">{profile?.bio || "Tell us what you love learning and who you dream of becoming."}</p><Button variant="outline" className="mentee-outline" onClick={() => { setDraft({ school: profile?.school || "", grade: profile?.grade || "", location: profile?.location || "", bio: profile?.bio || "" }); setEditing(true); }}><Pencil size={16} className="mr-2" />Edit Profile</Button></div></Panel>
          <Panel className="mentee-journey"><h2>My Learning Journey</h2><Progress value={data.session_progress} label="Session milestone progress" /><div className="mentee-milestone"><div><p className="font-semibold">Next milestone</p><p>Complete {data.milestone} mentorship sessions</p><p className="mentee-muted mt-2">{data.completed_sessions} completed · Keep growing!</p></div><Trophy size={72} strokeWidth={1.4} className="text-amber-500 shrink-0" /></div><Action to="/bookings">View Progress</Action></Panel>
        </div>
        <div className="mentee-stats">
          <Panel><div className="mentee-stat-top">{mentor ? <PersonAvatar name={mentor.name} src={mentor.avatar} /> : <Users className="mentee-stat-icon" />}<div><p>My Mentor</p><h3>{mentor?.name || "Your journey awaits"}</h3></div></div><Action to={mentor ? `/mentors/${mentor.id}` : "/services"}>{mentor ? "View Profile" : "Find a Mentor"}</Action></Panel>
          <Panel><div className="mentee-stat-top"><CalendarDays className="mentee-stat-icon" /><div><p>Upcoming Session</p><h3>{session ? new Date(session.scheduledAt).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "No sessions booked"}</h3>{session && <p>{new Date(session.scheduledAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })} · {session.status}</p>}</div></div><Action to="/bookings">{session ? "View Sessions" : "My Bookings"}</Action></Panel>
          <Panel><div className="mentee-stat-top"><Target className="mentee-stat-icon text-rose-500" /><div><p>My Goals</p><h3>{activeGoals} Active {activeGoals === 1 ? "Goal" : "Goals"}</h3></div></div><Action to="/my-goals">View Goals</Action></Panel>
          <Panel><div className="mentee-stat-top"><Star className="mentee-stat-icon text-amber-500" /><div><p>My Achievements</p><h3>{data.achievements.length} {data.achievements.length === 1 ? "Badge" : "Badges"}</h3></div></div><Action to="/my-achievements">View All</Action></Panel>
        </div>
        <div className="mentee-two-columns">
          <Panel id="mentorship"><div className="mentee-section-heading"><h2>My Mentorship</h2><span className="mentee-status">{mentor ? "Connected" : "Get started"}</span></div>{mentor ? <><div className="flex items-center gap-4 my-5"><PersonAvatar name={mentor.name} src={mentor.avatar} /><div><h3>Connected with: {mentor.name}</h3><p className="mentee-muted">{mentor.title || "Take the next step in your learning journey."}</p></div></div><p className="font-semibold text-sm">Sessions toward your next milestone</p><Progress value={data.session_progress} label="Mentorship session progress" /><Action to="/bookings">View Mentorship Sessions</Action></> : <div className="mentee-empty"><Users size={36} /><h3>Meet someone who inspires you</h3><p>Find a mentor to explore your interests and build your confidence.</p><Action to="/services">Find your first mentor</Action></div>}</Panel>
          <Panel id="learning"><div className="mentee-section-heading"><h2>Explore Learning Areas</h2><Action to="/learning-area">Explore more</Action></div>{data.learning_areas.length ? <div className="mentee-learning-grid">{data.learning_areas.map((area, index) => <Link to={`/categories/${area.slug}`} key={area.id} className="mentee-learning-card"><div>{area.image_url ? <img src={area.image_url} alt="" /> : index === 0 ? <BookOpen /> : index === 1 ? <GraduationCap /> : <Sparkles />}</div><h3>{area.name}</h3></Link>)}</div> : <div className="mentee-empty"><BookOpen size={36} /><p>Learning areas will appear here when available.</p></div>}</Panel>
          <Panel id="goals"><div className="mentee-section-heading"><h2>My Goals</h2><Target className="text-violet-600" /></div><Progress value={data.goal_progress} label="Completed goals" />{data.goals.length ? <ul className="mentee-goals">{data.goals.map(goal => <li key={goal.id}><label><input type="checkbox" checked={goal.completed} disabled={completeMutation.isPending} onChange={event => completeMutation.mutate({ id: goal.id, completed: event.target.checked })} /><span className={goal.completed ? "line-through text-slate-500" : ""}>{goal.title}</span>{goal.completed && <CheckCircle2 size={16} className="text-green-600 shrink-0" />}</label></li>)}</ul> : <p className="mentee-muted my-5">Every journey starts with a goal. What would you like to learn?</p>}<form className="flex gap-2 mt-4" onSubmit={(event: FormEvent) => { event.preventDefault(); if (goalTitle.trim()) goalMutation.mutate(goalTitle.trim()); }}><Input aria-label="New goal" maxLength={200} placeholder="Set a new learning goal…" value={goalTitle} onChange={event => setGoalTitle(event.target.value)} required /><Button disabled={goalMutation.isPending || !goalTitle.trim()} type="submit">{goalMutation.isPending ? "Adding…" : "Add Goal"}</Button></form></Panel>
          <div className="space-y-5"><Panel className="mentee-quick"><h2>Quick Actions</h2><div className="mentee-quick-grid"><Action to="/services"><Search size={19} />Find a Mentor</Action><Action to="/learning-area"><BookOpen size={19} />Explore Learning</Action><Action to="/bookings"><CalendarDays size={19} />My Sessions</Action><Action to="/messages"><MessageSquare size={19} />My Messages</Action></div></Panel><Panel id="achievements"><div className="mentee-section-heading"><h2>My Achievements</h2><Trophy className="text-amber-500" /></div>{data.achievements.length ? <div className="mentee-badges">{data.achievements.map(badge => <span key={badge}><Star size={20} />{badge}</span>)}</div> : <p className="mentee-muted mt-3">Complete a session or a goal to earn your first badge.</p>}</Panel></div>
        </div>
      </>}
      <p className="mentee-footer">A little curiosity today. A world of possibilities tomorrow.</p>
    </main>
    <Dialog open={editing} onOpenChange={setEditing}><DialogContent><DialogHeader><DialogTitle>Edit your profile</DialogTitle><DialogDescription>Share your school, interests, and learning ambitions.</DialogDescription></DialogHeader><form className="space-y-4" onSubmit={event => { event.preventDefault(); profileMutation.mutate(draft); }}>{([ ["school", "School", 150], ["grade", "Class / Grade", 50], ["location", "Location", 150] ] as const).map(([field, label, max]) => <div key={field}><Label htmlFor={`mentee-${field}`}>{label}</Label><Input id={`mentee-${field}`} maxLength={max} value={draft[field] || ""} onChange={event => setDraft({ ...draft, [field]: event.target.value })} /></div>)}<div><Label htmlFor="mentee-bio">About me</Label><Textarea id="mentee-bio" maxLength={1000} value={draft.bio || ""} onChange={event => setDraft({ ...draft, bio: event.target.value })} /></div><Button type="submit" disabled={profileMutation.isPending}>{profileMutation.isPending ? "Saving…" : "Save Profile"}</Button></form></DialogContent></Dialog>
  </div>;
}
