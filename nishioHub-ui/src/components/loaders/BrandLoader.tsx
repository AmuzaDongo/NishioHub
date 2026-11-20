export function BrandLoader({ logo = '/assets/learning-logo.svg', tagline = 'Discover. Learn. Grow.' }: { logo?: string; tagline?: string }) {
  return <div role="status" aria-label="Starting NishioHub" className="grid min-h-screen place-items-center bg-white text-violet-950"><div className="text-center"><img src={logo} alt="NishioHub" className="mx-auto h-20 max-w-[260px] motion-safe:animate-pulse"/><p className="mt-4 text-sm font-medium">{tagline}</p><span className="sr-only">Loading your platform…</span></div></div>;
}
