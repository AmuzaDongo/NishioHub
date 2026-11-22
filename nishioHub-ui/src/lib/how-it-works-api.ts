import api from './axios';
export interface HowItWorksContent {
 heading:string;description:string;hero_image:string;overview_video_url:string;overview_seconds:number;
 steps:{title:string;description:string}[];
 audiences:{id:'learners'|'mentors'|'schools'|'organizations';title:string;image:string;points:string[]}[];
}
export const getHowItWorks=async()=>(await api.get<HowItWorksContent>('/platform/how-it-works')).data;
