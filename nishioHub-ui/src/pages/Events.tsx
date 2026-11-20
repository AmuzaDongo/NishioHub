import { PageLoader } from "@/components/loaders/PageLoader";
import { EventParticipantContent } from "@/components/event-participant-content";
import { useState, type ReactNode } from "react";
import { Navigate, useSearchParams } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowRight,
  Bell,
  CalendarDays,
  ChartNoAxesColumnIncreasing,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock,
  Download,
  GraduationCap,
  MapPin,
  Mic,
  Plus,
  Star,
  Trophy,
  Users,
  X,
  Zap,
} from "lucide-react";
import { MenteeWorkspace } from "@/components/layout/mentee-workspace";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useAuth } from "@/lib/auth-context";
import { hasRole, roleName } from "@/lib/utils";
import { saveDownload } from "@/lib/achievements-api";
import {
  cancelEventRegistration,
  createCommunityEvent,
  downloadEventCalendar,
  getCommunityEvent,
  getEventAttendees,
  getEventsWorkspace,
  recordEventAttendance,
  registerForEvent,
  suggestCommunityEvent,
  updateEventReminder,
  type CommunityEvent,
  type EventCategory,
  type EventDraft,
} from "@/lib/events-api";
import { toast } from "sonner";
import "./events.css";

const zone = "Africa/Kampala";
const categoryNames: Record<EventCategory, string> = {
  workshop: "Workshop",
  talk: "Career Talk",
  challenge: "Challenge",
  mentorship: "Mentorship",
};
const categories = [
  { id: "all", label: "All Events", icon: CalendarDays },
  { id: "workshop", label: "Workshops", icon: GraduationCap },
  { id: "talk", label: "Talks", icon: Mic },
  { id: "challenge", label: "Challenges", icon: Trophy },
  { id: "mentorship", label: "Mentorship", icon: Users },
];
const emptyDraft: EventDraft = {
  title: "",
  description: "",
  category: "workshop",
  starts_at: "",
  ends_at: "",
  location: "",
  meeting_url: "",
  capacity: null,
};
function dayKey(value: Date) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en", {
      timeZone: zone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    })
      .formatToParts(value)
      .map((item) => [item.type, item.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}
function eventDate(event: CommunityEvent) {
  const start = new Date(event.starts_at),
    end = new Date(event.ends_at);
  const options: Intl.DateTimeFormatOptions = {
    timeZone: zone,
    month: "short",
    day: "numeric",
    year: "numeric",
  };
  return dayKey(start) === dayKey(end)
    ? start.toLocaleDateString(undefined, { ...options, weekday: "short" })
    : `${start.toLocaleDateString(undefined, options)} – ${end.toLocaleDateString(undefined, options)}`;
}
function eventTime(event: CommunityEvent) {
  const options: Intl.DateTimeFormatOptions = {
    timeZone: zone,
    hour: "numeric",
    minute: "2-digit",
  };
  return `${new Date(event.starts_at).toLocaleTimeString([], options)} – ${new Date(event.ends_at).toLocaleTimeString([], options)}`;
}
function Panel({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return <section className={`events-panel ${className}`}>{children}</section>;
}
function apiError(error: unknown) {
  const detail = (
    error as { response?: { data?: { detail?: string | string[] } } }
  )?.response?.data?.detail;
  toast.error(
    Array.isArray(detail)
      ? detail.join(", ")
      : detail || "Could not save your changes. Please try again.",
  );
}
export default function EventsPage() {
  const { user, isLoading: authLoading } = useAuth();
  const [params] = useSearchParams();
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("all");
  const [allEvents, setAllEvents] = useState(false);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);
  const today = dayKey(new Date());
  const [month, setMonth] = useState(() => {
    const [year, m] = today.split("-").map(Number);
    return new Date(year, m - 1, 1);
  });
  const [selectedId, setSelectedId] = useState<number | null>(() => {
    const id = Number(params.get("event"));
    return Number.isInteger(id) && id > 0 ? id : null;
  });
  const [registrationsOpen, setRegistrationsOpen] = useState(false);
  const [registrationMode, setRegistrationMode] = useState("registered");
  const [formMode, setFormMode] = useState<"create" | "suggest" | null>(null);
  const [draft, setDraft] = useState<EventDraft>(emptyDraft);
  const [cancelTarget, setCancelTarget] = useState<CommunityEvent | null>(null);
  const [reminderTarget, setReminderTarget] = useState<CommunityEvent | null>(
    null,
  );
  const [reminderMinutes, setReminderMinutes] = useState(15);
  const [downloading, setDownloading] = useState(false);
  const client = useQueryClient();
  const enabled = !!user && roleName(user) === "mentee";
  const queryKey = ["events", user?.id];
  const query = useQuery({ queryKey, queryFn: getEventsWorkspace, enabled });
  const detail = useQuery({
    queryKey: ["event-detail", user?.id, selectedId],
    queryFn: () => getCommunityEvent(selectedId!),
    enabled: enabled && !!selectedId,
  });
  const attendees = useQuery({
    queryKey: ["event-attendees", user?.id, selectedId],
    queryFn: () => getEventAttendees(selectedId!),
    enabled: enabled && !!selectedId && !!detail.data?.can_manage,
  });
  const refresh = async () => {
    await Promise.all([
      client.invalidateQueries({ queryKey }),
      client.invalidateQueries({ queryKey: ["event-detail", user?.id] }),
      client.invalidateQueries({ queryKey: ["my-activities", user?.id] }),
      client.invalidateQueries({ queryKey: ["my-achievements", user?.id] }),
      client.invalidateQueries({ queryKey: ["mentee-dashboard", user?.id] }),
    ]);
  };
  const register = useMutation({
    mutationFn: registerForEvent,
    onSuccess: async () => {
      await refresh();
      toast.success("You’re registered for the event");
    },
    onError: apiError,
  });
  const cancel = useMutation({
    mutationFn: cancelEventRegistration,
    onSuccess: async () => {
      await refresh();
      setCancelTarget(null);
      toast.success("Registration cancelled");
    },
    onError: apiError,
  });
  const create = useMutation({
    mutationFn: createCommunityEvent,
    onSuccess: async (event) => {
      await refresh();
      setFormMode(null);
      setSelectedId(event.id);
      toast.success("Event created");
    },
    onError: apiError,
  });
  const suggest = useMutation({
    mutationFn: suggestCommunityEvent,
    onSuccess: async () => {
      await refresh();
      setFormMode(null);
      toast.success("Event suggestion saved");
    },
    onError: apiError,
  });
  const reminder = useMutation({
    mutationFn: updateEventReminder,
    onSuccess: refresh,
    onError: apiError,
  });
  const attendance = useMutation({
    mutationFn: recordEventAttendance,
    onSuccess: async () => {
      await Promise.all([
        refresh(),
        client.invalidateQueries({
          queryKey: ["event-attendees", user?.id, selectedId],
        }),
      ]);
      toast.success("Attendance updated");
    },
    onError: apiError,
  });
  if (authLoading) return <PageLoader label='Loading events…' />;
  if (!user) return <Navigate to='/login' replace />;
  if (!hasRole(user, "mentee")) return <Navigate to='/dashboard' replace />;
  const data = query.data;
  const event = detail.data;
  const now = Date.now();
  const matches =
    data?.events.filter(
      (item) =>
        (category === "all" || category === item.category) &&
        `${item.title} ${item.description} ${item.location} ${item.organizer.name}`
          .toLowerCase()
          .includes(search.trim().toLowerCase()),
    ) || [];
  const matchingDayRanges = matches.map((item) => [
    dayKey(new Date(item.starts_at)),
    dayKey(new Date(item.ends_at)),
  ]);
  const filtered = matches.filter(
    (item) =>
      !selectedDay ||
      (dayKey(new Date(item.starts_at)) <= selectedDay &&
        dayKey(new Date(item.ends_at)) >= selectedDay),
  );
  const events = allEvents ? filtered : filtered.slice(0, 4);
  const monthLabel = month.toLocaleDateString(undefined, {
    month: "long",
    year: "numeric",
  });
  const ownRegistrations =
    data?.registrations.filter(
      (item) => item.registration?.status === "registered",
    ) || [];
  const registered = event?.registration?.status === "registered";
  const browse = () => {
    setCategory("all");
    setSearch("");
    setSelectedDay(null);
    setAllEvents(true);
    document
      .getElementById("events-list")
      ?.scrollIntoView({ behavior: "auto", block: "start" });
  };
  const openForm = (mode: "create" | "suggest") => {
    setDraft({ ...emptyDraft });
    setFormMode(mode);
  };
  const openReminder = (item: CommunityEvent) => {
    setRegistrationsOpen(false);
    setSelectedId(null);
    setReminderTarget(item);
    setReminderMinutes(item.registration?.reminder_minutes ?? 15);
  };
  const saveReminderAndDownload = async () => {
    if (!reminderTarget) return;
    setDownloading(true);
    try {
      await reminder.mutateAsync({
        id: reminderTarget.id,
        minutes: reminderMinutes,
      });
      saveDownload(
        await downloadEventCalendar(reminderTarget.id),
        `nishiohub-event-${reminderTarget.id}.ics`,
      );
      toast.success(
        "Calendar file downloaded. Open it in your calendar to add the reminder.",
      );
      setReminderTarget(null);
    } catch (error) {
      if (!(error as { response?: unknown }).response)
        toast.error("Could not download the calendar file. Please try again.");
    } finally {
      setDownloading(false);
    }
  };
  return (
    <MenteeWorkspace
      title='Events'
      name={data?.name || user.full_name}
      avatar={data?.avatar}
      activePage='events'
      search={search}
      onSearch={setSearch}
      searchPlaceholder='Search for courses, events, mentors, or topics...'
      sidebarAction={browse}
    >
      <div className='events-page-heading'>
        <div>
          <h1>
            <CalendarDays size={35} />
            Events
          </h1>
          <p>
            Discover and join upcoming learning, mentorship and community
            events.
          </p>
        </div>
        <div className='events-heading-actions'>
          <button
            className='events-outline-button'
            onClick={() => {
              setRegistrationMode("registered");
              setRegistrationsOpen(true);
            }}
            disabled={!data}
          >
            <CalendarDays size={20} />
            My Registrations
          </button>
          <button
            className='events-primary-button'
            onClick={() => openForm("create")}
          >
            <Plus size={23} />
            Create Event
          </button>
        </div>
      </div>
      {query.isPending ? (
        <Panel>
          <PageLoader label='Loading your events…' />
        </Panel>
      ) : query.isError ? (
        <Panel>
          <h2>We couldn’t load events</h2>
          <p className='my-4'>Please check your connection and try again.</p>
          <Button onClick={() => query.refetch()}>Try Again</Button>
        </Panel>
      ) : (
        data && (
          <div className='events-columns'>
            <div className='events-primary'>
              <section className='events-hero'>
                <div>
                  <h2>Upcoming Events</h2>
                  <p>
                    Join workshops, career talks, competitions
                    <br className='events-hero-break' /> and mentorship sessions
                    to learn, build
                    <br className='events-hero-break' /> skills and expand your
                    network.
                  </p>
                  <button onClick={browse}>
                    <CalendarDays size={22} />
                    Explore Events
                  </button>
                </div>
              </section>
              <Tabs
                value={category}
                onValueChange={(value) => {
                  setCategory(value);
                  setSelectedDay(null);
                }}
              >
                <TabsList className='events-tabs'>
                  {categories.map(({ id, label, icon: Icon }) => (
                    <TabsTrigger
                      key={id}
                      value={id}
                      id={`events-tab-${id}`}
                      aria-controls='events-list'
                    >
                      <Icon size={23} />
                      {label}
                    </TabsTrigger>
                  ))}
                </TabsList>
              </Tabs>
              <Panel className='events-list-panel'>
                <div className='events-section-heading'>
                  <h2>
                    <CalendarDays />
                    Upcoming Events ({filtered.length})
                  </h2>
                  <button
                    className='events-text-action'
                    onClick={() => setAllEvents(!allEvents)}
                  >
                    {allEvents ? "Show Less" : "View All"}
                    <ArrowRight size={16} />
                  </button>
                </div>
                {(search || selectedDay) && (
                  <div className='events-filter-line'>
                    <span>
                      {selectedDay
                        ? `Events on ${new Date(`${selectedDay}T12:00:00`).toLocaleDateString()}`
                        : `Search: “${search}”`}
                    </span>
                    <button
                      onClick={() => {
                        setSelectedDay(null);
                        setSearch("");
                      }}
                    >
                      Clear Filters
                      <X size={14} />
                    </button>
                  </div>
                )}
                <div
                  id='events-list'
                  className='events-card-grid'
                  role='tabpanel'
                  aria-labelledby={`events-tab-${category}`}
                >
                  {events.map((item) => {
                    const joined = item.registration?.status === "registered";
                    const full = item.available_places === 0;
                    return (
                      <article className='event-card' key={item.id}>
                        <button
                          className='event-card-image'
                          onClick={() => setSelectedId(item.id)}
                          aria-label={`View ${item.title}`}
                        >
                          <img src={item.image} alt='' loading='lazy' />
                        </button>
                        <div className='event-card-copy'>
                          <span className={`event-category ${item.category}`}>
                            {categoryNames[item.category]}
                          </span>
                          <button
                            onClick={() => setSelectedId(item.id)}
                            className='event-title'
                          >
                            <h3>{item.title}</h3>
                          </button>
                          <p>{item.description}</p>
                        </div>
                        <div className='event-card-footer'>
                          <div className='event-card-meta'>
                            <span>
                              <CalendarDays size={14} />
                              {eventDate(item)}
                            </span>
                            {dayKey(new Date(item.starts_at)) ===
                              dayKey(new Date(item.ends_at)) && (
                              <span>
                                <Clock size={14} />
                                {eventTime(item)}
                              </span>
                            )}
                            <span>
                              <MapPin size={14} />
                              {item.location}
                            </span>
                          </div>
                          <button
                            className='event-register-button'
                            disabled={register.isPending || (!joined && full)}
                            onClick={() =>
                              joined
                                ? setSelectedId(item.id)
                                : register.mutate(item.id)
                            }
                          >
                            {register.isPending &&
                            register.variables === item.id
                              ? "Registering…"
                              : joined
                                ? "Registered"
                                : full
                                  ? "Event Full"
                                  : item.category === "challenge"
                                    ? "Join Challenge"
                                    : "Register"}
                            {joined ? (
                              <CheckCircle2 size={16} />
                            ) : (
                              <ArrowRight size={17} />
                            )}
                          </button>
                        </div>
                      </article>
                    );
                  })}
                </div>
                {!events.length && (
                  <div className='events-empty'>
                    <CalendarDays size={39} />
                    <h3>
                      {search || selectedDay || category !== "all"
                        ? "No events match this view"
                        : "New learning opportunities are on the way"}
                    </h3>
                    <p>
                      Browse another category or suggest an event you would love
                      to join.
                    </p>
                    <button
                      className='events-text-action'
                      onClick={() => openForm("suggest")}
                    >
                      Suggest an Event
                      <ArrowRight size={16} />
                    </button>
                  </div>
                )}
              </Panel>
            </div>
            <div className='events-secondary'>
              <Panel className='events-calendar'>
                <div className='events-section-heading'>
                  <h2>
                    <CalendarDays />
                    Events Calendar
                  </h2>
                </div>
                <div className='events-calendar-navigation'>
                  <button
                    aria-label='Previous month'
                    onClick={() =>
                      setMonth(
                        new Date(month.getFullYear(), month.getMonth() - 1, 1),
                      )
                    }
                  >
                    <ChevronLeft size={22} />
                  </button>
                  <h3 aria-live='polite'>{monthLabel}</h3>
                  <button
                    aria-label='Next month'
                    onClick={() =>
                      setMonth(
                        new Date(month.getFullYear(), month.getMonth() + 1, 1),
                      )
                    }
                  >
                    <ChevronRight size={22} />
                  </button>
                </div>
                <div
                  className='events-calendar-grid'
                  role='group'
                  aria-label={`Events in ${monthLabel}`}
                >
                  {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map(
                    (day) => (
                      <span key={day} className='events-weekday'>
                        {day}
                      </span>
                    ),
                  )}
                  {Array.from({ length: month.getDay() }, (_, index) => (
                    <span key={`blank-${index}`} />
                  ))}
                  {Array.from(
                    {
                      length: new Date(
                        month.getFullYear(),
                        month.getMonth() + 1,
                        0,
                      ).getDate(),
                    },
                    (_, index) => {
                      const day = index + 1;
                      const key = `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
                      const hasEvent = matchingDayRanges.some(
                        ([start, end]) => start <= key && end >= key,
                      );
                      return (
                        <button
                          key={key}
                          aria-label={`${new Date(month.getFullYear(), month.getMonth(), day).toLocaleDateString(undefined, { dateStyle: "long" })}${hasEvent ? ": events available" : ""}`}
                          aria-pressed={selectedDay === key}
                          aria-current={today === key ? "date" : undefined}
                          className={`${selectedDay === key ? "selected" : ""} ${today === key ? "today" : ""}`}
                          onClick={() =>
                            setSelectedDay(selectedDay === key ? null : key)
                          }
                        >
                          <span>{day}</span>
                          <i className={hasEvent ? "has-event" : ""} />
                        </button>
                      );
                    },
                  )}
                </div>
              </Panel>
              <Panel className='events-summary'>
                <div className='events-section-heading'>
                  <h2>
                    <ChartNoAxesColumnIncreasing />
                    My Event Summary
                  </h2>
                </div>
                <div className='events-summary-grid'>
                  <button
                    onClick={() => {
                      setRegistrationMode("registered");
                      setRegistrationsOpen(true);
                    }}
                  >
                    <CalendarDays />
                    <strong>{data.summary.registered}</strong>
                    <span>Registered</span>
                  </button>
                  <button
                    onClick={() => {
                      setRegistrationMode("attended");
                      setRegistrationsOpen(true);
                    }}
                  >
                    <CheckCircle2 />
                    <strong>{data.summary.attended}</strong>
                    <span>Attended</span>
                  </button>
                  <button
                    onClick={() => {
                      setRegistrationMode("upcoming");
                      setRegistrationsOpen(true);
                    }}
                  >
                    <Star fill='currentColor' />
                    <strong>{data.summary.upcoming}</strong>
                    <span>Upcoming</span>
                  </button>
                </div>
              </Panel>
              <Panel className='events-quick'>
                <div className='events-section-heading'>
                  <h2>
                    <Zap />
                    Quick Actions
                  </h2>
                </div>
                <button onClick={browse}>
                  <CalendarDays />
                  Browse All Events
                  <ChevronRight size={19} />
                </button>
                <button
                  onClick={() => {
                    setRegistrationMode("reminders");
                    setRegistrationsOpen(true);
                  }}
                >
                  <Bell />
                  Set Event Reminders
                  <ChevronRight size={19} />
                </button>
                <button onClick={() => openForm("suggest")}>
                  <Users />
                  Suggest an Event
                  <ChevronRight size={19} />
                </button>
              </Panel>
            </div>
          </div>
        )
      )}
      <Dialog
        open={!!selectedId}
        onOpenChange={(open) => {
          if (!open) setSelectedId(null);
        }}
      >
        <DialogContent className='events-dialog'>
          <DialogHeader>
            <DialogTitle>{event?.title || "Event Details"}</DialogTitle>
            <DialogDescription>
              {event
                ? `${categoryNames[event.category]} · Organized by ${event.organizer.name}`
                : "Loading event details…"}
            </DialogDescription>
          </DialogHeader>
          {detail.isError ? (
            <p>
              Could not load this event.{" "}
              <button onClick={() => detail.refetch()}>Try Again</button>
            </p>
          ) : (
            event && (
              <div className='event-detail'>
                <img src={event.image} alt='' />
                <p>{event.description}</p>
                <div className='event-detail-meta'>
                  <span>
                    <CalendarDays />
                    {eventDate(event)}
                  </span>
                  <span>
                    <Clock />
                    {eventTime(event)} (Kampala)
                  </span>
                  <span>
                    <MapPin />
                    {event.location}
                  </span>
                  {event.available_places !== null && (
                    <span>{event.available_places} places available</span>
                  )}
                </div>
                {event.status !== "published" ? (
                  <p role='status'>
                    This event is {event.display_status}. Registration and
                    calendar reminders are unavailable.
                  </p>
                ) : event.registration?.attended_at ? (
                  <p className='event-attended'>
                    <CheckCircle2 size={19} />
                    Attendance confirmed
                  </p>
                ) : registered ? (
                  <div className='event-detail-actions'>
                    <Button onClick={() => openReminder(event)}>
                      <Download size={16} className='mr-2' />
                      Add to Calendar
                    </Button>
                    {event.meeting_url && (
                      <Button asChild variant='outline'>
                        <a
                          href={event.meeting_url}
                          target='_blank'
                          rel='noopener noreferrer'
                        >
                          Open Event Link
                        </a>
                      </Button>
                    )}
                    <Button
                      variant='outline'
                      onClick={() => {
                        setSelectedId(null);
                        setCancelTarget(event);
                      }}
                    >
                      Cancel Registration
                    </Button>
                  </div>
                ) : (
                  new Date(event.ends_at).getTime() > now && (
                    <Button
                      disabled={
                        register.isPending || event.available_places === 0
                      }
                      onClick={() => register.mutate(event.id)}
                    >
                      {event.available_places === 0
                        ? "Event Full"
                        : register.isPending
                          ? "Registering…"
                          : "Register"}
                    </Button>
                  )
                )}
                {event.registration?.status === "registered" &&
                  event.status === "published" && (
                    <EventParticipantContent key={event.id} id={event.id} />
                  )}{" "}
                {event.can_manage && (
                  <div className='event-attendee-section'>
                    <h3>Manage Attendees</h3>
                    <p>
                      Only the organizer or an administrator can confirm
                      attendance once the event starts.
                    </p>
                    {attendees.isPending ? (
                      <PageLoader label='Loading attendees…' />
                    ) : attendees.isError ? (
                      <Button
                        variant='outline'
                        onClick={() => attendees.refetch()}
                      >
                        Retry Attendees
                      </Button>
                    ) : attendees.data?.length ? (
                      attendees.data.map((person) => (
                        <label key={person.id}>
                          <input
                            type='checkbox'
                            checked={person.attended}
                            disabled={
                              event.status !== "published" ||
                              attendance.isPending ||
                              new Date(event.starts_at).getTime() > now
                            }
                            onChange={(change) =>
                              attendance.mutate({
                                eventId: event.id,
                                id: person.id,
                                attended: change.target.checked,
                              })
                            }
                          />
                          {person.name}
                          <span>
                            {person.attended ? "Attended" : "Registered"}
                          </span>
                        </label>
                      ))
                    ) : (
                      <p>No registrations yet.</p>
                    )}
                  </div>
                )}
              </div>
            )
          )}
        </DialogContent>
      </Dialog>
      <Dialog open={registrationsOpen} onOpenChange={setRegistrationsOpen}>
        <DialogContent className='events-dialog'>
          <DialogHeader>
            <DialogTitle>
              {registrationMode === "reminders"
                ? "Set Event Reminders"
                : "My Registrations"}
            </DialogTitle>
            <DialogDescription>
              Manage your registrations, reminders, and hosted events.
            </DialogDescription>
          </DialogHeader>
          <div className='event-registration-filters'>
            {["registered", "upcoming", "attended", "hosted"].map((mode) => (
              <button
                key={mode}
                onClick={() => setRegistrationMode(mode)}
                aria-pressed={registrationMode === mode}
              >
                {mode === "hosted" ? "Hosted Events" : mode}
              </button>
            ))}
          </div>
          <div className='event-registration-list'>
            {(registrationMode === "hosted"
              ? data?.hosted_events || []
              : ownRegistrations.filter((item) =>
                  registrationMode === "attended"
                    ? !!item.registration?.attended_at
                    : registrationMode === "upcoming" ||
                        registrationMode === "reminders"
                      ? item.status === "published" &&
                        !item.registration?.attended_at &&
                        new Date(item.ends_at).getTime() > now
                      : true,
                )
            ).map((item) => (
              <article key={item.id}>
                <div>
                  <h3>
                    {item.title}
                    {item.status !== "published" && ` (${item.display_status})`}
                  </h3>
                  <p>{eventDate(item)}</p>
                  <small>
                    {item.registration?.attended_at
                      ? "Attended"
                      : registrationMode === "hosted"
                        ? "You’re the organizer"
                        : "Registered"}
                  </small>
                </div>
                <Button
                  size='sm'
                  variant='outline'
                  onClick={() => {
                    if (registrationMode === "reminders") openReminder(item);
                    else {
                      setRegistrationsOpen(false);
                      setSelectedId(item.id);
                    }
                  }}
                >
                  {registrationMode === "reminders"
                    ? "Set Reminder"
                    : "View Details"}
                </Button>
              </article>
            ))}
            {!(registrationMode === "hosted"
              ? data?.hosted_events?.length
              : ownRegistrations.filter((item) =>
                  registrationMode === "attended"
                    ? !!item.registration?.attended_at
                    : registrationMode === "upcoming" ||
                        registrationMode === "reminders"
                      ? item.status === "published" &&
                        !item.registration?.attended_at &&
                        new Date(item.ends_at).getTime() > now
                      : true,
                ).length) && (
              <p className='events-empty-note'>No events in this view yet.</p>
            )}
          </div>
          {!!data?.suggestions.length && (
            <div className='event-suggestions-list'>
              <h3>Your Suggestions</h3>
              {data.suggestions.map((item) => (
                <p key={item.id}>{item.title}</p>
              ))}
            </div>
          )}
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!formMode}
        onOpenChange={(open) => {
          if (!open) setFormMode(null);
        }}
      >
        <DialogContent className='events-dialog'>
          <DialogHeader>
            <DialogTitle>
              {formMode === "create" ? "Create Event" : "Suggest an Event"}
            </DialogTitle>
            <DialogDescription>
              {formMode === "create"
                ? "Publish a community learning event. All times below are in Kampala (UTC+3)."
                : "Tell us about an event you would like to see. Suggestions are saved privately to your account."}
            </DialogDescription>
          </DialogHeader>
          <form
            className='events-form'
            onSubmit={(submit) => {
              submit.preventDefault();
              if (formMode === "suggest")
                suggest.mutate({
                  title: draft.title.trim(),
                  description: draft.description.trim(),
                  category: draft.category,
                });
              else
                create.mutate({
                  ...draft,
                  title: draft.title.trim(),
                  description: draft.description.trim(),
                  starts_at: new Date(`${draft.starts_at}+03:00`).toISOString(),
                  ends_at: new Date(`${draft.ends_at}+03:00`).toISOString(),
                });
            }}
          >
            <div>
              <Label htmlFor='event-title'>Event title</Label>
              <Input
                id='event-title'
                maxLength={160}
                value={draft.title}
                onChange={(change) =>
                  setDraft({ ...draft, title: change.target.value })
                }
                required
              />
            </div>
            <div>
              <Label htmlFor='event-description'>Description</Label>
              <Textarea
                id='event-description'
                maxLength={2000}
                value={draft.description}
                onChange={(change) =>
                  setDraft({ ...draft, description: change.target.value })
                }
                required
              />
            </div>
            <div>
              <Label htmlFor='event-category'>Category</Label>
              <select
                id='event-category'
                value={draft.category}
                onChange={(change) =>
                  setDraft({
                    ...draft,
                    category: change.target.value as EventCategory,
                  })
                }
              >
                {Object.entries(categoryNames).map(([key, name]) => (
                  <option key={key} value={key}>
                    {name}
                  </option>
                ))}
              </select>
            </div>
            {formMode === "create" && (
              <>
                <div className='events-form-columns'>
                  <div>
                    <Label htmlFor='event-start'>Starts (Kampala)</Label>
                    <Input
                      id='event-start'
                      type='datetime-local'
                      value={draft.starts_at}
                      onChange={(change) =>
                        setDraft({ ...draft, starts_at: change.target.value })
                      }
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor='event-end'>Ends (Kampala)</Label>
                    <Input
                      id='event-end'
                      type='datetime-local'
                      value={draft.ends_at}
                      onChange={(change) =>
                        setDraft({ ...draft, ends_at: change.target.value })
                      }
                      required
                    />
                  </div>
                </div>
                <div>
                  <Label htmlFor='event-location'>
                    Location / online platform
                  </Label>
                  <Input
                    id='event-location'
                    maxLength={200}
                    placeholder='School hall or Online (Zoom)'
                    value={draft.location}
                    onChange={(change) =>
                      setDraft({ ...draft, location: change.target.value })
                    }
                    required
                  />
                </div>
                <div className='events-form-columns'>
                  <div>
                    <Label htmlFor='event-link'>Meeting link (optional)</Label>
                    <Input
                      id='event-link'
                      type='url'
                      pattern='https?://.+'
                      maxLength={2048}
                      placeholder='https://…'
                      value={draft.meeting_url}
                      onChange={(change) =>
                        setDraft({ ...draft, meeting_url: change.target.value })
                      }
                    />
                  </div>
                  <div>
                    <Label htmlFor='event-capacity'>Places (optional)</Label>
                    <Input
                      id='event-capacity'
                      type='number'
                      min={1}
                      max={5000}
                      step={1}
                      value={draft.capacity ?? ""}
                      onChange={(change) =>
                        setDraft({
                          ...draft,
                          capacity: change.target.value
                            ? Number(change.target.value)
                            : null,
                        })
                      }
                    />
                  </div>
                </div>
              </>
            )}
            <Button
              type='submit'
              disabled={
                create.isPending ||
                suggest.isPending ||
                !draft.title.trim() ||
                !draft.description.trim()
              }
            >
              {create.isPending || suggest.isPending
                ? "Saving…"
                : formMode === "create"
                  ? "Publish Event"
                  : "Save Suggestion"}
            </Button>
          </form>
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!reminderTarget}
        onOpenChange={(open) => {
          if (!open) setReminderTarget(null);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Event Reminder</DialogTitle>
            <DialogDescription>
              Save your reminder choice, then open the downloaded file in your
              calendar.
            </DialogDescription>
          </DialogHeader>
          <div className='events-form'>
            <h3>{reminderTarget?.title}</h3>
            <Label htmlFor='event-reminder'>Remind me</Label>
            <select
              id='event-reminder'
              value={reminderMinutes}
              onChange={(change) =>
                setReminderMinutes(Number(change.target.value))
              }
            >
              {[
                [0, "No reminder"],
                [15, "15 minutes before"],
                [30, "30 minutes before"],
                [60, "1 hour before"],
                [1440, "1 day before"],
              ].map(([minutes, label]) => (
                <option key={minutes} value={minutes}>
                  {label}
                </option>
              ))}
            </select>
            <Button onClick={saveReminderAndDownload} disabled={downloading}>
              {downloading ? "Preparing…" : "Save & Download Calendar"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
      <AlertDialog
        open={!!cancelTarget}
        onOpenChange={(open) => {
          if (!open) setCancelTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Cancel your registration?</AlertDialogTitle>
            <AlertDialogDescription>
              Your place in “{cancelTarget?.title}” will be released.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep Registration</AlertDialogCancel>
            <AlertDialogAction
              disabled={cancel.isPending}
              onClick={(click) => {
                click.preventDefault();
                if (cancelTarget) cancel.mutate(cancelTarget.id);
              }}
            >
              {cancel.isPending ? "Cancelling…" : "Cancel Registration"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </MenteeWorkspace>
  );
}
