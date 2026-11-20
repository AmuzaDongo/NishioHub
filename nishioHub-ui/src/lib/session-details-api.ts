import api from './axios';
import type { AdminSession, SessionDetail, SessionDraft } from './admin-sessions-api';
import type { PageMeta } from './admin-programs-api';
export interface SessionAsset { id:number;kind:'material'|'recording';title:string;description:string|null;url:string|null;file:{filename:string;type:string;size:number}|null;created_at:string;lock_version:number;views:number;downloads:number;active?:boolean }
export interface SessionFeedback {id:string;user_id:number;author:string;rating:number;comment:string;created_at:string}
export interface SessionNote {id:number;body:string;author:string;created_at:string;updated_at:string;lock_version:number}
export interface SessionAudit {id:number;action:string;actor:string;created_at:string}
export interface SessionOverview extends AdminSession {objectives:string[];tags:string[];cover:string|null;registration_opens_at:string|null;registration_closes_at:string|null;feedback_opens_at:string|null;feedback_closes_at:string|null;capabilities:{manage:boolean;schedule:boolean};summary:{rating:number|null;feedback_count:number;highlights:SessionFeedback[];recording_views:number;material_downloads:number;engaged_learners:number;materials:number;recordings:number;recording_available_at:string|null;absent:number;unrecorded:number}}
export type SectionItem = SessionAsset | SessionFeedback | SessionNote | SessionAudit;
export const getSessionOverview=async(id:number)=>(await api.get<SessionOverview>(`/admin/sessions/${id}/details`)).data;
export const getSessionSection=async(id:number,section:string,page:number,q:string)=>(await api.get<{items:SectionItem[];meta:PageMeta}>(`/admin/sessions/${id}/sections/${section}`,{params:{page,q}})).data;
export const saveSessionOverview=async(id:number,details:Record<string,unknown>|FormData)=>(await api.patch<SessionOverview>(`/admin/sessions/${id}/details`,details instanceof FormData?details:{details})).data;
export const duplicateAdminSession=async(id:number,session:SessionDraft)=>(await api.post<AdminSession>(`/admin/sessions/${id}/duplicate`,{session})).data;
export async function addSessionAsset(id:number,asset:{kind:string;title:string;description:string;url:string;file:File|null}) {const body=new FormData();for(const [key,value] of Object.entries(asset))if(value!==null)body.append(`asset[${key}]`,value);return(await api.post<SessionAsset>(`/admin/sessions/${id}/assets`,body)).data;}
export const removeSessionAsset=(id:number,asset:SessionAsset)=>api.delete(`/admin/sessions/${id}/assets/${asset.id}`,{data:{lock_version:asset.lock_version}});
export const getAssetFile=async(id:number,asset:number,learner=false)=>(await api.get<Blob>(learner?`/bookings/${id}/session-assets/${asset}/file`:`/admin/sessions/${id}/assets/${asset}/file`,{responseType:'blob'})).data;
export const openAssetLink=async(id:number,asset:number,learner=false)=>(await api.post<{url:string}>(learner?`/bookings/${id}/session-assets/${asset}/access`:`/admin/sessions/${id}/assets/${asset}/access`)).data;
export const downloadSessionMaterials=async(id:number)=>(await api.get<Blob>(`/admin/sessions/${id}/materials-archive`,{responseType:'blob'})).data;
export const exportSessionAttendees=async(id:number)=>(await api.get<Blob>(`/admin/sessions/${id}/attendees-export`,{responseType:'blob'})).data;
export const saveSessionNote=(id:number,body:string,note:SessionNote|null)=>note?api.patch(`/admin/sessions/${id}/notes/${note.id}`,{note:{body,lock_version:note.lock_version}}):api.post(`/admin/sessions/${id}/notes`,{note:{body}});
export const removeSessionNote=(id:number,note:SessionNote)=>api.delete(`/admin/sessions/${id}/notes/${note.id}`,{data:{lock_version:note.lock_version}});
export const sendSessionFollowUp=async(id:number,message:string,request_key:string)=>(await api.post<{delivered:number;skipped:number}>(`/admin/sessions/${id}/follow-up`,{follow_up:{message,request_key}})).data;
export interface BookingContent {title:string;objectives:string[];tags:string[];assets:SessionAsset[];feedback:{rating:number;comment:string}|null;can_feedback:boolean}
export const getBookingContent=async(id:number)=>(await api.get<BookingContent>(`/bookings/${id}/session-content`)).data;
export const saveBookingFeedback=(id:number,rating:number,comment:string)=>api.put(`/bookings/${id}/session-feedback`,{feedback:{rating,comment}});
