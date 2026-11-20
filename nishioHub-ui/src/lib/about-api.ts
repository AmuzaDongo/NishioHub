import api from './axios';
export interface AboutTeamMember { name: string; title: string; bio: string; photo_url: string }
export interface AboutTeamDraft extends AboutTeamMember { published: boolean }
export interface PublicAbout {
  impact: { learners: number; mentors: number; resources: number; events: number; organizations: number };
  story_video_url: string | null; team: AboutTeamMember[];
}
export const getPublicAbout = async () => (await api.get<PublicAbout>('/platform/about')).data;
