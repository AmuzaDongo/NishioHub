import api from './axios';
import { eventDownload, type AdminEvent } from './admin-events-api';
import type { PageMeta } from './admin-programs-api';
export interface AgendaItem {id:number;title:string;description:string|null;starts_at:string;ends_at:string;lock_version:number}
export interface EventSpeaker {role?:string;id:number;name:string;title:string|null;bio:string|null;avatar_url:string|null;lock_version:number}
export interface EventMaterial {id:number;title:string;description:string|null;url:string|null;lock_version:number;file:{filename:string;type:string;size:number}|null}
export interface EventFeedback {id:number;author:string;rating:number;comment:string|null;created_at:string}
export interface EventSummary {registered:number;attended:number;no_show:number;unrecorded:number;cancelled:number;attendance_rate:number|null;rating:number|null;feedback_count:number;ratings:{rating:number;count:number}[];materials:number;speakers:number;agenda_count:number;agenda:AgendaItem[];trend:{at:string;registrations:number}[];growth:number|null}
export interface EventOverview extends AdminEvent {upload_limit_mb:number;summary:EventSummary;capabilities:{manage:boolean}}
export type EventSection='agenda'|'speakers'|'materials'|'feedback';
export type EventItem=AgendaItem|EventSpeaker|EventMaterial|EventFeedback;
export const getEventOverview=async(id:number)=>(await api.get<EventOverview>(`/admin/events/${id}/details`)).data;
export const getEventSection=async(id:number,section:EventSection,page:number,q:string)=>(await api.get<{items:EventItem[];meta:PageMeta}>(`/admin/events/${id}/sections/${section}`,{params:{page,q}})).data;
export const saveEventItem=async(id:number,section:string,item:Record<string,string|number|File>,itemId?:number)=>{const body=new FormData();Object.entries(item).forEach(([k,v])=>{if(v!==null&&v!==undefined)body.append(`item[${k}]`,v instanceof File?v:String(v))});await api.request({url:`/admin/events/${id}/sections/${section}${itemId?`/${itemId}`:''}`,method:itemId?'patch':'post',data:body})};
export const removeEventItem=async(id:number,section:string,item:{id:number;lock_version:number})=>{await api.delete(`/admin/events/${id}/sections/${section}/${item.id}`,{params:{lock_version:item.lock_version}})};
export const duplicateEvent=async(id:number,event:{title:string;starts_at:string;ends_at:string;lock_version:number})=>(await api.post<{id:number}>(`/admin/events/${id}/duplicate`,{event})).data;
export const deleteEvent=async(id:number,lock_version:number)=>{await api.delete(`/admin/events/${id}`,{params:{lock_version}})};
export const sendEventAnnouncement=async(id:number,message:string,request_key:string)=>(await api.post<{delivered:number;skipped:number}>(`/admin/events/${id}/announcement`,{announcement:{message,request_key}})).data;
export const downloadEventReport=(id:number)=>eventDownload(`/admin/events/${id}/report`);
export const getEventMaterial=(id:number,itemId:number)=>eventDownload(`/admin/events/${id}/materials/${itemId}/file`);
export interface LearnerEventContent {agenda:AgendaItem[];speakers:EventSpeaker[];materials:EventMaterial[];feedback:{rating:number;comment:string;lock_version:number}|null;can_feedback:boolean}
export const getLearnerEventContent=async(id:number)=>(await api.get<LearnerEventContent>(`/events/${id}/details`)).data;
export const saveEventFeedback=async(id:number,feedback:{rating:number;comment:string;lock_version?:number})=>(await api.put(`/events/${id}/feedback`,{feedback})).data;
