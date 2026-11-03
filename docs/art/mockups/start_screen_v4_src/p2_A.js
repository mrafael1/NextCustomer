
/* ======================= page 2, look A: the bagging counter ======================= */
/* The build is put together at the end of the belt. Behind the counter, a steel shelf holds the three starter packs,
   pre-packed in tall kraft carrier bags, their 3 items standing whole out of the top, each over its shelf-edge ticket.
   Picking one lifts its bag off the shelf (a big PICKED sticker on the bag, its lamp burns hot, the other two go dark).
   GOOD FIRST PICK is a wobbler on its spring, planted in the shelf beside the bag. The trolley is the cart recap: the
   15 cards stand loose in its wire basket under paper tags, still-to-come places dashed. The badge pins hang on the
   cashier's lanyard on the staff cork board. OPEN STORE drops the store's roller shutter and rolls it up on SHIFT 1/12. */
/* the bag's back: its open mouth behind the items and the two twisted paper handles (100x36 art) */
function bagBackA(){ return canv('bagbackA',100,36,(R)=>{
  for(const [a1,a2] of [[12,42],[58,88]]){ const cx=(a1+a2)/2, rx=(a2-a1)/2;
    for(let pass=0;pass<2;pass++) for(let k=0;k<=60;k++){ const t=Math.PI*k/60, xx=Math.round(cx+rx*Math.cos(t)), yy=Math.round(31-27*Math.sin(t));
      if(pass===0) R('#',xx-2,yy-2,4,4); else R(k%6<3?'h':'F',xx-1,yy-1,2,2); } }
  R('#',0,28,100,8); R('f',1,29,98,2); R('e',1,31,98,5);
}); }
/* the bag's front: a folded kraft lip, a tall body with the family band printed across it, a side gusset and a bottom
   fold (100x44 art) */
function bagFrontA(fam){ const fc=FAM[fam]; return canv('bagfrontA|'+fam,100,44,(R)=>{
  R('#',0,3,100,41); R('h',1,4,98,39); R('b',1,4,1,38);
  for(let i=0;i<100;i++){ const t=i%6<3?i%6:6-i%6; R('#',i,3-t+0,1,1); R('h',i,4-t,1,t); if(t>0) R('b',i,4-t,1,1); }   // the cut zig-zag top
  R('F',1,6,98,1);
  for(const px of [14,30,70,86]) for(let j=7;j<38;j+=2) R('F',px,j,1,1);                                       // pleats
  R('F',91,4,8,39); R('f',90,4,1,39); R('h',94,6,1,34);
  R('#',0,12,100,1); R(fc[0],1,13,98,12); R(fc[1],1,13,98,1); R(fc[2],1,24,98,1); R(fc[2],91,14,8,10); R('#',0,25,100,1);
  for(let i=6;i<88;i+=6) R('a',i,31,3,1);                    // a dashed "packed" seam
  R('F',1,39,98,1); R('f',1,40,98,1); R('F',1,41,98,2);       // the bottom fold
}); }
/* the trolley: wire basket, tube rims, the grip, a shelf wire between the two rows, chassis and casters (422x114 art) */
function trolleyA(){ return canv('trolleyA',422,114,(R)=>{
  const fx=y=>Math.round(416-(y-6)*10/98);
  for(let y=7;y<104;y++){ const r=fx(y); R('K',11,y,r-11,1);
    for(let i=12;i<r;i++){ if((i-12)%6===0||(y-7)%6===0) R('J',i,y,1,1); if((i-12)%6===0&&(y-7)%6===0) R('H',i,y,1,1); } }
  const tube=(y,a,b)=>{ R('#',a,y,b-a,4); R('B',a,y+1,b-a,1); R('D',a,y+2,b-a,1); };
  tube(4,6,420); tube(104,8,fx(104)+4);
  R('#',6,0,5,110); R('B',7,4,1,105); R('D',8,4,2,105);
  for(let y=7;y<104;y++){ const r=fx(y); R('#',r,y,4,1); R('B',r+1,y,1,1); R('D',r+2,y,1,1); }
  R('#',0,0,20,7); R('6',1,1,18,1); R('4',1,2,18,3); R('3',1,5,18,1);
  R('#',14,108,400,3); R('D',15,109,398,1);
  for(const dx of [169,297]){ R('#',dx-1,8,4,45); R('B',dx,8,1,45); R('D',dx+1,8,1,45); }
  R('#',230,56,4,48); R('B',231,56,1,48); R('D',232,56,1,48);
  R('#',12,53,fx(53)-12,3); R('B',12,53,fx(53)-12,1); R('E',12,54,fx(53)-12,1);
}); }
/* the staff cork board in its wood frame (194x115 art) */
function corkA(){ return canv('corkA',194,115,(R)=>{
  const r=rng('cork'); R('#',0,0,194,115); R('f',1,1,192,113); R('F',2,2,190,1); R('e',3,3,188,109);
  R('#',4,4,186,107); R('F',5,5,184,105);
  for(let j=5;j<110;j++) for(let i=5;i<189;i++){ const v=r(); if(v<.07) R('f',i,j); else if(v<.12) R('h',i,j); }
  R('#',39,4,13,6); R('L',40,5,11,3); R('l',40,8,11,1); R('#',44,9,3,6); R('L',45,9,1,5);
  const strand=(a,b)=>{ for(let j=12;j<=25;j++){ const xx=Math.round(a+(b-a)*(j-12)/13); R('#',xx-1,j,4,1); R('4',xx,j,2,1); if(j%4===0) R('6',xx,j,1,1); } };
  strand(41,44); strand(50,47);
  R('#',42,25,8,5); R('L',43,26,6,3); R('n',43,26,2,1);
}); }
function page2A(){
  const s=st(), shown=packIdShown(), preview=hovPack>=0&&hovPack!==sel;
  let h=`<img class="bd" src="${backdrop(2,sel)}" alt="">`;
  /* --- the packing shelf: dark back panel under the three lamps, the steel board, the ticket rail --- */
  h+=`<div class="a" style="left:24px;top:168px;width:1872px;height:240px;background:var(--teal-black);border:3px solid var(--ink);border-bottom:0"></div>`+panelCone(2,sel,24,168,1872,240);
  h+=`<div class="a" style="left:18px;top:405px;width:1884px;height:21px;background:linear-gradient(var(--ink) 0 3px,var(--steel-hi) 3px 6px,var(--steel-light) 6px 12px,var(--steel) 12px 15px,var(--steel-dark) 15px 18px,var(--ink) 18px 21px)"></div>`;
  h+=`<div class="a" style="left:24px;top:426px;width:1872px;height:117px;background:var(--charcoal);border:3px solid var(--ink);border-top:0;box-shadow:inset 0 3px 0 var(--steel-darkest)"></div>`;
  for(const ux of [24,1875]) h+=`<div class="a" style="left:${ux}px;top:168px;width:21px;height:375px;background:var(--steel-shade);border:3px solid var(--ink);box-shadow:inset 3px 0 0 var(--steel-light)"></div>`;
  /* the hanging sign, centred under the middle lamp: two chains from its housing */
  h+=`<div class="a" style="left:888px;top:84px;width:3px;height:18px;background:var(--steel-dark)"></div><div class="a" style="left:1029px;top:84px;width:3px;height:18px;background:var(--steel-dark)"></div>`;
  h+=`<div class="a fr f-sign_staples" style="left:765px;top:99px;width:390px;height:69px;display:grid;justify-items:center;align-content:center;gap:3px">${PT('PICK A STARTER PACK',INK)}
     <span class="bt" style="font-size:20px;line-height:22px;font-weight:800;color:${sel<0?'var(--tomato-dark)':'var(--green-dark)'}">${sel<0?'Pick one to open the store':'Your pick rides in the cart'}</span></div>`;
  const slapNow = sel!==lastSel; lastSel=sel;
  s.packs.forEach((id,i)=>{
    const p=PACKS[id], fc=FAM[p.fam], x=48+i*612, on=sel===i, hv=hovPack===i&&!on, off=sel>=0&&!on&&!hv;
    const nameSc = PTW(p.name,6)<=480 ? 6 : 3; if(nameSc<6) bad('pack name steps down: '+p.name);
    const items=p.cards.map((c,j)=>`<span class="itm" data-card="${c}" style="left:${150+j*96}px">${sprite(c,96)}</span>`).join('');
    h+=`<div class="bagcol ${hv?'hov':''} ${on?'sel':''} ${off?'off':''}" data-pack="${i}" style="left:${x}px;top:180px;width:588px;height:363px">
      <span class="shadow"></span>
      <div class="lift ${on&&slapNow&&!RM?'hop2':''}">
        ${aimg(bagBackA(),144,0,300,108)}${items}${aimg(bagFrontA(p.fam),144,96,300,132)}
        <span class="a" style="left:165px;top:141px;width:45px;height:45px;background:var(--paper);border:3px solid var(--ink);display:grid;place-items:center;box-shadow:inset -3px -3px 0 var(--cream-shade)"><img src="${SRC}icons/${fc[3]}.png" style="width:27px;height:27px" alt=""></span>
        ${on?`<div class="stk pk ${slapNow&&!RM?'slap':''}" style="left:222px;top:132px;display:flex;align-items:center;gap:9px;padding:9px 15px">${NM('★',INK)}${PT('PICKED',INK)}${NM('★',INK)}</div>`:''}
      </div>
      ${s.first===id?`<span class="wspring" style="left:513px;top:204px;height:24px"></span>
        <div class="wob ${on&&slapNow&&!RM?'swing':''}" style="left:462px;top:90px;width:111px;height:117px">${PT('GOOD',INK)}${PT('FIRST',INK)}${PT('PICK',INK)}</div>`:''}
      <div class="tkt"><div class="strip" style="background:${fc[0]}"><span class="kb fr f-cream ${sel<0?'call':''}" style="display:grid;place-items:center;width:48px;height:48px">${NM(String(i+1),INK)}</span>
          <img src="${SRC}icons/${fc[3]}.png" style="width:27px;height:27px;outline:3px solid var(--ink);background:${fc[0]}" alt="${p.fam}"></div>
        <div class="a" style="left:96px;top:-3px">${PT(p.name,INK,nameSc)}</div>
        <div class="a bt" style="left:96px;top:63px;width:474px;font-size:18px;line-height:19px;color:var(--ink-light);text-wrap:pretty">${esc(p.hint)}</div></div></div>`;
  });
  /* --- the trolley: the cart recap, 15 places, the cards standing loose in the basket --- */
  const deck=deckOf(shown), n=deck.length, pk=shown?PACKS[shown]:null, pc=pinCards();
  h+=aimg(trolleyA(),24,555,1266,342);
  const tag=(x,y,label,count,cls)=>`<div class="ctag ${cls||''}" style="left:${x}px;top:${y}px">${L(label+(count!=null?' '+count:''),INK,3,{num:INK})}</div>`;
  const it=(c,x,y,o={})=>`<span class="titm ${o.pop?'drop':''}" data-card="${c}" style="left:${x}px;top:${y}px;${o.delay!=null?`animation-delay:${o.delay}ms`:''}"><span class="tsh"></span>${sprite(c,96)}</span>`;
  const R1T=582, R1=618, R2T=726, R2=768;
  h+=tag(78,R1T,'STAPLES',4)+staples().map((c,k)=>it(c,78+k*102,R1)).join('');
  const popNow = shown!==lastPack; lastPack=shown;
  if(pk){ if(preview) h+=`<span class="pvA" style="left:579px;top:${R1-6}px;width:312px;height:108px"></span>`;
    h+=pk.cards.map((c,j)=>it(c,585+j*102,R1,{pop:popNow&&!preview,delay:j*60})).join('');
    h+=tag(585,R1T,preview?'PREVIEW':'YOUR PACK',3,preview?'pv':''); }
  else { h+=[0,1,2].map(j=>`<span class="eslot want" style="left:${585+j*102}px;top:${R1}px">${PT('?',P.M,6)}</span>`).join('');
    h+=`<div class="ctag warn row" style="left:585px;top:${R1T}px;gap:9px">${PT('YOUR PACK',INK)}<span class="bt" style="font-size:18px;color:var(--tomato-dark)">pick one above</span></div>`; }
  h+=tag(948,R1T,'PIN CARDS',pc.length)+pc.map((c,j)=>it(c,948+j*102,R1,{pop:true})).join('')+Array.from({length:Math.max(0,2-pc.length)},(_,j)=>`<span class="eslot" style="left:${948+(pc.length+j)*102}px;top:${R1}px"></span>`).join('');
  h+=tag(78,R2T,"TODAY'S DEAL",6)+shared().map((c,k)=>it(c,78+k*102,R2)).join('');
  const fam={}; deck.forEach(c=>famsOf(CARD[c]).forEach(f=>fam[f]=(fam[f]||0)+1));
  const fl=Object.entries(fam).sort((x,y)=>y[1]-x[1]);
  const fchip=(f,k)=>`<span class="row" style="gap:6px" data-fam="${f}"><span style="display:grid;place-items:center;width:33px;height:33px;border:3px solid var(--ink);background:${FAM[f][0]};flex:none"><img src="${SRC}icons/${FAM[f][3]}.png" style="width:27px;height:27px" alt="${f}"></span>${NM(String(k),PAPER)}</span>`;
  /* the ad board on the trolley's side: YOUR CART n/15, the sum, and the top 3 families */
  // one line, never wrapped: a long one steps down a size, then says "pin" for "from pins"
  const capOf=pw=>`= 4 staples + ${pk?'3 '+pk.name+(preview?' (preview)':'')+' + ':''}6 dealt${pc.length?` + ${pc.length} ${pw}`:''}${pk?'':' · +3 when you pick a pack'}`;
  const capFs = atkW(capOf('from pins'),19)<=492 ? 19 : 17, pinW = atkW(capOf('from pins'),capFs)<=492 ? 'from pins' : 'pin';
  if(atkW(capOf(pinW),capFs)>492) bad('cart caption wraps: '+capOf(pinW));
  h+=`<div class="a fr f-plate" style="left:720px;top:726px;width:510px;height:141px;padding:0 3px">
     <div class="row" style="gap:12px">${PT('YOUR CART',P.y)}${NM(n+'/15',n>DECK_LIMIT?P.o:PAPER)}</div>
     <div class="bt" style="font-size:${capFs}px;line-height:22px;margin-top:6px;color:var(--teal-pale);height:44px;white-space:nowrap">= 4 staples + ${pk?(preview?'<b style="color:var(--mustard-light)">3 '+esc(pk.name)+' (preview)</b>':'3 '+esc(pk.name))+' + ':''}6 dealt${pc.length?` + ${pc.length} ${pinW}`:''}${pk?'':' · <b style="color:var(--tomato-pale)">+3 when you pick a pack</b>'}</div>
     <div class="row" style="gap:18px;margin-top:3px">${PT('BY FAMILY',P['5'])}${fl.slice(0,3).map(([f,k])=>fchip(f,k)).join('')}</div></div>`;
  /* --- badge pins: the cashier's lanyard and the pinned note on the staff cork board --- */
  const ws=worn.slice(0,SLOTS);
  h+=`<div id="pinsArea">${aimg(corkA(),1314,555,582,345)}`;
  h+=`<div class="a badge" style="left:1347px;top:639px;width:204px;height:219px;background:var(--cream);border:3px solid var(--ink);box-shadow:9px 9px 0 rgba(43,36,32,.45);display:flex;flex-direction:column">
     <div style="height:69px;flex:none;background:var(--teal);border-bottom:3px solid var(--ink);display:grid;place-items:center;gap:6px;padding:9px 0">${PT('NEXT',PAPER)}${PT('CUSTOMER',PAPER)}</div>
     <div style="display:grid;justify-items:center;padding-top:9px">${PT('CASHIER',P['3'])}</div>
     <div style="flex:1;display:flex;align-items:center;justify-content:center;gap:9px;padding-bottom:6px">${Array.from({length:SLOTS},(_,k)=>pinDisc(PIN[ws[k]],SLOTS>1?19:25)).join('')}</div></div>`;
  h+=`<div class="a fr f-slip" style="left:1575px;top:585px;width:297px;color:var(--ink)">
     <span class="a" style="left:126px;top:-21px;width:18px;height:18px;background:var(--tomato);border:3px solid var(--ink);box-shadow:inset -3px -3px 0 var(--tomato-dark)"></span>
     <div class="row" style="padding:0 3px 6px;border-bottom:3px solid var(--ink);gap:9px">${PT('BADGE PINS',P.u)}<span style="margin-left:auto">${L(ws.length+'/'+SLOTS,P.u,3)}</span></div>
     ${ws.length?ws.map(id=>{const p=PIN[id];return `<div class="row" style="margin-top:9px;padding:0 3px;gap:9px;align-items:flex-start">${pinDisc(p,13)}<div><div style="font:800 19px/22px var(--body)">${esc(p.name)}</div><div class="bt" style="font-size:17px;line-height:20px;color:var(--ink-light)">${ws.length===1?esc(p.rule):''}${p.cards?`${ws.length===1?' · ':''}<b style="color:var(--green-dark)">+1 card in your cart</b>`:''}</div></div></div>`;}).join('')
       :`<div class="row" style="margin-top:9px;padding:0 3px;gap:9px">${pinDisc(null,13)}<div style="font:800 19px/22px var(--body);color:var(--grey-dark)">No pin worn</div></div>`}
     ${ws.length<SLOTS?`<div class="bt" style="font-size:18px;line-height:22px;margin-top:9px;padding:0 3px;color:var(--ink-light)">${SLOTS-ws.length} slot free</div>`:''}</div>`;
  h+=`<div class="a fr f-teal row chg" style="left:1575px;top:810px;height:57px;padding:0 15px;gap:12px">${L('CHANGE PINS ›',PAPER)}</div></div>`;
  return h+counter(2);
}
