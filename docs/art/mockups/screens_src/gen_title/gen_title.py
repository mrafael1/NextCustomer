"""Writes the #56 title-screen mock-ups (decide prep, 2026-10-19).

Run from the repo root:  python docs/art/mockups/screens_src/gen_title/gen_title.py
Then capture each page:  sh docs/art/mockups/screens_src/gen_title/cap_all.sh

Pages (authored at 1280x720 CSS px, captured at 1.5x = 1920x1080):
  docs/art/mockups/screens_title_a.html          A, with a save (Continue / New run)
  docs/art/mockups/screens_title_a_nosave.html   A, without a save (Click anywhere to start)
  docs/art/mockups/screens_title_a_confirm.html  A, with a save, abandon confirmation open
  docs/art/mockups/screens_title_b*.html         the same three states for B

A = the store front at night, the logo as a lit rooftop sign, the cashier waiting at her register
    through the open doors; a lit spot by the exit is reserved for the capsule machines (#63).
B = a plain teal backdrop and one giant receipt: the logo is printed as the receipt header, the
    coin line is a gold sticker slapped on it, the loyalty card is stapled to the corner. The cheap
    option for the cut list ("simplify the title backdrop").
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # docs/art/mockups
ASSETS = "screens_src/assets/"

# Real strings (ui/title_screen.gd; 8 = balance.quotas.size(); build label from project.godot).
TITLE = "NEXT CUSTOMER"
SUBTITLE = "Scan groceries and coupons in the best order. Meet the quota on all 8 shifts."
COINS = "Coins: 5"
PROMPT = "Click anywhere to start"
CONTINUE = "Continue (shift 3 / 8)"
NEW_RUN = "New run"
EXPORT = "Export log"
BUILD = "fb-p2"
QUESTION = "Abandon the run in progress? It won't count."
YES = "Yes, start a new run"
NO = "No, keep it"
RESERVE = "Room for the capsule machines (#63)"

COMMON_CSS = """
@font-face { font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }
@font-face { font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }
@font-face { font-family: JBMono; src: url(../../../fonts/JetBrainsMono-Regular.ttf); }
:root {
  --ink: #2b2420; --ink-light: #4a3f38; --muted: #8a8172; --paper: #fbf7ee; --cream: #f3e9d2; --cream-shade: #ddcba5;
  --cream-dark: #b39f78; --mustard: #e2b33c; --mustard-light: #f1d27a; --mustard-pale: #faecbc; --gold: #ffcf3f;
  --tomato: #d9534f; --tomato-dark: #a83a3c; --teal: #4f9a94; --teal-panel: #2a4d4b; --teal-dark: #1f3b3a; --teal-black: #172c2b;
  --steel: #8d8a83; --steel-light: #c7c3b8; --steel-dark: #57534c;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 1280px; height: 720px; overflow: hidden; background: var(--teal-black); }
img, canvas { image-rendering: pixelated; }
.stage { position: relative; width: 1280px; height: 720px; overflow: hidden; font-family: Atkinson, sans-serif; color: var(--ink); }
.abs { position: absolute; }
/* light display text: the 6 px ink outline of UiKit.display_label, as a stepped 3 px ring */
.ol { text-shadow: 3px 0 0 var(--ink), -3px 0 0 var(--ink), 0 3px 0 var(--ink), 0 -3px 0 var(--ink),
  2px 2px 0 var(--ink), -2px 2px 0 var(--ink), 2px -2px 0 var(--ink), -2px -2px 0 var(--ink), 3px 2px 0 var(--ink),
  -3px 2px 0 var(--ink), 3px -2px 0 var(--ink), -3px -2px 0 var(--ink), 2px 3px 0 var(--ink), -2px 3px 0 var(--ink),
  2px -3px 0 var(--ink), -2px -3px 0 var(--ink); }
/* FramedButton: the real 9-slice faces (art/frames/button.png and sign.png, 3 art px margins = 6 canvas px) */
.fbtn { position: absolute; display: flex; align-items: center; justify-content: center; padding: 0 24px 4px;
  font-family: Pixelify; color: var(--paper); white-space: nowrap; image-rendering: pixelated; }
.fbtn.primary { border: 6px solid transparent; border-image: url(ASSETSbutton.png) 6 fill / 6px stretch; }
.fbtn.secondary { border: 6px solid transparent; border-image: url(ASSETSsign.png) 6 fill / 6px stretch; padding-bottom: 2px; }
.fbtn.hover { filter: brightness(1.12); }
/* mock-up annotation only (not game art): where #63's entry would go */
.reserve { position: absolute; border: 2px dashed var(--mustard-pale); display: flex; align-items: flex-start; justify-content: center;
  padding-top: 10px; font: 600 14px Atkinson; color: var(--mustard-pale); background: rgba(250,236,188,.06); }
.reserve span { background: rgba(23,44,43,.85); padding: 2px 8px; }
.reserve.low { align-items: flex-end; padding: 0 0 10px; }
.coin { width: 24px; height: 24px; display: block; flex: none; }
.build { position: absolute; right: 20px; bottom: 16px; font: 600 14px Atkinson; color: var(--cream);
  text-shadow: 2px 0 0 var(--ink), -2px 0 0 var(--ink), 0 2px 0 var(--ink), 0 -2px 0 var(--ink); }
/* the abandon confirmation: ScreenShade-style black 0.5 over everything, then the panel */
.shade { position: absolute; inset: 0; background: rgba(0,0,0,.5); }
.ask { position: absolute; display: flex; flex-direction: column; align-items: center; gap: 22px; }
.ask .q { display: flex; align-items: center; gap: 14px; font: 750 26px Atkinson; color: var(--tomato); white-space: nowrap; }
.ask .q img { width: 39px; height: 33px; }
.ask .row { display: flex; gap: 16px; }
.ask .row .fbtn { position: relative; height: 56px; font-size: 22px; }
""".replace("ASSETS", ASSETS)


def button(cls: str, text: str, x: int, y: int, w: int, h: int, size: int, extra: str = "") -> str:
    return (f'<div class="fbtn {cls} ol" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;'
            f'font-size:{size}px;{extra}">{text}</div>')


def page(title: str, header: str, css: str, body: str, script: str = "") -> str:
    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>{title}</title>
<!--
{header}
-->
<style>
{COMMON_CSS}
{css}
</style>
</head>
<body>
<div class="stage">
{body}
</div>
<script>
{script}
</script>
</body>
</html>
"""


# ------------------------------------------------------------------ A: the store front at night
A_HEADER = """  #56 TITLE, OPTION A: THE STORE FRONT AT NIGHT (decide prep, 2026-10-19). Nothing is decided.
  Idea: the title is a full scene of its own. The supermarket's front at night, seen straight on from the pavement with the
  shift screen's camera rule (one vanishing point at (640, -1600): only the paving joints recede). The logo is a lit rooftop
  sign (brass frame, gold marquee bulbs); under the teal-and-cream awning the windows glow warm with the store's 0.5x shelf
  sprites, and through the open sliding doors the cashier waits at her register: the next customer is you. Light spills
  onto the pavement in hard stepped bands. A lit spot in front of the right-hand window, by the exit, is RESERVED for the
  capsule machines' entry (#63 decides it; the dashed box is a mock-up note, not art).
  UI: the subtitle and the coin line are a paper notice taped inside the left window; Continue / New run (or the pulsing
  "Click anywhere to start") stand on the pavement in front of the doors; Export log and the build label in the corners.
  New art/src/ sources: scenery/store_front (facade, cornice, windows, doors, awning, pavement as one backdrop or a few
  tiles), scenery/rooftop_sign (9-slice brass frame + bulb strip; the logo itself as a sprite: logo_title), frames/notice
  (taped paper, a 9-slice), frames/paper_panel (the confirmation panel; shared with #56's other panels). Reused: cashier,
  ceiling_lamp, yoghurt_pots, juice_bottles, bread_tin, wicker_basket, baguette_bin, button.png, sign.png, warning.png.
  Timing: none of #56's offer timings are touched (the title has none). Optional juice, not in the capture: the bulbs chase
  and the doors breathe. Reduced motion: still.
  Fit check: the longest strings here are "Continue (shift 3 / 8)" (26 px), the subtitle (20 px, 3 lines in the notice), and
  "Abandon the run in progress? It won't count." (26 px) beside the warning triangle.
  Art-direction pass (2026-10-19): shelves stocked with the real items_v2 sprites; the cashier at the game's 2x behind a
  full-height counter (window stock stays a 0.5x interior layer: in art/src it becomes one store_front_interior sprite at
  that scale); warm stepped light on the pavement; sign glow and chasing bulbs; logo at weight 600 so the C stays open;
  the #63 reserve moved below the stock with its label at the bottom; the confirmation taped like the notice."""

A_CSS = """
#scene { position: absolute; left: 0; top: 0; width: 1280px; height: 720px; }
.logo { position: absolute; left: 300px; top: 18px; width: 680px; height: 104px; display: flex; align-items: center; justify-content: center;
  font-family: Pixelify; font-weight: 600; font-size: 74px; letter-spacing: 4px; }
.logo .ink { position: absolute; color: var(--ink);
  text-shadow: 4px 0 0 var(--ink), -4px 0 0 var(--ink), 0 4px 0 var(--ink), 0 -4px 0 var(--ink), 4px 4px 0 var(--ink), -4px 4px 0 var(--ink),
  4px -4px 0 var(--ink), -4px -4px 0 var(--ink), 0 8px 0 #4a3010, 4px 8px 0 #4a3010, -4px 8px 0 #4a3010; }
/* two flat bands, not a gradient: gold top, mustard bottom (a sprite in the game: logo_title) */
.logo .face { position: relative; color: transparent; background: linear-gradient(var(--gold) 0 54%, var(--mustard) 54% 100%);
  -webkit-background-clip: text; background-clip: text; }
.notice { position: absolute; left: 84px; top: 302px; width: 344px; padding: 16px 20px 14px; background: var(--paper);
  border: 2px solid var(--ink); box-shadow: inset -4px -4px 0 var(--cream-shade), 6px 6px 0 rgba(23,44,43,.55); transform: rotate(-1.5deg); }
.notice p { font: 600 20px/27px Atkinson; color: var(--ink); }
.notice .rule { border-top: 2px dashed var(--cream-dark); margin: 10px 0 8px; }
.notice .coins { display: flex; align-items: center; gap: 10px; font: 750 22px Atkinson; color: var(--ink); }
.tape { position: absolute; width: 44px; height: 16px; background: rgba(250,236,188,.85); border: 2px solid rgba(43,36,32,.25); }
.prompt { position: absolute; left: 0; width: 1280px; top: 606px; text-align: center; font: 30px Pixelify; color: var(--cream); }
.ask { left: 290px; top: 262px; width: 700px; padding: 30px 32px 30px; background: var(--paper); border: 2px solid var(--ink);
  box-shadow: inset -4px -4px 0 var(--cream-shade), 8px 8px 0 rgba(0,0,0,.45); }
"""

A_SCENE_JS = r"""
// The backdrop, drawn on the 2 px art grid (1 art px = 2 canvas px); sprites from the game at their own size (0.5x layer).
const cv = document.getElementById('scene'), g = cv.getContext('2d');
g.imageSmoothingEnabled = false;
const r = (x, y, w, h, c) => { g.fillStyle = c; g.fillRect(x * 2, y * 2, w * 2, h * 2); };
let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const P = { ink: '#2b2420', tealBlack: '#172c2b', tealDark: '#1f3b3a', tealPanel: '#2a4d4b', teal3: '#3a7672', teal: '#4f9a94',
  tealLight: '#86c2b6', glass: '#e4f6f3', glass2: '#bfe2dd', slate: '#2c3533', slate2: '#222a29', s1: '#ecebe4', s2: '#c7c3b8',
  s3: '#a9a59b', s4: '#8d8a83', s5: '#6f6b63', s6: '#57534c', s7: '#45423d', rub: '#3d3a36', rub2: '#2c2926', char: '#24221f',
  cream: '#f3e9d2', creamShade: '#ddcba5', paper: '#fbf7ee', pl1: '#ece0c6', pl2: '#e4d6b9', pl3: '#cdbb98', pl4: '#b9a47c',
  w1: '#ddb07a', w2: '#c98c4e', w3: '#a8703a', w4: '#6e4524', w5: '#3e2614', b1: '#4a3010', b2: '#8a5d1a', b3: '#c8932b',
  gold: '#ffcf3f', mPale: '#faecbc', mLight: '#f1d27a', must: '#e2b33c', br1: '#4a3022', br2: '#7a5232' };

// sky with two flat bands and stars
r(0, 0, 640, 360, P.tealBlack); r(0, 44, 640, 30, P.slate2);
for (let i = 0; i < 70; i++) { const x = Math.floor(rnd() * 640), y = Math.floor(rnd() * 66); r(x, y, 1, 1, rnd() < .3 ? P.glass : P.tealLight); }
// moon, upper right: a stepped disc with a bite
for (let y = -7; y <= 7; y++) for (let x = -7; x <= 7; x++) if (x * x + y * y <= 49 && (x + 4) * (x + 4) + (y - 2) * (y - 2) > 30) r(588 + x, 22 + y, 1, 1, P.cream);
// neighbouring buildings, dark silhouettes left and right
r(0, 52, 26, 230, P.slate2); r(614, 40, 26, 242, P.slate2);
for (let y = 60; y < 260; y += 18) { r(6, y, 8, 10, P.tealDark); r(624, y - 4, 8, 10, P.tealDark); }

// facade: slate bricks
const FX = 20, FW = 600, FT = 72, FB = 272;
r(FX, FT, FW, FB - FT, P.slate);
for (let y = FT + 8, row = 0; y < FB; y += 6, row++) { r(FX, y, FW, 1, P.slate2); for (let x = FX + (row % 2) * 7; x < FX + FW; x += 14) r(x, y - 5, 1, 5, P.slate2); }
// cornice: steel ledge, lit top, ink under
r(FX - 4, FT - 6, FW + 8, 6, P.s5); r(FX - 4, FT - 6, FW + 8, 1, P.s3); r(FX - 4, FT - 7, FW + 8, 1, P.ink); r(FX - 4, FT, FW + 8, 1, P.ink); r(FX - 2, FT + 1, FW + 4, 2, P.slate2);

// rooftop sign: struts, then a brass-framed box with gold bulbs
for (const sx of [190, 300, 340, 450]) { r(sx, 58, 4, 10, P.s7); r(sx, 58, 1, 10, P.s5); }
const SX = 146, SY = 4, SW = 348, SH = 58;
r(SX - 12, 0, SW + 24, FT - 7, P.tealDark); r(SX - 6, 0, SW + 12, SH + 5, P.tealPanel);   // stepped glow on the sky, stops at the cornice
r(SX - 1, SY - 1, SW + 2, SH + 2, P.ink); r(SX, SY, SW, SH, P.b2); r(SX, SY, SW, 2, P.b3); r(SX, SY, 2, SH, P.b3); r(SX, SY + SH - 2, SW, 2, P.b1); r(SX + SW - 2, SY, 2, SH, P.b1);
r(SX + 6, SY + 6, SW - 12, SH - 12, P.ink); r(SX + 7, SY + 7, SW - 14, SH - 14, P.tealDark); r(SX + 7, SY + 7, SW - 14, 2, P.tealPanel);
let bulb = 0;   // chase: every third bulb is between flashes (b3), the lit ones get a 1 art px mustard halo
const lamp = (x, y) => { if (bulb++ % 3 === 2) { r(x, y, 2, 2, P.b3); return; } r(x - 1, y, 4, 2, P.must); r(x, y - 1, 2, 4, P.must); r(x, y, 2, 2, P.gold); r(x, y, 1, 1, P.mPale); };
for (let x = SX + 6; x < SX + SW - 4; x += 10) for (const y of [SY + 2, SY + SH - 4]) lamp(x, y);
for (let y = SY + 12; y < SY + SH - 8; y += 10) for (const x of [SX + 2, SX + SW - 4]) lamp(x, y);
// glow of the sign on the cornice: one flat lighter band
r(SX + 10, FT - 6, SW - 20, 1, P.mPale); r(SX + 30, FT - 5, SW - 60, 1, P.s2);

// awning: teal and cream stripes, a lit top band, scalloped edge
const AY = 80, AH = 16;
r(FX + 2, AY - 1, FW - 4, AH + 2, P.ink);
for (let x = FX + 3, i = 0; x < FX + FW - 3; x += 15, i++) {
  const w = Math.min(15, FX + FW - 3 - x), c = i % 2 ? P.cream : P.teal, d = i % 2 ? P.creamShade : P.teal3;
  r(x, AY, w, AH, c); r(x, AY, w, 3, i % 2 ? P.paper : P.tealLight); r(x, AY + AH - 3, w, 3, d);
  // scallop: a stepped half-disc under each stripe
  r(x + 1, AY + AH, w - 2, 2, c); r(x + 3, AY + AH + 2, w - 6, 2, d); r(x + 1, AY + AH + 2, 2, 1, P.ink); r(x + w - 3, AY + AH + 2, 2, 1, P.ink);
  r(x + 3, AY + AH + 4, w - 6, 1, P.ink);
}
r(FX + 4, AY + AH + 5, FW - 8, 3, P.slate2);   // awning shadow on the wall

// windows (warm interior with 0.5x shelves) and the door opening
const WY = 108, WB = 250;
function interior(x, w) {
  r(x, WY, w, WB - WY, P.pl1); r(x, WY + 86, w, WB - WY - 86, P.pl2); r(x, WY + 85, w, 1, P.pl3);
  for (const sy of [148, 186, 224]) { r(x, sy, w, 3, P.w2); r(x, sy, w, 1, P.w1); r(x, sy + 3, w, 2, P.w4); }
}
interior(24, 208); interior(408, 208); interior(250, 140);
// door interior: a checker floor receding, the register counter, the cashier behind it
for (let y = 226, k = 0; y < 272; y += 6, k++) for (let x = 250, j = 0; x < 390; x += 10, j++) r(x, y, 10, 6, (j + k) % 2 ? P.pl2 : P.pl4);
r(250, 108, 140, 4, P.pl3);
const shelvesImg = [];
function sprite(src, x, y, w, h, flip) { shelvesImg.push({ src, x, y, w, h, flip }); }
// glass and frames are drawn after the sprites load (see below)
function glassAndFrames() {
  // haze over everything behind glass (a modulate in Godot)
  g.fillStyle = 'rgba(79,154,148,.14)'; g.fillRect(24 * 2, WY * 2, 208 * 2, (WB - WY) * 2); g.fillRect(408 * 2, WY * 2, 208 * 2, (WB - WY) * 2);
  // reflections: stepped diagonal bands of glass
  g.fillStyle = 'rgba(228,246,243,.16)';
  for (const [x0, w0] of [[40, 14], [70, 6], [430, 14], [460, 6], [520, 10]]) for (let y = WY; y < WB; y += 2) g.fillRect((x0 + (WB - y) * .5) * 2, y * 2, w0 * 2, 4);
  // window frames: steel, lit top-left, shaded bottom-right, ink outline; a mullion each
  for (const x of [24, 408]) {
    r(x - 5, WY - 5, 218, 4, P.ink); r(x - 5, WB + 1, 218, 8, P.ink);
    r(x - 4, WY - 4, 216, 4, P.s3); r(x - 4, WY - 4, 4, WB - WY + 8, P.s3); r(x + 208, WY - 4, 4, WB - WY + 8, P.s6); r(x - 4, WB, 216, 4, P.s6);
    r(x - 5, WY - 5, 1, WB - WY + 14, P.ink); r(x + 212, WY - 5, 1, WB - WY + 14, P.ink);
    r(x + 102, WY, 4, WB - WY, P.s4); r(x + 102, WY, 1, WB - WY, P.s2); r(x + 105, WY, 1, WB - WY, P.s6);
    r(x - 6, WB + 4, 220, 4, P.s4); r(x - 6, WB + 4, 220, 1, P.s2); r(x - 6, WB + 8, 220, 1, P.ink);   // sill
  }
  // kick plate under the windows
  r(20, 258, 214, 14, P.char); r(406, 258, 214, 14, P.char);
  // door surround and two sliding glass leaves, parted
  r(244, WY - 6, 152, 6, P.ink); r(245, WY - 5, 150, 4, P.s3);
  r(244, WY - 6, 5, 166, P.ink); r(245, WY - 5, 3, 165, P.s3); r(391, WY - 6, 5, 166, P.ink); r(392, WY - 5, 3, 165, P.s6);
  for (const [lx, hx] of [[250, 300], [346, 350]]) {
    g.fillStyle = 'rgba(191,226,221,.22)'; g.fillRect(lx * 2, WY * 2, 44 * 2, 164 * 2);
    r(lx, WY, 44, 2, P.s4); r(lx, WY + 162, 44, 2, P.s5); r(lx, WY, 2, 164, P.s4); r(lx + 42, WY, 2, 164, P.s5);
    r(hx === 300 ? lx + 36 : lx + 4, WY + 64, 2, 40, P.s2);   // handles
  }
  // the lit cart sign over the door
  r(298, 98, 44, 11, P.ink); r(299, 99, 42, 9, P.teal); r(299, 99, 42, 2, P.tealLight); r(299, 106, 42, 2, P.teal3);
}

// pavement: rubber slabs, joints receding to (320, -800) art px, light spill as flat stepped bands, a curb, the road
r(0, 272, 640, 88, P.s7);
r(0, 272, 640, 1, P.ink);
const spill = [[24, 208], [250, 140], [408, 208]];
const steps = [[0, 6, '#8a8172'], [6, 12, P.s5], [18, 18, P.s6]];
for (const [x, w] of spill) for (const [dy, h, c] of steps) r(x - 4 - dy, 273 + dy, w + 8 + dy * 2, h, c);
r(246, 273, 148, 4, P.pl4); r(250, 277, 140, 4, '#8a8172');   // the open doors throw the brightest light
r(262, 273, 116, 7, P.br1); r(262, 273, 116, 1, P.br2); r(262, 279, 116, 1, P.ink);   // doormat
for (let y = 290; y < 344; y += 18) r(0, y, 640, 1, P.rub);
for (let xt = -40; xt <= 680; xt += 48) { for (let y = 273; y < 344; y++) { const k = (y + 800) / (273 + 800); r(Math.round(320 + (xt - 320) * k), y, 1, 1, P.rub); } }
r(0, 344, 640, 6, P.s4); r(0, 344, 640, 1, P.s3); r(0, 350, 640, 1, P.ink); r(0, 351, 640, 9, P.char);
// reserved exit spot: a wall sconce and its light pool (the machines would stand here)
r(488, 302, 132, 4, '#8a8172'); r(484, 306, 140, 10, P.s5); r(480, 316, 148, 14, P.s6);   // its light pool, kept free

const I = 'IT:';   // items_v2 sprites (48x48), the rest are scenery props
const imgs = [
  ['ceiling_lamp', 64, 216], ['ceiling_lamp', 314, 216], ['ceiling_lamp', 832, 216], ['ceiling_lamp', 1058, 216],
  // left window, top shelf (the notice covers the rest)
  ['yoghurt_pots', 54, 258], [I + 'milk', 148, 250], [I + 'cheese', 216, 250], [I + 'eggs', 262, 252], ['yoghurt_pots', 312, 258], [I + 'milk', 410, 250],
  ['juice_bottles', 160, 336], ['juice_bottles', 420, 334], ['bread_tin', 430, 426],
  // right window: bakery and fruit up top, pantry and household in the middle, dairy below
  ['wicker_basket', 828, 276], ['bread_boule', 839, 262], [I + 'strawberries', 888, 250], [I + 'banana', 942, 250],
  [I + 'crisps', 1032, 250], [I + 'crisps', 1076, 250], [I + 'tea_bags', 1128, 250], [I + 'coffee', 1176, 250],
  ['bread_tin', 828, 350], [I + 'croissant', 866, 326], [I + 'croissant', 910, 326], ['baguette_bin', 966, 310],
  [I + 'batteries', 1032, 326], [I + 'batteries', 1074, 326], ['juice_bottles', 1126, 332], ['juice_bottles', 1176, 332],
  ['yoghurt_pots', 826, 410], [I + 'milk', 924, 400], [I + 'eggs', 968, 402], [I + 'cheese', 1034, 400], ['yoghurt_pots', 1088, 410], [I + 'milk', 1182, 400],
  ['wall_clock', 724, 230],
];
let left = imgs.length + 1;
const loaded = {};
function done() {
  if (--left) return;
  for (const [n, x, y] of imgs) g.drawImage(loaded[n + x + y], x, y);
  // cashier behind the counter, seen through the doors
  g.drawImage(loaded.cashier, 0, 0, 76, 124, 566, 284, 152, 248);   // cropped at the counter front
  // checkout counter just inside the doors: steel top, teal front down to the floor line, kick strip
  r(256, 216, 128, 4, P.s3); r(256, 216, 128, 1, P.s1); r(256, 220, 128, 50, P.tealPanel); r(256, 220, 128, 2, P.teal3);
  r(256, 262, 128, 8, P.tealDark); for (let x = 266; x < 380; x += 24) r(x, 228, 1, 30, P.teal3);
  r(255, 215, 130, 1, P.ink); r(255, 220, 130, 1, P.ink);
  r(258, 200, 24, 16, P.ink); r(259, 201, 22, 14, P.char); r(259, 201, 22, 2, P.rub); r(261, 204, 18, 6, P.tealBlack); r(262, 205, 8, 1, P.gold);   // till with a lit display
  r(360, 208, 18, 8, P.ink); r(361, 209, 16, 6, P.s4); r(361, 209, 16, 1, P.s2);   // scanner plate
  glassAndFrames();
  const ic = new Image(); ic.onload = () => { g.drawImage(ic, 620 - 12, 202, 24, 18); }; ic.src = 'ASSETScart.png';
}
for (const [n, x, y] of imgs) { const im = new Image(); im.onload = done; im.src = n.startsWith(I) ? 'assets/art/items_v2/' + n.slice(3) + '.png' : 'ASSETS' + n + '.png'; loaded[n + x + y] = im; }
const cash = new Image(); cash.onload = done; cash.src = 'ASSETScashier.png'; loaded.cashier = cash;
""".replace("ASSETS", ASSETS)

COIN_SVG = ('<svg class="coin" viewBox="0 0 12 12" shape-rendering="crispEdges">'
            '<path fill="#2b2420" d="M3 0h6v1h2v2h1v6h-1v2h-2v1H3v-1H1V9H0V3h1V1h2z"/>'
            '<path fill="#e2b33c" d="M3 1h6v1h1v1h1v6h-1v1H9v1H3v-1H2V9H1V3h1V2h1z"/>'
            '<path fill="#ffcf3f" d="M3 2h5v1H3v5H2V3h1z"/><path fill="#b38425" d="M9 4h1v5H9v1H4V9h5z"/>'
            '<path fill="#7a5a1c" d="M5 4h2v4H5z"/></svg>')

WARN = f'<img src="{ASSETS}warning.png" alt="">'


def a_page(state: str) -> str:
    body = ['<canvas id="scene" width="1280" height="720"></canvas>',
            f'<div class="logo"><span class="ink">{TITLE}</span><span class="face">{TITLE}</span></div>',
            f'<div class="notice"><div class="tape" style="left:-14px;top:-8px;transform:rotate(-20deg)"></div>'
            f'<div class="tape" style="right:-14px;top:-8px;transform:rotate(18deg)"></div>'
            f'<p>{SUBTITLE}</p><div class="rule"></div><div class="coins">{COIN_SVG}{COINS}</div></div>',
            f'<div class="reserve low" style="left:956px;top:470px;width:288px;height:196px"><span>{RESERVE}</span></div>']
    if state == "nosave":
        body.append(f'<div class="prompt ol">{PROMPT}</div>')
    else:
        # 24 apart, each at least 200x64; centred on the doors (x 640)
        body.append(button("primary", CONTINUE, 340, 596, 360, 68, 26))
        body.append(button("primary", NEW_RUN, 724, 596, 216, 68, 26))
    body.append(button("secondary", EXPORT, 20, 664, 132, 40, 16))
    body.append(f'<div class="build">{BUILD}</div>')
    if state == "confirm":
        body.append('<div class="shade"></div>')
        body.append(f'<div class="ask"><div class="tape" style="left:-16px;top:-8px;transform:rotate(-20deg)"></div>'
                    f'<div class="tape" style="right:-16px;top:-8px;transform:rotate(18deg)"></div>'
                    f'<div class="q">{WARN}{QUESTION}</div><div class="row">'
                    f'<div class="fbtn primary ol" style="width:290px">{YES}</div>'
                    f'<div class="fbtn secondary ol" style="width:200px">{NO}</div></div></div>')
    name = {"save": "with a save", "nosave": "without a save", "confirm": "abandon confirmation"}[state]
    return page(f"Title A ({name})", A_HEADER + f"\n  STATE: {name}.", A_CSS, "\n".join(body), A_SCENE_JS)


# ------------------------------------------------------------------ B: one giant receipt on a plain backdrop
B_HEADER = """  #56 TITLE, OPTION B: THE GIANT RECEIPT (decide prep, 2026-10-19). Nothing is decided.
  Idea: a plain styled backdrop, the cheap option for the cut list ("simplify the title backdrop"). The darkest teal with a
  faint floor-tile check, and one giant till receipt hanging from a printer slot at the top edge. The logo is the receipt's
  header, printed big; the subtitle prints in the receipt font (JetBrains Mono) at the receipt's 44-character measure; the
  coin line is a gold price-gun starburst slapped across the header (the sticker device from #71's h1); the loyalty card
  (art/frames/loyalty_card.png, tilted -6 degrees, 3 empty stamp boxes) is stapled to the top-right corner as on #61's final
  receipt, so the title already shows the two objects a run ends with. Buttons sit on the paper; a barcode closes the strip.
  The space right of the receipt is RESERVED for the capsule machines' entry (#63; the dashed box is a mock-up note).
  New art/src/ sources: frames/receipt_tall (paper 9-slice with a torn bottom edge, or receipt_paper.png + a tear strip),
  frames/printer_slot (one steel strip), effects/sticker_burst_big (a larger gold starburst), the logo as a sprite
  (logo_title, the same one A would use). Reused: loyalty_card.png, stamp_ring_empty.png, button.png, sign.png, warning.png.
  Timing: none (the title has no offer timings). Optional juice, not in the capture: the receipt prints down 0.4 s on first
  show and the sticker slaps on; nothing waits for it (Enter or a click works at once). Reduced motion: shown in place.
  Fit check: the subtitle at 18 px mono in 2 lines of at most 44 characters; "Continue (shift 3 / 8)" in a 400 px button;
  the confirmation's question on one line in a 680 px slip.
  Art-direction pass (2026-10-19): the printer is the register's charcoal box with its LED; without a save the strip is
  shorter (no dead paper under the prompt); logo at weight 600 so the C stays open."""

B_CSS = """
.bg { position: absolute; inset: 0; background-color: var(--teal-black);
  background-image: linear-gradient(45deg, var(--teal-dark) 25%, transparent 25%, transparent 75%, var(--teal-dark) 75%),
    linear-gradient(45deg, var(--teal-dark) 25%, transparent 25%, transparent 75%, var(--teal-dark) 75%);
  background-size: 80px 80px; background-position: 0 0, 40px 40px; opacity: .45; }
.slot { position: absolute; left: 352px; top: -4px; width: 576px; height: 34px; background: #3d3a36; border: 2px solid var(--ink); border-top: 0;
  box-shadow: inset 0 -6px 0 #2c2926, inset 0 4px 0 #57534c, 8px 8px 0 rgba(0,0,0,.35); }
.slot i { position: absolute; left: 34px; right: 34px; bottom: 6px; height: 4px; background: var(--ink); }
.slot b { position: absolute; left: 14px; top: 10px; width: 8px; height: 6px; background: #5fae5a; box-shadow: 0 0 0 2px var(--ink); }
.slot u { position: absolute; left: 30px; top: 10px; width: 12px; height: 6px; background: #8d8a83; box-shadow: 0 0 0 2px var(--ink); }
.receipt { position: absolute; left: 392px; top: 14px; width: 496px; height: 690px; background: var(--paper);
  border-left: 2px solid var(--ink); border-right: 2px solid var(--ink); box-shadow: inset -6px 0 0 var(--cream-shade);
  clip-path: polygon(TEETH); }
.rshadow { position: absolute; left: 402px; top: 24px; width: 496px; height: 690px; background: rgba(0,0,0,.35); clip-path: polygon(TEETH); }
.rink { position: absolute; left: 390px; top: 14px; width: 500px; height: 693px; background: var(--ink); clip-path: polygon(TEETHINK); }
.rc { position: absolute; left: 392px; top: 14px; width: 496px; display: flex; flex-direction: column; align-items: center; }
.hdr { margin-top: 40px; font: 15px JBMono; color: var(--ink-light); letter-spacing: 1px; }
.logo { margin-top: 10px; text-align: center; font-family: Pixelify; font-weight: 600; color: var(--ink); line-height: .92; }
.logo .l1 { font-size: 104px; letter-spacing: 6px; }
.logo .l2 { font-size: 76px; letter-spacing: 2px; }
.dash { width: 432px; margin-top: 18px; border-top: 2px dashed var(--cream-dark); }
.sub { width: 432px; margin-top: 16px; font: 18px/26px JBMono; color: var(--ink); text-align: center; }
.burst { position: absolute; left: 542px; top: 368px; width: 196px; height: 92px; transform: rotate(-9deg); }
.burst > svg { position: absolute; inset: 0; width: 196px; height: 92px; }
.burst span { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; gap: 8px; font: 750 26px Atkinson; color: var(--ink); padding-bottom: 4px; white-space: nowrap; }
.card { position: absolute; left: 800px; top: 30px; width: 176px; height: 108px; transform: rotate(-6deg);
  border: 6px solid transparent; border-image: url(ASSETSloyalty_card.png) 6 fill / 6px stretch; box-shadow: 6px 6px 0 rgba(0,0,0,.3); }
.card .band { position: absolute; left: -2px; right: -2px; top: 2px; height: 22px; background: var(--teal); border-bottom: 2px solid #3a7672; }
.card .t { position: absolute; right: 10px; top: 3px; font: 15px Pixelify; letter-spacing: 1px; color: var(--paper); }
.card .boxes { position: absolute; left: 12px; top: 40px; display: flex; gap: 12px; }
.card .boxes img { width: 34px; height: 34px; opacity: .8; }
.staple { position: absolute; left: 818px; top: 60px; width: 20px; height: 5px; background: var(--muted); border: 1px solid var(--ink); transform: rotate(-6deg); }
.btns { position: absolute; left: 432px; width: 416px; }
.barcode { position: absolute; left: 472px; top: 640px; width: 336px; height: 34px; display: flex; gap: 2px; justify-content: center; }
.barcode i { display: block; background: var(--ink); height: 34px; }
.prompt { position: absolute; left: 392px; width: 496px; top: 490px; text-align: center; font: 30px Pixelify; color: var(--ink); }
.prompt small { display: block; margin-top: 6px; font: 15px JBMono; color: var(--muted); letter-spacing: 1px; }
/* the confirmation: a void slip torn from the same roll */
.ask { left: 290px; top: 250px; width: 700px; height: 220px; justify-content: center; padding: 8px 30px 12px; background: var(--paper);
  clip-path: polygon(SLIP); box-shadow: inset -6px 0 0 var(--cream-shade); }
.askink { position: absolute; left: 288px; top: 248px; width: 704px; height: 224px; background: var(--ink); clip-path: polygon(SLIPINK); }
.askshadow { position: absolute; left: 300px; top: 260px; width: 700px; height: 220px; background: rgba(0,0,0,.4); clip-path: polygon(SLIP); }
""".replace("ASSETS", ASSETS)


def teeth(w: int, h: int, tooth: int = 16, depth: int = 8, top_too: bool = False) -> str:
    """A torn edge as a stepped zigzag (polygon points in px)."""
    pts = []
    if top_too:
        for x in range(0, w + 1, tooth):
            pts.append(f"{x}px {depth if (x // tooth) % 2 else 0}px")
    else:
        pts += ["0 0", f"{w}px 0"]
    for x in range(w, -1, -tooth):
        pts.append(f"{x}px {h - (depth if (x // tooth) % 2 else 0)}px")
    return ", ".join(pts)


def b_page(state: str) -> str:
    # without a save the strip is shorter (no buttons): the prompt prints under the sticker, then the barcode
    rh = 596 if state == "nosave" else 690
    css = B_CSS
    if state == "nosave":
        css = css.replace("height: 690px", f"height: {rh}px").replace("height: 693px", f"height: {rh + 3}px").replace(
            "top: 640px; width: 336px", f"top: {rh - 50}px; width: 336px").replace("top: 490px; text-align", "top: 482px; text-align")
    css = (css.replace("TEETHINK", teeth(500, rh + 3)).replace("TEETH", teeth(496, rh))
           .replace("SLIPINK", teeth(704, 224, 16, 8, True)).replace("SLIP", teeth(700, 220, 16, 8, True)))
    # a stepped 8-point starburst on the 2 px grid
    burst = ('<svg viewBox="0 0 98 46" shape-rendering="crispEdges">'
             '<polygon fill="#2b2420" points="49,0 57,6 69,2 72,10 86,9 84,16 97,21 88,27 95,35 81,36 78,44 64,40 49,46 36,40 21,44 17,36 3,35 10,27 1,21 13,16 12,9 26,10 30,2 41,6"/>'
             '<polygon fill="#e2b33c" points="49,3 57,9 67,5 70,12 83,12 81,18 92,22 85,27 91,33 79,34 76,41 64,37 49,43 36,37 23,41 20,34 7,33 13,27 6,22 17,18 15,12 28,12 31,5 41,9"/>'
             '<polygon fill="#ffcf3f" points="49,3 57,9 67,5 70,12 83,12 81,18 92,22 49,22 6,22 17,18 15,12 28,12 31,5 41,9"/></svg>')
    bars = "".join(f'<i style="width:{w}px"></i>' for w in [4, 2, 2, 6, 2, 4, 2, 2, 4, 6, 2, 2, 4, 2, 6, 2, 4, 2, 2, 6, 4, 2, 2, 4, 2, 6, 2, 2, 4, 2, 4, 6, 2, 2, 4, 2, 2, 6, 2, 4, 2, 4, 2, 2, 6, 2, 4, 2, 2, 4, 6, 2, 4, 2, 2])
    body = ['<div class="bg"></div>', '<div class="rshadow"></div>', '<div class="rink"></div>', '<div class="receipt"></div>',
            '<div class="slot"><i></i><b></b><u></u></div>',
            f'<div class="rc"><div class="hdr">NEXT CUSTOMER · REG 3</div>'
            f'<div class="logo"><div class="l1">NEXT</div><div class="l2">CUSTOMER</div></div>'
            f'<div class="dash"></div><div class="sub">{SUBTITLE}</div><div class="dash"></div></div>',
            f'<div class="burst">{burst}<span>{COIN_SVG}{COINS}</span></div>',
            f'<div class="barcode">{bars}</div>',
            f'<div class="card"><div class="band"></div><div class="t ol">LOYALTY</div><div class="boxes">'
            + "".join(f'<img src="{ASSETS}stamp_ring_empty.png" alt="">' for _ in range(3)) + '</div></div>',
            '<div class="staple"></div>',
            f'<div class="reserve" style="left:944px;top:330px;width:300px;height:250px"><span>{RESERVE}</span></div>']
    if state == "nosave":
        body.append(f'<div class="prompt">{PROMPT}</div>')
    else:
        # stacked on the paper, 24 apart, each 416x64 (>= 200x64)
        body.append(button("primary", CONTINUE, 432, 470, 416, 64, 26))
        body.append(button("primary", NEW_RUN, 432, 558, 416, 64, 26))
    body.append(button("secondary", EXPORT, 20, 664, 132, 40, 16))
    body.append(f'<div class="build">{BUILD}</div>')
    if state == "confirm":
        body.append('<div class="shade"></div><div class="askshadow"></div><div class="askink"></div>')
        body.append(f'<div class="ask"><div class="q">{WARN}{QUESTION}</div><div class="row">'
                    f'<div class="fbtn primary ol" style="width:290px">{YES}</div>'
                    f'<div class="fbtn secondary ol" style="width:200px">{NO}</div></div></div>')
    name = {"save": "with a save", "nosave": "without a save", "confirm": "abandon confirmation"}[state]
    if state == "nosave":
        # without a save the receipt is shorter: no buttons, the prompt prints where they were
        pass
    return page(f"Title B ({name})", B_HEADER + f"\n  STATE: {name}.", css, "\n".join(body))


def main() -> None:
    for state, suffix in (("save", ""), ("nosave", "_nosave"), ("confirm", "_confirm")):
        (ROOT / f"screens_title_a{suffix}.html").write_text(a_page(state), encoding="utf-8")
        (ROOT / f"screens_title_b{suffix}.html").write_text(b_page(state), encoding="utf-8")
        print("wrote", f"screens_title_a{suffix}.html", f"screens_title_b{suffix}.html")


if __name__ == "__main__":
    main()
