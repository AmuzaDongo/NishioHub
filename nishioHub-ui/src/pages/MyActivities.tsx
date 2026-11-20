import { PageLoader } from '@/components/loaders/PageLoader';
import { useState, type ReactNode } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Activity, ArrowRight, Award, BookOpen, CalendarCheck, CalendarDays, Check, CheckCircle2, ChevronLeft, ChevronRight, Circle, CircleDashed, Clock, GraduationCap, Laptop, Play, Target, Trophy, Users, X } from "lucide-react";
import { MenteeWorkspace } from "@/components/layout/mentee-workspace";
import { Button } from "@/components/ui/button";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth-context";
import { hasRole, roleName } from "@/lib/utils";
import { getMyActivities, type ActivityStatus, type LearnerActivity } from "@/lib/activities-api";
import "./my-activities.css";

const timezone = "Africa/Kampala";
const dateOptions: Intl.DateTimeFormatOptions = { timeZone: timezone, month: "short", day: "numeric", year: "numeric", hour: "numeric", minute: "2-digit" };
const icons = { calendar: CalendarDays, book: BookOpen, play: Play, laptop: Laptop, users: Users, target: Target, trophy: Trophy };
const labels: Record<ActivityStatus, string> = { completed: "Completed", in_progress: "In Progress", upcoming: "Upcoming", cancelled: "Cancelled" };
const tabs = [ { id: "all", title: "All Activities", icon: GraduationCap }, { id: "learning", title: "Learning", icon: BookOpen }, { id: "mentorship", title: "Mentorship", icon: Users }, { id: "events", title: "Events", icon: CalendarDays }, { id: "challenges", title: "Challenges", icon: Award } ];
function dayKey(date: Date) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en", { timeZone: timezone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(date).map(part => [part.type, part.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}
function Panel({ children, className = "" }: { children: ReactNode; className?: string }) { return <section className={`activities-panel ${className}`}>{children}</section>; }
function StatusBadge({ status }: { status: ActivityStatus }) {
  return <span className={`activity-status ${status}`}>{status === "completed" ? <CheckCircle2 size={17} /> : status === "in_progress" ? <CircleDashed size={17} /> : null}{labels[status]}</span>;
}
export default function MyActivitiesPage() {
  const { user, isLoading: authLoading } = useAuth();
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState("all");
  const [status, setStatus] = useState<ActivityStatus | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);
  const today = dayKey(new Date());
  const [month, setMonth] = useState(() => { const [year, monthNumber] = today.split("-").map(Number); return new Date(year, monthNumber - 1, 1); });
  const query = useQuery({ queryKey: ["my-activities", user?.id], queryFn: getMyActivities, enabled: !!user && hasRole(user, "mentee") });
  if (authLoading) return <PageLoader label="Loading your activities…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!hasRole(user, "mentee")) return <Navigate to="/dashboard" replace />;
  const data = query.data;
  const activities = data?.activities || [];
  const matches = activities.filter(item => (tab === "all" || item.category === tab) && `${item.title} ${item.description}`.toLowerCase().includes(search.trim().toLowerCase()));
  const filtered = matches.filter(item => (!status || item.status === status) && (!selectedDay || dayKey(new Date(item.occurred_at)) === selectedDay));
  const recent = (status === "upcoming" || selectedDay ? filtered : filtered.filter(item => item.status !== "upcoming")).sort((a, b) => status === "upcoming" ? a.occurred_at.localeCompare(b.occurred_at) : b.occurred_at.localeCompare(a.occurred_at));
  const upcoming = matches.filter(item => item.status === "upcoming" && (!selectedDay || dayKey(new Date(item.occurred_at)) === selectedDay)).sort((a, b) => a.occurred_at.localeCompare(b.occurred_at));
  const visible = showAll ? recent : recent.slice(0, 5);
  const activitiesByDay = new Map<string, LearnerActivity[]>();
  for (const entry of matches) {
    const key = dayKey(new Date(entry.occurred_at));
    activitiesByDay.set(key, [...(activitiesByDay.get(key) || []), entry]);
  }
  const monthLabel = month.toLocaleDateString(undefined, { month: "long", year: "numeric" });
  const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const stats = [ { label: "Total Activities", value: data?.stats.total || 0, icon: CalendarCheck, color: "purple", valueFilter: null }, { label: "Completed", value: data?.stats.completed || 0, icon: Check, color: "green", valueFilter: "completed" as ActivityStatus }, { label: "In Progress", value: data?.stats.in_progress || 0, icon: Play, color: "blue", valueFilter: "in_progress" as ActivityStatus }, { label: "Upcoming", value: data?.stats.upcoming || 0, icon: Clock, color: "amber", valueFilter: "upcoming" as ActivityStatus } ];
  const clearFilters = () => { setSearch(""); setTab("all"); setStatus(null); setSelectedDay(null); };
  function renderEntry(item: LearnerActivity, compact = false) {
    const Icon = icons[item.icon] || CalendarDays;
    return <Link key={item.id} to={item.href} className={`activity-entry ${compact ? "compact" : ""} ${item.status}`}><div className={`activity-entry-icon ${item.icon}`}><Icon size={compact ? 31 : 37} /></div><div className="activity-entry-copy"><h3>{item.title}</h3><p>{item.description}</p><time dateTime={item.occurred_at}><CalendarDays size={15} />{new Date(item.occurred_at).toLocaleString(undefined, dateOptions)}</time></div><StatusBadge status={item.status} /></Link>;
  }
  return <MenteeWorkspace title="My Activities" name={data?.name || user.full_name} avatar={data?.avatar} activePage="activities" search={search} onSearch={setSearch} searchPlaceholder="Search for courses, activities, mentors, or events..." sidebarAction={() => navigate("/learning-area")}>
    <div className="activities-page-heading"><h1>My Activities</h1><p>Track your learning, mentorship and platform activities.</p></div>
    {query.isPending ? <Panel><PageLoader label="Loading your activities…"/></Panel> : query.isError ? <Panel><h2>We couldn’t load your activities</h2><p className="my-4">Please check your connection and try again.</p><Button onClick={() => query.refetch()}>Try Again</Button></Panel> : data && <>
      <div className="activities-stats">{stats.map(stat => <button key={stat.label} className={`activities-stat ${stat.color}`} aria-pressed={status === stat.valueFilter} onClick={() => { setStatus(stat.valueFilter); setShowAll(true); setSelectedDay(null); }}><span className="activities-stat-icon"><stat.icon size={40} /></span><span><strong>{stat.value}</strong><small>{stat.label}</small></span></button>)}</div>
      <Tabs value={tab} onValueChange={value => { setTab(value); setShowAll(false); setSelectedDay(null); }} className="activities-tabs-root"><TabsList className="activities-tabs">{tabs.map(({ id, title, icon: Icon }) => <TabsTrigger key={id} id={`activity-tab-${id}`} aria-controls="activities-content" value={id}><Icon size={25} />{title}</TabsTrigger>)}</TabsList></Tabs>
      {(search || status || selectedDay) && <div className="activities-filters"><span>{selectedDay ? `Activities on ${new Date(`${selectedDay}T12:00:00`).toLocaleDateString(undefined, { dateStyle: "long" })}` : status ? labels[status] : `Search: “${search}”`}</span><button onClick={clearFilters}>Clear Filters<X size={14} /></button></div>}
      <div className="activities-columns" id="activities-content" role="tabpanel" aria-labelledby={`activity-tab-${tab}`}><Panel className="activities-recent"><div className="activities-section-heading"><h2><Activity />{status === "upcoming" ? "Upcoming Activities" : selectedDay ? "Activities on This Day" : "Recent Activities"}</h2><button className="activities-text-action" onClick={() => setShowAll(!showAll)}>{showAll ? "Show Less" : "View All"}<ArrowRight size={17} /></button></div>{visible.length ? <div className="activities-feed">{visible.map(item => renderEntry(item))}</div> : <div className="activities-empty"><Activity size={39} /><h3>{tab === "events" ? "No event activities yet" : tab === "challenges" ? "No challenge activities yet" : "No activities in this view"}</h3><p>{search || selectedDay || status ? "Try another date or clear your filters." : tab === "events" || tab === "challenges" ? "Your activities will appear here when available." : "Start a course, complete a lesson, or book a mentorship session to begin your journey."}</p>{tab === "all" && !search && !selectedDay && <Link to="/learning-area">Explore Learning<ArrowRight size={16} /></Link>}</div>}</Panel>
        <div className="activities-secondary"><Panel className="activities-calendar"><div className="activities-section-heading"><h2><CalendarDays />Activity Calendar</h2></div><div className="activities-calendar-navigation"><button aria-label="Previous month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}><ChevronLeft size={21} /></button><h3 aria-live="polite">{monthLabel}</h3><button aria-label="Next month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}><ChevronRight size={21} /></button></div><div className="activities-calendar-grid" role="group" aria-label={`Activity dates in ${monthLabel}`}>{["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map(day => <span key={day} className="activities-weekday">{day}</span>)}{Array.from({ length: month.getDay() }, (_, index) => <span key={`blank-${index}`} />)}{Array.from({ length: daysInMonth }, (_, index) => { const day = index + 1; const key = `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`; const entries = activitiesByDay.get(key) || []; const states = [...new Set(entries.map(item => item.status))]; return <button key={key} aria-label={`${new Date(month.getFullYear(), month.getMonth(), day).toLocaleDateString(undefined, { dateStyle: "long" })}: ${entries.length} ${entries.length === 1 ? "activity" : "activities"}`} aria-pressed={selectedDay === key} aria-current={today === key ? "date" : undefined} className={`${selectedDay === key ? "selected" : ""} ${today === key ? "today" : ""}`} onClick={() => { setSelectedDay(selectedDay === key ? null : key); setShowAll(true); }}><span>{day}</span><span className="activities-day-markers">{states.map(state => <i key={state} className={state} />)}</span></button>; })}</div><div className="activities-calendar-legend"><span><i className="completed" />Completed</span><span><i className="in_progress" />In Progress</span><span><i className="upcoming" />Upcoming</span></div>{selectedDay && <button className="activities-calendar-clear" onClick={() => setSelectedDay(null)}>Show All Dates</button>}</Panel>
          <Panel className="activities-upcoming"><div className="activities-section-heading"><h2><CalendarDays />Upcoming Activities</h2><button className="activities-text-action" onClick={() => { setStatus("upcoming"); setShowAll(true); }}>View All<ArrowRight size={17} /></button></div>{upcoming.length ? upcoming.slice(0, 2).map(item => renderEntry(item, true)) : <div className="activities-upcoming-empty"><Clock size={27} /><p>{selectedDay ? "No upcoming activities on this date." : "No upcoming activities in this view."}</p><Link to="/services">Find a Mentor<ArrowRight size={15} /></Link></div>}</Panel></div>
      </div>
    </>}
  </MenteeWorkspace>;
}
