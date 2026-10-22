# #86 round 5: the count-up monitor, decluttered and rewarding (live mock-ups)

Written 2026-10-19 after the user played build pass 1 of #86 in the game.

## What the user said (play test of build pass 1)

- Top-bar gauge (TA liquid): "good, need some polishing but it fits well". They chose a **money-green liquid**
  over the gold (now built: green `#5fae5a`, light `#a5d17e`, dark `#3d7a45`; brighter past the flag).
- Count-up monitor: "too much infos, hard to follow. it feels like multiple UI elements not fitting together."
- € tank: "euro filling is good but does not reward anything visually. number going up is okeh. I don't know it
  lacks something."
- They noticed the planning stickers vanish at checkout and #60's old token animation still plays (the decided
  "stickers stay and fire" is not built yet).

## What is on the monitor in the game now (look at the captures)

`game_pass1_short_1920x1080.png` (mid-count, short of the quota) and `game_pass1_total_1920x1080.png` (the total,
quota met). The screen (406 x 158 px at the 1280 x 720 game scale) holds, all at once: the item's art (96 px) with its
name and "7 / 7"; the SUBTOTAL caption; the step line at the top right ("+€5 Milk: earlier Breakfast"); the big ink
number on a mustard shadow; the € tank (64 x 92) at the right; on the bottom row "SPEND €73+", the gain chip "+€8"
and the tag "€17 to go"; at the quota a green "✓ MET" chip over SPEND. Nine things, from three different design
rounds. That is the clutter the user means.

## The task

Make ONE live, self-running HTML page (see "The page" below) that rethinks the count-up monitor from your angle so
that it reads as ONE designed screen, is easy to follow beat by beat, and pays off visually when the quota is met.
The user judges motion from live pages, not stills.

Keep (decided in rounds 1-4, comment on issue #86; do not reopen them):
- The € tank idea: the euro sign (or the screen, if your angle integrates it) fills with sloshing gold, full exactly
  at the quota; past it, it overflows. (V1.)
- The landing sticker (MA): each beat's sticker (×3 gold starburst, +12 cream price-gun label, =€6 teal label, a grey
  "pfff" for a fizzle; the same shapes as on the items) is slapped big on the monitor.
- The number punches on each gain; a slowly turning pixel sunburst behind it that turns gold at the quota.
- A SPEND MET ✓ stamp slams down at the quota (green, rubber-stamp look, see v4).
- Player-facing name: SPEND €73+ (never QUOTA).
- The quota ding is the only new sound moment (no sound needed in the page).
- Items during the count-up: the planning stickers STAY on the items and fire when their step lands (punch, flash,
  the value flies to the receipt, a small ✓ settles). The rail strip lights gold from giver to target as it pays.
  Show this on a short belt strip under the monitor, so the user sees the monitor and the items working together.
- Top bar: the TA liquid gauge in MONEY GREEN with its anchoring flag (full at the quota while short; at the quota a
  flag is planted there and the gauge re-scales to the total so the flag slides back). Include it at the top.

Free to change (this is the point of the round):
- What the monitor shows and what it drops. Strong hint: the receipt already prints each step line, and the top bar
  already shows SPEND €73+ and the to-go amount. Every element must earn its place; say in a caption what you dropped
  and why.
- Where the tank sits and how big; how the to-go / over amount reads (e.g. on the tank itself).
- The REWARD at the quota: it must feel like a payoff (the user: "does not reward anything visually"). Think
  register/supermarket/cash: the tank bursting, gold spilling out of the monitor, coins or notes raining, the screen
  flashing gold, the number turning gold, a shake, the stamp, a jackpot beat. Then a satisfying overflow state past it
  ("+€44" counting what is over) that keeps rewarding each extra gain without becoming noise.
- How a beat reads: one clear focal point at a time (the item that pays, its sticker, the gain, the number).

Rejected before (do not bring back): coin stacks (felt flat), till drums, a static segment track, a flag sitting at
the end of a bar, a bar that reads 2/3 full at the quota.

## Style and constraints

- The game's pixel style: hard pixels (draw canvases at half resolution with `image-rendering: pixelated`, CSS 2x),
  ink outlines `#2b2420`, the palette in `art/src/palette.txt` (paper `#fbf7ee`, cream `#f3e9d2`, cream shade
  `#ddcba5`, mustard `#e2b33c`, mustard light `#f1d27a`, mustard pale `#faecbc`, mustard dark `#b38425`, good green
  `#5fae5a`, green dark `#3d7a45`, tomato dark `#a83a3c` (only for fizzles and "to go"), teal panel `#2a4d4b`, teal
  dark `#1f3b3a`, rubber `#3d3a36`). Fonts: Pixelify Sans for captions, Atkinson Hyperlegible Next (weights 200-800)
  for numbers and text: `../../../fonts/PixelifySans-Variable.ttf`, `../../../fonts/AtkinsonHyperlegibleNext-Variable.ttf`.
- Real art you can use: `assets/art/items_v2/*.png` (milk, eggs, bread, croissant ...), `assets/art/icons/`,
  `../../../art/effects/` (sticker_burst.png, sticker_label.png, sticker_label_teal.png, sticker_label_grey.png,
  euro_tank.png (32x46, cream-shade inside), sparkle.png, rail_*.png, pay_burst.png ...), `../../../art/icons/`.
- The monitor must stay the game's monitor: 424 x 176 outer (rubber bezel), screen ~406 x 158, at the 1280 x 720 game
  scale. Show it at 2x CSS if it helps reading, but say the game size in the caption.
- Reduced motion must be possible: say in the caption what stays (the states) and what goes (the motion).
- No new sound. Display only: everything shown is the shown subtotal against the quota.

## The page

- File: `docs/art/mockups/count_up_86_v5_<letter>.html` (your letter is given in your prompt), hand-written (no
  generator needed), one self-contained page, no network (local fonts/art only).
- LIVE: one loop plays a count-up, then repeats. Use the v4 timeline so pages compare: QUOTA 73;
  beats [gain, sticker, kind]: [1,'+1',add], [10,'+10',add], [21,'×3',mul], [24,'×3',mul], [9,'+9',add],
  [12,'+12',add], [40,'×2',mul] -> €77 crosses 73 on beat 6 (ding), €117 at the end; ~0.95 s per beat, hold ~3.2 s,
  restart. Also support `?at=<seconds>` to fast-forward for captures (as v4 does) and `?rm=1` for reduced motion.
- Layout of the page: a title line ("#86 round 5 <letter>: <your angle name>"), then the scene: the top bar strip
  (TA in green) above, the monitor, and a short belt strip of 4-5 items with their planning stickers under it, laid
  out roughly as in the game (look at the captures), 1280 px wide. Under the scene, a caption of 3-6 short lines:
  the angle, what the monitor shows, what it dropped, the reward, reduced motion.
- Read `count_up_86_v4_live.html` first: reuse its loop, its LiquidBar (recolour to green for the top bar), its
  EuroTank, sticker and stamp CSS where they fit.

## Self-check before you finish

Capture your page with headless Chrome and LOOK at the PNGs (Read them). `cap.sh` in this folder takes the query:
`sh docs/art/mockups/count_up_86_v5_src/cap.sh docs/art/mockups/count_up_86_v5_<letter>.html docs/art/mockups/count_up_86_v5_<letter>_at6.5.png "at=6.5" 720`
(use a larger height, e.g. 900, if your scene is taller). Capture at least: mid-count short of the quota (`at=3.0`),
the ding moment (`at=6.3` to `6.6`, pick the frame where the reward peaks), and the overflow end (`at=8.5`), plus one
with `at=6.5&rm=1` (reduced motion). Check: nothing overlaps badly, text is readable, one focal point per beat, the
reward moment is clearly bigger than a normal beat, the pixel style holds. Fix what you see and capture again. Keep the
final PNGs (`_at3.0.png`, `_at6.5.png`, `_at8.5.png`) next to the page; they are the stills for the index.
