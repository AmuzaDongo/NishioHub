import api from './axios';

export const hostingTypes = { workshop: 'Workshops & Training', webinar: 'Webinars & Online Sessions', mentorship: 'Mentorship Sessions', career_talk: 'Career Talks & Panels', community_event: 'Community Events' };
export interface EventHostingFields {
  name: string; email: string; phone_number: string; event_type: string; title: string;
  description: string; preferred_date: string; location: string; additional_information: string; terms_accepted: boolean;
}
export type EventHostingDetails = Pick<EventHostingFields, 'phone_number' | 'event_type' | 'preferred_date' | 'location' | 'additional_information' | 'terms_accepted'> & { policy_version: string; submitted_by_id?: number };
export const submitEventHostingRequest = async (event_request: EventHostingFields & { submission_key: string }) =>
  (await api.post<{ reference: string; detail: string }>('/platform/event-hosting-requests', { event_request })).data;

export type HostingRequest = import('./public-home-api').PublicInquiry & { event_details: EventHostingDetails };
export type HostingDecision = 'approved' | 'rejected' | 'changes_requested';
export interface HostingReview { decision: HostingDecision; note: string; lock_version: number; event?: { starts_at: string; ends_at: string; format: string; location: string; capacity?: number | null } }
export const reviewEventHostingRequest = async (id: number, review: HostingReview) => (await api.post<HostingRequest>(`/admin/inquiries/${id}/decision`, { review })).data;
export const getMyEventHostingRequests = async (page: number) => (await api.get<{ items: HostingRequest[]; total: number }>('/me/event-hosting-requests', { params: { page } })).data;
export const resubmitEventHostingRequest = async (id: number, event_request: EventHostingFields & { lock_version: number }) => (await api.patch<HostingRequest>(`/me/event-hosting-requests/${id}`, { event_request })).data;
export const hostingRequestLabel = { pending: 'Pending Review', approved: 'Approved', rejected: 'Rejected', changes_requested: 'Changes Requested' };
export function hostingRequestFields(request: HostingRequest): EventHostingFields {
  const details = request.event_details;
  return { name: request.name, email: request.email, title: request.subject, description: request.message, phone_number: details.phone_number, event_type: details.event_type, preferred_date: details.preferred_date, location: details.location, additional_information: details.additional_information, terms_accepted: details.terms_accepted };
}
