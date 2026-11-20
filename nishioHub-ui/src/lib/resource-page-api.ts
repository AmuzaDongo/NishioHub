import api from './axios';
import type {PublicLearningResource} from './public-learning-api';
export interface ResourcePageDetails {topic:string;license_label:string;learning_outcomes:string[];takeaways:string[];audiences:string[];author_name:string;author_title:string;author_bio:string;author_photo_url:string;author_profile_url:string}
export const defaultResourcePage:ResourcePageDetails={topic:'',license_label:'',learning_outcomes:[],takeaways:[],audiences:[],author_name:'',author_title:'',author_bio:'',author_photo_url:'',author_profile_url:''};
export interface SupportingResource {id:number;title:string;has_file:boolean;has_link:boolean;file_type:string|null;size:number|null}
export interface PublicResourcePage extends PublicLearningResource {page_details:ResourcePageDetails;updated_at:string;comments_count:number;related:PublicLearningResource[];has_file:boolean;has_link:boolean;supporting_resources:SupportingResource[]}
export const getPublicResourcePage=async(id:number)=>(await api.get<PublicResourcePage>(`/platform/learning-resources/${id}`)).data;
export interface ResourceComment {id:number;display_name:string;body:string;created_at:string;status?:'pending'|'approved'|'rejected';lock_version?:number}
export const getResourceComments=async(id:number,page:number)=>(await api.get<{items:ResourceComment[];total:number;page:number}>(`/platform/learning-resources/${id}/comments`,{params:{page}})).data;
export const getMyResourceComments=async(id:number)=>(await api.get<{items:ResourceComment[]}>(`/learning/resources/${id}/comments/mine`)).data;
export const postResourceComment=async(id:number,comment:{display_name:string;body:string;submission_key:string})=>(await api.post<ResourceComment>(`/learning/resources/${id}/comments`,{comment})).data;
export const removeResourceComment=(id:number,commentId:number)=>api.delete(`/learning/resources/${id}/comments/${commentId}`);
export const getModerationComments=async(id:number,status:string,page:number)=>(await api.get<{items:ResourceComment[];total:number;page:number}>(`/admin/resources/${id}/comments`,{params:{status,page}})).data;
export const reviewResourceComment=(id:number,comment:ResourceComment,status:'approved'|'rejected')=>api.patch(`/admin/resources/${id}/comments/${comment.id}`,{review:{status,lock_version:comment.lock_version}});
export function resourcePageReturn(value:string|null){return /^\/learn\/[1-9]\d{0,11}$/.test(value||'')?value:null;}
export function submissionKey(){if(crypto.randomUUID)return crypto.randomUUID();const b=crypto.getRandomValues(new Uint8Array(16));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;const h=Array.from(b,x=>x.toString(16).padStart(2,'0')).join('');return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;}
