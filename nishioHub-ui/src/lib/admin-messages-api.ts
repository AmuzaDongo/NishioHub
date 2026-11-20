import api from './axios';
import type { ChatConversation, ChatPerson, ChatMessage } from './messages-api';
import type { PageMeta } from './admin-programs-api';
export interface AdminConversation extends ChatConversation { starred:boolean; archived:boolean; muted:boolean; blocked:boolean; can_send:boolean; lock_version:number; meeting_url:string|null; cohort:string|null; program:{id:number;title:string}|null; about:{email:string;phone:string|null;location:string|null;program:{id:number;title:string}|null;cohort:string|null}|null; capabilities:{manage:boolean} }
export interface AdminInbox { conversations:AdminConversation[]; counts:Record<string,number>;meta:PageMeta;capabilities:{manage:boolean} }
export interface MessagePreferences {notify_messages:boolean;send_read_receipts:boolean;enter_to_send:boolean;lock_version:number}
export const getAdminInbox=async(page:number,tab:string,q:string)=>(await api.get<AdminInbox>('/admin/messages',{params:{page,tab,q}})).data;
export const getAdminConversation=async(id:string)=>(await api.get<AdminConversation>(`/admin/messages/${id}`)).data;
export const getAdminChatContacts=async(q:string,page:number,role:string,program_id:number|null)=>(await api.get<{people:ChatPerson[];meta:PageMeta}>('/admin/messages/contacts',{params:{q,page,role,program_id}})).data;
export const composeAdminConversation=async(participant_ids:number[],kind:'direct'|'group',title:string,program_id:number|null,cohort_label:string)=>(await api.post<AdminConversation>('/admin/messages',{participant_ids,kind,title,program_id,cohort_label})).data;
export const updateAdminInboxState=async(record:AdminConversation,state:{starred?:boolean;archived?:boolean;muted?:boolean;deleted?:boolean})=>{await api.patch(`/admin/messages/${record.id}/state`,{state,lock_version:record.lock_version})};
export const blockAdminChatContact=async(record:AdminConversation)=>{await api.patch(`/admin/messages/${record.id}/block`,{blocked:!record.blocked})};
export const getAdminSharedContent=async(id:string,page:number)=>(await api.get<{items:ChatMessage[];meta:PageMeta}>(`/admin/messages/${id}/content`,{params:{page}})).data;
export const getMessagePreferences=async()=>(await api.get<MessagePreferences>('/admin/messages/preferences')).data;
export const saveMessagePreferences=async(preferences:MessagePreferences)=>(await api.patch<MessagePreferences>('/admin/messages/preferences',{preferences})).data;
export const sendAdminBroadcast=async(recipient_ids:number[],title:string,content:string,client_nonce:string)=>(await api.post<{id:number;delivered:number;conversation_ids:number[]}>('/admin/messages/broadcast',{recipient_ids,title,content,client_nonce})).data;
