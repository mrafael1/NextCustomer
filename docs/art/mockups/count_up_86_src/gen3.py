"""Round 3 of the #86 decide mock-ups (2026-10-19): count_up_86_v3_board.html in docs/art/mockups.

The user's round-2 answers: coins are the better idea but feel flat; M2's live fill is close. The flag must ANCHOR the quota once
it is met and the gauge carries on past it (a flag sitting at the bar's end is weird).

So here:
- Coins have depth: a 3/4 view coin is a top ellipse (lit rim, embossed €) over a ridged edge band, and they stack.
- Every gauge is full at the quota while short. At the quota a flag is planted on that spot; from then on the gauge re-scales to
  the total, so the flag slides back to quota / total of the way and the stretch past it fills with bright coins (or bright fill).

Animated: open the page in a browser to see the motion; the capture is one frame. In the game the coins are pixel sprites.
Standard library only. Run: python docs/art/mockups/count_up_86_src/gen3.py
"""
import pathlib

HERE = pathlib.Path(__file__).parent
MOCKUPS = HERE.parent
_src = (HERE / "gen.py").read_text(encoding="utf-8")
_ns = {"__file__": str(HERE / "gen.py"), "__name__": "gen_parts"}
exec(compile(_src.split("(MOCKUPS / \"count_up_86_board.html\")")[0], "gen.py", "exec"), _ns)
FONTS, PARTS_CSS, MILK = _ns["FONTS"], _ns["PARTS_CSS"], _ns["MILK"]
_src2 = (HERE / "gen2.py").read_text(encoding="utf-8")
CSS2 = _src2.split('CSS = """', 1)[1].split('"""', 1)[0]

CSS3 = """
/* ---- 3/4-view coins: a ridged edge band under a lit top ellipse; stacks of them ---- */
.cs { position: absolute; }
.cs .ed { position: absolute; left: 0; right: 0; border: 2px solid var(--ink); border-top: 0;
  background: repeating-linear-gradient(90deg, var(--mustard-dark) 0 2px, var(--mustard) 2px 4px); }
.cs .tp { position: absolute; left: 0; right: 0; border: 2px solid var(--ink); border-radius: 50%;
  background: radial-gradient(ellipse at 38% 35%, var(--mustard-pale) 0 18%, var(--mustard-light) 19% 40%, var(--mustard) 41% 70%, var(--mustard-dark) 71%); }
.cs .tp::after { content: "€"; position: absolute; inset: 0; display: grid; place-items: center; font: 800 9px Atkinson; color: var(--mustard-dark); }
.cs.br .ed { background: repeating-linear-gradient(90deg, var(--mustard) 0 2px, var(--mustard-light) 2px 4px); }
.cs.br .tp { background: radial-gradient(ellipse at 38% 35%, var(--paper) 0 24%, var(--mustard-pale) 25% 50%, var(--mustard-light) 51% 75%, var(--mustard) 76%); }
.cs.gh { opacity: .45; }
.cs.gh .ed, .cs.gh .tp { border-style: dashed; }
.cs .glint { position: absolute; width: 6px; height: 6px; background: var(--paper); animation: twinkle 1.4s infinite; }
@keyframes land { 0% { transform: translateY(-40px); } 55% { transform: translateY(0); } 70% { transform: translateY(-5px); } 82%, 100% { transform: translateY(0); } }
@keyframes plant { 0% { transform: translateY(-30px) rotate(-20deg); opacity: 0; } 50% { transform: translateY(2px) rotate(4deg); opacity: 1; } 100% { transform: none; } }
.flag { position: absolute; animation: plant .7s ease-out both; z-index: 4; }
.flag .pole { position: absolute; left: 0; top: 0; width: 4px; background: var(--paper); border: 1px solid var(--ink); }
.flag .cloth { position: absolute; left: 4px; background-clip: padding-box; top: 0; padding: 0 5px; font: 800 11px/14px Atkinson; color: var(--paper); background: var(--good);
  border: 2px solid var(--ink); white-space: nowrap; animation: flap .9s infinite; transform-origin: left; }
"""


def stack(x, bottom, n, w=22, t=5, bright=False, ghost=False, drop_top=False, glint=False):
    """n coins of width w and thickness t, the stack standing on y=bottom (top-left origin of the parent)."""
    e = w * 0.42  # the top ellipse's height
    parts = []
    for k in range(n):
        y = bottom - (k + 1) * t
        anim = "animation:land 1.4s both;" if (drop_top and k == n - 1) else ""
        parts.append(f'<i class="ed" style="top:{y - e / 2 + e / 2:.0f}px;height:{t + e / 2:.0f}px;border-radius:0 0 {w / 2:.0f}px {w / 2:.0f}px / 0 0 {e / 2:.0f}px {e / 2:.0f}px;{anim}"></i>')
        if k == n - 1:
            parts.append(f'<i class="tp" style="top:{y - e / 2:.0f}px;height:{e:.0f}px;{anim}"></i>')
    g = f'<i class="glint" style="left:{w * .3:.0f}px;top:{bottom - n * t - e / 2:.0f}px"></i>' if glint else ''
    return f'<span class="cs{" br" if bright else ""}{" gh" if ghost else ""}" style="left:{x}px;top:0;width:{w}px;height:{bottom}px">{"".join(parts)}{g}</span>'


def flag(x, top, h, text="✓ €73", flip=False):
    side = "right:0;left:auto;transform-origin:right" if flip else ""
    return f'<span class="flag" style="left:{x}px;top:{top}px"><span class="pole" style="height:{h}px"></span><span class="cloth" style="{side}">{text}</span></span>'


def columns(total, quota=73, cols=10):
    """Each column's value and the flag's place: while short, a column is quota / cols; once met the gauge re-scales to the
    total (a column is total / cols) and the flag stands quota / total of the way along."""
    met = total >= quota
    unit = (total if met else quota) / cols
    full = total / unit
    flag_at = quota / unit if met else None
    return met, unit, full, flag_at


# ------------------------------------------------------------------ monitor

def number_block(value, met, left=104, top=16, size=70):
    c1, c2 = ("#f1d27a", "#faecbc") if met else ("#f3e9d2", "#fbf7ee")
    return (f'<div class="rays" style="--c1:{c1};--c2:{c2};left:{left + 10}px;top:{top - 60}px;width:200px;height:200px"></div>'
            f'<div class="big86" style="position:absolute;left:{left}px;top:{top}px;font-size:{size}px;line-height:{size}px;'
            f'text-shadow:4px 4px 0 {"#e2b33c" if met else "#f1d27a"};animation:punch .9s infinite">{value}</div>')


def landing(state):
    if state == "beat":
        return '<span class="star86" style="position:absolute;left:292px;top:8px;width:74px;height:74px;font-size:26px;transform:rotate(-8deg)"><i></i><b>×3</b></span>'
    txt = "+12" if state == "met" else "+40"
    return f'<span class="lab86" style="position:absolute;left:300px;top:22px;height:40px;padding:0 10px;font-size:26px;transform:rotate(6deg)">{txt}</span>'


def mon_stacks(state):
    """M1 v3, coin stacks: a shallow tray seen from above the front, ten stack spots; each spot's stack grows to 4 coins as its
    tenth of the quota fills, the top coin lands with a bounce, the spot that finishes wobbles. At the quota a green flag is
    planted there and the tray re-scales to the total: the flag slides back and the stacks past it fill with bright coins."""
    total = {"beat": 65, "met": 77, "big": 117}[state]
    met, unit, full, flag_at = columns(total)
    tray_x, tray_w, floor = 104, 284, 156
    pitch = 27
    body = ""
    for i in range(10):
        n = 4 if i + 1 <= int(full) else (round((full - i) * 4) if i < full else 0)
        bright = met and flag_at is not None and i >= int(flag_at)
        if n:
            body += stack(4 + i * pitch, floor - 116, n, bright=bright, drop_top=(i == int(full) - 1 and not met), glint=(i == 2))
        else:
            body += f'<span style="position:absolute;left:{6 + i * pitch}px;top:{floor - 126}px;width:18px;height:8px;border-radius:50%;border:2px dashed #b8ab90"></span>'
    fl = flag(4 + flag_at * pitch - 3, -10, 44, f'✓ €73 · +€{total - 73}', flip=flag_at > 6) if met else ''
    togo = '' if met else '<span class="togo86 short" style="position:absolute;left:228px;top:-20px;animation:bob .8s infinite">€8 to go</span>'
    over = ''
    tray = (f'<div style="position:absolute;left:{tray_x}px;top:116px;width:{tray_w}px;height:44px">'
            f'<div style="position:absolute;left:-4px;right:-4px;top:16px;height:26px;background:linear-gradient(#e9e1cd,#d9cfba);border:3px solid var(--ink);'
            f'border-radius:4px;box-shadow:inset 0 4px 0 rgba(255,255,255,.6)"></div>{body}{fl}{togo}{over}</div>')
    stampx = ('<span class="stamp86 slam" style="position:absolute;left:150px;top:96px;color:var(--good-dark);font-size:16px;line-height:16px;z-index:5">SPEND MET ✓</span>'
              if state == "met" else '')
    spark = ('<span class="twk g" style="left:120px;top:10px"></span><span class="twk g" style="left:260px;top:86px;animation-delay:.5s"></span>' if met else '')
    v = f"€{total}"
    return (f'<div class="mon"><div class="scr" style="background:{"var(--mustard-pale)" if met else "#fbf1d0"}">{number_block(v, met)}'
            f'<div class="art"><img class="px" src="{MILK}" style="animation:bob 1.2s infinite"><div class="k">MILK {"7" if met else "6"} / 7</div></div>'
            f'{landing(state)}<div class="lbl" style="position:absolute;left:108px;top:4px;z-index:2">SUBTOTAL</div>{tray}{stampx}{spark}</div></div>')


def mon_fill(state):
    """M2 v3, live fill with the anchoring flag: M2's glass gauge (bubbles, shine, ticks, pulse from 80 %). At the quota the
    flag is planted at the end, then the gauge re-scales to the total: the flag slides back and the fill carries on past it,
    brighter, with "+€N" at its edge."""
    total = {"beat": 65, "met": 77, "big": 117}[state]
    met = total >= 73
    w = 272
    fw = w if met else int(w * total / 73)
    fx = int(w * 73 / total) if met else None
    bubbles = "".join(f'<i style="position:absolute;left:{x}px;bottom:2px;width:5px;height:5px;border-radius:50%;background:var(--paper);animation:bubble 1.3s infinite;animation-delay:{d}s"></i>'
                      for x, d in ((30, 0), (90, .4), (150, .8), (210, .2)) if x < fw)
    fill = (f'<div style="position:absolute;left:0;top:0;bottom:0;width:{fw}px;overflow:hidden;background:var(--mustard);'
            f'box-shadow:inset 0 5px 0 var(--mustard-light), inset 0 -5px 0 var(--mustard-dark)">{bubbles}<span class="shinebar"></span></div>')
    over = (f'<div style="position:absolute;left:{fx}px;top:0;bottom:0;width:{w - fx}px;background:var(--mustard-light);box-shadow:inset 0 5px 0 var(--paper)"></div>' if met else '')
    fl = flag(fx - 2, -26, 56, f'✓ €73 · +€{total - 73}', flip=fx > w * .6) if met else ''
    tag = ('<span class="togo86 short" style="position:absolute;left:206px;top:-26px;animation:bob .8s infinite">€8 to go</span>' if not met else
           '')
    gauge = (f'<div style="position:absolute;left:106px;top:120px;width:{w + 6}px;height:30px;background:#e9e1cd;border:3px solid var(--ink);'
             f'{"" if met else "animation:pulse 1s infinite;"}">{fill}{over}{fl}{tag}</div>')
    stampx = ('<span class="stamp86 slam" style="position:absolute;left:150px;top:96px;color:var(--good-dark);font-size:16px;line-height:16px;z-index:5">SPEND MET ✓</span>'
              if state == "met" else '')
    v = f"€{total}"
    return (f'<div class="mon"><div class="scr" style="background:{"var(--mustard-pale)" if met else "#fbf1d0"}">{number_block(v, met)}'
            f'<div class="art"><img class="px" src="{MILK}" style="animation:bob 1.2s infinite"><div class="k">MILK {"7" if met else "6"} / 7</div></div>'
            f'{landing(state)}<div class="lbl" style="position:absolute;left:108px;top:4px;z-index:2">SUBTOTAL</div>{gauge}{stampx}</div></div>')


# ------------------------------------------------------------------ top bar

STATES = [("short", "planning: €52 of €73"), ("close", "planning: €70, almost"), ("met", "met: €77, flag planted"),
          ("big", "met big: €182, flag slid back"), ("drag", "drag: €52 › €58")]
TOTAL = {"short": 52, "close": 70, "met": 77, "big": 182, "drag": 52}


def chip(inner, glow=False):
    return (f'<div class="bar" style="height:64px"><div class="chip" style="height:46px;{"animation:pulse 1s infinite;" if glow else ""}">'
            f'<span class="k">SPEND €73+</span>{inner}</div></div>')


def t_stacks(state):
    """T1 v3, coin stacks in the chip: ten small stacks (3 coins each) on a shelf, full at the quota; the next coin wobbles,
    the chip glows from 80 %. At the quota the flag is planted there; then the shelf re-scales to the total, the flag slides back
    and the stacks past it are bright."""
    total = TOTAL[state]
    met, unit, full, flag_at = columns(total)
    gfull = columns(58)[2] if state == "drag" else full
    pitch, base = 25, 34
    body = ""
    for i in range(10):
        n = 3 if i + 1 <= int(full) else (round((full - i) * 3) if i < full else 0)
        gn = 3 if i + 1 <= int(gfull) else (round((gfull - i) * 3) if i < gfull else 0)
        bright = met and i >= int(flag_at)
        if n:
            body += stack(2 + i * pitch, base, n, w=20, t=4, bright=bright, glint=(i == 1))
        if gn > n:
            body += stack(2 + i * pitch, base - n * 4, gn - n, w=20, t=4, ghost=True)
        if not n and gn <= n:
            body += f'<span style="position:absolute;left:{4 + i * pitch}px;top:{base - 10}px;width:16px;height:8px;border-radius:50%;border:2px dashed #6d8f8b"></span>'
    fl = flag(2 + flag_at * pitch - 3, -4, 40, "✓") if met else ''
    shelf = '<i style="position:absolute;left:-2px;right:-2px;top:31px;height:6px;background:var(--steel-light);border:2px solid var(--ink)"></i>'
    right = (f'<span class="togo86" style="background:var(--mustard)">+€{total - 73}</span>' if met else
             (f'<span class="togo86 short">€15 to go</span>' if state == "drag" else f'<span class="togo86{" short" if total < 70 else ""}">€{73 - total} to go</span>'))
    inner = f'<span style="position:relative;flex:none;width:252px;height:40px">{shelf}{body}{fl}</span>{right}'
    return chip(inner, glow=(not met and total / 73 >= .8))


def t_fill(state):
    """T2 v3, live fill with the anchoring flag: full at the quota; then the flag is planted, the bar re-scales to the total and
    the flag slides back while the bright fill carries on past it."""
    total = TOTAL[state]
    met = total >= 73
    w = 290
    fw = w if met else int(w * total / 73)
    fx = int(w * 73 / total) if met else None
    bubbles = "".join(f'<i style="position:absolute;left:{x}px;bottom:1px;width:4px;height:4px;border-radius:50%;background:var(--paper);animation:bubble 1.3s infinite;animation-delay:{d}s"></i>'
                      for x, d in ((20, 0), (70, .5), (120, .9), (170, .3), (220, .7)) if x < fw)
    ghost = ""
    if state == "drag":
        gw = int(w * 58 / 73)
        ghost = f'<i style="position:absolute;left:{fw}px;top:0;bottom:0;width:{gw - fw}px;background:repeating-linear-gradient(90deg,var(--mustard) 0 4px,transparent 4px 7px)"></i>'
    fill = (f'<i style="position:absolute;left:0;top:0;bottom:0;width:{fw}px;overflow:hidden;background:var(--mustard);box-shadow:inset 0 3px 0 var(--mustard-light)">'
            f'{bubbles}<span class="shinebar"></span></i>')
    over = (f'<i style="position:absolute;left:{fx}px;top:0;bottom:0;width:{w - fx}px;background:var(--mustard-light);box-shadow:inset 0 3px 0 var(--paper)"></i>' if met else '')
    fl = flag(fx - 2, -14, 34, "✓") if met else ''
    right = (f'<span class="togo86" style="background:var(--mustard)">+€{total - 73}</span>' if met else
             (f'<span class="togo86 short">€15 to go</span>' if state == "drag" else f'<span class="togo86{" short" if total < 70 else ""}">€{73 - total} to go</span>'))
    inner = (f'<span style="position:relative;flex:none;width:{w + 4}px;height:20px;background:rgba(0,0,0,.3);border:2px solid var(--ink)">'
             f'{fill}{over}{ghost}{fl}</span>{right}')
    return chip(inner, glow=(not met and total / 73 >= .8))


def board():
    out = ['<h1>#86 round 3: coins with depth, an anchoring flag<small>2026-10-19 · open the page in a browser to see the motion · '
           'gold outline = recommended</small></h1>']
    out.append('<div class="note" style="margin-top:6px">While short, every gauge is full exactly at the quota. When the total reaches it, a '
               'green flag is planted on that spot; then the gauge re-scales to the total, so the flag slides back to where €73 now '
               'sits and the stretch past it fills bright. Shown: €65 short, €77 just met (flag near the end), and a bigger total '
               '(flag slid back).</div>')
    out.append('<h2>Count-up monitor</h2>')
    for key, title, fn, rec, desc in (
            ("M1", "Coin stacks", mon_stacks, True,
             "Ten stack spots in a tray; each fills to 4 coins (3/4 view: lit top, ridged edge) as its tenth of the quota fills. The "
             "top coin drops and bounces, a glint runs over the pile. Past the flag the stacks are bright gold."),
            ("M2", "Live fill", mon_fill, False,
             "Round 2's glass gauge (bubbles, shine, pulse from 80 %), with the flag planted at the quota and the bright fill carrying "
             "on past it.")):
        out.append(f'<div class="cap" style="font-size:15px;margin-top:12px"><b>{key} · {title}</b></div><div class="note" style="font-size:13px">{desc}</div>'
                   f'<div class="row"><div class="{"rec" if rec else ""}" style="display:flex;gap:14px;zoom:.9">{fn("beat")}{fn("met")}{fn("big")}</div></div>')
    out.append('<h2>Top-bar gauge</h2>')
    for key, title, fn, rec, desc in (
            ("T1", "Coin stacks", t_stacks, True,
             "Ten small stacks of 3 on a steel shelf; the next coin wobbles and the chip glows from 80 %; a drag shows the coins it "
             "would add as dashed ghosts. Same coins as M1."),
            ("T2", "Live fill", t_fill, False,
             "The glass bar with bubbles and shine; same flag and carry-on past it.")):
        cells = "".join(f'<div class="cell">{fn(s)}<div class="cap">{c}</div></div>' for s, c in STATES)
        out.append(f'<div class="cap" style="font-size:15px;margin-top:14px"><b>{key} · {title}</b></div><div class="note" style="font-size:13px">{desc}</div>'
                   f'<div class="{"rec" if rec else ""}" style="display:grid;grid-template-columns:520px 520px;gap:14px 20px;margin-top:10px;width:1060px">{cells}</div>')
    return ('<!doctype html>\n<html>\n<head>\n<meta charset="utf-8">\n<title>Count-up gauge round 3</title>\n<style>' + FONTS + PARTS_CSS + CSS2 + CSS3
            + '</style>\n</head>\n<body>\n' + "\n".join(out) + '\n</body>\n</html>\n')


(MOCKUPS / "count_up_86_v3_board.html").write_text(board(), encoding="utf-8")
print("wrote count_up_86_v3_board.html")
