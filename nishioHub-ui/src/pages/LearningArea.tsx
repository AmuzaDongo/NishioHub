import { PageLoader } from "@/components/loaders/PageLoader";
import { useState, type ReactNode } from "react";
import { Link, Navigate, useSearchParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowRight,
  Bell,
  BookOpen,
  CalendarDays,
  ChartNoAxesColumnIncreasing,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  Circle,
  Clock,
  Code2,
  Flame,
  FlaskConical,
  GraduationCap,
  Handshake,
  Home,
  Laptop,
  LayoutGrid,
  Lightbulb,
  Menu,
  MessageSquare,
  Palette,
  Play,
  Route,
  Search,
  Settings,
  Sparkles,
  Sprout,
  Target,
  Trophy,
  UserRound,
  Users,
  Video,
  X,
} from "lucide-react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useAuth } from "@/lib/auth-context";
import { useUnreadNotifications } from "@/hooks/use-unread-notifications";
import { hasRole, roleName } from "@/lib/utils";
import {
  completeLearningLesson,
  enrollInCourse,
  getLearningArea,
  type LearningCategory,
  type LearningCourse,
} from "@/lib/learning-area-api";
import { toast } from "sonner";
import { PlatformResourceLibrary } from "@/components/platform-resource-library";
import "./learning-area.css";

const categoryIcons = {
  laptop: Laptop,
  flask: FlaskConical,
  chart: ChartNoAxesColumnIncreasing,
  handshake: Handshake,
  sprout: Sprout,
  palette: Palette,
  users: Users,
};
function Panel({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`learning-panel ${className}`}>{children}</section>
  );
}
function Heading({
  children,
  action,
}: {
  children: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className='learning-panel-heading'>
      <h2>{children}</h2>
      {action}
    </div>
  );
}
function CourseImage({ course }: { course: LearningCourse }) {
  return (
    <img
      src={course.image}
      alt=''
      loading='lazy'
      onError={(event) => {
        event.currentTarget.onerror = null;
        event.currentTarget.src = "/images/Code.jpg";
      }}
    />
  );
}
export default function LearningAreaPage() {
  const unreadNotifications = useUnreadNotifications();
  const { user, isLoading: authLoading, logout } = useAuth();
  const [params] = useSearchParams();
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [categoryDialog, setCategoryDialog] = useState(false);
  const [courseId, setCourseId] = useState<string | null>(() =>
    params.get("course"),
  );
  const [lessonId, setLessonId] = useState<string | null>(() =>
    params.get("lesson"),
  );
  const client = useQueryClient();
  const queryKey = ["learning-area", user?.id];
  const query = useQuery({
    queryKey,
    queryFn: getLearningArea,
    enabled: !!user && hasRole(user, "mentee"),
  });
  const refresh = () => client.invalidateQueries({ queryKey });
  const enrollMutation = useMutation({
    mutationFn: enrollInCourse,
    onSuccess: refresh,
    onError: () =>
      toast.error("Could not start this course. Please try again."),
  });
  const completeMutation = useMutation({
    mutationFn: completeLearningLesson,
    onSuccess: async () => {
      await refresh();
      toast.success("Lesson completed. Keep growing!");
    },
    onError: () =>
      toast.error("Could not save your progress. Please try again."),
  });
  if (authLoading) return <PageLoader label='Loading Learning Area…' />;
  if (!user) return <Navigate to='/login' replace />;
  if (!hasRole(user, "mentee")) return <Navigate to='/dashboard' replace />;
  const data = query.data;
  const name = data?.name || user.full_name;
  const base = (
    import.meta.env.VITE_API_BASE_URL || "https://api.nishiohub.com/api/v1"
  ).replace(/\/api\/v1\/?$/, "");
  const avatar =
    data?.avatar && !/^(https?:|blob:|data:)/.test(data.avatar)
      ? new URL(data.avatar.replace(/^\//, ""), `${base}/`).href
      : data?.avatar;
  const courses = data?.courses || [];
  const activeCourse = courses.find((course) => course.id === courseId);
  const lesson =
    activeCourse?.lessons.find((item) => item.id === lessonId) ||
    activeCourse?.lessons[0];
  const pathCourse =
    courses.find(
      (course) =>
        course.enrolled &&
        course.completed_lesson_ids.length < course.lessons.length,
    ) || courses.find((course) => course.id === "programming");
  const visibleCourses = courses.filter(
    (course) =>
      (!category || course.category_id === category) &&
      (!search.trim() ||
        `${course.title} ${course.lessons.map((item) => item.title).join(" ")}`
          .toLowerCase()
          .includes(search.trim().toLowerCase())) &&
      (showAll || category || search.trim() || course.featured),
  );
  const recommendations = courses
    .filter((course) => !course.featured)
    .slice(0, 4);
  const openCourse = (course: LearningCourse) => {
    setCourseId(course.id);
    setLessonId(
      (
        course.lessons.find(
          (item) => !course.completed_lesson_ids.includes(item.id),
        ) || course.lessons[0]
      ).id,
    );
  };
  const browseCourses = () => {
    document
      .getElementById("learning-courses")
      ?.scrollIntoView({
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches
          ? "auto"
          : "smooth",
        block: "start",
      });
  };
  const chooseCategory = (item: LearningCategory) => {
    setCategory(category === item.id ? null : item.id);
    setShowAll(true);
    setCategoryDialog(false);
  };
  const navItems = [
    { label: "Overview", icon: Home, to: "/mentee/dashboard" },
    { label: "My Profile", icon: UserRound, to: "/profile" },
    { label: "My Mentorship", icon: Users, to: "/mentee/dashboard#mentorship" },
    { label: "Find a Mentor", icon: Users, to: "/services" },
    { label: "Learning Area", icon: BookOpen, to: "/learning-area" },
    { label: "My Goals", icon: Target, to: "/my-goals" },
    { label: "My Activities", icon: CalendarDays, to: "/my-activities" },
    { label: "Achievements", icon: Trophy, to: "/my-achievements" },
    { label: "Events", icon: CalendarDays, to: "/events" },
    { label: "Messages", icon: MessageSquare, to: "/messages" },
    { label: "Notifications", icon: Bell, to: "/notifications" },
    { label: "Settings", icon: Settings, to: "/settings" },
  ];
  return (
    <div className='learning-shell'>
      <header className='learning-header'>
        <Link to='/' aria-label='NishioHub home'>
          <img
            src='/assets/learning-logo.svg'
            alt='NishioHub — Discover. Learn. Grow.'
            className='learning-logo'
          />
        </Link>
        <div className='learning-search'>
          <Search size={22} />
          <input
            aria-label='Search courses, skills, or topics'
            placeholder='Search for courses, skills, or topics...'
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
          {search && (
            <button aria-label='Clear search' onClick={() => setSearch("")}>
              <X size={17} />
            </button>
          )}
        </div>
        <div className='learning-header-account'>
          <Link
            to='/notifications'
            className='workspace-notification-bell'
            aria-label={`Notifications, ${unreadNotifications} unread`}
          >
            <Bell size={26} />
            {unreadNotifications > 0 && (
              <span>
                {unreadNotifications > 99 ? "99+" : unreadNotifications}
              </span>
            )}
          </Link>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button className='learning-account'>
                <Avatar>
                  <AvatarImage src={avatar || undefined} alt={name} />
                  <AvatarFallback>
                    {name
                      .split(" ")
                      .map((part) => part[0])
                      .slice(0, 2)
                      .join("")}
                  </AvatarFallback>
                </Avatar>
                <span>
                  <strong>{name}</strong>
                  <small>Mentee</small>
                </span>
                <ChevronDown size={20} />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align='end'>
              <DropdownMenuItem asChild>
                <Link to='/profile'>My Profile</Link>
              </DropdownMenuItem>
              <DropdownMenuItem asChild>
                <Link to='/settings'>Settings</Link>
              </DropdownMenuItem>
              <DropdownMenuItem onClick={logout}>Sign Out</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <button
            className='learning-menu-toggle'
            aria-label={menuOpen ? "Close navigation" : "Open navigation"}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(!menuOpen)}
          >
            {menuOpen ? <X /> : <Menu />}
          </button>
        </div>
      </header>
      <aside className={`learning-sidebar ${menuOpen ? "is-open" : ""}`}>
        <nav aria-label='Mentee navigation'>
          {navItems.map(({ label, icon: Icon, to }) => (
            <Link
              key={label}
              to={to}
              className={label === "Learning Area" ? "active" : ""}
              aria-current={label === "Learning Area" ? "page" : undefined}
              onClick={() => setMenuOpen(false)}
            >
              <Icon size={24} />
              {label}
            </Link>
          ))}
        </nav>
        <div className='learning-invite'>
          <GraduationCap size={57} />
          <h3>
            Keep Learning
            <br />
            Keep Growing
          </h3>
          <p>
            Access courses, skills and resources to achieve
            <br />
            your dreams.
          </p>
          <button onClick={browseCourses}>
            Explore Courses
            <ArrowRight size={18} />
          </button>
        </div>
      </aside>
      <main className='learning-main'>
        <div className='learning-breadcrumb'>
          <Link to='/mentee/dashboard' aria-label='Overview'>
            <Home size={19} />
          </Link>
          <ChevronRight size={15} />
          <span>Learning Area</span>
        </div>
        <div className='learning-mobile-search'>
          <Search size={18} />
          <input
            aria-label='Search learning courses'
            placeholder='Search for courses, skills, or topics...'
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </div>
        {query.isPending ? (
          <Panel>
            <PageLoader label='Loading your Learning Area…' />
          </Panel>
        ) : query.isError ? (
          <Panel>
            <h1>Learning Area</h1>
            <p className='my-4'>
              We couldn’t load your courses. Please check your connection.
            </p>
            <Button onClick={() => query.refetch()}>Try Again</Button>
          </Panel>
        ) : (
          data && (
            <div className='learning-columns'>
              <div className='learning-primary'>
                <div className='learning-page-title'>
                  <h1>Learning Area</h1>
                  <p>
                    Build new skills, explore your interests and prepare for
                    your future.
                  </p>
                </div>
                <section className='learning-hero'>
                  <div className='learning-hero-copy'>
                    <h2>Learn. Practice. Grow.</h2>
                    <p>
                      Access courses, guides and resources designed
                      <br className='learning-hero-break' /> for students and
                      young innovators.
                    </p>
                    <button onClick={browseCourses}>
                      <Play size={19} fill='currentColor' />
                      Explore Courses
                    </button>
                  </div>
                </section>
                <Panel className='learning-categories'>
                  <Heading
                    action={
                      <button
                        className='learning-text-link'
                        onClick={() => setCategoryDialog(true)}
                      >
                        View All Categories
                        <ArrowRight size={16} />
                      </button>
                    }
                  >
                    <LayoutGrid />
                    Explore by Category
                  </Heading>
                  <div className='learning-category-grid'>
                    {data.categories.map((item) => {
                      const Icon =
                        categoryIcons[
                          item.icon as keyof typeof categoryIcons
                        ] || BookOpen;
                      return (
                        <button
                          className={`learning-category ${item.color} ${category === item.id ? "is-selected" : ""}`}
                          key={item.id}
                          onClick={() => chooseCategory(item)}
                          aria-pressed={category === item.id}
                        >
                          <Icon size={34} />
                          <span>{item.name}</span>
                        </button>
                      );
                    })}
                  </div>
                </Panel>
                <Panel className='learning-featured'>
                  <div
                    id='learning-courses'
                    className='learning-course-anchor'
                  />
                  <Heading
                    action={
                      <button
                        className='learning-text-link'
                        onClick={() => {
                          setShowAll(!showAll);
                          setCategory(null);
                        }}
                      >
                        {showAll ? "Featured Courses" : "View All Courses"}
                        <ArrowRight size={16} />
                      </button>
                    }
                  >
                    <GraduationCap />
                    {showAll || category || search
                      ? "Explore Courses"
                      : "Featured Courses"}
                  </Heading>
                  {(category || search) && (
                    <div className='learning-filter-line'>
                      <span>
                        {category
                          ? data.categories.find((item) => item.id === category)
                              ?.name
                          : `Results for “${search}”`}
                      </span>
                      <button
                        onClick={() => {
                          setCategory(null);
                          setSearch("");
                        }}
                      >
                        Clear filters
                        <X size={13} />
                      </button>
                    </div>
                  )}
                  <div className='learning-course-grid'>
                    {visibleCourses.map((course) => {
                      const completed =
                        course.completed_lesson_ids.length ===
                        course.lessons.length;
                      return (
                        <article
                          className='learning-course-card'
                          key={course.id}
                        >
                          <div className='learning-course-image'>
                            <CourseImage course={course} />
                            <span
                              className={`learning-level ${course.level === "Intermediate" ? "intermediate" : ""}`}
                            >
                              {course.level}
                            </span>
                          </div>
                          <div className='learning-course-body'>
                            <h3>{course.title}</h3>
                            <p>
                              <CalendarDays size={12} />
                              {course.lessons.length} Lessons<span>·</span>
                              <Clock size={12} />
                              {course.lessons.reduce(
                                (sum, item) => sum + item.minutes,
                                0,
                              ) / 60}{" "}
                              Hours
                            </p>
                            <button onClick={() => openCourse(course)}>
                              {completed ? (
                                <CheckCircle2 size={14} />
                              ) : (
                                <Play size={14} fill='currentColor' />
                              )}
                              {completed
                                ? "Review Course"
                                : course.enrolled
                                  ? "Continue Course"
                                  : "Start Course"}
                            </button>
                          </div>
                        </article>
                      );
                    })}
                  </div>
                  {!visibleCourses.length && (
                    <div className='learning-empty'>
                      <BookOpen size={30} />
                      <p>No courses found in this selection yet.</p>
                      <button
                        className='learning-text-link'
                        onClick={() => {
                          setCategory(null);
                          setSearch("");
                          setShowAll(true);
                        }}
                      >
                        Explore all courses
                        <ArrowRight size={15} />
                      </button>
                    </div>
                  )}
                </Panel>
                <Panel className='learning-recommended'>
                  <Heading>
                    <Sparkles />
                    Recommended for You
                  </Heading>
                  <div className='learning-recommendation-grid'>
                    {recommendations.map((course, index) => {
                      const Icon = [
                        Code2,
                        ChartNoAxesColumnIncreasing,
                        Sprout,
                        Users,
                      ][index];
                      return (
                        <button
                          key={course.id}
                          onClick={() => openCourse(course)}
                        >
                          <Icon size={24} />
                          <span>{course.title}</span>
                        </button>
                      );
                    })}
                  </div>
                </Panel>
                <PlatformResourceLibrary
                  resources={data.shared_resources || []}
                />
              </div>
              <div className='learning-secondary'>
                <Panel className='learning-progress-card'>
                  <Heading>
                    <ChartNoAxesColumnIncreasing />
                    My Learning Progress
                  </Heading>
                  <div className='learning-progress-row'>
                    <div
                      className='learning-progress-track'
                      role='progressbar'
                      aria-label='Completed lessons in enrolled courses'
                      aria-valuemin={0}
                      aria-valuemax={100}
                      aria-valuenow={data.progress.percent}
                    >
                      <span style={{ width: `${data.progress.percent}%` }} />
                    </div>
                    <strong>{data.progress.percent}%</strong>
                  </div>
                  <div className='learning-stat-grid'>
                    <div>
                      <BookOpen />
                      <strong>{data.progress.enrolled}</strong>
                      <span>Courses</span>
                    </div>
                    <div>
                      <CheckCircle2 />
                      <strong>{data.progress.completed}</strong>
                      <span>Completed</span>
                    </div>
                    <div title='Estimated study hours from completed lessons'>
                      <Clock />
                      <strong>{data.progress.hours}</strong>
                      <span>Hours</span>
                    </div>
                  </div>
                </Panel>
                <Panel className='learning-path'>
                  <Heading>
                    <Route />
                    My Learning Path
                  </Heading>
                  <div className='learning-path-title'>
                    <Target size={23} />
                    {pathCourse?.id === "programming"
                      ? "Software Engineering Aspirant"
                      : pathCourse?.title || "Your Learning Journey"}
                  </div>
                  <ul>
                    {pathCourse?.lessons.map((item) => {
                      const done = pathCourse.completed_lesson_ids.includes(
                        item.id,
                      );
                      return (
                        <li key={item.id}>
                          <button
                            onClick={() => {
                              openCourse(pathCourse);
                              setLessonId(item.id);
                            }}
                          >
                            {done ? (
                              <CheckCircle2
                                className='is-completed'
                                size={21}
                              />
                            ) : (
                              <Circle size={21} />
                            )}
                            <span>{item.title}</span>
                          </button>
                        </li>
                      );
                    })}
                  </ul>
                  <button
                    className='learning-outline-button'
                    onClick={() => {
                      if (pathCourse) openCourse(pathCourse);
                    }}
                  >
                    Continue Learning
                    <ArrowRight size={18} />
                  </button>
                </Panel>
                <Panel className='learning-streak'>
                  <Flame size={32} fill='#ffb600' />
                  <div>
                    <h2>Learning Streak</h2>
                    <strong>
                      {data.progress.streak}{" "}
                      {data.progress.streak === 1 ? "Day" : "Days"}
                    </strong>
                    <p>
                      {data.progress.streak
                        ? "Keep it up! Consistency builds great skills."
                        : "Complete a lesson to start your streak."}
                    </p>
                  </div>
                </Panel>
                <Panel className='learning-sessions'>
                  <Heading>
                    <CalendarDays />
                    Upcoming Learning Sessions
                  </Heading>
                  {data.upcoming_sessions.length ? (
                    data.upcoming_sessions.map((session) => {
                      const date = new Date(session.scheduled_at);
                      return (
                        <Link
                          className='learning-session'
                          to='/bookings'
                          key={session.id}
                        >
                          <div className='learning-session-date'>
                            <span>
                              {date.toLocaleDateString(undefined, {
                                month: "short",
                              })}
                            </span>
                            <strong>{date.getDate()}</strong>
                          </div>
                          <div>
                            <h3>{session.title}</h3>
                            <p>
                              {date.toLocaleDateString(undefined, {
                                weekday: "short",
                                month: "short",
                                day: "numeric",
                                year: "numeric",
                              })}{" "}
                              ·{" "}
                              {date.toLocaleTimeString([], {
                                hour: "2-digit",
                                minute: "2-digit",
                              })}
                            </p>
                          </div>
                          <Video size={18} />
                        </Link>
                      );
                    })
                  ) : (
                    <div className='learning-empty learning-empty-small'>
                      <CalendarDays size={26} />
                      <p>No confirmed learning sessions yet.</p>
                      <Link className='learning-text-link' to='/services'>
                        Find a Mentor
                        <ArrowRight size={14} />
                      </Link>
                    </div>
                  )}
                  <Link className='learning-schedule-link' to='/bookings'>
                    View Full Schedule
                    <ArrowRight size={18} />
                  </Link>
                </Panel>
              </div>
            </div>
          )
        )}
      </main>
      <Dialog open={categoryDialog} onOpenChange={setCategoryDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Explore by Category</DialogTitle>
            <DialogDescription>
              Choose a learning area to explore its courses.
            </DialogDescription>
          </DialogHeader>
          <div className='learning-category-dialog'>
            {data?.categories.map((item) => {
              const Icon =
                categoryIcons[item.icon as keyof typeof categoryIcons] ||
                BookOpen;
              return (
                <button key={item.id} onClick={() => chooseCategory(item)}>
                  <Icon size={24} />
                  {item.name}
                  <ArrowRight size={16} />
                </button>
              );
            })}
          </div>
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!activeCourse}
        onOpenChange={(open) => {
          if (!open) {
            setCourseId(null);
            setLessonId(null);
          }
        }}
      >
        <DialogContent className='learning-reader'>
          <DialogHeader>
            <DialogTitle>{activeCourse?.title}</DialogTitle>
            <DialogDescription>
              {activeCourse?.level} · {activeCourse?.lessons.length} lessons ·
              Your progress saves automatically when you complete a lesson.
            </DialogDescription>
          </DialogHeader>
          {activeCourse && lesson && (
            <div className='learning-reader-grid'>
              <nav aria-label='Course lessons'>
                {activeCourse.lessons.map((item, index) => (
                  <button
                    key={item.id}
                    className={lesson.id === item.id ? "active" : ""}
                    onClick={() => setLessonId(item.id)}
                  >
                    {activeCourse.completed_lesson_ids.includes(item.id) ? (
                      <CheckCircle2 size={16} />
                    ) : (
                      <span>{index + 1}</span>
                    )}
                    {item.title}
                  </button>
                ))}
              </nav>
              <article>
                <p className='learning-reader-meta'>
                  <Clock size={14} />
                  {lesson.minutes} minute lesson and practice
                </p>
                <h2>{lesson.title}</h2>
                <p>{lesson.content}</p>
                <div className='learning-practice'>
                  <h3>
                    <Lightbulb size={20} />
                    Try it yourself
                  </h3>
                  <p>{lesson.practice}</p>
                </div>
                {!activeCourse.enrolled ? (
                  <Button
                    onClick={() => enrollMutation.mutate(activeCourse.id)}
                    disabled={enrollMutation.isPending}
                  >
                    {enrollMutation.isPending ? "Starting…" : "Start Course"}
                    <Play size={15} className='ml-2' />
                  </Button>
                ) : activeCourse.completed_lesson_ids.includes(lesson.id) ? (
                  <div className='learning-lesson-complete'>
                    <Check size={19} />
                    Lesson completed
                    {activeCourse.lessons.some(
                      (item) =>
                        !activeCourse.completed_lesson_ids.includes(item.id),
                    ) && (
                      <button
                        onClick={() =>
                          setLessonId(
                            activeCourse.lessons.find(
                              (item) =>
                                !activeCourse.completed_lesson_ids.includes(
                                  item.id,
                                ),
                            )!.id,
                          )
                        }
                      >
                        Next Lesson
                        <ArrowRight size={15} />
                      </button>
                    )}
                  </div>
                ) : (
                  <Button
                    onClick={() =>
                      completeMutation.mutate({
                        courseId: activeCourse.id,
                        lessonId: lesson.id,
                      })
                    }
                    disabled={completeMutation.isPending}
                  >
                    {completeMutation.isPending
                      ? "Saving…"
                      : "Mark Lesson Complete"}
                    <Check size={17} className='ml-2' />
                  </Button>
                )}
              </article>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
