
/* ======================= page 2, look C: the display end-cap, standing in its aisle ======================= */
/* The end-cap at the head of an aisle, at night, in the premium toy machine's language. The store has depth now: a lino
   floor in perspective runs back to the aisle, a gondola run recedes behind the pins easel, and the light of the
   end-cap pools on the floor. The unit: a lit STARTER PACKS marquee on brass posts, three promo bays (a key tag hanging
   under the marquee, a family-colour topper with the name, the 3 products standing big on a brass shelf with price-gun
   tags, a clipped talker with the hint). Picking a bay lights it like a prize (bulbs chase down its posts, its light burns
   hot, a gold PICKED hangs beside its key) and the other two go dark. In front of it, YOUR CART is a flatbed stock
   trolley: the 15 cards in one row in cart order, a tag on the deck edge under each group. Beside the trolley a price
   board carries the LED n/15 and the top 3 families; BADGE PINS hang on a velvet card on an easel. */
const BAYC = i => 48 + i*528;          // screen x of bay i; 504 wide, from y 240 to 630
function sceneC(selI, hovI){ return canv('sceneC|'+selI+'|'+hovI,640,360,(R)=>{
  R('1',0,28,640,332);
  /* the back wall over the unit: dim shelving, as on page 1 */
  const r=rng('endcap');
  for(let bx=2;bx<636;){ const bw=4+Math.floor(r()*8), bh=6+Math.floor(r()*10), col=STOCK_COL[Math.floor(r()*STOCK_COL.length)][0]; R(col,bx,52-bh,Math.min(bw,636-bx),bh); bx+=bw+1+Math.floor(r()*3); }
  R('8',0,52,640,2); R('8',0,28,640,3);
  /* the gondola run receding to the right of the unit (vanishing point at 300,150) */
  const VX=300, VY=150;
  for(let i=546;i<640;i++){ const s=(i-VX)/340;
    for(let j=31;j<214;j++){ const yp=(j-VY)/s; if(yp<-128||yp>=64) continue;
      const row=Math.floor((yp+128)/36), loc=(yp+128)-row*36, z=Math.floor(8/s*3);
      if(loc<2.2/s) R(loc<1/s?'2':'8',i,j,1,1);
      else { const h=((row*131+z*71)%97)/97, top=36*(.35+h*.4); R(loc>36-top?STOCK_COL[(row*3+z)%STOCK_COL.length][0]:'8',i,j,1,1); } } }
  /* the floor: a lino checker in perspective, the end-cap's light pooled on it */
  for(let j=214;j<360;j++) for(let i=0;i<640;i++){ const d=j-VY+40, row=Math.floor(2400/d), col=Math.floor((i-VX)*24/d);
    R((row+col)%2?'2':'1',i,j,1,1);
    if(row!==Math.floor(2400/(d+1))) R('8',i,j,1,1);                                        // grout between tile rows
    const pool=j<230&&i>14&&i<540&&(i-16)%176<168; if(pool&&(j<220?(i+j)%2===0:(i%4===0&&j%2===0))) R('u',i,j,1,1); }
  for(let i=8;i<546;i++) for(let j=214;j<218;j++) if((i+j)%2===0||j<216) R('N',i,j,1,1);   // the unit's shadow
  /* the end-cap unit: marquee, posts, three bays */
  R('#',8,56,536,26); R('l',9,57,534,24); R('L',9,57,534,1); R('k',9,80,534,1); R('#',11,60,530,19); R('N',12,61,528,17);
  for(let j=62;j<78;j+=2) R('K',12,j,528,1);
  for(let bx=12;bx<540;bx+=24){ R('L',bx,59,1,1); R('L',bx,79,1,1); }
  for(let b=0;b<3;b++){
    const bx=16+176*b, on=b===selI, hv=b===hovI&&!on, off=selI>=0&&!on&&!hv;
    R('8',bx,82,168,128);
    R(off?'1':'2',bx,99,168,74); R(off?'2':'3',bx,99,168,1);
    for(let j=101;j<173;j+=4) for(let k=bx+2;k<bx+166;k+=4) R('8',k,j,1,1);
    // the bay's display light under the topper and its dithered cone over the products
    const cx=bx+84;
    if(!off) for(let j=123;j<173;j++){ const sh=(j-123)/50, half=Math.round(20+54*sh);
      for(let k=Math.max(bx+1,cx-half);k<Math.min(bx+167,cx+half);k++){ if((k-bx-2)%4===0&&(j-101)%4===0) continue;
        const dot = on&&sh<.35 ? (k+j)%2===0 : (k%2===0&&j%2===0); if(dot) R(on?'m':hv?'l':'u',k,j,1,1); } }
    R('#',cx-18,122,36,3); R('L',cx-17,122,34,1); R('l',cx-17,123,34,1); R('#',cx-14,125,28,1); R(on?'n':hv?'y':off?'l':'Y',cx-14,124,28,1);
    // the shelf: ink, a lit lip, brass, the price channel, ink; then the dark back behind the talker
    R('#',bx,173,168,1); R('y',bx,174,168,1); R('L',bx,175,168,2); R('l',bx,177,168,10); R('k',bx,178,168,1); R('#',bx,187,168,1);
    if(on){ R('L',bx,82,168,2); R('n',bx,82,168,1); }
  }
  for(const px of [8,184,360,536]){ R('#',px,81,8,130); R('L',px+1,81,6,130); R('y',px+2,81,1,130); R('l',px+5,81,1,130); for(let j=88;j<206;j+=8) R('k',px+3,j,2,3); }
  R('#',8,210,536,4); R('l',9,211,534,2); R('L',9,211,534,1);
  /* the pins easel's legs and the price board's feet */
  [[556,206],[626,206]].forEach(([lx,ly])=>{ R('#',lx,ly,4,12); R('L',lx+1,ly,2,12); });
  R('#',552,209,82,3); R('l',553,210,80,1);
  /* the flatbed stock trolley: deck, trimmed edge, three casters, its handle at the right end */
  R('#',16,263,480,14); R('B',17,264,478,1); R('D',17,265,478,3); R('#',16,268,480,1); R('L',17,269,478,1); R('E',17,270,478,6); R('H',17,275,478,1);
  [40,252,470].forEach(cx=>{ R('#',cx-1,277,3,3); R('D',cx,277,1,3); for(let j=-3;j<=3;j++) for(let i=-3;i<=3;i++){ const d=Math.hypot(i,j); if(d<=3.2) R(d>2.3?'#':'J',cx+i,283+j,1,1); } });
  for(let i=14;i<500;i++) for(let j=286;j<289;j++) if((i+j)%2===0) R('N',i,j,1,1);
  R('#',494,222,6,47); R('B',495,222,1,46); R('D',496,222,2,46); R('#',488,216,14,7); R('6',489,217,12,1); R('4',489,218,12,3); R('3',489,221,12,1);
}); }
/* the velvet of the pins card: a brass frame, wine velvet with a soft nap and a darker edge (82x120 art) */
function velvetC(){ return canv('velvetC',82,120,(R)=>{
  R('#',0,0,82,120); R('L',1,1,80,118); R('y',1,1,80,1); R('y',1,1,1,118); R('l',1,118,80,1); R('l',80,1,1,118);
  R('#',3,3,76,114); R('q',4,4,74,112);
  for(let j=4;j<116;j++) for(let i=4;i<78;i++){ const e=Math.min(i-4,77-i,j-4,115-j); if(e<2&&(i+j)%2===0) R('#',i,j,1,1); else if((i*7+j*13)%17===0) R('r',i,j,1,1); }
  R('#',8,6,66,13); R('L',9,7,64,11); R('y',9,7,64,1); R('l',9,17,64,1); R('k',11,12,2,2); R('k',69,12,2,2);
}); }
function prodC(id, l, t, opt={}){
  return `<div class="prodC ${opt.pop?'drop':''}" data-card="${id}" style="left:${l}px;top:${t}px;${opt.delay!=null?`animation-delay:${opt.delay}ms;`:''}"><span class="psh"></span>${sprite(id,144)}</div>`;
}
function priceTagC(id, l, t){
  const c=CARD[id];
  return c.kind===2 ? `<span class="ptagC cp" data-card="${id}" style="left:${l}px;top:${t}px"><img src="${SRC}icons/family_coupon.png" style="width:27px;height:27px" alt="coupon"></span>`
                    : `<span class="ptagC" data-card="${id}" style="left:${l}px;top:${t}px">${NM(c.base+'€',INK)}</span>`;
}
function bayC(id, i, slapNow){
  const s=st(), p=PACKS[id], fc=FAM[p.fam], dark=DARK_FACE.has(p.fam), on=sel===i, hv=hovPack===i&&!on, off=sel>=0&&!on&&!hv, gf=s.first===id;
  const nameSc = PTW(p.name,6)<=504-30 ? 6 : 3; if(nameSc<6) bad('pack name steps down: '+p.name);
  let h=`<div class="bayC ${on?'on':''} ${hv?'hov':''} ${off?'off':''}" data-pack="${i}" style="left:${BAYC(i)}px;top:240px;width:504px;height:390px">`;
  // under the marquee: the key tag (right), GOOD FIRST PICK (left) and, once picked, the gold PICKED sticker
  h+=`<span style="left:465px;top:0;width:6px;height:6px;background:var(--brass-dark)"></span>`;
  h+=`<span class="keyC kb fr f-cream ${sel<0?'call':''}" style="left:444px">${NM(String(i+1),INK)}</span>`;
  if(gf) h+=`<div class="gfC" style="left:12px;top:3px">${PT('GOOD FIRST PICK',INK)}</div>`;
  if(on) h+=`<div class="stk pk ${slapNow&&!RM?'slap':''}" style="left:${gf?285:12}px;top:0">${gf?'':NM('★',INK)}${PT('PICKED',INK)}${gf?'':NM('★',INK)}</div>`;
  h+=`<div class="topC" style="background:${fc[0]};box-shadow:inset 0 3px 0 ${fc[1]},inset 0 -3px 0 ${fc[2]}${on?',0 0 0 3px var(--gold),0 0 0 6px var(--ink)':''},0 6px 0 rgba(23,44,43,.6)"><span class="nmw">${PT(p.name,dark?PAPER:INK,nameSc)}</span></div>`;
  h+=p.cards.map((c,k)=>prodC(c,24+k*156,135)+priceTagC(c,24+k*156+39,288)).join('');
  h+=`<div class="talkC"><span style="display:grid;place-items:center;width:33px;height:33px;border:3px solid var(--ink);background:${fc[0]};flex:none"><img src="${SRC}icons/${fc[3]}.png" style="width:27px;height:27px" alt="${p.fam}"></span><span class="bt">${esc(p.hint)}</span></div>
    <span class="tclipC" style="left:60px"></span><span class="tclipC" style="left:426px"></span>`;
  return h+`</div>`;
}
function page2C(){
  const s=st(), shown=packIdShown(), preview=hovPack>=0&&hovPack!==sel;
  let h=`<img class="bd" src="${sceneC(sel,hovPack)}" alt="">`;
  /* --- the marquee: STARTER PACKS, bulbs chasing along its top --- */
  h+=bulbRow(36,162,24,0,66,false);
  h+=`<div class="a" style="left:27px;top:189px;width:1608px;display:flex;justify-content:center">${PT('STARTER PACKS',P.k,6)}</div>`;
  h+=`<div class="a" style="left:24px;top:186px;width:1608px;display:flex;justify-content:center">${PT('STARTER PACKS',P.n,6)}</div>`;
  h+=`<div class="a" style="left:54px;top:198px">${L('PICK 1 OF 3',P.y,3,{num:P.n})}</div>`;
  h+=`<div class="a bt" style="right:${1920-1602}px;top:195px;font-weight:800;color:${sel<0?'var(--paper)':'var(--mustard-pale)'}">${sel<0?'Pick one to open the store':'3 cards that start your build'}</div>`;
  /* --- the three bays; the picked one's posts chase, a hovered one burns steady --- */
  const slapNow = sel!==lastSel; lastSel=sel;
  s.packs.forEach((id,i)=>{ h+=bayC(id,i,slapNow); });
  [[sel,false],[hovPack!==sel?hovPack:-1,true]].forEach(([b,steady])=>{ if(b<0) return; const lx=BAYC(b)-21, rx=BAYC(b)+507;
    h+=bulbRow(lx,258,0,24,15,steady)+bulbRow(rx,258,0,24,15,steady,1); });
  /* --- YOUR CART: the flatbed stock trolley, 15 cards in one row --- */
  const deck=deckOf(shown), n=deck.length, pk=shown?PACKS[shown]:null, pc=pinCards(), popNow=shown!==lastPack; lastPack=shown;
  h+=`<div class="a row" style="left:48px;top:651px;gap:18px">${PT('YOUR CART',P.y)}<span class="bt" style="font-size:20px;line-height:21px;color:var(--teal-pale)">4 staples + ${pk?(preview?'<b style="color:var(--mustard-light)">3 from '+esc(pk.name)+' (preview)</b>':'3 from '+esc(pk.name))+' + ':''}6 dealt${pc.length?` + ${pc.length} from pins`:''}${pk?'':' · <b style="color:var(--tomato-pale)">+3 when you pick a pack</b>'}</span></div>`;
  const TY=699, STEP=90, GAP=18;
  let x=66;
  const tagC=(l,inner,cls='')=>`<div class="stagC ${cls}" style="left:${l}px;top:801px">${inner}</div>`;
  // staples
  let gx=x; staples().forEach(c=>{ h+=`<div class="trC" data-card="${c}" style="left:${x}px;top:${TY}px">${sprite(c,96)}</div>`; x+=STEP; }); h+=tagC(gx,L('STAPLES 4',INK,3)); x+=GAP;
  // the pack: its 3, a preview in a dashed mustard frame, or 3 dashed facings and a "pick one above" tag
  gx=x;
  if(pk){ if(preview) h+=`<div class="pvwC" style="left:${x-9}px;top:${TY-9}px;width:${3*STEP+12}px;height:114px"></div>`;
    pk.cards.forEach((c,j)=>{ h+=`<div class="trC ${popNow&&!preview&&!RM?'drop':''}" data-card="${c}" style="left:${x}px;top:${TY}px;animation-delay:${j*60}ms">${sprite(c,96)}</div>`; x+=STEP; });
    h+=tagC(gx,L((preview?'PREVIEW':'YOUR PACK')+' 3',INK,3),preview?'mus':''); }
  else { for(let j=0;j<3;j++){ h+=`<div class="efcC" style="left:${x}px;top:${TY}px">${PT('?',P.M,6)}</div>`; x+=STEP; }
    h+=tagC(gx,`${PT('YOUR PACK',INK)}<span class="bt" style="font-size:18px;line-height:21px;color:var(--tomato-dark);font-weight:800">pick one</span>`,'mus'); }
  x+=GAP;
  // today's deal
  gx=x; shared().forEach(c=>{ h+=`<div class="trC" data-card="${c}" style="left:${x}px;top:${TY}px">${sprite(c,96)}</div>`; x+=STEP; }); h+=tagC(gx,L("TODAY'S DEAL 6",INK,3)); x+=GAP;
  // pin cards: the pins' cards, then dashed free places
  gx=x; for(let j=0;j<2;j++){ const c=pc[j]; h+= c ? `<div class="trC drop" data-card="${c}" style="left:${x}px;top:${TY}px">${sprite(c,96)}</div>` : `<div class="efcC free" style="left:${x}px;top:${TY}px"></div>`; x+=STEP; }
  h+=tagC(gx,L('PINS '+pc.length,INK,3));
  if(x-STEP+96>1482) bad('trolley row past the deck');
  /* --- the price board beside the trolley: the LED n/15 and the top 3 families --- */
  h+=`<div class="a fr f-plaque" style="left:1530px;top:648px;width:366px;height:252px"></div>`;
  h+=`<div class="ledC fr f-led" style="left:1551px;top:663px;width:324px;height:72px"><img src="${SRC}icons/cart.png" style="width:36px;height:27px" alt="cart">${NM(n+'/15',n>DECK_LIMIT?P.o:P.n,6,P.k)}</div>`;
  h+=`<div class="a row" style="left:1554px;top:744px;gap:12px">${PT('BY FAMILY',INK)}<span class="bt" style="font-size:18px;line-height:21px;color:var(--ink-light)">top 3</span></div>`;
  const fam={}; deck.forEach(c=>famsOf(CARD[c]).forEach(f=>fam[f]=(fam[f]||0)+1));
  Object.entries(fam).sort((x,y)=>y[1]-x[1]).slice(0,3).forEach(([f,k],j)=>{
    h+=`<div class="fcardC" data-fam="${f}" style="left:${1551+j*111}px;top:774px;width:102px"><span class="fct" style="background:${FAM[f][0]}"></span>
      <span style="display:grid;place-items:center;width:33px;height:33px;border:3px solid var(--ink);background:${FAM[f][0]}"><img src="${SRC}icons/${FAM[f][3]}.png" style="width:27px;height:27px" alt=""></span>${NM(String(k),INK,6)}
      <span class="bt" style="font-size:16px;line-height:18px;color:var(--ink)">${f}</span></div>`; });
  /* --- BADGE PINS: the velvet card on its easel --- */
  const ws=worn.slice(0,SLOTS);
  h+=`<div class="pinsarea" id="pinsArea">${aimg(velvetC(),1650,258,246,360)}`;
  h+=`<div class="a" style="left:1674px;top:282px;width:198px;display:flex;justify-content:center">${PT('BADGE PINS',P.k)}</div>`;
  h+=`<div class="a badge" style="left:1683px;top:330px;width:180px;height:165px;background:var(--cream);border:3px solid var(--ink);box-shadow:9px 9px 0 rgba(23,8,12,.55);display:flex;flex-direction:column">
     <div style="height:60px;flex:none;background:var(--teal);border-bottom:3px solid var(--ink);display:grid;place-items:center;gap:3px;padding:6px 0">${PT('NEXT',PAPER)}${PT('CUSTOMER',PAPER)}</div>
     <div style="display:grid;justify-items:center;padding-top:6px">${PT('CASHIER',P['3'])}</div>
     <div style="flex:1;display:flex;align-items:center;justify-content:center;gap:9px;padding-bottom:3px">${Array.from({length:SLOTS},(_,k)=>pinDisc(PIN[ws[k]],SLOTS>1?19:25)).join('')}</div></div>`;
  h+=`<div class="a" style="left:1671px;top:510px;width:204px;display:grid;gap:3px;text-align:center">${ws.length?ws.map(id=>`<div style="font:800 19px/22px var(--body);color:var(--mustard-pale)">${esc(PIN[id].name)}${PIN[id].cards?' <span style="color:var(--green-light)">+1 card</span>':''}</div>`).join(''):`<div style="font:800 19px/22px var(--body);color:var(--tomato-pale)">No pin worn</div>`}${ws.length<SLOTS?`<div class="bt" style="font-size:17px;line-height:20px;color:var(--tomato-pale)">${SLOTS-ws.length} slot free</div>`:''}</div>`;
  h+=`<div class="plate fr f-teal row" style="left:1680px;top:561px;width:186px;height:48px;justify-content:center;gap:9px">${L('CHANGE ›',PAPER)}</div></div>`;
  return h+counter(2);
}
