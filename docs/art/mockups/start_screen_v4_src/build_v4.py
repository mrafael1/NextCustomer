"""Builds start_screen_v4.html from start_screen_v3.html (page 1 unchanged) and the round-4 page 2 sources here."""
import io, os
H = os.path.dirname(os.path.abspath(__file__)); M = os.path.dirname(H)
U = lambda p: io.open(p, encoding='utf-8').read().replace('\r\n', '\n')
s = U(os.path.join(M, 'start_screen_v3.html'))
def rep(a, b, n=1):
    global s
    assert s.count(a) == n, (s.count(a), a[:80]); s = s.replace(a, b)
rep('<title>Start Screen Split</title>', '<title>Start Screen v4</title>')
rep('.selfcheck{', U(os.path.join(H, 'p2.css')) + '\n.selfcheck{')
rep('<div class="seg" id="segG"><button data-g="1" aria-pressed="true">1 Your store</button><button data-g="2">2 Your build</button></div>',
    '<div class="seg" id="segG"><button data-g="1" aria-pressed="true">1 Your store</button><button data-g="2">2 Your build</button></div>\n'
    '    <span class="lbl">PAGE 2 LOOK</span>\n'
    '    <div class="seg" id="segL"><button data-l="A">A Bagging counter</button><button data-l="B" aria-pressed="true">B Staff room</button><button data-l="C">C End-cap</button></div>')
a = s.index('<main>'); b = s.index('</main>') + len('</main>')
s = s[:a] + U(os.path.join(H, 'main.html')).strip() + s[b:]
rep("  sheet: ['.########.'", "  led: ['##########','#DDDDDDDD#','#D######H#'].concat(rep('#D#NNNN#H#',4),['#D######H#','#HHHHHHHH#','##########']), // LED shelf display (machine ledGlass)\n  sheet: ['.########.'")
# the counter belongs to its page (so it slides with it); page 2 B has its own floor and time clock
rep('function counter(){', 'function counter(pg){')
rep('  if(PAGE===1){\n    h+=backPlate', '  if(pg===1){\n    h+=backPlate')
rep("    h+=backPlate('back','STORE');",
    "    if(p&&LOOK==='C'){ const bl=[]; for(let k=0;k<19;k++) bl.push([1416+k*24,51]); for(let k=0;k<4;k++){ bl.push([1389,78+k*24]); bl.push([1884,78+k*24]); }\n"
    "      h+=bl.map(([x,y],k)=>`<span class=\"blb ${k%2?'b':'a'}\" style=\"left:${x}px;top:${y}px\"></span>`).join(''); } // C: the key's plaque lights up like the end-cap\n"
    "    h+=backPlate('back','STORE');")
rep('function page1(){\n', 'function page1(){ return page1Body()+counter(1); }\nfunction page1Body(){\n')
a = s.index('/* ======================= page 2: YOUR BUILD ======================= */'); b = s.index('/* ======================= modals (TitlePopup sheets) ======================= */')
s = s[:a] + ''.join(U(os.path.join(H, f)) + '\n' for f in ['p2_common.js', 'p2_A.js', 'p2_B.js', 'p2_C.js']) + \
    "function page2(){ return LOOK==='A' ? page2A() : LOOK==='C' ? page2C() : page2B(); }\n\n" + s[b:]
rep('const s=st(), w=900, x=1920-w-48, y=108;', "const s=st(), w=900, x=PAGE===2&&LOOK==='B'?390:1920-w-48, y=108;")
rep("F.className='F'+(RM?' rm':'');", "F.className='F'+(RM?' rm':'')+' lk'+LOOK;")
rep('h+=`<div class="chrome">${topBar()}${stepRail()}${counter()}</div>`;', 'h+=`<div class="chrome">${topBar()}${stepRail()}</div>`;')
a = s.index('function go(){'); b = s.index("document.addEventListener('keydown'")
s = s[:a] + U(os.path.join(H, 'go.js')) + '\n' + s[b:]
rep("if(Q.get('page')) QP.page=+Q.get('page');", "if(Q.get('page')) QP.page=+Q.get('page');\nif(['A','B','C'].includes(Q.get('p2'))) LOOK=Q.get('p2');")
rep("  if(Q.get('sel')) sel=+Q.get('sel');", "  if(Q.get('sel')) sel=+Q.get('sel');\n  if(Q.get('hov')) hovPack=+Q.get('hov');   // capture hook: a pack under the pointer (its preview in the cart)")
rep("  if(Q.get('solo')){ soloSetup(); render(); }\n  else fit();", "  if(Q.get('solo')){ soloSetup(); render(); }\n  else fit();\n  if(Q.get('shutter')){ const sh=shutterEl(); sh.classList.add('shown'); F.appendChild(sh); }   // capture hook: the shutter down (after the solo render)")
rep("/* URL hooks: ?page=1|2&s=0..3", "/* URL hooks: ?p2=A|B|C&hov=0..2&shutter=1&page=1|2&s=0..3")
rep("seg('segM','m',v=>{RM=v==='1';render();});", "seg('segM','m',v=>{RM=v==='1';render();});\nseg('segL','l',v=>{ LOOK=v; lastSel=sel; lastPack=packIdShown(); modal=null; render(); });")
rep("  document.querySelectorAll('#segM button')", "  document.querySelectorAll('#segL button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.l===LOOK));\n  document.querySelectorAll('#segM button')")
rep("c.innerHTML = `Page ${PAGE} · ", "c.innerHTML = `Page ${PAGE}${PAGE===2?' (look '+LOOK+')':''} · ")
# OPEN STORE locks the page: no input may re-render (and wipe the shutter) or stack a second go() until the final reset()
rep("if(e.target.closest('.sheet')||ANIM){ tip.style.display='none'; return; }", "if(e.target.closest('.sheet')||ANIM||GOING){ tip.style.display='none'; return; }")
rep("F.addEventListener('mouseover',e=>{\n  if(modal||ANIM) return;", "F.addEventListener('mouseover',e=>{\n  if(modal||ANIM||GOING) return;")
rep("F.addEventListener('mouseleave',()=>{ if(ANIM) return;", "F.addEventListener('mouseleave',()=>{ if(ANIM||GOING) return;")
rep("const T=e.target; if(ANIM) return;", "const T=e.target; if(ANIM||GOING) return;")
rep("  if(p===PAGE||modal||ANIM) return;\n  hovPack=-1;", "  if(p===PAGE||modal||ANIM||GOING) return;\n  hovPack=-1;")
rep("function toTitle(){\n  if(modal||ANIM) return;", "function toTitle(){\n  if(modal||ANIM||GOING) return;")
rep("document.addEventListener('keydown',e=>{\n  if(e.key==='Escape')", "document.addEventListener('keydown',e=>{\n  if(GOING) return;\n  if(e.key==='Escape')")
rep("PAGE=QP.page||1; ANIM=null;", "PAGE=QP.page||1; ANIM=null; GOING=false;")
rep("g.addEventListener('click',e=>{const b=e.target.closest('button');", "g.addEventListener('click',e=>{if(GOING)return;const b=e.target.closest('button');")
rep("document.getElementById('reset').onclick=()=>{QP.page=PAGE;reset();};", "document.getElementById('reset').onclick=()=>{if(GOING)return;QP.page=PAGE;reset();};")
io.open(os.path.join(M, 'start_screen_v4.html'), 'w', encoding='utf-8', newline='\n').write(s)
print('ok', len(s))

# REGULARS (user, 2026-11-03): the 4 every-run cards are YOUR REGULARS; the 6-product shelf stays the Staples shelf
import re
for a, z in [('YOUR STAPLES','YOUR REGULARS'), ('STAPLES 4','REGULARS 4'), ('SWAP A STAPLE','SWAP A REGULAR'), ('Staple swaps','Regular swaps'),
             ('Swapped staple','Swapped regular'), ('staple swap','regular swap'), ('swapped staples','swapped regulars'), ('swapped staple','swapped regular'),
             ('4 staples','4 regulars'), ('every staple','every regular'), ('first staple','first regular'), ('your 4 staples','your 4 regulars')]:
    s = s.replace(a, z)
io.open(os.path.join(M, 'start_screen_v4.html'), 'w', encoding='utf-8', newline=chr(10)).write(s)
print('renamed')
