
/* ======================= page 2, look B: the staff room before the shift (recommended) ======================= */
/* One room on the 640x360 art grid, shown at 3x: a cinder-block wall under one fluorescent tube, a row of teal staff
   lockers (yours, No. 11, a double, stands open: one cork board holds the badge on its lanyard and the note of the pins
   you wear), a wooden bench with the three starter packs as produce crates (items standing whole on top, price tags on
   the lip, a stapled label; PICKED and GOOD FIRST PICK stay inside their crate), the order clipboard (the cart: 15
   numbered lines, each saying where the card comes from), the parked trolley (the same 15 as item art) and the time
   clock on the wall: clocking in punches the card, the shutter comes down and rolls up on SHIFT 1/12. */
function chDraw(x, s, X, Y, col){ let cx=X; x.fillStyle=col; for(const ch of s){ const g=CH[ch]; if(!g) continue; g.forEach((r,j)=>{ for(let i=0;i<r.length;i++) if(r[i]==='#') x.fillRect(cx+i,Y+j,1,1); }); cx+=g[0].length+1; } }
function roomArt(){ return canv('room',640,360,(R,x)=>{
  const r=rng('staffroom');
  /* the wall: cinder blocks in running bond, lit by the tube (one px in four on the faces, a checker near it) */
  R('%',0,28,640,332);
  const TX=322, face=(i,j)=>{ const row=(j-28)>>3, y8=(j-28)&7, off=row%2?8:0; return y8!==0 && ((i+off)&15)!==0; };
  for(let j=29;j<360;j++) for(let i=0;i<640;i++) if(face(i,j)){ const hw=70+(j-34)*1.05, d=Math.abs(i+.5-TX);
    let k='='; if(j<300&&d<hw){ const hot=j<96&&d<hw*.55; if(hot? (i+j)%2===0 : (i%2===0&&j%2===0)) k='-'; } R(k,i,j,1,1); }
  /* the fluorescent tube */
  R('#',246,28,152,7); R('D',247,28,150,3); R('E',247,31,150,1); R('w',250,32,144,2); R('A',250,34,144,1); R('#',246,32,4,3); R('#',394,32,4,3);
  /* cardboard stock boxes on top of the lockers */
  [[300,36,26,16],[328,42,20,10],[372,40,24,12]].forEach(([bx,by,bw,bh])=>{ R('#',bx,by,bw,bh+1); R('F',bx+1,by+1,bw-2,bh-1); R('h',bx+1,by+1,bw-2,1); R('f',bx+bw-3,by+1,2,bh-1); R('y',bx+Math.floor(bw/2)-1,by+1,3,bh-1); });
  /* the locker row's top ledge */
  R('#',6,52,426,5); R('3',7,53,424,2); R('5',7,53,424,1);
  /* your double locker (No. 11), open: frame, dark inside, a top shelf with a mug and the pin tin, one cork board */
  R('#',36,56,150,246); R('4',37,57,148,244); R('5',37,57,1,244); R('3',184,57,1,244);
  R('N',40,60,142,240); R('K',40,60,142,4); R('8',40,170,142,130);
  R('#',40,68,142,3); R('3',40,68,142,1);
  R('#',118,59,9,9); R('c',119,60,7,8); R('b',124,60,1,8); R('#',127,61,3,5); R('N',128,62,1,3); R('R',119,63,7,2);
  R('#',160,62,18,6); R('L',161,63,16,4); R('n',161,63,16,1); R('l',161,66,16,1); R('#',163,64,12,1);
  R('#',42,72,138,89); R('f',43,73,136,87); R('F',43,73,136,1); R('#',44,75,134,84);
  for(let j=76;j<158;j++) for(let i=45;i<177;i++){ const v=r(); R(v<.08?'h':v<.16?'f':v<.2?'e':'F',i,j,1,1); }
  // a coat hook with your apron, and a pair of shoes, below the board
  R('#',54,286,22,8); R('J',55,287,20,6); R('E',55,287,20,1); R('#',80,286,22,8); R('J',81,287,20,6); R('E',81,287,20,1);
  /* the door, swung open (seen almost edge-on): its inside face, vents, two hinges */
  R('#',8,58,28,244); R('3',9,59,26,242); R('2',12,62,20,236); R('4',9,59,26,1); R('2',34,59,1,242);
  for(let v=0;v<4;v++){ R('#',13,66+v*4,18,2); R('8',13,67+v*4,18,1); }
  for(let v=0;v<3;v++){ R('#',13,272+v*5,18,2); R('8',13,273+v*5,18,1); }
  [72,250].forEach(hy=>{ R('#',34,hy,3,8); R('B',35,hy+1,1,6); });
  /* the four closed lockers: vents, a brass number plate, a handle, kick vents */
  ['12','13','14','15'].forEach((no,k)=>{ const lx=188+k*60;
    R('#',lx,56,61,246); R('4',lx+1,57,59,244); R('5',lx+1,57,1,244); R('5',lx+1,57,59,1); R('3',lx+58,57,1,244); R('3',lx+1,300,59,1);
    for(let v=0;v<4;v++){ R('#',lx+14,64+v*4,32,2); R('2',lx+14,65+v*4,32,1); }
    R('#',lx+20,84,21,12); R('L',lx+21,85,19,10); R('n',lx+21,85,19,1); R('l',lx+21,94,19,1); chDraw(x,no,lx+21+Math.floor((19-11)/2),86,INK);
    R('#',lx+50,140,5,26); R('B',lx+51,141,3,24); R('A',lx+51,141,1,24);
    for(let v=0;v<3;v++){ R('#',lx+14,268+v*5,32,2); R('2',lx+14,269+v*5,32,1); } });
  /* the floor of the room (left of the pillar): a baseboard and a dark lino checker; right of it the wall runs down */
  R('N',0,299,436,3);
  for(let j=302;j<360;j++) for(let i=0;i<436;i++){ const row=(j-302)/6|0, off=row%2?8:0; R((((i+off)>>4)&1)?'I':'J',i,j,1,1); }
  R('N',442,353,198,2); R('I',442,355,198,5);
  /* the bench: a wooden seat on steel legs, its shadow on the floor */
  R('#',10,281,422,11); R('h',11,282,420,1); R('F',11,283,420,4); R('f',11,287,420,4);
  [30,216,404].forEach(lx=>{ R('#',lx,292,7,14); R('D',lx+1,292,5,13); R('E',lx+4,292,2,13); });
  for(let j=302;j<307;j++) for(let i=12;i<430;i++) if((i+j)%2===0) R('K',i,j,1,1);
  /* the pillar: the corner between the room and the clock wall */
  R('#',433,28,3,332); R('2',436,28,6,332); R('3',436,28,1,332);
}); }
/* the time clock's dial, small enough for the brass band: brass rim, cream face, hands at 8:59, a tomato second hand */
function clockFaceSmall(){ return canv('face18',18,18,(R,x)=>{
  for(let j=0;j<18;j++) for(let i=0;i<18;i++){ const t=Math.hypot(i+.5-9,j+.5-9); let k=null;
    if(t<=9) k='#'; if(t<=8) k=(i+j<16)?'n':'L'; if(t<=6.6) k='#'; if(t<=5.8) k='w'; if(k) R(k,i,j,1,1); }
  R('#',8,4,2,1); R('#',13,8,1,2); R('#',8,13,2,1); R('#',4,8,1,2);   // 12, 3, 6, 9
  R('#',8,4,2,5); R('#',5,8,4,2); R('R',10,10,2,1); R('R',12,11,1,1); R('R',8,8,2,2);
}); }
function dymo(text, x, y, o={}){ return `<div class="a dymo" style="left:${x}px;top:${y}px;background:${o.bg||P['8']};${o.extra||''}">${PT(text,o.fg||PAPER)}</div>`; }
/* the lit backing of the picked crate: a mustard glow dithered on the lockers behind its items */
function glowB(){ return canv('glowB',140,54,(R)=>{
  for(let j=0;j<54;j++) for(let i=0;i<140;i++){ const d=((i-70)/70)**2+((j-40)/42)**2; if(d>=1) continue;
    if(d<.32 ? (i+j)%2===0 : (i%2===0&&j%2===0)) R(d<.32?'m':'u',i,j,1,1); } }); }
/* the lanyard: a brass hook on the board and the two teal strands down to the badge's clip */
function lanyardB(){ return canv('lanyard',24,15,(R)=>{
  R('#',8,0,8,4); R('L',9,1,6,2); R('n',9,1,2,1);
  const strand=(a,b)=>{ for(let j=4;j<=12;j++){ const xx=Math.round(a+(b-a)*(j-4)/8); R('#',xx-1,j,4,1); R('4',xx,j,2,1); if(j%3===0) R('6',xx,j,1,1); } };
  strand(10,5); strand(14,19); R('#',3,12,18,3); R('L',4,12,16,2); R('n',4,12,4,1);
}); }
/* one starter pack as a produce crate on the bench */
function crateB(id, i, slapNow){
  const s=st(), p=PACKS[id], fc=FAM[p.fam], dark=DARK_FACE.has(p.fam), x=36+i*420, on=sel===i, hv=hovPack===i&&!on, off=sel>=0&&!on&&!hv;
  const pop=slapNow&&on&&!RM;
  if(PTW(p.name)>330-18-42-12-6) bad('crate name too wide: '+p.name);
  // crate 1 carrying GOOD FIRST PICK stacks above crate 2, whose dimming would otherwise cover the wobbler's right edge
  let h=`<div class="crate ${hv?'hov':''} ${on?'sel':''} ${off?'off':''} ${pop?'hopc':''}" data-pack="${i}" style="left:${x}px;top:540px;${i===0&&s.first===id?'z-index:6':''}">`;
  if(on) h+=`<img class="glow" src="${glowB()}" alt="">`;
  h+=`<div class="cback"></div>`;
  h+=`<div class="citems">${p.cards.map((c,j)=>`<div class="citem ${pop?'pop':''}" data-card="${c}" style="animation-delay:${j*60}ms">${sprite(c,96)}</div>`).join('')}</div>`;
  h+=`<div class="cfront"><span class="post l"></span><span class="post r"></span></div>`;
  h+=p.cards.map((c,j)=>{ const cx=39+j*111+48, cp=CARD[c].kind===2;
    return `<span class="ptagB ${cp?'cp':''}" data-card="${c}" style="left:${cx-33}px;width:66px">${cp?`<img src="${SRC}icons/family_coupon.png" style="width:27px;height:27px" alt="coupon">`:NM(CARD[c].base+'€',INK)}</span>`; }).join('');
  h+=`<div class="clabel">
      <div class="cname" style="background:${fc[0]}"><span class="nmw">${PT(p.name,dark?PAPER:INK)}</span>
        <span class="kb fr f-cream ${sel<0?'call':''}" style="display:grid;place-items:center;width:42px;height:42px;margin-left:auto;flex:none">${NM(String(i+1),INK)}</span></div>
      <div class="chint">${esc(p.hint)}</div>
      <div class="cfoot"><img src="${SRC}icons/${fc[3]}.png" style="width:27px;height:27px;background:${fc[0]};outline:3px solid var(--ink);margin-left:3px" alt="${p.fam}">${PT(p.fam.toUpperCase(),P['%'])}</div>
      <span class="staple" style="left:12px"></span><span class="staple" style="right:12px"></span>
      ${on?`<div class="stk pk ${slapNow&&!RM?'slap':''}" style="right:-18px;bottom:-18px">${PT('PICKED',INK)}</div>`:''}</div>`;
  if(on) h+=bulbRow(3,111,0,24,8,false)+bulbRow(375,111,0,24,8,false,1);
  else if(hv) h+=bulbRow(3,111,0,24,8,true)+bulbRow(375,111,0,24,8,true);
  // GOOD FIRST PICK: a wobbler above the crate's right end; on crate 1 it stands lower, at the crate's right edge, so it
  // keeps clear of the badge-pins cork board above it
  const wb = i===0 ? {sx:384,st:45,sh:15,wx:351,wy:-57} : {sx:363,st:-21,sh:81,wx:276,wy:-120};
  if(s.first===id) h+=`<span class="wspring" style="left:${wb.sx}px;top:${wb.st}px;height:${wb.sh}px"></span>
      <div class="wob ${on&&slapNow&&!RM?'swing':''}" style="left:${wb.wx}px;top:${wb.wy}px;width:111px;height:102px;${i===0?'z-index:6':''}">${PT('GOOD',INK)}${PT('FIRST',INK)}${PT('PICK',INK)}</div>`;
  return h+`</div>`;
}
/* the cart as an order sheet: 15 numbered lines (staples, pack, deal, pin cards), each with its mini, name, where it comes
   from, its price and a check box the clerk stamps when the line is filled; CART n/15 on an LED, BY FAMILY as count cards */
const TICKS = `<svg width="21" height="21" viewBox="0 0 7 7" shape-rendering="crispEdges"><path fill="${P.g}" d="M6 0h1v2h-1v1h-1v1h-1v1h-1v1h-1v1h-1v-1h-1v-2h1v1h1v-1h1v-1h1v-1h1v-1h1z"/></svg>`;
/* a pale tint of a family face over the order sheet's paper (hard colour, no alpha) */
function paleOf(hex){ const f=n=>parseInt(hex.slice(n,n+2),16), pp=[0xfb,0xf7,0xee]; return 'rgb('+[1,3,5].map((n,i)=>Math.round(f(n)*0.35+pp[i]*0.65)).join(',')+')'; }
function orderSheet(){
  const s=st(), shown=packIdShown(), preview=hovPack>=0&&hovPack!==sel, pk=shown?PACKS[shown]:null, pc=pinCards();
  const deck=deckOf(shown), n=deck.length, popNow=shown!==lastPack; lastPack=shown;
  const lines=[];
  staples().forEach((c,k)=>lines.push({c,from:swaps[k]?'your swap':'regular',g:'STAPLES'}));
  if(pk) pk.cards.forEach(c=>lines.push({c,from:pk.name,g:'PACK',pv:preview,pop:popNow&&!preview}));
  else for(let k=0;k<3;k++) lines.push({empty:true,g:'PACK',k});
  shared().forEach(c=>{ const a=aisleOf(c); lines.push({c,from:a==='staples'?'Staples shelf':AISLE[a].name,g:'DEAL'}); });
  worn.slice(0,SLOTS).forEach(id=>((PIN[id]&&PIN[id].cards)||[]).forEach(c=>lines.push({c,from:PIN[id].name+' pin',g:'PIN',pop:true})));
  while(lines.length<DECK_LIMIT) lines.push({empty:true,free:true,g:'PIN'});
  const X=1314, Y=105, W=582, H=756;
  let h=`<div class="a clipb" style="left:${X}px;top:${Y}px;width:${W}px;height:${H}px"></div>
    <div class="a paper" style="left:${X+21}px;top:${Y+24}px;width:${W-42}px;height:${H-48}px"></div>
    <div class="a clipB" style="left:${X+W/2-60}px;top:${Y-9}px"><span class="clipbar"></span></div>`;
  const PX=X+36, PW=W-72;
  h+=`<div class="a row" style="left:${PX}px;top:${Y+36}px;width:${PW}px;height:72px;gap:15px">${PT('ORDER SHEET',INK)}
      <span class="fr f-led row" style="margin-left:auto;height:72px;padding:0 6px;gap:12px"><img src="${SRC}icons/cart.png" style="width:36px;height:27px" alt="cart">${NM(n+'/15',n>DECK_LIMIT?P.o:P.n,6,P.k)}</span></div>`;
  // the sum line: one line, never wrapped (a long one steps down a size)
  const pinT = pc.length?` + ${pc.length} pin`:'';
  const plain = pk ? `4 staples + ${preview?'PREVIEW ':''}3 ${pk.name} + 6 dealt${pinT}` : `4 staples + 6 dealt${pinT} · +3 when you pick a crate`;
  const fs = atkW(plain,19)+(preview?30:0) <= PW ? 19 : 17;
  if(atkW(plain,fs)+(preview?30:0) > PW) bad('order sheet sum line too long');
  const packT = pk ? (preview?`<span class="pvchip">${PT('PREVIEW',INK)}</span><span style="color:var(--grey)">3 ${esc(pk.name)}</span>`:`3 ${esc(pk.name)}`)+' + ' : '';
  h+=`<div class="a bt" style="left:${PX}px;top:${Y+114}px;width:${PW}px;font-size:${fs}px;line-height:27px;color:var(--ink-light);white-space:nowrap">4 staples + ${packT}6 dealt${pinT}${pk?'':' · <b style="color:var(--tomato-dark)">+3 when you pick a crate</b>'}</div>`;
  h+=`<div class="a" style="left:${PX}px;top:${Y+147}px;width:${PW}px;height:9px;border-top:3px solid var(--ink);border-bottom:3px solid var(--ink)"></div>`;
  const LY=Y+162, LH=29;
  h+=`<div class="a sheetlines" style="left:${PX}px;top:${LY}px;width:${PW}px">`;
  let lastG=null;
  lines.forEach((ln,k)=>{
    const top=k*LH, first=ln.g!==lastG; lastG=ln.g;
    const no=`<span class="no">${NM(String(k+1).padStart(2,'0'),ln.empty?P[':']:P['-'])}</span>`;
    let body;
    if(ln.free) body=`${no}<span class="mini free"></span><span class="nmx" style="color:var(--grey)">free line</span><span class="fromx">for pin cards</span><span class="prx"></span><span class="ck off"></span>`;
    else if(ln.empty) body=`${no}<span class="mini empty">${PT('?',P.r)}</span><span class="nmx" style="color:var(--tomato-dark)">pick a crate</span><span class="fromx">${ln.k===0?`<span style="background:var(--mustard-pale);border:3px solid var(--mustard-dark);padding:0 6px;color:var(--ink)">press 1, 2 or 3</span>`:''}</span><span class="prx"></span><span class="ck want"></span>`;
    else {
      const c=CARD[ln.c], f=ticketFam(c), coupon=c.kind===2, mini=coupon?`${SRC}icons/coupon_${ln.c}_mini.png`:`${SRC}minis/${ln.c}.png`, pv=!!ln.pv;
      body=`${no}<span class="mini" style="background:${FAM[f][0]}"><img src="${mini}" style="width:${coupon?27:21}px;height:21px" alt=""></span>
        <span class="nmx" style="${pv?'color:var(--grey)':''}">${esc(c.name)}</span><span class="fromx" style="${ln.g==='PACK'&&!pv?'color:var(--ink);font-weight:800':''}">${esc(ln.from)}</span>
        <span class="prx">${coupon?NM('–',pv?P['-']:INK):NM(c.base+'€',pv?P['-']:INK)}</span>
        <span class="ck ${pv?'pv':'on'} ${ln.pop&&!RM?'stamp':''}" style="${ln.pop?`animation-delay:${120+(k%3)*90}ms`:''}">${pv?'':TICKS}</span>`;
    }
    const pkl=ln.g==='PACK'&&pk&&!ln.empty&&!ln.pv;
    h+=`<div class="ln ${first&&k?'first':''} ${ln.pop&&!RM?'drop':''} ${pkl?'pkl':''}" ${ln.c?`data-card="${ln.c}"`:''} style="top:${top}px;${pkl?`background:${paleOf(FAM[pk.fam][0])};`:''}${ln.pop?`animation-delay:${(k%3)*90}ms`:''}">${body}</div>`;
  });
  h+=`</div>`;
  // the starter pack's 3 lines: a bar in the pack's colour in the sheet's left margin (dashed while only previewed)
  if(pk){ const k0=lines.findIndex(l=>l.g==='PACK'); h+=`<div class="a pkbar ${preview?'pv':''}" style="left:${PX-18}px;top:${LY+k0*LH-3}px;height:${3*LH}px;background:${preview?'transparent':FAM[pk.fam][0]}"></div>`; }
  // BY FAMILY: three count cards at the sheet's foot (big digit, glyph, name)
  const fam={}; deck.forEach(c=>famsOf(CARD[c]).forEach(f=>fam[f]=(fam[f]||0)+1));
  const fl=Object.entries(fam).sort((x,y)=>y[1]-x[1]).slice(0,3);
  const FY=LY+15*LH;
  h+=`<div class="a row" style="left:${PX}px;top:${FY}px;width:${PW}px;border-top:3px solid var(--ink);padding-top:6px;gap:12px">${PT('BY FAMILY',P['%'])}<span class="bt" style="font-size:17px;line-height:20px;color:var(--grey-dark)">top 3 · a card can be in 2</span></div>`;
  h+=`<div class="a row" style="left:${PX}px;top:${FY+36}px;width:${PW}px;gap:12px;align-items:flex-start">
     ${fl.map(([f,k])=>`<div class="fcardB" data-fam="${f}"><span class="fct" style="background:${FAM[f][0]}"></span><div class="row" style="gap:9px"><span style="display:grid;place-items:center;width:33px;height:33px;border:3px solid var(--ink);background:${FAM[f][0]};flex:none"><img src="${SRC}icons/${FAM[f][3]}.png" style="width:27px;height:27px" alt=""></span>${NM(String(k),INK,6)}</div><div class="bt" style="font-size:17px;line-height:20px;color:var(--ink)">${f}</div></div>`).join('')}</div>`;
  return h;
}
/* your open locker: one cork board holds the badge on its lanyard and the note of the pins you wear */
function lockerPins(){
  const ws=worn.slice(0,SLOTS);
  let h=`<div class="pinsarea" id="pinsArea">`;
  h+=dymo('BADGE PINS',141,192,{extra:'z-index:2'});
  h+=aimg(lanyardB(),189,231,72,45);
  h+=`<div class="a badge" style="left:141px;top:270px;width:168px;height:186px;background:var(--cream);border:3px solid var(--ink);box-shadow:9px 9px 0 rgba(43,36,32,.45);display:flex;flex-direction:column">
     <div style="height:57px;flex:none;background:var(--teal);border-bottom:3px solid var(--ink);display:grid;place-items:center;gap:3px;padding:6px 0">${PT('NEXT',PAPER)}${PT('CUSTOMER',PAPER)}</div>
     <div style="display:grid;justify-items:center;padding-top:6px">${PT('CASHIER',P['3'])}</div>
     <div style="flex:1;display:flex;align-items:center;justify-content:center;gap:9px;padding-bottom:6px">${Array.from({length:SLOTS},(_,k)=>pinDisc(PIN[ws[k]],SLOTS>1?19:25)).join('')}</div></div>`;
  h+=`<div class="a note" style="left:324px;top:237px;width:228px">
     <span class="tape"></span>
     <div class="row" style="gap:9px">${PT('WEARING',P.u)}${L(ws.length+'/'+SLOTS,P.u,3)}</div>
     ${ws.length?ws.map(id=>{const p=PIN[id];return `<div style="margin-top:9px"><div style="font:800 19px/22px var(--body);color:var(--ink)">${esc(p.name)}</div>${ws.length===1?`<div class="bt" style="font-size:17px;line-height:20px;margin-top:3px;color:var(--ink-light)">${esc(p.rule)}</div>`:''}${p.cards?`<div class="bt" style="font-size:17px;line-height:20px;color:var(--green-dark)">+1 card in your cart</div>`:''}</div>`;}).join('')
       :`<div style="margin-top:9px;font:800 19px/22px var(--body);color:var(--grey-dark)">No pin worn</div>`}
     <div class="bt" style="font-size:17px;line-height:20px;margin-top:9px;color:var(--teal-shade)">${ws.length<SLOTS?`${SLOTS-ws.length} slot free · `:''}click to change</div></div>`;
  return h+`</div>`;
}
function keycapS(k){ return `<span class="fr f-cream" style="display:inline-grid;place-items:center;vertical-align:middle;width:30px;height:30px;border-width:6px">${PT(k,INK,2)}</span>`; }
/* the time clock on the wall right of the pillar: brass band with its dymo and dial, the card slot, the one primary key */
function timeClock(){
  const s=st(), p=sel>=0?PACKS[s.packs[sel]]:null, n=deckOf(sel>=0?s.packs[sel]:null).length, on=!!p;
  const X=1335, Y=876, W=561, H=192;
  let h=`<div class="a tclock" style="left:${X}px;top:${Y}px;width:${W}px;height:${H}px">
    <div class="a fr f-plaque" style="left:0;top:0;width:${W}px;height:${H}px"></div>
    <div class="a tband"></div>
    ${dymo('TIME CLOCK',24,9,{bg:P['#'],fg:P.Y})}
    ${aimg(clockFaceSmall(),W-81,6,54,54)}
    <div class="a cardbay"><div class="tcard ${on?'in':''}" id="tcard"><span class="tch">${PT('IN',PAPER)}</span><span class="tcl"></span><span class="tcp"></span></div></div>
  </div>`;
  h+=primaryKey2(on?'OPEN STORE ›':'PICK A PACK FIRST', on?`Clock in · ${p.name} · ${n} cards`:'Pick a crate, or press 1, 2 or 3', on, 'go', X+108, Y+66, W-129, 111);
  return h;
}
function primaryKey2(cap, sub, on, id, x, y, w, hh){
  const big = PTW(cap.replace(' ›',''),6) + 48 <= w-18;
  const capHTML = big ? L(cap, on?PAPER:INK, 6) : L(cap, on?PAPER:INK, 3);
  return `<div class="key fr ${on?'f-red on':'f-off dis'}" id="${id}" style="left:${x}px;top:${y}px;width:${w}px;height:${hh}px">${on?TICK:''}
    <div style="display:grid;justify-items:center;gap:6px;margin-top:-6px">${capHTML}<div class="bt" style="color:${on?'var(--paper)':'var(--ink)'};font-size:20px;line-height:24px;white-space:nowrap">${esc(sub)}</div></div></div>`;
}
/* the trolley parked in front of the bench: the 15 cards as item art, in cart order, so the build reads at a glance */
function trolleyB(){
  const shown=packIdShown(), preview=hovPack>=0&&hovPack!==sel, pk=shown?PACKS[shown]:null, pc=pinCards(), popNow=shown!==lastPackT; lastPackT=shown;
  const groups=[{cards:staples()},{cards:pk?pk.cards:[null,null,null],pack:true},{cards:shared()},{cards:pc.concat(Array(Math.max(0,2-pc.length)).fill(undefined)).slice(0,2)}];
  const X0=432, TY=906, STEP=51, GAP=24;
  let x=X0, items='', marks='';
  groups.forEach((g,gi)=>{ const gx=x;
    g.cards.forEach((c,j)=>{
      if(c===null) items+=`<span class="tre want" style="left:${x}px;top:${TY}px">${PT('?',P.o)}</span>`;
      else if(c===undefined) items+=`<span class="tre" style="left:${x}px;top:${TY}px"></span>`;
      else items+=`<span class="tri ${g.pack&&popNow&&!preview&&!RM?'pop':''}" data-card="${c}" style="left:${x}px;top:${TY}px;animation-delay:${j*60}ms">${sprite(c,48)}</span>`;
      x+=STEP; });
    if(g.pack&&preview) marks+=`<span class="trpv" style="left:${gx-6}px;top:${TY-6}px;width:${x-gx+9}px;height:60px"></span>`;
    if(g.pack&&pk&&!preview) marks+=`<span class="trpk" style="left:${gx-9}px;top:${TY-9}px;width:${x-gx+15}px;height:66px;border-color:${FAM[pk.fam][0]}"></span><span class="trtag" style="left:${gx-9}px;top:${TY-33}px;background:${FAM[pk.fam][0]}">${PT('PACK',DARK_FACE.has(pk.fam)?PAPER:INK)}</span>`;
    x+=GAP-3; });
  const AW=Math.ceil((x-(GAP-3)-X0+12)/3);
  const art=canv('trolleyB'+AW,AW+12,40,(R)=>{
    R('#',0,0,8,5); R('6',1,1,6,1); R('4',1,2,6,2); R('#',2,5,3,28); R('B',3,5,1,27);         // grip and post
    R('#',4,6,AW+4,2); R('D',4,6,AW+4,1);                                                   // back rim
    for(let v=8;v<19;v++) for(let u=6;u<AW+8;u++) if((u%3===0)||(v%3===0)) R('J',u,v,1,1);   // back mesh behind the items
    R('#',4,18,AW+6,3); R('B',4,19,AW+6,1);                                                 // the top rim the items stand in
    const fe=v=>AW+8-Math.round((v-21)*.8);                                                  // the basket's front slants in
    for(let v=21;v<31;v++){ const e=fe(v); R('K',6,v,e-6,1); for(let u=6;u<e;u+=3) R('J',u,v,1,1); if(v%3===0) R('J',6,v,e-6,1); R('#',e,v,2,1); R('B',e,v,1,1); }
    R('#',6,31,fe(31)-4,2); R('D',6,31,fe(31)-4,1); R('#',10,33,AW-10,2);                   // basket floor and chassis
    [16,AW-4].forEach(cx=>{ for(let j=-3;j<=3;j++) for(let i=-3;i<=3;i++){ const d=Math.hypot(i,j); if(d<=3.2) R(d>2.3?'#':'D',cx+i,36+j,1,1); } });
  });
  return aimg(art,X0-36,TY-9,(AW+12)*3,120)+marks+items;
}
let lastPackT=null;
function page2B(){
  const s=st();
  const slapNow = sel!==lastSel; lastSel=sel;
  let h=`<img class="bd" src="${roomArt()}" alt="">`;
  h+=`<div class="a tube ${hopTab&&!RM?'flick':''}"></div>`;
  /* the notice taped over the closed lockers: the page's one question, and a second line that answers the pick */
  h+=`<div class="a notice" style="left:603px;top:297px;width:642px;padding:18px 24px 12px">
     <span class="tape" style="left:24px"></span><span class="tape" style="right:24px"></span>
     <div class="row" style="justify-content:center">${PT('PICK A STARTER PACK',INK,6)}</div>
     <div class="bt" style="text-align:center;margin-top:9px;font-size:22px;line-height:27px;"><b style="color:${sel<0?'var(--tomato-dark)':'var(--green-dark)'}">${sel<0?'Pick one to open the store':'Your pick rides in the cart'}</b></div></div>`;
  h+=lockerPins();
  s.packs.forEach((id,i)=>{ h+=crateB(id,i,slapNow); });
  h+=orderSheet();
  /* the floor: ◀ STORE on its plaque, the parked trolley, the hints; the time clock on the wall */
  h+=plaque(18,948,354,120);
  h+=`<div class="plate fr f-teal" id="back" style="left:48px;top:972px;width:294px;height:72px;padding:0 15px;justify-content:center">${NM('‹',PAPER)}${PT('STORE',PAPER)}</div>`;
  h+=trolleyB();
  h+=`<div class="a row bt" style="left:402px;top:1029px;gap:9px;color:var(--steel-light)">${keycap('ESC')} back, choices kept ${keycap('1')}${keycap('2')}${keycap('3')} pick a crate ${keycap('P')} pins ${keycap('ENTER')} clock in</div>`;
  h+=timeClock();
  return h;
}
