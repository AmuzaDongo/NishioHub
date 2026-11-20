import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { getPublicEvents } from '@/lib/system-settings-api';
import { assetUrl, platformDate, usePlatform } from '@/lib/platform-context';
export function PublicEvents() {
  const platform = usePlatform();
  const query = useQuery({ queryKey: ['public-events'], queryFn: getPublicEvents, enabled: platform.public_events_enabled, refetchInterval: 60000 });
  if (!platform.public_events_enabled || !query.data?.length) return null;
  return <section className="container py-12"><h2 className="text-2xl font-bold mb-6">Upcoming Events</h2><div className="grid md:grid-cols-3 gap-5">{query.data.map(event => <article className="rounded-xl border bg-white overflow-hidden" key={event.id}><img src={event.image.startsWith("/images/") ? event.image : assetUrl(event.image)} alt="" className="w-full h-40 object-cover" /><div className="p-5"><h3 className="font-bold">{event.title}</h3><p className="text-sm my-3">{platformDate(event.starts_at, platform, true)} · {event.location}</p><p className="text-sm text-muted-foreground line-clamp-3 mb-4">{event.description}</p><Link to={`/community-events?event=${event.id}`} className="text-violet-700 font-medium">View event →</Link></div></article>)}</div></section>;
}
