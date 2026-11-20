import { useEffect, useState, type ReactNode } from "react";
import { Link, useLocation } from "react-router-dom";
import {
  ArrowRight,
  ChevronDown,
  Copy,
  Facebook,
  Linkedin,
  Mail,
  Megaphone,
  Menu,
  Search,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { useAuth } from "@/lib/auth-context";
import { assetUrl, usePlatform } from "@/lib/platform-context";
import { hasRole, isPlatformAdmin } from "@/lib/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
const button =
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg border border-violet-600 bg-gradient-to-b from-violet-600 to-violet-800 px-5 py-2.5 text-sm font-bold text-white shadow-sm transition hover:brightness-110 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-violet-700";
export function HomeAction({
  to,
  children,
  outline = false,
  className = "",
}: {
  to: string;
  children: ReactNode;
  outline?: boolean;
  className?: string;
}) {
  return (
    <Link
      to={to}
      className={`${button} ${outline ? "!bg-none !bg-white !text-violet-900" : ""} ${className}`}
    >
      {children}
    </Link>
  );
}
export function Header({
  children,
  announcement = true,
  showFooter = true,
  onSearch,
  searchLabel = "Search events",
  authReturnTo,
  getStartedLabel = "Get Started",
}: {
  children?: ReactNode;
  announcement?: boolean;
  showFooter?: boolean;
  onSearch?: () => void;
  searchLabel?: string;
  authReturnTo?: string;
  getStartedLabel?: string;
}) {
  const platform = usePlatform();
  const { user, logout } = useAuth();
  const { pathname, hash } = useLocation();
  const [open, setOpen] = useState(false);
  const [banner, setBanner] = useState(() => {
    try {
      return sessionStorage.getItem("nishiohub-welcome-hidden") !== "yes";
    } catch {
      return true;
    }
  });
  useEffect(() => {
    setOpen(false);
    requestAnimationFrame(() => {
      if (hash)
        document
          .getElementById(hash.slice(1))
          ?.scrollIntoView({ block: "start" });
      else window.scrollTo({ top: 0, behavior: "auto" });
    });
  }, [pathname, hash]);
  const account = isPlatformAdmin(user)
    ? "/admin"
    : hasRole(user, "mentee")
      ? "/mentee/dashboard"
      : hasRole(user, "mentor")
        ? "/dashboard"
        : "/profile";
  const loginTo = authReturnTo
    ? `/login?return_to=${encodeURIComponent(authReturnTo)}`
    : "/login";
  const start = user
    ? account
    : platform.registration_enabled
      ? authReturnTo
        ? `/register?role=${["/mentor/application", "/host-an-event"].includes(authReturnTo) ? "mentor" : "mentee"}&return_to=${encodeURIComponent(authReturnTo)}`
        : "/register?role=mentee"
      : "/contact";
  const mentorJoin = "/become-a-mentor";
  const groups = [
    {
      name: "Find Mentors",
      to: "/services",
      links: [
        ["Browse Mentors", "/services"],
        ["Become a Mentor", mentorJoin],
        ["Explore Expertise", "/categories"],
      ],
    },
    {
      name: "Programs",
      to: "/programs",
      links: [
        ["Explore Programs", "/programs"],
        ["How It Works", "/how-it-works"],
      ],
    },
    {
      name: "Learning",
      to: "/learn",
      links: [
        ["Learning Resources", "/learn"],
        ["My Learning", hasRole(user, "mentee") ? "/learning-area" : start],
        ["My Goals", hasRole(user, "mentee") ? "/my-goals" : start],
      ],
    },
    {
      name: "About",
      to: "/about",
      links: [
        ["About NishioHub", "/about"],
        ["Our Story", "/about#story"],
        ["Our Leadership", "/about?view=team"],
        ["How It Works", "/how-it-works"],
        ["Contact Us", "/contact"],
      ],
    },
    {
      name: "For Schools",
      to: "/#schools",
      links: [
        ["Schools & Organizations", "/#schools"],
        ["Partner With Us", "/partner-with-us"],
        ["Host an Event", "/host-an-event"],
      ],
    },
  ];
  const logo = assetUrl(platform.logo_url) || "/assets/learning-logo.svg";
  const shareUrl =
    typeof window === "undefined" ? "" : `${window.location.origin}/`;
  const footerGroups = [
    {
      title: "Platform",
      links: [
        ["Find Mentors", "/services"],
        ["Programs", "/programs"],
        ["Learning Resources", "/learn"],
        ["Events", "/community-events"],
        ["Achievements", hasRole(user, "mentee") ? "/my-achievements" : start],
      ],
    },
    {
      title: "For You",
      links: [
        ["Primary School", "/#primary"],
        ["Secondary School", "/#secondary"],
        ["University & College", "/#university"],
        ["Early Career", "/#career"],
        ["Professionals & Founders", "/#professionals"],
      ],
    },
    {
      title: "For Organizations",
      links: [
        ["For Schools", "/#schools"],
        ["For Companies", "/partner-with-us"],
        ["Partnerships", "/partner-with-us"],
        ["Become a Mentor", mentorJoin],
      ],
    },
    {
      title: "Support",
      links: [
        ["Help Centre", "/help"],
        ["Safety & Child Protection", "/contact?category=support"],
        ["Community Support", "/contact?category=support"],
        ["Privacy Policy", "/privacy-policy"],
        ["Terms of Service", "/terms-of-service"],
      ],
    },
  ];
  return (
    <div className='contents font-sans text-[#160c2e]'>
      {announcement && banner && (
        <div className='relative bg-gradient-to-r from-[#391264] via-violet-700 to-[#5c1b8b] px-10 py-1.5 text-center text-[11px] text-white'>
          <Megaphone size={13} className='mr-2 inline text-yellow-300' />
          Welcome to {platform.platform_name} — a safe, inclusive mentorship
          platform for learners, students, young professionals and leaders.
          <button
            aria-label='Dismiss welcome message'
            className='absolute right-3 top-1/2 -translate-y-1/2 rounded p-1 hover:bg-white/20'
            onClick={() => {
              setBanner(false);
              try {
                sessionStorage.setItem("nishiohub-welcome-hidden", "yes");
              } catch {
                /* Storage may be disabled. */
              }
            }}
          >
            <X size={15} />
          </button>
        </div>
      )}
      <header className='sticky top-0 z-40 border-b border-violet-100 bg-white/95 backdrop-blur'>
        <div className='mx-auto flex max-w-[1440px] items-center justify-between gap-4 px-5 py-3 lg:px-6 xl:px-10'>
          <Link to='/' aria-label={`${platform.platform_name} home`}>
            <img
              src={logo}
              alt={platform.platform_name}
              className='h-11 w-36 object-contain xl:w-40 object-left'
            />
          </Link>
          <nav
            aria-label='Main navigation'
            className='hidden items-center gap-3 text-xs font-bold lg:flex xl:gap-5'
          >
            <Link
              className={`py-2 ${pathname === "/" ? "border-b-2 border-violet-700 text-violet-700" : ""}`}
              to='/'
            >
              Home
            </Link>
            {groups.map((group, i) => (
              <span key={group.name} className='contents'>
                {i === 3 && (
                  <Link
                    aria-current={
                      pathname === "/community-events" ? "page" : undefined
                    }
                    className={`py-2 hover:text-violet-700 ${pathname === "/community-events" ? "border-b-2 border-violet-700 text-violet-700" : ""}`}
                    to='/community-events'
                  >
                    Events
                  </Link>
                )}
                <DropdownMenu>
                  <DropdownMenuTrigger
                    className={`flex items-center gap-1 whitespace-nowrap py-2 hover:text-violet-700 ${pathname === group.to ? "border-b-2 border-violet-700 text-violet-700" : ""}`}
                  >
                    {group.name}
                    <ChevronDown size={13} />
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align='start'>
                    {group.links.map(([label, to]) => (
                      <DropdownMenuItem key={label} asChild>
                        <Link to={to}>{label}</Link>
                      </DropdownMenuItem>
                    ))}
                  </DropdownMenuContent>
                </DropdownMenu>
              </span>
            ))}
          </nav>
          {onSearch && (
            <button
              aria-label={searchLabel}
              onClick={onSearch}
              className='ml-auto rounded-lg p-2 text-violet-700 hover:bg-violet-50'
            >
              <Search size={22} />
            </button>
          )}
          <div className='hidden items-center gap-3 lg:flex'>
            {user ? (
              <>
                <HomeAction to={account}>
                  My Account <ArrowRight size={15} />
                </HomeAction>
                <button
                  className='text-xs font-bold text-violet-800'
                  onClick={logout}
                >
                  Log Out
                </button>
              </>
            ) : (
              <>
                <HomeAction
                  to={loginTo}
                  outline
                  className='!px-4 !py-2 !text-xs'
                >
                  Log In
                </HomeAction>
                <HomeAction to={start} className='!px-4 !py-2 !text-xs'>
                  {platform.registration_enabled
                    ? getStartedLabel
                    : "Contact Us"}
                </HomeAction>
              </>
            )}
          </div>
          <button
            className='rounded-lg border border-violet-200 p-2 text-violet-700 lg:hidden'
            aria-label='Toggle menu'
            aria-expanded={open}
            aria-controls='public-mobile-menu'
            onClick={() => setOpen(!open)}
          >
            {open ? <X /> : <Menu />}
          </button>
        </div>
        {open && (
          <nav
            id='public-mobile-menu'
            aria-label='Mobile navigation'
            className='max-h-[75vh] overflow-y-auto border-t border-violet-100 bg-white p-5 lg:hidden'
          >
            <Link
              className='block py-2 font-bold'
              to='/'
              onClick={() => setOpen(false)}
            >
              Home
            </Link>
            {groups.map((group) => (
              <div key={group.name} className='border-t border-violet-50 py-2'>
                <p className='text-xs font-bold uppercase tracking-wider text-violet-700'>
                  {group.name}
                </p>
                {group.links.map(([label, to]) => (
                  <Link
                    key={label}
                    to={to}
                    className='block py-2 text-sm'
                    onClick={() => setOpen(false)}
                  >
                    {label}
                  </Link>
                ))}
              </div>
            ))}
            <Link
              className='block py-2 font-bold'
              to='/community-events'
              onClick={() => setOpen(false)}
            >
              Events
            </Link>
            <div className='mt-3 flex gap-3'>
              <HomeAction to={user ? account : loginTo} outline>
                {user ? "My Account" : "Log In"}
              </HomeAction>
              <HomeAction to={start}>
                {user ? "Dashboard" : getStartedLabel}
              </HomeAction>
            </div>
          </nav>
        )}
      </header>
    </div>
  );
}
