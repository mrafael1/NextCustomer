"""Builds ../../machine_77_index.html: every #77 prep page and still, with one-line captions.

Run: python gen_index.py (from anywhere). House style as screens_index.html: palette colours, fonts from ../../../fonts/.
"""
import html
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "machine_77_index.html"))
MOCK = os.path.dirname(OUT)

SECTIONS = [
    {
        "title": "Round 3 · look F chosen, inspection bonus ticket, balance",
        "tag": "new 2026-10-20",
        "q": "Q7 bonus · Q8 lever · Q9 bonus pick (open)",
        "round2": True,
        "pages": [("machine_77_flow.html", "flow page, opens on look F; shift 3 shows the bonus"),
                  ("machine_77_loyalty.html", "round-3 balance rows")],
        "why": "Look F (restock hatch) is chosen, and the Banana and Eggs redraw is approved. Your idea, proposed: passing an "
               "inspected shift (3, 5, 7) gives a second full machine visit: any chute, 3 prizes, pick 1, the meter counts it. "
               "It adds about 13 s. Balance: 22% → 32% with the bonus ticket, 35.6% with Carrier bag and Tea bags Rare (at the band's edge; both upper bounds, the simulated UPGRADES picks are optimistic). "
               "It cannot lift shift 3 (68-69% pass): the first bonus comes after it.",
        "groups": [
            ("Look F · the bonus ticket after a passed inspection (shift 3, Spot check)", [
                ("machine_77_flow_f_bonus_1_stamped_receipt.png", "receipt: INSPECTION PASSED ✓"),
                ("machine_77_flow_f_bonus_2_announce.png", "head: BONUS TICKET!, stub prints"),
                ("machine_77_flow_f_bonus_9_stub_feeding.png", "the stub feeds in"),
                ("machine_77_flow_f_bonus_3_second_choice.png", "2nd odds card: REGULAR 1 › 2"),
                ("machine_77_flow_f_bonus_4_second_reveal.png", "2nd draw: 3 more boxes revealed"),
                ("machine_77_flow_f_bonus_5_second_landing.png", "2nd NEW ITEMS lands, +1"),
                ("machine_77_flow_f_bonus_7_upgrades_landing.png", "2nd visit as UPGRADES: in place"),
                ("machine_77_flow_f_bonus_6_reduced_motion.png", "reduced motion"),
            ]),
            ("For comparison · balance round 3 · look F as chosen in round 2", [
                ("machine_77_flow_f_bonus_8_one_ticket_inspection_off.png", "inspection off: one ticket"),
                ("machine_77_balance_r3_page.png", "loyalty page, ROUND 3 rows"),
                ("machine_77_flow_f_intake_at2.0.png", "F: order slip pinned up"),
                ("machine_77_flow_f_draw_at8.9.png", "F: boxes on runway and belt"),
                ("machine_77_flow_f_legendary_at14.15.png", "F: LEGENDARY reveal"),
            ]),
        ],
    },
    {
        "title": "Round 2 · new looks, clean split, redraws, balance",
        "tag": "2026-10-20",
        "q": "Q3 decided: F",
        "pages": [("machine_77_flow.html", "flow page, MACHINE LOOK row"),
                  ("machine_77_upgrades.html", "redrawn Banana and Eggs"),
                  ("machine_77_loyalty.html", "round-2 balance rows")],
        "why": "Three new looks close to A with nothing that spins (D was recommended; you chose F). "
               "NEW ITEMS (add to cart) always arrives plain at the product's own rarity; UPGRADES (improve one you own) "
               "is the only way to BIG and GOLDEN, Legendary = SHELF UPGRADE, Golden twin gone. "
               "Balance: the split wins 22% ± 5 under option B, below the 35-40% band.",
        "groups": [
            ("Look D · coupon printer: checks your receipt, prints 3 slips", [
                ("machine_77_flow_d_intake_at2.0.png", "receipt feeds in, receipt screen"),
                ("machine_77_flow_d_draw_at8.45.png", "receipt OK, slip 1 prints"),
                ("machine_77_flow_d_legendary_at13.65.png", "LEGENDARY reveal"),
                ("machine_77_flow_d_new_landing_at17.3.png", "NEW ITEMS: new slot, +1"),
                ("machine_77_flow_d_upgrades_landing_at17.4.png", "UPGRADES: shelf upgrade in place"),
                ("machine_77_flow_d_rm_at9.2.png", "reduced motion"),
            ]),
            ("Look E · click & collect lockers: packs 3 lockers, doors open", [
                ("machine_77_flow_e_intake_at2.0.png", "reading the receipt"),
                ("machine_77_flow_e_draw_at8.6.png", "locker 1 opens, bag inside"),
                ("machine_77_flow_e_legendary_at13.45.png", "LEGENDARY reveal in the lockers"),
                ("machine_77_flow_e_new_landing_at17.1.png", "NEW ITEMS: new slot, +1"),
                ("machine_77_flow_e_upgrades_landing_at17.2.png", "UPGRADES: in place, same count"),
                ("machine_77_flow_e_rm_at9.2.png", "reduced motion"),
                ("machine_77_flow_e_stampday_at24.0.png", "STAMP DAY free order"),
            ]),
            ("Look F · restock hatch (CHOSEN): bays drop boxes, a runway and a little belt bring them out", [
                ("machine_77_flow_f_intake_at2.0.png", "order slip pinned up"),
                ("machine_77_flow_f_draw_at8.9.png", "box 1 on the belt, box 2 on the runway"),
                ("machine_77_flow_f_legendary_at14.15.png", "LEGENDARY reveal"),
                ("machine_77_flow_f_new_landing_at17.8.png", "NEW ITEMS: new slot, +1"),
                ("machine_77_flow_f_upgrades_landing_at17.9.png", "UPGRADES: in place, same count"),
                ("machine_77_flow_f_rm_at9.2.png", "reduced motion"),
            ]),
            ("The clean split (look A)", [
                ("machine_77_flow_r2_new_odds_at6.0.png", "NEW ITEMS card: product rarity"),
                ("machine_77_flow_r2_new_coldsnacks_lvl3_odds_at6.0.png", "no Legendary stocked: steps down"),
                ("machine_77_flow_r2_new_landed_at17.3.png", "NEW IN CART, count +1"),
                ("machine_77_flow_r2_upgrades_odds_shift7_at6.0.png", "UPGRADES card, shift 7"),
                ("machine_77_flow_r2_upgrades_glint_shift7_at17.2.png", "the owned copy glints"),
                ("machine_77_flow_r2_upgrades_done_at18.2.png", "UPGRADED, same count"),
                ("machine_77_flow_r2_b_upgrades_reveal_at15.2.png", "UPGRADES reveal, look B"),
            ]),
            ("Banana and Eggs redrawn · balance round 2", [
                ("machine_77_eggs_banana_before_after.png", "before / after (approved)"),
                ("machine_77_upgrades_sprites_4x.png", "all 4 items × 3 tiers at 4x"),
                ("machine_77_upgrades_1920x1080.png", "tier grid + belt"),
                ("machine_77_balance_r2_page.png", "loyalty page, round-2 rows"),
            ]),
        ],
    },
    {
        "title": "1 · Machine flow (round 1 looks)",
        "tag": "live",
        "q": "Q3 look · Q1 · Q6",
        "pages": [("machine_77_flow.html", "flow page (live: look, shift, chute, owned, Regular, STAMP DAY, speed)")],
        "why": "The whole visit at a calm 1x (about 20.5 s): receipt in, odds card, CONFIRM, draw, 3 reveals rarest last, "
               "pick, the prize lands, the chute's REGULAR hole punches. Odds cards are exact (checked on 100,000 rolls per state).",
        "groups": [
            ("Look A · prize drum (round 1; you liked it, the drum felt too random)", [
                ("machine_77_flow_a_at1.35.png", "receipt flies to the slot"),
                ("machine_77_flow_a_at5.6.png", "COUPONS odds card open"),
                ("machine_77_flow_a_at8.4.png", "drum spins, bulbs chase"),
                ("machine_77_flow_a_at13.97.png", "COMMON · RARE! · LEGENDARY!!"),
                ("machine_77_flow_a_at17.05.png", "pick flies to the cart"),
                ("machine_77_flow_a_at17.5_landed_msg.png", "screen: IN YOUR CART ✓"),
                ("machine_77_flow_a_at9.3_rm.png", "reduced motion"),
            ]),
            ("Look B · scratch & win", [
                ("machine_77_flow_b_at2.0.png", "receipt feeds in"),
                ("machine_77_flow_b_at8.4.png", "promo draw number rolls"),
                ("machine_77_flow_b_shift6_register_at11.0.png", "screen before the first reveal"),
                ("machine_77_flow_b_at12.4.png", "scratch tickets reveal"),
                ("machine_77_flow_b_at14.47.png", "all three revealed"),
                ("machine_77_flow_b_at17.55.png", "the pick lands"),
                ("machine_77_flow_b_shift2_stampday_at26.8.png", "STAMP DAY free register"),
            ]),
            ("Look C · price-drop peg board", [
                ("machine_77_flow_c_at8.9.png", "tags bounce down the pegs"),
                ("machine_77_flow_c_at13.77.png", "all three revealed"),
                ("machine_77_flow_c_at16.85.png", "the pick lands"),
                ("machine_77_flow_c_shift7_upgrades_at15.0.png", "UPGRADES (round 1: TWIN tag, now removed)"),
            ]),
            ("States (look A)", [
                ("machine_77_flow_a_shift1_coupons_odds_at5.6.png", "1st COUPONS: guarantee line"),
                ("machine_77_flow_a_shift1_register_at14.0.png", "shift 1 REGISTER draw"),
                ("machine_77_flow_a_shift2_stampday_at22.75.png", "shift 2 STAMP DAY draw"),
                ("machine_77_flow_a_shift5_upgrades_at14.0.png", "shift 5 UPGRADES draw"),
                ("machine_77_flow_a_shift6_register_odds_at5.6.png", "REGISTER card, 2 owned"),
                ("machine_77_flow_a_shift7_new_odds_at5.6.png", "NEW ITEMS card, per item"),
                ("machine_77_flow_a_shift7_new_at14.0.png", "shift 7 NEW ITEMS draw"),
                ("machine_77_flow_a_lvl3_odds_at5.6.png", "Regular 3: 1 of 3 ≥ RARE"),
            ]),
        ],
    },
    {
        "title": "2 · Rarity reveals",
        "tag": "live",
        "q": "Q2 · Q6",
        "pages": [("machine_77_reveals.html", "reveals page (stations, DRAW 3, greyscale, game size, ODDS row)")],
        "why": "COMMON 0.4 s · RARE! 0.9 s · LEGENDARY!! 1.6 s, told apart by shape, pips, label, motion and sound, so greyscale still reads. "
               "DRAW 3 rolls with the flow page's process (draw77.js); the ODDS row shows its exact odds.",
        "groups": [
            ("Stations", [
                ("machine_77_reveals_common_at0.8.png", "Common: plain flip"),
                ("machine_77_reveals_rare_at2.3.png", "Rare: teal burst, RARE! label"),
                ("machine_77_reveals_legendary_rumble_at3.4.png", "Legendary: rumble"),
                ("machine_77_reveals_legendary_at4.4.png", "Legendary: sunburst, stamp"),
                ("machine_77_reveals_grey_at4.4.png", "greyscale check"),
                ("machine_77_reveals_rm_at4.4.png", "reduced motion"),
                ("machine_77_reveals_game_at4.4.png", "game size, 120x150 tickets"),
                ("machine_77_reveals_full_at4.4.png", "full page with caption"),
            ]),
            ("DRAW 3 (real rolls)", [
                ("machine_77_reveals_draw_items_at4.45.png", "NEW ITEMS: plain Cheese, Milk, Eggs (product rarity)"),
                ("machine_77_reveals_draw_pick_at5.5.png", "a picked ticket"),
                ("machine_77_reveals_draw_items_game_at5.5.png", "NEW ITEMS at game size"),
                ("machine_77_reveals_draw_coupons_at4.6.png", "COUPONS draw"),
                ("machine_77_reveals_draw_coupons_lvl3_at4.png", "Regular 3: drop 1 at least RARE"),
                ("machine_77_reveals_draw_register_lvl2_at5.png", "REGISTER: 3 types, Regular 2"),
            ]),
        ],
    },
    {
        "title": "3 · Item upgrades",
        "tag": "still + hover",
        "q": "Q5 art",
        "pages": [("machine_77_upgrades.html", "tier grid + belt"), ("machine_77_upgrades_bay.html", "upgrades in the B2 bay, shift 4")],
        "why": "One copy, two steps: plain → BIG (+2 price, bigger pack) → GOLDEN (one rule field up, brass remap). "
               "BIG sprites are generated stand-ins; the numbers are the brief's placeholders.",
        "groups": [
            ("", [
                ("machine_77_upgrades_1920x1080.png", "Banana · Milk · Eggs · Coffee × 3 tiers"),
                ("machine_77_upgrades_grey_1920x1080.png", "greyscale: tags by shape"),
                ("machine_77_upgrades_bay_1920x1080.png", "bay: BIG Eggs, GOLDEN Milk, €37 / €61"),
                ("machine_77_upgrades_bay_grey_1920x1080.png", "bay, greyscale"),
                ("machine_77_upgrades_sprites_4x.png", "sprite sheet at 4x"),
            ]),
        ],
    },
    {
        "title": "4 · Loyalty + balance",
        "tag": "interactive",
        "q": "Q1 power · Q2 · Q4 meters",
        "pages": [("machine_77_loyalty.html", "Regular meters A/B/C, STAMP DAY, odds table, win-rate chart")],
        "why": "Click a chute to pick it: its meter punches and the odds card moves. Right: the simulator's win rates "
               "(machine_77_src/BALANCE.md) and option A's refit quota curve.",
        "groups": [
            ("", [
                ("machine_77_balance_default.png", "default: meters A, chart"),
                ("machine_77_balance_coupons3.png", "after 3 COUPONS picks"),
                ("machine_77_balance_meters_b.png", "meters B: stamp strip"),
                ("machine_77_balance_meters_c.png", "meters C: bulb rail"),
                ("machine_77_balance_cardfull.png", "REGISTER: CARD FULL"),
                ("machine_77_balance_stampday.png", "a STAMP DAY stamp"),
                ("machine_77_balance_page_full.png", "full page with caption"),
            ]),
        ],
    },
]

STATS = [
    ("22% ± 5", "round 2: B + split", "UPGRADES taken blind"),
    ("32% ± 6", "+ bonus ticket", "after inspected 3/5/7"),
    ("35.6% ± 6", "+ Carrier, Tea Rare", "band edge, optimistic"),
    ("38% ± 7", "+ bonus after 1", "203 runs; shift 3 75%"),
    ("68–69%", "shift 3 pass", "bonus comes after it"),
    ("28.8%", "Breakfast + bonus", "passes #42 (bar 21.4%)"),
]
HOT = 2

QUESTIONS = [
    ("Q7", "Bonus ticket (open)", "yes, after passed 3, 5, 7", "only after 3 · no"),
    ("Q8", "Extra lever (open)", "Carrier, Tea bags to Rare", "+ bonus after 1 · gentler shift-3 quota"),
    ("Q9", "Bonus pick (open)", "any chute, same rules", "a different chute · UPGRADES only"),
    ("Q3", "Machine", "decided: F, restock hatch", ""),
    ("Q1", "Power", "decided: B, STAMP DAY floor", ""),
    ("Q2", "Guarantees", "decided: may lift a tier, true odds", ""),
    ("Q4", "Meters", "decided: punch ticket", ""),
    ("Q5", "Upgrade art", "decided: BIG drawn + auto GOLDEN", ""),
    ("Q6", "Tempo", "decided: 1x", ""),
    ("Art", "Eggs, Banana", "decided: redraw approved", ""),
]

CSS = """
@font-face { font-family: Pixelify; src: url(../../../fonts/PixelifySans-Variable.ttf); }
@font-face { font-family: Atkinson; src: url(../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf); font-weight: 200 800; }
:root { --ink:#2b2420; --paper:#fbf7ee; --cream:#f3e9d2; --cream-shade:#ddcba5;
  --teal-black:#172c2b; --teal-dark:#1f3b3a; --teal-mid:#2a4d4b; --teal:#4f9a94; --teal-light:#c3e0d4; --slate:#222a29;
  --mustard:#e2b33c; --gold:#ffcf3f; --brass:#8a5d1a; --tomato:#d9534f; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: var(--teal-black); color: var(--paper); font-family: Atkinson, sans-serif; }
body { width: 1280px; padding: 0 16px 16px; }
a { color: inherit; }
header { height: 52px; display: flex; align-items: center; gap: 16px; border-bottom: 4px solid var(--teal-mid);
  margin: 0 -16px 8px; padding: 0 16px; background: var(--teal-dark); }
header h1 { font-family: Pixelify; font-size: 24px; color: var(--mustard); text-shadow: 2px 2px 0 var(--ink); white-space: nowrap; }
header p { font-size: 12.5px; color: var(--teal-light); }
.top { display: grid; grid-template-columns: 430px 1fr; gap: 8px; margin-bottom: 8px; }
.box { background: var(--teal-dark); border: 2px solid var(--ink); box-shadow: 4px 4px 0 var(--slate); padding: 6px 10px 8px; }
.box h2, section h2 { font-family: Pixelify; font-size: 18px; color: var(--paper); }
.first ol { margin: 4px 0 0 18px; font-size: 12.5px; line-height: 1.4; color: var(--cream-shade); }
.first ol b { color: var(--gold); }
.first .path { font-size: 11px; color: var(--teal-light); margin-top: 4px; }
.stats { display: grid; grid-template-columns: repeat(6, 1fr); gap: 6px; margin-top: 6px; }
.qq.open .k { background: var(--gold); }
.stat { background: var(--cream); color: var(--ink); border: 2px solid var(--ink); padding: 3px 6px 4px; }
.stat b { display: block; font-family: Pixelify; font-size: 19px; line-height: 1.1; }
.stat i { display: block; font-style: normal; font-size: 11.5px; font-weight: 750; }
.stat span { display: block; font-size: 10.5px; color: #4a3f38; line-height: 1.2; }
.stat.hot { background: var(--gold); }
.qs { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px 10px; margin-top: 6px; }
.qq { font-size: 11.5px; color: var(--cream-shade); line-height: 1.25; }
.qq .k { font-family: Pixelify; font-size: 12px; background: var(--mustard); color: var(--ink); padding: 0 5px; border: 2px solid var(--ink); margin-right: 4px; }
.qq b { color: var(--paper); }
.qq em { font-style: normal; color: var(--gold); }
.note { font-size: 11px; color: var(--teal-light); margin-top: 5px; }
section { background: var(--teal-dark); border: 2px solid var(--ink); box-shadow: 4px 4px 0 var(--slate);
  margin-bottom: 8px; padding: 5px 10px 8px; }
.head { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.tag { font-family: Pixelify; font-size: 12px; background: var(--teal); color: var(--ink); padding: 0 6px; border: 2px solid var(--ink); }
.q { font-family: Pixelify; font-size: 12px; background: var(--mustard); color: var(--ink); padding: 0 6px; border: 2px solid var(--ink); }
.pages { display: flex; gap: 8px; margin-left: auto; }
.pg { font-size: 12px; font-weight: 750; background: var(--cream); color: var(--ink); text-decoration: none;
  border: 2px solid var(--ink); box-shadow: 2px 2px 0 var(--slate); padding: 1px 8px; }
.pg:hover { background: var(--gold); }
.pg span { font-weight: 400; color: #4a3f38; }
.why { font-size: 12px; color: var(--teal-light); margin-top: 2px; }
h3 { font-size: 12px; font-weight: 750; color: var(--mustard); margin: 5px 0 2px; }
.thumbs { display: flex; flex-wrap: wrap; gap: 6px 8px; }
.th { display: block; width: 146px; text-decoration: none; }
.th img { display: block; width: 146px; height: 82px; object-fit: cover; object-position: top; border: 2px solid var(--ink); background: var(--teal-black); }
.th span { display: block; font-size: 10.5px; line-height: 1.2; color: var(--cream-shade); margin-top: 1px; }
.th:hover img { border-color: var(--gold); }
section.r2 { border-color: var(--gold); box-shadow: 4px 4px 0 var(--brass); }
section.r2 .tag { background: var(--gold); }
.qq.done { opacity: .8; }
footer { font-size: 11px; color: var(--teal-light); }
"""


def e(s):
    return html.escape(s, quote=True)


def main():
    missing = []
    out = ['<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><title>Receipt rewards index</title>\n'
           '<meta name="viewport" content="width=1280">\n'
           '<!--\n  #77 decide prep (2026-10-20): index of every machine_77_* page and still, with one-line captions.\n'
           '  Round 3: Q1-Q6 and the chute split are decided (look F); Q7-Q9 (the inspection bonus ticket) are open. Questions in\n'
           '  machine_77_src/DECIDE_77.md, numbers in machine_77_src/BALANCE.md.\n'
           '  Built by machine_77_src/index/gen_index.py. Authored at 1280 CSS px; palette colours only; fonts from ../../../fonts/.\n-->\n'
           '<style>' + CSS + '</style></head><body>\n']
    out.append('<header><h1>#77 RECEIPT REWARDS: decide index</h1><p>The machine that replaces the reward print-out and '
               'the exit kiosk, item upgrades and Regular meters. Mock-ups only, nothing built. Round 3: look F chosen; three questions left on the inspection bonus ticket. '
               'Click a thumbnail for the full still, a button for the page.</p></header>\n')
    # top row: open first + numbers + questions
    out.append('<div class="top"><div class="box first"><h2>Open first</h2><ol>'
               '<li><b><a href="machine_77_flow.html">machine_77_flow.html</a></b>: opens on look F. Shift 3: after the '
               'first pick, the BONUS TICKET stub prints and a second visit runs (<i style="white-space:nowrap">?inspection=off</i> for one ticket).</li>'
               '<li><b>The Round 3 stills</b> below: the bonus beats without playing.</li>'
               '<li><b><a href="machine_77_loyalty.html">machine_77_loyalty.html</a></b>: round 3\'s balance rows under '
               '"ROUND 3: INSPECTION BONUS TICKET".</li></ol>'
               '<p class="path">Questions: machine_77_src/DECIDE_77.md · numbers and method: machine_77_src/BALANCE.md · '
               'brief: machine_77_src/BRIEF.md</p></div>\n')
    out.append('<div class="box"><h2>Key numbers <span style="font-family:Atkinson;font-size:11.5px;color:var(--teal-light)">'
               'simulator, greedy@sensible, option B, today\'s quotas; ± is the 95% interval</span></h2><div class="stats">')
    for i, (big, lab, sub) in enumerate(STATS):
        out.append(f'<div class="stat{" hot" if i == HOT else ""}"><b>{e(big)}</b><i>{e(lab)}</i><span>{e(sub)}</span></div>')
    out.append('</div><div class="qs">')
    for k, head, rec, alt in QUESTIONS:
        done = rec.startswith("decided")
        out.append(f'<p class="qq{" done" if done else " open"}"><span class="k">{k}</span><b>{e(head)}:</b> <em>{e(rec)}</em>'
                   + (f' · {e(alt)}' if alt else '') + '</p>')
    out.append('</div><p class="note">Recommended first (gold). The bonus ticket is worth about +10 points and helps shifts 4-8 '
               '(shift 5 pass 78% → 92%), not shift 3. R3a/R3b are upper bounds: the simulated player picks the best item at each rolled tier, so R3b may land under 35% in the build. R3b and R3e differ by 3 points, inside the noise. GOLDEN Milk rises '
               'to about 1.9 copies a run (4.4-4.8 GOLDEN in all), so its nerf is more pressing.</p></div></div>\n')
    for s in SECTIONS:
        pages = "".join(f'<a class="pg" href="{e(p)}">{e(p)} <span>{e(d)}</span></a>' for p, d in s["pages"])
        cls = ' class="r2"' if s.get("round2") else ""
        out.append(f'<section{cls}><div class="head"><h2>{e(s["title"])}</h2><span class="tag">{e(s["tag"])}</span>'
                   f'<span class="q">{e(s["q"])}</span></div><div class="pages" style="margin:3px 0 0">{pages}</div>'
                   f'<p class="why">{e(s["why"])}</p>')
        for gname, items in s["groups"]:
            if gname:
                out.append(f'<h3>{e(gname)}</h3>')
            else:
                out.append('<div style="height:5px"></div>')
            out.append('<div class="thumbs">')
            for f, cap in items:
                if not os.path.exists(os.path.join(MOCK, f)):
                    missing.append(f)
                out.append(f'<a class="th" href="{e(f)}"><img src="{e(f)}" alt="{e(cap)}" loading="eager"><span>{e(cap)}</span></a>')
            out.append('</div>')
        out.append('</section>\n')
    out.append('<footer>Sources: machine_77_src/ (flow/, reveal/, upgrades/, loyalty/, balance/, index/). '
               'Stills are 1920x1080 captures at 1.5x unless named full or 4x. Nothing here is in the game.</footer>\n')
    out.append('</body></html>\n')
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("".join(out))
    n = sum(len(items) for s in SECTIONS for _, items in s["groups"])
    print(f"wrote {OUT}: {n} stills, missing {missing}")


if __name__ == "__main__":
    main()
