import { normalizeApplicationPhone, validApplicationPhone } from './application-phone';
import type { ApplicationFields, MentorApplication } from './mentor-onboarding-api';
export const qualificationOptions = { secondary:'Secondary School',certificate:'Certificate',diploma:'Diploma',bachelors:'Bachelor’s Degree',masters:'Master’s Degree',doctorate:'Doctorate / PhD',other:'Other Relevant Qualification' };
export const learnerOptions = { primary:'Primary (P.1 – P.7)',secondary:'Secondary (S.1 – S.6)',university:'University & College',early_career:'Early Career / Young Professionals' };
export const experienceOptions = { '0-1':'0–1 Years','2-5':'2–5 Years','6-10':'6–10 Years','10+':'10+ Years' };
export const expertiseOptions = ['Education','Technology','Career Guidance','Leadership','Business & Entrepreneurship','Science & Innovation','Agriculture & Environment','Creative Arts','Health & Wellbeing','Finance','Life Skills'];
export const emptyApplication:ApplicationFields = {full_name:'',contact_email:'',phone_number:'',location:'',gender:'',date_of_birth:'',highest_qualification:'',organization:'',experience_range:'',expertise_tags:[],target_learners:[],terms_accepted:false,headline:'',background:'',expertise:'',years_of_experience:0,motivation:'',references_text:'',conduct_accepted:false,safeguarding_accepted:false};
export function applicationFields(record:MentorApplication):ApplicationFields {
 const fields=Object.fromEntries(Object.keys(emptyApplication).map(key=>[key,record[key as keyof ApplicationFields]??emptyApplication[key as keyof ApplicationFields]])) as unknown as ApplicationFields;
 fields.phone_number=normalizeApplicationPhone(fields.phone_number);
 return fields;
}
export function bioWords(value:string){ return value.trim()?value.trim().split(/\s+/).length:0; }
export function applicationFormErrors(draft:ApplicationFields, hasPhoto:boolean):Record<string,string> {
 const errors:Record<string,string>={};
 for(const [key,label] of Object.entries({full_name:'Full name',contact_email:'Email address',phone_number:'Phone number',location:'Location',gender:'Gender',date_of_birth:'Date of birth',highest_qualification:'Highest qualification',headline:'Current occupation / role',experience_range:'Years of experience'}))if(!String(draft[key as keyof ApplicationFields]).trim())errors[key]=`${label} is required.`;
 if(draft.contact_email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(draft.contact_email))errors.contact_email='Enter a valid email address.';
 if(draft.phone_number&&!validApplicationPhone(draft.phone_number))errors.phone_number='Enter a phone number, e.g. 0772 345 678 or +256 772 345 678.';
 if(!hasPhoto)errors.profile_photo='Upload a clear profile photo.';
 if(!draft.expertise_tags.length)errors.expertise_tags='Choose at least one area of expertise.';
 if(!draft.target_learners.length)errors.target_learners='Choose at least one learner group.';
 if(bioWords(draft.background)<100||bioWords(draft.background)>300)errors.background='Your short bio must contain 100–300 words.';
 if(!draft.conduct_accepted||!draft.safeguarding_accepted||!draft.terms_accepted)errors.terms_accepted='Agree to the Code of Conduct, Safeguarding Policy and Terms of Service.';
 return errors;
}
