import { type ReactNode } from "react";
import { Link } from "react-router-dom";
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
