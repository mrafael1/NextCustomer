"""Builds purse_a.html, purse_a_count_up.html and purse_a_states.html (#76 decide prep, direction A) in docs/art/mockups.

The two scene pages patch planning_effects_h1.html (approved "just perfect"): the purse is drawn after the mirror pass, in
display coordinates, on the counter by the register (brief spot A). The states page is standalone. purse.js (the pixel purse)
is inlined into every page, so each page stays self-contained. Standard library only.
"""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).parent
MOCKUPS = pathlib.Path(__file__).resolve().parents[2]
base = (MOCKUPS / 'planning_effects_h1.html').read_text(encoding='utf-8')
purse_js = (HERE / 'purse.js').read_text(encoding='utf-8')


def sub(s, old, new, count=1):
    if old not in s:
        sys.exit('missing: ' + old[:90])
    return s.replace(old, new, count)


# The purse's 48 x 60 texel canvas at 2 px a texel: its centre column (texel 24) lands on x 310 and its ground row (texel 56)
# on y 398 (the counter top's front, the column's light edge at y 400). The body spans x 284-336 (brief spot A); only coins
# and notes in flight at the burst leave that box, and none of them reach the receipt (x 46-282 above y 344).
PURSE_CSS = """
/* ================= #76 purse, direction A (decide prep) ================= */
.purse { position: absolute; left: 262px; top: 286px; width: 96px; height: 120px; z-index: 6; }
.purse canvas { width: 96px; height: 120px; display: block; }
"""


def overlay(step, still):
    return f"""<script>
// ================= #76 purse A: drawn after the mirror pass, in display coordinates =================
{purse_js}
(() => {{ const d = document.createElement('div'); d.className = 'purse'; d.dataset.disp = 1;
  d.appendChild(purseCanvas({step}, {{ still: {'true' if still else 'false'} }})); stage.appendChild(d); }})();
</script>
"""


HEADER_PLAN = """<!--
  PURSE A IN PLANNING (#76 decide prep, 2026-10-19; nothing decided). planning_effects_h1.html + the purse, by
  purse_src/gen_a/gen_a.py. A fat brown-leather frame purse stands on the counter by the register, in front of the cashier,
  where the customer sets it down to pay (brief spot A, body x 284-336, left of the print-out shade's edge at x 336).
  It shows the step for the row's projection against the quota: h1's row projects €182 on a €73 quota, so it is at step 4
  (BURST), held still: in planning a step change plays once (about 300 ms) and nothing loops, so the notes stand up in the
  open mouth and the coins rest on the counter. The QUOTA chip's bar and the monitor's LED bar stay as they are.
-->
"""

HEADER_COUNT = """<!--
  PURSE A MID COUNT-UP (#76 decide prep, 2026-10-19; nothing decided). planning_effects_h1.html in its count-up state + the
  purse, by purse_src/gen_a/gen_a.py. The moment: the last Milk's +€12 loyalty beat lands (subtotal €65 -> €77), which crosses
  the €73 quota: the quota ding. The QUOTA chip's check disc appears, the LED bar is full, and the purse bursts (its strongest
  reaction, step 4): the frame springs wide, notes and coins fly for about 600 ms and the coins come to rest on the counter.
  Simplifications: the belt keeps h1's planning stickers (in the game the count-up's belt chips and scan brackets take over),
  and the hand is not dimmed.
-->
"""

COUNT_CSS = """
/* count-up monitor (from shift_screen_b2_count_up.html) */
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
.cu .togo { font-size: 12.5px; font-weight: 750; color: var(--ink); white-space: nowrap; display: flex; align-items: center; gap: 4px; }
.okdisc { display: inline-grid; place-items: center; width: 20px; height: 20px; background: var(--good); border: 2px solid var(--ink); border-radius: 50%; color: var(--paper); font-size: 12px; font-weight: 800; line-height: 1; }
.ln.combo { background: var(--mustard-pale); }
.ln.sub { padding-left: 12px; font-size: 12px; white-space: nowrap; gap: 5px; }
.ln.ghost { color: #c9bfae; }
.receipt .sum.cuhint { color: var(--muted); }
.key.off { filter: saturate(.45) brightness(.78); }
.scanbrk { position: absolute; width: 16px; height: 16px; border: 0 solid var(--mustard); z-index: 6; }
"""

MON_COUNT = '''<div class="abs monitor"><div class="screen cu">
    <div class="art"><img class="px" src="assets/art/items_v2/milk.png" style="width:96px;height:96px"><div class="kind">MILK</div><div class="kind" style="font-size:12px;margin-top:0">7 / 7</div></div>
    <div class="col">
      <div class="row1"><span class="lbl">SUBTOTAL</span><span class="step">+€12 loyalty</span></div>
      <div style="position:relative"><div class="big">€77</div><div class="gain" style="right:0;top:20px">+€12</div></div>
      <div class="qrow"><span class="lbl">QUOTA <span class="num" style="font-size:14px;letter-spacing:0">€73</span></span><span class="qbar">''' + '<i class="on"></i>' * 10 + '''</span><span class="togo"><span class="okdisc">✓</span>met</span></div>
    </div>
  </div></div>'''

OK = '<span class="pl" style="color:var(--good);font-weight:700">✓</span>'
FZ = '<span class="pl"><img class="px" src="assets/art/icons/fizzle.png"></span>'
TRI = ('<span class="pl"><svg width="14" height="13" viewBox="0 0 24 22" shape-rendering="crispEdges"><polygon points="12,1 23,20 1,20" '
       'fill="#e2b33c" stroke="#2b2420" stroke-width="3"/></svg></span>')
RECEIPT_COUNT = f'''<div class="abs receipt">
    <div class="h">NEXT CUSTOMER · REG 3</div>
    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>
    <div class="dash"></div>
    <div class="ln"><span class="nm">Eggs</span><span>€1.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Bread</span><span>€10.00</span>{OK}</div>
    <div class="ln"><span class="nm">Milk</span><span>€0.00</span>{TRI}</div>
    <div class="ln"><span class="nm">Multipack</span><span>€0.00</span>{FZ}</div>
    <div class="ln"><span class="nm">Milk</span><span>€21.00</span>{OK}</div>
    <div class="ln"><span class="nm">Milk</span><span>€24.00</span>{OK}</div>
    <div class="ln"><span class="nm">Milk</span><span>€4.00</span><span class="pl"></span></div>
    <div class="ln sub"><span class="nm">+ own rule</span><span>+€5</span><span class="pl"></span></div>
    <div class="ln sub on"><span class="nm">+ loyalty</span><span>+€12</span><span class="pl"></span></div>
  </div>'''


def scene(count):
    s = base
    s = re.sub(r'<title>[^<]*</title>', '<title>Purse A' + (' count-up' if count else '') + '</title>', s, count=1)
    s = sub(s, '</title>\n', '</title>\n' + (HEADER_COUNT if count else HEADER_PLAN))
    s = sub(s, '</style>', PURSE_CSS + (COUNT_CSS if count else '') + '\n</style>')
    if count:
        s = sub(s, '<span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€182</span>',
                '<span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€77</span>'
                '<span class="okdisc" style="margin-left:-2px">✓</span>')
        s = re.sub(r'<div class="abs monitor"><div class="screen brief">.*?\n  </div></div>\n', lambda m: MON_COUNT + '\n', s, count=1, flags=re.S)
        s = re.sub(r'<div class="abs receipt">.*?\n  </div>\n', lambda m: RECEIPT_COUNT + '\n', s, count=1, flags=re.S)
        s = sub(s, '<div class="abs key checkout">', '<div class="abs key checkout off">')
        s = sub(s, '<div class="abs key redraw">', '<div class="abs key redraw off">')
    s = sub(s, '</script>\n</body>', '</script>\n' + overlay(4, still=not count) + '</body>')
    if count:
        # the legend lives on the calm monitor, which the count-up screen replaces
        s = sub(s, "const lg = document.getElementById('legend');", "const lg = document.getElementById('legend') || document.createElement('div');")
        # scan brackets round the last Milk (slot 7, x 1136-1248, display coordinates)
        brk = ("<script>\n(() => { [[1132, 294, 'Left', 'Top'], [1236, 294, 'Right', 'Top'], [1132, 398, 'Left', 'Bottom'], [1236, 398, 'Right', 'Bottom']]"
               ".forEach(([x, y, a, b]) => { const d = document.createElement('div'); d.className = 'scanbrk'; d.style.left = x + 'px'; d.style.top = y + 'px';"
               " d.style['border' + a + 'Width'] = '4px'; d.style['border' + b + 'Width'] = '4px'; stage.appendChild(d); }); })();\n</script>\n")
        s = sub(s, '</body>', brk + '</body>')
    return s


(MOCKUPS / 'purse_a.html').write_text(scene(False), encoding='utf-8')
(MOCKUPS / 'purse_a_count_up.html').write_text(scene(True), encoding='utf-8')
states = (HERE / 'states.html').read_text(encoding='utf-8')
(MOCKUPS / 'purse_a_states.html').write_text(sub(states, '/*PURSE_JS*/', purse_js), encoding='utf-8')
for n in ('purse_a', 'purse_a_count_up', 'purse_a_states'):
    print('wrote', MOCKUPS / (n + '.html'))
