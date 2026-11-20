import api from './axios';
export const libraryCategories={academic:'Academic Learning',digital:'Digital Skills',career:'Career & Life Skills',entrepreneurship:'Entrepreneurship',mentorship:'Mentorship Guides',teaching:'Teaching Resources',exams:'Exam Preparation',research:'Research & Innovation',general:'Other Resources'};
export const libraryPaths={primary:'Primary Learners',secondary:'Secondary Learners',university:'University Students',career:'Young Professionals',entrepreneurs:'Entrepreneurs'};
export const libraryFormats={study_material:'Study Materials',video:'Video Lessons',toolkit:'Toolkits',career_guide:'Career Guides',learning_path:'Learning Paths',other:'Other Resources'};
export interface LibraryDetails {category:string;learning_paths:string[];format:string;level:string;page_count:number|null;featured:boolean}
export const defaultLibraryDetails:LibraryDetails={category:'general',learning_paths:[],format:'auto',level:'all',page_count:null,featured:false};
export interface PublicLearningResource {id:number;title:string;description:string;resource_type:string;category:string;learning_paths:string[];format:string;level:string;page_count:number|null;featured:boolean;duration_seconds:number|null;thumbnail:string|null;file_type:string|null;accesses:number;downloads:number;language:string;target_audience:string|null;published_at:string|null}
export interface LibraryFilters {q:string;category:string;path:string;format:string;sort:string;page:number;per_page:number;saved:boolean;featured:boolean}
export interface PublicLibrary {items:PublicLearningResource[];recent:PublicLearningResource[];popular:PublicLearningResource[];categories:Record<string,number>;total:number;meta:{page:number;total:number;total_pages:number}}
export const getPublicLibrary=async(params:LibraryFilters)=>(await api.get<PublicLibrary>('/platform/learning-resources',{params})).data;
export const getPublicLearningResource=async(id:number)=>(await api.get<PublicLearningResource>(`/platform/learning-resources/${id}`)).data;
export const getResourceBookmarks=async()=>(await api.get<{resource_ids:number[]}>('/me/resource-bookmarks')).data;
export const setResourceBookmark=async(id:number,saved:boolean)=>saved?api.put(`/me/resource-bookmarks/${id}`):api.delete(`/me/resource-bookmarks/${id}`);
export function libraryReturn(value:string|null){return value==='/learn'||value==='/learn?saved=true'||/^\/learn\?resource=[1-9]\d{0,11}$/.test(value||'')?value:null;}
