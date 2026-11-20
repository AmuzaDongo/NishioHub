import { ReactNode } from "react";
import { Header } from "./header";
import { Footer } from "./footer";

interface MainLayoutProps {
  children: ReactNode;
  announcement?: boolean;
  onSearch?: () => void;
  searchLabel?: string;
}

export function MainLayout({ children, announcement = true, onSearch, searchLabel }: MainLayoutProps) {
  return (
    <div className="flex min-h-screen flex-col">
      <Header announcement={announcement} onSearch={onSearch} searchLabel={searchLabel} />
      <main className="flex-1">
        {children}
      </main>
      <Footer />
    </div>
  );
}