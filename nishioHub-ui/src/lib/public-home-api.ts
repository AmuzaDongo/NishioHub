import api from './axios';
import type { PartnershipDetails } from './partnership-api';
import type { EventHostingDetails } from './event-hosting-api';
export interface HomeMentor {id:number;name:string;title:string;skills:string[];verified:boolean;avatar:string|null}
export interface PublicItem {id:number|string;title:string;description?:string;image?:string;category?:string;starts_at?:string;ends_at?:string;location?:string;starts_on?:string|null;ends_on?:string|null;mode?:string;target_audience?:string|null;objectives?:string[];level?:string;lessons?:number}
export type CatalogKind='programs'|'learning'|'events';
export const getPublicHome=async()=>(await api.get<{mentors:HomeMentor[];events:PublicItem[]}>('/platform/home')).data;
export const getPublicCatalog=async(kind:CatalogKind,q:string,page:number)=>(await api.get<{items:PublicItem[];meta:{page:number;total:number;total_pages:number};enabled:boolean}>('/platform/catalog',{params:{kind,q,page}})).data;
export const submitPublicInquiry=async(inquiry:{name:string;email:string;subject:string;category:string;message:string})=>(await api.post<{reference:string;detail:string}>('/platform/inquiries',{inquiry})).data;
export interface PublicInquiry {id:number;reference:string;name:string;email:string;subject:string;category:string;message:string;reviewed:boolean;created_at:string;event_details?:EventHostingDetails;partnership_details?:PartnershipDetails;program_details?:{id:number;title:string;interest_type?:'individual'|'school'};status:'pending'|'approved'|'rejected'|'changes_requested';review_note:string;reviewed_at:string|null;reviewed_by:string|null;lock_version:number;requester_id:number|null;event_id:number|null;event:{id:number;title:string;status:'draft'|'published'|'cancelled';starts_at:string;ends_at:string;location:string;format:string}|null}
export const getPublicInquiries=async(page:number)=>(await api.get<{items:PublicInquiry[];total:number}>('/admin/inquiries',{params:{page}})).data;
export const reviewPublicInquiry=async(id:number,reviewed:boolean)=>{await api.patch(`/admin/inquiries/${id}`,{reviewed})};
