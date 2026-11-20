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
export function Footer({
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
    <>
      {showFooter && (
        <footer className='bg-gradient-to-r from-[#2c0e48] to-[#311152] px-6 py-6 text-white lg:px-10'>
          <div className='mx-auto grid max-w-[1360px] gap-6 sm:grid-cols-3 lg:grid-cols-[1.5fr_repeat(4,1fr)_1.2fr]'>
            <div>
              <Link to='/' aria-label={`${platform.platform_name} home`}>
                <img
                  src={logo}
                  alt={platform.platform_name}
                  className='mb-2 h-9 w-36 rounded bg-white/95 p-1 object-contain'
                />
              </Link>
              <p className='max-w-56 text-[10px] leading-relaxed'>
                A mentorship platform for learners, students, young
                professionals and leaders—building skills, confidence and
                opportunities for a brighter future.
              </p>
            </div>
            {footerGroups.map((group) => (
              <nav key={group.title} aria-label={group.title}>
                <h2 className='mb-2 text-xs font-bold'>{group.title}</h2>
                <ul className='space-y-1 text-[10px]'>
                  {group.links.map(([label, to]) => (
                    <li key={label}>
                      <Link className='hover:underline' to={to}>
                        {label}
                      </Link>
                    </li>
                  ))}
                </ul>
              </nav>
            ))}
            <div>
              <h2 className='mb-3 text-xs font-bold'>Stay Connected</h2>
              <div className='mb-3 flex gap-3'>
                <a
                  aria-label='Share on X'
                  target='_blank'
                  rel='noreferrer'
                  href={`https://twitter.com/intent/tweet?url=${encodeURIComponent(shareUrl)}`}
                >
                  <X size={18} />
                </a>
                <a
                  aria-label='Share on LinkedIn'
                  target='_blank'
                  rel='noreferrer'
                  href={`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(shareUrl)}`}
                >
                  <Linkedin size={18} />
                </a>
                <a
                  aria-label='Share on Facebook'
                  target='_blank'
                  rel='noreferrer'
                  href={`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`}
                >
                  <Facebook size={18} />
                </a>
                <button
                  aria-label='Copy homepage link'
                  onClick={async () => {
                    try {
                      await navigator.clipboard.writeText(shareUrl);
                      toast.success("Homepage link copied");
                    } catch {
                      toast.error(
                        "Could not copy the link. Copy the page address from your browser.",
                      );
                    }
                  }}
                >
                  <Copy size={17} />
                </button>
              </div>
              <a
                className='flex items-center gap-2 break-all text-[10px]'
                href={`mailto:${platform.support_email}`}
              >
                <Mail size={15} />
                {platform.support_email}
              </a>
            </div>
          </div>
        </footer>
      )}
    </>
  );
}
