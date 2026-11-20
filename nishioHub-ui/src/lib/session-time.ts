function parts(value: Date, timezone: string) { return Object.fromEntries(new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(value).map(p => [p.type, p.value])); }
export function sessionLocalInput(value: string, timezone: string) { const p = parts(new Date(value), timezone); return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`; }
export function sessionIsoInput(value: string, timezone: string) {
  const [y, m, d, h, min] = value.split(/[-T:]/).map(Number); const utc = Date.UTC(y, m - 1, d, h, min);
  if (!Number.isFinite(utc)) throw new Error('Choose a valid date and time');
  let candidate = utc;
  for (let i = 0; i < 3; i++) { const p = parts(new Date(candidate), timezone); const local = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute); candidate += utc - local; }
  const result = new Date(candidate).toISOString();
  if (sessionLocalInput(result, timezone) !== value) throw new Error('This time does not exist in the platform timezone. Choose another time.');
  return result;
}
