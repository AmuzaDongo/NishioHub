import { useRef, useState, type FormEvent } from 'react';
import { CheckCircle2, Send } from 'lucide-react';
import { ButtonLoader } from '@/components/loaders/ButtonLoader';
import { inquireAboutProgram, type PublicProgram } from '@/lib/public-programs-api';
import { useAuth } from '@/lib/auth-context';
import { operationError } from '@/components/admin/dashboard-operations';

const input = 'mt-1 w-full rounded-lg border border-violet-200 bg-white p-2 text-sm font-normal focus:outline-violet-600';
function newKey() {
  if (crypto.randomUUID) return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16)); bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
  const h = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}
export function ProgramInquiryForm({ program, interestType = 'individual' }: { program: PublicProgram; interestType?: 'individual' | 'school' }) {
  const { user } = useAuth(); const [name, setName] = useState(user?.full_name || ''); const [email, setEmail] = useState(user?.email || '');
  const [message, setMessage] = useState(interestType === 'school' ? `I represent a school interested in ${program.title}. Please share school participation and enrollment information.` : `I am interested in ${program.title}. Please share eligibility and enrollment information.`);
  const [error, setError] = useState(''); const [reference, setReference] = useState(''); const [busy, setBusy] = useState(false);
  const lock = useRef(false); const key = useRef(''); const signature = useRef(''); const receipt = useRef<HTMLDivElement>(null);
  async function submit(event: FormEvent) {
    event.preventDefault(); if (lock.current) return;
    const payload = { interest_type: interestType, name: name.trim(), email: email.trim(), message: message.trim() };
    if (payload.name.length < 2 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.email) || payload.message.length < 10) { setError('Enter your name, a valid email and a message of at least 10 characters.'); return; }
    lock.current = true; setBusy(true); setError('');
    try {
      const next = JSON.stringify(payload); if (!key.current || signature.current !== next) { key.current = newKey(); signature.current = next; }
      const result = await inquireAboutProgram(program.id, { ...payload, submission_key: key.current }); setReference(result.reference); requestAnimationFrame(() => receipt.current?.focus());
    } catch (failure) { setError(operationError(failure)); } finally { lock.current = false; setBusy(false); }
  }
  if (reference) return <div ref={receipt} tabIndex={-1} role="status" className="rounded-xl border border-green-200 bg-green-50 p-4 outline-none"><h3 className="flex items-center gap-2 font-bold"><CheckCircle2 className="text-green-600" size={21}/>Program inquiry received</h3><p className="mt-2 text-sm">Our team will contact you about eligibility and enrollment. This inquiry does not reserve a place.</p><p className="mt-3 break-all text-xs">Reference: <strong>{reference}</strong></p></div>;
  return <form onSubmit={submit} className="space-y-3 rounded-xl border border-violet-100 bg-violet-50 p-4"><h3 className="font-extrabold">{interestType === 'school' ? 'Enroll Your School — Inquiry' : 'Ask About Joining'}</h3><p className="text-xs leading-relaxed">Tell us how to reach you. Our team will help with eligibility, school or guardian involvement where needed, and enrollment.</p><fieldset disabled={busy} className="space-y-3"><div className="grid gap-3 sm:grid-cols-2"><label className="text-xs font-bold">Full Name *<input aria-label="Program inquiry full name" required minLength={2} maxLength={150} autoComplete="name" value={name} onChange={e => setName(e.target.value)} className={input}/></label><label className="text-xs font-bold">Email Address *<input aria-label="Program inquiry email" required type="email" maxLength={254} autoComplete="email" value={email} onChange={e => setEmail(e.target.value)} className={input}/></label></div><label className="block text-xs font-bold">Message *<textarea aria-label="Program inquiry message" required minLength={10} maxLength={1000} rows={3} value={message} onChange={e => setMessage(e.target.value)} className={input}/></label></fieldset>{error && <p role="alert" className="text-sm text-red-700">{error}</p>}<ButtonLoader type="submit" loading={busy} loadingText="Sending Program Inquiry..." className="inline-flex items-center gap-2 rounded-lg bg-violet-700 px-4 py-2 text-sm font-bold text-white disabled:opacity-50"><Send size={16}/>Send Program Inquiry</ButtonLoader></form>;
}
