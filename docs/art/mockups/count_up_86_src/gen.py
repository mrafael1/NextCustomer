"""Builds the #86 decide mock-ups in docs/art/mockups (2026-10-19; nothing decided beyond Q1/Q2):

- count_up_86_board.html: the parts to choose from, drawn large: three count-up monitor layouts (MA, MB, MC) at two moments,
  three quota gauges (GA, GB, GC) in four states, the name candidates on the gauge, and the item beat that the user already
  chose (stickers stay and fire, the rail strip lights as it pays).
- count_up_86_scene.html: planning_effects_h1.html in the count-up at the quota ding with the recommended monitor and gauge,
  so the parts can be judged in place.

Standard library only. Run from anywhere: python docs/art/mockups/count_up_86_src/gen.py
"""
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).parent
MOCKUPS = HERE.parent

FONTS = """
@font-face { font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }
@font-face { font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }
@font-face { font-family: JBMono; src: url(../../../fonts/JetBrainsMono-Regular.ttf); }
:root {
  --ink: #2b2420; --ink-light: #4a3f38; --muted: #8a8172; --paper: #fbf7ee; --cream: #f3e9d2;
  --cream-shade: #ddcba5; --mustard: #e2b33c; --mustard-light: #f1d27a; --mustard-pale: #faecbc; --mustard-dark: #b38425;
  --tomato: #d9534f; --tomato-dark: #a83a3c; --tomato-light: #ec7d75; --teal: #4f9a94; --teal-panel: #2a4d4b; --teal-dark: #1f3b3a;
  --good: #5fae5a; --good-dark: #3f7d3b; --wood: #a8703a; --rubber: #3d3a36; --steel-light: #c7c3b8;
}
"""


def star_points(n=14, r_out=50, r_in=38):
    """A starburst polygon (percent coordinates) for clip-path."""
    import math
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi * i / n - math.pi / 2
        pts.append(f"{50 + r * math.cos(a):.1f}% {50 + r * math.sin(a):.1f}%")
    return "polygon(" + ", ".join(pts) + ")"


STAR = star_points()

PARTS_CSS = """
/* ---- shared parts ---- */
.num { font-family: Atkinson; font-weight: 750; }
.px { image-rendering: pixelated; }
/* h1 stickers, approximated in CSS: a cream price-gun label (+N) and a gold starburst (xN), ink outline, hard shadow */
.lab86 { display: inline-flex; align-items: center; justify-content: center; font-family: Atkinson; font-weight: 800; color: var(--ink);
  background: var(--paper); border: 2px solid var(--ink); box-shadow: 3px 3px 0 rgba(43,36,32,.35), inset 0 -3px 0 var(--cream-shade); }
.star86 { position: relative; display: inline-grid; place-items: center; font-family: Atkinson; font-weight: 800; color: var(--ink); }
.star86::before, .star86::after { content: ""; position: absolute; inset: 0; clip-path: STAR; z-index: 0; }
.star86::before { background: var(--ink); transform: translate(3px, 3px); opacity: .35; }
.star86::after { background: var(--ink); }
.star86 > i { position: absolute; z-index: 1; inset: 3px; clip-path: STAR; background: var(--mustard); box-shadow: inset 0 4px 0 var(--mustard-light); }
.star86 > b { position: relative; z-index: 2; }
.okdisc86 { display: inline-grid; place-items: center; width: 22px; height: 22px; background: var(--good); border: 2px solid var(--ink);
  border-radius: 50%; color: var(--paper); font-size: 13px; font-weight: 800; line-height: 1; flex: none; }
.stamp86 { display: inline-flex; flex-direction: column; align-items: center; padding: 2px 10px; border: 3px solid currentColor;
  outline: 2px solid currentColor; outline-offset: 2px; font-family: Pixelify; letter-spacing: 1px; transform: rotate(-8deg); background: rgba(251,247,238,.85); }
.spark86 { position: absolute; width: 10px; height: 10px; background:
  linear-gradient(var(--mustard-light), var(--mustard-light)) 4px 0 / 2px 10px no-repeat,
  linear-gradient(var(--mustard-light), var(--mustard-light)) 0 4px / 10px 2px no-repeat; }

/* ---- monitor (424 x 176, as in the game) ---- */
.mon { position: relative; width: 424px; height: 176px; background: var(--rubber); border: 2px solid var(--ink); border-radius: 6px; padding: 6px; flex: none; }
.scr { position: relative; width: 100%; height: 100%; background: var(--paper); border: 2px solid var(--ink); border-radius: 2px; overflow: hidden; }
.scr .lbl { font-family: Pixelify; font-size: 14px; letter-spacing: 2px; color: var(--ink-light); }
.scr .art { position: absolute; left: 8px; top: 8px; width: 88px; text-align: center; }
.scr .art img { width: 88px; height: 88px; }
.scr .art .k { font-family: Pixelify; font-size: 12px; color: var(--teal-panel); letter-spacing: 1px; }
.big86 { font-family: Atkinson; font-weight: 800; letter-spacing: -1px; color: var(--ink); }
.segs86 { display: flex; gap: 2px; padding: 2px; background: var(--ink); }
.segs86 i { flex: 1; background: #d9cfba; }
.segs86 i.on { background: var(--mustard); box-shadow: inset 0 2px 0 var(--mustard-light); }
.segs86 i.next { background: var(--mustard-pale); box-shadow: inset 0 0 0 2px var(--mustard-dark); }
.segs86.met i { background: var(--mustard-light); box-shadow: inset 0 2px 0 var(--paper); }

/* ---- top bar gauge (the QUOTA chip: 396 x 38 in the game's top bar) ---- */
.bar { position: relative; width: 520px; height: 56px; background: var(--teal-dark); border: 2px solid var(--ink); display: flex; align-items: center; padding: 0 10px; }
.chip { position: relative; height: 38px; display: flex; align-items: center; gap: 8px; padding: 0 10px; background: var(--teal-panel);
  border: 2px solid var(--ink); border-radius: 4px; box-shadow: inset 0 2px 0 rgba(255,255,255,.12); color: var(--paper); width: 100%; }
.chip .k { font-family: Pixelify; font-size: 15px; letter-spacing: 1px; color: var(--mustard-pale); white-space: nowrap; }
.chip .v { font-family: Atkinson; font-weight: 750; font-size: 20px; white-space: nowrap; }
.track86 { position: relative; flex: 1; height: 16px; background: var(--ink); padding: 2px; }
.togo86 { font-family: Atkinson; font-weight: 750; font-size: 13px; padding: 1px 6px; background: var(--paper); color: var(--ink); border: 2px solid var(--ink); white-space: nowrap; }
.togo86.short { color: var(--tomato-dark); }

/* ---- board layout ---- */
html, body { background: #17302f; }
body { width: 1280px; font-family: Atkinson, sans-serif; color: var(--paper); padding: 18px 24px 30px; }
* { box-sizing: border-box; margin: 0; padding: 0; }
h1 { font-family: Pixelify; font-size: 26px; color: var(--mustard-light); letter-spacing: 1px; }
h1 small { font-family: Atkinson; font-size: 14px; color: var(--steel-light); letter-spacing: 0; margin-left: 12px; font-weight: 500; }
h2 { font-family: Pixelify; font-size: 19px; color: var(--paper); margin: 18px 0 4px; letter-spacing: 1px; }
h2 .tag { font-family: Atkinson; font-size: 11px; font-weight: 800; color: var(--ink); background: var(--mustard); padding: 1px 6px; margin-left: 8px; letter-spacing: 0; vertical-align: 3px; }
.note { font-size: 13px; color: var(--steel-light); line-height: 17px; max-width: 1220px; }
.row { display: flex; gap: 16px; align-items: flex-start; margin-top: 8px; }
.cell { display: flex; flex-direction: column; gap: 4px; }
.cap { font-size: 12px; color: var(--steel-light); font-weight: 600; }
.cap b { color: var(--mustard-light); }
.rec { outline: 3px solid var(--mustard); outline-offset: 6px; }
"""
PARTS_CSS = PARTS_CSS.replace("STAR", STAR)

MILK = "assets/art/items_v2/milk.png"

# ---------------------------------------------------------------- monitors
# Two moments for each: BEAT (the 3rd Milk's x3 lands: subtotal 23 -> 65, quota 73 not reached) and MET (the last Milk's
# +12 loyalty lands: 65 -> 77, the quota ding).


def mon_a(met):
    """MA, sticker slam: the landing sticker is slapped big on the monitor beside a huge subtotal; the quota is a segment track
    with a "to go" tag; at the ding a stamp slams over the track and the number gets h1's stepped halo."""
    sub, gain = ("€77", "+12") if met else ("€65", "×3")
    sticker = (f'<span class="lab86" style="position:absolute;left:286px;top:30px;height:44px;padding:0 10px;font-size:28px;transform:rotate(6deg)">{gain}</span>'
               if met else
               f'<span class="star86" style="position:absolute;left:282px;top:16px;width:78px;height:78px;font-size:28px;transform:rotate(-8deg)"><i></i><b>{gain}</b></span>')
    halo = ("text-shadow: 0 0 0 transparent; filter: drop-shadow(2px 0 0 #faecbc) drop-shadow(-2px 0 0 #faecbc) drop-shadow(0 2px 0 #faecbc) drop-shadow(0 -2px 0 #faecbc)"
            " drop-shadow(2px 0 0 #e2b33c) drop-shadow(-2px 0 0 #e2b33c) drop-shadow(0 2px 0 #e2b33c) drop-shadow(0 -2px 0 #e2b33c);" if met else "text-shadow: 4px 4px 0 var(--mustard-light);")
    segs = ('<span class="segs86 met" style="width:100%;height:18px">' + '<i></i>' * 10 + '</span>' if met else
            '<span class="segs86" style="width:100%;height:18px">' + '<i class="on"></i>' * 8 + '<i class="next"></i><i></i></span>')
    tail = ('<span class="stamp86" style="position:absolute;left:150px;top:118px;color:var(--good-dark);font-size:18px;line-height:18px">SPEND MET ✓</span>'
            '<span class="spark86" style="left:132px;top:112px"></span><span class="spark86" style="left:300px;top:150px"></span>' if met else
            '<span class="togo86" style="position:absolute;left:278px;top:114px">€8 to go</span>')
    return f'''<div class="mon"><div class="scr">
  <div class="art"><img class="px" src="{MILK}"><div class="k">MILK {"7" if met else "6"} / 7</div></div>
  <div style="position:absolute;left:108px;top:6px" class="lbl">SUBTOTAL</div>
  <div class="big86" style="position:absolute;left:104px;top:20px;font-size:76px;line-height:76px;{halo}">{sub}</div>
  {sticker}
  <div style="position:absolute;left:108px;right:10px;top:122px;display:flex;align-items:center;gap:8px">
    <span class="lbl" style="font-size:12px;letter-spacing:1px;white-space:nowrap">SPEND €73+</span>{segs}</div>
  {tail}
</div></div>'''


def mon_b(met):
    """MB, till drums: the subtotal rolls on mechanical digit drums (the rolling digit shows half of the next one); the gain
    flies in as a coin chip; the quota is a "to go" counter under the drums; at the ding the drums turn gold and a bell rings."""
    digits = "077" if met else "065"
    drums = ""
    for i, d in enumerate(digits):
        rolling = (i == 2)
        bg = "var(--mustard-light)" if met else "var(--paper)"
        nxt = str((int(d) + 1) % 10)
        inner = (f'<span style="position:absolute;left:0;right:0;top:-26px;opacity:.55">{nxt}</span><span style="position:relative">{d}</span>'
                 if rolling and not met else d)
        drums += (f'<span style="position:relative;overflow:hidden;display:inline-grid;place-items:center;width:58px;height:78px;background:{bg};'
                  f'border:3px solid var(--ink);box-shadow:inset 0 10px 0 rgba(43,36,32,.12), inset 0 -10px 0 rgba(43,36,32,.12);'
                  f'font-family:Atkinson;font-weight:800;font-size:58px;color:var(--ink);margin-right:4px">{inner}</span>')
    under = ('<span class="okdisc86">✓</span><span style="font-weight:800;font-size:15px;color:var(--good-dark)">SPEND MET</span>'
             '<span style="font-size:13px;font-weight:700;color:var(--ink-light);margin-left:auto">+€4 over</span>' if met else
             '<span style="font-family:Pixelify;font-size:13px;color:var(--ink-light);letter-spacing:1px">SPEND €73+</span>'
             '<span class="togo86 short" style="margin-left:auto">€8 to go</span>')
    chip = ('<span class="lab86" style="position:absolute;left:330px;top:14px;height:30px;padding:0 6px;font-size:18px">+€12</span>' if met else
            '<span class="star86" style="position:absolute;left:326px;top:6px;width:56px;height:56px;font-size:19px"><i></i><b>×3</b></span>')
    bell = ('<span style="position:absolute;left:342px;top:66px;font-size:30px">🔔</span>' if met else '')
    return f'''<div class="mon"><div class="scr">
  <div class="art"><img class="px" src="{MILK}"><div class="k">MILK {"7" if met else "6"} / 7</div></div>
  <div style="position:absolute;left:108px;top:6px" class="lbl">€ SUBTOTAL</div>
  <div style="position:absolute;left:106px;top:26px;display:flex">{drums}</div>
  {chip}{bell}
  <div style="position:absolute;left:108px;right:10px;top:122px;display:flex;align-items:center;gap:8px">{under}</div>
</div></div>'''


def mon_c(met):
    """MC, coin tube: a tall tube on the right fills with stacked coins toward the quota line; coins over the line are gold and
    stack on; the subtotal sits big on the left with the landing sticker under it."""
    fill = 1.05 if met else 0.89
    h = 132
    line_y = 22  # the quota line, from the tube's top
    coins = ""
    stack_h = int((h - line_y) * fill)
    for k in range(stack_h // 8):
        y = h - 8 - k * 8
        over = y < line_y
        coins += (f'<i style="position:absolute;left:3px;right:3px;top:{y}px;height:8px;border:2px solid var(--ink);border-radius:3px;'
                  f'background:{"var(--mustard-light)" if over else "var(--mustard)"};box-shadow:inset 0 2px 0 {"var(--paper)" if over else "var(--mustard-light)"}"></i>')
    tube = (f'<div style="position:absolute;right:16px;top:12px;width:46px;height:{h}px;background:#e9e1cd;border:3px solid var(--ink);border-top:0;'
            f'box-shadow:inset 6px 0 0 rgba(255,255,255,.5)">{coins}'
            f'<div style="position:absolute;left:-12px;right:-12px;top:{line_y}px;height:0;border-top:3px dashed {"var(--good-dark)" if met else "var(--tomato-dark)"}"></div></div>'
            f'<div style="position:absolute;right:74px;top:{12 + line_y - 9}px;font-weight:800;font-size:13px;color:{"var(--good-dark)" if met else "var(--tomato-dark)"}">'
            f'{"✓ €73" if met else "€73"}</div>')
    sticker = ('<span class="lab86" style="height:30px;padding:0 8px;font-size:20px">+12 <small style="font-size:12px">loyalty</small></span>' if met else
               '<span class="star86" style="width:58px;height:58px;font-size:19px"><i></i><b>×3</b></span>')
    msg = ('<span class="stamp86" style="position:absolute;left:204px;top:96px;color:var(--good-dark);font-size:15px">MET</span>' if met else
           '<span class="togo86 short" style="position:absolute;left:184px;top:112px">€8 to go</span>')
    return f'''<div class="mon"><div class="scr">
  <div class="art"><img class="px" src="{MILK}"><div class="k">MILK {"7" if met else "6"} / 7</div></div>
  <div style="position:absolute;left:108px;top:6px" class="lbl">SUBTOTAL</div>
  <div class="big86" style="position:absolute;left:104px;top:22px;font-size:62px;line-height:62px;text-shadow:3px 3px 0 var(--mustard-light)">{"€77" if met else "€65"}</div>
  <div style="position:absolute;left:108px;top:96px;display:flex;align-items:center;gap:6px">{sticker}</div>
  {msg}{tube}
</div></div>'''


# ---------------------------------------------------------------- gauges
# States: SHORT (planning, projected 52 of 73), CLOSE (projected 70), MET (projected 182), DRAG (52 -> 58 while dragging).

def gauge_a(state, name="SPEND €73+"):
    """GA, segment track: 10 segments, each 10 % of the quota; the next one to fill is outlined; a "to go" tag on the right;
    at the quota every segment turns pale gold and the tag becomes a check disc with what you're over."""
    total = {"short": 52, "close": 70, "met": 182, "drag": 58}[state]
    on = min(10, total * 10 // 73)
    segs = "".join('<i class="on"></i>' if i < on else ('<i class="next"></i>' if i == on else '<i></i>') for i in range(10))
    if state == "met":
        segs = '<i></i>' * 10
    track = f'<span class="segs86{" met" if state == "met" else ""}" style="flex:1;height:18px">{segs}</span>'
    right = {"short": '<span class="togo86 short">€21 to go</span>',
             "close": '<span class="togo86">€3 to go</span>',
             "met": '<span class="okdisc86">✓</span><span class="v" style="color:var(--mustard-light)">€182</span>',
             "drag": '<span class="v" style="color:var(--mustard-light)">› €58</span><span class="togo86 short">€15 to go</span>'}[state]
    return f'<div class="bar"><div class="chip"><span class="k">{name}</span>{track}{right}</div></div>'


def gauge_b(state, name="SPEND €73+", w=270):
    """GB, goal flag: the quota is a flag post two thirds along the track, so the track also shows how far past it you go (to
    1.5x; beyond that the marker sits at the end with a +N arrow). The total is a price-gun tag riding the track; the part past
    the flag fills gold. At the quota the flag turns into a gold check pennant."""
    total = {"short": 52, "close": 70, "met": 182, "drag": 58}[state]
    flag_x = int(w * 2 / 3)
    pos = min(w, int(total / 73 * flag_x))
    fill_main = min(pos, flag_x)
    over = max(0, pos - flag_x)
    met = state == "met"
    ghost = ""
    if state == "drag":
        ghost_pos = int(58 / 73 * flag_x)
        pos = int(52 / 73 * flag_x)
        fill_main = pos
        ghost = (f'<i style="position:absolute;left:{pos + 2}px;top:2px;width:{ghost_pos - pos}px;height:12px;'
                 f'background:repeating-linear-gradient(90deg,var(--mustard) 0 4px,transparent 4px 6px)"></i>')
    flag = (f'<span style="position:absolute;left:{flag_x - 1}px;top:-12px;width:3px;height:30px;background:var(--paper);border:1px solid var(--ink)"></span>'
            f'<span style="position:absolute;left:{flag_x + 2}px;top:-12px;height:14px;padding:0 4px;font-size:10px;font-weight:800;line-height:12px;'
            f'background:{"var(--good)" if met else "var(--paper)"};color:{"var(--paper)" if met else "var(--ink)"};border:1px solid var(--ink)">{"✓" if met else "€73"}</span>')
    tag_x = (int(58 / 73 * flag_x) if state == "drag" else pos)
    tag_txt = {"short": "€52", "close": "€70", "met": "€182 ›", "drag": "€58"}[state]
    tag = (f'<span style="position:absolute;left:{tag_x - 18}px;top:16px;height:16px;padding:0 4px;font-size:11px;font-weight:800;line-height:13px;'
           f'background:{"var(--mustard)" if met else "var(--paper)"};color:var(--ink);border:2px solid var(--ink);white-space:nowrap">{tag_txt}</span>')
    track = (f'<span class="track86" style="flex:none;width:{w + 4}px;margin-top:-10px">'
             f'<i style="position:absolute;left:2px;top:2px;width:{fill_main}px;height:12px;background:var(--mustard);box-shadow:inset 0 2px 0 var(--mustard-light)"></i>'
             f'<i style="position:absolute;left:{flag_x + 2}px;top:2px;width:{over}px;height:12px;background:var(--mustard-light);box-shadow:inset 0 2px 0 var(--paper)"></i>'
             f'{ghost}{flag}{tag}</span>')
    right = {"short": '<span class="togo86 short">€21 to go</span>', "close": '<span class="togo86">€3 to go</span>',
             "met": '<span class="okdisc86">✓</span>', "drag": '<span class="togo86 short">€15 to go</span>'}[state]
    return f'<div class="bar"><div class="chip"><span class="k">{name}</span>{track}{right}</div></div>'


def gauge_c(state, name="SPEND €73+"):
    """GC, stamp: today's bar and numbers, juiced by what happens at the line: the name sits on a cream price tag; short shows
    "short €N" on the tag in tomato ink; at the quota a green MET stamp slams onto the tag and the bar turns gold to the end."""
    total = {"short": 52, "close": 70, "met": 182, "drag": 58}[state]
    pct = min(100, total * 100 // 73)
    met = state == "met"
    tag = (f'<span style="position:relative;display:inline-flex;flex-direction:column;justify-content:center;height:30px;padding:0 8px;background:var(--paper);'
           f'color:var(--ink);border:2px solid var(--ink);font-family:Pixelify;font-size:13px;line-height:13px;white-space:nowrap">{name}'
           + ('' if met else f'<small style="font-family:Atkinson;font-weight:800;font-size:11px;color:{"var(--tomato-dark)" if total < 70 else "var(--ink)"}">'
              f'{"short €" + str(73 - (52 if state == "drag" else total))}</small>')
           + ('<span class="stamp86" style="position:absolute;left:30px;top:-6px;color:var(--good-dark);font-size:13px;line-height:13px;padding:1px 6px">MET ✓</span>' if met else '')
           + '</span>')
    fill = "var(--mustard-light)" if met else "var(--mustard)"
    track = (f'<span class="track86"><i style="position:absolute;left:2px;top:2px;bottom:2px;width:calc({pct}% - 4px);background:{fill};'
             f'box-shadow:inset 0 2px 0 var(--mustard-light)"></i></span>')
    v = {"short": "€52", "close": "€70", "met": "€182", "drag": "€52 › €58 (+6)"}[state]
    return f'<div class="bar"><div class="chip" style="padding-left:4px">{tag}{track}<span class="v" style="color:var(--mustard-light)">{v}</span></div></div>'


# ---------------------------------------------------------------- the item beat (Q1/Q2 decided: stay and fire, strip lights)

def item_beat(phase):
    """The 7th Milk as Multipack's x3 lands on it: before (calm, as in planning), fire (the x3 sticker punches 125 % with a white
    flash ring, the strip lights gold from Multipack to this Milk, +€42 pops on the rail, the halo steps up a ring, the ticket's
    burst rolls up), after (settled: sticker back to size with a small gold tick, strip calm again, halo kept)."""
    fire = phase == "fire"
    after = phase == "after"
    halo = {"before": 1, "fire": 2, "after": 2}[phase]
    rings = ["#2b2420", "#e2b33c", "#faecbc"][:halo + 1][::-1]
    filt = " ".join(f"drop-shadow(2px 0 0 {c}) drop-shadow(-2px 0 0 {c}) drop-shadow(0 2px 0 {c}) drop-shadow(0 -2px 0 {c})" for c in rings)
    star_style = "transform:rotate(-6deg) scale(1.25);" if fire else "transform:rotate(-6deg);"
    flash = ('<span style="position:absolute;left:96px;top:46px;width:86px;height:86px;border-radius:50%;border:4px solid var(--paper);opacity:.9"></span>'
             '<span class="spark86" style="left:90px;top:44px"></span><span class="spark86" style="left:178px;top:116px"></span>' if fire else '')
    tick = ('<span class="okdisc86" style="position:absolute;left:160px;top:56px;width:18px;height:18px;font-size:11px">✓</span>' if after else '')
    strip_bg = "var(--mustard-light)" if fire else "#b38425"
    strip_ring = "box-shadow:0 0 0 2px var(--paper),0 0 0 4px var(--mustard),0 0 0 6px var(--ink);" if fire else ""
    gain = ('<span class="lab86" style="position:absolute;left:60px;top:196px;height:22px;padding:0 5px;font-size:14px;background:var(--mustard)">+€42</span>' if fire else '')
    price = {"before": "€126", "fire": "€126", "after": "€126"}[phase]
    burst_scale = "scale(1.2)" if fire else "scale(1)"
    return f'''<div style="position:relative;width:236px;height:290px;background:linear-gradient(#e4d6b9 0 150px,#3d3a36 150px 206px,#8d8a83 206px 222px,#a8703a 222px);border:2px solid var(--ink)">
  <img class="px" src="{MILK}" style="position:absolute;left:60px;top:{60 if fire or after else 66}px;width:96px;height:96px;filter:{filt}">
  <span class="lab86" style="position:absolute;left:126px;top:18px;height:26px;padding:0 6px;font-size:17px">+5</span>
  <span class="lab86" style="position:absolute;left:132px;top:40px;height:26px;padding:0 6px;font-size:17px">+12</span>
  <span class="star86" style="position:absolute;left:118px;top:64px;width:56px;height:56px;font-size:19px;{star_style}"><i></i><b>×3</b></span>
  {flash}{tick}
  <span style="position:absolute;left:0;right:0;top:206px;height:14px;background:{strip_bg};border-top:2px solid var(--ink);border-bottom:2px solid var(--ink);{strip_ring}"></span>
  <span style="position:absolute;left:4px;top:206px;font-family:Pixelify;font-size:10px;color:var(--ink);line-height:14px">‹ MULTIPACK</span>
  {gain}
  <div style="position:absolute;left:14px;right:14px;top:228px;height:52px;background:var(--paper);border:2px solid var(--ink);padding:3px 6px;color:var(--ink)">
    <span style="font-weight:750;font-size:18px;color:var(--ink-light);text-decoration:line-through">€4</span>
    <span class="star86" style="position:absolute;right:-6px;top:-18px;width:66px;height:46px;font-size:18px;transform:{burst_scale}"><i></i><b>{price}</b></span>
    <div style="font-size:11px;font-weight:650;line-height:12px">+1 per earlier<br>Breakfast</div></div>
</div>'''


def board():
    mons = [("MA", "Sticker slam", mon_a, True,
             "The landing sticker is slapped big on the monitor, the same h1 shape as on the item. Huge subtotal; a segment track with "
             "\"€8 to go\". At the ding a SPEND MET stamp slams over the track and the number gets h1's stepped halo."),
            ("MB", "Till drums", mon_b, False,
             "The subtotal rolls on mechanical digit drums, each gain spinning the last drum. The quota is a \"to go\" counter under "
             "the drums. At the ding the drums turn gold, the bell rings and the line reads SPEND MET, +€N over."),
            ("MC", "Coin tube", mon_c, False,
             "A tube on the right fills with coins toward a dashed quota line; past it, gold coins keep stacking. The subtotal and the "
             "landing sticker sit on the left. Shows \"how close\" as a height, but it's the busiest of the three.")]
    gauges = [("GA", "Segment track", gauge_a, False,
               "Ten segments, each 10 % of the quota; the next one to fill is outlined. A \"to go\" tag, tomato ink while short. At "
               "the quota the segments go pale gold and the tag becomes a check with the total."),
              ("GB", "Goal flag", gauge_b, True,
               "The quota is a flag post two thirds along, so the track also shows how far past it you are (up to 1.5×, then the tag "
               "sits at the end with ›). The total rides the track on a price-gun tag; past the flag it fills pale gold. A drag shows "
               "the new stretch hatched."),
              ("GC", "Stamp on the tag", gauge_c, False,
               "Today's bar and numbers; the name sits on a cream tag that says \"short €N\". At the quota a MET ✓ stamp slams onto "
               "the tag and the bar fills gold. The cheapest; how close is still only a bar length.")]
    states = [("short", "planning: €52 of €73"), ("close", "planning: €70, almost"), ("met", "met: €182"), ("drag", "drag: €52 › €58")]

    out = [f'<h1>#86: count-up, monitor and quota gauge<small>decide mock-ups, 2026-10-19 · decided already: stickers stay and fire, '
           f'the rail strip lights as it pays · gold outline = recommended</small></h1>']
    out.append('<h2>The item beat <span class="tag">DECIDED</span></h2><div class="note">The 7th Milk as Multipack\'s ×3 lands on it. '
               'Nothing moves to a new place: the ×3 sticker punches to 125 % with a white flash ring, the strip lights gold from '
               'Multipack to this Milk and +€42 pops on the rail, the halo steps up a ring and the ticket\'s burst rolls up. Then it '
               'settles, with a small check on the sticker that has paid. #60\'s flying tokens and dimmed markers are retired.</div>')
    out.append('<div class="row">' + "".join(f'<div class="cell">{item_beat(p)}<div class="cap"><b>{t}</b></div></div>'
                                              for p, t in (("before", "before: as in planning"), ("fire", "fire: the step lands"),
                                                           ("after", "after: settled, paid"))) + '</div>')
    out.append('<h2>Q3 · Count-up monitor</h2><div class="note">Left: the 3rd Milk\'s ×3 lands (€23 › €65, not there yet). Right: the '
               'last Milk\'s +€12 loyalty lands (€65 › €77): the quota ding. The monitor is the game\'s 424 × 176.</div>')
    for key, title, fn, rec, desc in mons:
        out.append(f'<div class="row"><div class="cell"><div class="{"rec" if rec else ""}" style="display:flex;gap:16px">{fn(False)}{fn(True)}</div></div>'
                   f'<div class="cell" style="width:330px"><div class="cap" style="font-size:15px"><b>{key} · {title}</b></div>'
                   f'<div class="note" style="font-size:13px">{desc}</div></div></div>')
    out.append('<h2>Q4 · Quota gauge (top bar)</h2><div class="note">Four states, in planning and live during the count. Shown with '
               '"SPEND €73+" as the name; Q5 picks the name.</div>')
    for key, title, fn, rec, desc in gauges:
        cells = "".join(f'<div class="cell">{fn(s)}<div class="cap">{c}</div></div>' for s, c in states[:2])
        cells2 = "".join(f'<div class="cell">{fn(s)}<div class="cap">{c}</div></div>' for s, c in states[2:])
        out.append(f'<div class="cap" style="font-size:15px;margin-top:14px"><b>{key} · {title}</b></div><div class="note" style="font-size:13px">{desc}</div>'
                   f'<div class="{"rec" if rec else ""}" style="display:grid;grid-template-columns:520px 520px;gap:8px 20px;margin-top:6px;width:1060px">{cells}{cells2}</div>')
    names = ["SPEND €73+", "MIN. SPEND €73", "TARGET €73", "GOAL €73", "TILL GOAL €73", "SALES GOAL €73"]
    out.append('<h2>Q5 · The name players see</h2><div class="note">Only player text changes; code and data keep <i>quota</i>. "Budget" '
               'was dropped: it reads as a maximum. Shown on GB at €70 (almost there).</div>')
    out.append('<div style="display:grid;grid-template-columns:520px 520px;gap:8px 20px;margin-top:8px">'
               + "".join(f'<div class="cell">{gauge_b("close", n)}<div class="cap">{n}</div></div>' for n in names) + '</div>')
    return ('<!doctype html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>Count-up gauge board</title>\n<style>' + FONTS + PARTS_CSS
            + '</style>\n</head>\n<body>\n' + "\n".join(out) + '\n</body>\n</html>\n')


# ---------------------------------------------------------------- the scene: h1 at the quota ding, MA + GB

RECEIPT_COUNT = '''<div class="abs receipt">
    <div class="h">NEXT CUSTOMER · REG 3</div>
    <div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>
    <div class="dash"></div>
    <div class="ln"><span class="nm">Eggs</span><span>€1.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Bread</span><span>€10.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Milk</span><span>€0.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Multipack</span><span>€0.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Milk</span><span>€21.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Milk</span><span>€24.00</span><span class="pl"></span></div>
    <div class="ln"><span class="nm">Milk</span><span>€4.00</span><span class="pl"></span></div>
    <div class="ln" style="padding-left:12px;font-size:12px"><span class="nm">+ own rule</span><span>+€5</span><span class="pl"></span></div>
    <div class="ln" style="padding-left:12px;font-size:12px;background:var(--mustard-pale)"><span class="nm">+ loyalty</span><span>+€12</span><span class="pl"></span></div>
  </div>'''


def scene():
    base = (MOCKUPS / "planning_effects_h1.html").read_text(encoding="utf-8")

    def sub(s, old, new):
        if old not in s:
            sys.exit("missing: " + old[:90])
        return s.replace(old, new, 1)

    s = re.sub(r"<title>[^<]*</title>", "<title>Count-up quota ding</title>", base, count=1)
    s = sub(s, "</title>\n", "</title>\n<!--\n  #86 decide mock-up (2026-10-19): planning_effects_h1.html at the quota ding of the count-up (the last Milk's +€12 "
            "loyalty lands, €65 › €77), with monitor MA and gauge GB, built by count_up_86_src/gen.py. The rail strip's factor badges "
            "are gone (the #71 play test). Item-level beats (sticker punch, strip lighting) are on count_up_86_board.html.\n-->\n")
    s = sub(s, "</style>", PARTS_CSS.split("/* ---- board layout ---- */")[0].replace(".bar {", ".bar_unused {").replace(".chip {", ".chip_unused {")
            + "\n:root { --good-dark: #3f7d3b; --mustard-dark: #b38425; }\n.fb { display: none !important; }\n.key.off { filter: saturate(.45) brightness(.78); }\n"
            ".monitor .scr { border-radius: 2px; }\n"
            ".monitor .stamp86 { color: var(--good-dark) !important; border-color: var(--good-dark) !important; outline-color: var(--good-dark) !important; }\n</style>")
    gb = gauge_b("met", w=190)
    inner = re.search(r'<div class="chip">(.*)</div></div>$', gb).group(1)
    s = re.sub(r'<div class="chip" style="flex:1">.*?€182</span></div>',
               lambda m: '<div class="chip" style="flex:1;gap:8px"><span class="k">SPEND €73+</span>'
               + inner.split('<span class="k">SPEND €73+</span>', 1)[1].replace('€182 ›', '€77') + '</div>', s, count=1, flags=re.S)
    mon = mon_a(True)
    s = re.sub(r'<div class="abs monitor"><div class="screen brief">.*?\n  </div></div>\n',
               lambda m: '<div class="abs monitor" style="padding:0;background:none;border:0">' + mon.replace('<div class="mon">', '<div class="mon" style="width:424px;height:176px">', 1) + '</div>\n',
               s, count=1, flags=re.S)
    s = re.sub(r'<div class="abs receipt">.*?\n  </div>\n', lambda m: RECEIPT_COUNT + "\n", s, count=1, flags=re.S)
    s = sub(s, '<div class="abs key checkout">', '<div class="abs key checkout off">')
    s = sub(s, '<div class="abs key redraw">', '<div class="abs key redraw off">')
    s = sub(s, "const lg = document.getElementById('legend');", "const lg = document.getElementById('legend') || document.createElement('div');")
    return s


(MOCKUPS / "count_up_86_board.html").write_text(board(), encoding="utf-8")
(MOCKUPS / "count_up_86_scene.html").write_text(scene(), encoding="utf-8")
print("wrote count_up_86_board.html and count_up_86_scene.html")
