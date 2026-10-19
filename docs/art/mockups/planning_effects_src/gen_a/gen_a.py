"""Builds planning_effects_a.html and planning_effects_a_hover.html from the mirrored B2 mock-up."""
import pathlib, re, sys

MOCKUPS = pathlib.Path(__file__).resolve().parents[2]  # docs/art/mockups: input and output
if not (MOCKUPS / "shift_screen_b2_mirrored.html").exists():
    sys.exit("shift_screen_b2_mirrored.html comes from main (#84): merge main first")
D = MOCKUPS
HERE = pathlib.Path(__file__).parent
base = (D / "shift_screen_b2_mirrored.html").read_text(encoding="utf-8")
overlay_js = (HERE / "overlay.js").read_text(encoding="utf-8")
overlay_css = (HERE / "overlay.css").read_text(encoding="utf-8")


def cut(s, start, end, repl=""):
    i = s.index(start)
    j = s.index(end, i) + len(end)
    return s[:i] + repl + s[j:]


def sub(s, old, new):
    assert s.count(old) == 1, old[:80]
    return s.replace(old, new)


HEADER = """<!--
  PLANNING EFFECTS, DIRECTION A "ON THE ITEM" (#71, 2026-10-18). Built on shift_screen_b2_mirrored.html (everything but
  the belt row, the tickets, the receipt, the monitor and the top bar's numbers is that page unchanged).
  Every effect is physically attached to the item it concerns:
  - a SOURCE wears a hanging ribbon on a string, in words, with an arrow-shaped end: "x3 -> 3 Milk";
  - a RECEIVED effect is a sticker slapped on the item's art (a cream price-gun label for "+", a gold starburst for "x"),
    with a mini badge of who gave it (no badge: the item's own ticket rule); stickers stack top to bottom in the order the
    engine applies them, so a column reads as the sum: +5 +12 x3 x2;
  - under each item a price-gun tag pinned to the belt lip gives the pay: "EUR 4 -> EUR 21" (gold), "EUR 4 -> EUR 0" (tomato,
    denied), "pfff EUR 0" (grey, fizzled), "EUR 1" (paper, unchanged); it is the last line of the sticker sum;
  - a boosted item stands 6 px raised with a stepped pixel halo; 1, 2 or 3 rings for x2+, x5+, x20+ its base;
  - a denied item is greyed under a tomato rubber stamp "EUR 0 / SPOT CHECK" with the inspection's triangle.
  Hover state: the hovered item's ribbon names the total it adds, gold leader lines run from it to the stickers it put on
  other items, unrelated stickers and tags step back, the monitor explains, the receipt marks the lines it touches.
-->
"""


def build(hover):
    s = base
    s = sub(s, "<title>Shift screen B2 mirrored</title>", "<title>Planning effects A" + (" hover" if hover else "") + "</title>\n" + HEADER)
    s = sub(s, "</style>", overlay_css + "\n</style>")
    # top bar numbers
    s = sub(s, '<span class="bar"><i></i></span><span class="v" style="color:var(--mustard-light)">€22</span>',
            '<span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€182</span>')
    s = sub(s, "Inspection · −1 slot", "Inspection · 3rd product pays €0")
    # monitor
    i = s.index('<div class="abs monitor"><div class="screen">')
    j = s.index("</div></div>", s.index('<div class="pays">', i)) + len("</div></div>")
    if hover:
        mon = ('<div class="abs monitor"><div class="screen">\n'
               '    <div class="art"><div style="position:relative;width:96px;height:96px"><img class="px" src="assets/art/items_v2/coupon_slip.png" style="width:96px;height:96px"><img class="px slipicon" src="assets/art/icons/coupon_multipack_v2.png"></div><div class="kind">COUPON</div></div>\n'
               '    <div style="flex:1;min-width:0">\n'
               '      <div class="title">Multipack</div>\n'
               '      <div class="rule">×3 to later products sharing a tag with the product just before it</div>\n'
               '      <div class="gives"><span class="gx">×3</span><span>to the 3 Milks after it: <b>+€114</b></span></div>\n'
               '      <div class="why"><img class="px" src="assets/art/icons/fizzle.png"><span>Coupon engine: the first coupon paid nothing</span></div>\n'
               '    </div>\n'
               '    <div class="pays">pays <b>€0</b></div>\n'
               '  </div></div>')
    else:
        mon = ('<div class="abs monitor"><div class="screen" style="flex-direction:column;gap:0;padding:10px 14px">\n'
               '    <div style="display:flex;justify-content:space-between"><span class="title" style="font-size:24px">SHIFT 5/8</span><span class="title" style="font-size:24px">QUOTA €73</span></div>\n'
               '    <div class="kind" style="margin-top:14px">INSPECTION</div>\n'
               '    <div class="title" style="font-size:20px">Spot check</div>\n'
               '    <div class="rule">The 3rd product pays €0</div>\n'
               '  </div></div>')
    s = s[:i] + mon + s[j:]
    # receipt
    i = s.index('<div class="abs receipt">')
    j = s.index("</div>\n\n  <div class=\"abs key checkout\">", i)
    on = lambda k: ' on' if hover and k == 'mp' else ''
    x3 = '<b class="x3">×3</b>' if hover else ''
    ok = '<span class="pl" style="color:var(--good);font-weight:700">✓</span>'
    rc = ('<div class="abs receipt">\n'
          '    <div class="h">NEXT CUSTOMER · REG 3</div>\n'
          '    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>\n'
          '    <div class="dash"></div>\n'
          '    <div class="ln"><span class="nm">Eggs</span><span>€1.00</span><span class="pl"></span></div>\n'
          f'    <div class="ln"><span class="nm">Bread</span><span>€10.00</span>{ok}</div>\n'
          '    <div class="ln"><span class="nm">Milk</span><span>€0.00</span><span class="pl"><svg width="14" height="13" viewBox="0 0 24 22" shape-rendering="crispEdges"><polygon points="12,1 23,20 1,20" fill="#e2b33c" stroke="#2b2420" stroke-width="3"/></svg></span></div>\n'
          f'    <div class="ln{on("mp")}"><span class="nm">Multipack</span><span>€0.00</span><span class="pl"><img class="px" src="assets/art/icons/fizzle.png"></span></div>\n'
          f'    <div class="ln{" tch" if hover else ""}"><span class="nm">Milk</span>{x3}<span>€21.00</span>{ok}</div>\n'
          f'    <div class="ln{" tch" if hover else ""}"><span class="nm">Milk</span>{x3}<span>€24.00</span>{ok}</div>\n'
          f'    <div class="ln{" tch" if hover else ""}"><span class="nm">Milk</span>{x3}<span>€126.00</span>{ok}</div>\n'
          '    <div class="dash"></div>\n'
          '    <div class="ln"><span class="nm" style="font-family:Pixelify;font-size:16px">PROJECTED</span><span class="num" style="font-size:18px">€182.00</span><span class="pl"></span></div>\n'
          '    <div class="sum" style="margin-top:3px">1 fizzle<span class="hint"> · ' + ('Multipack hovered' if hover else 'hover an item') + '</span></div>\n'
          '  ')
    s = s[:i] + rc + s[j:]
    s = sub(s, "Redraw <small>1 left</small>", "Redraw <small>2 left</small>")
    # empty-slot footprints and the old belt row (incl. the closed slot) go
    s = cut(s, "[2, 1].forEach(i => {\n  const x0 = X0 + i * P + 8", "\n});\n", "\n")
    s = cut(s, "const row = [\n  ['cheese'", "inspection</div>');\n}\n")
    # overlay after the mirror pass
    s = sub(s, "</script>\n</body>", "const HOVER = " + ("true" if hover else "false") + ";\n" + overlay_js + "\n</script>\n</body>")
    return s


(D / "planning_effects_a.html").write_text(build(False), encoding="utf-8")
(D / "planning_effects_a_hover.html").write_text(build(True), encoding="utf-8")
print("ok")
