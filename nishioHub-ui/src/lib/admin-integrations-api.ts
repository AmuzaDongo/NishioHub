import api from './axios';
export type IntegrationStatus='available'|'active'|'paused'|'attention';
export interface Integration {key:string;name:string;category:string;label:string;description:string;docs_url:string;fields:{key:string;label:string;secret:boolean}[];status:IntegrationStatus;environment:string;lock_version:number|null;credential_fields:string[];last_checked_at:string|null;last_message:string|null;last_http_status:number|null;updated_at:string|null;updated_by:string|null}
export interface IntegrationLog {id:number;provider_key:string;action:string;outcome:string;message:string;http_status:number|null;actor_name:string;created_at:string}
export interface IntegrationWorkspace {items:Integration[];stats:{total:number;active:number;paused:number;attention:number;available:number};categories:{key:string;count:number}[];activity:IntegrationLog[];capabilities:{manage:boolean}}
export const getIntegrations=async(q:string,category:string)=>(await api.get<IntegrationWorkspace>('/admin/integrations',{params:{q,category}})).data;
export const saveIntegration=async(item:Integration,credentials:Record<string,string>,environment:string)=>(await api.patch<Integration>(`/admin/integrations/${item.key}`,{integration:{credentials,environment,lock_version:item.lock_version}})).data;
export const integrationStatus=async(item:Integration,action_name:'pause'|'resume')=>(await api.post<Integration>(`/admin/integrations/${item.key}/status`,{action_name,lock_version:item.lock_version})).data;
export const checkIntegration=async(item:Integration)=>(await api.post<Integration>(`/admin/integrations/${item.key}/check`,{lock_version:item.lock_version})).data;
export const disconnectIntegration=async(item:Integration)=>(await api.delete<Integration>(`/admin/integrations/${item.key}`,{params:{lock_version:item.lock_version}})).data;
export const getIntegrationLogs=async(page:number,provider:string,outcome:string)=>(await api.get<{items:IntegrationLog[];meta:{page:number;total:number;total_pages:number}}>('/admin/integrations/logs',{params:{page,provider:provider||undefined,outcome:outcome||undefined}})).data;
