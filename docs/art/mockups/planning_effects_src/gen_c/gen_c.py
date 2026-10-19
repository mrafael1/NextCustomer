"""Builds planning_effects_c.html and planning_effects_c_hover.html from the mirrored B2 mock-up."""
import pathlib, re, sys
MOCKUPS = pathlib.Path(__file__).resolve().parents[2]  # docs/art/mockups: input and output
if not (MOCKUPS / "shift_screen_b2_mirrored.html").exists():
    sys.exit("shift_screen_b2_mirrored.html comes from main (#84): merge main first")
D = MOCKUPS
base = (D / 'shift_screen_b2_mirrored.html').read_text(encoding='utf-8')
overlay = (pathlib.Path(__file__).parent / 'overlay_c.js').read_text(encoding='utf-8')
extra_css = (pathlib.Path(__file__).parent / 'overlay_c.css').read_text(encoding='utf-8')


def sub(s, old, new, count=1):
    assert s.count(old) >= 1, old[:80]
    return s.replace(old, new, count)


def build(hover):
    s = base
    s = sub(s, '<title>Shift screen B2 mirrored</title>', '<title>Planning effects C</title>')
    s = sub(s, '<!--\n  MIRRORED B2', '<!--\n  PLANNING EFFECTS, direction C "Arcs" (#71, ' + ('Multipack hovered' if hover else 'calm planning') + '): built on the mirrored B2 page; the overlay script at the end draws\n  the effect arcs, the rail tokens and the result bubbles in display coordinates.\n  MIRRORED B2')
    s = sub(s, '</style>', extra_css + '\n</style>')
    # top bar
    s = sub(s, '<span class="bar"><i></i></span><span class="v" style="color:var(--mustard-light)">€22</span>',
            '<span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€182</span>')
    s = sub(s, 'Inspection · −1 slot', 'Inspection · 3rd product pays €0')
    s = sub(s, '<span class="stamp" title="Coupon engine">', '<span class="stamp" id="stCoupon" title="Coupon engine">')
    s = sub(s, '<span class="stamp" title="Slot engine">', '<span class="stamp" id="stSlot" title="Slot engine">')
    s = sub(s, '<span class="stamp" title="Category engine">', '<span class="stamp" id="stTag" title="Category engine">')
    # monitor
    m0 = s.index('<div class="abs monitor"><div class="screen">')
    m1 = s.index('</div></div>', s.index('<div class="pays">pays <b>€0</b></div>')) + len('</div></div>')
    if hover:
        mon = '''<div class="abs monitor"><div class="screen">
    <div class="art"><div style="position:relative;width:96px;height:96px"><img class="px" src="assets/art/items_v2/coupon_slip.png" style="width:96px;height:96px"><img class="px slipicon" src="assets/art/icons/coupon_multipack_v2.png"></div><div class="kind">COUPON</div></div>
    <div style="flex:1;min-width:0">
      <div class="title">Multipack</div>
      <div class="rule">×3 to later products sharing a tag with the product just before it</div>
      <div class="gives"><span class="gtk">×3</span><span>to <b>Milk</b>, <b>Milk</b>, <b>Milk</b> <span class="dim">(slots 5–7)</span></span></div>
      <div class="gain">adds <b>+€114</b> to the shift</div>
      <div class="why"><img class="px" src="assets/art/icons/fizzle.png"><span>Coupon engine: the first coupon paid nothing</span></div>
    </div>
    <div class="pays">pays <b>€0</b></div>
  </div></div>'''
    else:
        mon = '''<div class="abs monitor"><div class="screen brief">
    <div style="flex:1;min-width:0;position:relative">
      <div class="bt"><span>SHIFT <b>5/8</b></span><span>QUOTA <b>€73</b></span></div>
      <div class="kind" style="margin-top:6px">INSPECTION</div>
      <div class="title">Spot check</div>
      <div class="rule" style="margin-top:1px">The 3rd product pays €0</div>
      <div class="legend"><span class="lg"><i class="tk gift">×2</i>from another item</span><span class="lg"><i class="tk own">+3</i>its own rule</span><span class="lg"><i class="tk upg"><canvas class="px mst" data-glyph="slot" width="7" height="7"></canvas>+12</i>loyalty</span></div>
    </div>
  </div></div>'''
    s = s[:m0] + mon + s[m1:]
    # receipt
    r0 = s.index('<div class="abs receipt">')
    r1 = s.index('<div class="abs key checkout">')
    ok = '<span class="pl" style="color:var(--good);font-weight:700">✓</span>'
    x3 = '<span class="pl"><i class="rx3">×3</i></span>' if hover else ok
    fz = '<span class="pl"><img class="px" src="assets/art/icons/fizzle.png"></span>'
    lines = [('Eggs', '€1.00', '<span class="pl"></span>', ''), ('Bread', '€10.00', ok, ''), ('Milk', '€0.00', fz, ''),
             ('Multipack', '€0.00', fz, ' on' if hover else ''), ('Milk', '€21.00', x3, ''), ('Milk', '€24.00', x3, ''), ('Milk', '€126.00', x3, '')]
    rec = '<div class="abs receipt">\n    <div class="h">NEXT CUSTOMER · REG 3</div>\n    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>\n    <div class="dash"></div>\n'
    for n, p, pl, c in lines:
        rec += f'    <div class="ln{c}"><span class="nm">{n}</span><span>{p}</span>{pl}</div>\n'
    rec += '    <div class="dash"></div>\n    <div class="ln"><span class="nm" style="font-family:Pixelify;font-size:15px">PROJECTED</span><span class="num" style="font-size:18px">€182.00</span><span class="pl"></span></div>\n'
    rec += '    <div class="sum" style="margin-top:3px">2 fizzles<span class="hint"> · hover an item</span></div>\n  </div>\n\n  '
    s = s[:r0] + rec + s[r1:]
    # no empty slot footprints
    s = sub(s, '[2, 1].forEach(i => {\n  const x0 = X0 + i * P + 8', '[].forEach(i => {\n  const x0 = X0 + i * P + 8')
    # belt row
    b0 = s.index('// ================= belt items =================')
    b1 = s.index('// ================= the hand')
    s = s[:b0] + BELT.replace('%HOVER%', 'true' if hover else 'false') + '\n' + s[b1:]
    # overlay after the mirror pass
    s = sub(s, '</script>\n</body>', '</script>\n<script>\nconst HOVER = ' + ('true' if hover else 'false') + ';\n' + overlay + '\n</script>\n</body>')
    return s


BELT = r'''// ================= belt items (planning effects #71 row) =================
// a placeholder Bread loaf (no sprite yet): a 48 x 48 texel tin loaf, flat crust fills, ink outline, lit upper left
const BREAD_URL = (() => { const c = document.createElement('canvas'); c.width = 48; c.height = 48; const g = c.getContext('2d');
  const inL = (i, j) => { const x = i + .5, y = j + .5; if (x < 6 || x > 42 || y > 44) return false; if (y >= 30) return true; return ((x - 24) / 18) ** 2 + ((y - 30) / 9) ** 2 <= 1; };
  for (let j = 0; j < 48; j++) for (let i = 0; i < 48; i++) {
    let col = null;
    if (inL(i, j)) { col = '#c98c4e';
      if (!inL(i - 1, j) || !inL(i, j - 1) || !inL(i - 2, j) && j > 30 || !inL(i, j - 2)) col = '#e2b07a';
      if (!inL(i + 1, j) || !inL(i, j + 1) || !inL(i + 2, j) && j > 26) col = '#8a5a2e';
      if (j === 34 && i > 7 && i < 41) col = '#8a5a2e';
      if ((j === 25 || j === 26) && [14, 15, 16, 22, 23, 24, 30, 31, 32].includes(i)) col = '#f0d29c';
    } else if (inL(i - 1, j) || inL(i + 1, j) || inL(i, j - 1) || inL(i, j + 1)) col = '#2b2420';
    if (col) { g.fillStyle = col; g.fillRect(i, j, 1, 1); } }
  return c.toDataURL(); })();
const HOVERED = %HOVER%;
// display slot d (1..7) sits at source slot 7 - d (the mirror pass moves it)
const ROW = [
  { n: 'eggs', src: `${A}items_v2/eggs.png`, p: '€1', r: '×2 next Food' },
  { n: 'bread', src: BREAD_URL, p: '€5', r: '', a: 'bakery' },
  { n: 'milk', src: `${A}items_v2/milk.png`, p: '€4', r: '+1 per earlier Breakfast', a: 'cold_cases', cls: 'denied' },
  { n: 'coupon', src: `${A}items_v2/coupon_slip.png`, cp: true },
  { n: 'milk', src: `${A}items_v2/milk.png`, p: '€4', r: '+1 per earlier Breakfast', a: 'cold_cases' },
  { n: 'milk', src: `${A}items_v2/milk.png`, p: '€4', r: '+1 per earlier Breakfast', a: 'cold_cases' },
  { n: 'milk', src: `${A}items_v2/milk.png`, p: '€4', r: '+1 per earlier Breakfast', a: 'cold_cases' },
];
ROW.forEach((it, k) => {
  const i = 6 - k, x = X0 + i * P + 8, hov = it.cp && HOVERED;
  const d = it.cp ? item(it.src, x, ground, { lift: hov ? 16 : 0, base: 16, icon: `${A}icons/coupon_multipack_v2.png` }) : item(it.src, x, ground);
  d.id = 'it' + (k + 1); if (it.cls) d.classList.add(it.cls);
  if (it.cp) label('label cp' + (hov ? ' sel' : ''), X0 + i * P, 428, 'COUPON', '×3 later with prior’s tag');
  else label('label', X0 + i * P, 428, it.p, it.r, it.a);
  if (hov) [['l', 't'], ['r', 't'], ['l', 'b'], ['r', 'b']].forEach(([h, v]) => {
    el('abs brk', { left: (h === 'l' ? x - 16 : x + 96) + 'px', top: (v === 't' ? ground - 100 : ground - 4) + 'px',
      borderLeftWidth: h === 'l' ? '4px' : 0, borderRightWidth: h === 'r' ? '4px' : 0, borderTopWidth: v === 't' ? '4px' : 0, borderBottomWidth: v === 'b' ? '4px' : 0 });
  });
});
'''

for hover in (False, True):
    name = 'planning_effects_c_hover.html' if hover else 'planning_effects_c.html'
    (D / name).write_text(build(hover), encoding='utf-8')
    print('wrote', name)
