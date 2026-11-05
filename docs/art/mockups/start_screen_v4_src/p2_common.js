
/* ======================= page 2 (round 4): three looks behind one switch ======================= */
/* LOOK picks page 2's place: A the bagging counter, B the staff room (recommended), C the display end-cap.
   Page 1, the top bar, the step rail, the keys, the modals and every rule are shared. */
let LOOK = 'B';
const ART2 = {};      // cached canvases of the three looks
function canv(key, w, h, fn){ if(ART2[key]) return ART2[key]; const c=document.createElement('canvas'); c.width=w; c.height=h; const x=c.getContext('2d');
  const R=(k,X,Y,W,H=1)=>{ x.fillStyle=P[k]||k; x.fillRect(X,Y,W,H); }; fn(R,x); return ART2[key]=c.toDataURL(); }
const aimg=(url,l,t,w,h,extra='')=>`<img class="a" src="${url}" style="left:${l}px;top:${t}px;width:${w}px;height:${h}px;${extra}" alt="">`;
/* Atkinson width of a plain sentence (to step a long line down a size instead of letting it wrap) */
const ATKM=document.createElement('canvas').getContext('2d');
function atkW(s, size, weight=700){ ATKM.font=`${weight} ${size}px NCAtk`; return ATKM.measureText(s).width; }
/* a row of chase bulbs along a line (screen px); phase alternates a/b, steady lights them all */
function bulbRow(x0, y0, dx, dy, n, steady, ph=0){ let h=''; for(let k=0;k<n;k++) h+=`<span class="blb ${steady?'steady':(k+ph)%2?'b':'a'}" style="left:${x0+k*dx}px;top:${y0+k*dy}px"></span>`; return h; }

/* the store's roller shutter (A and B's OPEN STORE): a brass-trimmed housing with the lit NEXT CUSTOMER sign, steel slats
   in the night light of two gooseneck lamps (StorefrontArt's cone dots), a brass bottom bar with two handles and a lock */
function shutterArt(){ return canv('shutter',640,360,(R)=>{
  for(let y=36;y<346;y++){ const k=(y-36)%12; R(k===0?'B':k<9?'D':k<11?'E':'#',0,y,640,1); }
  // the lamps' cones on the slats: one px in four, a checker near the lamp
  [150,490].forEach(cx=>{ for(let y=44;y<300;y++){ const half=8+(y-44)*.42; for(let i=Math.max(0,Math.round(cx-half));i<Math.min(640,cx+half);i++){
    const near=y<100; if(near?(i+y)%2===0:(i%2===0&&y%2===0)){ const k=(y-36)%12; if(k!==11) R(k===0?'y':'u',i,y,1,1); } } } });
  // housing: steel box, brass trim, the sign plate (charcoal glass in a brass ring)
  R('#',0,0,640,38); R('E',0,1,640,30); R('D',0,1,640,2); R('H',0,28,640,3); R('L',0,31,640,4); R('n',0,31,640,1); R('l',0,34,640,1); R('#',0,35,640,1);
  R('#',150,3,340,30); R('L',151,4,338,28); R('n',151,4,338,1); R('l',151,31,338,1); R('#',153,6,334,24); R('N',154,7,332,22);
  for(let j=8;j<29;j+=2) R('K',154,j,332,1);
  // the two gooseneck lamps under the housing
  [150,490].forEach(cx=>{ R('#',cx-1,35,3,6); R('#',cx-6,40,12,4); R('L',cx-5,40,10,2); R('n',cx-4,43,8,1); });
  // bottom bar, handles, lock
  R('#',0,345,640,1); R('L',0,346,640,9); R('n',0,346,640,1); R('l',0,353,640,2); R('#',0,355,640,5);
  [210,430].forEach(hx=>{ R('#',hx,348,24,6); R('B',hx+2,350,20,2); R('#',hx+4,350,16,1); });
  R('#',312,347,16,8); R('B',313,348,14,6); R('#',319,350,2,3);
}); }
function shutterEl(){
  const d=document.createElement('div'); d.className='shutter';
  const bl=bulbRow(468,15,30,0,33,false)+bulbRow(468,84,30,0,33,false);
  d.innerHTML=`<img src="${shutterArt()}" style="position:absolute;left:0;top:0;width:1920px;height:1080px" alt="">${bl}
    <div class="a" style="left:3px;top:33px;width:1920px;display:flex;justify-content:center">${PT('NEXT CUSTOMER',P.k,6)}</div>
    <div class="a" style="left:0;top:30px;width:1920px;display:flex;justify-content:center">${PT('NEXT CUSTOMER',P.n,6)}</div>
    <div class="a" style="left:828px;top:474px;width:264px;padding:12px 15px;background:var(--paper);border:3px solid var(--ink);transform:rotate(-2deg);box-shadow:6px 6px 0 rgba(43,36,32,.45);display:grid;justify-items:center;gap:6px">${PT('OPENING',INK)}${PT('TIME',P.r)}</div>`;
  return d;
}
