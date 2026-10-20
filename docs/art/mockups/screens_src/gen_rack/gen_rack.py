"""Builds the #56 impulse-rack mock-ups (docs/art/mockups/screens_rack_*.html) from the mirrored B2 scene.

Input: docs/art/mockups/screens_src/base_b2_mirrored.html (git show origin/main:docs/art/mockups/shift_screen_b2_mirrored.html).
Output: screens_rack_a[_start|_scan].html and screens_rack_b[_start|_scan].html in docs/art/mockups.
Run from anywhere: python docs/art/mockups/screens_src/gen_rack/gen_rack.py
"""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
MOCKUPS = HERE.parents[1]
BASE = MOCKUPS / "screens_src" / "base_b2_mirrored.html"
if not BASE.exists():
    sys.exit("missing screens_src/base_b2_mirrored.html: git show origin/main:docs/art/mockups/shift_screen_b2_mirrored.html > it")
KIT = (HERE / "kit.css").read_text(encoding="utf-8")
A = "assets/art/"
S = "screens_src/assets/"


def sub(s, old, new, count=1):
    if old not in s:
        sys.exit("missing: " + old[:90])
    return s.replace(old, new, count)


# ---------------------------------------------------------------- real data (data/cards, data/aisles)
# (sprite or None, display name, base, sticker summary, aisle id, tags for the scan popup, rule text)
CHEESE = ("cheese", "Cheese", "€3", "+4 after Bread", "cold_cases", "Food · Dairy · Cold cases", "+4 if immediately after Bread")
STRAWB = ("strawberries", "Strawberries", "€2", "+3 beside Produce", "fruit_and_veg", "Food · Produce · Fruit & veg",
          "+3 if beside a Produce product")
CROIS = ("croissant", "Croissant", "€2", "+2 beside Bakery", "bakery", "Food · Breakfast · Bakery", "+2 if beside a Bakery product")
TOFFEE = (None, "Dusty toffees", "€1", "+2 per earlier Clearance", "snacks", "Food · Snack · Clearance · Snacks",
          "+2 for each earlier Clearance product")
YOGURT = (None, "Reduced yogurt", "€2", "+3 beside Clearance", "cold_cases", "Food · Dairy · Clearance · Cold cases",
          "+3 if beside a Clearance product")

NOTE = "Pick an item for your cart, or skip."
NOTE_FULL = "Your cart is full: picking an item means removing one."
WARN = "INSPECTION NEXT SHIFT: One coupon slot fewer"   # the longest notice_text
HEADLINE = "Impulse rack: grab one before shift 1?"


def tray(card, new=False, lift=False, extra_style=""):
    spr, name, base, summ, aisle, _, _ = card
    art = (f'<img class="spr" src="{A}items_v2/{spr}.png">' if spr else
           f'<div class="pend"><img src="{S}art_pending_v2.png"><span>{name}</span></div>')
    shadow = '<svg class="sh" viewBox="0 0 40 4" shape-rendering="crispEdges"><path d="M6 0h28v1h4v2h-4v1H6V3H2V1h4z" fill="rgba(20,14,10,.25)"/></svg>'
    tag = (f'<div class="newtag"><img src="{S}sticker_burst.png"><span>NEW</span></div>'
           f'<img class="glint g1" src="{S}sparkle.png"><img class="glint g2" src="{S}sparkle.png">') if new else ""
    return (f'<div class="tray{" lift" if lift else ""}" style="{extra_style}">{shadow}{art}'
            f'<div class="stk"><div class="b">{base}</div><img class="g px" src="{A}icons/aisle_{aisle}.png"><div class="s">{summ}</div></div>{tag}</div>')


def popup(card, left, top, side):
    _, name, base, _, aisle, tags, rule = card
    tail = f'<img class="tail {side}" src="{S}popup_tail_side.png">'
    return (f'<div class="popup" style="left:{left}px;top:{top}px">{tail}'
            f'<div class="hd"><img src="{A}icons/aisle_{aisle}.png"><span class="nm">{name}</span><span class="mini">{base}</span></div>'
            f'<div class="tags">{tags}</div><div class="rule">{rule}</div></div>')


def brackets(x, y, w, h):
    out = []
    for hz, vt in (("l", "t"), ("r", "t"), ("l", "b"), ("r", "b")):
        st = (f'left:{x - 4 if hz == "l" else x + w - 12}px;top:{y - 4 if vt == "t" else y + h - 12}px;'
              f'border-{"left" if hz == "l" else "right"}-width:4px;border-{"top" if vt == "t" else "bottom"}-width:4px')
        out.append(f'<div class="brk2" style="{st}"></div>')
    return "".join(out)


def buttons(cart):
    return (f'<span class="fb">Skip</span>'
            f'<span class="fb"><img class="cart" src="{S}cart.png">View cart <span class="n">({cart})</span></span>')


# ---------------------------------------------------------------- the scene before shift 1
MON_BRIEF = '''<div class="abs monitor"><div class="screen rbrief">
    <div class="bt"><span>SHIFT <b>1/8</b></span><span>QUOTA <b>€34</b></span></div>
    <div class="bk">INSPECTION</div>
    <div class="bn">No inspection this shift</div>
  </div></div>'''

MON_B = '''<div class="abs monitor"><div class="screen rbrief">
    <div class="bt"><span>SHIFT <b>1/8</b></span><span>QUOTA <b>€34</b></span></div>
    <div class="dsh"></div>
    {note}
    {warn}
  </div></div>'''

SCENE_CSS = '''
/* #56 rack: the monitor's brief and the offer's notices (display only) */
.rbrief { flex-direction: column; gap: 4px; padding: 10px 14px; }
.rbrief .bt { display: flex; justify-content: space-between; font-family: Pixelify; font-size: 21px; }
.rbrief .bt b { font-family: Atkinson; font-weight: 750; font-size: 21px; }
.rbrief .bk { font-family: Pixelify; font-size: 12px; letter-spacing: 1px; color: var(--ink-light); margin-top: 6px; }
.rbrief .bn { font-family: Pixelify; font-size: 17px; }
.rbrief .dsh { border-top: 2px dashed var(--cream-shade); margin: 4px 0 2px; }
.rbrief .note { text-align: left; font-size: 15px; line-height: 19px; text-wrap: balance; }
.rbrief .notice { justify-content: flex-start; font-size: 15px; line-height: 19px; margin-top: 4px; text-wrap: balance; }
.checkout.off { filter: saturate(.35) brightness(.8); }
'''

RECEIPT = '''<div class="abs receipt">
    <div class="h">NEXT CUSTOMER · REG 3</div>
    <div class="dash"></div>
  </div>'''


def scene(title, header, cart, monitor):
    s = BASE.read_text(encoding="utf-8")
    s = re.sub(r"<title>.*?</title>\n<!--.*?-->", lambda m: f"<title>{title}</title>\n{header}", s, count=1, flags=re.S)
    s = sub(s, "</style>", SCENE_CSS + "\n" + KIT + "\n</style>")
    s = sub(s, '<span class="v">5/8</span>', '<span class="v">1/8</span>')
    s = sub(s, '<span class="v">€73</span><span class="bar"><i></i></span><span class="v" style="color:var(--mustard-light)">€22</span>',
            '<span class="v">€34</span><span class="bar"><i style="width:0"></i></span><span class="v" style="color:var(--mustard-light)">€0</span>')
    s = re.sub(r'\n  <div class="chip warn">.*?</div>', "", s, count=1)   # shift 1 is never inspected: no chip
    s = re.sub(r'(<span class="k">LOYALTY</span>).*?(</div>)',
               lambda m: m.group(1) + '<span class="stamp"><canvas class="px" data-glyph="empty" width="13" height="13"></canvas></span>' * 3 + m.group(2),
               s, count=1)   # the starter card: 3 empty boxes
    s = sub(s, '<span class="num" style="margin-left:6px">13/15</span>', f'<span class="num" style="margin-left:6px">{cart}</span>')
    s = re.sub(r'<div class="abs monitor"><div class="screen">.*?<div class="pays">pays <b>€0</b></div>\n  </div></div>',
               lambda m: monitor, s, count=1, flags=re.S)
    s = re.sub(r'<div class="abs receipt">.*?\n  </div>', lambda m: RECEIPT, s, count=1, flags=re.S)   # cleared for the rack
    s = sub(s, '<div class="abs key checkout">', '<div class="abs key checkout off">')
    s = sub(s, "Redraw <small>1 left</small>", "Redraw <small>2 left</small>")
    # the belt is empty before shift 1: seven blank slot tickets
    s = re.sub(r"// ================= belt items =================.*?(// ================= the hand)",
               lambda m: "// belt: empty before shift 1\nfor (let i = 0; i < 7; i++) label('label empty', X0 + i * P, 428, String(7 - i), '');\n\n" + m.group(1),
               s, count=1, flags=re.S)
    s = re.sub(r"const hand = \[.*?\n\];", "const hand = [];   // no hand before shift 1", s, count=1, flags=re.S)
    return s


def page(name, html):
    (MOCKUPS / name).write_text(html, encoding="utf-8")
    print("wrote", name)


def overlay(s, body):
    return sub(s, "</body>", f'<div class="ov">\n{body}\n</div>\n</body>')


# ================================================================ A: the styled RewardPanel pop-in
A_HEADER = """<!--
  #56 IMPULSE RACK, OPTION A (2026-10-19, decide prep, nothing decided): the styled RewardPanel pop-in.
  Idea: today's RewardPanel parts, top to bottom and in the same order, on a real paper frame over the shaded mirrored B2 scene
  (before shift 1: the belt and the baskets are empty, the receipt is cleared). The items stand on a little steel shelf whose
  front rail holds their price stickers, the same steel price rail as the belt, so the panel reads as a shelf, not a form.
  The headline sits on a teal shop-sign header strip, like the store's aisle signs.
  New art/src/ sources: frames/offer_panel (paper, 2-texel ink border, stepped hard shadow; 9-slice), frames/offer_header
  (the teal sign strip with a brass screw at each end; 9-slice, patterned ends), frames/offer_shelf (teal display niche, steel shelf top + price rail,
  a 3-band tile), effects/sparkle reused for the NEW glints. Buttons reuse frames/sign.png (both are secondary: Skip, View cart); the warning reuses icons/warning.png.
  Timing: unchanged. The same 0.22 s pop-in (scale 0.7 > 1, TRANS_BACK), armed 350 ms after the show once the mouse is up.
  Fit check: screens_rack_a.html carries the warning AND the deck-full note together (never both on the real rack, see the brief
  3.2), the longest notice (One coupon slot fewer), the longest sticker summary (+2 per earlier Clearance) and the NEW sticker
  (#65 suggestion, on the sticker's PROMO corner). Panel 600 x 414 at 340,152 (start: 600 x 384 at 340,167): inside 1280 x 720, under the top bar (<= 592 tall);
  buttons 86 x 48 and 234 x 48, 16 apart.
  _start: the real shift-1 rack (13/15, no warning). _scan: the scan popup (288 wide) open beside the NEW item, over the panel.
-->"""


def panel_a(cards, note, warn, cart, scan=None):
    rows = "".join(tray(c, new=n, lift=(scan == i)) for i, (c, n) in enumerate(cards))
    warn_html = f'<div class="notice"><img src="{S}warning.png">{WARN}</div>' if warn else ""
    top = 152 if warn else 167   # centred on 720: 414 and 384 tall (measured in Chrome)
    return f'''<div class="shade"></div>
<div class="pa" style="top:{top}px">
  <div class="pa-head"><span>{HEADLINE}</span></div>
  <div class="note">{note}</div>
  {warn_html}
  <div class="pa-shelf"><div class="pa-niche"></div><div class="pa-rail"></div><div class="pa-items">{rows}</div></div>
  <div class="pa-btns">{buttons(cart)}</div>
</div>'''


A_CSS = '''
/* ---- option A: the offer panel ---- */
.pa { position: absolute; left: 340px; width: 600px; padding: 0 24px 20px; display: flex; flex-direction: column; align-items: center; gap: 12px;
  background: var(--paper); border: 4px solid var(--ink); border-radius: 4px;
  box-shadow: inset 0 -6px 0 var(--cream), inset -4px 0 0 var(--cream), 8px 8px 0 rgba(0,0,0,.45); }
/* the header strip: a teal shop sign along the panel's top, brass screw at each end */
.pa-head { position: relative; width: calc(100% + 48px); height: 58px; margin-bottom: 2px; display: grid; place-items: center;
  background: var(--teal); border-bottom: 4px solid var(--ink); box-shadow: inset 0 4px 0 #86c2b6, inset 0 -6px 0 #3a7672; }
.pa-head::before, .pa-head::after { content: ""; position: absolute; top: 20px; width: 12px; height: 12px; background: #c8932b; border: 2px solid var(--ink);
  box-shadow: inset 2px 2px 0 #ffcf3f, inset -2px -2px 0 #8a5d1a; }   /* brass rivets, lit top left (not hollow boxes) */
.pa-head::before { left: 14px; } .pa-head::after { right: 14px; }
.pa-head span { font-family: Pixelify; font-size: 25px; color: var(--paper); letter-spacing: .5px;
  text-shadow: 2px 0 0 var(--ink), -2px 0 0 var(--ink), 0 2px 0 var(--ink), 0 -2px 0 var(--ink), 2px 2px 0 var(--ink), -2px 2px 0 var(--ink), 2px -2px 0 var(--ink), -2px -2px 0 var(--ink),
    0 4px 0 var(--ink), 2px 4px 0 var(--ink), -2px 4px 0 var(--ink); }
.pa-shelf { position: relative; width: 416px; height: 176px; margin-top: 14px; }
.pa-items { position: absolute; left: 24px; top: 0; display: flex; gap: 22px; }
/* the display niche: a recessed teal box behind the items (teal dark, stepped inner shadow top-left, lit lip bottom-right),
   so the sprites read against a dark ground like the belt's rubber instead of floating on paper. art/src: part of frames/offer_shelf */
.pa-niche { position: absolute; left: 0; top: -12px; width: 416px; height: 112px; background: #2a4d4b; border: 2px solid var(--ink); border-bottom: 0;
  box-shadow: inset 6px 6px 0 #1f3b3a, inset -2px 0 0 #3a7672; }
.pa-niche::before { content: ""; position: absolute; left: 14px; right: 6px; top: 16px; height: 2px;
  background: repeating-linear-gradient(90deg, #1f3b3a 0 4px, transparent 4px 16px); }   /* peg holes, one row (hard steps) */
/* the steel shelf: a foreshortened top face the items stand on, then the price rail the stickers clip onto */
.pa-rail { position: absolute; left: 0; top: 94px; width: 416px; height: 80px; }
.pa-rail::before { content: ""; position: absolute; left: 0; right: 0; top: 0; height: 12px; background: #c7c3b8;
  border: 2px solid var(--ink); border-bottom: 0; box-shadow: inset 0 2px 0 #ecebe4, inset 0 -2px 0 #a9a59b; }
.pa-rail::after { content: ""; position: absolute; left: 0; right: 0; top: 12px; height: 68px; background: #8d8a83;
  border: 2px solid var(--ink); box-shadow: inset 0 2px 0 #a9a59b, inset 0 -4px 0 #6f6b63, 4px 4px 0 rgba(43,36,32,.25); }
.pa-rail { z-index: 0; } .pa-items { z-index: 1; }
.pa .notice { margin-top: -4px; }
.pa-btns { display: flex; gap: 16px; margin-top: 2px; }
'''


def build_a():
    full = [(CHEESE, False), (TOFFEE, True), (STRAWB, False)]
    for name, note, warn, cart, scan in (
        ("screens_rack_a.html", NOTE_FULL, True, "15/15", None),
        ("screens_rack_a_start.html", NOTE, False, "13/15", None),
        ("screens_rack_a_scan.html", NOTE_FULL, True, "15/15", 1),
    ):
        s = scene("Impulse rack A", A_HEADER, cart, MON_BRIEF)
        s = sub(s, "</style>", A_CSS + "\n</style>")
        cards = full if (warn or scan is not None) else [(CHEESE, False), (STRAWB, False), (CROIS, False)]
        body = panel_a(cards, note, warn, cart, scan)
        if scan is not None:
            # item 1's column: panel left 340 + 4 border + 24 pad + shelf (552 - 456) / 2 = 72 + items' 44 + 130
            # => x 614..722; the popup opens right of it (8 px gap), its top level with the lifted sprite.
            ix, iy = 340 + 4 + 24 + 48 + 44 + 130, 152 + 4 + 58 + 2 + 12 + 20 + 12 + 22 + 12 + 14
            body += brackets(ix, iy, 108, 168)
            body += popup(TOFFEE, ix + 108 + 18, iy, "l")
        page(name, overlay(s, body))


# ================================================================ B: a physical impulse rack by the register
B_HEADER = """<!--
  #56 IMPULSE RACK, OPTION B (2026-10-19, decide prep, nothing decided): an impulse-buy rack prop at the checkout.
  Idea: a free-standing wire rack (velvet and brass header, teal pegboard back, one steel shelf, a lower crossbar) stands in front
  of the counter at the belt's customer end, right of the empty hand baskets. The three offered items stand on its shelf with their
  price stickers clipped on its steel rail (the belt's rail again); Skip and View cart hang from the crossbar as shop-sign buttons.
  The headline is painted on the rack's header; the note and the red inspection warning print on the hung monitor (the store's
  notice voice, like the shift screen's notices), so no paper panel floats over the store. The scene is shaded lighter (0.35)
  around the rack and the monitor, which stay lit.
  BEHAVIOUR CHANGES (to confirm with the user): the monitor shows the offer's note and warning during the rack (today the channel
  is ended and the panel carries them); the rack and the monitor are left unshaded, like the print-out's register column.
  New art/src/ sources: scenery/impulse_rack (uprights, feet, crossbar, pegboard; one prop sprite, the shelf a 3-band tile so it
  fits 3 items), frames/rack_header (velvet face, brass trim; 9-slice). Buttons reuse frames/sign.png; warning reuses icons/warning.png.
  Timing: kept identical if the rack pops in the same 0.22 s (scale 0.7 > 1 from its feet) and arms 350 ms after; a longer roll-in
  from the right edge would change presented_ms and needs a PROTOTYPE_PLAN section 8 changelog row and the timing tests updated.
  The rack is on screen only while the offer is (it is not part of the shift scene), so the hand baskets come back for shift 1.
  Fit check: screens_rack_b.html has the warning AND the deck-full note (on the monitor: 2 lines + 1 line, fits 396 px), the
  longest headline on the header (38 characters at 22 px), the longest sticker summary and the NEW sticker (#65 suggestion).
  Rack 452 x 418 at 808,294 inside 1280 x 720; buttons 86 x 48 and 234 x 48, 14 apart. _start: the real shift-1 rack. _scan: the popup (288) open left of the NEW item.
-->"""

B_CSS = '''
/* ---- option B: the rack prop (display coordinates) ---- */
.shadeb { position: absolute; left: 0; top: 64px; width: 1280px; height: 656px; background: rgba(0,0,0,.35);
  /* the monitor (rods to its foot) stays lit: an evenodd hole */
  clip-path: path(evenodd, "M0 0H1280V656H0Z M484 2H908V178H902V188H490V178H484Z"); }
.rk { position: absolute; left: 808px; top: 294px; width: 452px; height: 418px; }
.rk svg { position: absolute; left: 0; top: 0; width: 452px; height: 418px; overflow: visible; }
.rk-head { position: absolute; left: 14px; top: 0; width: 424px; height: 50px; display: grid; place-items: center;
  font-family: Pixelify; font-size: 20px; color: #ffcf3f; letter-spacing: 0; white-space: nowrap;
  text-shadow: 2px 0 0 var(--ink), -2px 0 0 var(--ink), 0 2px 0 var(--ink), 0 -2px 0 var(--ink), 2px 2px 0 #2a0e14; }
.rk-items { position: absolute; left: 42px; top: 70px; display: flex; gap: 22px; }
.rk-btns { position: absolute; left: 0; width: 452px; top: 330px; display: flex; justify-content: center; gap: 14px; }
'''


def rack_svg():
    """The rack prop on the 2 px texel grid: ink outlines, light from the upper left, palette colours only."""
    r = []
    R = lambda x, y, w, h, f: r.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{f}"/>')
    INK = "#2b2420"
    # floor shadow (stepped, to the right)
    R(16, 404, 432, 6, "rgba(20,14,10,.45)"); R(24, 410, 420, 4, "rgba(20,14,10,.3)")
    # uprights: steel tubes 10 px, lit left edge
    for x in (2, 438):
        R(x, 24, 12, 384, INK); R(x + 2, 26, 8, 380, "#a9a59b"); R(x + 2, 26, 2, 380, "#ecebe4"); R(x + 8, 26, 2, 380, "#6f6b63")
    # feet: steel plates
    for x in (-10, 426):
        R(x, 400, 36, 12, INK); R(x + 2, 402, 32, 8, "#8d8a83"); R(x + 2, 402, 32, 2, "#c7c3b8")
    # pegboard back (teal dark, peg holes on a 16 px grid), behind the items
    R(14, 50, 424, 336, INK); R(16, 50, 420, 334, "#2a4d4b"); R(16, 50, 420, 4, "#1f3b3a")   # down to the bottom rail: hides the baskets behind
    for yy in list(range(62, 160, 16)) + list(range(264, 300, 16)) + list(range(318, 382, 16)):
        for xx in range(26, 430, 16):
            R(xx, yy, 4, 4, "#1f3b3a")
    # header: brass frame, velvet face
    R(8, 0, 436, 54, INK); R(10, 2, 432, 50, "#c8932b"); R(10, 2, 432, 2, "#ffcf3f"); R(10, 48, 432, 4, "#8a5d1a")
    R(16, 8, 420, 38, INK); R(18, 10, 416, 34, "#8a1f33"); R(18, 10, 416, 4, "#b23a55"); R(18, 40, 416, 4, "#561327")
    for x in (20, 424):   # brass rivets
        R(x - 6, 20, 8, 8, INK); R(x - 4, 22, 4, 4, "#ffcf3f")
    # the shelf: foreshortened steel top face (items stand at y 166), then the price rail the stickers clip on
    R(10, 164, 432, 14, INK); R(12, 166, 428, 10, "#c7c3b8"); R(12, 166, 428, 2, "#ecebe4"); R(12, 174, 428, 2, "#a9a59b")
    R(10, 178, 432, 74, INK); R(12, 178, 428, 70, "#8d8a83"); R(12, 178, 428, 2, "#a9a59b"); R(12, 244, 428, 4, "#6f6b63")
    R(16, 252, 428, 4, "rgba(43,36,32,.35)")
    # empty peg hooks on the board under the shelf (steel stems, lit tip), the rack's own vocabulary
    for x in (40, 104, 168, 232, 296, 360):
        R(x, 264, 4, 4, INK); R(x + 2, 266, 2, 18, INK); R(x + 4, 282, 6, 4, INK); R(x + 4, 282, 4, 2, "#ecebe4")
    # the crossbar the buttons hang from
    R(10, 300, 432, 10, INK); R(12, 302, 428, 6, "#a9a59b"); R(12, 302, 428, 2, "#ecebe4")
    # chains: 2 per button (Skip 59..145, View cart 159..393 at top 330), steel links on the texel grid
    for x in (72, 130, 176, 376):
        for y in range(310, 330, 6):
            R(x, y, 4, 4, INK); R(x + 1, y + 1, 2, 2, "#c7c3b8")
    # bottom rail just above the feet
    R(10, 384, 432, 10, INK); R(12, 386, 428, 6, "#8d8a83"); R(12, 386, 428, 2, "#c7c3b8")
    return '<svg viewBox="0 0 452 418" shape-rendering="crispEdges">' + "".join(r) + "</svg>"


def rack_b(cards, cart, scan=None):
    rows = "".join(tray(c, new=n, lift=(scan == i)) for i, (c, n) in enumerate(cards))
    return f'''<div class="shadeb"></div>
<div class="rk">{rack_svg()}
  <div class="rk-head">{HEADLINE}</div>
  <div class="rk-items">{rows}</div>
  <div class="rk-btns">{buttons(cart)}</div>
</div>'''


def build_b():
    full = [(CHEESE, False), (TOFFEE, True), (STRAWB, False)]
    for name, note, warn, cart, scan in (
        ("screens_rack_b.html", NOTE_FULL, True, "15/15", None),
        ("screens_rack_b_start.html", NOTE, False, "13/15", None),
        ("screens_rack_b_scan.html", NOTE_FULL, True, "15/15", 1),
    ):
        warn_html = f'<div class="notice"><img src="{S}warning.png">{WARN}</div>' if warn else ""
        mon = MON_B.format(note=f'<div class="note">{note}</div>', warn=warn_html)
        s = scene("Impulse rack B", B_HEADER, cart, mon)
        s = sub(s, "</style>", B_CSS + "\n</style>")
        cards = full if (warn or scan is not None) else [(CHEESE, False), (STRAWB, False), (CROIS, False)]
        body = rack_b(cards, cart, scan)
        if scan is not None:
            ix, iy = 808 + 42 + 130, 294 + 70
            body += brackets(ix, iy, 108, 168)
            body += popup(TOFFEE, ix - 18 - 288, iy, "r")
        page(name, overlay(s, body))


if __name__ == "__main__":
    build_a()
    build_b()
