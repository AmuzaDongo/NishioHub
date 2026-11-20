import api from './axios';
import type { PageMeta, ProgramPerson } from './admin-programs-api';
export type GoalKind='mentee'|'mentor'|'program';
export type GoalCategory='learning'|'career'|'project'|'personal'|'other';
export type GoalTracking='on_track'|'in_progress'|'at_risk';
export type GoalPriority='low'|'medium'|'high';
export type GoalStatus=GoalTracking|'completed';
export interface AdminGoal {id:string;kind:GoalKind;title:string;description:string|null;progress:number;completed:boolean;target_date:string|null;icon:string;category:GoalCategory;tracking_status:GoalTracking;status:GoalStatus;lock_version:number;created_at:string;priority:GoalPriority;completed_at:string|null;assignee:ProgramPerson|null;program:{id:number;title:string;status:string}|null}
export interface AdminGoalMilestone {id:number;title:string;target_date:string|null;completed:boolean;lock_version:number}
export interface GoalDetail extends AdminGoal {milestones:AdminGoalMilestone[];history:{id:number;progress:number;note:string;actor_name:string|null;created_at:string}[]}
export interface GoalPerson {id:number;name:string;avatar:string|null;active:boolean;goals:number;progress:number;completed:number;at_risk:number}
export interface GoalFilters {q:string;tab:string;type:string;category:string;status:string;program_id:string;assignee_id:string;page:number;per_page:number;sort:string;direction:string;months:string}
export interface GoalWorkspace {items:AdminGoal[];people:GoalPerson[];mode:'goals'|'people';meta:PageMeta;capabilities:{manage:boolean;view_users:boolean};stats:{total:number;on_track:number;in_progress:number;at_risk:number;completed:number;overall_progress:number|null;changes:Record<string,number|null>};distribution:{status:GoalStatus;count:number}[];categories:{category:GoalCategory;count:number}[];trend:{month:string;progress:number|null;recorded_goals:number}[];trend_change:number|null;timezone:string}
export interface AdminGoalDraft {kind:GoalKind;title:string;description:string;user_id:number|null;platform_program_id:number|null;progress:number;target_date:string|null;category:GoalCategory;tracking_status:GoalTracking;icon:string;priority:GoalPriority;lock_version?:number;note?:string}
export const getAdminGoals=async(params:GoalFilters)=>(await api.get<GoalWorkspace>('/admin/goals',{params})).data;
export const getAdminGoal=async(id:string)=>(await api.get<GoalDetail>(`/admin/goals/${id}`)).data;
export const saveAdminGoal=async(id:string|undefined,goal:Partial<AdminGoalDraft>)=>(await api.request<GoalDetail>({url:id?`/admin/goals/${id}`:'/admin/goals',method:id?'patch':'post',data:{goal}})).data;
export const archiveAdminGoal=async(goal:AdminGoal)=>{await api.delete(`/admin/goals/${goal.id}`,{params:{lock_version:goal.lock_version}})};
export const saveAdminMilestone=async(goalId:string,milestone:Partial<AdminGoalMilestone>,id?:number)=>{await api.request({url:`/admin/goals/${goalId}/milestones${id?`/${id}`:''}`,method:id?'patch':'post',data:{milestone}})};
export const removeAdminMilestone=async(goalId:string,milestone:AdminGoalMilestone)=>{await api.delete(`/admin/goals/${goalId}/milestones/${milestone.id}`,{params:{lock_version:milestone.lock_version}})};
export const exportAdminGoals=async(params:GoalFilters,goal_ids:string[])=>(await api.get<Blob>('/admin/goals/export',{params:{...params,...(goal_ids.length?{goal_ids}:{})},responseType:'blob'})).data;
export const exportGoalReport=async(params:GoalFilters)=>(await api.get<Blob>('/admin/goals/report',{params,responseType:'blob'})).data;
