import api from './axios';
export type ReportKind='overview'|'users'|'programs'|'learning'|'events'|'achievements';
export type ReportFilters={period:string;from?:string;to?:string;q?:string;program_id?:number};
export interface ReportTable {columns:{key:string;title:string}[];items:Record<string,string|number|null>[];meta:{page:number;per_page:number;total:number;total_pages:number}}
export interface ReportSpec {id:number;name:string;kind:ReportKind;columns:string[];filters:ReportFilters;lock_version:number}
export interface ReportSchedule extends ReportSpec {frequency:string;hour:number;minute:number;weekday:number;month_day:number;timezone:string;active:boolean;next_run_at:string;last_run_at:string|null;last_status:string|null;last_error:string|null}
export interface ReportRun {id:number;name:string;kind:ReportKind;status:string;row_count:number|null;error:string|null;created_at:string;finished_at:string|null}
export interface ReportData {period:{from:string;to:string;timezone:string};generated_at:string;metrics:{key:ReportKind|'resources';value:number;previous:number;change:number|null}[];user_growth:{month:string;value:number}[];roles:{key:string;count:number}[];achievement_trend:{month:string;value:number}[];completion:{enrolled:number;completed:number;in_progress:number;not_started:number;rate:number|null;previous_rate:number|null};goal_categories:{category:string;progress:number|null;recorded_goals:number}[];insights:{title:string;text:string;change:number|null}[];top_programs:Record<string,string|number|null>[];capabilities:{manage:boolean;users:boolean;user_export:boolean};catalog:Record<string,Record<string,string>>;table?:ReportTable;saved?:ReportSpec[];schedules?:ReportSchedule[];runs?:ReportRun[];runs_meta?:ReportTable['meta']}
export const getReports=async(params:ReportFilters & {tab:string;page:number;per_page:number})=>(await api.get<ReportData>('/admin/reports',{params})).data;
export const exportReports=async(kind:ReportKind,filters:ReportFilters)=>(await api.get<Blob>('/admin/reports/export',{params:{...filters,kind},responseType:'blob'})).data;
export const saveReport=async(report:Partial<ReportSpec>)=>(await api.request<ReportSpec>({url:`/admin/reports/custom${report.id?`/${report.id}`:''}`,method:report.id?'patch':'post',data:{report}})).data;
export const deleteReport=async(report:ReportSpec)=>{await api.delete(`/admin/reports/custom/${report.id}`,{params:{lock_version:report.lock_version}})};
export const previewReport=async(id:number,page:number)=>(await api.get<ReportTable>(`/admin/reports/custom/${id}`,{params:{page}})).data;
export const exportSavedReport=async(id:number)=>(await api.get<Blob>(`/admin/reports/custom/${id}/export`,{responseType:'blob'})).data;
export const saveSchedule=async(schedule:Partial<ReportSchedule>)=>(await api.request<ReportSchedule>({url:`/admin/reports/schedules${schedule.id?`/${schedule.id}`:''}`,method:schedule.id?'patch':'post',data:{schedule}})).data;
export const deleteSchedule=async(s:ReportSchedule)=>{await api.delete(`/admin/reports/schedules/${s.id}`,{params:{lock_version:s.lock_version}})};
export const runSchedule=async(id:number)=>(await api.post<ReportRun>(`/admin/reports/schedules/${id}/run`)).data;
export const downloadReportRun=async(id:number)=>(await api.get<Blob>(`/admin/reports/runs/${id}/file`,{responseType:'blob'})).data;
