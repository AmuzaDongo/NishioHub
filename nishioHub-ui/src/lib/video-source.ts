export type VideoSource = {kind:'embed'|'file';url:string};
// Only known providers become frames. Arbitrary URLs never become iframe sources.
export function videoSource(value:string,force=false):VideoSource|null {
 let u:URL;try{u=new URL(value);}catch{return null;}
 if(u.username||u.password||!['https:','http:','blob:'].includes(u.protocol))return null;
 const host=u.hostname.toLowerCase();
 if(['youtube.com','www.youtube.com','m.youtube.com','youtube-nocookie.com','www.youtube-nocookie.com','youtu.be','www.youtu.be'].includes(host)){
  const parts=u.pathname.split('/').filter(Boolean);
  const id=host.endsWith('youtu.be')?parts[0]:u.pathname==='/watch'?u.searchParams.get('v'):['embed','shorts','live'].includes(parts[0])?parts[1]:null;
  if(!id||!/^[-\w]{11}$/.test(id))return null;
  const url=new URL(`https://www.youtube-nocookie.com/embed/${id}`);url.searchParams.set('rel','0');url.searchParams.set('playsinline','1');
  const start=u.searchParams.get('start')||u.searchParams.get('t');if(start&&/^\d+$/.test(start))url.searchParams.set('start',start);
  return {kind:'embed',url:url.href};
 }
 if(['vimeo.com','www.vimeo.com','player.vimeo.com'].includes(host)){
  const parts=u.pathname.split('/').filter(Boolean);const index=parts.findIndex(p=>/^\d+$/.test(p));if(index<0)return null;
  const url=new URL(`https://player.vimeo.com/video/${parts[index]}`);const hash=u.searchParams.get('h')||parts[index+1];if(hash&&/^[a-zA-Z0-9]+$/.test(hash))url.searchParams.set('h',hash);
  return {kind:'embed',url:url.href};
 }
 if(force||/\.(mp4|webm|ogv|ogg|mov|m4v)$/i.test(u.pathname))return {kind:'file',url:u.href};
 return null;
}

export function vidstackSource(value:string,force=false,mimeType?:string){
 const source=videoSource(value,force);if(!source)return null;
 const url=new URL(source.url);
 if(source.kind==='embed')return {src:source.url,type:url.hostname==='player.vimeo.com'?'video/vimeo' as const:'video/youtube' as const};
 const hint=mimeType?.split(';')[0];
 const type=hint==='video/webm'||/\.webm$/i.test(url.pathname)?'video/webm':hint==='video/ogg'||/\.(ogv|ogg)$/i.test(url.pathname)?'video/ogg':'video/mp4';
 return {src:source.url,type:type as 'video/mp4'|'video/webm'|'video/ogg'};
}
export function videoStart(value:string){
 const source=videoSource(value);if(!source||source.kind!=='embed')return 0;
 return Number(new URL(source.url).searchParams.get('start'))||0;
}
