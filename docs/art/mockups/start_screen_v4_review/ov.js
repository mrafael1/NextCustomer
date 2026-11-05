(()=>{const fr=F.getBoundingClientRect(),k=fr.width/1920;
const els=[...F.querySelectorAll('.pg.on *, .chrome *')].filter(e=>{ if(e.closest('.tip'))return false; const cs=getComputedStyle(e); if(cs.visibility==='hidden'||cs.display==='none'||+cs.opacity===0) return false;
 const own=[...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim()); return own||e.tagName==='IMG'&&!e.classList.contains('a')||e.tagName==='CANVAS';});
const R=els.map(e=>{const r=e.getBoundingClientRect();return {e,l:(r.left-fr.left)/k,t:(r.top-fr.top)/k,r:(r.right-fr.left)/k,b:(r.bottom-fr.top)/k};}).filter(o=>o.r-o.l>2&&o.b-o.t>2&&(o.r-o.l)*(o.b-o.t)<60000);
const out=[];
for(let i=0;i<R.length;i++)for(let j=i+1;j<R.length;j++){const a=R[i],b=R[j]; if(a.e.contains(b.e)||b.e.contains(a.e))continue;
 const w=Math.min(a.r,b.r)-Math.max(a.l,b.l), h=Math.min(a.b,b.b)-Math.max(a.t,b.t); if(w>4&&h>4){
  const d=x=>(x.e.tagName==='IMG'?'img:'+(x.e.getAttribute('src')||'').slice(-28):JSON.stringify(x.e.textContent.trim().slice(0,24)))+`@${Math.round(x.l)},${Math.round(x.t)}`;
  out.push(d(a)+' X '+d(b)+` [${Math.round(w)}x${Math.round(h)}]`);}}
const imgs=[...document.images].filter(i=>i.complete&&i.naturalWidth===0).map(i=>(i.getAttribute('src')||'').slice(0,80));
return {n:R.length,ov:out.slice(0,40),broken:imgs};})()
