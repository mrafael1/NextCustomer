"""Builds docs/art/mockups/screens_index.html: every screens_* mock-up with its capture as a thumbnail."""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))
MOCK = os.path.normpath(os.path.join(HERE, "..", ".."))

SCREENS = [
    ("title", "Title", "Q1", "a", [
        ("a", "A: store front at night",
         "Lit rooftop sign as the logo, stocked windows, cashier through the doors, buttons on the pavement; "
         "#63 spot by the right window.",
         ["", "_nosave", "_confirm"]),
        ("b", "B: giant receipt",
         "Plain teal backdrop, one long receipt from the printer: logo header, mono subtitle, gold coin "
         "starburst, stapled loyalty card. Cut-list option.",
         ["", "_nosave", "_confirm"])],
     "A: store-page material, introduces cashier and store; B stays the cut-list fallback. Risk: the "
     "half-scale window stock must become one interior sprite."),
    ("rack", "Impulse rack", "Q2", "a", [
        ("a", "A: styled RewardPanel pop-in",
         "Today's parts in order on a paper frame, teal sign header, items in a teal niche on the belt's "
         "steel rail. 600x414, same timing.",
         ["", "_start", "_scan"]),
        ("b", "B: wire rack prop at the checkout",
         "Free-standing impulse rack by the belt; buttons hang from its crossbar; note and warning move onto "
         "the monitor (behaviour change).",
         ["", "_start", "_scan"])],
     "A: no behaviour or timing change, parts shared with #61's print-out. Open: switch the monitor off "
     "during the rack (the panel cuts its line in half)."),
    ("deck", "Deck view and chooser", "default", "b", [
        ("a", "A: clipboard with clear pockets",
         "Stock sheet on a wood board, items in clear pockets, label-tape headings, binder tabs; Run info "
         "shows stamp rings.",
         ["", "_stock", "_info", "_chooser"]),
        ("b", "B: teal hand basket on shelves",
         "The counter's basket emptied onto steel rails; copies stacked with a cream xN label; Run info "
         "text only.",
         ["", "_stock", "_info", "_chooser"])],
     "Default B (sticker device, belongs to the counter), with NEW as text and no 'Remove 1'. "
     "PAGE_SIZE 936x500: the starter page (484) fits unscrolled."),
    ("kiosk", "Exit kiosk", "Q3", "a", [
        ("a", "A: lottery ticket dispenser",
         "Velvet-and-brass kiosk with a bulb marquee over the shaded checkout; tickets hang from its mouth "
         "like scratch tickets; RECEIPT IN slot for #66.",
         ["", "_hover"]),
        ("b", "B: photo-booth printer at the exit",
         "Camera cuts to the exit doors; teal booth with a curtain, tickets on brass clips; #63 corner "
         "outlined.",
         ["", "_hover"])],
     "A: no extra backdrop or camera cut, timing unchanged, survives #66 being cut. Q4 (perk stamp): "
     "yes, the ring with initials until #59 (shown in kiosk A and deck A)."),
    ("results", "Results / final receipt", "default", "a", [
        ("a", "A: till report on the counter",
         "The register prints the final receipt; CHECKOUT key becomes New run, Redraw becomes Export log; "
         "gold sparkle, coin band, gutter marks.",
         ["", "_over", "_printing"]),
        ("b", "B: staff noticeboard",
         "Cut to a cork board with the receipt pinned and a stamped headline; New run on a time clock "
         "beside it.",
         ["", "_over"])],
     "Default A: no cut, buttons on the machine you played on. B needs a backdrop and leans to staff "
     "framing (plan section 12)."),
]

LABELS = {"": "main", "_nosave": "no save", "_confirm": "confirm", "_start": "shift 1", "_scan": "scan popup",
          "_stock": "stock", "_info": "run info", "_chooser": "chooser", "_hover": "hover",
          "_over": "run over", "_printing": "printing"}

CSS = """
@font-face { font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }
@font-face { font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }
:root { --ink:#2b2420; --paper:#fbf7ee; --cream:#f3e9d2; --cream-shade:#ddcba5;
  --teal-black:#172c2b; --teal-dark:#1f3b3a; --teal-mid:#2a4d4b; --teal-light:#c3e0d4; --slate:#222a29;
  --mustard:#e2b33c; --gold:#ffcf3f; --brass:#8a5d1a; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: var(--teal-black); color: var(--paper); font-family: Atkinson, sans-serif; }
body { width: 1280px; padding: 0 16px 24px; }
header { height: 52px; display: flex; align-items: center; gap: 16px; border-bottom: 4px solid var(--teal-mid);
  margin: 0 -16px 8px; padding: 0 16px; background: var(--teal-dark); }
header h1 { font-family: Pixelify; font-size: 24px; color: var(--mustard); text-shadow: 2px 2px 0 var(--ink); white-space: nowrap; }
header p { font-size: 12.5px; color: var(--teal-light); }
section { background: var(--teal-dark); border: 2px solid var(--ink); box-shadow: 4px 4px 0 var(--slate);
  margin-bottom: 6px; padding: 4px 8px 5px; }
.head { display: flex; align-items: baseline; gap: 10px; }
h2 { font-family: Pixelify; font-size: 19px; color: var(--paper); }
.q { font-family: Pixelify; font-size: 12px; background: var(--mustard); color: var(--ink); padding: 0 8px; border: 2px solid var(--ink); }
.q.dflt { background: var(--cream-shade); }
.why { font-size: 12px; color: var(--teal-light); flex: 1; }
.why b { color: var(--mustard); }
.opts { display: flex; gap: 8px; margin-top: 3px; }
.opt { flex: 1; padding: 3px 6px 4px; border: 2px solid transparent; }
.opt.on { border-color: var(--brass); background: var(--teal-mid); }
.pitch { margin-bottom: 3px; }
h3 { font-size: 13.5px; font-weight: 750; color: var(--cream); display: flex; align-items: center; gap: 6px; }
.rec { font-size: 10px; font-weight: 750; background: var(--gold); color: var(--ink); padding: 0 5px;
  border: 2px solid var(--ink); text-transform: uppercase; letter-spacing: .5px; }
.pitch p { font-size: 11.5px; line-height: 1.28; color: var(--cream-shade); margin-top: 2px; }
.thumbs { display: flex; gap: 8px; }
.th { display: block; width: 112px; text-decoration: none; }
.th img { display: block; width: 112px; height: 63px; border: 2px solid var(--ink); background: var(--teal-black); }
.th span { display: block; font-size: 10.5px; color: var(--teal-light); }
.th:hover img { border-color: var(--gold); }
"""


def build() -> str:
    parts = []
    for key, name, q, rec, opts, why in SCREENS:
        qtag = f'<span class="q">{q}</span>' if q != "default" else '<span class="q dflt">default</span>'
        rows = []
        for o, title, pitch, states in opts:
            thumbs = []
            for s in states:
                page = f"screens_{key}_{o}{s}"
                for ext in (".html", "_1920x1080.png"):
                    assert os.path.exists(os.path.join(MOCK, page + ext)), page + ext
                thumbs.append(f'<a class="th" href="{page}.html"><img src="{page}_1920x1080.png" alt="{page}">'
                              f'<span>{LABELS[s]}</span></a>')
            on = o == rec
            badge = '<span class="rec">recommended</span>' if on else ""
            rows.append(f'<div class="opt{" on" if on else ""}"><div class="pitch"><h3>{html.escape(title)}'
                        f'{badge}</h3><p>{html.escape(pitch)}</p></div><div class="thumbs">{"".join(thumbs)}'
                        f'</div></div>')
        parts.append(f'<section><div class="head"><h2>{name}</h2>{qtag}<p class="why"><b>Critic:</b> '
                     f'{html.escape(why)}</p></div><div class="opts">{"".join(rows)}</div></section>')
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Screens decide index</title>
<!--
  #56 decide prep (2026-10-19): index of every screens_* mock-up, grouped by screen, with the A/B pitch and the
  critic's recommendation. Nothing is decided; the questions are in screens_src/DECIDE_56.md.
  Built by screens_src/gen_index/gen_index.py. Authored at 1280 CSS px; palette colours only; fonts from ../../../fonts/.
-->
<style>{CSS}</style></head><body>
<header><h1>#56 screens: decide index</h1><p>Every mock-up, grouped by screen; click a thumbnail to open its page.
Questions, defaults and the art list: screens_src/DECIDE_56.md. Nothing is decided.</p></header>
{"".join(parts)}
</body></html>
"""


if __name__ == "__main__":
    with open(os.path.join(MOCK, "screens_index.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(build())
    print("ok")
