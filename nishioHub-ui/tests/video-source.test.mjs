import assert from 'node:assert/strict';
import ts from 'typescript';
import {readFileSync} from 'node:fs';
const code=ts.transpileModule(readFileSync(new URL('../src/lib/video-source.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.ES2022}}).outputText;
const {videoSource,vidstackSource,videoStart}=await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
const id='M7lc1UVf-VE';
for(const url of [`https://youtube.com/watch?v=${id}`,`https://youtu.be/${id}`,`https://youtube.com/shorts/${id}`,`https://youtube.com/live/${id}`,`https://www.youtube-nocookie.com/embed/${id}`]){
 const source=videoSource(url);assert.equal(source.kind,'embed');assert.equal(new URL(source.url).hostname,'www.youtube-nocookie.com');assert.equal(new URL(source.url).pathname,`/embed/${id}`);
}
assert.equal(new URL(videoSource(`https://youtu.be/${id}?t=90`).url).searchParams.get('start'),'90');
assert.equal(videoSource('https://vimeo.com/76979871/ab123').url,'https://player.vimeo.com/video/76979871?h=ab123');
assert.equal(videoSource('https://player.vimeo.com/video/76979871?h=ab123').kind,'embed');
assert.equal(videoSource('https://cdn.example.test/movie.MP4?signature=private').kind,'file');
assert.equal(videoSource('blob:https://nishiohub.com/test',true).kind,'file');
assert.equal(videoSource('https://cdn.example.test/private-stream',true).kind,'file');
for(const url of ['javascript:alert(1)','data:text/html,<script>bad</script>','https://youtube.com.evil.test/watch?v='+id,'https://evil.test/?video=movie.mp4','https://user:password@youtube.com/watch?v='+id,'https://youtube.com/watch?v=invalid','https://example.test/guide.pdf'])assert.equal(videoSource(url),null,url);
console.log('PASS: video source parsing, provider allowlist, signed file links, unlisted Vimeo hash, and unsafe source rejection');

assert.equal(vidstackSource(`https://youtube.com/shorts/${id}`).type,'video/youtube');
assert.equal(vidstackSource('https://vimeo.com/76979871/ab123').type,'video/vimeo');
assert.equal(vidstackSource('https://vimeo.com/76979871/ab123').src,'https://player.vimeo.com/video/76979871?h=ab123');
assert.equal(vidstackSource('blob:https://nishiohub.com/clip',true,'video/webm').type,'video/webm');
assert.equal(vidstackSource('https://cdn.example.test/private-stream',true,'video/mp4').type,'video/mp4');
assert.equal(vidstackSource('https://cdn.example.test/clip.webm?signature=private').type,'video/webm');
assert.equal(vidstackSource('javascript:alert(1)',true),null);
assert.equal(videoStart(`https://youtu.be/${id}?t=90`),90);
console.log('PASS: Vidstack source types, blob MIME hints, private Vimeo hash and chapter start time');
