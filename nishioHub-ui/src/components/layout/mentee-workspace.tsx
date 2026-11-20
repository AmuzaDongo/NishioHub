import { useState, type ReactNode } from "react";
import { Link } from "react-router-dom";
import { ArrowRight, Bell, BookOpen, CalendarDays, ChevronDown, ChevronRight, GraduationCap, Home, Menu, MessageSquare, Search, Settings, Target, Trophy, UserRound, Users, X } from "lucide-react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { useAuth } from "@/lib/auth-context";
import { useUnreadNotifications } from "@/hooks/use-unread-notifications";
import { roleName, hasRole, isPlatformAdmin } from "@/lib/utils";
import { usePlatform, assetUrl } from "@/lib/platform-context";
import { useMessaging } from "@/lib/messaging-context";
import "@/pages/learning-area.css";

interface MenteeWorkspaceProps {
  children: ReactNode;
  title: string;
  name: string;
  avatar?: string | null;
  activePage: "goals" | "learning" | "activities" | "achievements" | "events" | "notifications" | "messages" | "settings";
  searchPlaceholder?: string;
  search: string;
  onSearch: (value: string) => void;
  sidebarAction: () => void;
}
export function MenteeWorkspace({ children, title, name, avatar, activePage, search, onSearch, sidebarAction, searchPlaceholder = "Search for courses, goals, mentors, or resources..." }: MenteeWorkspaceProps) {
  const { user, logout } = useAuth();
  const platform = usePlatform();
  const unreadCount = useUnreadNotifications();
  const { unreadCount: unreadMessages } = useMessaging();
  const sharedPage = activePage === 'notifications' || activePage === 'messages' || activePage === 'settings';
  const adminWorkspace = sharedPage && isPlatformAdmin(user);
  const mentorNotifications = sharedPage && !adminWorkspace && hasRole(user, 'mentor');
  const generalWorkspace = sharedPage && !adminWorkspace && !mentorNotifications && !hasRole(user, 'mentee');
  const roleLabel = (roleName(user) || 'Member').replace(/_/g, ' ').replace(/\b\w/g, s => s.toUpperCase());
  const [menuOpen, setMenuOpen] = useState(false);
  const base = (import.meta.env.VITE_API_BASE_URL || "https://api.nishiohub.com/api/v1").replace(/\/api\/v1\/?$/, "");
  const avatarUrl = avatar && !/^(https?:|blob:|data:)/.test(avatar) ? new URL(avatar.replace(/^\//, ""), `${base}/`).href : avatar;
  const nav = adminWorkspace || generalWorkspace ? [
    { label:'Overview',icon:Home,to:adminWorkspace?'/admin':'/dashboard' },
    { label:'My Profile',icon:UserRound,to:'/profile' },
    { label:'Messages',icon:MessageSquare,to:'/messages',page:'messages' },
    { label:'Notifications',icon:Bell,to:'/notifications',page:'notifications' },
    { label:'Settings',icon:Settings,to:'/settings',page:'settings' },
  ] : mentorNotifications ? [
    { label: "Overview", icon: Home, to: "/dashboard" },
    { label: "My Profile", icon: UserRound, to: "/mentor/profile" },
    { label: "My Mentorship", icon: Users, to: "/mentor/mentorship" },
    { label: "My Sessions", icon: CalendarDays, to: "/bookings" },
    { label: "Messages", icon: MessageSquare, to: "/messages", page: "messages" },
    { label: "Notifications", icon: Bell, to: "/notifications", page: "notifications" },
    { label: "Settings", icon: Settings, to: "/settings", page: "settings" },
  ] : [
    { label: "Overview", icon: Home, to: "/mentee/dashboard" },
    { label: "My Profile", icon: UserRound, to: "/profile" },
    { label: "My Mentorship", icon: Users, to: "/mentee/dashboard#mentorship" },
    { label: "Find a Mentor", icon: Users, to: "/services" },
    { label: "Learning Area", icon: BookOpen, to: "/learning-area", page: "learning" },
    { label: "My Goals", icon: Target, to: "/my-goals", page: "goals" },
    { label: "My Activities", icon: CalendarDays, to: "/my-activities", page: "activities" },
    { label: "Achievements", icon: Trophy, to: "/my-achievements", page: "achievements" },
    { label: "Events", icon: CalendarDays, to: "/events", page: "events" },
    { label: "Messages", icon: MessageSquare, to: "/messages", page: "messages" },
    { label: "Notifications", icon: Bell, to: "/notifications", page: "notifications" },
    { label: "Settings", icon: Settings, to: "/settings", page: "settings" },
  ];
  const searchInput = (mobile = false) => <div className={mobile ? "learning-mobile-search" : "learning-search"}><Search size={mobile ? 18 : 22} /><input aria-label={mobile ? `Search ${title} on mobile` : `Search ${title}`} placeholder={searchPlaceholder} value={search} onChange={event => onSearch(event.target.value)} />{search && <button aria-label="Clear search" onClick={() => onSearch("")}><X size={17} /></button>}</div>;
  return <div className={`learning-shell ${activePage === "settings" ? "settings-workspace" : activePage === "messages" ? "messages-workspace" : activePage === "notifications" ? "notifications-workspace" : activePage === "events" ? "events-workspace" : activePage === "achievements" ? "achievements-workspace" : activePage === "activities" ? "activities-workspace" : "goals-workspace"}`}>
    <header className="learning-header"><Link to="/" aria-label="NishioHub home"><img src={assetUrl(platform.logo_url) || "/assets/learning-logo.svg"} alt={`${platform.platform_name} — ${platform.tagline}`} className="learning-logo" /></Link>{searchInput()}<div className="learning-header-account"><Link to="/notifications" className="workspace-notification-bell" aria-label={`Notifications${unreadCount ? `, ${unreadCount} unread` : ""}`}><Bell size={26} />{unreadCount > 0 && <span>{unreadCount > 99 ? "99+" : unreadCount}</span>}</Link><DropdownMenu><DropdownMenuTrigger asChild><button className="learning-account"><Avatar><AvatarImage src={avatarUrl || undefined} alt={name} /><AvatarFallback>{name.split(" ").map(part => part[0]).slice(0, 2).join("")}</AvatarFallback></Avatar><span><strong>{name}</strong><small>{roleLabel}</small></span><ChevronDown size={20} /></button></DropdownMenuTrigger><DropdownMenuContent align="end"><DropdownMenuItem asChild><Link to="/profile">My Profile</Link></DropdownMenuItem><DropdownMenuItem asChild><Link to="/settings">Settings</Link></DropdownMenuItem><DropdownMenuItem onClick={logout}>Sign Out</DropdownMenuItem></DropdownMenuContent></DropdownMenu><button className="learning-menu-toggle" aria-label={menuOpen ? "Close navigation" : "Open navigation"} aria-expanded={menuOpen} onClick={() => setMenuOpen(!menuOpen)}>{menuOpen ? <X /> : <Menu />}</button></div></header>
    <aside className={`learning-sidebar ${menuOpen ? "is-open" : ""}`}><nav aria-label={`${roleLabel} navigation`}>{nav.map(({ label, icon: Icon, to, page }) => <Link key={label} to={to} className={page === activePage ? "active" : ""} aria-current={page === activePage ? "page" : undefined} onClick={() => setMenuOpen(false)}><Icon size={24} />{label}{label === "Messages" && unreadMessages > 0 && <span className="workspace-message-unread">{unreadMessages > 99 ? "99+" : unreadMessages}</span>}</Link>)}</nav><div className="learning-invite">{activePage === "settings" ? <Settings size={57} /> : activePage === "messages" ? <MessageSquare size={57} /> : activePage === "notifications" ? <Bell size={57} /> : activePage === "events" ? <CalendarDays size={57} /> : activePage === "achievements" ? <Trophy size={57} /> : <GraduationCap size={57} />}<h3>{activePage === "settings" ? <>Customize<br />Your Experience</> : activePage === "messages" ? <>Stay Connected</> : activePage === "notifications" ? <>Stay Updated</> : activePage === "events" ? <>Join Events</> : activePage === "achievements" ? <>Celebrate<br />Your Progress</> : activePage === "activities" ? <>Be Active,<br />Learn More</> : <>Set Goals<br />Grow Your Future</>}</h3><p>{activePage === "settings" ? <>Manage your profile,<br />account, notifications<br />and more.</> : activePage === "messages" ? <>Chat with your mentor,<br />get support and grow<br />your skills.</> : activePage === "notifications" ? <>Get alerts about your<br />learning, mentorship,<br />events and goals.</> : activePage === "events" ? <>Workshops, talks,<br />challenges and<br />mentorship sessions<br />to grow your skills.</> : activePage === "achievements" ? <>View your badges,<br />certificates and<br />learning milestones.</> : activePage === "activities" ? <>Join activities, attend<br />sessions and engage<br />with your mentor.</> : <>Plan, learn, track and<br />achieve your dreams<br />with your mentor’s support.</>}</p><button onClick={() => { setMenuOpen(false); sidebarAction(); }}>{activePage === "settings" ? "Explore Settings" : activePage === "messages" ? "Start a Conversation" : activePage === "notifications" ? "Manage Alerts" : activePage === "events" ? "Explore Events" : activePage === "achievements" ? "Explore More" : activePage === "activities" ? "Explore Activities" : "Create a Goal"}<ArrowRight size={18} /></button></div></aside>
    <main className="learning-main"><div className="learning-breadcrumb"><Link to="/mentee/dashboard" aria-label="Overview"><Home size={19} /></Link><ChevronRight size={15} /><span>{title}</span></div>{searchInput(true)}{children}</main>
  </div>;
}
