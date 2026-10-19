"""Builds planning_effects_h1.html and planning_effects_h1_hover.html (hybrid h1) from the mirrored B2 mock-up."""
import pathlib, re, sys

HERE = pathlib.Path(__file__).parent
MOCKUPS = pathlib.Path(__file__).resolve().parents[2]  # docs/art/mockups: input and output
if not (MOCKUPS / "shift_screen_b2_mirrored.html").exists():
    sys.exit("shift_screen_b2_mirrored.html comes from main (#84): merge main first")
D = MOCKUPS
base = (D / 'shift_screen_b2_mirrored.html').read_text(encoding='utf-8')
overlay = (HERE / 'overlay.js').read_text(encoding='utf-8')
css = (HERE / 'overlay.css').read_text(encoding='utf-8')


def sub(s, old, new, count=1):
    if old not in s:
        sys.exit('missing: ' + old[:80])
    return s.replace(old, new, count)


HEADER = """<!--
  PLANNING EFFECTS, HYBRID h1 (#71, 2026-10-18): A's stickers, halo and stamp + B's ticket price + B's rail strip links.
  Built on shift_screen_b2_mirrored.html; the overlay script at the end draws the belt row in display coordinates.
  - RECEIVED effects are stickers slapped on the item (A): a cream price-gun label for "+N", a gold starburst for "xN", each with
    a mini badge of who gave it (no badge: the item's own ticket rule). They stack top to bottom in the engine's apply order and
    grow upward over the item and the back wall, never down onto the ticket: the column reads as the sum, the ticket is its total.
  - The PAY is on the ticket (B): the base price is struck and the real pay sits on a gold starburst (boosted) or a punched
    tomato tag (paid nothing). The rule text is never covered. No pay tag under the item, no reason slips: the stickers say why.
  - A boosted item stands 6 px raised in a stepped pixel halo (A): 1, 2 or 3 rings for x2+, x5+, x20+ its base.
  - A denied item is greyed under a tilted tomato rubber stamp "EUR 0 / SPOT CHECK" (A).
  - WHO GIVES WHAT is the rail strip (B): a lit brass strip along the belt lip, from a plug over the giver's ticket to the last
    target, the giver's name printed at its start, a factor badge dropping onto each target ticket. Always on while planning,
    calm (brass, no glow); hovering an item turns its strip bright gold with a ring, adds each target's gain on the strip, and
    steps everything unrelated back.
-->
"""

MON_CALM = '''<div class="abs monitor"><div class="screen brief">
    <div class="bt"><span>SHIFT 5/8</span><span>QUOTA €73</span></div>
    <div class="bk">INSPECTION</div>
    <div class="bn">Spot check</div>
    <div class="bd2">The 3rd product pays €0</div>
    <div class="legend" id="legend"></div>
  </div></div>'''

MON_HOVER = '''<div class="abs monitor"><div class="screen">
    <div class="art"><div style="position:relative;width:96px;height:96px"><img class="px" src="assets/art/items_v2/coupon_slip.png" style="width:96px;height:96px"><img class="px slipicon" src="assets/art/icons/coupon_multipack_v2.png"></div><div class="kind">COUPON</div></div>
    <div style="flex:1;min-width:0">
      <div class="title">Multipack</div>
      <div class="rule">×3 to later products sharing a tag with the product just before it (not Food or Breakfast)</div>
      <div class="gives"><b>×3</b><span>to the 3 Milks after it: they share Milk's <u>Cold case</u> tag · <b class="amt">+€114</b></span></div>
      <div class="why"><img class="px" src="assets/art/icons/fizzle.png"><span>Coupon engine: the first coupon pays nothing</span></div>
    </div>
    <div class="pays">pays <b>€0</b></div>
  </div></div>'''


def receipt(hover):
    ok = '<span class="pl" style="color:var(--good);font-weight:700">✓</span>'
    fz = '<span class="pl"><img class="px" src="assets/art/icons/fizzle.png"></span>'
    tri = ('<span class="pl"><svg width="14" height="13" viewBox="0 0 24 22" shape-rendering="crispEdges"><polygon points="12,1 23,20 1,20" '
           'fill="#e2b33c" stroke="#2b2420" stroke-width="3"/></svg></span>')
    x3 = '<b class="x3">×3</b>' if hover else ''
    tch = ' tch' if hover else ''
    rows = [('Eggs', '€1.00', '<span class="pl"></span>', '', ''), ('Bread', '€10.00', ok, '', ''), ('Milk', '€0.00', tri, '', ''),
            ('Multipack', '€0.00', fz, ' on' if hover else '', ''), ('Milk', '€21.00', ok, tch, x3), ('Milk', '€24.00', ok, tch, x3),
            ('Milk', '€126.00', ok, tch, x3)]
    body = ''.join(f'    <div class="ln{c}"><span class="nm">{n}</span>{x}<span>{p}</span>{m}</div>\n' for n, p, m, c, x in rows)
    return f'''<div class="abs receipt">
    <div class="h">NEXT CUSTOMER · REG 3</div>
    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>
    <div class="dash"></div>
{body}    <div class="dash"></div>
    <div class="ln"><span class="nm" style="font-family:Pixelify;font-size:15px">PROJECTED</span><span class="num" style="font-size:18px">€182.00</span><span class="pl"></span></div>
    <div class="sum" style="margin-top:3px">1 fizzle<span class="hint"> · {'Multipack hovered' if hover else 'hover an item'}</span></div>
  </div>'''


for hover in (False, True):
    s = base
    s = sub(s, '<title>Shift screen B2 mirrored</title>', '<title>Planning effects h1' + (' hover' if hover else '') + '</title>\n' + HEADER)
    s = sub(s, '</style>', css + '\n</style>')
    s = sub(s, '<span class="bar"><i></i></span><span class="v" style="color:var(--mustard-light)">€22</span>',
            '<span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€182</span>')
    s = sub(s, 'Inspection · −1 slot', 'Inspection · 3rd product pays €0')
    s = re.sub(r'<div class="abs monitor"><div class="screen">.*?<div class="pays">pays <b>€0</b></div>\n  </div></div>\n',
               lambda m: (MON_HOVER if hover else MON_CALM) + '\n', s, count=1, flags=re.S)
    s = re.sub(r'<div class="abs receipt">.*?\n  </div>\n', lambda m: receipt(hover) + '\n', s, count=1, flags=re.S)
    s = sub(s, 'Redraw <small>1 left</small>', 'Redraw <small>2 left</small>')
    s = sub(s, '[2, 1].forEach(i => {\n  const x0 = X0 + i * P + 8', '[].forEach(i => {\n  const x0 = X0 + i * P + 8')
    a = s.index('// ================= belt items =================')
    b = s.index('// ================= the hand ("Cart")')
    s = s[:a] + s[b:]
    s = sub(s, '</script>\n</body>', '</script>\n<script>\nconst HOVER = ' + ('true' if hover else 'false') + ';\n' + overlay + '\n</script>\n</body>')
    out = D / ('planning_effects_h1' + ('_hover' if hover else '') + '.html')
    out.write_text(s, encoding='utf-8')
    print('wrote', out)
