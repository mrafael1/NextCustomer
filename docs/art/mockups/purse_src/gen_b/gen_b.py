"""Builds purse_b.html, purse_b_count_up.html and purse_b_states.html in docs/art/mockups (#76, direction B).

The two scene pages patch planning_effects_h1.html (approved "just perfect"); the states page is a sheet of its own.
Standard library only. Run from anywhere: python docs/art/mockups/purse_src/gen_b/gen_b.py
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sprites  # noqa: E402

MOCKUPS = HERE.parents[1]
pal = sprites.palette()
sprites.check(pal)
DATA = {
    'pal': {k: v for k, v in pal.items() if v},
    'wallet': {s: sprites.wallet(s) for s in sprites.STATES},
    'face': sprites.FACE,
    'mini': sprites.MINI,
}
JS = (HERE / 'purse.js').read_text(encoding='utf-8')
CSS = (HERE / 'purse.css').read_text(encoding='utf-8')
LIB = f'<script>\nconst PURSE = {json.dumps(DATA, separators=(",", ":"))};\n</script>\n<script>\n{JS}</script>\n'


def sub(s, old, new):
    if old not in s:
        sys.exit('missing: ' + old[:90])
    return s.replace(old, new, 1)


def cut(s, start, end, new):
    a = s.find(start)
    b = s.find(end, a)
    if a < 0 or b < 0:
        sys.exit('missing block: ' + start[:60])
    return s[:a] + new + s[b:]


HEADER = """<!--
  PURSE, DIRECTION B (#76 decide prep, 2026-10-19; nothing decided): the rich customer's WALLET on the counter and its
  FACE-LIKE BUDGET TAG, which carries the quota as a minimum spend ("BUDGET at least €73") and REPLACES the quota bar:
  the top bar's QUOTA chip in planning, the monitor's LED quota row during the count. Built on planning_effects_h1.html.
  - The tag is a cream hang-tag with a face. Its stitched pocket fills with notes as the shown total rises (the old bar's
    fill fraction, display only); at the budget a mustard rubber stamp with a check lands on it; past it notes spill out.
  - The wallet sits at spot A (canvas at (284, 292), body Rect2(284, 352, 52, 40); left of x 336 so the print-out shade leaves it lit), brown leather,
    mustard stud, a debossed euro sign on its front (review fix: the little tag read as a robot face). Five steps on total / budget: S0 slim < 0.5,
    S1 strain 0.5, S2 bursting 0.9, S3 open at 1.0, S4 overstuffed 1.5 (display ratios, @export tuning in data/balance/).
  - Sweat drops, sparkles and the gleam are stickers (loops); reduced motion drops them and keeps the pose.
  Generator: purse_src/gen_b/gen_b.py (sprites.py, purse.js, purse.css).
-->
"""

QUOTA_CHIP = ('<div class="chip" style="flex:1"><span class="k">QUOTA</span><span class="v">€73</span><span class="bar">'
              '<i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€182</span></div>')


def budget_chip(amount):
    return (f'<div class="chip budget" style="flex:1"><div class="bhold" id="btagHold"></div>'
            f'<span class="v amt" style="color:var(--mustard-light)">{amount}</span><span class="bslot"></span></div>')


def scene(title, amount, script, extra=None):
    s = (MOCKUPS / 'planning_effects_h1.html').read_text(encoding='utf-8')
    s = sub(s, '<title>Planning effects h1</title>', f'<title>{title}</title>\n' + HEADER)
    s = sub(s, QUOTA_CHIP, budget_chip(amount))
    s = sub(s, '<span>QUOTA €73</span>', '<span>BUDGET €73+</span>')  # review fix: one word for the quota on screen
    s = sub(s, '</head>', f'<style>\n{CSS}</style>\n</head>')
    if extra:
        s = extra(s)
    s = sub(s, '</body>', LIB + f'<script>\n{script}\n</script>\n</body>')
    return s


# ---------- page 1: planning, h1's row projecting €182 against €73: S4 ----------
PLAN = """document.fonts.ready.then(() => {
const st = document.getElementById('stage'), h = document.getElementById('btagHold');
PB.tag(h, { w: h.clientWidth, state: 's4', fill: 1, met: true, over: true });
PB.wallet(st, 's4', 284, 292, { z: 6 });
});"""

# ---------- page 2: mid count-up, Milk 7's x3 just landed: subtotal €119 of €73 (the ding rang at €77): S4 at its strongest ----------
MON_CU = '''<div class="abs monitor"><div class="screen cu">
    <div class="art"><img class="px" src="assets/art/items_v2/milk.png" style="width:96px;height:96px"><div class="kind">MILK</div><div class="kind" style="font-size:12px;margin-top:0">7 / 7</div></div>
    <div class="col">
      <div class="row1"><span class="lbl">SUBTOTAL</span><span class="step">×3 Multipack</span></div>
      <div style="position:relative"><div class="big">€119</div><div class="gain" style="right:0;top:18px">+€42</div></div>
      <div class="qrow" id="ledrow"><span class="togo"><b>+€46</b> over</span></div>
    </div>
  </div></div>

  '''

RECEIPT_CU = '''<div class="abs receipt">
    <div class="h">NEXT CUSTOMER · REG 3</div>
    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>
    <div class="dash"></div>
    <div class="ln"><span class="nm">Eggs</span><span>€1.00</span></div>
    <div class="ln"><span class="nm">Bread</span><span>€10.00</span></div>
    <div class="ln"><span class="nm">Milk</span><span>€0.00</span></div>
    <div class="ln"><span class="nm">Multipack</span><span>€0.00</span></div>
    <div class="ln"><span class="nm">Milk</span><span>€21.00</span></div>
    <div class="ln"><span class="nm">Milk</span><span>€24.00</span></div>
    <div class="ln on"><span class="nm">Milk</span><span>€63.00</span></div>
    <div class="ln sub"><span class="nm">×3 Multipack</span><span>+€42.00</span></div>
    <div class="dash"></div>
    <div class="ln ghost"><span class="nm" style="font-family:Pixelify;font-size:15px">TOTAL</span><span>·····</span></div>
  </div>

  '''


def count_extra(s):
    s = cut(s, '<div class="abs monitor"><div class="screen brief">', '<!-- receipt rising', MON_CU)
    s = cut(s, '<div class="abs receipt">', '<div class="abs key checkout">', RECEIPT_CU)
    s = sub(s, '<div class="abs key checkout">', '<div class="abs key checkout counting">')
    return s


COUNT = """document.fonts.ready.then(() => {
const st = document.getElementById('stage'), h = document.getElementById('btagHold');
PB.tag(h, { w: h.clientWidth, state: 's4', fill: 1, met: true, over: true });
const row = document.getElementById('ledrow');
const t = PB.tag(row, { w: 196, state: 's4', fill: 1, met: true, over: true });
row.insertBefore(t, row.firstChild);
PB.wallet(st, 's4', 284, 292, { z: 6, lift: 4 });
// counting: the hand is shaded, the scanned item is bracketed (as in the B2 count-up)
const sh = document.createElement('div'); sh.className = 'cshade'; st.appendChild(sh);
const x = 368 + 6 * 128 + 8, y0 = 388 - 112, y1 = 388 - 18;
[['l', 't'], ['r', 't'], ['l', 'b'], ['r', 'b']].forEach(([a, b]) => { const d = document.createElement('div'); d.className = 'scanbrk';
  Object.assign(d.style, { left: (a === 'l' ? x - 14 : x + 94) + 'px', top: (b === 't' ? y0 : y1) + 'px',
    borderLeftWidth: a === 'l' ? '4px' : 0, borderRightWidth: a === 'r' ? '4px' : 0, borderTopWidth: b === 't' ? '4px' : 0, borderBottomWidth: b === 'b' ? '4px' : 0 });
  st.appendChild(d); });
});"""

# ---------- page 3: the states sheet ----------
STATES_HTML = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Purse B states</title>
""" + HEADER + """<style>
@font-face { font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }
@font-face { font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }
@font-face { font-family: JBMono; src: url(../../../fonts/JetBrainsMono-Regular.ttf); }
:root { --ink: #2b2420; --ink-light: #4a3f38; --muted: #8a8172; --paper: #fbf7ee; --mustard: #e2b33c; --mustard-light: #f1d27a;
  --mustard-pale: #faecbc; --teal-panel: #2a4d4b; --teal-dark: #1f3b3a; --wood: #a8703a; --wood-light: #c98c4e; --wood-dark: #6e4524; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 1280px; height: 720px; overflow: hidden; background: var(--teal-dark); }
.px { image-rendering: pixelated; }
.sheet { position: relative; width: 1280px; height: 720px; font-family: Atkinson, sans-serif; color: var(--paper); padding: 10px 16px; }
h1 { font-family: Pixelify; font-weight: 400; font-size: 22px; letter-spacing: 1px; color: var(--mustard-pale); }
h1 small { font-family: Atkinson; font-size: 13px; font-weight: 600; letter-spacing: 0; color: #c7beab; margin-left: 10px; }
.sec { font-family: Pixelify; font-size: 12px; letter-spacing: 2px; color: #86c2b6; margin: 6px 0 3px; }
.row { display: flex; gap: 8px; }
.card { position: relative; background: var(--teal-panel); border: 2px solid var(--ink); border-radius: 6px; padding: 6px 7px; overflow: hidden;
  box-shadow: inset 0 -3px 0 rgba(0,0,0,.25); }
.card .nm { font-family: Pixelify; font-size: 15px; color: var(--paper); }
.card .nm b { font-weight: 400; color: var(--mustard-light); margin-right: 5px; }
.card .nm .am { float: right; font-family: Atkinson; font-weight: 750; font-size: 15px; color: var(--mustard-light); }
.card .tr { font-size: 11.5px; font-weight: 650; color: #c3e0d4; line-height: 14px; margin-top: 1px; height: 28px; }
.card .sd { margin-top: 3px; font-size: 11px; font-weight: 600; color: #c7beab; line-height: 13px; }
.card .sd b { color: var(--mustard-pale); font-weight: 700; }
.counter { position: relative; overflow: hidden; margin: 4px -7px 4px; background: var(--wood); border-top: 2px solid var(--ink); border-bottom: 2px solid var(--ink); }
.counter::before { content: ""; position: absolute; left: 0; right: 0; top: 0; height: 4px; background: var(--wood-light); }
.tagrow { display: flex; align-items: center; gap: 6px; background: var(--teal-dark); border: 2px solid var(--ink); border-radius: 4px; padding: 2px; height: 42px; justify-content: flex-start; }
.tagrow .amt { font-family: Atkinson; font-weight: 750; font-size: 17px; color: var(--mustard-light); white-space: nowrap; }
.tagrow .amt.drag { color: var(--mustard-pale); font-size: 15px; }
.btag { position: relative; height: 34px; flex: none; }
.btag canvas.tagc { position: absolute; left: 0; top: 0; }
.btag .tt { position: absolute; top: 3px; white-space: nowrap; color: #2b2420; line-height: 1; }
.btag .tt .k2 { display: block; font-family: Pixelify; font-size: 11px; letter-spacing: 1px; color: #4a3f38; line-height: 12px; }
.btag .tt .q { display: block; font-family: Atkinson; font-weight: 750; font-size: 15px; line-height: 16px; }
.thank { position: absolute; z-index: 9; font-family: Pixelify; font-size: 12px; letter-spacing: 1px; color: var(--ink); background: var(--mustard);
  border: 2px solid var(--ink); padding: 1px 5px; box-shadow: 2px 2px 0 rgba(20,14,10,.45); transform: rotate(-4deg); }
.grey { filter: grayscale(1); }
.gl { position: absolute; left: 6px; bottom: 3px; font-family: Pixelify; font-size: 11px; color: var(--paper); text-shadow: 1px 1px 0 var(--ink); z-index: 9; }
.note { font-size: 11px; font-weight: 600; color: #c7beab; line-height: 14px; }
.note b { color: var(--mustard-pale); }
</style>
</head>
<body>
<div class="sheet" id="sheet">
  <h1>Purse B · the wallet and its budget tag<small>#76 decide prep · direction B · nothing decided · quota €73 (shift 5/8) · steps are total ÷ budget, display only</small></h1>
  <div class="sec">THE LADDER · planning: the projected total · count-up: the running subtotal (beats only, never per tick)</div>
  <div class="row" id="ladder"></div>
  <div class="sec">DRAG · VERDICT · REDUCED MOTION</div>
  <div class="row" id="row2"></div>
  <div class="sec">GREYSCALE · the same frames and tags with no colour: pose, props, the face and the stamp carry every step</div>
  <div class="row" id="row3"></div>
</div>
""" + LIB + """<script>
document.fonts.ready.then(() => {
const mk = (parent, w, html) => { const d = document.createElement('div'); d.className = 'card'; d.style.width = w + 'px'; d.innerHTML = html; parent.appendChild(d); return d; };
const counter = (card, h) => { const c = document.createElement('div'); c.className = 'counter'; c.style.height = h + 'px'; card.appendChild(c); return c; };
const tagrow = (card, o) => { const r = document.createElement('div'); r.className = 'tagrow'; card.appendChild(r); PB.tag(r, o); return r; };

// ---- the ladder: wallet at 3x (1 texel = 6 px on the 1920 capture), the tag at its real size ----
const L = [
  ['s0', 'S0', 'Slim', 'total < 0.5 × budget (under €37)', 0.33, '€24', 'none'],
  ['s1', 'S1', 'Straining', '≥ 0.5 × (€37–65): bulges, a card pokes out', 0.71, '€52', 'none (pose swap only)'],
  ['s2', 'S2', 'Bursting', '≥ 0.9 × (€66–72): notes poke, the stud strains', 0.93, '€68', '<b>tick</b> once on entering'],
  ['s3', 'S3', 'Budget met', '≥ 1.0 × (€73+): flap pops, tag stamped', 1, '€80', '<b>tag</b> + the ding already there'],
  ['s4', 'S4', 'Overstuffed', '≥ 1.5 × (€110+): spills, sweats, gleams', 1, '€182', '<b>coin_1–3</b> jingle, once'],
];
const lad = document.getElementById('ladder');
L.forEach(([s, k, nm, tr, f, amt, snd]) => {
  const c = mk(lad, 242, `<div class="nm"><b>${k}</b>${nm}<span class="am">${amt}</span></div><div class="tr">${tr}</div>`);
  const ct = counter(c, 146);
  PB.wallet(ct, s, 82, 146 - 52 * 3 + 2, { t: 3 });
  tagrow(c, { w: 222, state: s, fill: f, met: f >= 1, over: s === 's4' });
  c.insertAdjacentHTML('beforeend', `<div class="sd">sound: ${snd}</div>`);
});

// ---- drag, verdicts, reduced motion: wallet at the stage's own size ----
const r2 = document.getElementById('row2');
const R2 = [
  ['hop', 'Drag +', '› €58 (+6)', 'would-be total rises: a hop', 'none (no hover sounds)', { state: 's1', fill: 0.79 }],
  ['slump', 'Drag −', '› €48 (−4)', 'would-be total falls: a sag', 'none', { state: 'short', fill: 0.66 }],
  ['over', 'OVER', '€182', 'pays out into the drawer', '<b>coin_2</b> under stamp_paid', { state: 'over', fill: 1, met: true, line1: 'PAID · THANK YOU', line2: '+€109 over' }],
  ['on', 'ON QUOTA', '€73', 'a satisfied snap shut', '<b>tick</b> as the clasp', { state: 'on', fill: 1, met: true, line1: 'BUDGET', line2: 'spent: €73' }],
  ['short', 'SHORT', '€52', 'half full, sags; ink tag', 'none (fail plays)', { state: 'short', fill: 0.71, line1: 'SHE WANTED TO', line2: 'spend €21 more' }],
  ['s4', 'Reduced motion', '€182', 'S4 pose, loops off', 'as S4', { state: 's4', fill: 1, met: true, over: true }],
];
R2.forEach(([s, nm, amt, tr, snd, to]) => {
  const c = mk(r2, 202, `<div class="nm">${nm}<span class="am">${amt}</span></div><div class="tr">${tr}</div>`);
  const ct = counter(c, 92);
  PB.wallet(ct, s, 74, 92 - 104 + 2, { fx: nm !== 'Reduced motion', lift: s === 'hop' ? 6 : 0 });
  if (s === 'over') ct.insertAdjacentHTML('beforeend', '<span class="thank" style="left:122px;top:22px">THANK YOU</span>');
  tagrow(c, Object.assign({ w: 182 }, to));
  c.insertAdjacentHTML('beforeend', `<div class="sd">sound: ${snd}</div>`);
});

// ---- greyscale proof: every frame and two tags, no colour ----
const r3 = document.getElementById('row3');
[['s0', 'S0'], ['s1', 'S1'], ['s2', 'S2'], ['s3', 'S3'], ['s4', 'S4'], ['hop', 'drag +'], ['slump', 'drag −'], ['over', 'OVER'], ['on', 'ON'], ['short', 'SHORT']].forEach(([s, nm]) => {
  const c = mk(r3, 82, ''); c.classList.add('grey'); c.style.padding = '0';
  const ct = counter(c, 80); ct.style.margin = '0';
  PB.wallet(ct, s, 15, 80 - 104 + 2, { lift: s === 'hop' ? 6 : 0 });
  ct.insertAdjacentHTML('beforeend', `<span class="gl">${nm}</span>`);
});
const tg = mk(r3, 404, ''); tg.classList.add('grey'); tg.style.display = 'flex'; tg.style.flexDirection = 'column'; tg.style.gap = '2px'; tg.style.padding = '2px 6px';
[{ state: 's1', fill: 0.71 }, { state: 's4', fill: 1, met: true, over: true }].forEach(o => tagrow(tg, Object.assign({ w: 372 }, o)));
});
</script>
</body>
</html>
"""


def main():
    (MOCKUPS / 'purse_b.html').write_text(scene('Purse B', '€182', PLAN), encoding='utf-8')
    (MOCKUPS / 'purse_b_count_up.html').write_text(scene('Purse B count-up', '€119', COUNT, count_extra), encoding='utf-8')
    (MOCKUPS / 'purse_b_states.html').write_text(STATES_HTML, encoding='utf-8')
    print('wrote purse_b.html, purse_b_count_up.html, purse_b_states.html')


if __name__ == '__main__':
    main()
