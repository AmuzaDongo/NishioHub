import api from './axios';
export type PublicEventTab='upcoming'|'live'|'past'|'featured';
export interface PublicEventFilters {tab:PublicEventTab;types:string[];audiences:string[];mode:string;date_range:string;from:string;to:string;q:string;page:number}
export interface PublicEvent {id:number;title:string;description:string;type:string;event_type:string;starts_at:string;ends_at:string;format:string;location:string;display_status:string;image:string;target_audiences:string[];featured:boolean;available_places:number|null;capacity:number|null;can_register:boolean;registered:boolean;can_cancel:boolean;reminder_minutes:number|null;meeting_url:string|null;recording_url:string|null;organizer:string}
export interface PublicEventsData {items:PublicEvent[];meta:{page:number;total:number;per_page:number;total_pages:number};facets:{total:number;types:{key:string;label:string;count:number}[];audiences:{key:string;label:string;count:number}[]};enabled:boolean;registration_enabled:boolean;timezone:string;can_create:boolean}
export const getPublicEventsDiscovery=async(filters:PublicEventFilters)=>(await api.get<PublicEventsData>('/platform/events/discover',{params:filters})).data;
export const getPublicEvent=async(id:number)=>(await api.get<PublicEvent>(`/platform/events/discover/${id}`)).data;
// Only the event page is allowed as a post-authentication return destination.
export function publicEventReturn(value:string|null){return value&&(/^\/community-events\?event=[1-9]\d*$/.test(value)||/^\/community-events\/[1-9]\d*$/.test(value))?value:null}

export interface PublicEventDetails extends PublicEvent {
 timezone: string; objectives: string[]; faqs: {question:string;answer:string}[];
 agenda: {id:number;title:string;description:string|null;starts_at:string;ends_at:string}[];
 speakers: {id:number;name:string;title:string|null;bio:string|null;avatar_url:string|null;role:string}[];
 resources_locked: boolean; materials_count: number;
 materials: {id:number;title:string;description:string|null;url:string|null;file:{filename:string;type:string;size:number}|null}[];
 related_events: PublicEvent[];
}
export const getPublicEventDetails = async(id:number) => (await api.get<PublicEventDetails>(`/platform/events/discover/${id}`)).data;
export const getPublicEventCalendar = async(id:number) => (await api.get<Blob>(`/platform/events/discover/${id}/calendar`,{responseType:'blob'})).data;
export const downloadPublicEventMaterial = async(id:number,materialId:number) => (await api.get<Blob>(`/events/${id}/materials/${materialId}/file`,{responseType:'blob'})).data;
