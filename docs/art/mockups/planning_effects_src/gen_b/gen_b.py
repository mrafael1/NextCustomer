"""Builds planning_effects_b.html and planning_effects_b_hover.html from the mirrored B2 mock-up."""
import pathlib, re, sys

MOCKUPS = pathlib.Path(__file__).resolve().parents[2]  # docs/art/mockups: input and output
if not (MOCKUPS / "shift_screen_b2_mirrored.html").exists():
    sys.exit("shift_screen_b2_mirrored.html comes from main (#84): merge main first")
D = MOCKUPS
base = (D / 'shift_screen_b2_mirrored.html').read_text(encoding='utf-8')
overlay = (pathlib.Path(__file__).parent / 'overlay_b.js').read_text(encoding='utf-8')
css = (pathlib.Path(__file__).parent / 'overlay_b.css').read_text(encoding='utf-8')

def sub(s, old, new, count=1):
    if old not in s:
        sys.exit('missing: ' + old[:80])
    return s.replace(old, new, count)

MON_CALM = '''<div class="abs monitor"><div class="screen brief">
    <div class="bt"><span>SHIFT 5/8</span><span>QUOTA €73</span></div>
    <div class="bk">INSPECTION</div>
    <div class="bn">Spot check</div>
    <div class="bd2">The 3rd product pays €0</div>
    <div class="dots"><i class="on"></i><i></i><i></i><i></i><i></i></div>
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
    on = ' on' if hover else ''
    ok = '<span class="pl" style="color:var(--good);font-weight:700">✓</span>'
    fz = '<span class="pl"><img class="px" src="assets/art/icons/fizzle.png"></span>'
    rows = [('Eggs', '€1.00', '<span class="pl"></span>', ''), ('Bread', '€10.00', ok, ''), ('Milk', '€0.00', fz, ''),
            ('Multipack', '€0.00', fz, on), ('Milk', '€21.00', ok, ''), ('Milk', '€24.00', ok, ''), ('Milk', '€126.00', ok, '')]
    body = ''.join(f'    <div class="ln{c}"><span class="nm">{n}</span><span>{p}</span>{m}</div>\n' for n, p, m, c in rows)
    return f'''<div class="abs receipt">
    <div class="h">NEXT CUSTOMER · REG 3</div>
    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>
    <div class="dash"></div>
{body}    <div class="dash"></div>
    <div class="ln"><span class="nm" style="font-family:Pixelify;font-size:15px">PROJECTED</span><span class="num" style="font-size:18px">€182.00</span><span class="pl"></span></div>
    <div class="sum" style="margin-top:3px">2 fizzles<span class="hint"> · hover an item</span></div>
  </div>'''

for hover in (False, True):
    s = base
    s = sub(s, '<title>Shift screen B2 mirrored</title>', '<title>Planning effects B' + (' hover' if hover else '') + '</title>')
    s = sub(s, '</style>', css + '\n</style>')
    s = sub(s, '<span class="v" style="color:var(--mustard-light)">€22</span>', '<span class="v" style="color:var(--mustard-light)">€182</span>')
    s = sub(s, 'Inspection · −1 slot', 'Inspection · 3rd product pays €0')
    # monitor
    s = re.sub(r'<div class="abs monitor"><div class="screen">.*?<div class="pays">pays <b>€0</b></div>\n  </div></div>\n', (MON_HOVER if hover else MON_CALM) + '\n', s, count=1, flags=re.S)
    s = re.sub(r'<div class="abs receipt">.*?\n  </div>\n', receipt(hover) + '\n', s, count=1, flags=re.S)
    # no empty footprints: all 7 slots are full
    s = sub(s, '[2, 1].forEach(i => {\n  const x0 = X0 + i * P + 8', '[].forEach(i => {\n  const x0 = X0 + i * P + 8')
    # drop the old belt row (items, hovered coupon, empty and closed slots); the overlay draws the new row after the mirror pass
    a = s.index('// ================= belt items =================')
    b = s.index('// ================= the hand ("Cart")')
    s = s[:a] + s[b:]
    s = sub(s, '</script>\n</body>', '</script>\n<script>\nconst HOVER = ' + ('true' if hover else 'false') + ';\n' + overlay + '\n</script>\n</body>')
    out = D / ('planning_effects_b' + ('_hover' if hover else '') + '.html')
    out.write_text(s, encoding='utf-8')
    print('wrote', out)
