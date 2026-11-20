import api from './axios';
import type { PageMeta, ProgramPerson } from './admin-programs-api';
export type ResourceType = 'course'|'video'|'document'|'link'|'other';
export type ResourceStatus = 'published'|'draft'|'archived';
export interface AdminResource {id:number;title:string;description:string;resource_type:ResourceType;tags:string[];status:ResourceStatus;program:{id:number;title:string}|null;uploaded_by:ProgramPerson|null;url:string|null;file:{filename:string;size:number;type:string}|null;views:number;created_at:string;lock_version:number}
export interface ResourceDetail extends AdminResource {downloads:number;link_opens:number;unique_users:number}
export interface ResourceFilters {q:string;tab:string;type:string;status:string;program_id:string;sort:string;direction:string;page:number;per_page:number;months:string}
export interface ResourceWorkspace {items:AdminResource[];meta:PageMeta;capabilities:{manage:boolean};stats:{total:number;counts:Partial<Record<ResourceType,number>>;changes:Record<string,number|null>};distribution:{type:ResourceType;count:number}[];trend:{month:string;views:number}[];trend_change:number|null;top_resources:AdminResource[]}
export interface ResourceDraft {title:string;description:string;resource_type:ResourceType;status:ResourceStatus;url:string;platform_program_id:number|null;tags:string[];file:File|null;remove_file:boolean;lock_version?:number}
export interface ResourcePreview {valid:boolean;ready:number;total:number;rows:{row:number;title:string;errors:string[]}[]}
export const getAdminResources=async(params:ResourceFilters)=>(await api.get<ResourceWorkspace>('/admin/resources',{params})).data;
export const getAdminResource=async(id:number)=>(await api.get<ResourceDetail>(`/admin/resources/${id}`)).data;
export async function saveAdminResource(id:number|undefined,resource:ResourceDraft){const body=new FormData();for(const [key,value]of Object.entries(resource)){if(key==='tags'){if(resource.tags.length)resource.tags.forEach(t=>body.append('resource[tags][]',t));else body.append('resource[clear_tags]','true')}else if(value!==null&&value!==undefined)body.append(`resource[${key}]`,value instanceof File?value:String(value));else if(key==='platform_program_id')body.append('resource[platform_program_id]','')}return(await(id?api.patch<AdminResource>(`/admin/resources/${id}`,body):api.post<AdminResource>('/admin/resources',body))).data;}
export const changeResourceStatus=(resources:AdminResource[],status:ResourceStatus)=>api.post('/admin/resources/bulk-status',{resource_ids:resources.map(r=>r.id),versions:Object.fromEntries(resources.map(r=>[r.id,r.lock_version])),status});
export const downloadAdminResource=async(id:number)=>(await api.get<Blob>(`/admin/resources/${id}/file`,{responseType:'blob'})).data;
export const exportResources=async(params:ResourceFilters,ids:number[])=>(await api.get<Blob>('/admin/resources/export',{params:{...params,...(ids.length?{resource_ids:ids}:{})},responseType:'blob'})).data;
export const resourceTemplate=async()=>(await api.get<Blob>('/admin/resources/import-template',{responseType:'blob'})).data;
export async function resourceCsv(file:File,commit:boolean):Promise<ResourcePreview|{imported:number}>{const form=new FormData();form.append('file',file);return(await api.post(commit?'/admin/resources/import':'/admin/resources/import-preview',form)).data;}
