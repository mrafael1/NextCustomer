/* OPEN STORE. A: the store's roller shutter drops over the counter and rolls up on the opening flood. B: the time card
   punches into the clock, then the same shutter. C (and reduced motion): the stepped mustard-pale flood, as in v3. */
let GOING=false;   // OPEN STORE is running: every input waits for the final reset()
function go(){
  if(GOING) return;
  if(sel<0||modal){ const k=document.getElementById('go'); if(k&&!RM){ k.animate([{transform:'translate(6px,6px)'},{transform:'translate(0,6px)'},{transform:'translate(12px,6px)'},{transform:'translate(6px,6px)'}],{duration:180,easing:'steps(4,end)'}); } return; }
  GOING=true;
  const k=document.getElementById('go'); k.style.transform='translate(6px,6px)'; k.style.boxShadow='3px 3px 0 rgba(43,36,32,.45)';
  const fl=document.getElementById('flood'), pk=PACKS[st().packs[sel]], n=deckOf(st().packs[sel]).length;
  const showFlood=()=>{ fl.innerHTML=`<div style="display:grid;justify-items:center;gap:24px">${LOOK==='B'?PT('CLOCKED IN',P.u,3):''}${L('SHIFT 1/12',INK,6,{num:INK})}${L(pk.name.toUpperCase()+' · '+n+' CARDS',P.u,3,{num:P.u})}</div>`; fl.style.display='grid'; };
  if(RM||LOOK==='C'){ setTimeout(showFlood, RM?0:120); setTimeout(()=>{ fl.style.display='none'; reset(); }, RM?1200:1800); return; }
  let t0=90;
  if(LOOK==='B'){ const tc=document.getElementById('tcard'); if(tc) tc.classList.add('punch'); t0=360; }
  const sh=shutterEl();
  setTimeout(()=>{ F.appendChild(sh); sh.classList.add('down'); }, t0);
  setTimeout(()=>{ showFlood(); fl.style.animation='none'; sh.classList.remove('down'); sh.classList.add('shown'); void sh.offsetWidth; sh.classList.remove('shown'); sh.classList.add('up'); }, t0+300+480);
  setTimeout(()=>{ sh.remove(); fl.style.display='none'; fl.style.animation=''; reset(); }, t0+300+480+600+800);
}
