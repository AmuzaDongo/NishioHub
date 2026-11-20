import { useEffect, useState } from 'react';
import { Bell, Download } from 'lucide-react';
import { toast } from 'sonner';
import { operationError } from '@/components/admin/dashboard-operations';
import { downloadEventCalendar, updateEventReminder } from '@/lib/events-api';
import { saveDownload } from '@/lib/achievements-api';

const button = 'inline-flex items-center justify-center gap-2 rounded-lg border border-violet-500 bg-white px-3 py-2 text-sm font-bold text-violet-800 hover:bg-violet-50 disabled:cursor-not-allowed disabled:opacity-50';

export function PublicEventRegistrationControls({ eventId, reminderMinutes, disabled, onRefresh }: {
  eventId: number;
  reminderMinutes: number;
  disabled: boolean;
  onRefresh: () => Promise<void>;
}) {
  const [minutes, setMinutes] = useState(reminderMinutes);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  useEffect(() => { setMinutes(reminderMinutes); setError(''); }, [eventId, reminderMinutes]);

  async function saveReminder() {
    setPending(true); setError('');
    try {
      await updateEventReminder({ id: eventId, minutes });
      await onRefresh();
      toast.success('Calendar reminder saved. Download the calendar file to add it to your calendar.');
    } catch (failure) { setError(operationError(failure)); }
    finally { setPending(false); }
  }

  async function downloadCalendar() {
    setPending(true); setError('');
    try { saveDownload(await downloadEventCalendar(eventId), `nishiohub-event-${eventId}.ics`); }
    catch (failure) { setError(operationError(failure)); }
    finally { setPending(false); }
  }

  return <div className="space-y-3 rounded-xl border border-violet-100 bg-violet-50/60 p-3">
    <label className="block text-sm font-bold">Calendar reminder
      <select className="mt-2 w-full rounded-lg border border-violet-200 bg-white p-2 text-sm font-normal" value={minutes} disabled={disabled || pending} onChange={event => setMinutes(Number(event.target.value))}>
        <option value={0}>No reminder</option><option value={15}>15 minutes before</option><option value={30}>30 minutes before</option><option value={60}>1 hour before</option><option value={1440}>1 day before</option>
      </select>
    </label>
    <div className="flex flex-wrap gap-2">
      <button className={button} disabled={disabled || pending || minutes === reminderMinutes} onClick={saveReminder}><Bell size={16}/>Save Reminder</button>
      <button className={button} disabled={disabled || pending || minutes !== reminderMinutes} onClick={downloadCalendar}><Download size={16}/>Add to Calendar</button>
    </div>
    <p className="text-xs text-violet-900">Save your reminder, then download the calendar file. Import it into your calendar to receive the alert.</p>
    {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
  </div>;
}
