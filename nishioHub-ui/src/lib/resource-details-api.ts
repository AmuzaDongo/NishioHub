import type {ResourcePageDetails} from './resource-page-api';
import type {LibraryDetails} from './public-learning-api';
import api from './axios';
import type {AdminResource,ResourceDraft} from './admin-resources-api';
import type {PageMeta} from './admin-programs-api';
export interface ResourceContent {id:number;title:string;body:string|null;url:string|null;position:number;start_seconds:number|null;lock_version:number;public_listing?:boolean;file?:{filename:string;type:string;size:number}|null}
export interface ResourceFeedback {id:number;author:string;rating:number;comment:string;created_at:string}
export interface ResourceVersion {id:number;number:number;actor:string;created_at:string;title:string;contents:number;file:string|null}
export interface ResourceAudit {id:number;action:string;actor:string;created_at:string}
export interface ResourceLearner {id:number;name:string;percent:number;completed_at:string|null;updated_at:string}
export interface ResourceOverview extends AdminResource {page_details:ResourcePageDetails;library_details:LibraryDetails;language:string;target_audience:string|null;module_name:string|null;position:number|null;required:boolean;awards:string|null;duration_seconds:number|null;visibility:'platform'|'program'|'staff';published_at:string|null;thumbnail:string|null;captions:boolean;contents_count:number;shares:{id:number;program_id:number;title:string}[];capabilities:{manage:boolean};summary:{views:number;downloads:number;unique_users:number;completed:number;in_progress:number;not_started:number;audience:number;completion_rate:number;engagement:number;rating:number|null;feedback_count:number;trend:{month:string;views:number}[];trend_change:number|null};activity:{id:string;title:string;actor:string;created_at:string}[]}
export const getResourceOverview=async(id:number,months:string)=>(await api.get<ResourceOverview>(`/admin/resources/${id}/details`,{params:{months}})).data;
export const getResourceSection=async(id:number,section:string,page:number,q:string)=>(await api.get<{items:(ResourceContent|ResourceFeedback|ResourceVersion|ResourceAudit|ResourceLearner)[];meta:PageMeta}>(`/admin/resources/${id}/sections/${section}`,{params:{page,q}})).data;
export const saveResourceMetadata=(id:number,body:FormData)=>api.patch(`/admin/resources/${id}/details`,body);
export type ResourceContentDraft=Partial<Omit<ResourceContent,'file'>> & {file?:File|null;remove_file?:boolean};
export function saveResourceContent(id:number,content:ResourceContentDraft){
 let body:FormData|{content:ResourceContentDraft};
 if(content.file instanceof File){body=new FormData();for(const[key,value]of Object.entries(content))if(value!==undefined&&value!==null)body.append(`content[${key}]`,value instanceof File?value:String(value));}
 else body={content};
 return content.id?api.patch(`/admin/resources/${id}/contents/${content.id}`,body):api.post(`/admin/resources/${id}/contents`,body);
}
export const deleteResourceContent=(id:number,content:ResourceContent)=>api.delete(`/admin/resources/${id}/contents/${content.id}`,{data:{lock_version:content.lock_version}});
export const shareResource=(id:number,program_id:number,lock_version:number)=>api.post(`/admin/resources/${id}/shares`,{share:{program_id,lock_version}});
export const unshareResource=(id:number,share:number,lock_version:number)=>api.delete(`/admin/resources/${id}/shares/${share}`,{data:{lock_version}});
export const restoreResourceVersion=(id:number,version:number,lock_version:number)=>api.post(`/admin/resources/${id}/versions/${version}/restore`,{lock_version});
export const deleteResource=(id:number,lock_version:number)=>api.delete(`/admin/resources/${id}`,{data:{lock_version}});
export async function duplicateResource(id:number,resource:ResourceDraft){const body=new FormData();for(const [k,v] of Object.entries(resource)){if(k==='tags'){if(resource.tags.length)resource.tags.forEach(t=>body.append('resource[tags][]',t));else body.append('resource[clear_tags]','true')}else if(v!==null&&v!==undefined)body.append(`resource[${k}]`,v instanceof File?v:String(v));else if(k==='platform_program_id')body.append('resource[platform_program_id]','')}return(await api.post<AdminResource>(`/admin/resources/${id}/duplicate`,body)).data;}
export const getResourceCaptions=async(id:number,learner=false)=>(await api.get<Blob>(learner?`/learning/resources/${id}/captions`:`/admin/resources/${id}/captions`,{responseType:'blob'})).data;
export interface LearnerResource {id:number;title:string;description:string;resource_type:string;tags:string[];url:string|null;file:{filename:string;type:string;size:number}|null;contents:ResourceContent[];language:string;duration_seconds:number|null;captions:boolean;progress:{percent:number;lock_version:number}|null;feedback:{rating:number;comment:string}|null;can_participate:boolean}
export const getLearnerResource=async(id:number)=>(await api.get<LearnerResource>(`/learning/resources/${id}/details`)).data;
export const updateResourceProgress=(id:number,percent:number,lock_version:number)=>api.put(`/learning/resources/${id}/progress`,{progress:{percent,lock_version}});
export const submitResourceFeedback=(id:number,rating:number,comment:string)=>api.put(`/learning/resources/${id}/feedback`,{feedback:{rating,comment}});
