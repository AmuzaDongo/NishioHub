import api from './axios';
export const programStages = { primary: 'Primary School', secondary: 'Secondary School', university: 'University & College', career: 'Early Career', professionals: 'Professionals & Leaders' };
export const programThemes = { career_guidance: 'Career Guidance', academic_support: 'Academic Support', digital_skills: 'Digital & Tech Skills', entrepreneurship: 'Entrepreneurship', leadership: 'Leadership & Life Skills', wellbeing: 'Wellbeing & Mindset', industry_exposure: 'Industry Exposure', innovation: 'Innovation & Projects' };
export interface ProgramDiscovery { audience_stages: string[]; themes: string[]; featured: boolean }
export interface PublicProgram extends ProgramDiscovery {
  id: number; title: string; description: string; image: string | null; category: string | null;
  starts_on: string | null; ends_on: string | null; mode: 'online' | 'in_person' | 'hybrid'; target_audience: string;
  objectives: string[]; registration_starts_on: string | null; registration_ends_on: string | null;
}
export const getPublicPrograms = async (params: { q: string; stage: string; theme: string; page: number; featured: boolean; per_page: number }) =>
  (await api.get<{ items: PublicProgram[]; meta: { page: number; total: number; total_pages: number } }>('/platform/programs', { params })).data;
export interface ProgramPublicDetails {
  benefits: string[]; curriculum: {title:string;description:string;image_url?:string}[];
  requirements: string[]; faqs: {question:string;answer:string}[]; schedule: {title:string;description:string}[];
  duration_label:string; cost_label:string; certificate_label:string; intro_video_url:string;
}
export const emptyProgramPublicDetails: ProgramPublicDetails = {benefits:[],curriculum:[],requirements:[],faqs:[],schedule:[],duration_label:'',cost_label:'',certificate_label:'',intro_video_url:''};
export interface PublicProgramDetail extends PublicProgram {
  public_details: ProgramPublicDetails;
  mentors: {id:number;name:string;title:string;avatar:string|null}[];
  availability: {status:'open'|'upcoming'|'closed'|'full'|'ended';label:string};
}
export const getPublicProgram = async (id: number) => (await api.get<PublicProgramDetail>(`/platform/programs/${id}`)).data;
export const inquireAboutProgram = async (id: number, inquiry: { name: string; email: string; message: string; submission_key: string; interest_type?: 'individual' | 'school' }) =>
  (await api.post<{ reference: string }>(`/platform/programs/${id}/inquiries`, { inquiry })).data;
