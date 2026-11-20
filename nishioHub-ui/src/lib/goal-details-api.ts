import api from './axios';
import type {AdminGoal,AdminGoalMilestone} from './admin-goals-api';
import type {PageMeta} from './admin-programs-api';
export interface GoalAttachment {id:number;title:string;url:string|null;lock_version:number;author:string;created_at:string;file:{filename:string;type:string;size:number}|null}
export interface GoalUpdate {id:string;kind:'note'|'progress';source_id:number;progress:number|null;body:string;author:string|null;created_at:string;updated_at:string;lock_version:number}
export interface GoalActivity {id:string;title:string;author:string|null;created_at:string}
export interface GoalOverview extends AdminGoal {has_cover:boolean;upload_limit_mb:number;capabilities:{manage:boolean};summary:{total_tasks:number;completed_tasks:number;task_completion_rate:number|null;completed_at:string|null;days_taken:number|null;trend:{id:number;progress:number;at:string;note:string}[];progress_change:number|null;updates:number;attachments:number;recent_updates:GoalUpdate[];recent_attachments:GoalAttachment[]}}
export type GoalSectionItem=AdminGoalMilestone|GoalUpdate|GoalAttachment|GoalActivity;
export const getGoalOverview=async(id:string)=>(await api.get<GoalOverview>(`/admin/goals/${id}/details`)).data;
export const getGoalSection=async(id:string,section:string,page:number,q:string)=>(await api.get<{items:GoalSectionItem[];meta:PageMeta}>(`/admin/goals/${id}/sections/${section}`,{params:{page,q}})).data;
export const saveGoalUpdate=async(id:string,body:string,item?:GoalUpdate)=>{await api.request({url:`/admin/goals/${id}/updates${item?`/${item.source_id}`:''}`,method:item?'patch':'post',data:{update:{body,...(item?{lock_version:item.lock_version}:{})}}})};
export const removeGoalUpdate=async(id:string,item:GoalUpdate)=>{await api.delete(`/admin/goals/${id}/updates/${item.source_id}`,{params:{lock_version:item.lock_version}})};
export const addGoalAttachment=async(id:string,title:string,url:string,file:File|null)=>{const body=new FormData();body.append('attachment[title]',title);body.append('attachment[url]',url);if(file)body.append('attachment[file]',file);await api.post(`/admin/goals/${id}/attachments`,body)};
export const removeGoalAttachment=async(id:string,item:GoalAttachment)=>{await api.delete(`/admin/goals/${id}/attachments/${item.id}`,{params:{lock_version:item.lock_version}})};
export const getGoalFile=async(id:string,path:string)=>(await api.get<Blob>(`/admin/goals/${id}/${path}`,{responseType:'blob'})).data;
export const saveGoalCover=async(id:string,lock_version:number,file:File|null)=>{const body=new FormData();body.append('lock_version',String(lock_version));if(file)body.append('file',file);else body.append('remove_cover','true');await api.patch(`/admin/goals/${id}/cover`,body)};
export const duplicateAdminGoal=async(id:string,goal:{title:string;target_date:string|null;user_id:number|null;platform_program_id:number|null;lock_version:number})=>(await api.post<{id:string}>(`/admin/goals/${id}/duplicate`,{goal})).data;
