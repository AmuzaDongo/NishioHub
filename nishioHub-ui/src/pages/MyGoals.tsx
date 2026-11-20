import { PageLoader } from '@/components/loaders/PageLoader';
import { useState, type ReactNode } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowRight, BookOpen, CalendarDays, ChartNoAxesColumnIncreasing, Check, CheckCircle2, Circle, CircleDashed, Clock, Code2, Flag, GraduationCap, History, Laptop, MoreHorizontal, Pencil, Plus, Target, Trash2, Trophy, Users, Zap } from "lucide-react";
import { MenteeWorkspace } from "@/components/layout/mentee-workspace";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from "@/components/ui/alert-dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth-context";
import { useMessaging } from "@/lib/messaging-context";
import { hasRole, roleName } from "@/lib/utils";
import { getMenteeDashboard } from "@/lib/mentee-dashboard-api";
import { addGoalMilestone, deleteGoal, deleteGoalMilestone, getMyGoals, saveGoal, saveVision, updateGoalMilestone, type GoalDraft, type PersonalGoal } from "@/lib/goals-api";
import { toast } from "sonner";
import "./my-goals.css";

const goalIcons = { target: Target, code: Code2, laptop: Laptop, graduation: GraduationCap, trophy: Trophy };
const emptyDraft: GoalDraft = { title: "", description: "", target_date: null, progress: 0, icon: "target" };
type GoalFilter = "all" | "completed" | "in-progress" | "not-started";
function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`goals-panel ${className}`}>{children}</section>;
}
function dateLabel(value: string | null) {
  return value ? new Date(`${value}T12:00:00`).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "No target date";
}
function errorToast(error: unknown) {
  const detail = (error as { response?: { data?: { detail?: string | string[] } } })?.response?.data?.detail;
  toast.error(Array.isArray(detail) ? detail.join(", ") : detail || "Could not save your changes. Please try again.");
}

export default function MyGoalsPage() {
  const { user, isLoading: authLoading } = useAuth();
  const { getOrCreateConversation } = useMessaging();
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState("goals");
  const [filter, setFilter] = useState<GoalFilter>("all");
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | undefined>();
  const [draft, setDraft] = useState<GoalDraft>(emptyDraft);
  const [progressOpen, setProgressOpen] = useState(false);
  const [progressGoalId, setProgressGoalId] = useState("");
  const [progress, setProgress] = useState(0);
  const [milestoneOpen, setMilestoneOpen] = useState(false);
  const [milestoneGoalId, setMilestoneGoalId] = useState("");
  const [milestoneTitle, setMilestoneTitle] = useState("");
  const [milestoneDate, setMilestoneDate] = useState("");
  const [visionOpen, setVisionOpen] = useState(false);
  const [vision, setVision] = useState("");
  const [deleting, setDeleting] = useState<PersonalGoal | null>(null);
  const client = useQueryClient();
  const queryKey = ["my-goals", user?.id];
  const enabled = !!user && hasRole(user, "mentee");
  const query = useQuery({ queryKey, queryFn: getMyGoals, enabled });
  const dashboard = useQuery({ queryKey: ["mentee-dashboard", user?.id], queryFn: getMenteeDashboard, enabled });
  const refresh = async () => { await Promise.all([client.invalidateQueries({ queryKey }), client.invalidateQueries({ queryKey: ["mentee-dashboard", user?.id] })]); };
  const goalMutation = useMutation({ mutationFn: saveGoal, onSuccess: async () => { await refresh(); setEditorOpen(false); setProgressOpen(false); toast.success("Goal saved"); }, onError: errorToast });
  const removeMutation = useMutation({ mutationFn: deleteGoal, onSuccess: async () => { await refresh(); setDeleting(null); toast.success("Goal removed"); }, onError: errorToast });
  const milestoneMutation = useMutation({ mutationFn: addGoalMilestone, onSuccess: async () => { await refresh(); setMilestoneOpen(false); toast.success("Milestone added"); }, onError: errorToast });
  const milestoneUpdate = useMutation({ mutationFn: updateGoalMilestone, onSuccess: refresh, onError: errorToast });
  const milestoneDelete = useMutation({ mutationFn: deleteGoalMilestone, onSuccess: refresh, onError: errorToast });
  const visionMutation = useMutation({ mutationFn: saveVision, onSuccess: async () => { await refresh(); setVisionOpen(false); toast.success("Vision saved"); }, onError: errorToast });
  if (authLoading) return <PageLoader label="Loading your goals…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!hasRole(user, "mentee")) return <Navigate to="/mentor/mentorship" replace />;
  const data = query.data;
  const goals = data?.goals || [];
  const textMatches = (value: string) => value.toLowerCase().includes(search.trim().toLowerCase());
  const visibleGoals = goals.filter(goal => textMatches(`${goal.title} ${goal.description || ""}`) && (filter === "all" || (filter === "completed" ? goal.progress === 100 : filter === "in-progress" ? goal.progress > 0 && goal.progress < 100 : goal.progress === 0)));
  const milestones = goals.flatMap(goal => goal.milestones.map(milestone => ({ ...milestone, goalTitle: goal.title }))).sort((a, b) => (a.target_date || "9999").localeCompare(b.target_date || "9999") || a.id - b.id);
  const visibleMilestones = milestones.filter(item => textMatches(`${item.title} ${item.goalTitle}`));
  const history = data?.history.filter(event => textMatches(`${event.goal_title} ${event.note}`)) || [];
  const newGoal = () => { setEditingId(undefined); setDraft({ ...emptyDraft }); setEditorOpen(true); };
  const editGoal = (goal: PersonalGoal) => { setEditingId(goal.id); setDraft({ title: goal.title, description: goal.description || "", progress: goal.progress, target_date: goal.target_date, icon: goal.icon }); setEditorOpen(true); };
  const updateProgress = (goal?: PersonalGoal) => { const selected = goal || goals.find(item => item.progress < 100) || goals[0]; if (!selected) { newGoal(); return; } setProgressGoalId(String(selected.id)); setProgress(selected.progress); setProgressOpen(true); };
  const addMilestone = (goal?: PersonalGoal) => { if (!goals.length) { newGoal(); return; } setMilestoneGoalId(String(goal?.id || goals[0].id)); setMilestoneTitle(""); setMilestoneDate(""); setMilestoneOpen(true); };
  const talkToMentor = async () => { const mentor = dashboard.data?.mentor; if (mentor) { const id = await getOrCreateConversation(String(mentor.id)); if (id) navigate(`/messages/${id}`); } else navigate("/services"); };
  const stats = [
    { label: "Total Goals", value: goals.length, icon: Target, color: "purple", filter: "all" as GoalFilter },
    { label: "Completed", value: goals.filter(goal => goal.progress === 100).length, icon: Check, color: "green", filter: "completed" as GoalFilter },
    { label: "In Progress", value: goals.filter(goal => goal.progress > 0 && goal.progress < 100).length, icon: CircleDashed, color: "blue", filter: "in-progress" as GoalFilter },
    { label: "Not Started", value: goals.filter(goal => goal.progress === 0).length, icon: Clock, color: "orange", filter: "not-started" as GoalFilter },
  ];
  function renderMilestone(item: typeof milestones[number], compact = false) {
    return <li key={item.id} className={compact ? "goals-milestone-compact" : "goals-milestone-row"}><button className="goals-milestone-check" aria-label={`${item.completed ? "Reopen" : "Complete"} milestone: ${item.title}`} aria-pressed={item.completed} disabled={milestoneUpdate.isPending} onClick={() => milestoneUpdate.mutate({ goalId: item.mentee_goal_id, id: item.id, completed: !item.completed })}>{item.completed ? <CheckCircle2 size={22} className="is-complete" /> : <Circle size={22} />}</button><div><span>{item.title}</span>{!compact && <p>{item.goalTitle} · {dateLabel(item.target_date)}</p>}</div>{!compact && <Button variant="ghost" size="icon" aria-label={`Remove milestone: ${item.title}`} disabled={milestoneDelete.isPending} onClick={() => milestoneDelete.mutate({ goalId: item.mentee_goal_id, id: item.id })}><Trash2 size={16} /></Button>}</li>;
  }
  return <MenteeWorkspace title="My Goals" name={data?.name || user.full_name} avatar={data?.avatar} activePage="goals" search={search} onSearch={setSearch} sidebarAction={newGoal}>
    <div className="goals-page-heading"><div><h1>My Goals</h1><p>Set, track and achieve your learning and career goals.</p></div><button className="goals-create-button" onClick={newGoal} disabled={!data}><Plus size={22} />Create New Goal</button></div>
    {query.isPending ? <Panel><PageLoader label="Loading your goals…"/></Panel> : query.isError ? <Panel><h2>We couldn’t load your goals</h2><p className="my-4">Please check your connection and try again.</p><Button onClick={() => query.refetch()}>Try Again</Button></Panel> : data && <>
      <div className="goals-stats">{stats.map(stat => <button key={stat.label} className={`goals-stat ${stat.color}`} onClick={() => { setFilter(stat.filter); setTab("goals"); }} aria-pressed={filter === stat.filter && tab === "goals"}><span className="goals-stat-icon"><stat.icon size={40} /></span><span><strong>{stat.value}</strong><small>{stat.label}</small></span></button>)}</div>
      <div className="goals-columns"><Tabs value={tab} onValueChange={setTab} className="goals-primary"><TabsList className="goals-tabs"><TabsTrigger value="goals">My Goals</TabsTrigger><TabsTrigger value="milestones"><CalendarDays size={22} />Milestones</TabsTrigger><TabsTrigger value="history"><ChartNoAxesColumnIncreasing size={22} />Progress History</TabsTrigger></TabsList>
        <TabsContent value="goals" className="goals-tab-content"><Panel className="goals-list">{filter !== "all" && <div className="goals-filter"><span>{stats.find(stat => stat.filter === filter)?.label}</span><button onClick={() => setFilter("all")}>Show All Goals</button></div>}{visibleGoals.length ? visibleGoals.map(goal => { const Icon = goalIcons[goal.icon as keyof typeof goalIcons] || Target; const status = goal.progress === 100 ? "completed" : goal.progress > 0 ? "in-progress" : "not-started"; return <article key={goal.id} className={`goals-row ${status}`}><div className={`goals-row-icon ${goal.icon}`}><Icon size={40} /></div><div className="goals-row-copy"><h2>{goal.title}</h2>{goal.description && <p>{goal.description}</p>}<span className="goals-target"><CalendarDays size={16} />Target: {dateLabel(goal.target_date)}</span></div><div className="goals-row-progress"><span className={`goals-status ${status}`}>{goal.progress === 100 ? "Completed" : goal.progress > 0 ? "In Progress" : "Not Started"}</span><button className="goals-progress-edit" aria-label={`Update progress for ${goal.title}`} onClick={() => updateProgress(goal)}><strong>{goal.progress}%</strong><span role="progressbar" aria-label={`${goal.title} progress`} aria-valuemin={0} aria-valuemax={100} aria-valuenow={goal.progress} className="goals-progress-track"><span style={{ width: `${goal.progress}%` }} /></span></button></div><DropdownMenu><DropdownMenuTrigger asChild><button aria-label={`Actions for ${goal.title}`} className="goals-more"><MoreHorizontal size={23} /></button></DropdownMenuTrigger><DropdownMenuContent align="end"><DropdownMenuItem onClick={() => updateProgress(goal)}><ChartNoAxesColumnIncreasing size={16} className="mr-2" />Update Progress</DropdownMenuItem><DropdownMenuItem onClick={() => editGoal(goal)}><Pencil size={16} className="mr-2" />Edit Goal</DropdownMenuItem><DropdownMenuItem onClick={() => addMilestone(goal)}><Flag size={16} className="mr-2" />Add Milestone</DropdownMenuItem><DropdownMenuItem onClick={() => setDeleting(goal)} className="text-red-600"><Trash2 size={16} className="mr-2" />Delete Goal</DropdownMenuItem></DropdownMenuContent></DropdownMenu></article>; }) : <div className="goals-empty"><Target size={42} /><h2>{search || filter !== "all" ? "No goals match this view" : "Your future starts with a goal"}</h2><p>{search || filter !== "all" ? "Try another search or show all your goals." : "Create your first learning or career goal, then take it one step at a time."}</p>{!search && filter === "all" && <Button onClick={newGoal}><Plus size={17} className="mr-2" />Create a Goal</Button>}</div>}</Panel></TabsContent>
        <TabsContent value="milestones" className="goals-tab-content"><Panel><div className="goals-section-heading"><h2><Flag />My Milestones</h2><button className="goals-text-action" onClick={() => addMilestone()}><Plus size={16} />Add Milestone</button></div><p className="goals-helper">Break your goals into smaller steps. Milestones and goal percentages can be updated separately.</p>{visibleMilestones.length ? <ul className="goals-milestones-full">{visibleMilestones.map(item => renderMilestone(item))}</ul> : <div className="goals-empty"><Flag size={35} /><p>{search ? "No milestones match your search." : "Add a milestone to plan the next step toward a goal."}</p></div>}</Panel></TabsContent>
        <TabsContent value="history" className="goals-tab-content"><Panel><div className="goals-section-heading"><h2><History />Progress History</h2></div>{history.length ? <ol className="goals-history">{history.map(event => <li key={event.id}><span className="goals-history-dot"><ChartNoAxesColumnIncreasing size={19} /></span><div><h3>{event.goal_title}</h3><p>{event.note} · {event.progress}%</p><time dateTime={event.created_at}>{new Date(event.created_at).toLocaleString()}</time></div><strong>{event.progress}%</strong></li>)}</ol> : <div className="goals-empty"><History size={36} /><p>{search ? "No history matches your search." : "Your goal creation and progress updates will appear here."}</p></div>}</Panel></TabsContent>
      </Tabs><div className="goals-secondary"><Panel className="goals-vision"><div className="goals-vision-art"><img src="/images/learning-hero.png" alt="A student learning with a laptop" /></div><div className="goals-vision-copy"><h2>My Vision Goal</h2><blockquote>{data.vision || "What future do you dream of creating? Write your vision and let it guide your goals."}</blockquote><button aria-label="Edit your vision goal" onClick={() => { setVision(data.vision || ""); setVisionOpen(true); }}><Pencil size={14} />{data.vision ? "Edit Vision" : "Set Your Vision"}</button></div></Panel>
        <Panel className="goals-next-milestones"><div className="goals-section-heading"><h2><Flag />My Next Milestones</h2><button className="goals-text-action" onClick={() => setTab("milestones")}>View All<ArrowRight size={16} /></button></div>{milestones.length ? <ul>{milestones.filter(item => !item.completed).concat(milestones.filter(item => item.completed)).slice(0, 4).map(item => renderMilestone(item, true))}</ul> : <div className="goals-small-empty"><p>Small steps make big dreams possible.</p><button className="goals-text-action" onClick={() => addMilestone()}>Add Your First Milestone<ArrowRight size={15} /></button></div>}</Panel>
        <Panel className="goals-quick"><div className="goals-section-heading"><h2><Zap />Quick Actions</h2></div><div className="goals-quick-grid"><button onClick={() => updateProgress()}><ChartNoAxesColumnIncreasing />Update Progress</button><button onClick={() => addMilestone()}><Flag />Add Milestone</button><button onClick={talkToMentor} disabled={dashboard.isPending}><Users />Talk to My Mentor</button><Link to="/learning-area"><BookOpen />Find Resources</Link></div></Panel>
      </div></div>
    </>}
    <Dialog open={editorOpen} onOpenChange={setEditorOpen}><DialogContent className="goals-form-dialog"><DialogHeader><DialogTitle>{editingId ? "Edit Goal" : "Create New Goal"}</DialogTitle><DialogDescription>Choose something meaningful and a practical next step.</DialogDescription></DialogHeader><form className="goals-form" onSubmit={event => { event.preventDefault(); goalMutation.mutate({ id: editingId, goal: { ...draft, title: draft.title.trim() } }); }}><div><Label htmlFor="goal-title">Goal title</Label><Input id="goal-title" value={draft.title} maxLength={200} required onChange={event => setDraft({ ...draft, title: event.target.value })} /></div><div><Label htmlFor="goal-description">Description</Label><Textarea id="goal-description" maxLength={2000} value={draft.description} onChange={event => setDraft({ ...draft, description: event.target.value })} /></div><div className="goals-form-columns"><div><Label htmlFor="goal-target">Target date</Label><Input id="goal-target" type="date" value={draft.target_date || ""} onChange={event => setDraft({ ...draft, target_date: event.target.value || null })} /></div><div><Label htmlFor="goal-icon">Goal icon</Label><select id="goal-icon" value={draft.icon} onChange={event => setDraft({ ...draft, icon: event.target.value })}><option value="target">Target</option><option value="code">Computer Skills</option><option value="laptop">Programming</option><option value="graduation">Career / Education</option><option value="trophy">Achievement</option></select></div></div><div><Label htmlFor="goal-initial-progress">Progress (%)</Label><Input id="goal-initial-progress" type="number" min={0} max={100} step={1} required value={draft.progress} onChange={event => setDraft({ ...draft, progress: Number(event.target.value) })} /></div><Button type="submit" disabled={goalMutation.isPending || !draft.title.trim()}>{goalMutation.isPending ? "Saving…" : "Save Goal"}</Button></form></DialogContent></Dialog>
    <Dialog open={progressOpen} onOpenChange={setProgressOpen}><DialogContent><DialogHeader><DialogTitle>Update Progress</DialogTitle><DialogDescription>Record how far you have come. Every step counts.</DialogDescription></DialogHeader><form className="goals-form" onSubmit={event => { event.preventDefault(); goalMutation.mutate({ id: Number(progressGoalId), goal: { progress } }); }}><div><Label htmlFor="progress-goal">Goal</Label><select id="progress-goal" value={progressGoalId} onChange={event => { setProgressGoalId(event.target.value); setProgress(goals.find(goal => String(goal.id) === event.target.value)?.progress || 0); }}>{goals.map(goal => <option key={goal.id} value={goal.id}>{goal.title}</option>)}</select></div><div><Label htmlFor="goal-progress-range">Progress: {progress}%</Label><input id="goal-progress-range" type="range" min={0} max={100} step={1} value={progress} onChange={event => setProgress(Number(event.target.value))} /></div><div><Label htmlFor="goal-progress-number">Percentage</Label><Input id="goal-progress-number" type="number" min={0} max={100} step={1} value={progress} required onChange={event => setProgress(Number(event.target.value))} /></div><Button type="submit" disabled={goalMutation.isPending}>{goalMutation.isPending ? "Saving…" : "Save Progress"}</Button></form></DialogContent></Dialog>
    <Dialog open={milestoneOpen} onOpenChange={setMilestoneOpen}><DialogContent><DialogHeader><DialogTitle>Add Milestone</DialogTitle><DialogDescription>A small, clear step toward your larger goal.</DialogDescription></DialogHeader><form className="goals-form" onSubmit={event => { event.preventDefault(); milestoneMutation.mutate({ goalId: Number(milestoneGoalId), title: milestoneTitle.trim(), target_date: milestoneDate || null }); }}><div><Label htmlFor="milestone-goal">Goal</Label><select id="milestone-goal" value={milestoneGoalId} onChange={event => setMilestoneGoalId(event.target.value)}>{goals.map(goal => <option key={goal.id} value={goal.id}>{goal.title}</option>)}</select></div><div><Label htmlFor="milestone-title">Milestone</Label><Input id="milestone-title" required maxLength={200} value={milestoneTitle} onChange={event => setMilestoneTitle(event.target.value)} /></div><div><Label htmlFor="milestone-date">Target date (optional)</Label><Input id="milestone-date" type="date" value={milestoneDate} onChange={event => setMilestoneDate(event.target.value)} /></div><Button type="submit" disabled={milestoneMutation.isPending || !milestoneTitle.trim()}>{milestoneMutation.isPending ? "Saving…" : "Add Milestone"}</Button></form></DialogContent></Dialog>
    <Dialog open={visionOpen} onOpenChange={setVisionOpen}><DialogContent><DialogHeader><DialogTitle>My Vision Goal</DialogTitle><DialogDescription>Describe the future you want to build.</DialogDescription></DialogHeader><form className="goals-form" onSubmit={event => { event.preventDefault(); visionMutation.mutate(vision.trim()); }}><Label htmlFor="goal-vision">Your vision</Label><Textarea id="goal-vision" maxLength={1000} value={vision} onChange={event => setVision(event.target.value)} rows={5} /><Button type="submit" disabled={visionMutation.isPending}>{visionMutation.isPending ? "Saving…" : "Save Vision"}</Button></form></DialogContent></Dialog>
    <AlertDialog open={!!deleting} onOpenChange={open => { if (!open) setDeleting(null); }}><AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Delete this goal?</AlertDialogTitle><AlertDialogDescription>“{deleting?.title}” and its milestones and progress history will be removed.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Keep Goal</AlertDialogCancel><AlertDialogAction disabled={removeMutation.isPending} onClick={event => { event.preventDefault(); if (deleting) removeMutation.mutate(deleting.id); }}>{removeMutation.isPending ? "Deleting…" : "Delete Goal"}</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog>
  </MenteeWorkspace>;
}
