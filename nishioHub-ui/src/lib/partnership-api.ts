import api from './axios';

export const partnershipFocus = {
  schools: 'For Schools & Education Institutions', universities: 'For Universities & Colleges',
  businesses: 'For Businesses & Employers', ngos: 'For NGOs & Development Partners',
  government: 'For Government & Public Institutions', community: 'For Community & Youth Organizations',
};
export interface PartnershipDetails {
  organization_name: string; contact_role: string; phone_number: string; focus: string;
  terms_accepted: boolean; request_kind: 'partnership' | 'meeting'; preferred_at?: string;
}
export interface PartnershipRequest extends PartnershipDetails { name: string; email: string; message: string }
export const submitPartnershipRequest = async (request: PartnershipRequest & { submission_key: string }) =>
  (await api.post<{ reference: string; detail: string }>('/platform/partnership-requests', { partnership_request: request })).data;
