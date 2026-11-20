import { PageLoader } from '@/components/loaders/PageLoader';
import { useDeferredValue, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { useInfiniteQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Bell, BookOpen, CalendarDays, Check, CheckCheck, Filter, GraduationCap, Medal, Megaphone, Settings, Target, Trophy, Users } from "lucide-react";
import { MenteeWorkspace } from "@/components/layout/mentee-workspace";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth-context";
import { getNotificationsWorkspace, markAllNotificationsRead, setNotificationRead, updateNotificationPreferences, type NotificationPreferences, type NotificationTopic, type UserNotification } from "@/lib/notifications-api";
import { toast } from "sonner";
import "./notifications.css";

const categories = [{ id: "all", title: "All Notifications", short: "All", icon: Bell }, { id: "mentorship", title: "Mentorship", short: "Mentorship", icon: Users }, { id: "learning", title: "Learning", short: "Learning", icon: BookOpen }, { id: "events", title: "Events", short: "Events", icon: CalendarDays }, { id: "system", title: "System", short: "System", icon: Settings }] as const;
const settings: { id: NotificationTopic; label: string; icon: typeof Users }[] = [
  { id: "mentorship", label: "Mentorship updates", icon: Users },
  { id: "learning", label: "Learning & courses", icon: BookOpen },
  { id: "events", label: "Events & activities", icon: CalendarDays },
  { id: "goals", label: "Goals & achievements", icon: Trophy },
  { id: "platform", label: "Platform updates", icon: Megaphone },
];
const icons = { users: Users, graduation: GraduationCap, calendar: CalendarDays, target: Target, medal: Medal, book: BookOpen, megaphone: Megaphone, bell: Bell };
function relativeTime(value: string) {
  const date = new Date(value), now = new Date();
  const minutes = Math.max(0, Math.floor((now.getTime() - date.getTime()) / 60000));
  if (minutes < 1) return "Just now";
  if (minutes < 60) return `${minutes} ${minutes === 1 ? "min" : "mins"} ago`;
  if (minutes < 1440) { const hours = Math.floor(minutes / 60); return `${hours} ${hours === 1 ? "hour" : "hours"} ago`; }
  const options: Intl.DateTimeFormatOptions = { timeZone: "Africa/Kampala", year: "numeric", month: "short", day: "numeric" };
  if (date.toLocaleDateString("en", options) === new Date(now.getTime() - 86400000).toLocaleDateString("en", options)) return "Yesterday";
  return date.toLocaleDateString(undefined, options);
}
export default function NotificationsPage() {
  const { user, isLoading: authLoading } = useAuth();
  const navigate = useNavigate();
  const client = useQueryClient();
  const [search, setSearch] = useState("");
  const deferredSearch = useDeferredValue(search);
  const [category, setCategory] = useState("all");
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [preferencesOpen, setPreferencesOpen] = useState(false);
  const query = useInfiniteQuery({
    queryKey: ["notifications-workspace", user?.id, category, deferredSearch, unreadOnly],
    initialPageParam: 1,
    queryFn: ({ pageParam }) => getNotificationsWorkspace({ page: pageParam, category, q: deferredSearch, unread: unreadOnly }),
    getNextPageParam: last => last.meta.page < last.meta.total_pages ? last.meta.page + 1 : undefined,
    enabled: !!user?.access_token,
    refetchInterval: 60_000,
  });
  const refresh = async () => { await Promise.all([client.invalidateQueries({ queryKey: ["notifications-workspace", user?.id] }), client.invalidateQueries({ queryKey: ["notification-unread-count", user?.id] })]); };
  const readMutation = useMutation({ mutationFn: setNotificationRead, onSuccess: refresh, onError: () => toast.error("Could not update this notification. Please try again.") });
  const allReadMutation = useMutation({ mutationFn: markAllNotificationsRead, onSuccess: async () => { await refresh(); toast.success("All notifications marked as read"); }, onError: () => toast.error("Could not mark your notifications as read. Please try again.") });
  const preferenceMutation = useMutation({ mutationFn: updateNotificationPreferences, onSuccess: async () => { await refresh(); toast.success("Notification preferences saved"); }, onError: () => toast.error("Could not save your preferences. Please try again.") });
  if (authLoading) return <PageLoader label="Loading notifications…"/>;
  if (!user) return <Navigate to="/login" replace />;
  const data = query.data?.pages[0];
  const notifications = query.data?.pages.flatMap(page => page.notifications) || [];
  const counts = data?.counts;
  const preferences = data?.preferences;
  const openNotification = async (notification: UserNotification) => {
    try { if (!notification.read) await readMutation.mutateAsync({ id: notification.id, read: true }); navigate(notification.href); } catch { /* Mutation displays the error and retains the notification. */ }
  };
  function preferenceRows(values: NotificationPreferences) {
    return settings.map(({ id, label, icon: Icon }) => <label className="notification-setting" key={id}><Icon size={25} /><span>{label}</span><Switch aria-label={label} checked={values[id]} disabled={preferenceMutation.isPending} onCheckedChange={checked => preferenceMutation.mutate({ [id]: checked })} /></label>);
  }
  return <MenteeWorkspace title="Notifications" name={data?.name || user.full_name} avatar={data?.avatar} activePage="notifications" search={search} onSearch={setSearch} searchPlaceholder="Search for courses, mentors, events, or resources..." sidebarAction={() => setPreferencesOpen(true)}>
    <div className="notifications-page-heading"><div><h1><Bell size={34} fill="currentColor" />Notifications</h1><p>Stay informed about your learning, mentorship, events and activities.</p></div><button className="notifications-mark-all" disabled={!counts?.unread || allReadMutation.isPending} onClick={() => allReadMutation.mutate()}><Check size={21} />{allReadMutation.isPending ? "Marking as Read…" : "Mark All as Read"}</button></div>
    {query.isPending ? <div className="notifications-panel"><PageLoader label="Loading your notifications…"/></div> : query.isError ? <div className="notifications-panel"><h2>We couldn’t load your notifications</h2><p className="my-4">Please check your connection and try again.</p><Button onClick={() => query.refetch()}>Try Again</Button></div> : data && <div className="notifications-columns"><div className="notifications-primary"><Tabs value={category} onValueChange={setCategory}><TabsList className="notifications-tabs">{categories.map(({ id, title, icon: Icon }) => <TabsTrigger id={`notification-tab-${id}`} aria-controls="notification-feed" key={id} value={id}><Icon size={23} />{title} ({counts?.[id] || 0})</TabsTrigger>)}</TabsList></Tabs>
      {unreadOnly && <div className="notifications-unread-filter"><span>Unread notifications</span><button onClick={() => setUnreadOnly(false)}>Show All</button></div>}
      <section id="notification-feed" className="notification-feed" role="tabpanel" aria-labelledby={`notification-tab-${category}`} aria-busy={query.isFetching}><h2 className="sr-only">Your notifications</h2>{notifications.length ? notifications.map(notification => { const Icon = icons[notification.icon as keyof typeof icons] || Bell; return <article className={`notification-row ${notification.read ? "read" : "unread"} ${notification.icon}`} key={notification.id}><button className="notification-row-main" onClick={() => openNotification(notification)} disabled={readMutation.isPending}><span className={`notification-icon ${notification.icon}`}><Icon size={36} /></span><span className="notification-copy"><h3>{notification.title}</h3><p>{notification.message}</p></span><time dateTime={notification.created_at} title={new Date(notification.created_at).toLocaleString(undefined, { timeZone: "Africa/Kampala" })}>{relativeTime(notification.created_at)}</time></button><button className={`notification-read-toggle ${notification.read ? "is-read" : ""}`} aria-label={`Mark ${notification.title} as ${notification.read ? "unread" : "read"}`} title={notification.read ? "Mark as unread" : "Mark as read"} disabled={readMutation.isPending} onClick={() => readMutation.mutate({ id: notification.id, read: !notification.read })}>{notification.read ? <CheckCheck size={17} /> : <span />}</button></article>; }) : <div className="notifications-empty"><Bell size={42} /><h3>{search || category !== "all" || unreadOnly ? "No notifications match this view" : "You’re all caught up"}</h3><p>Your learning, mentorship, and event updates will appear here.</p>{(search || category !== "all" || unreadOnly) && <button onClick={() => { setCategory("all"); setSearch(""); setUnreadOnly(false); }}>Show All Notifications</button>}</div>}{query.hasNextPage && <button className="notifications-load-more" disabled={query.isFetchingNextPage} onClick={() => query.fetchNextPage()}>{query.isFetchingNextPage ? "Loading…" : "Load More Notifications"}</button>}</section>
    </div><aside className="notifications-secondary"><section className="notifications-panel notifications-filters"><div className="notifications-section-heading"><h2><Filter fill="currentColor" />Quick Filters</h2><button className="notification-unread-count" aria-pressed={unreadOnly} onClick={() => setUnreadOnly(!unreadOnly)}>Unread ({counts?.unread || 0})</button></div>{categories.map(({ id, short, icon: Icon }) => <button className={category === id ? "active" : ""} aria-pressed={category === id} key={id} onClick={() => setCategory(id)}><Icon size={25} />{short} ({counts?.[id] || 0})</button>)}</section><section className="notifications-panel notifications-settings"><div className="notifications-section-heading"><h2><Settings fill="currentColor" />Notification Settings</h2></div><p>Choose what you want to be notified about.</p><div className="notification-setting-list">{preferences && preferenceRows(preferences)}</div><button className="notifications-manage" onClick={() => setPreferencesOpen(true)}><Settings size={23} fill="currentColor" />Manage Preferences</button></section></aside></div>}
    <Dialog open={preferencesOpen} onOpenChange={setPreferencesOpen}><DialogContent><DialogHeader><DialogTitle>Notification Preferences</DialogTitle><DialogDescription>Choose future in-app alerts. Changes save immediately.</DialogDescription></DialogHeader>{preferences ? <div className="notification-preferences-dialog">{preferenceRows(preferences)}</div> : <p role="status">Load your notifications to manage preferences.</p>}</DialogContent></Dialog>
  </MenteeWorkspace>;
}
