"""Builds the #56 deck-view mock-ups in docs/art/mockups (decide prep, nothing decided):

  screens_deck_a.html          A, binder / clipboard: Cart tab, starter deck (13/15)
  screens_deck_a_info.html     A: Run info tab (upgrades with stamp rings, inspections, stock)
  screens_deck_a_stock.html    A: Run info scrolled to the end (the stock grid, NEW arrivals)
  screens_deck_a_chooser.html  A: forced remove-an-item chooser (15/15, for Breakfast sticker)
  screens_deck_b*.html         B, counter / basket: the same three states

Every string and number comes from data/ through cards.py. Run from anywhere:
  python docs/art/mockups/screens_src/gen_deck/gen_deck.py
then capture with screens_src/gen_deck/run.sh.
"""
import html
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import cards as C  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[2]  # docs/art/mockups
SA = "screens_src/assets/"
ITEMS = "assets/art/items_v2/"
ICONS = "assets/art/icons/"
SPRITES = {"banana", "batteries", "cheese", "coffee", "crisps", "croissant", "eggs", "milk",
           "strawberries", "tea_bags"}
COUPON_ICONS = {"multipack": "coupon_multipack_v2", "two_for_one": "coupon_two_for_one_v2"}

# Geometry (canvas px on the 1280x720 stage; 1 art px = 2 canvas px).
CELL_W, CELL_H = 108, 200          # tray item 108x168 + a 32 px caption (name, xN, NEW)
COLS, GAP = 8, 8
# clear-sleeve glare (A): a 6 px band stepping down-left in 4 px stairs (hard edges, no anti-aliasing)
def _glare(rows=7, w=8):
    right = [p for k in range(rows) for p in ((34 - 4 * k, 4 * k), (34 - 4 * k, 4 * k + 4))]
    left = [p for k in reversed(range(rows)) for p in ((34 - 4 * k - w, 4 * k + 4), (34 - 4 * k - w, 4 * k))]
    return "polygon(" + ", ".join(f"{x}px {y}px" for x, y in right + left) + ")"


GLARE = _glare()
PAGE_W, PAGE_H = COLS * CELL_W + (COLS - 1) * GAP + 16, 500   # 936 x 500
PAGE_GAP = 6

STARTER = C.starter_ids()
CHOOSER_DECK = STARTER + ["tea_bags", "multipack"]   # shifts 1-2 of the brief's sample run: 15/15
CHOOSER_FOR = C.card("breakfast_sticker").name       # longest item name (BRIEF 3.3), a coupon reward
STOCK = C.stock(["cold_cases", "pantry", "household"], ["cream", "sugar_cubes"])
NEW = {"cream", "sugar_cubes"}
UPGRADES = [("coupon_engine", "CoE"), ("slot_engine", "SlE"), ("category_engine", "CaE")]
INSPECTION_LINES = [
    ("This shift", C.inspection("short_belt")),
    ("Next shift", None),
]
AISLES_LINE = ["cold_cases", "pantry", "household"]

e = html.escape
# The capture's top bar reads "Cart 13/15"; the chooser pages patch the 13 to 15 (mock-up only).
CARTFIX = '<div class="cartfix">15</div>'


def esc(s):
    return e(s).replace("  ", "&nbsp; ")


COMMON_CSS = f"""
@font-face {{ font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }}
@font-face {{ font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }}
@font-face {{ font-family: JBMono; src: url(../../../fonts/JetBrainsMono-Regular.ttf); }}
:root {{
  --ink:#2b2420; --ink-light:#4a3f38; --grey-dark:#5e574d; --grey:#8a8172; --grey-light:#c7beab;
  --cream-darkest:#b39f78; --cream-shade:#ddcba5; --cream:#f3e9d2; --paper:#fbf7ee;
  --teal-darkest:#1f3b3a; --teal-dark:#2a4d4b; --teal-shade:#3a7672; --teal:#4f9a94; --teal-light:#86c2b6; --teal-pale:#c3e0d4; --teal-black:#172c2b;
  --mustard-darkest:#7a5a1c; --mustard-dark:#b38425; --mustard:#e2b33c; --mustard-light:#f1d27a; --mustard-pale:#faecbc;
  --gold:#ffcf3f; --brass:#c8932b; --brass-dark:#8a5d1a;
  --steel-hi:#ecebe4; --steel-light:#c7c3b8; --steel-pale:#a9a59b; --steel:#8d8a83; --steel-shade:#6f6b63; --steel-dark:#57534c; --steel-darkest:#45423d;
  --wood-pale:#ddb07a; --wood-light:#c98c4e; --wood:#a8703a; --wood-dark:#6e4524; --wood-darkest:#3e2614;
  --glass:#e4f6f3; --glass2:#bfe2dd; --good:#5fae5a;
}}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: 1280px; height: 720px; overflow: hidden; background: var(--teal-darkest); }}
.stage {{ position: relative; width: 1280px; height: 720px; overflow: hidden; }}
.abs {{ position: absolute; }}
.px {{ image-rendering: pixelated; display: block; }}
.bg {{ position: absolute; left: 0; top: 0; width: 1280px; height: 720px; image-rendering: pixelated; }}
.shade {{ position: absolute; left: 0; top: 64px; width: 1280px; height: 656px; background: rgba(0,0,0,.5); }}
.pix {{ font-family: Pixelify; }}
.body {{ font-family: Atkinson; }}
.num {{ font-family: Atkinson; font-weight: 750; }}
.lt {{ color: var(--paper); -webkit-text-stroke: 4px var(--ink); paint-order: stroke fill; }}
/* the item: tray form (ItemView.Form.TRAY) */
.cell {{ position: absolute; width: {CELL_W}px; height: {CELL_H}px; }}
.cell .shadow {{ position: absolute; left: 14px; top: 94px; width: 80px; height: 8px; background: rgba(43,36,32,.25);
  clip-path: polygon(8px 0, 72px 0, 80px 2px, 80px 6px, 72px 8px, 8px 8px, 0 6px, 0 2px); }}
.cell .spr {{ position: absolute; left: 6px; top: 4px; width: 96px; height: 96px; }}
.cell .spr img {{ position: absolute; image-rendering: pixelated; }}
.cell .pname {{ position: absolute; left: 12px; top: 24px; width: 72px; height: 68px; display: flex; align-items: center; justify-content: center;
  text-align: center; font: 700 12px/12px Atkinson; color: var(--grey-dark); }}
.cell .cname {{ position: absolute; left: 26px; top: 32px; width: 60px; height: 42px; display: flex; align-items: center; justify-content: center;
  text-align: center; font: 700 12px/12px Atkinson; color: var(--ink); }}
/* PriceSticker 108x64: ticket_product.png 9-slice (top 4, sides 3 art px) or ticket_coupon.png */
.stk {{ position: absolute; left: 0; top: 104px; width: 108px; height: 64px; }}
.stk .face {{ position: absolute; inset: 0; border-style: solid; border-width: 8px 6px 6px 6px;
  border-image: url({SA}ticket_product.png) 4 3 3 3 fill stretch; image-rendering: pixelated; }}
.stk .cface {{ position: absolute; inset: 0; image-rendering: pixelated; }}
.stk .base {{ position: absolute; left: 8px; top: 6px; height: 24px; font: 750 22px/24px Atkinson; color: var(--ink); }}
.stk .ctitle {{ position: absolute; left: 8px; top: 8px; height: 20px; font: 13px/20px Pixelify; color: var(--teal-dark); }}
.stk .glyph {{ position: absolute; left: 84px; top: 8px; width: 18px; height: 18px; image-rendering: pixelated; }}
.stk .sum {{ position: absolute; left: 6px; top: 28px; width: 96px; height: 34px; font: 700 13px/14px Atkinson; color: var(--ink);
  display: flex; align-items: center; }}
/* FramedButton on sign.png (secondary) */
.sign {{ position: absolute; height: 36px; padding: 0 12px 4px; display: flex; align-items: center; justify-content: center;
  border-style: solid; border-width: 6px; border-image: url({SA}sign.png) 3 fill stretch; image-rendering: pixelated;
  font: 16px/1 Pixelify; color: var(--paper); }}
.sign span {{ word-spacing: 3px; -webkit-text-stroke: 4px var(--ink); paint-order: stroke fill; position: relative; top: 1px; }}
.cartfix {{ position: absolute; left: 1153px; top: 14px; width: 17px; height: 20px; background: var(--teal);
  font: 750 18px/20px Atkinson; color: var(--paper); letter-spacing: 0; }}
.sign.off {{ transform: translateY(4px); height: 32px; padding-bottom: 0; filter: brightness(.6); opacity: .85; }}
"""


def sprite(c):
    if not c.is_product:
        icon = COUPON_ICONS.get(c.id)
        inner = f'<img src="{ITEMS}coupon_slip.png" style="left:0;top:0;width:96px;height:96px">'
        if icon:
            inner += f'<img src="{ICONS}{icon}.png" style="left:28px;top:38px;width:40px;height:28px">'
        else:
            inner += f'<div class="cname">{e(c.name)}</div>'
        return f'<div class="spr">{inner}</div>'
    if c.id in SPRITES:
        return f'<div class="spr"><img src="{ITEMS}{c.id}.png" style="left:0;top:0;width:96px;height:96px"></div>'
    return (f'<div class="spr"><img src="{SA}art_pending_v2.png" style="left:0;top:0;width:96px;height:96px">'
            f'<div class="pname">{e(c.name)}</div></div>')


def sticker(c):
    if not c.is_product:
        return (f'<div class="stk"><img class="cface" src="{SA}ticket_coupon.png" width="108" height="64">'
                f'<div class="ctitle">COUPON</div><div class="sum">{esc(c.summary)}</div></div>')
    glyph = f'<img class="glyph" src="{ICONS}aisle_{c.aisle}.png">' if c.aisle else ""
    summ = f'<div class="sum">{esc(c.summary)}</div>' if c.summary else ""
    return f'<div class="stk"><div class="face"></div><div class="base">€{c.base}</div>{glyph}{summ}</div>'


def item(c):
    return f'<div class="shadow"></div>{sprite(c)}{sticker(c)}'


def page(title, comment, css, body, cartfix="", scroll=""):
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>{e(title)}</title>
<!--
{comment}
-->
<style>{COMMON_CSS}{css}</style></head>
<body data-scroll="{scroll}"><div class="stage">
<img class="bg" src="{SA}shift_screen_1280x720.png" alt="">
<div class="shade"></div>
{body}
{cartfix}
</div>
<script>
// Fit check: the page area's content height against PAGE_SIZE.y (500); the thumb follows it.
const pg = document.querySelector('.pagebox'), inner = document.querySelector('.pageinner');
if (pg && inner) {{
  const h = inner.scrollHeight; document.body.dataset.content = h;
  const th = document.querySelector('.thumb');
  if (th) {{ if (h <= {PAGE_H}) th.parentElement.style.display = 'none';
            else th.style.height = Math.max(24, Math.round({PAGE_H} * {PAGE_H} / h / 2) * 2) + 'px'; }}
  if (document.body.dataset.scroll === 'end' && h > {PAGE_H}) {{
    inner.style.top = ({PAGE_H} - h) + 'px';
    if (th) th.style.top = (th.parentElement.clientHeight - th.offsetHeight) + 'px'; }}
}}
const p = document.querySelector('.panel'); if (p) {{ const r = p.getBoundingClientRect();
  document.body.dataset.panel = [r.left, r.top, r.width, r.height].join(','); }}
</script>
</body></html>
"""


HEADER = """  #56 DECK VIEW, OPTION {opt} ({name}), state: {state}. Decide prep, 2026-10-19: nothing is decided.
  Idea: {idea}
  Built by screens_src/gen_deck/gen_deck.py from data/ (starter deck, real stickers, upgrades, inspections, stock).
  Background: the real game capture docs/art/shift_screen_1280x720.png under ScreenShade (black 0.5 from y 64); top bar unshaded.
  Cells: tray items (ItemView TRAY 108x168: 96 sprite + PriceSticker) plus a 32 px caption = 108x200 per cell (SUGGESTION: the caption
    carries the name, the xN copies and NEW; today the deck view has a 20 px count line under 120x168 CardViews).
  PAGE_SIZE: (8 x 108 + 7 x 8 + 16, 500) = 936 x 500. Starter page = tags 20 + heading 20 + row 200 + heading 20 + row 200 + 4 gaps of 6
    = 484 <= 500: fits unscrolled. (A 200-high item with today's separate 20 px count line under it gives rows of 222 and 528: does not fit.)
  Panel: {panel}. Height limit: pop_in centres it; the top bar (y 0-56, shade from 64) must stay clear, so <= 592 tall.
  New art/src/ sources: {sources}
  Timing: unchanged (pop_in 0.22 s + fan; no new animation; the deck view is not an offer, so no presented/armed change).
  Longest-text checks: {longest}
"""


def cells_grid(entries, top, left, cell_fn):
    out = []
    for i, entry in enumerate(entries):
        r, col = divmod(i, COLS)
        x = left + col * (CELL_W + GAP)
        y = top + r * (CELL_H + GAP)
        out.append(cell_fn(entry, x, y))
    return "\n".join(out), (len(entries) + COLS - 1) // COLS


def tags_line(ids):
    return "Tags: " + "  ·  ".join(f"{t} {n}" for t, n in C.tag_counts(ids))


def upgrade_line(uid):
    u = C.upgrade(uid)
    return u, f"{u['name']} ({u['type']})", u["effect"] + (("  ·  " + u["condition"]) if u["condition"] else "")


def inspection_text(when, insp):
    return f"{when}: {insp['name']}, {insp['notice']}" if insp else f"{when}: no inspection."


def copies_note(n):
    return f"×{n}" if n > 1 else ""


# --------------------------------------------------------------------------------------------
# Option A: binder / clipboard
# --------------------------------------------------------------------------------------------
A_CSS = f"""
/* The clipboard: a wood board (new frame art/src/frames/clipboard.txt, 9-slice), a paper sheet (new frame sheet.txt,
   reusable by every paper panel of #56), a steel clip (new prop art/src/scenery/board_clip.txt) and binder index tabs
   (new frames tab_paper.txt / tab_sign.txt). Shadows are stepped and hard; light from the upper left. */
.panel {{ position: absolute; left: 136px; top: 64px; width: 1000px; height: 592px; }}
.board {{ position: absolute; inset: 0; background: var(--ink);
  clip-path: polygon(8px 0, calc(100% - 8px) 0, 100% 8px, 100% calc(100% - 8px), calc(100% - 8px) 100%, 8px 100%, 0 calc(100% - 8px), 0 8px); }}
.board::before {{ content: ''; position: absolute; inset: 2px; background: var(--wood);
  box-shadow: inset 4px 4px 0 var(--wood-light), inset -6px -6px 0 var(--wood-dark);
  clip-path: polygon(6px 0, calc(100% - 6px) 0, 100% 6px, 100% calc(100% - 6px), calc(100% - 6px) 100%, 6px 100%, 0 calc(100% - 6px), 0 6px); }}
.hshadow {{ position: absolute; left: 144px; top: 72px; width: 1000px; height: 592px; background: rgba(23,44,43,.55);
  clip-path: polygon(8px 0, calc(100% - 8px) 0, 100% 8px, 100% calc(100% - 8px), calc(100% - 8px) 100%, 8px 100%, 0 calc(100% - 8px), 0 8px); }}
.sheet2 {{ position: absolute; left: 26px; top: 16px; width: 956px; height: 570px; background: var(--cream-shade); border: 2px solid var(--ink); }}
.sheet {{ position: absolute; left: 20px; top: 10px; width: 960px; height: 574px; background: var(--paper); border: 2px solid var(--ink);
  box-shadow: inset -2px -4px 0 var(--cream-shade);
  background-image: repeating-linear-gradient(to bottom, transparent 0 22px, var(--cream) 22px 24px); background-position: 0 66px;
  background-repeat: no-repeat; background-size: 100% calc(100% - 72px); }}
/* the ruled stock sheet: hard 2 px cream rules every 24 px (drawn into frames/sheet.txt; no gradient, hard stops only) */
.sheet .rule {{ position: absolute; left: 12px; right: 112px; top: 62px; height: 2px; background: var(--ink-light); }}
.clip {{ position: absolute; left: 410px; top: 0; width: 180px; height: 40px; }}
.clip .lever {{ position: absolute; left: 30px; top: 0; width: 120px; height: 14px; background: var(--ink);
  clip-path: polygon(6px 0, 114px 0, 120px 6px, 120px 14px, 0 14px, 0 6px); }}
.clip .lever::before {{ content:''; position:absolute; left: 2px; top: 2px; right: 2px; bottom: 0; background: var(--steel-pale);
  box-shadow: inset 2px 2px 0 var(--steel-hi); clip-path: polygon(4px 0, 112px 0, 116px 4px, 116px 12px, 0 12px, 0 4px); }}
.clip .plate {{ position: absolute; left: 0; top: 12px; width: 180px; height: 28px; background: var(--ink); }}
.clip .plate::before {{ content:''; position:absolute; inset: 2px; background: var(--steel-light);
  box-shadow: inset 2px 2px 0 var(--steel-hi), inset -2px -4px 0 var(--steel); }}
.clip .rivet {{ position: absolute; top: 22px; width: 8px; height: 8px; background: var(--steel-dark); box-shadow: 2px 2px 0 var(--steel-hi) inset; }}
.title {{ position: absolute; left: 36px; top: 42px; font: 22px/30px Pixelify; color: var(--ink); white-space: nowrap; }}
.title b {{ font: 750 22px/30px Atkinson; }}
.tape {{ display: inline-block; height: 20px; padding: 0 8px; background: var(--mustard-light); border: 2px solid var(--ink);
  font: 14px/16px Pixelify; color: var(--ink); white-space: pre; box-shadow: 2px 2px 0 var(--cream-shade); }}
.tape.teal {{ background: var(--teal-pale); }}
.line {{ font: 16px/20px Atkinson; color: var(--ink-light); white-space: pre-wrap; }}
.line b {{ font-weight: 750; color: var(--ink); }}
.pagebox {{ position: absolute; left: 32px; top: 78px; width: {PAGE_W}px; height: {PAGE_H}px; overflow: hidden; }}
.pageinner {{ position: absolute; left: 0; top: 0; width: {PAGE_W - 16}px; display: flex; flex-direction: column; gap: {PAGE_GAP}px; }}
.grid {{ position: relative; }}
.scroll {{ position: absolute; right: 0; top: 0; width: 12px; height: {PAGE_H}px; background: var(--cream-shade); border: 2px solid var(--ink); }}
.thumb {{ position: absolute; left: 0; top: 0; width: 8px; background: var(--steel); box-shadow: inset 2px 2px 0 var(--steel-light); }}
/* the pocket each item sits in: a clear sleeve stapled to the sheet (new frame pocket.txt) */
.pocket {{ position: absolute; left: 0; top: 0; width: 108px; height: 120px; background: var(--glass); border: 2px solid var(--teal-shade);
  box-shadow: inset 0 6px 0 var(--glass2); }}
.glare {{ position: absolute; left: 70px; top: 4px; width: 34px; height: 34px; background: var(--paper); opacity: .6; z-index: 1; clip-path: {GLARE}; }}
.newtag {{ position: absolute; left: 64px; top: -6px; height: 20px; padding: 0 4px; border: 2px solid var(--ink); font: 12px/16px Pixelify;
  color: var(--ink); background: var(--paper); box-shadow: 2px 2px 0 var(--ink); z-index: 2; }}
.cap {{ position: absolute; left: 0; top: 170px; width: 108px; height: 28px; display: flex; align-items: center; gap: 4px; }}
.cap .nm {{ flex: 1; min-width: 0; font: 700 13px/13px Atkinson; color: var(--ink); overflow: hidden; }}
.cap .cnt {{ height: 24px; padding: 0 5px; background: var(--mustard); border: 2px solid var(--ink); font: 750 16px/20px Atkinson; color: var(--ink);
  box-shadow: 2px 2px 0 var(--mustard-darkest); }}
.cap .new {{ height: 20px; padding: 0 4px; border: 2px solid var(--ink); font: 12px/16px Pixelify; color: var(--ink); background: var(--paper); }}
.tabs {{ position: absolute; left: 978px; top: 88px; width: 100px; }}
.tab {{ position: absolute; left: 0; width: 100px; height: 44px; display: flex; align-items: center; justify-content: center; font: 16px/1 Pixelify; }}
.tab.on {{ left: -4px; width: 106px; background: var(--paper); border: 2px solid var(--ink); border-left: none; color: var(--ink);
  box-shadow: inset 0 -4px 0 var(--cream-shade); }}
.tab.on::after {{ content: ''; position: absolute; left: -2px; top: 0; width: 4px; height: 40px; background: var(--paper); }}
.tab.idle {{ border-style: solid; border-width: 6px; border-image: url({SA}sign.png) 3 fill stretch; image-rendering: pixelated; color: var(--paper); }}
.tab.idle span {{ word-spacing: 3px; -webkit-text-stroke: 4px var(--ink); paint-order: stroke fill; }}
.stamp {{ position: relative; flex: none; width: 34px; height: 34px; }}
.stamp img {{ position: absolute; inset: 4px; width: 26px; height: 26px; image-rendering: pixelated; }}
.stamp b {{ position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font: 10px/1 Pixelify; color: var(--paper); }}
.urow {{ display: flex; gap: 8px; align-items: flex-start; }}
.irow {{ display: flex; gap: 8px; align-items: center; }}
.hover .pocket {{ border-color: var(--ink); box-shadow: inset 0 6px 0 var(--glass2), 0 0 0 2px var(--gold), 0 0 0 4px var(--ink); }}
.hover {{ transform: translateY(-4px); }}
.rmtag {{ position: absolute; left: 4px; top: -18px; height: 22px; padding: 0 6px; background: var(--mustard); border: 2px solid var(--ink);
  font: 13px/18px Pixelify; color: var(--ink); white-space: nowrap; transform: rotate(-4deg); box-shadow: 2px 2px 0 var(--ink); z-index: 3; }}
"""


def a_cell(entry, x, y):
    c, note, hover = entry
    cnt = ""
    if note.startswith("×"):
        cnt = f'<span class="cnt">{note}</span>'
    newtag = '<div class="newtag">NEW</div>' if note == "NEW" else ""
    rm = '<div class="rmtag">Remove 1</div>' if hover else ""
    return (f'<div class="cell{" hover" if hover else ""}" style="left:{x}px;top:{y}px"><div class="pocket"></div>{rm}{item(c)}<div class="glare"></div>{newtag}'
            f'<div class="cap"><span class="nm">{e(c.name)}</span>{cnt}</div></div>')


def a_grid(entries):
    rows = (len(entries) + COLS - 1) // COLS
    h = rows * CELL_H + (rows - 1) * GAP
    body, _ = cells_grid(entries, 0, 0, a_cell)
    return f'<div class="grid" style="height:{h}px">{body}</div>'


def a_deck_page(ids, hover_id=None):
    prods = [(c, copies_note(n), c.id == hover_id) for c, n in C.groups(ids) if c.is_product]
    coups = [(c, copies_note(n), c.id == hover_id) for c, n in C.groups(ids) if not c.is_product]
    np = sum(n for c, n in C.groups(ids) if c.is_product)
    nc = sum(n for c, n in C.groups(ids) if not c.is_product)
    return f"""<div class="line">{esc(tags_line(ids))}</div>
  <div><span class="tape">{esc(f'PRODUCTS  ({np})')}</span></div>
  {a_grid(prods)}
  <div><span class="tape">{esc(f'COUPONS  ({nc})')}</span></div>
  {a_grid(coups)}"""


def a_info_page():
    rows = []
    for uid, ini in UPGRADES:
        u, head, rest = upgrade_line(uid)
        rows.append(f'<div class="urow"><div class="stamp"><img src="{SA}stamp_ring.png"><b>{ini}</b></div>'
                    f'<div class="line" style="padding-top:7px"><b>{esc(head)}:</b> {esc(rest)}</div></div>')
    insp = []
    for when, i in INSPECTION_LINES:
        icon = (f'<img class="px" src="{SA}warning.png" style="width:26px;height:22px">' if i else
                '<span style="display:inline-block;width:26px"></span>')
        insp.append(f'<div class="irow">{icon}<div class="line">{esc(inspection_text(when, i))}</div></div>')
    aisles = "Aisles: " + ", ".join(C.aisle_name(a) for a in AISLES_LINE)
    stock = [(c, "NEW" if c.id in NEW else "", False) for c in STOCK]
    return f"""<div><span class="tape">UPGRADES</span></div>
  {''.join(rows)}
  <div><span class="tape">INSPECTIONS</span></div>
  {''.join(insp)}
  <div><span class="tape">{esc('STOCK  (every card a reward or the impulse rack can offer this run)')}</span></div>
  <div class="irow"><div class="line">{esc(aisles)}</div>{''.join(f'<img class="px" src="{ICONS}aisle_{a}.png" style="width:18px;height:18px">' for a in AISLES_LINE)}</div>
  {a_grid(stock)}"""


def option_a(state):
    if state == "chooser":
        title = f"Cart full (15/15): choose an item to remove for {CHOOSER_FOR}"
        inner = a_deck_page(CHOOSER_DECK, hover_id="soup")
        tabs = ""
    else:
        title = "Your cart (13/15)"
        inner = a_deck_page(STARTER) if state == "cart" else a_info_page()

        on_cart = state == "cart"
        tabs = (f'<div class="tabs"><div class="tab {"on" if on_cart else "idle"}" style="top:0"><span>Cart</span></div>'
                f'<div class="tab {"idle" if on_cart else "on"}" style="top:52px"><span>Run info</span></div></div>')
    body = f"""<div class="hshadow"></div>
<div class="panel">
  <div class="board"></div>
  <div class="sheet2"></div>
  <div class="sheet"><div class="rule"></div></div>
  {tabs}
  <div class="clip"><div class="lever"></div><div class="plate"></div><div class="rivet" style="left:14px"></div><div class="rivet" style="left:158px"></div></div>
  <div class="title">{esc(title)}</div>
  <div class="sign" style="left:880px;top:40px;width:84px"><span>Close</span></div>
  <div class="pagebox"><div class="pageinner">
  {inner}
  </div><div class="scroll"><div class="thumb"></div></div></div>
</div>"""
    idea = ("the cart is a clipboard with a stock sheet: each item sits in a clear pocket with its name typed under it and the "
            "copies on a mustard tag; headings are label-maker tape; Cart and Run info are binder index tabs on the sheet's right "
            "edge; Run info shows the loyalty stamp ring (initials until #59's perk glyphs) beside each upgrade.")
    states = {"cart": "Cart tab, starter deck", "info": "Run info tab (shift 5, 3 upgrades, Short belt)",
              "stock": "Run info tab scrolled to the end: the stock grid (22 products incl. 2 NEW arrivals + 8 coupons = 30 cells, 4 rows)",
              "chooser": "forced chooser, 15/15, Soup hovered"}
    comment = HEADER.format(
        opt="A", name="binder / clipboard", state=states[state], idea=idea,
        panel="1000x592 at (136,64), exactly the 592 limit: board 1000 wide, sheet 960x574, page 936x500 at (168,142); the index tabs stick out right to x 1214",
        sources=("frames/clipboard.txt (wood board 9-slice), frames/sheet.txt (paper sheet 9-slice, shared with the other paper "
                 "panels), frames/pocket.txt (clear sleeve), frames/tape.txt (label tape 9-slice), frames/tab_paper.txt (active "
                 "index tab; the idle tab reuses sign.png), scenery/board_clip.txt (steel clip). Stamp ring reuses icons/stamp_ring.png."),
        longest=("chooser title 'Cart full (15/15): choose an item to remove for Breakfast sticker' (longest name); Run info: the Slot engine line "
                 "(wraps to 2 lines), 'Flickering bulb' and 'Reduced yogurt' captions (wrap to 2 lines in the 108 caption), the "
                 "STOCK heading."))
    if state == "chooser":
        comment += ("  Chooser: tabs hidden, Close cancels (as today). SUGGESTION, a behaviour addition: the hovered item lifts 4 px in a "
                    "gold ring with a 'Remove 1' tape (not colour alone). Today hover does nothing visible.\n")
    return page({"cart": "Deck view A", "info": "Deck view A info", "stock": "Deck view A stock", "chooser": "Deck view A chooser"}[state],
                comment, A_CSS, body, CARTFIX if state == "chooser" else "", "end" if state == "stock" else "")


# --------------------------------------------------------------------------------------------
# Option B: on the counter, in the shopping basket
# --------------------------------------------------------------------------------------------
B_CSS = f"""
/* The basket: the panel is one of the counter's teal hand baskets seen front-on, emptied onto two steel shelves.
   New sources: frames/basket_panel.txt (teal plastic 9-slice with the rim, the slot holes and the cart badge drawn
   at full size along the bottom), scenery/shelf_rail.txt (the steel price rail behind each row, tiled like the belt's
   rail). The xN copies reuse sticker_label.png (the price-gun label from #71); NEW reuses sticker_burst.png. */
.panel {{ position: absolute; left: 152px; top: 68px; width: 976px; height: 584px; }}
.hshadow {{ position: absolute; left: 160px; top: 76px; width: 976px; height: 584px; background: rgba(23,44,43,.6);
  clip-path: polygon(10px 0, calc(100% - 10px) 0, 100% 10px, 100% 100%, 0 100%, 0 10px); }}
.basket {{ position: absolute; inset: 0; background: var(--ink);
  clip-path: polygon(10px 0, calc(100% - 10px) 0, 100% 10px, 100% calc(100% - 14px), calc(100% - 14px) 100%, 14px 100%, 0 calc(100% - 14px), 0 10px); }}
.basket::before {{ content: ''; position: absolute; inset: 2px; background: var(--teal);
  box-shadow: inset 4px 4px 0 var(--teal-light), inset -4px -6px 0 var(--teal-shade);
  clip-path: polygon(8px 0, calc(100% - 8px) 0, 100% 8px, 100% calc(100% - 12px), calc(100% - 12px) 100%, 12px 100%, 0 calc(100% - 12px), 0 8px); }}
.rim {{ position: absolute; left: 0; top: 0; width: 976px; height: 50px; }}
.rim .lip {{ position: absolute; left: 10px; right: 10px; top: 44px; height: 6px; background: var(--teal-shade); border-top: 2px solid var(--ink); }}
.inside {{ position: absolute; left: 10px; top: 52px; width: 956px; height: 504px; background: var(--teal-dark);
  border: 2px solid var(--ink); box-shadow: inset 0 8px 0 var(--teal-darkest); }}
.holes {{ position: absolute; left: 0; right: 0; top: 558px; height: 24px; display: flex; justify-content: center; gap: 10px; align-items: center; }}
.holes i {{ display: block; width: 34px; height: 10px; background: var(--teal-darkest); border-top: 2px solid var(--ink); }}
.badge {{ width: 44px !important; height: 22px !important; background: var(--teal-darkest) !important; border: 2px solid var(--ink) !important;
  display: flex !important; align-items: center; justify-content: center; }}
.title {{ position: absolute; left: 22px; top: 8px; font: 22px/32px Pixelify; color: var(--paper); -webkit-text-stroke: 6px var(--ink);
  paint-order: stroke fill; white-space: nowrap; word-spacing: 4px; }}
.title .cart {{ display: inline-block; vertical-align: -2px; width: 24px; height: 18px; margin-right: 8px; image-rendering: pixelated; }}
.line {{ font: 16px/20px Atkinson; color: var(--cream); white-space: pre-wrap; }}
.line b {{ font-weight: 750; color: var(--paper); }}
.line .ty {{ color: var(--teal-light); }}
.head {{ font: 16px/20px Pixelify; color: var(--mustard); white-space: pre; }}
.pagebox {{ position: absolute; left: 20px; top: 54px; width: {PAGE_W}px; height: {PAGE_H}px; overflow: hidden; }}
.pageinner {{ position: absolute; left: 0; top: 4px; width: {PAGE_W - 16}px; display: flex; flex-direction: column; gap: {PAGE_GAP}px; }}
.grid {{ position: relative; }}
.rail {{ position: absolute; left: 0; width: {PAGE_W - 16}px; height: 40px; background: var(--ink); }}
.rail::before {{ content: ''; position: absolute; left: 0; right: 0; top: 2px; bottom: 2px; background: var(--steel);
  box-shadow: inset 0 4px 0 var(--steel-light), inset 0 -6px 0 var(--steel-dark); }}
.scroll {{ position: absolute; right: 0; top: 4px; width: 12px; height: {PAGE_H - 8}px; background: var(--teal-darkest); border: 2px solid var(--ink); }}
.thumb {{ position: absolute; left: 0; top: 0; width: 8px; background: var(--teal-light); box-shadow: inset 2px 2px 0 var(--teal-pale); }}
.pendback {{ position: absolute; left: 14px; top: 10px; width: 80px; height: 84px; background: var(--cream-shade); }}
.ghost {{ position: absolute; left: 14px; top: -4px; width: 96px; height: 96px; filter: brightness(.62); }}
.ghost2 {{ left: 22px; top: -8px; filter: brightness(.45); }}
.ghost img {{ position: absolute; inset: 0; width: 96px; height: 96px; image-rendering: pixelated; }}
.gun {{ position: absolute; left: 62px; top: 0px; height: 28px; min-width: 40px; padding: 0 6px; display: flex; align-items: center; justify-content: center;
  border-style: solid; border-width: 6px; border-image: url({SA}sticker_label.png) 6 fill stretch; image-rendering: pixelated;
  font: 750 16px/1 Atkinson; color: var(--ink); transform: rotate(6deg); z-index: 2; }}
.burst {{ position: absolute; left: 50px; top: 4px; width: 62px; height: 34px; z-index: 2; transform: rotate(-8deg); }}
.burst img {{ position: absolute; inset: 0; width: 62px; height: 34px; image-rendering: pixelated; }}
.burst b {{ position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font: 13px/1 Pixelify; color: var(--ink); }}
.cap {{ position: absolute; left: 0; top: 172px; width: 108px; height: 28px; text-align: center; font: 700 13px/13px Atkinson; color: var(--paper); overflow-wrap: anywhere;
  display: flex; align-items: center; justify-content: center; }}
.irow {{ display: flex; gap: 8px; align-items: center; }}
.hover {{ transform: translateY(-6px); }}
.hover .halo {{ position: absolute; left: -2px; top: -2px; width: 112px; height: 108px; background: var(--gold);
  clip-path: polygon(8px 0, 104px 0, 112px 8px, 112px 100px, 104px 108px, 8px 108px, 0 100px, 0 8px); opacity: .9; }}
.hover .halo::before {{ content: ''; position: absolute; inset: 4px; background: var(--teal-dark);
  clip-path: polygon(6px 0, calc(100% - 6px) 0, 100% 6px, 100% calc(100% - 6px), calc(100% - 6px) 100%, 6px 100%, 0 calc(100% - 6px), 0 6px); }}
.rmtag {{ position: absolute; left: 6px; top: -22px; z-index: 3; height: 26px; padding: 0 6px; display: flex; align-items: center;
  border-style: solid; border-width: 6px; border-image: url({SA}sticker_label.png) 6 fill stretch; image-rendering: pixelated;
  font: 13px/1 Pixelify; color: var(--ink); white-space: nowrap; transform: rotate(-5deg); }}
"""


def b_cell(entry, x, y):
    c, n, note, hover = entry
    ghosts = ""
    if n > 1 and (c.id in SPRITES or not c.is_product):
        src = f"{ITEMS}{c.id}.png" if c.is_product else f"{ITEMS}coupon_slip.png"
        ghosts = (f'<div class="ghost ghost2"><img src="{src}"></div>' if n > 2 else "") + f'<div class="ghost"><img src="{src}"></div>'
    elif n > 1:
        ghosts = (f'<div class="ghost ghost2"><img src="{SA}art_pending_v2.png"></div>' if n > 2 else "") + \
                 f'<div class="ghost"><img src="{SA}art_pending_v2.png"></div>'
    gun = f'<div class="gun">×{n}</div>' if n > 1 else ""
    burst = f'<div class="burst"><img src="{SA}sticker_burst.png"><b>NEW</b></div>' if note == "NEW" else ""
    rm = '<div class="rmtag">Remove 1</div>' if hover else ""
    halo = '<div class="halo"></div>' if hover else ""
    back = '<div class="pendback"></div>' if c.is_product and c.id not in SPRITES else ""
    return (f'<div class="cell{" hover" if hover else ""}" style="left:{x}px;top:{y}px">{halo}{ghosts}{back}{item(c)}{gun}{burst}{rm}'
            f'<div class="cap"><span>{e(c.name)}</span></div></div>')


def b_grid(entries):
    rows = (len(entries) + COLS - 1) // COLS
    h = rows * CELL_H + (rows - 1) * GAP
    rails = "".join(f'<div class="rail" style="top:{r * (CELL_H + GAP) + 116}px"></div>' for r in range(rows))
    body, _ = cells_grid(entries, 0, 0, b_cell)
    return f'<div class="grid" style="height:{h}px">{rails}{body}</div>'


def b_deck_page(ids, hover_id=None):
    gs = C.groups(ids)
    prods = [(c, n, "", c.id == hover_id) for c, n in gs if c.is_product]
    coups = [(c, n, "", c.id == hover_id) for c, n in gs if not c.is_product]
    np = sum(n for c, n in gs if c.is_product)
    nc = sum(n for c, n in gs if not c.is_product)
    return f"""<div class="line">{esc(tags_line(ids))}</div>
  <div class="head">{esc(f'PRODUCTS  ({np})')}</div>
  {b_grid(prods)}
  <div class="head">{esc(f'COUPONS  ({nc})')}</div>
  {b_grid(coups)}"""


def b_info_page():
    rows = []
    for uid, _ in UPGRADES:
        u = C.upgrade(uid)
        rest = u["effect"] + (("  ·  " + u["condition"]) if u["condition"] else "")
        rows.append(f'<div class="line"><b>{esc(u["name"])}</b> <span class="ty">({esc(u["type"])})</span>: {esc(rest)}</div>')
    insp = []
    for when, i in INSPECTION_LINES:
        icon = (f'<img class="px" src="{SA}warning.png" style="width:26px;height:22px">' if i else
                '<span style="display:inline-block;width:26px"></span>')
        insp.append(f'<div class="irow">{icon}<div class="line">{esc(inspection_text(when, i))}</div></div>')
    aisles = "Aisles: " + ", ".join(C.aisle_name(a) for a in AISLES_LINE)
    stock = [(c, 1, "NEW" if c.id in NEW else "", False) for c in STOCK]
    return f"""<div class="head">UPGRADES</div>
  {''.join(rows)}
  <div class="head">INSPECTIONS</div>
  {''.join(insp)}
  <div class="head">{esc('STOCK  (every card a reward or the impulse rack can offer this run)')}</div>
  <div class="irow"><div class="line">{esc(aisles)}</div>{''.join(f'<img class="px" src="{ICONS}aisle_{a}.png" style="width:18px;height:18px">' for a in AISLES_LINE)}</div>
  {b_grid(stock)}"""


def option_b(state):
    if state == "chooser":
        title = f"Cart full (15/15): choose an item to remove for {CHOOSER_FOR}"
        inner = b_deck_page(CHOOSER_DECK, hover_id="soup")
        buttons = '<div class="sign" style="left:870px;top:6px;width:84px"><span>Close</span></div>'
    else:
        title = "Your cart (13/15)"
        inner = b_deck_page(STARTER) if state == "cart" else b_info_page()
        on_cart = state == "cart"
        buttons = (f'<div class="sign{" off" if on_cart else ""}" style="left:656px;top:6px;width:84px"><span>Cart</span></div>'
                   f'<div class="sign{"" if on_cart else " off"}" style="left:748px;top:6px;width:110px"><span>Run info</span></div>'
                   f'<div class="sign" style="left:870px;top:6px;width:84px"><span>Close</span></div>')
    holes = "".join("<i></i>" for _ in range(9))
    body = f"""<div class="hshadow"></div>
<div class="panel">
  <div class="basket"></div>
  <div class="rim"><div class="lip"></div></div>
  <div class="title"><img class="cart" src="{SA}cart.png">{esc(title)}</div>
  {buttons}
  <div class="inside"></div>
  <div class="pagebox"><div class="pageinner">
  {inner}
  </div><div class="scroll"><div class="thumb"></div></div></div>
  <div class="holes">{holes}<i class="badge"><img class="px" src="{SA}cart.png" style="width:24px;height:18px"></i>{holes}</div>
</div>"""
    idea = ("the cart is one of the counter's teal hand baskets, emptied onto steel shelves: items stand on a price rail like "
            "the belt's, copies stand stacked behind the first (darkened) with a cream price-gun label 'xN' slapped on, new arrivals "
            "wear a gold NEW starburst; the title sits on the basket rim with the tabs and Close as shop-sign buttons; Run info is "
            "text only (no perk stamps). Art-pending boxes get a cream-shade backing so their printed names read on the dark "
            "basket floor (mock-up only; it goes away as the item sprites land).")
    states = {"cart": "Cart tab, starter deck", "info": "Run info tab (shift 5, 3 upgrades, Short belt)",
              "stock": "Run info tab scrolled to the end: the stock grid (22 products incl. 2 NEW arrivals + 8 coupons = 30 cells, 4 rows)",
              "chooser": "forced chooser, 15/15, Soup hovered"}
    comment = HEADER.format(
        opt="B", name="counter / shopping basket", state=states[state], idea=idea,
        panel="976x584 at (152,68): rim 50, inside 956x504, page 936x500 at (20,54) (the 16 px scrollbar gutter stays clear of column 8), slot-hole band 24",
        sources=("frames/basket_panel.txt (teal basket 9-slice; rim, slot holes and cart badge at full size), scenery/shelf_rail.txt "
                 "(steel rail strip). Reuses sign.png buttons, effects/sticker_label.png (xN, Remove 1) and effects/sticker_burst.png (NEW: "
                 "a SUGGESTION that pre-empts #65's sticker; the brief's default keeps NEW as text)."),
        longest=("chooser title (the rim's widest text; the tabs are hidden there), the Slot engine line (wraps to 2 lines), "
                 "'Flickering bulb' / 'Reduced yogurt' captions, the STOCK heading."))
    if state == "chooser":
        comment += ("  Chooser: tabs hidden, Close cancels (as today). SUGGESTION, a behaviour addition: the hovered item lifts 6 px in a "
                    "stepped gold halo with a 'Remove 1' price-gun label (not colour alone).\n")
    return page({"cart": "Deck view B", "info": "Deck view B info", "stock": "Deck view B stock", "chooser": "Deck view B chooser"}[state],
                comment, B_CSS, body, CARTFIX if state == "chooser" else "", "end" if state == "stock" else "")


def main():
    for opt, fn in (("a", option_a), ("b", option_b)):
        for state, suffix in (("cart", ""), ("info", "_info"), ("stock", "_stock"), ("chooser", "_chooser")):
            path = OUT / f"screens_deck_{opt}{suffix}.html"
            path.write_text(fn(state), encoding="utf-8")
            print("wrote", path.relative_to(OUT.parents[2]))


if __name__ == "__main__":
    main()
