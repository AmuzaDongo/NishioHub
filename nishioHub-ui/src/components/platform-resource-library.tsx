import {Link} from 'react-router-dom';
import api from '@/lib/axios';
import { useState } from 'react';
import { BookOpen, Download, ExternalLink } from 'lucide-react';
import { toast } from 'sonner';
import { downloadPlatformResource } from '@/lib/admin-dashboard-api';
import { saveDownload } from '@/lib/achievements-api';
import type { SharedLearningResource } from '@/lib/learning-area-api';

export function PlatformResourceLibrary({ resources }: { resources: SharedLearningResource[] }) {
  const [downloading, setDownloading] = useState<number | null>(null);
  const download = async (resource: SharedLearningResource) => {
    if (!resource.download_path || !resource.filename) return;
    setDownloading(resource.id);
    try { saveDownload(await downloadPlatformResource(resource.download_path), resource.filename); }
    catch { toast.error('Could not download this resource. Please try again.'); }
    finally { setDownloading(null); }
  };
  if (!resources.length) return null;
  return <section className="learning-panel"><div className="learning-panel-heading"><h2><BookOpen />Shared Learning Resources</h2></div><div className="learning-shared-resources">{resources.map(resource => <article key={resource.id}><h3>{resource.title}</h3>{resource.program && <small>{resource.program}</small>}<p>{resource.description}</p><div><Link className="learning-outline-button" to={`/learning/resources/${resource.id}`}><BookOpen size={15}/>Resource Details</Link>{resource.url && <a className="learning-outline-button" href={resource.url} onClick={() => { void api.post(`/learning/resources/${resource.id}/access`).catch(() => undefined); }} target="_blank" rel="noopener noreferrer"><ExternalLink size={15} />Open Resource</a>}{resource.download_path && <button className="learning-outline-button" disabled={downloading !== null} onClick={() => download(resource)}><Download size={15} />{downloading === resource.id ? 'Downloading…' : resource.filename}</button>}</div></article>)}</div></section>;
}
