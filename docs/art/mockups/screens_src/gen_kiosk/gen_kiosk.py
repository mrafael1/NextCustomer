"""Builds the #56 exit-kiosk mock-ups (directions A and B) on the mirrored B2 scene.

Run from anywhere: python docs/art/mockups/screens_src/gen_kiosk/gen_kiosk.py
Writes docs/art/mockups/screens_kiosk_a.html, screens_kiosk_a_hover.html, screens_kiosk_b.html, screens_kiosk_b_hover.html.
The base scene is docs/art/mockups/screens_src/base_b2_mirrored.html (git show origin/main:docs/art/mockups/shift_screen_b2_mirrored.html).
The kiosk is drawn in an overlay after the base page's script, so the base's mirror pass never touches it.
"""
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
MOCKUPS = HERE.parents[1]  # docs/art/mockups
BASE = MOCKUPS / "screens_src" / "base_b2_mirrored.html"

if not BASE.exists() or BASE.stat().st_size == 0:
    BASE.write_text(subprocess.run(["git", "show", "origin/main:docs/art/mockups/shift_screen_b2_mirrored.html"],
                                   capture_output=True, text=True, encoding="utf-8", cwd=MOCKUPS).stdout, encoding="utf-8")
base = BASE.read_text(encoding="utf-8")


def sub(s, old, new, count=1):
    if old not in s:
        sys.exit("missing: " + old[:80])
    return s.replace(old, new, count)


# ---------------------------------------------------------------- real data (data/upgrades/*.tres, verbatim)
U = {
    "slot": ("Slot engine", "SLOT ENGINE", "Your 6th product pays ×2",
             "Only the 6th product (coupons don't count): the 7th with Big basket, the 5th on a Short belt shift; no effect with fewer",
             "Breakfast special", "slot"),
    "big": ("Big basket", "RISKY", "+1 product slot", "Your quota is 15% higher from the next shift (rounded up)",
            "Clearance collector, Bulk buyer", "basket"),
    "cat": ("Category engine", "CATEGORY ENGINE", "+3 for each different tag among your products", "Paid on the last product in the row",
            "Mixed basket", "tag"),
    "redraw": ("Extra redraw", "ECONOMY", "+1 redraw each shift", "", "Any build", "redraw"),
}
TITLE_BIG, TITLE_SMALL = "EXIT KIOSK", "pick your prize"   # UpgradePanel.TITLE "EXIT KIOSK: pick your prize", split over two lines
NOTE = "Pick one ticket. It goes on your loyalty card for the rest of the run."

# ---------------------------------------------------------------- shared CSS (prefixed kk- so it never meets the base's classes)
CSS = r"""
<style>
#ov { position: absolute; left: 0; top: 0; width: 1280px; height: 720px; z-index: 20; font-family: Atkinson, sans-serif; color: var(--ink); }
#ov div, #ov span { box-sizing: border-box; }
#ov .a { position: absolute; }
.kk-shade { left: 0; top: 64px; width: 1280px; height: 656px; background: rgba(0,0,0,.5); }
.kk-pix { image-rendering: pixelated; }
.kk-out { text-shadow: 2px 0 0 #2b2420, -2px 0 0 #2b2420, 0 2px 0 #2b2420, 0 -2px 0 #2b2420, 2px 2px 0 #2b2420, -2px -2px 0 #2b2420,
  2px -2px 0 #2b2420, -2px 2px 0 #2b2420, 4px 4px 0 #2b2420; }   /* the 6 px ink outline of light display text, in 2 px steps */
/* ---- the ticket (shared fields, same order on every ticket: name, type, effect, condition, supports) ---- */
.kk-t { position: absolute; display: flex; flex-direction: column; background: #fbf7ee; border: 2px solid #2b2420; }
.kk-t .nm { font-family: Pixelify; font-size: 24px; line-height: 26px; color: #2b2420; }
.kk-t .ty { font-weight: 750; font-size: 12px; letter-spacing: 1.5px; color: #3a7672; margin-top: 3px; }
.kk-t .ef { font-weight: 750; font-size: 17px; line-height: 21px; margin-top: 10px; color: #2b2420; }
.kk-t .co { font-size: 14px; line-height: 18px; color: #4a3f38; margin-top: 10px; padding-top: 8px; }
.kk-t .co.none { color: #8a8172; font-style: italic; }
.kk-t .su { margin-top: auto; font-size: 13px; line-height: 16px; color: #5e574d; }
.kk-t .su b { font-weight: 750; color: #4a3f38; }
/* INSTANT WINNER! gag (cosmetic only, never hides a field) */
.kk-win { width: 112px; height: 74px; }
.kk-win span { position: absolute; left: 0; top: 19px; width: 112px; text-align: center; font-family: Pixelify; font-size: 15px; line-height: 17px; color: #2b2420; }
.kk-spark { width: 10px; height: 10px; }
.kk-spark::before, .kk-spark::after { content: ''; position: absolute; background: #ffcf3f; box-shadow: 0 0 0 2px #2b2420; }
.kk-spark::before { left: 4px; top: 0; width: 2px; height: 10px; }
.kk-spark::after { left: 0; top: 4px; width: 10px; height: 2px; }
</style>
"""


def star_svg(w, h, fill, n=14, inner=.74):
    """A pixel starburst (crisp edges), drawn in an svg w x h."""
    import math
    cx, cy, pts = w / 2, h / 2, []
    for i in range(n * 2):
        r = 1 if i % 2 == 0 else inner
        a = math.pi * i / n - math.pi / 2
        pts.append(f"{round((cx + (w / 2 - 4) * r * math.cos(a)) / 2) * 2},{round((cy + (h / 2 - 4) * r * math.sin(a)) / 2) * 2}")
    p = " ".join(pts)
    return (f'<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" shape-rendering="crispEdges" style="position:absolute;left:0;top:0">'
            f'<polygon points="{p}" transform="translate(4,4)" fill="#2b2420"/>'
            f'<polygon points="{p}" fill="{fill}" stroke="#2b2420" stroke-width="3"/></svg>')


def badge(x, y, w, h, text, fs, rot=-4, n=12):
    """Gold starburst badge with Pixelify ink text (replaces the old meaningless "NC" monogram)."""
    return (f'<div class="a" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;transform:rotate({rot}deg);z-index:6">'
            + star_svg(w, h, "#ffcf3f", n) +
            f'<div class="a" style="left:0;top:0;width:{w}px;height:{h}px;display:flex;align-items:center;justify-content:center;'
            f'text-align:center;font-family:Pixelify;font-size:{fs}px;line-height:{fs + 1}px;color:#2b2420">{text}</div></div>')


def rivets(x0, y0, x1, y1, col="#c8932b", z=5):
    """Four 6x6 brass rivets (lit upper-left) at a panel's corners."""
    out = []
    for x, y in ((x0, y0), (x1 - 6, y0), (x0, y1 - 6), (x1 - 6, y1 - 6)):
        out.append(f'<div class="a" style="left:{x}px;top:{y}px;width:6px;height:6px;background:{col};'
                   f'box-shadow:0 0 0 2px #2b2420, inset 2px 2px 0 #ffcf3f;z-index:{z}"></div>')
    return "".join(out)


def glow(x, y, w, h, rgb="255,207,63", steps=(.10, .07, .04), step=8, z=1):
    """A stepped (hard-edged) light halo drawn in code as alpha, never as extra palette colours."""
    out = []
    for i, a in enumerate(steps):
        d = step * (i + 1)
        out.append(f'<div class="a" style="left:{x - d}px;top:{y - d}px;width:{w + 2 * d}px;height:{h + 2 * d}px;'
                   f'background:rgba({rgb},{a});z-index:{z};pointer-events:none"></div>')
    return "".join(out)


def winner(x, y, rot):
    return (f'<div class="a kk-win" style="left:{x}px;top:{y}px;transform:rotate({rot}deg);z-index:9">{star_svg(112, 74, "#ffcf3f")}'
            f'<span>INSTANT<br>WINNER!</span></div>')


def fields(key):
    nm, ty, ef, co, su, _ = U[key]
    cond = f'<div class="co">{co}</div>' if co else '<div class="co none">No condition</div>'
    return nm, ty, ef, cond, su


# ---------------------------------------------------------------- shared JS: pixel perk stamps, bulbs
JS_COMMON = r"""
<script>
// perk glyphs (7 x 7 texels, #59 draws the real ones): the base page's slot / tag / coupon, plus a basket and a redraw
const PERK = {
  slot:   ['CCCCCCC', 'C.....C', 'C.CCC.C', 'C.CCC.C', 'C.CCC.C', 'C.....C', 'CCCCCCC'],
  tag:    ['..CCCCC', '.CCCCCC', 'CC.CCCC', 'CCCCCCC', '.CCCCCC', '..CCCCC', '.......'],
  coupon: ['.......', 'CCCCCCC', 'C.CCCCC', '.CCCCC.', 'C.CCCCC', 'CCCCCCC', '.......'],
  basket: ['..C.C..', '.C...C.', 'CCCCCCC', 'C.C.C.C', 'C.C.C.C', '.CCCCC.', '.......'],
  redraw: ['..CCC.C', '.C...CC', 'C...CCC', 'C......', 'C.....C', '.C...C.', '..CCC..'] };
// the top bar on shift 4: one upgrade owned (Coupon engine from shift 2), two empty boxes
document.querySelectorAll('.stamp canvas').forEach((c, i) => {
  c.getContext('2d').clearRect(0, 0, 13, 13);
  pxDisc(c, i === 0 ? { ring: '#f1d27a', inner: '#e2b33c', fill: '#2a4d4b', glyph: PERK.coupon, ink: '#faecbc' }
    : { ring: 'rgba(251,247,238,.4)', dash: true });
});
document.querySelectorAll('canvas[data-perk]').forEach(c => pxDisc(c, { ring: '#2b2420', inner: '#e2b33c', fill: '#2a4d4b',
  glyph: PERK[c.dataset.perk], ink: '#faecbc', shadow: 'rgba(43,36,32,.35)' }));
</script>
"""


def page(title, header, scene_html, js=""):
    s = base
    s = sub(s, "<title>Shift screen B2 mirrored</title>", f"<title>{title}</title>\n{header}")
    # the scene behind: shift 4 of 8 just checked out (quota €61 met with €88), next shift is inspected (Short belt)
    s = sub(s, '<span class="k">SHIFT</span><span class="v">5/8</span>', '<span class="k">SHIFT</span><span class="v">4/8</span>')
    s = sub(s, '<span class="v">€73</span><span class="bar"><i></i></span><span class="v" style="color:var(--mustard-light)">€22</span>',
            '<span class="v">€61</span><span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€88</span>')
    s = sub(s, "</style>\n</head>", "</style>\n" + CSS + "</head>")
    s = sub(s, "</script>\n</body>", "</script>\n" + scene_html + JS_COMMON + js + "\n</body>")
    return s


# ================================================================= DIRECTION A: lottery ticket dispenser
A_HEADER = """<!--
  #56 EXIT KIOSK, DIRECTION A: LOTTERY TICKET DISPENSER (decide-round option, 2026-10-19; nothing decided)
  Idea: a velvet-and-brass lottery kiosk with a chaser-bulb marquee is wheeled in front of the shaded checkout. Its three prize
  tickets hang from the dispenser mouth like scratch tickets torn off a roll (perforated stub, serial, gold inner frame). No glass
  globe, no crank, no coin slot: it reads as a ticket booth, never a coin-op capsule machine (#63). No buttons, no skip.
  Ticket fields, in order: name, TYPE, effect, condition (or "No condition", italic muted), "Supports: ...".
  The condition moves off tomato (tomato = fizzle / CHECKOUT / CLOSED): ink-light under a dotted rule.
  Perk stamp: shown here (decision 4 "yes"): a 13x13 ring by the name with #59's perk glyph (placeholders here).
  Hover (screens_kiosk_a_hover): the ticket lifts 6 px in a mustard/gold ring (off tomato), the cosmetic INSTANT WINNER! starburst is
  slapped on it, and the next empty box on the top bar's LOYALTY chip lights up where the ticket will go.
  Receipt in: the "RECEIPT IN" slot on the lower panel is where #66's torn receipt goes; the roll window shows the ticket roll.
  New art/src sources: frames/kiosk_ticket_lottery (9-slice: stub + gold inner frame), scenery/kiosk_lottery (cabinet, marquee,
  mouth, roll window, receipt slot; static, drawn once at 1x), effects/instant_winner (starburst), the perk glyphs (#59).
  Timing: unchanged. The kiosk pops in like today's panel (UiKit.pop_in, 0.22 s) and arms 350 ms later; tickets drop from the mouth
  only in #66's ceremony. presented_ms / armed_ms keep their meaning, no PROTOTYPE_PLAN section 8 row.
  Fit check: the longest triple, Slot engine + Big basket + Category engine (Slot engine's condition is the longest text);
  the hover page shows a "No condition" ticket (Extra redraw + Slot engine + Big basket).
  Layout: the prop stands on the floor (y 712) and spans y 70-712; it is a prop, not a centred pop_in panel, so the 592 px panel
  limit does not apply; the top bar (0-56) stays unshaded and clickable (Cart hides the tickets as today).
-->"""

A_TICKET_W, A_TICKET_H, A_GAP = 248, 272, 20


def a_ticket(key, x, y, serial, hover=False, perk=True):
    nm, ty, ef, cond, su = fields(key)
    lift = -6 if hover else 0
    ring = ("box-shadow: 0 0 0 4px #e2b33c, 0 0 0 6px #2b2420, 0 0 0 10px #ffcf3f, 0 0 0 12px #2b2420, 6px 14px 0 12px rgba(20,10,6,.45);"
            if hover else "box-shadow: 4px 4px 0 rgba(20,10,6,.45);")
    stamp = (f'<canvas class="kk-pix" data-perk="{U[key][5]}" width="14" height="14" '
             f'style="position:absolute;right:-10px;top:14px;width:28px;height:28px;z-index:3"></canvas>') if perk else ""
    return f'''<div class="kk-t" style="left:{x}px;top:{y + lift}px;width:{A_TICKET_W}px;height:{A_TICKET_H}px;{ring}z-index:4">
  <div style="height:22px;padding-top:6px !important;border-bottom:2px dotted #8a8172;display:flex;justify-content:space-between;align-items:center;padding:0 30px 0 10px;
    font-family:JBMono;font-size:9px;color:#8a8172;background:#f3e9d2">
    <span{' style="visibility:hidden"' if hover else ''}>№ {serial}</span><span{' style="visibility:hidden"' if hover else ''}>PRIZE TICKET</span></div>
  <div style="position:absolute;left:6px;right:6px;top:28px;bottom:6px;border:2px solid #e2b33c;box-shadow:inset 0 0 0 2px #faecbc"></div>
  <div style="position:absolute;left:-2px;top:16px;width:8px;height:12px;background:#8a1f33;border:2px solid #2b2420;border-left:none"></div>
  <div style="position:absolute;right:-2px;top:16px;width:8px;height:12px;background:#8a1f33;border:2px solid #2b2420;border-right:none"></div>
  {stamp}
  <div style="position:relative;flex:1;display:flex;flex-direction:column;padding:10px 16px 14px 16px">
    <div class="nm">{nm}</div>
    <div class="ty">{ty}</div>
    <div class="ef">{ef}</div>
    {cond.replace('class="co', 'style="border-top:2px dotted #c7beab" class="co')}
    <div class="su" style="margin-top:auto;padding-top:8px"><b>Supports:</b> {su}</div>
  </div>
</div>'''


def kiosk_a(keys, hover_idx=None):
    h = ['<div id="ov">', '<div class="a" style="left:0;top:64px;width:1280px;height:656px;background:rgba(0,0,0,.5);z-index:0"></div>']
    X0, X1 = 196, 1084
    # floor contact shadow (stepped, hard), the plinth and the cabinet body
    h.append(glow(236, 70, 808, 100, step=10, z=0))
    h.append(f'<div class="a" style="left:{X0 - 40}px;top:704px;width:{X1 - X0 + 80}px;height:16px;background:rgba(255,207,63,.08)"></div>')
    h.append(f'<div class="a" style="left:{X0 + 8}px;top:700px;width:{X1 - X0 + 8}px;height:12px;background:rgba(20,10,6,.5)"></div>')
    h.append(f'<div class="a" style="left:{X0 + 4}px;top:690px;width:{X1 - X0 - 8}px;height:18px;background:#2c2926;border:2px solid #2b2420;'
             f'box-shadow:inset 0 2px 0 #3d3a36"></div>')
    # body: velvet face, lit left edge, shaded right edge, ink outline
    h.append(f'<div class="a" style="left:{X0}px;top:164px;width:{X1 - X0}px;height:530px;background:#8a1f33;border:2px solid #2b2420;'
             f'box-shadow:inset 6px 0 0 #b23a55, inset -8px 0 0 #561327, inset 0 -6px 0 #561327"></div>')
    h.append(f'<div class="a" style="left:{X1 - 2}px;top:170px;width:18px;height:520px;background:#2a0e14;border:2px solid #2b2420;'
             f'clip-path:polygon(0 0,100% 2%,100% 99%,0 100%)"></div>')
    # cabinet top face (seen from above: the vanishing point is high), lit
    h.append(f'<div class="a" style="left:{X0 + 4}px;top:156px;width:{X1 - X0 + 10}px;height:10px;background:#b23a55;border:2px solid #2b2420;'
             f'clip-path:polygon(0 100%,2% 0,100% 0,100% 100%)"></div>')
    # button-tufted velvet: diamond quilting with brass buttons (scenery/kiosk_lottery would draw it once)
    tuft = []
    for ty in range(176, 680, 24):
        for tx in range(X0 + 18, X1 - 30, 24):
            tuft.append(f'<rect x="{tx + 10}" y="{ty + 10}" width="4" height="4" fill="#561327"/>'
                        f'<rect x="{tx + 10}" y="{ty + 10}" width="2" height="2" fill="#c8932b"/>')
    h.append(f'<svg class="a" style="left:0;top:0" width="1280" height="720" shape-rendering="crispEdges">'
             f'<defs><pattern id="q" width="24" height="24" patternUnits="userSpaceOnUse" x="{X0 + 18}" y="176">'
             f'<path d="M0 12 L12 0 L24 12 L12 24 Z" fill="none" stroke="#6e2630" stroke-width="2"/></pattern></defs>'
             f'<rect x="{X0 + 18}" y="178" width="{X1 - X0 - 36}" height="502" fill="url(#q)"/>' + "".join(tuft) + '</svg>')
    # brass feet
    for fx in (X0 + 10, X1 - 54):
        h.append(f'<div class="a" style="left:{fx}px;top:694px;width:44px;height:14px;background:#c8932b;border:2px solid #2b2420;'
                 f'box-shadow:inset 2px 2px 0 #ffcf3f, inset -2px -2px 0 #8a5d1a;z-index:2"></div>')
    # brass pinstripe frame on the body
    h.append(f'<div class="a" style="left:{X0 + 16}px;top:176px;width:{X1 - X0 - 32}px;height:506px;border:2px solid #c8932b;'
             f'box-shadow:inset 0 0 0 2px #561327"></div>')
    # marquee crown: brass frame, dark board, chaser bulbs, title
    h.append('<div class="a" style="left:236px;top:70px;width:808px;height:100px;background:#c8932b;border:2px solid #2b2420;'
             'box-shadow:inset 4px 4px 0 #ffcf3f, inset -4px -4px 0 #8a5d1a, 6px 6px 0 rgba(20,10,6,.45)"></div>')
    h.append(rivets(240, 162, 1040, 176))
    h.append('<div class="a" id="board" style="left:250px;top:82px;width:780px;height:76px;background:#2a0e14;border:2px solid #2b2420"></div>')
    h.append(f'<div class="a kk-out" style="left:250px;top:84px;width:780px;text-align:center;font-family:Pixelify;font-size:42px;'
             f'line-height:46px;color:#ffcf3f;letter-spacing:3px">{TITLE_BIG}</div>')
    h.append(f'<div class="a" style="left:250px;top:130px;width:780px;text-align:center;font-family:Pixelify;font-size:19px;color:#faecbc;'
             f'letter-spacing:2px">{TITLE_SMALL}</div>')
    # dispenser mouth: charcoal slot between brass lips; the tickets come out from under the lower lip
    h.append('<div class="a" style="left:232px;top:186px;width:816px;height:22px;background:#24221f;border:2px solid #2b2420;'
             'box-shadow:inset 0 4px 0 #8a5d1a;z-index:5"></div>')
    h.append('<div class="a" style="left:226px;top:204px;width:828px;height:8px;background:#c8932b;border:2px solid #2b2420;'
             'box-shadow:inset 0 2px 0 #ffcf3f;z-index:5"></div>')
    # tickets
    x0 = 640 - (3 * A_TICKET_W + 2 * A_GAP) // 2
    for i, k in enumerate(keys):
        h.append(a_ticket(k, x0 + i * (A_TICKET_W + A_GAP), 206, f"04-{i + 1:03d}", hover=(i == hover_idx)))
    # instruction plate (brass name plate)
    h.append(f'<div class="a" style="left:268px;top:496px;width:744px;height:36px;background:#faecbc;border:2px solid #2b2420;'
             f'box-shadow:inset 0 0 0 2px #c8932b, inset 0 -4px 0 #f1d27a, 4px 4px 0 rgba(20,10,6,.45);display:flex;align-items:center;'
             f'justify-content:center;font-size:16px;font-weight:650;color:#2b2420">{NOTE}</div>')
    # lower panel: RECEIPT IN slot (left), star emblem (centre), ticket-roll window (right)
    h.append('<div class="a" style="left:240px;top:552px;width:800px;height:124px;background:#561327;border:2px solid #2b2420;'
             'box-shadow:0 0 0 4px #c8932b, 0 0 0 6px #2b2420, inset 6px 6px 0 #2a0e14, inset -2px -2px 0 #8a1f33"></div>')
    h.append(rivets(250, 562, 1030, 666))
    h.append('<div class="a" style="left:262px;top:576px;width:236px;height:76px;background:#c8932b;border:2px solid #2b2420;'
             'box-shadow:inset 2px 2px 0 #ffcf3f, inset -2px -2px 0 #8a5d1a"></div>')
    h.append('<div class="a" style="left:276px;top:588px;width:208px;height:14px;background:#24221f;border:2px solid #2b2420"></div>')
    h.append('<div class="a" style="left:262px;top:616px;width:236px;text-align:center;font-family:Pixelify;font-size:16px;color:#2b2420;'
             'letter-spacing:2px">RECEIPT IN <span style="display:inline-block;transform:rotate(-90deg)">›</span></div>')
    h.append(badge(566, 566, 148, 96, "THANK<br>YOU!", 22))
    h.append('<div class="a" style="left:782px;top:576px;width:236px;height:76px;background:#bfe2dd;border:2px solid #2b2420;'
             'box-shadow:inset 0 0 0 4px #c8932b, inset 0 0 0 6px #2b2420;overflow:hidden">'
             '<div class="a" style="left:14px;top:12px;width:208px;height:52px;background:#f3e9d2;border:2px solid #2b2420"></div>'
             + "".join(f'<div class="a" style="left:{16 + i * 52}px;top:14px;width:50px;height:48px;border-right:2px dotted #8a8172">'
                       f'<div class="a" style="left:17px;top:8px;width:14px;height:14px;background:#e2b33c;border:2px solid #2b2420;transform:rotate(45deg)"></div>'
                       f'<div class="a" style="left:8px;top:32px;width:32px;height:2px;background:#b39f78"></div>'
                       f'<div class="a" style="left:12px;top:38px;width:24px;height:2px;background:#b39f78"></div></div>' for i in range(4))
             + '<div class="a" style="left:30px;top:8px;width:8px;height:60px;background:rgba(228,246,243,.7)"></div>'
             '<div class="a" style="left:44px;top:8px;width:4px;height:60px;background:rgba(228,246,243,.7)"></div></div>')
    # chaser bulbs round the marquee: lit gold / dim brass, alternating (one frame of the chase)
    for i, x in enumerate(range(242, 1040, 16)):
        for y in (74, 160):
            on = (i + (y > 100)) % 2 == 0
            h.append(f'<div class="a" style="left:{x}px;top:{y}px;width:8px;height:8px;background:{"#ffcf3f" if on else "#8a5d1a"};'
                     f'border:2px solid #2b2420;{"box-shadow:inset 2px 2px 0 #faecbc" if on else ""}"></div>')
    for j, y in enumerate(range(90, 156, 16)):
        for x in (240, 1032):
            on = j % 2 == 0
            h.append(f'<div class="a" style="left:{x}px;top:{y}px;width:8px;height:8px;background:{"#ffcf3f" if on else "#8a5d1a"};'
                     f'border:2px solid #2b2420;{"box-shadow:inset 2px 2px 0 #faecbc" if on else ""}"></div>')
    if hover_idx is not None:
        tx = x0 + hover_idx * (A_TICKET_W + A_GAP)
        h.append(f'<div class="a" style="left:{tx + 12}px;top:196px;width:196px;height:26px;transform:rotate(-3deg);z-index:9;'
                 f'background:#ffcf3f;border:2px solid #2b2420;box-shadow:inset 0 2px 0 #faecbc, inset 0 -2px 0 #e2b33c, 3px 3px 0 rgba(20,10,6,.45);'
                 f'display:flex;align-items:center;justify-content:center;font-family:Pixelify;font-size:15px;letter-spacing:1px;color:#2b2420">INSTANT WINNER!</div>')
        h.append(f'<div class="a" style="left:{tx + 192}px;top:180px;width:44px;height:36px;transform:rotate(10deg);z-index:10">{star_svg(44, 36, "#ffcf3f", 9)}</div>')
        for sx, sy in ((tx - 14, 236), (tx + A_TICKET_W + 6, 238), (tx + 214, 178)):
            h.append(f'<div class="a kk-spark" style="left:{sx}px;top:{sy}px;z-index:9"></div>')
    h.append('</div>')
    return "\n".join(h)


LOYALTY_HINT_JS = r"""
<script>
// hover: the next empty loyalty box lights up where the picked ticket will go (a gold ring, not colour alone: it is also filled)
{ const c = document.querySelectorAll('.stamp canvas')[1];
  c.getContext('2d').clearRect(0, 0, 13, 13);
  pxDisc(c, { ring: '#ffcf3f', inner: '#faecbc', fill: '#2a4d4b', glyph: PERK[window.HOVER_PERK], ink: '#ffcf3f' });
  c.parentElement.style.boxShadow = '0 0 0 2px #2b2420, 0 0 0 4px #ffcf3f'; c.parentElement.style.borderRadius = '50%'; }
</script>
"""

# ================================================================= DIRECTION B: photo-booth coupon printer by the exit doors
B_HEADER = """<!--
  #56 EXIT KIOSK, DIRECTION B: PHOTO-BOOTH PRIZE PRINTER BY THE EXIT DOORS (decide-round option, 2026-10-19; nothing decided)
  Idea: the camera cuts from the checkout to the store exit: sliding glass doors under a green EXIT sign, the plaster wall, the
  tiled floor, and a teal photo-booth kiosk with a velvet side curtain. Its prize tickets are printed like coupon print-outs and
  hang clipped by brass bulldog clips on a rail across its front. The capsule machines' corner (#63) is reserved at the right
  and only outlined: the booth is a tall closed cabinet with a curtain and a print slot, nothing like a glass-globe coin-op.
  No buttons, no skip.
  Ticket fields, in order: name, TYPE (teal label), effect, condition (or "No condition", italic muted), "Supports: ...".
  The condition moves off tomato: ink-light under a dashed rule. Perk stamp: NOT shown (decision 4 "text only").
  Hover (screens_kiosk_b_hover): the clip springs open and the ticket lifts 6 px in a mustard/gold ring; the cosmetic INSTANT
  WINNER! is a tilted mustard rubber stamp on it; the next empty LOYALTY box lights up on the top bar.
  Receipt in: the RECEIPT IN feed slot on the lower front, left; #66's torn receipt goes in there.
  New art/src sources: scenery/exit_backdrop (doors, EXIT sign, wall, floor; one full-screen backdrop), scenery/kiosk_booth (cabinet,
  sign box, print slot, clip rail, curtain, screen), frames/kiosk_ticket_print (9-slice: dashed cut line), icons/bulldog_clip,
  effects/instant_winner_stamp.
  Timing / behaviour change (label): the backdrop swaps from the checkout to the exit scene when the kiosk shows. As a hard cut under
  the same 0.22 s pop-in, presented_ms / armed_ms keep their meaning; a pan or slide would need a PROTOTYPE_PLAN section 8 row. The deck
  view (Cart) would open over the exit scene; after the pick the camera cuts back to the checkout for the next shift.
  Fit check: the longest triple, Slot engine + Big basket + Category engine; the hover page shows a "No condition" ticket.
  Cost: one extra full-screen backdrop; if art runs long (cut list) the booth can stand over the shaded checkout like A.
-->"""

B_TICKET_W, B_TICKET_H, B_GAP = 240, 290, 16


def b_ticket(key, x, y, hover=False):
    nm, ty, ef, cond, su = fields(key)
    lift = -6 if hover else 0
    ring = ("box-shadow: 0 0 0 4px #e2b33c, 0 0 0 6px #2b2420, 0 0 0 10px #ffcf3f, 0 0 0 12px #2b2420, 6px 14px 0 12px rgba(20,10,6,.45);"
            if hover else "box-shadow: 4px 4px 0 rgba(20,10,6,.45);")
    clip_y = y - 14 + (-16 if hover else 0)
    clip = (f'<div class="a" style="left:{x + B_TICKET_W // 2 - 20}px;top:{clip_y}px;width:40px;height:26px;z-index:7">'
            f'<div class="a" style="left:0;top:8px;width:40px;height:18px;background:#c8932b;border:2px solid #2b2420;'
            f'box-shadow:inset 2px 2px 0 #ffcf3f, inset -2px -2px 0 #8a5d1a"></div>'
            f'<div class="a" style="left:8px;top:0;width:24px;height:12px;border:2px solid #2b2420;border-bottom:none;'
            f'{"transform:rotate(-24deg);transform-origin:0 100%;" if hover else ""}"></div></div>')
    return f'''{clip}<div class="kk-t" style="left:{x}px;top:{y + lift}px;width:{B_TICKET_W}px;height:{B_TICKET_H}px;{ring}z-index:6;
  {'transform:rotate(-1.5deg);' if hover else ''}">
  <div style="position:absolute;left:6px;right:6px;top:6px;bottom:6px;border:2px dashed #b39f78"></div>
  <div style="position:relative;flex:1;display:flex;flex-direction:column;padding:16px 14px 14px 15px">
    <div class="nm">{nm}</div>
    <div><span class="ty" style="display:inline-block;border:2px solid #4f9a94;padding:1px 6px 0 7px;margin-top:6px">{ty}</span></div>
    <div class="ef">{ef}</div>
    {cond.replace('class="co', 'style="border-top:2px dashed #c7beab" class="co')}
    <div class="su" style="margin-top:auto;padding-top:8px"><b>Supports:</b> {su}</div>
  </div>
</div>'''


def kiosk_b(keys, hover_idx=None):
    h = ['<div id="ov">']
    # ---- the exit backdrop (opaque, under the top bar's 2 px ink rule) ----
    h.append('<div class="a" style="left:0;top:58px;width:1280px;height:470px;background:#e4d6b9"></div>')
    h.append('<div class="a" style="left:0;top:58px;width:1280px;height:16px;background:#cdbb98;border-bottom:2px solid #b9a47c"></div>')
    # wainscot band
    h.append('<div class="a" style="left:0;top:452px;width:1280px;height:76px;background:#2a4d4b;border-top:4px solid #3a7672;'
             'border-bottom:2px solid #2b2420;box-shadow:inset 0 4px 0 #1f3b3a"></div>')
    # floor: cream tiles in rows that foreshorten toward the camera (lines converge on the vanishing point 640,-1600)
    h.append('<div class="a" style="left:0;top:528px;width:1280px;height:192px;background:#ece0c6"></div>')
    lines = []
    for y in (548, 574, 606, 646, 694):
        lines.append(f'<line x1="0" y1="{y}" x2="1280" y2="{y}" stroke="#cdbb98" stroke-width="2"/>')
    for x in range(-640, 1921, 96):
        # from y 528 to 720 along the ray to the vanishing point
        xb = 640 + (x - 640) * (720 + 1600) / (528 + 1600)
        lines.append(f'<line x1="{x}" y1="528" x2="{xb:.0f}" y2="720" stroke="#cdbb98" stroke-width="2"/>')
    h.append('<svg class="a" style="left:0;top:0" width="1280" height="720" shape-rendering="crispEdges">' + "".join(lines) + '</svg>')
    # sliding exit doors (left): steel frame, two glass panes with glints, rubber mat
    h.append('<div class="a" style="left:22px;top:136px;width:178px;height:392px;background:#8d8a83;border:2px solid #2b2420;'
             'box-shadow:inset 4px 4px 0 #c7c3b8, inset -4px 0 0 #57534c"></div>')
    for px in (32, 112):
        h.append(f'<div class="a" style="left:{px}px;top:148px;width:78px;height:372px;background:#bfe2dd;border:2px solid #2b2420;overflow:hidden">'
                 f'<div class="a" style="left:12px;top:-20px;width:10px;height:420px;background:#e4f6f3;transform:skewX(-14deg)"></div>'
                 f'<div class="a" style="left:30px;top:-20px;width:4px;height:420px;background:#e4f6f3;transform:skewX(-14deg)"></div>'
                 f'<div class="a" style="left:0;top:300px;width:78px;height:72px;background:#86c2b6"></div></div>')
    h.append('<div class="a" style="left:108px;top:148px;width:6px;height:372px;background:#57534c"></div>')
    h.append('<div class="a" style="left:6px;top:530px;width:212px;height:40px;background:#3d3a36;border:2px solid #2b2420;'
             'clip-path:polygon(4% 0,96% 0,100% 100%,0 100%)"></div>')
    # EXIT sign (green box, label + arrow, so colour is not the only signal)
    h.append('<div class="a" style="left:56px;top:92px;width:112px;height:36px;background:#3d7a45;border:2px solid #2b2420;'
             'box-shadow:inset 0 3px 0 #5fae5a, 4px 4px 0 rgba(20,10,6,.35);display:flex;align-items:center;justify-content:center;'
             'font-family:Pixelify;font-size:22px;color:#fbf7ee;letter-spacing:2px">EXIT ›</div>')
    # ceiling lamps
    for lx in (300, 620, 940):
        h.append(f'<img class="a kk-pix" src="screens_src/assets/ceiling_lamp.png" style="left:{lx}px;top:58px;width:74px;height:20px;z-index:0">')
        for i, a in enumerate((.16, .11, .07)):
            w0, w1 = 120 + i * 60, 300 + i * 120
            h.append(f'<div class="a" style="left:{lx - w1 // 2 + 37}px;top:78px;width:{w1}px;height:642px;background:rgba(255,236,188,{a});'
                     f'clip-path:polygon({(w1 - w0) // 2}px 0,{(w1 + w0) // 2}px 0,100% 100%,0 100%);z-index:0"></div>')
    # wall clock over the capsule corner (reuses the game's wall_clock sprite)
    h.append('<img class="a kk-pix" src="screens_src/assets/wall_clock.png" style="left:1144px;top:150px;width:88px;height:88px;z-index:2">')
    # skirting board between the wainscot and the floor
    h.append('<div class="a" style="left:0;top:520px;width:1280px;height:8px;background:#6e4524;border-bottom:2px solid #2b2420;box-shadow:inset 0 2px 0 #a8703a"></div>')
    # capsule machines' corner (#63), reserved and outlined only
    h.append('<div class="a" style="left:1112px;top:292px;width:152px;height:290px;border:2px dashed #8a8172;background:rgba(205,187,152,.35)"></div>')
    h.append('<div class="a" style="left:1112px;top:420px;width:152px;text-align:center;font-size:13px;font-weight:650;color:#5e574d;line-height:16px">'
             'capsule machines<br>(#63)</div>')
    # ---- the booth ----
    BX0, BX1 = 228, 1012
    h.append(f'<div class="a" style="left:{BX0 + 8}px;top:690px;width:{BX1 - BX0 + 96}px;height:14px;background:rgba(20,10,6,.35)"></div>')
    # curtain alcove on the right: side frame, rod, velvet folds
    h.append(f'<div class="a" style="left:{BX1 - 4}px;top:150px;width:96px;height:548px;background:#1f3b3a;border:2px solid #2b2420"></div>')
    h.append(f'<div class="a" style="left:{BX1}px;top:160px;width:88px;height:6px;background:#c8932b;border:2px solid #2b2420"></div>')
    folds = "".join(f'<div class="a" style="left:{i * 16}px;top:0;width:16px;height:100%;background:linear-gradient(90deg,'
                    f'#b23a55 0 4px,#8a1f33 4px 12px,#561327 12px 16px)"></div>' for i in range(5))
    h.append(f'<div class="a" style="left:{BX1 + 4}px;top:168px;width:80px;height:520px;overflow:hidden;border-left:2px solid #2b2420">{folds}</div>')
    # booth top: sign box, cap
    h.append(f'<div class="a" style="left:{BX0 - 6}px;top:140px;width:{BX1 - BX0 + 104}px;height:10px;background:#4f9a94;border:2px solid #2b2420;'
             f'clip-path:polygon(1% 0,99% 0,100% 100%,0 100%)"></div>')
    h.append(f'<div class="a" style="left:{BX0 - 6}px;top:148px;width:{BX1 - BX0 + 104}px;height:14px;background:#2a4d4b;border:2px solid #2b2420;'
             f'box-shadow:inset 0 2px 0 #3a7672, 0 4px 0 rgba(20,10,6,.35)"></div>')
    h.append(f'<div class="a" style="left:{BX0 + 20}px;top:72px;width:{BX1 - BX0 - 40}px;height:76px;background:#fbf7ee;border:2px solid #2b2420;'
             f'box-shadow:inset 0 0 0 4px #4f9a94, inset 0 0 0 6px #2b2420, inset 0 -10px 0 #ddcba5, 4px 4px 0 rgba(20,10,6,.35)"></div>')
    h.append(f'<div class="a" style="left:{BX0 + 20}px;top:74px;width:{BX1 - BX0 - 40}px;text-align:center;font-family:Pixelify;font-size:36px;'
             f'line-height:40px;color:#1f3b3a;letter-spacing:3px">{TITLE_BIG}</div>')
    h.append(f'<div class="a" style="left:{BX0 + 20}px;top:112px;width:{BX1 - BX0 - 40}px;text-align:center;font-family:Pixelify;font-size:17px;'
             f'color:#3a7672;letter-spacing:2px">{TITLE_SMALL}</div>')
    # booth front: teal face, lit left, shaded right
    h.append(f'<div class="a" style="left:{BX0}px;top:158px;width:{BX1 - BX0}px;height:536px;background:#3a7672;border:2px solid #2b2420;'
             f'box-shadow:inset 6px 0 0 #4f9a94, inset -8px 0 0 #2a4d4b, inset 0 -8px 0 #2a4d4b"></div>')
    # panel seams and rivets on the booth front (scenery/kiosk_booth)
    for sx in (BX0 + 14, BX1 - 16):
        h.append(f'<div class="a" style="left:{sx}px;top:162px;width:2px;height:520px;background:#2a4d4b"></div>')
    h.append(rivets(BX0 + 4, 166, BX1 - 4, 680, col="#c7c3b8"))
    # sign end caps: gold stars, so the sign reads as a prize booth and not a store notice
    h.append(f'<div class="a" style="left:{BX0 + 30}px;top:84px;width:52px;height:52px;z-index:3">{star_svg(52, 52, "#ffcf3f", 8, .5)}</div>')
    h.append(f'<div class="a" style="left:{BX1 - 82}px;top:84px;width:52px;height:52px;z-index:3">{star_svg(52, 52, "#ffcf3f", 8, .5)}</div>')
    # print slot with brass lips
    h.append(f'<div class="a" style="left:{BX0 + 24}px;top:170px;width:{BX1 - BX0 - 48}px;height:18px;background:#24221f;border:2px solid #2b2420;'
             f'box-shadow:inset 0 4px 0 #8a5d1a"></div>')
    # clip rail
    h.append(f'<div class="a" style="left:{BX0 + 12}px;top:196px;width:{BX1 - BX0 - 24}px;height:10px;background:#c8932b;border:2px solid #2b2420;'
             f'box-shadow:inset 0 2px 0 #ffcf3f, inset 0 -2px 0 #8a5d1a;z-index:5"></div>')
    for rx in (BX0 + 16, BX1 - 26):
        h.append(f'<div class="a" style="left:{rx}px;top:192px;width:10px;height:18px;background:#8a5d1a;border:2px solid #2b2420;z-index:5"></div>')
    cx = (BX0 + BX1) // 2
    x0 = cx - (3 * B_TICKET_W + 2 * B_GAP) // 2
    for i, k in enumerate(keys):
        h.append(b_ticket(k, x0 + i * (B_TICKET_W + B_GAP), 210, hover=(i == hover_idx)))
    # the kiosk screen: the instruction note, in mustard pale on slate
    h.append(f'<div class="a" style="left:{BX0 + 30}px;top:528px;width:{BX1 - BX0 - 60}px;height:40px;background:#222a29;border:2px solid #2b2420;'
             f'box-shadow:inset 0 0 0 4px #57534c, inset 0 0 0 6px #2b2420;display:flex;align-items:center;justify-content:center;'
             f'font-size:16px;font-weight:650;color:#faecbc">{NOTE}</div>')
    # lower front: RECEIPT IN feed slot (left), speaker grille (right)
    h.append(f'<div class="a" style="left:{BX0 + 30}px;top:590px;width:240px;height:80px;background:#ecebe4;border:2px solid #2b2420;'
             f'box-shadow:inset 2px 2px 0 #fbf7ee, inset -4px -4px 0 #a9a59b"></div>')
    h.append(f'<div class="a" style="left:{BX0 + 46}px;top:602px;width:208px;height:14px;background:#24221f;border:2px solid #2b2420;'
             f'box-shadow:inset 0 4px 0 #45423d"></div>')
    h.append(f'<div class="a" style="left:{BX0 + 30}px;top:628px;width:240px;text-align:center;font-family:Pixelify;font-size:16px;'
             f'color:#2b2420;letter-spacing:2px">RECEIPT IN <span style="display:inline-block;transform:rotate(-90deg)">›</span></div>')
    grille = "".join(f'<div class="a" style="left:{12 + i * 14}px;top:14px;width:6px;height:48px;background:#1f3b3a"></div>' for i in range(14))
    h.append(f'<div class="a" style="left:{BX1 - 250}px;top:590px;width:220px;height:80px;background:#2a4d4b;border:2px solid #2b2420;'
             f'box-shadow:inset 2px 2px 0 #1f3b3a">{grille}</div>')
    h.append(badge(BX0 + 318, 588, 148, 88, "THANK<br>YOU!", 20))
    tread = "".join(f'<div class="a" style="left:{8 + i * 16}px;top:6px;width:8px;height:4px;background:#6f6b63"></div>' for i in range((BX1 - BX0) // 16))
    h.append(f'<div class="a" style="left:{BX0 - 2}px;top:684px;width:{BX1 - BX0 + 4}px;height:20px;background:#a9a59b;border:2px solid #2b2420;'
             f'box-shadow:inset 0 2px 0 #c7c3b8">{tread}</div>')
    if hover_idx is not None:
        tx = x0 + hover_idx * (B_TICKET_W + B_GAP)
        h.append(f'<div class="a" style="left:{tx + 46}px;top:414px;width:170px;height:32px;transform:rotate(-7deg);z-index:9;'
                 f'border:4px solid #b38425;box-shadow:inset 0 0 0 2px #fbf7ee, inset 0 0 0 4px #b38425;display:flex;'
                 f'align-items:center;justify-content:center;font-family:Pixelify;font-size:17px;line-height:18px;color:#b38425;'
                 f'background:rgba(250,236,188,.55)">INSTANT WINNER!</div>')
        for sx, sy in ((tx - 20, 250), (tx + B_TICKET_W + 10, 300), (tx + 40, 188)):
            h.append(f'<div class="a kk-spark" style="left:{sx}px;top:{sy}px;z-index:9"></div>')
    h.append('</div>')
    return "\n".join(h)


LONG = ["slot", "big", "cat"]
NOCOND = ["redraw", "slot", "big"]
pages = {
    "screens_kiosk_a.html": page("Exit kiosk A", A_HEADER, kiosk_a(LONG)),
    "screens_kiosk_a_hover.html": page("Exit kiosk A hover", A_HEADER, kiosk_a(NOCOND, hover_idx=1),
                                       "<script>window.HOVER_PERK='slot';</script>" + LOYALTY_HINT_JS),
    "screens_kiosk_b.html": page("Exit kiosk B", B_HEADER, kiosk_b(LONG)),
    "screens_kiosk_b_hover.html": page("Exit kiosk B hover", B_HEADER, kiosk_b(NOCOND, hover_idx=1),
                                       "<script>window.HOVER_PERK='slot';</script>" + LOYALTY_HINT_JS),
}
for name, html in pages.items():
    (MOCKUPS / name).write_text(html, encoding="utf-8")
    print("wrote", name)
