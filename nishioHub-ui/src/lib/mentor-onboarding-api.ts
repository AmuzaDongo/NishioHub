import api from '@/lib/axios';
export const applicationDocuments = { identity_document: 'Government ID', curriculum_vitae: 'Professional / Academic CV', qualification_document: 'Qualifications or Experience Evidence' } as const;
export type ApplicationDocument = keyof typeof applicationDocuments;
export type ApplicationUpload = ApplicationDocument | 'profile_photo';
export interface ApplicationFile { filename: string; size: number; content_type: string; uploaded_at?: string }
export type ApplicationStatus = 'draft' | 'submitted' | 'changes_requested' | 'approved' | 'rejected';
export interface ApplicationFields { full_name:string; contact_email:string; phone_number:string; location:string; gender:string; date_of_birth:string; highest_qualification:string; organization:string; experience_range:string; expertise_tags:string[]; target_learners:string[]; terms_accepted:boolean; headline: string; background: string; expertise: string; years_of_experience: number; motivation: string; references_text: string; conduct_accepted: boolean; safeguarding_accepted: boolean }
export interface MentorApplication extends ApplicationFields {
 id: number; form_version:number; profile_photo:ApplicationFile|null; status: ApplicationStatus; lock_version: number; editable: boolean; profile_verified?: boolean;
 documents: Record<ApplicationDocument, ApplicationFile | null>;
 policy_version_current: string; submitted_at: string | null; reviewed_at: string | null; review_note: string; missing_requirements: string[];
 applicant?: { id: number; name: string; email: string }; reviewer?: string; can_review?: boolean;
}
export const getMentorApplication = async () => (await api.get<MentorApplication>('/me/mentor-application')).data;
export const saveMentorApplication = async (application: ApplicationFields, lock_version: number) => (await api.patch<MentorApplication>('/me/mentor-application', { application, lock_version })).data;
export async function uploadApplicationDocument(kind: ApplicationUpload, file: File, lock_version: number) {
 const body = new FormData(); body.append('file', file); body.append('lock_version', String(lock_version));
 return (await api.post<MentorApplication>(`/me/mentor-application/documents/${kind}`, body)).data;
}
export const removeApplicationDocument = async (kind: ApplicationUpload, lock_version: number) => (await api.delete<MentorApplication>(`/me/mentor-application/documents/${kind}`, { params: { lock_version } })).data;
export const submitMentorApplication = async (application: MentorApplication) => (await api.post<MentorApplication>('/me/mentor-application/submit', { lock_version: application.lock_version, policy_version: application.policy_version_current })).data;
export const downloadApplicationDocument = async (kind: ApplicationUpload, adminId?: number) => (await api.get<Blob>(adminId ? `/admin/mentor-applications/${adminId}/documents/${kind}` : `/me/mentor-application/documents/${kind}`, { responseType: 'blob' })).data;
export interface ApplicationsList { items: { id: number; name: string; email: string; headline: string; status: ApplicationStatus; submitted_at: string }[]; total: number; page: number; total_pages: number; can_review: boolean }
export const getMentorApplications = async (q: string, status: string, page: number) => (await api.get<ApplicationsList>('/admin/mentor-applications', { params: { q, status, page } })).data;
export const getAdminMentorApplication = async (id: number) => (await api.get<MentorApplication>(`/admin/mentor-applications/${id}`)).data;
export const reviewMentorApplication = async (id: number, lock_version: number, decision: ApplicationStatus, note: string) => (await api.post<MentorApplication>(`/admin/mentor-applications/${id}/review`, { lock_version, decision, note })).data;
