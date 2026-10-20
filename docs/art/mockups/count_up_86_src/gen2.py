"""Round 2 of the #86 decide mock-ups (2026-10-19): count_up_86_v2_board.html in docs/art/mockups.

The user's round-1 answers: keep MA's landing stickers and SPEND MET stamp, but the monitor needs more juice (the number felt
alone; the coin tube "isn't bad", a gauge may be the better picture). The top-bar gauges weren't alive enough, and GB's flag only
works once the quota is met: before that the bar must fill to the end at the quota. Name: SPEND €73+.

The page is animated (CSS keyframes): open it in a browser to see the motion; the capture is one frame of it.
Standard library only. Run: python docs/art/mockups/count_up_86_src/gen2.py
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
HERE = pathlib.Path(__file__).parent
MOCKUPS = HERE.parent

# reuse round 1's fonts, palette and sticker parts
_src = (HERE / "gen.py").read_text(encoding="utf-8")
_ns = {"__file__": str(HERE / "gen.py"), "__name__": "gen_parts"}
exec(compile(_src.split("(MOCKUPS / \"count_up_86_board.html\")")[0], "gen.py", "exec"), _ns)
FONTS, PARTS_CSS, MILK = _ns["FONTS"], _ns["PARTS_CSS"], _ns["MILK"]

CSS = """
/* ---- motion (open the page to see it; reduced motion keeps the end states) ---- */
@keyframes shine { 0% { transform: translateX(-60px) skewX(-20deg); } 70%, 100% { transform: translateX(560px) skewX(-20deg); } }
@keyframes wobble { 0%, 100% { transform: rotate(-10deg) translateY(0); } 50% { transform: rotate(10deg) translateY(-3px); } }
@keyframes drop { 0% { transform: translateY(-46px); opacity: 0; } 15% { opacity: 1; } 60% { transform: translateY(0); } 72% { transform: translateY(-6px); } 84%, 100% { transform: translateY(0); } }
@keyframes pulse { 0%, 100% { box-shadow: 0 0 0 2px var(--ink), 0 0 0 4px rgba(241,210,122,0); } 50% { box-shadow: 0 0 0 2px var(--ink), 0 0 0 6px rgba(241,210,122,.9); } }
@keyframes spin { to { transform: rotate(360deg); } }
@keyframes twinkle { 0%, 100% { opacity: 0; transform: scale(.4); } 40%, 60% { opacity: 1; transform: scale(1); } }
@keyframes bob { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-3px); } }
@keyframes slam { 0% { transform: rotate(-8deg) scale(2.2); opacity: 0; } 35% { transform: rotate(-8deg) scale(.92); opacity: 1; } 50%, 100% { transform: rotate(-8deg) scale(1); } }
@keyframes punch { 0%, 100% { transform: scale(1); } 20% { transform: scale(1.12); } }
@keyframes bubble { 0% { transform: translateY(8px); opacity: 0; } 30% { opacity: .9; } 100% { transform: translateY(-14px); opacity: 0; } }
@keyframes flap { 0%, 100% { transform: skewY(0deg); } 50% { transform: skewY(-6deg); } }
@keyframes spill { 0% { transform: translate(0, 0) rotate(0); } 100% { transform: translate(var(--dx), var(--dy)) rotate(var(--r)); } }

/* ---- pixel coin: a gold disc with an ink rim, a light top-left and a dark lower band ---- */
.coin { position: absolute; width: 22px; height: 22px; border-radius: 50%; background: var(--mustard); border: 2px solid var(--ink);
  box-shadow: inset 3px 3px 0 var(--mustard-light), inset -3px -3px 0 var(--mustard-dark); }
.coin::after { content: "€"; position: absolute; inset: 0; display: grid; place-items: center; font: 800 11px Atkinson; color: var(--mustard-dark); }
.coin.edge { height: 9px; border-radius: 4px; box-shadow: inset 0 2px 0 var(--mustard-light), inset 0 -2px 0 var(--mustard-dark); }
.coin.edge::after { content: none; }
.coin.bright { background: var(--mustard-light); box-shadow: inset 3px 3px 0 var(--paper), inset -3px -3px 0 var(--mustard); }
.coin.edge.bright { box-shadow: inset 0 2px 0 var(--paper), inset 0 -2px 0 var(--mustard); }
.twk { position: absolute; width: 12px; height: 12px; animation: twinkle 1.6s infinite; background:
  linear-gradient(var(--paper), var(--paper)) 5px 0 / 2px 12px no-repeat, linear-gradient(var(--paper), var(--paper)) 0 5px / 12px 2px no-repeat; }
.twk.g { background: linear-gradient(var(--mustard-light), var(--mustard-light)) 5px 0 / 2px 12px no-repeat,
  linear-gradient(var(--mustard-light), var(--mustard-light)) 0 5px / 12px 2px no-repeat; }
/* stepped sunburst behind the subtotal (two rings of hard rays, no blur) */
.rays { position: absolute; border-radius: 50%; background: repeating-conic-gradient(var(--c1) 0 10deg, var(--c2) 10deg 20deg); animation: spin 24s linear infinite; }
.shinebar { position: absolute; top: 0; bottom: 0; width: 18px; background: rgba(255,255,255,.55); animation: shine 2.4s infinite; }
.lab86, .star86 { }
.stamp86.slam { animation: slam .6s ease-out both; }
"""


def screen_bg(progress, met):
    """The screen's ground warms with progress: cream, then mustard-pale near the quota, then gold rays once met."""
    if met:
        return "var(--mustard-pale)"
    return "var(--paper)" if progress < .8 else "#fbf1d0"


def number_block(value, met, left=104, top=18, size=74):
    """The subtotal on a slow stepped sunburst (pale while short, gold once met) so it never stands alone on the screen."""
    c1, c2 = ("#f1d27a", "#faecbc") if met else ("#f3e9d2", "#fbf7ee")
    return (f'<div class="rays" style="--c1:{c1};--c2:{c2};left:{left + 10}px;top:{top - 60}px;width:200px;height:200px;opacity:{1 if met else .9}"></div>'
            f'<div class="big86" style="position:absolute;left:{left}px;top:{top}px;font-size:{size}px;line-height:{size}px;'
            f'text-shadow:4px 4px 0 {"#e2b33c" if met else "#f1d27a"};animation:punch .9s infinite">{value}</div>')


def landing(met, left=290, top=22):
    if met:
        return f'<span class="lab86" style="position:absolute;left:{left + 4}px;top:{top + 8}px;height:44px;padding:0 10px;font-size:28px;transform:rotate(6deg)">+12</span>'
    return f'<span class="star86" style="position:absolute;left:{left}px;top:{top - 6}px;width:78px;height:78px;font-size:28px;transform:rotate(-8deg)"><i></i><b>×3</b></span>'


def art(met):
    return (f'<div class="art"><img class="px" src="{MILK}" style="animation:bob 1.2s infinite"><div class="k">MILK {"7" if met else "6"} / 7</div></div>')


def stamp(left, top, size=18):
    return (f'<span class="stamp86 slam" style="position:absolute;left:{left}px;top:{top}px;color:var(--good-dark);font-size:{size}px;line-height:{size}px;z-index:5">SPEND MET ✓</span>')


# ------------------------------------------------------------------ monitors (424 x 176)

def m1(state):
    """M1, coin rail: under the subtotal a glass tray of 10 coin slots, one per 10 % of the quota. Each gain drops coins into the
    next slots (they bounce); the slot that would finish the quota wobbles; "€8 to go" hangs over it. At the quota the coins
    flip bright, the SPEND MET stamp slams across the tray and coins spill out past its end."""
    met = state == "met"
    v = {"beat": "€65", "met": "€77"}[state]
    filled = 10 if met else 8
    slots = ""
    for i in range(10):
        x = 4 + i * 27
        if i < filled:
            anim = "animation:drop 1.4s both;animation-delay:%.2fs;" % (0.08 * (i - 6)) if (not met and i >= 6) else ""
            slots += f'<span class="coin{" bright" if met else ""}" style="left:{x}px;top:4px;{anim}"></span>'
        elif i == filled:
            slots += f'<span class="coin" style="left:{x}px;top:4px;opacity:.35;animation:wobble .5s infinite"></span>'
        else:
            slots += f'<span style="position:absolute;left:{x + 4}px;top:8px;width:14px;height:14px;border-radius:50%;border:2px dashed #b8ab90"></span>'
    spill = ""
    if met:
        for k, (dx, dy, r) in enumerate(((24, -18, 40), (40, 6, -30), (16, 12, 80))):
            spill += f'<span class="coin bright" style="left:{272 + k * 6}px;top:4px;--dx:{dx}px;--dy:{dy}px;--r:{r}deg;animation:spill .7s ease-out both"></span>'
    tray = (f'<div style="position:absolute;left:104px;top:116px;width:278px;height:34px;background:rgba(255,255,255,.55);border:3px solid var(--ink);'
            f'box-shadow:inset 0 -6px 0 rgba(43,36,32,.12)">{slots}{spill}'
            f'<span class="shinebar"></span></div>')
    togo = ('' if met else '<span class="togo86 short" style="position:absolute;left:304px;top:92px;animation:bob .8s infinite">€8 to go</span>')
    spark = ('<span class="twk g" style="left:112px;top:8px"></span><span class="twk g" style="left:250px;top:84px;animation-delay:.5s"></span>'
             '<span class="twk" style="left:380px;top:110px;animation-delay:.9s"></span>' if met else '')
    return (f'<div class="mon"><div class="scr" style="background:{screen_bg(.89, met)}">{number_block(v, met)}{art(met)}{landing(met)}'
            f'<div class="lbl" style="position:absolute;left:108px;top:4px;z-index:2">SUBTOTAL</div>{tray}{togo}'
            f'{stamp(150, 112) if met else ""}{spark}</div></div>')


def m2(state):
    """M2, live fill: a thick glass gauge under the subtotal: a mustard fill with a light band, bubbles rising and a shine
    sweeping along, ticks every 10 %, and the price-gun tag riding its edge. Near the quota the gauge pulses and the screen
    warms; at the quota it flashes, fills gold to the end and the stamp slams over it."""
    met = state == "met"
    v = {"beat": "€65", "met": "€77"}[state]
    pct = 100 if met else 89
    w = 272
    fillw = int(w * pct / 100)
    ticks = "".join(f'<i style="position:absolute;left:{int(w * k / 10)}px;top:0;width:2px;height:6px;background:var(--ink);opacity:.5"></i>' for k in range(1, 10))
    bubbles = "".join(f'<i style="position:absolute;left:{x}px;bottom:2px;width:5px;height:5px;border-radius:50%;background:var(--paper);'
                      f'animation:bubble 1.3s infinite;animation-delay:{d}s"></i>' for x, d in ((30, 0), (90, .4), (150, .8), (210, .2), (240, 1)))
    fill = (f'<div style="position:absolute;left:0;top:0;bottom:0;width:{fillw}px;overflow:hidden;background:{"var(--mustard-light)" if met else "var(--mustard)"};'
            f'box-shadow:inset 0 5px 0 {"var(--paper)" if met else "var(--mustard-light)"}, inset 0 -5px 0 var(--mustard-dark)">{bubbles}<span class="shinebar"></span></div>')
    tag = ('' if met else '<span class="togo86 short" style="position:absolute;left:226px;top:-26px;animation:bob .8s infinite">€8 to go</span>')
    gauge = (f'<div style="position:absolute;left:106px;top:114px;width:{w + 6}px;height:30px;background:#e9e1cd;border:3px solid var(--ink);'
             f'{"" if met else "animation:pulse 1s infinite;"}">{fill}{ticks}{tag}</div>')
    spark = ('<span class="twk g" style="left:112px;top:8px"></span><span class="twk g" style="left:250px;top:84px;animation-delay:.5s"></span>'
             '<span class="twk" style="left:372px;top:112px;animation-delay:.9s"></span>' if met else '')
    return (f'<div class="mon"><div class="scr" style="background:{screen_bg(.89, met)}">{number_block(v, met)}{art(met)}{landing(met)}'
            f'<div class="lbl" style="position:absolute;left:108px;top:4px;z-index:2">SUBTOTAL</div>{gauge}'
            f'{stamp(150, 112) if met else ""}{spark}</div></div>')


def m3(state):
    """M3, coin tube: MC refined. A wide glass tube on the right fills with coins (edge-on) toward the €73 mark at its top;
    the next coins drop in and bounce. The subtotal sits on its sunburst at the left, the landing sticker under it. At the quota
    the top coin pops out of the tube in a burst of sparkle and the stamp slams across the screen."""
    met = state == "met"
    v = {"beat": "€65", "met": "€77"}[state]
    n = 12 if met else 10
    coins = "".join(f'<span class="coin edge{" bright" if met else ""}" style="left:3px;width:44px;top:{134 - 11 * k}px;'
                    f'{"animation:drop 1.4s both;animation-delay:%.2fs;" % (0.1 * (k - 8)) if (not met and k >= 8) else ""}"></span>' for k in range(n))
    pop = ('<span class="coin bright" style="left:12px;top:-30px;--dx:-26px;--dy:-10px;--r:-60deg;animation:spill .8s ease-out both"></span>' if met else '')
    tube = (f'<div style="position:absolute;right:16px;top:8px;width:56px;height:150px;background:rgba(233,225,205,.8);border:3px solid var(--ink);border-top:0;'
            f'box-shadow:inset 8px 0 0 rgba(255,255,255,.6)">{coins}{pop}'
            f'<div style="position:absolute;left:-14px;right:-14px;top:4px;border-top:3px dashed {"var(--good-dark)" if met else "var(--tomato-dark)"}"></div></div>'
            f'<div style="position:absolute;right:88px;top:4px;font-weight:800;font-size:13px;color:{"var(--good-dark)" if met else "var(--tomato-dark)"}">{"✓ €73" if met else "€73"}</div>')
    lab = (('<span class="lab86" style="position:absolute;left:112px;top:104px;height:34px;padding:0 8px;font-size:22px;transform:rotate(4deg)">+12</span>') if met else
           ('<span class="star86" style="position:absolute;left:110px;top:94px;width:66px;height:66px;font-size:22px;transform:rotate(-8deg)"><i></i><b>×3</b></span>'
            '<span class="togo86 short" style="position:absolute;left:190px;top:122px;animation:bob .8s infinite">€8 to go</span>'))
    spark = ('<span class="twk g" style="left:300px;top:14px"></span><span class="twk g" style="left:390px;top:30px;animation-delay:.5s"></span>' if met else '')
    return (f'<div class="mon"><div class="scr" style="background:{screen_bg(.89, met)}">{number_block(v, met, size=64)}{art(met)}{lab}'
            f'<div class="lbl" style="position:absolute;left:108px;top:4px;z-index:2">SUBTOTAL</div>{tube}'
            f'{stamp(176, 64, 16) if met else ""}{spark}</div></div>')


# ------------------------------------------------------------------ top-bar gauges (the chip; 520 wide here, 396 in the game)
# States: short 52 / close 70 / met 77 (just over) / big 182 / drag 52 › 58. Every gauge fills to its END at the quota; what
# lies past the quota only appears once it is met.

STATES = [("short", "planning: €52 of €73"), ("close", "planning: €70, almost"), ("met", "met: €77"), ("big", "met big: €182"), ("drag", "drag: €52 › €58")]
TOTAL = {"short": 52, "close": 70, "met": 77, "big": 182, "drag": 52}


def chip(inner, glow=False):
    return (f'<div class="bar"><div class="chip" style="{"animation:pulse 1s infinite;" if glow else ""}"><span class="k">SPEND €73+</span>{inner}</div></div>')


def t1(state):
    """T1, coin slots: the bar is 10 coin slots, each 10 % of the quota. Coins drop in and bounce as the total rises; the next
    slot wobbles; from 80 % the chip glows. At the quota every coin flips bright, a gold flag pops up at the end, and anything
    over shows as a "+€N over" ribbon off the flag."""
    t = TOTAL[state]
    met = t >= 73
    n = 10 if met else t * 10 // 73
    gn = 58 * 10 // 73 if state == "drag" else n
    slots = ""
    for i in range(10):
        x = 2 + i * 24
        if i < n:
            slots += f'<span class="coin{" bright" if met else ""}" style="left:{x}px;top:1px;width:20px;height:20px"></span>'
        elif i < gn:
            slots += f'<span class="coin" style="left:{x}px;top:1px;width:20px;height:20px;opacity:.45;outline:2px dashed var(--mustard-light)"></span>'
        elif i == gn:
            slots += f'<span class="coin" style="left:{x}px;top:1px;width:20px;height:20px;opacity:.3;animation:wobble .5s infinite"></span>'
        else:
            slots += f'<span style="position:absolute;left:{x + 4}px;top:5px;width:12px;height:12px;border-radius:50%;border:2px dashed #6d8f8b"></span>'
    flag = ('<span style="position:absolute;left:238px;top:-14px;width:3px;height:36px;background:var(--paper);border:1px solid var(--ink)"></span>'
            '<span style="position:absolute;left:241px;top:-14px;padding:0 5px;height:16px;font:800 11px/14px Atkinson;background:var(--good);color:var(--paper);'
            'border:1px solid var(--ink);animation:flap .8s infinite;transform-origin:left">✓</span>' if met else '')
    over = (f'<span class="togo86" style="background:var(--mustard);margin-left:10px">+€{t - 73} over</span>' if met else
            (f'<span class="togo86 short">€{73 - 58} to go</span>' if state == "drag" else
             f'<span class="togo86{" short" if t < 70 else ""}">€{73 - t} to go</span>'))
    twk = ('<span class="twk" style="left:60px;top:-8px"></span><span class="twk g" style="left:180px;top:10px;animation-delay:.6s"></span>' if met else '')
    inner = (f'<span style="position:relative;flex:none;width:244px;height:24px;background:rgba(0,0,0,.25);border:2px solid var(--ink)">{slots}{flag}'
             f'{twk}</span>{over}')
    return chip(inner, glow=(not met and t / 73 >= .8))


def t2(state):
    """T2, live fill: a glass bar that fills to its end at the quota: bubbles rise in the fill, a shine sweeps along it, a tick
    every 10 %, and a "to go" tag rides the fill's edge. From 80 % it pulses. At the quota the bar flashes and turns gold with a
    flag at the end; past it a second, brighter lap fills over the gold (x1.5 at €110, full at x2) and a "×N" badge counts laps."""
    t = TOTAL[state]
    met = t >= 73
    w = 300
    pct = min(1, t / 73)
    fw = int(w * pct)
    lap = min(1, max(0, (t - 73) / 73)) if met else 0
    bubbles = "".join(f'<i style="position:absolute;left:{x}px;bottom:1px;width:4px;height:4px;border-radius:50%;background:var(--paper);animation:bubble 1.3s infinite;animation-delay:{d}s"></i>'
                      for x, d in ((20, 0), (70, .5), (120, .9), (170, .3), (220, .7)) if x < fw)
    ghost = ""
    if state == "drag":
        gw = int(w * 58 / 73)
        ghost = f'<i style="position:absolute;left:{fw}px;top:0;bottom:0;width:{gw - fw}px;background:repeating-linear-gradient(90deg,var(--mustard) 0 4px,transparent 4px 7px)"></i>'
    ticks = "".join(f'<i style="position:absolute;left:{int(w * k / 10)}px;top:0;width:2px;height:5px;background:var(--ink);opacity:.6"></i>' for k in range(1, 10))
    lapbar = (f'<i style="position:absolute;left:0;top:0;bottom:0;width:{int(w * lap)}px;background:var(--paper);opacity:.55"></i>' if lap else '')
    flag = ('<span style="position:absolute;right:-6px;top:-14px;width:3px;height:34px;background:var(--paper);border:1px solid var(--ink)"></span>'
            '<span style="position:absolute;right:-26px;top:-14px;padding:0 4px;height:16px;font:800 11px/14px Atkinson;background:var(--good);color:var(--paper);'
            'border:1px solid var(--ink);animation:flap .8s infinite">✓</span>' if met else '')
    fill = (f'<i style="position:absolute;left:0;top:0;bottom:0;width:{fw}px;overflow:hidden;background:{"var(--mustard-light)" if met else "var(--mustard)"};'
            f'box-shadow:inset 0 3px 0 {"var(--paper)" if met else "var(--mustard-light)"}">{bubbles}<span class="shinebar"></span></i>')
    right = ((f'<span class="togo86" style="background:var(--mustard);margin-left:22px">×{t / 73:.1f}</span>' if t >= 110 else
              f'<span class="togo86" style="background:var(--mustard);margin-left:22px">+€{t - 73}</span>') if met else
             (f'<span class="togo86 short">€15 to go</span>' if state == "drag" else f'<span class="togo86{" short" if t < 70 else ""}">€{73 - t} to go</span>'))
    inner = (f'<span style="position:relative;flex:none;width:{w + 4}px;height:20px;background:rgba(0,0,0,.3);border:2px solid var(--ink)">'
             f'{fill}{lapbar}{ghost}{ticks}{flag}</span>{right}')
    return chip(inner, glow=(not met and t / 73 >= .8))


def t3(state):
    """T3, shopping bag: a paper bag icon at the start of the bar fills with produce as the total rises (it bulges at 80 %); the
    bar fills to the end at the quota with the price-gun tag riding its edge. At the quota the bag pops a gold check, the bar
    goes gold and a flag rises at the end; past it the tag reads the total and "+€N" while the bag overflows."""
    t = TOTAL[state]
    met = t >= 73
    w = 250
    fw = int(w * min(1, t / 73))
    # the bag: cream paper, ink outline, a fill level of mustard "produce"
    level = min(1, t / 73)
    bag = (f'<span style="position:relative;flex:none;width:30px;height:32px;margin-top:-4px;{"animation:bob .6s infinite;" if t / 73 >= .8 else ""}">'
           f'<span style="position:absolute;left:2px;right:2px;bottom:0;height:24px;background:var(--cream);border:2px solid var(--ink);'
           f'border-radius:0 0 3px 3px;overflow:hidden"><i style="position:absolute;left:0;right:0;bottom:0;height:{int(22 * level)}px;background:var(--good)"></i>'
           f'<i style="position:absolute;left:3px;right:3px;bottom:{int(22 * level) - 4}px;height:6px;background:var(--tomato);border-radius:3px;{"" if level > .3 else "display:none"}"></i></span>'
           f'{"<span class=okdisc86 style=position:absolute;right:-8px;top:-6px;width:16px;height:16px;font-size:10px>✓</span>" if met else ""}'
           f'{"<span class=coin style=left:12px;top:-12px;width:12px;height:12px></span>" if t > 110 else ""}</span>')
    tag_txt = f"€{t}" if state != "drag" else "€58"
    tag_x = fw if state != "drag" else int(w * 58 / 73)
    flag = ('<span style="position:absolute;right:-4px;top:-14px;width:3px;height:32px;background:var(--paper);border:1px solid var(--ink)"></span>' if met else '')
    tag = (f'<span style="position:absolute;left:{min(tag_x, w) - 18}px;top:14px;padding:0 4px;height:16px;font:800 11px/13px Atkinson;'
           f'background:{"var(--mustard)" if met else "var(--paper)"};color:var(--ink);border:2px solid var(--ink);white-space:nowrap;z-index:2">{tag_txt}{" ›" if t > 73 else ""}</span>')
    fill = (f'<i style="position:absolute;left:0;top:0;bottom:0;width:{fw}px;overflow:hidden;background:{"var(--mustard-light)" if met else "var(--mustard)"};'
            f'box-shadow:inset 0 3px 0 {"var(--paper)" if met else "var(--mustard-light)"}"><span class="shinebar"></span></i>')
    right = ((f'<span class="togo86" style="background:var(--mustard);margin-left:6px">+€{t - 73}</span>') if met else
             (f'<span class="togo86 short">€15 to go</span>' if state == "drag" else f'<span class="togo86{" short" if t < 70 else ""}">€{73 - t} to go</span>'))
    inner = (f'{bag}<span style="position:relative;flex:none;width:{w + 4}px;height:16px;margin-top:-10px;background:rgba(0,0,0,.3);border:2px solid var(--ink)">'
             f'{fill}{flag}{tag}</span>{right}')
    return chip(inner, glow=(not met and t / 73 >= .8))


def board():
    mons = [("M1", "Coin rail", m1, True,
             "MA's stickers and stamp on a warmer screen: the subtotal sits on a slow pixel sunburst and punches on each gain. Under it a "
             "glass tray of 10 coin slots (10 % of the quota each): coins drop in and bounce, the slot that would finish wobbles, "
             "\"€8 to go\" hangs over it. At the quota the coins flip bright, SPEND MET slams across the tray and coins spill out."),
            ("M2", "Live fill", m2, False,
             "Same top half. Under it a thick glass gauge: bubbles rise in the fill, a shine sweeps along, a tick every 10 %, the total "
             "on a tag at its edge. From 80 % the gauge pulses and the screen warms. At the quota it flashes gold and the stamp slams."),
            ("M3", "Coin tube", m3, False,
             "MC refined: a wide tube on the right fills coin by coin to the €73 mark; the subtotal on its sunburst at the left with the "
             "landing sticker under it. At the quota the top coin pops out in a burst. The tallest \"how close\", the least room for the number.")]
    gauges = [("T1", "Coin slots", t1, True,
               "10 coin slots fill to the end at the quota; coins drop and bounce, the next slot wobbles, the chip glows from 80 %. At the "
               "quota the coins flip bright, a flag pops up at the end and \"+€N over\" hangs off it."),
              ("T2", "Live fill", t2, False,
               "A glass bar with bubbles and a sweeping shine, ticks every 10 %, filling to the end at the quota; pulses from 80 %. Met: "
               "gold with a flag; past it a brighter second lap fills over the gold and a ×N badge counts laps (×2.5 at €182)."),
              ("T3", "Shopping bag", t3, False,
               "A paper bag at the start fills with produce as the bar fills; it bulges at 80 %. Met: the bag pops a check, the bar goes "
               "gold, a flag rises at the end, and the tag reads the total with \"+€N\".")]
    out = ['<h1>#86 round 2: a livelier monitor and gauge<small>2026-10-19 · open the page in a browser to see the motion · '
           'kept: MA\'s landing stickers and stamp, SPEND €73+ · gold outline = recommended</small></h1>']
    out.append('<h2>Count-up monitor</h2><div class="note">Left: the 3rd Milk\'s ×3 lands (€65, €8 to go). Right: the last Milk\'s '
               '+12 loyalty lands: the quota ding. Game size, 424 × 176.</div>')
    for key, title, fn, rec, desc in mons:
        out.append(f'<div class="row"><div class="{"rec" if rec else ""}" style="display:flex;gap:16px">{fn("beat")}{fn("met")}</div>'
                   f'<div class="cell" style="width:330px"><div class="cap" style="font-size:15px"><b>{key} · {title}</b></div>'
                   f'<div class="note" style="font-size:13px">{desc}</div></div></div>')
    out.append('<h2>Top-bar gauge</h2><div class="note">Every gauge is full at the quota; the flag and what\'s over only appear once '
               'it\'s met. Five states: short, almost, just met, met big, and a drag.</div>')
    for key, title, fn, rec, desc in gauges:
        cells = "".join(f'<div class="cell">{fn(s)}<div class="cap">{c}</div></div>' for s, c in STATES)
        out.append(f'<div class="cap" style="font-size:15px;margin-top:14px"><b>{key} · {title}</b></div><div class="note" style="font-size:13px">{desc}</div>'
                   f'<div class="{"rec" if rec else ""}" style="display:grid;grid-template-columns:520px 520px;gap:14px 20px;margin-top:10px;width:1060px">{cells}</div>')
    return ('<!doctype html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>Count-up gauge round 2</title>\n<style>' + FONTS + PARTS_CSS + CSS
            + '</style>\n</head>\n<body>\n' + "\n".join(out) + '\n</body>\n</html>\n')


(MOCKUPS / "count_up_86_v2_board.html").write_text(board(), encoding="utf-8")
print("wrote count_up_86_v2_board.html")
