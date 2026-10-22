"""Builds the direction C purse mock-ups (#76, decide prep): purse_c.html, purse_c_count_up.html and purse_c_states.html.

Direction C, the "grin purse": a brown leather kiss-lock coin purse on the counter by the register whose two clasp knobs
are its eyes and whose opening is its mouth. The bigger the total against the quota, the wider it grins and the higher
its fan of notes and card rises. A paper tag hanging from its hinge carries the framing: "SPEND €73+".

Patches planning_effects_h1.html (the approved h1 page, already mirrored) the way gen_h1 patches its base. The sprites
come from purse_sprites.py and are painted from palette keys in the page. Standard library only. Run from anywhere:
    python docs/art/mockups/purse_src/gen_c/gen_c.py
"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import purse_sprites as P  # noqa: E402

MOCKUPS = HERE.parents[1]  # docs/art/mockups
BASE = (MOCKUPS / 'planning_effects_h1.html').read_text(encoding='utf-8')
SPRITES = P.all_sprites()


def sub(s, old, new, count=1):
    if old not in s:
        sys.exit('missing: ' + old[:80])
    return s.replace(old, new, count)


# ------------------------------------------------------------------ shared: the painter, the tag, the CSS
PAINTER = '''
const PURSE_PAL = %s;
const PURSE_SPR = %s;
const PURSE_W = %d, PURSE_H = %d;
// paints one pose at `scale` screen px per art px (2 in the game)
function purseCanvas(name, scale) {
  const c = document.createElement('canvas'); c.width = PURSE_W; c.height = PURSE_H; c.className = 'px';
  c.style.width = PURSE_W * scale + 'px'; c.style.height = PURSE_H * scale + 'px';
  const g = c.getContext('2d');
  PURSE_SPR[name].forEach((row, j) => [...row].forEach((k, i) => { if (k !== '.') { g.fillStyle = PURSE_PAL[k]; g.fillRect(i, j, 1, 1); } }));
  return c;
}
''' % (json.dumps(P.PALETTE), json.dumps(SPRITES), P.W, P.H)

CSS = '''
/* ================= #76 direction C: the grin purse ================= */
.purse { position: absolute; z-index: 6; }
.purse canvas { display: block; }
/* the paper tag on a string from the purse's left hinge: the quota as a minimum spend */
.ptag { position: absolute; z-index: 6; width: 50px; height: 34px; background: #fbf7ee; border: 2px solid #2b2420;
  box-shadow: inset 2px 2px 0 #ffffff, inset -2px -2px 0 #ddcba5, 4px 2px 0 rgba(20,14,10,.42);
  clip-path: polygon(8px 0, 100% 0, 100% 100%, 8px 100%, 0 calc(100% - 8px), 0 8px);
  display: flex; flex-direction: column; align-items: center; justify-content: center; padding-left: 6px; color: #2b2420; }
.ptag::before { content: ''; position: absolute; left: 4px; top: 13px; width: 4px; height: 4px; background: #2b2420; }
.ptag .pk { font-family: Pixelify; font-size: 10px; line-height: 10px; letter-spacing: 1px; color: #4a3f38; }
.ptag b { font-family: Atkinson; font-weight: 800; font-size: 15px; line-height: 16px; white-space: nowrap; }
.ptag.met { width: 68px; }
.ptag.met b { font-size: 14px; }
.ptag.wide { width: 86px; }
.ptag.wide b { font-size: 13px; }
.ptag .ck { position: absolute; left: -2px; bottom: -2px; width: 14px; height: 14px; background: #5fae5a; border: 2px solid #2b2420;
  font: 800 10px/10px Atkinson; color: #fbf7ee; display: flex; align-items: center; justify-content: center; }
.pstring { position: absolute; z-index: 6; overflow: visible; }
'''

# the purse in the scene: grid left edge at x 274 (body x 284..336), grid top at y 296 (body foot on y 400)
SCENE_X, SCENE_Y = 274, 296


def scene_js(pose, tag_html, tag_cls=''):
    return PAINTER + '''
(() => {
  const d = document.createElement('div'); d.className = 'purse'; d.dataset.disp = '1';
  d.style.left = '%dpx'; d.style.top = '%dpx'; d.appendChild(purseCanvas('%s', 2)); stage.appendChild(d);
  // the string: from the left hinge (art 7,31 -> screen 288,358) down to the tag's hole
  const s = document.createElementNS(NS, 'svg'); s.setAttribute('class', 'pstring'); s.dataset.disp = '1';
  s.setAttribute('width', 60); s.setAttribute('height', 30); s.style.left = '232px'; s.style.top = '350px';
  s.setAttribute('shape-rendering', 'crispEdges');
  s.innerHTML = '<rect x="54" y="8" width="2" height="2" fill="#2b2420"/><rect x="52" y="10" width="2" height="2" fill="#2b2420"/>' +
    '<rect x="50" y="12" width="2" height="2" fill="#2b2420"/><rect x="48" y="14" width="2" height="2" fill="#2b2420"/>' +
    '<rect x="46" y="16" width="2" height="2" fill="#2b2420"/>';
  stage.appendChild(s);
  const t = document.createElement('div'); t.className = 'ptag %s'; t.dataset.disp = '1'; t.innerHTML = '%s';
  t.style.left = '%dpx'; t.style.top = '360px'; stage.appendChild(t);
})();
''' % (SCENE_X, SCENE_Y, pose, tag_cls, tag_html, {'': 222, 'met': 204}.get(tag_cls, 198))


TAG_PLAN = '<span class="pk">SPEND</span><b>€73+</b>'
TAG_MET = '<span class="pk">SPEND</span><b>€73+ ✓</b>'

HEADER = """<!--
  PURSE, DIRECTION C "the grin purse" (#76 decide prep, 2026-10-19). Not decided; one of the options for the user.
  Built by docs/art/mockups/purse_src/gen_c/gen_c.py on top of planning_effects_h1.html (approved h1 planning effects).
  - A brown leather kiss-lock coin purse stands on the counter by the register (spot A, body Rect2(284, 326, 52, 72), left of
    x 336 so the reward print-out's shade never covers it). Its two clasp knobs are its EYES and its opening is its MOUTH: the
    purse is a face, so "she is happier" is read the way people read faces, at a glance, before any number.
  - The bigger the total against the quota, the wider it grins and the taller the fan of notes (and her card) it raises:
    5 steps on the projected total in planning and on the running subtotal in the count-up (display ratios 0.5 / 0.85 / 1.0 /
    2.0 of the quota, kept as tuning data; the purse never computes a score).
  - A paper tag on a string from its hinge says "SPEND €73+": the quota is a minimum spend, read before the first CHECKOUT.
  - Colours: leather e/f/F/h, mustard clasp M/y/m, teal lining, green notes, teal card (a cream one read as a Milk carton), white teeth; no sweat on the happy steps (it reads as "spending hurts"); no velvet, no brass, no tomato.
-->
"""


# ------------------------------------------------------------------ page 1: planning (h1 row, €182 projected on €73)
def planning():
    s = BASE
    s = sub(s, '<title>Planning effects h1</title>', '<title>Purse C grin</title>\n' + HEADER)
    s = sub(s, '</style>', CSS + '\n</style>')
    s = sub(s, '</script>\n</body>', '</script>\n<script>\n' + scene_js('s4', TAG_MET, 'met') + '</script>\n</body>')
    return s


# ------------------------------------------------------------------ page 2: count-up, the last Milk lands (56 -> 182)
MON_COUNT = '''<div class="abs monitor"><div class="screen cu">
    <div class="art"><img class="px" src="assets/art/items_v2/milk.png" style="width:96px;height:96px"><div class="kind">MILK</div><div class="kind" style="font-size:12px;margin-top:0">7 / 7</div></div>
    <div class="col">
      <div class="row1"><span class="lbl">SUBTOTAL</span><span class="step">×3 Multipack · +€12 loyalty</span></div>
      <div style="position:relative"><div class="big">€182</div><div class="gain" style="right:0;top:20px">+€126</div></div>
      <div class="qrow"><span class="lbl">QUOTA <span class="num" style="font-size:14px;letter-spacing:0">€73</span></span><span class="qbar"><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i></span><span class="togo"><b style="color:#2b2420">✓</b> +€109 over</span></div>
    </div>
  </div></div>'''

COUNT_CSS = '''
/* count-up monitor layout (from shift_screen_b2_count_up.html) */
.screen.cu { gap: 12px; padding: 8px 12px 8px 10px; }
.cu .art { width: 96px; }
.cu .kind { color: var(--ink-light); }
.cu .col { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.cu .row1 { display: flex; align-items: center; justify-content: space-between; height: 24px; }
.cu .lbl { font-family: Pixelify; font-size: 15px; letter-spacing: 2px; color: var(--ink-light); }
.cu .step { font-size: 12.5px; font-weight: 650; color: var(--ink-light); }
.cu .big { font-family: Atkinson; font-weight: 750; font-size: 78px; line-height: 70px; letter-spacing: -1px; height: 72px; color: var(--ink); text-shadow: 4px 4px 0 var(--mustard-light); margin-top: 2px; }
.cu .gain { position: absolute; font-family: Atkinson; font-weight: 750; font-size: 20px; line-height: 24px; padding: 0 8px; color: var(--ink);
  background: var(--mustard); border: 2px solid var(--ink); box-shadow: inset 0 2px 0 var(--mustard-light), inset 0 -2px 0 #c39228, 3px 3px 0 rgba(43,36,32,.3); }
.cu .qrow { display: flex; align-items: center; gap: 8px; margin-top: 4px; }
.cu .qrow .lbl { font-size: 13px; letter-spacing: 1px; }
.qbar { flex: 1; height: 16px; display: flex; gap: 2px; padding: 2px; background: var(--ink); }
.qbar i { flex: 1; background: #d9cfba; }
.qbar i.on { background: var(--mustard); box-shadow: inset 0 2px 0 var(--mustard-light); }
.cu .togo { font-size: 12.5px; font-weight: 700; color: var(--ink-light); white-space: nowrap; }
.ln.now { background: var(--mustard-pale); outline: 2px solid var(--mustard); }
.ln.ghost { color: #c9bfae; }
.checkout { filter: saturate(.35) brightness(.72); }
.redraw { filter: saturate(.5) brightness(.8); }
.cshade { position: absolute; left: 336px; top: 496px; width: 944px; height: 204px; background: rgba(20,14,10,.38); z-index: 6; }
'''


def count_up():
    s = BASE
    s = sub(s, '<title>Planning effects h1</title>', '<title>Purse C count-up</title>\n' + HEADER.replace(
        '-->', '  COUNT-UP STILL: the 7th beat (the last Milk, +€126) lands; the subtotal jumps €56 -> €182 and passes the quota\n'
        '  on this beat, so the quota ding and the top step arrive together: the clasp pops ("!"), the notes fan out, one note\n'
        '  flicks toward the register, the tag gets its check. The belt and the hand are shaded for the count, as in the game.\n-->'))
    s = sub(s, '</style>', CSS + COUNT_CSS + '\n</style>')
    s = re.sub(r'<div class="abs monitor"><div class="screen brief">.*?</div></div>\n', lambda m: MON_COUNT + '\n', s, count=1, flags=re.S)
    # receipt: the last Milk is the line printing now, the TOTAL waits for the verdict
    s = sub(s, '<div class="ln"><span class="nm">Milk</span><span>€126.00</span>', '<div class="ln now"><span class="nm">Milk</span><span>€126.00</span>')
    s = sub(s, '<span class="nm" style="font-family:Pixelify;font-size:15px">PROJECTED</span><span class="num" style="font-size:18px">€182.00</span>',
            '<span class="nm" style="font-family:Pixelify;font-size:15px">TOTAL</span><span class="num" style="font-size:18px;color:#c9bfae">· · · · ·</span>')
    s = sub(s, '1 fizzle<span class="hint"> · hover an item</span>', '1 fizzle<span class="hint"> · tap: skip · hold: fast</span>')
    s = sub(s, '<span class="v" style="color:var(--mustard-light)">€182</span>',
            '<span class="v" style="color:var(--mustard-light)">€182</span><span style="width:20px;height:20px;background:#5fae5a;border:2px solid #2b2420;color:#fbf7ee;font:800 13px/16px Atkinson;text-align:center">✓</span>')
    shade = 'document.querySelector(".stage").appendChild(Object.assign(document.createElement("div"), {className: "cshade"})).dataset.disp = "1";\n'
    s = sub(s, '</script>\n</body>', '</script>\n<script>\n' + shade + scene_js('peak', TAG_MET, 'met') + '</script>\n</body>')
    return s


# ------------------------------------------------------------------ page 3: every step, large, plus reduced motion and greyscale
LADDER = [
    ('s0', 'Window shopping', 'below 50% of quota', 'shut, sleepy eyes, flat lip', 'none'),
    ('s1', 'Interested', '50% to 85%', 'lips part, a note peeks', 'tick (soft)'),
    ('s2', 'Almost', '85% to 100%', 'clasp strains, eyes up, a card', 'tick'),
    ('s3', 'Happy', 'at the quota (met)', 'wide grin, white teeth (one gold), cash fan', 'ding'),
    ('s4', 'Splurge', '2x the quota or more', 'bulging, eyes squeezed, coins pop', 'register_bell'),
]
VERDICTS = [
    ('over', 'Thank you!', 'verdict OVER (+€N)', 'notes fly to the drawer, heart', 'stamp_paid'),
    ('on', 'Just right', 'verdict ON QUOTA', 'snaps shut, smiling', 'clasp snap'),
    ('short', 'Still wants more', 'verdict SHORT €N', 'slumps, frown, notes unspent', 'fail (existing)'),
]
TRANSIENTS = [
    ('drag_plus', 'Drag +', 'drag delta > 0', 'hops 6 px, looks at the belt', 'none'),
    ('drag_minus', 'Drag −', 'drag delta < 0', 'sinks, lips close, looks down', 'none'),
    ('flick', 'Gain beat', 'each gain beat lands', 'one note flicks to the register', 'none (ladder plays)'),
    ('gasp', 'Quota ding', 'met flips true', 'clasp pops wide, "!"', 'ding + clasp pop'),
    ('tremble', 'Held breath', 'pause before TOTAL', 'shivers 1 px, strains', 'none'),
]

TAGS = [('<span class="pk">SPEND</span><b>€73+</b>', '', 'planning, below quota'),
        (TAG_MET, 'met', 'quota met'),
        ('<span class="pk">THANK YOU</span><b>+€109</b>', 'wide', 'verdict OVER'),
        ('<span class="pk">ON QUOTA</span><b>€73 ✓</b>', 'wide', 'verdict ON'),
        ('<span class="pk">SHE WANTED</span><b>€21 more</b>', 'wide', 'verdict SHORT (ink)')]


def states():
    cards = []

    def card(name, title, trig, vis, snd, scale, grey=False, small=False):
        cls = 'card' + (' grey' if grey else '') + (' small' if small else '')
        extra = '' if small else f'<div class="tv">{vis}</div><div class="ts">♪ {snd}</div>'
        return (f'<div class="{cls}"><div class="spr" data-pose="{name}" data-scale="{scale}"></div><div class="wood"></div>'
                f'<div class="tt">{title}</div><div class="tg">{trig}</div>{extra}</div>')

    row1 = ''.join(card(*r, 3) for r in LADDER) + '<div class="sep"></div>' + ''.join(card(*r, 3) for r in VERDICTS)
    row2 = ''.join(card(*r, 3) for r in TRANSIENTS)
    row2 += card('s4_still', 'Reduced motion', 'any step, loops off', 'pose kept; no sparkle, coins, shiver', 'same', 3)
    tags = ''.join(f'<div class="tagcell"><div class="ptag {c}" style="position:relative">{h}</div><span>{lbl}</span></div>' for h, c, lbl in TAGS)
    grey = ''.join(card(r[0], r[1], '', '', '', 2, grey=True, small=True) for r in LADDER + VERDICTS)
    grey += ''.join(card(r[0], r[1], '', '', '', 2, grey=True, small=True) for r in TRANSIENTS[2:4])
    return f'''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Purse C states</title>
{HEADER}<style>
@font-face {{ font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }}
@font-face {{ font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: 1280px; height: 720px; overflow: hidden; background: #1f3b3a; color: #fbf7ee; font-family: Atkinson; }}
img, .px {{ image-rendering: pixelated; }}
h1 {{ position: absolute; left: 16px; top: 8px; font-family: Pixelify; font-size: 22px; font-weight: 500; color: #f1d27a; }}
.sub {{ position: absolute; left: 16px; top: 34px; font-size: 12px; font-weight: 600; color: #c3e0d4; }}
.row {{ position: absolute; left: 12px; display: flex; gap: 6px; align-items: flex-start; }}
.lab {{ position: absolute; left: 16px; font-family: Pixelify; font-size: 12px; letter-spacing: 1px; color: #86c2b6; }}
.card {{ width: 150px; background: #2a4d4b; border: 2px solid #172c2b; position: relative; padding-bottom: 4px; }}
.card .spr {{ height: 162px; display: flex; justify-content: center; align-items: flex-end; background: #e4d6b9; }}
.card .wood {{ height: 8px; background: #c98c4e; border-top: 2px solid #ddb07a; border-bottom: 2px solid #6e4524; }}
.card .tt {{ font-family: Pixelify; font-size: 14px; line-height: 16px; color: #fbf7ee; padding: 3px 6px 0; }}
.card .tg {{ font-size: 11px; line-height: 13px; font-weight: 750; color: #f1d27a; padding: 0 6px; }}
.card .tv {{ font-size: 10.5px; font-weight: 600; color: #c3e0d4; padding: 0 6px; line-height: 12px; height: 24px; overflow: hidden; }}
.card .ts {{ font-size: 10.5px; line-height: 12px; font-weight: 600; color: #c7beab; padding: 1px 6px 0; }}
.card.small {{ width: 120px; padding-bottom: 1px; }}
.card.small .spr {{ height: 92px; overflow: hidden; }}
.card.small .wood {{ height: 6px; }}
.card.small .tt {{ font-size: 11px; line-height: 13px; padding: 1px 4px 0; white-space: nowrap; }}
.card.grey .spr, .card.grey .wood, .tags.grey {{ filter: grayscale(1); }}
.sep {{ width: 4px; align-self: stretch; background: #f1d27a; margin: 0 3px; }}
.tags {{ display: grid; grid-template-columns: 1fr 1fr; gap: 6px 10px; width: 336px; padding: 8px 10px; background: #2a4d4b; border: 2px solid #172c2b; height: 242px; align-content: start; }}
.tags .hd {{ grid-column: 1 / 3; font-family: Pixelify; font-size: 13px; color: #fbf7ee; }}
.tagcell {{ display: flex; flex-direction: column; align-items: flex-start; gap: 3px; background: #e4d6b9; padding: 5px 8px; }}
.tagcell span {{ font-size: 10.5px; font-weight: 700; color: #2b2420; line-height: 12px; }}
{CSS}
</style></head><body>
<h1>Purse C · the grin purse: every reaction step</h1>
<div class="sub">1 art px = 3 screen px here (2 in the game). Steps follow the projected total (planning) and the subtotal (count-up) against the quota. ♪ = suggested sound.</div>
<div class="lab" style="top:52px">LADDER (planning and count-up)  ·  VERDICT (dessert)</div>
<div class="row" style="top:66px">{row1}</div>
<div class="lab" style="top:318px">TRANSIENTS (one-shots over the current step)  ·  REDUCED MOTION</div>
<div class="row" style="top:332px">{row2}<div class="tags"><div class="hd">The tag on the string</div>{tags}</div></div>
<div class="lab" style="top:584px;left:16px">GREYSCALE: each step differs by eyes, mouth width and fan height, never by colour alone (the tags are words)</div>
<div class="row" style="top:598px">{grey}</div>
<script>
{PAINTER}
document.querySelectorAll('.spr').forEach(d => {{
  const sc = +d.dataset.scale, c = purseCanvas(d.dataset.pose, sc);
  d.appendChild(c);
}});
</script>
</body></html>
'''


for name, html in (('purse_c.html', planning()), ('purse_c_count_up.html', count_up()), ('purse_c_states.html', states())):
    (MOCKUPS / name).write_text(html, encoding='utf-8')
    print('wrote', MOCKUPS / name)
