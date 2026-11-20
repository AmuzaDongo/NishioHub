// Render the authenticated SVG locally so Unicode names and the certificate's
// artwork survive PDF export without a server-side browser or font dependency.
export async function certificateToPdf(svg: Blob): Promise<Blob> {
  const url = URL.createObjectURL(svg);
  try {
    const image = new Image();
    await new Promise<void>((resolve, reject) => { image.onload = () => resolve(); image.onerror = () => reject(new Error('Could not render the certificate')); image.src = url; });
    const canvas = document.createElement('canvas'); canvas.width = 2400; canvas.height = 1700;
    const context = canvas.getContext('2d');
    if (!context) throw new Error('PDF export requires canvas support');
    context.fillStyle = '#ffffff'; context.fillRect(0, 0, canvas.width, canvas.height); context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const jpeg = Uint8Array.from(atob(canvas.toDataURL('image/jpeg', 0.95).split(',')[1]), c => c.charCodeAt(0));
    const encode = (text: string) => new TextEncoder().encode(text);
    const parts: Uint8Array[] = []; const offsets: number[] = [0]; let length = 0;
    const append = (data: Uint8Array) => { parts.push(data); length += data.byteLength; };
    const object = (id: number, content: string) => { offsets[id] = length; append(encode(`${id} 0 obj\n${content}\nendobj\n`)); };
    append(encode('%PDF-1.4\n'));
    object(1, '<< /Type /Catalog /Pages 2 0 R >>');
    object(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    object(3, '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 841.89 595.28] /Resources << /XObject << /Certificate 4 0 R >> >> /Contents 5 0 R >>');
    offsets[4] = length;
    append(encode(`4 0 obj\n<< /Type /XObject /Subtype /Image /Width 2400 /Height 1700 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.byteLength} >>\nstream\n`));
    append(jpeg); append(encode('\nendstream\nendobj\n'));
    const commands = 'q\n841.89 0 0 595.28 0 0 cm\n/Certificate Do\nQ\n';
    object(5, `<< /Length ${encode(commands).byteLength} >>\nstream\n${commands}endstream`);
    const xref = length;
    append(encode(`xref\n0 6\n0000000000 65535 f \n${offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('')}trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`));
    return new Blob(parts, { type: 'application/pdf' });
  } finally { URL.revokeObjectURL(url); }
}
