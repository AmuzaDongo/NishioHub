import { PageLoader } from '@/components/loaders/PageLoader';
import { useState, type ReactNode } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { ArrowRight, Award, BookOpen, CalendarDays, ChartNoAxesColumnIncreasing, Check, CheckCircle2, Circle, Code2, Crown, Download, FileBadge, GraduationCap, Laptop, LockKeyhole, Medal, Rocket, Share2, Star, Target, TrendingUp, Trophy, Users } from "lucide-react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Label } from "@/components/ui/label";
import { MenteeWorkspace } from "@/components/layout/mentee-workspace";
import { useAuth } from "@/lib/auth-context";
import { hasRole, roleName } from "@/lib/utils";
import { downloadAchievementRecord, downloadLearningCertificate, getMyAchievements, saveDownload, type AchievementBadge, type AchievementEntry, type LearningCertificate } from "@/lib/achievements-api";
import { toast } from "sonner";
import "./my-achievements.css";

const icons = { code: Code2, graduation: GraduationCap, target: Target, laptop: Laptop, star: Star, book: BookOpen, users: Users, rocket: Rocket, trophy: Trophy, certificate: FileBadge };
const tabs = [{ id: "overview", title: "Overview", icon: Trophy }, { id: "badges", title: "Badges", icon: Medal }, { id: "certificates", title: "Certificates", icon: FileBadge }, { id: "milestones", title: "Milestones", icon: Target }, { id: "leaderboard", title: "Leaderboard", icon: ChartNoAxesColumnIncreasing }];
function dateLabel(value: string) { return new Date(value).toLocaleDateString(undefined, { timeZone: "Africa/Kampala", month: "short", day: "numeric", year: "numeric" }); }
function Panel({ children, className = "" }: { children: ReactNode; className?: string }) { return <section className={`achievements-panel ${className}`}>{children}</section>; }
function Heading({ children, action }: { children: ReactNode; action?: ReactNode }) { return <div className="achievements-section-heading"><h2>{children}</h2>{action}</div>; }
export default function MyAchievementsPage() {
  const { user, isLoading: authLoading } = useAuth();
  const navigate = useNavigate();
  const [search, setSearch] = useState("");
  const [tab, setTab] = useState("overview");
  const [showAll, setShowAll] = useState(false);
  const [selectedBadge, setSelectedBadge] = useState<AchievementBadge | null>(null);
  const [selectedCertificate, setSelectedCertificate] = useState<LearningCertificate | null>(null);
  const [shareOpen, setShareOpen] = useState(false);
  const [shareId, setShareId] = useState("");
  const [sharing, setSharing] = useState(false);
  const [downloadKey, setDownloadKey] = useState<string | null>(null);
  const query = useQuery({ queryKey: ["my-achievements", user?.id], queryFn: getMyAchievements, enabled: !!user && hasRole(user, "mentee") });
  if (authLoading) return <PageLoader label="Loading your achievements…"/>;
  if (!user) return <Navigate to="/login" replace />;
  if (!hasRole(user, "mentee")) return <Navigate to="/dashboard" replace />;
  const data = query.data;
  const name = data?.name || user.full_name;
  const base = (import.meta.env.VITE_API_BASE_URL || "https://api.nishiohub.com/api/v1").replace(/\/api\/v1\/?$/, "");
  const avatar = data?.avatar && !/^(https?:|blob:|data:)/.test(data.avatar) ? new URL(data.avatar.replace(/^\//, ""), `${base}/`).href : data?.avatar;
  const matches = (value: string) => value.toLowerCase().includes(search.trim().toLowerCase());
  const entries = data?.achievements.filter(entry => matches(`${entry.title} ${entry.description}`)) || [];
  const badges = data?.badges.filter(badge => matches(`${badge.name} ${badge.description}`)) || [];
  const certificates = data?.certificates.filter(certificate => matches(certificate.title)) || [];
  const milestones = data?.milestones.filter(milestone => matches(`${milestone.title} ${milestone.goal_title}`)) || [];
  const downloadRecord = async () => {
    setDownloadKey("record");
    try { saveDownload(await downloadAchievementRecord(), "nishiohub-achievement-record.csv"); toast.success("Achievement record downloaded"); }
    catch { toast.error("Could not download your record. Please try again."); }
    finally { setDownloadKey(null); }
  };
  const downloadCertificate = async (certificate: LearningCertificate) => {
    setDownloadKey(certificate.id);
    try { saveDownload(await downloadLearningCertificate(certificate.id), `nishiohub-certificate-${certificate.id}.svg`); toast.success("Certificate downloaded"); }
    catch { toast.error("Could not download your certificate. Please try again."); }
    finally { setDownloadKey(null); }
  };
  const share = async () => {
    const entry = data?.achievements.find(item => item.id === shareId);
    if (!entry) return;
    setSharing(true);
    const text = `${name} — ${entry.title}\n${entry.description}\n${dateLabel(entry.occurred_at)} · NishioHub`;
    try {
      if (navigator.share) await navigator.share({ title: "My NishioHub Achievement", text });
      else { await navigator.clipboard.writeText(text); toast.success("Achievement text copied. You can share it wherever you choose."); }
      setShareOpen(false);
    } catch (error) { if ((error as { name?: string }).name !== "AbortError") toast.error("Sharing wasn’t available. Please try again."); }
    finally { setSharing(false); }
  };
  function badgeCard(badge: AchievementBadge) {
    const Icon = icons[badge.icon as keyof typeof icons] || Medal;
    return <button className={`achievement-badge ${badge.color} ${badge.earned ? "earned" : "locked"}`} key={badge.id} onClick={() => setSelectedBadge(badge)} aria-label={`${badge.name}${badge.earned ? ": earned" : ": locked"}`}><span className="achievement-badge-seal"><Icon size={31} />{!badge.earned && <LockKeyhole className="achievement-badge-lock" size={13} />}</span><strong>{badge.name}</strong>{tab === "badges" && <small>{badge.earned ? `Earned ${dateLabel(badge.earned_at!)}` : "Not earned yet"}</small>}</button>;
  }
  function certificateCard(certificate: LearningCertificate, index: number) {
    return <button key={certificate.id} className={`achievement-certificate-card tone-${index % 3}`} onClick={() => setSelectedCertificate(certificate)}><span className="certificate-decoration"><Medal size={32} /></span><strong>{certificate.title}</strong><small>Issued: {dateLabel(certificate.issued_at)}</small>{tab === "certificates" && <span className="certificate-download-label"><Download size={14} />View Certificate</span>}</button>;
  }
  function achievementRow(entry: AchievementEntry) {
    const Icon = icons[entry.icon as keyof typeof icons] || Trophy;
    const content = <><span className={`achievement-entry-icon ${entry.kind}`}><Icon size={37} /></span><span className="achievement-entry-copy"><h3>{entry.title}</h3><p>{entry.description}</p><time dateTime={entry.occurred_at}><CalendarDays size={15} />{dateLabel(entry.occurred_at)}</time></span><span className={`achievement-entry-status ${entry.kind}`}>{entry.kind === "completed" ? <CheckCircle2 size={17} /> : entry.kind === "badge" ? <Medal size={18} /> : <FileBadge size={17} />}{entry.kind === "completed" ? "Completed" : entry.kind === "badge" ? "Badge Earned" : "Certificate"}</span></>;
    if (entry.certificate_id) return <button key={entry.id} className="achievement-entry" onClick={() => setSelectedCertificate(data?.certificates.find(item => item.id === entry.certificate_id) || null)}>{content}</button>;
    return <Link key={entry.id} to={entry.href || "/learning-area"} className="achievement-entry">{content}</Link>;
  }
  return <MenteeWorkspace title="My Achievements" activePage="achievements" name={name} avatar={data?.avatar} search={search} onSearch={setSearch} searchPlaceholder="Search for courses, achievements, badges or resources..." sidebarAction={() => navigate("/learning-area")}>
    <div className="achievements-page-heading"><div><h1><Trophy size={32} fill="currentColor" />My Achievements</h1><p>A record of your learning, skills, and milestones on NishioHub.</p></div><div className="achievements-heading-actions"><button className="achievements-download-button" disabled={!data || !!downloadKey} onClick={downloadRecord}><Download size={19} />{downloadKey === "record" ? "Downloading…" : "Download Record"}</button><button className="achievements-share-button" disabled={!data?.achievements.length} onClick={() => { setShareId(data?.achievements[0]?.id || ""); setShareOpen(true); }}><Share2 size={20} />Share Achievement</button></div></div>
    {query.isPending ? <Panel><PageLoader label="Loading your achievements…"/></Panel> : query.isError ? <Panel><h2>We couldn’t load your achievements</h2><p className="my-4">Please check your connection and try again.</p><Button onClick={() => query.refetch()}>Try Again</Button></Panel> : data && <>
      <div className="achievements-hero-grid"><section className="achievements-hero"><div className="achievement-portrait-wrap"><Avatar className="achievement-portrait"><AvatarImage src={avatar || undefined} alt={name} /><AvatarFallback>{name.split(" ").map(part => part[0]).slice(0, 2).join("")}</AvatarFallback></Avatar><span className="achievement-portrait-crown"><Crown size={28} fill="currentColor" /></span></div><div className="achievements-hero-copy"><h2>{name}</h2><span className="achievement-hero-role">Mentee</span><blockquote>{data.vision || "Consistent learning and mentorship are helping me grow towards my dreams."}</blockquote></div><img className="achievement-hero-trophy" src="/images/achievement-trophy.png" alt="Golden achievement trophy" /></section><Panel className="achievements-summary"><Heading><ChartNoAxesColumnIncreasing />My Achievement Summary</Heading><div className="achievement-summary-grid"><button onClick={() => navigate("/learning-area")}><span className="summary-icon purple"><GraduationCap /></span><span><strong>{data.summary.courses}</strong><small>Courses<br />Completed</small></span></button><button onClick={() => setTab("badges")}><span className="summary-icon gold"><Medal /></span><span><strong>{data.summary.badges}</strong><small>Badges<br />Earned</small></span></button><button onClick={() => setTab("certificates")}><span className="summary-icon blue"><FileBadge /></span><span><strong>{data.summary.certificates}</strong><small>Certificates<br />Received</small></span></button><button onClick={() => navigate("/learning-area")} title="Completed lessons across enrolled courses"><span className="summary-icon green"><TrendingUp /></span><span><strong>{data.summary.progress}%</strong><small>Overall Progress</small></span></button></div></Panel></div>
      <Tabs value={tab} onValueChange={setTab} className="achievements-tabs-root"><TabsList className="achievements-tabs">{tabs.map(({ id, title, icon: Icon }) => <TabsTrigger key={id} id={`achievement-tab-${id}`} aria-controls="achievements-content" value={id}><Icon size={24} />{title}</TabsTrigger>)}</TabsList></Tabs>
      <div id="achievements-content" role="tabpanel" aria-labelledby={`achievement-tab-${tab}`}>
        {tab === "overview" ? <div className="achievements-overview-grid"><Panel className="achievements-recent"><Heading action={<button className="achievements-text-action" onClick={() => setShowAll(!showAll)}>{showAll ? "Show Less" : "View All"}<ArrowRight size={16} /></button>}><Star fill="currentColor" />Recent Achievements</Heading>{entries.length ? (showAll ? entries : entries.slice(0, 4)).map(achievementRow) : <div className="achievements-empty"><Trophy size={42} /><h3>{search ? "No achievements match your search" : "Your next achievement starts here"}</h3><p>Complete a course, finish a goal, or attend a mentorship session to celebrate your progress.</p><Link to="/learning-area">Explore Learning<ArrowRight size={16} /></Link></div>}</Panel><div className="achievements-secondary"><Panel className="achievements-badges"><Heading action={<button className="achievements-text-action" onClick={() => setTab("badges")}>View All<ArrowRight size={16} /></button>}><Medal fill="currentColor" />My Badges ({data.summary.badges})</Heading><div className="achievement-badge-grid">{badges.slice(0, 5).map(badgeCard)}</div>{!badges.length && <p className="achievement-empty-note">No badges match your search.</p>}</Panel><Panel className="achievements-certificates"><Heading action={<button className="achievements-text-action" onClick={() => setTab("certificates")}>View All<ArrowRight size={16} /></button>}><FileBadge />My Certificates ({data.summary.certificates})</Heading>{certificates.length ? <div className="achievement-certificate-grid">{certificates.slice(0, 3).map(certificateCard)}</div> : <div className="achievement-certificate-empty"><FileBadge size={35} /><p>{search ? "No certificates match your search." : "Complete all lessons in a course to receive your first certificate."}</p><Link to="/learning-area">Continue Learning<ArrowRight size={15} /></Link></div>}</Panel></div></div>
        : tab === "badges" ? <Panel><Heading><Medal />My Badges ({data.summary.badges})</Heading><p className="achievement-helper">Select a badge to see how to earn it. Locked badges show your next opportunities.</p><div className="achievement-badge-grid all-badges">{badges.map(badgeCard)}</div>{!badges.length && <p className="achievement-empty-note">No badges match your search.</p>}</Panel>
        : tab === "certificates" ? <Panel><Heading><FileBadge />My Certificates ({data.summary.certificates})</Heading><p className="achievement-helper">Your NishioHub course completion records. Open a certificate to download it.</p>{certificates.length ? <div className="achievement-certificate-grid all-certificates">{certificates.map(certificateCard)}</div> : <div className="achievements-empty"><FileBadge size={38} /><p>{search ? "No certificates match your search." : "Finish a course to unlock your first certificate."}</p><Link to="/learning-area">Explore Courses<ArrowRight size={15} /></Link></div>}</Panel>
        : tab === "milestones" ? <Panel><Heading action={<Link to="/my-goals" className="achievements-text-action">My Goals<ArrowRight size={16} /></Link>}><Target />My Milestones</Heading>{milestones.length ? <ul className="achievement-milestones">{milestones.map(milestone => <li key={milestone.id}><Link to={milestone.href}>{milestone.completed ? <CheckCircle2 className="completed" size={25} /> : <Circle size={25} />}<span><strong>{milestone.title}</strong><small>{milestone.goal_title}</small></span><span className="achievement-milestone-state">{milestone.completed ? "Completed" : "In Progress"}</span><ArrowRight size={17} /></Link></li>)}</ul> : <div className="achievements-empty"><Target size={38} /><p>{search ? "No milestones match your search." : "Add milestones to your goals and track each step toward your future."}</p><Link to="/my-goals">Set a Goal<ArrowRight size={15} /></Link></div>}</Panel>
        : <Panel><Heading><ChartNoAxesColumnIncreasing />Leaderboard</Heading><div className="achievements-empty"><Trophy size={45} /><h3>Keep growing at your own pace</h3><p>A community leaderboard isn’t available yet. Your learning progress and achievements are recorded here.</p><Link to="/learning-area">Continue Learning<ArrowRight size={16} /></Link></div></Panel>}
      </div>
    </>}
    <Dialog open={!!selectedBadge} onOpenChange={open => { if (!open) setSelectedBadge(null); }}><DialogContent><DialogHeader><DialogTitle>{selectedBadge?.name}</DialogTitle><DialogDescription>{selectedBadge?.earned ? `Earned on ${dateLabel(selectedBadge.earned_at!)}` : "Keep learning to unlock this badge."}</DialogDescription></DialogHeader>{selectedBadge && <div className="achievement-badge-detail">{badgeCard(selectedBadge)}<p>{selectedBadge.description}</p><Button asChild><Link to={selectedBadge.href}>{selectedBadge.earned ? "Explore More" : "Keep Growing"}<ArrowRight size={16} className="ml-2" /></Link></Button></div>}</DialogContent></Dialog>
    <Dialog open={!!selectedCertificate} onOpenChange={open => { if (!open) setSelectedCertificate(null); }}><DialogContent><DialogHeader><DialogTitle>{selectedCertificate?.course_id ? "Course Completion Certificate" : "Achievement Certificate"}</DialogTitle><DialogDescription>Your personal NishioHub learning record.</DialogDescription></DialogHeader>{selectedCertificate && <div className="achievement-certificate-detail"><Medal size={43} /><h2>{name}</h2><p>{selectedCertificate.course_id ? "Completed all lessons and practice activities in" : "Recognized for"}</p><h3>{selectedCertificate.title}</h3><p>Issued: {dateLabel(selectedCertificate.issued_at)}</p><small>Record ID: {selectedCertificate.id}</small><Button disabled={!!downloadKey} onClick={() => downloadCertificate(selectedCertificate)}><Download size={17} className="mr-2" />{downloadKey === selectedCertificate.id ? "Downloading…" : "Download Certificate"}</Button></div>}</DialogContent></Dialog>
    <Dialog open={shareOpen} onOpenChange={setShareOpen}><DialogContent><DialogHeader><DialogTitle>Share an Achievement</DialogTitle><DialogDescription>Choose an earned achievement. Share it through your device or copy its text.</DialogDescription></DialogHeader><div className="achievement-share-form"><Label htmlFor="achievement-share">Achievement</Label><select id="achievement-share" value={shareId} onChange={event => setShareId(event.target.value)}>{data?.achievements.map(entry => <option key={entry.id} value={entry.id}>{entry.title}</option>)}</select><Button onClick={share} disabled={sharing || !shareId}><Share2 size={17} className="mr-2" />{sharing ? "Sharing…" : "Share Achievement"}</Button></div></DialogContent></Dialog>
  </MenteeWorkspace>;
}
