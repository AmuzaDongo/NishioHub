// Keep JSON requests for ordinary edits; upload binary images with multipart data.
export function programRequestBody(program: object) {
  const fields = program as Record<string, unknown>;
  if (!(fields.banner instanceof File) && !fields.remove_banner) return { program };
  const body = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined || key === 'banner' && value === null) continue;
    if (Array.isArray(value)) {
      body.append(`program[${key}][]`, '');
      value.forEach(item => body.append(`program[${key}][]`, String(item)));
    } else if (key === 'public_details' && value && typeof value === 'object') body.append('program[public_details_json]', JSON.stringify(value));
    else if (value instanceof File) body.append(`program[${key}]`, value);
    else if (value === null || ['string', 'number', 'boolean'].includes(typeof value)) body.append(`program[${key}]`, String(value ?? ''));
  }
  return body;
}
