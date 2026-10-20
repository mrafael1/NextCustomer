# #56 mock-up brief: the screens outside the checkout

Shared brief for the agents making the decide-round mock-ups for issue #56 ("Final look for the exit kiosk and the screens outside the checkout"). Nothing is decided yet: the mock-ups are options for the user to choose from. Written 2026-10-19 from the code on `feature/planning-effects`, the plans, the issue, and the user's notes from earlier mock-up rounds.

## 0. Ground rules for every mock-up agent

- **Where you may write:** `docs/art/mockups/screens_*` (pages and captures) and `docs/art/mockups/screens_src/` (generators, copied assets, notes). Nothing else. Do not edit `docs/art/mockups/README.md`, game code, `art/`, `data/`, `tests/` or the plans in `docs/*.md`, because another workflow is building #71 on this branch.
- **Don't run** Godot, `tools/test.sh`, `tools/check.sh` or `tools/import.sh`. Headless Chrome for captures is fine. Don't commit, push or comment on GitHub.
- **Naming:** pages are `screens_<screen>_<option>[_<state>].html`, captures are the same name plus `_1920x1080.png`. Screens: `title`, `rack`, `deck`, `kiosk`, `results`. Options: `a`, `b`, `c` …. States, for example: `title_a_save`, `title_a_confirm`, `deck_a_info`, `deck_a_chooser`, `results_a_over`. Each generator goes in `screens_src/gen_<screen>_<option>/`.
- **Capture:** 1280x720 at 1.5x, which gives 1920x1080. Copy `docs/art/mockups/planning_effects_src/gen_h1/cap.sh` into `screens_src/` (headless Chrome, `CHROME=<path>`, throwaway profile under `TMPDIR`). `docs/art/mockups/capture.js` (Playwright) also works. Clean up any temporary Chrome profiles afterwards.
- **Base scene:** the approved shift screen is **mirrored B2**: register, printer and cashier on the left, belt running toward them. Use these as references:
  - `docs/art/mockups/planning_effects_h1.html`. It is in this working tree and contains the whole mirrored scene.
  - `docs/art/mockups/shift_screen_b2_mirrored.html` (and `_count_up`). These exist only on `main`; read them with `git show main:docs/art/mockups/shift_screen_b2_mirrored.html > docs/art/mockups/screens_src/base_b2_mirrored.html`. Never check out.
  - `docs/art/mockups/shift_screen_b2.html`, the unmirrored original, for its comments on camera and light.
  - The real game captures: `docs/art/shift_screen_1280x720.png`, `docs/art/shift_screen_1920x1080.png` and `docs/art/shift_screen_effects_*.png`.
  - `docs/art/style_frame_v2_*.png`. This is the older boutique style; use it for history only.
- **Assets:**
  - Reuse `docs/art/mockups/assets/art/...` by relative path. It has the items_v2 sprites, the aisle and coupon icons, `fizzle`, `combo_diamond` and some old scenery.
  - Anything else you need from the game's built art is read-only: `art/frames/*.png` (`button`, `sign`, `chip`, `chip_warn`, `top_button`, `loyalty_card`, `popup`, `receipt_paper`, `ticket_*`, `key_*`), `art/icons/*.png` (`art_pending_v2`, `cart`, `menu`, `warning`, `stamp_ring`, `stamp_ring_empty`, `mark_check`, `mark_fizzle`), `art/scenery/*.png` and `art/effects/*.png` (`sticker_label`, `sticker_burst`, `deny_stamp`, `sparkle`, `pay_burst` …). Copy what you use into `screens_src/assets/` and reference the copy by relative path.
  - Fonts load from `../../../fonts/` the way the B2 pages do. Never hotlink anything from the web.
- **Real data only.** Use the texts in section 3 verbatim and real cards, upgrades and inspections from `data/`. Where a layout must prove it fits, use the **longest** texts (section 3.7). Item sprites exist for Banana, Batteries, Cheese, Coffee, Crisps, Croissant, Eggs, Milk, Strawberries and Tea bags, plus the coupon slip with the Multipack and 2 for 1 icons. Every other product shows the dashed art-pending box (`art_pending_v2.png`) with its name printed inside, and every other coupon shows the slip with its name where the icon goes.
- **Pixel-art feel:**
  - Use the 2 px art-pixel grid: 1 art pixel = 2 canvas pixels on the 1280x720 stage.
  - Flat colour bands, no gradients, no anti-aliased soft shadows (shadows are stepped and hard), 2 px ink outlines, light from the upper left.
  - Use palette colours only (section 2.1).
  - In the mock-ups, frames may be CSS approximations of 9-slices, as the B2 pages did. Say in a comment which parts would become new `art/src/` sources.

## 1. What the user has liked (and disliked) in past rounds

Sources: memory notes `shift-screen-b2-decisions`, `planning-effects-decisions`, `shift-screen-art-decisions`, `style-frame-v2-decisions` and `fb-p2-playtest-findings`.

- **Juice above all.** In the fb-p2 playtest the game was "hard to enjoy without visuals, juice, sfx". The user wants the counting and receipt "very juicy". On the first #71 build the verdict was "visually flat, nothing comes out, only numbers", with numbers "floating in the air".
- **Physical objects in the store, not flat panels.** B2 won because it is a believable store seen through one camera:
  - a hung monitor, a printer box, teal hand baskets, a cash register with real keys
  - a cashier
  - distinct store sections behind a cool haze (cold cases, bakery, fruit and veg).

  The proportions must be real, with one vanishing point at (640, −1600) and one light at the upper left. A steep CSS tilt "read as weird proportions".
- **Stickers, stamps and tickets.** These are the most-loved devices:
  - #71's h1 ("just perfect"): cream price-gun labels, gold starbursts, the tilted SPOT CHECK rubber stamp, the struck ticket price with a gold burst, and the brass rail strip with a name plate and chevrons.
  - The PAID stamp and the tear of #61's dessert.
  - The loyalty card's stamp rings.

  The user said "a big stack can be funny in late builds". Things slapped on, stamped and printed beat floating text.
- **Clean, not messy.** On shift-screen proposal 2 the user found "the screen gets messy quickly". The user rejected:
  - h2's pipes ("too much on screen")
  - A's ribbons and arrows
  - a floating chip band.

  One place per fact.
- **Warm, a bit arcade, but premium.** The style-frame v1 look was "too cold". The framing is a supermarket for rich shoppers, where a higher total is good. In fb-p2, players thought a *lower* total won, so copy and visuals should celebrate spending.
- **Colour rules the user approved:** tomato means fizzle, CHECKOUT or CLOSED (and the €0 tag and the deny stamp). Multipliers are mustard or gold, never tomato. The inspection icon is a mustard triangle. Coupon captions are teal. Colour is never the only signal: there is always an icon or a label too.
- **The review process:** the user plays each feature before any commit and wants UI tests to check on-screen geometry. Give about 4 real choices with a recommendation; everything else should be a stated default. Mock-ups and captures live in the repo, not the scratchpad.

## 2. What the approved shift screen established (reuse it)

### 2.1 Palette
`art/src/palette.txt` has 67 colours, in ramps:

- **Ink and grey:** ink #2b2420 (warm, the only outline colour), ink light #4a3f38, greys #5e574d, #8a8172 and #c7beab.
- **Cream:** #b39f78, #ddcba5, cream #f3e9d2, paper #fbf7ee.
- **Teal:** #1f3b3a, #2a4d4b, #3a7672, teal #4f9a94, #86c2b6, #c3e0d4, bright #5fb0a8, black #172c2b.
- **Tomato:** #6e2630, #a83a3c, tomato #d9534f, #ec8a6e, #f5bfa0.
- **Mustard:** #7a5a1c, #b38425, mustard #e2b33c, #f1d27a, #faecbc.
- **Green:** #3d7a45, good #5fae5a, #a5d17e.
- **Brown:** #4a3022, #7a5232, #a87a4e, #d2a874.
- **Brass, gold and velvet:** brass #4a3010, #8a5d1a, #c8932b; gold #ffcf3f; velvet #2a0e14, #561327, #8a1f33, #b23a55.
- **Steel and rubber:** steel #ecebe4, #c7c3b8, #a9a59b, #8d8a83, #6f6b63, #57534c, #45423d; rubber #3d3a36, #2c2926; charcoal #24221f.
- **Wood:** #ddb07a, #c98c4e, #a8703a, #6e4524, #3e2614.
- **Plaster:** #ece0c6, #e4d6b9, #cdbb98, #b9a47c.
- **Glass and slate:** glass #e4f6f3, #bfe2dd; slate #2c3533, #222a29.
- **Skin:** #e2b48c, #c38f6a.

`ui/palette.gd` names them: `BACKGROUND` (teal darkest), `PANEL` (teal dark), `PAPER`, `CREAM`, `MUSTARD`, `TOMATO`, `TEAL`, `GOOD`, `MUTED_INK` and so on. Use no more than 12 colours per sprite. Haze and shade are drawn in code (a modulate or alpha), never as extra colours.

### 2.2 Fonts, by role
Fonts are set by role through `UiKit` (`ui/ui_kit.gd`):

- **Pixelify Sans** (`fonts/PixelifySans-Variable.ttf`): titles, signs, buttons (`display_label`). Light text gets a 6 px ink outline.
- **Atkinson Hyperlegible Next** (`fonts/AtkinsonHyperlegibleNext-Variable.ttf`): rules, tag lines, notices, hints (`body_label`). At weight 750 it is used for **every number and price** (`number_label`), because Pixelify's € and 2 read poorly.
- **JetBrains Mono** (`fonts/JetBrainsMono-Regular.ttf`): the receipt (`receipt_label`), including the final receipt's history and coin lines.
- The fonts must cover `€ × · — … −` (`ArtStyle.REQUIRED_GLYPHS`). They have **no "→"**, so texts use "›".

### 2.3 Kit pieces
- **Framed button** (`FramedButton`): a 9-slice face, either `button.png` (chunky tomato with a ledge) or `sign.png` (a lighter teal shop sign for secondary buttons), with a Pixelify caption.
  - Hover brightens the face.
  - Pressed sinks it 4 px.
  - Disabled sinks it, dims it and drops the hand cursor. A state is never shown by colour alone.
  - It never takes focus (Space is the fast-forward key).

  Note that the title, reward, deck, kiosk and results buttons are still **plain Godot `Button`s** (`UiKit.button`). #56 moves them to framed buttons.
- **Notice style** (`UiKit.style_notice`): tomato Atkinson at 16 px. On the shift screen the notices print in ink on the monitor. #56's panels follow the tomato body style, for example the red inspection warning and the abandon question.
- **Panels:**
  - `UiKit.frame_panel(texture, margin)` draws 9-slice frames (plain edges and middles; a patterned frame is drawn at full size).
  - `UiKit.paper_panel()` is the placeholder #56 replaces: a paper `StyleBoxFlat` with an ink border and a 12 px radius. Today `RewardPanel`, `UpgradePanel`, `UpgradeTicket`, `ResultsPanel` and `DeckView` (teal panel, cream border) build their own `StyleBoxFlat`s.
  - New frames go in `art/src/frames/`.
- **Loyalty card:** the framing decided in #55 is a customer loyalty card. On the top bar's LOYALTY chip it shows 13x13 mustard stamp rings at 2x, holding the upgrade's initials ("CoE", "SlE", "BiB", "ExCS") until #59 draws 7x7 perk glyphs, plus dashed empty rings. The full card face (`art/frames/loyalty_card.png`, boxes 34x34, tilted −6°) is stapled to the final receipt. The starter deck has no starting upgrade, so the card has 3 boxes.
- **Tickets and items:** see section 2.4.
- **Mirrored B2 scene** (`ShiftStage` constants), from left to right:
  - The register column at the left edge (`REGISTER_RECT` 0,330 336x370), with the printer box and its receipt on top. The CHECKOUT key (tomato, "CHECKOUT ›") at 20,422 296x82. Redraw and the keypad, then the cash drawer.
  - The cashier in a teal apron by the receipt.
  - The hung monitor at 484,56 424x192.
  - The belt at 348,314 918x180, with a steel price rail.
  - The teal hand baskets on a steel ledge at 346,662.
  - The wall sections: cold cases, bakery with a clock, fruit and veg stand, aisle signs in each aisle's `sign_color`, under a cool haze.
  - The top bar (teal band, y 0–56): SHIFT, QUOTA, inspection chip, LOYALTY, "Cart 13/15" and ☰.

### 2.4 Items (since #75)
**Items replaced cards.** `ArtCardView` (120x200) was **retired** by #75 (decision 4A). The issue text still names it, but it is out of date. An item is `ItemView`: its 48x48 sprite at 2x (96x96) over its price sticker (`PriceSticker`, 108x64).

- **Product ticket:** paper with a mustard-light band. It shows the base in the number font, the aisle glyph, and a 2-line bold summary.
- **Coupon ticket:** a teal COUPON band.
- **In an offer:** a `TRAY` cell of **108x168** (sprite at 6,4 on a soft shadow, sticker at 0,104), with a 22 px gap between items.

The impulse rack and the reward print-out **already show these tray items**. The deck view and the chooser still show plain `CardView`s (**120x168**, coloured rectangles, no sprite), "until #56". The obvious reading of the issue today is to switch the deck view and chooser to tray items. Flag it as a stated default.

### 2.5 Scan popup on offers
Resting the pointer on an offered item for 600 ms opens `ScanPopup` beside it, over its panel. The popup is 288 wide, 140–280 high, a paper panel with gold trim and a hard shadow. Leave room for it beside the items.

## 3. The screens: every element, string and behaviour

Wherever an option moves something into a prop (a rack, a kiosk, a receipt), every string below must still be visible and in the right order.

### 3.1 Title (`ui/title_screen.gd`, its own scene, before the shift screen)
**Today:** a flat teal-darkest `ColorRect` with a centred column (gap 18):

| Element | Text | Today's style |
|---|---|---|
| Title | `NEXT CUSTOMER` | default font 84 px, mustard, 14 px ink outline (to become a logo) |
| Subtitle | `Scan groceries and coupons in the best order. Meet the quota on all 8 shifts.` (8 comes from `balance.quotas.size()`) | 22 px light text |
| Coin line | `Coins: 5`, or `Coins: ?` when there is no readable profile | 22 px mustard |
| Without a save | `Click anywhere to start`, pulsing (alpha 1 ↔ 0.35, 0.7 s each way) | 30 px cream |
| With a save | two buttons, each at least 200x64, 24 apart: `Continue (shift 3 / 8)` (`"Continue (shift %d / %d)"`) and `New run` | 26 px |
| Bottom corner (20 px in, 16 up) | `Export log` button on the left; build label `fb-p2` (the `next_customer/build_label` setting) on the right | 16 px button, 14 px label |
| Confirmation (with a save, after New run) | a black 0.5 shade that blocks clicks, then a centred panel: `Abandon the run in progress? It won't count.`, then the buttons `Yes, start a new run` and `No, keep it` | question 26 px ink on a paper panel; buttons 20 px, 16 apart; pops in with `UiKit.pop_in` |

**Behaviour that stays:**
- Without a save, a background click (or Enter or Space) starts a run.
- With a save, the background does nothing, Enter or Space continues (unless the confirmation is open), and only the buttons act.
- The first click or key press starts the front music, unless that press starts the run.
- The question uses the notice style, per the issue. Every button clicks (`ui_click`); No uses `ui_close`.

**Three states to mock up:** no save, with a save, and with a save plus the confirmation open.

**Decide with the user:**
- What the title shows besides the logo: a store scene (for example the store front or entrance, or the B2 counter after hours), or a plain backdrop.
- Whether it leaves room for a capsule-machine entry. #63 decides that entry; it is an open question there ("results only, or the title screen too"). Only reserve the space, don't design it.

The cut list says "simplify the title backdrop" if art runs long, so give one cheap option.

### 3.2 Impulse rack and `RewardPanel` (`ui/reward_panel.gd`)
There are two ways in, and they share the panel's parts.

**The impulse rack** (`show_rack`), before shift 1, over the shaded shift screen:
- The panel pops in at the centre (`UiKit.pop_in`: scale 0.7 → 1 in 0.22 s, TRANS_BACK, `ui_open`).
- It arms **350 ms** after it appears, once the mouse is up.
- Until it arms, Skip and View cart are disabled, the items can't be picked or scanned, and the top bar's Cart does nothing.
- The pop-in can't be skipped.

**The reward print-out** (`show_printout`, built by #61; its layout is **out of scope** but it is built from these parts):
- It sits on the stage right of the receipt, under the hung monitor (area top = monitor foot + 24).
- It has no headline. Its items lift out of the printer over 150 ms.
- Products wear a cosmetic tilted `PROMO` tag (tomato, 12 px, at sticker rect 52,4 52x20, 8° tilt).
- It arms when the lift ends and the mouse is up.

**Parts, top to bottom** (column gap 14, today a paper panel with a 4 px ink border, 12 px radius and 24 px padding):

| Part | Text |
|---|---|
| Headline (rack only) | `Impulse rack: grab one before shift 1?` (28 px ink) |
| Note | `Pick an item for your cart, or skip.`, or at the deck limit `Your cart is full: picking an item means removing one.` (16 px muted ink) |
| Red inspection warning (when the next shift is inspected) | `INSPECTION NEXT SHIFT: The 3rd product pays €0`, `INSPECTION NEXT SHIFT: One product slot fewer` or `INSPECTION NEXT SHIFT: One coupon slot fewer` (18 px tomato, to become the notice style) |
| Items | 3 tray items (`impulse_rack_size` = 3), each 108x168, 22 apart, so the row is 368 wide. The rack offers stocked products only (the newest new arrival in one slot); rewards include coupons |
| Buttons | `Skip` (`ui_back`) and `View cart (13/15)` (`"View cart (%d/%d)"`; it opens the deck view, which plays `fan`) |

**Fit test case (issue):** a 3-item offer with the warning **and** the deck-full note. In the real game the rack itself never shows a warning, because shift 1 is never inspected (inspections are on shifts 3, 5 and 7, announced at the previous checkout), and with the starter deck (13 of 15) it is never full either. The warning and the full note really appear on the **reward print-out**. Still, mock the panel parts with both so the fit is proven.

**Also leave room for:**
- The **NEW sticker** on the rack's items (#65; new arrivals). Rack items carry no PROMO, so the PROMO corner of the sticker is a natural spot. Flag this as a suggestion.
- The **scan popup** (288 wide) beside an item.

**Decide with the user:** whether the rack stays a styled `RewardPanel` pop-in, or becomes a rack prop by the register (an impulse-buy stand by the checkout: gum, batteries, a wire rack). The plan doesn't fix its look; section 7.2 says the shopping-list note is "at the register before the impulse rack". If it becomes a prop, the pop-in's length or end may change. Then `presented_ms` and `armed_ms` keep their meaning, but `docs/PROTOTYPE_PLAN.md` section 8 needs a changelog row (section 4.3).

### 3.3 Deck view and the remove-an-item chooser (`ui/deck_view.gd`)
The view opens over the shaded shift screen with a pop-in and `fan`, from the top bar's Cart, from View cart, or as the forced chooser. Today it is a teal `PANEL` with a 3 px cream border, a 12 px radius and 18 px padding.

**Header row:**
- The title: `Your cart (13/15)`, or in the chooser `Cart full (15/15): choose an item to remove for Birthday candles`. The longest name is the coupon `Breakfast sticker`.
- The tabs `Cart` and `Run info` (`ui_switch`). The active tab is shown as disabled.
- `Close` (`ui_close`).
- In the chooser the tabs are hidden and only the deck shows. Close stays visible: it cancels the pick and brings the offer back (`_on_deck_closed`).

**Cart tab** (a scroll area of `PAGE_SIZE`, page gap 6):
- A tag line: `Tags: Food 10  ·  Breakfast 8  ·  Produce 3  ·  Bakery 2  ·  Dairy 2` (starter deck; most common first, ties by name).
- `PRODUCTS  (12)` (mustard heading), then a grid of 8 columns with 8 px gaps. Each cell is one item per distinct card, with a 20 px line under it: `×3` for 3 copies, blank for 1.
  - Starter products, sorted by name: Banana ×3, Bread ×2, Coffee ×2, Eggs ×2, Milk ×2, Soup.
- `COUPONS  (1)`, then Final markdown.

**Run info tab:**
- `UPGRADES` (mustard), then `None yet.`, or one line per owned upgrade: `Slot engine (Slot Engine): Your 6th product pays ×2  ·  Only the 6th product (coupons don't count): the 7th with Big basket, the 5th on a Short belt shift; no effect with fewer`. This is the longest; it wraps.
- `INSPECTIONS`, with lines such as:
  - `This shift: no inspection.`
  - `This shift: Spot check, The 3rd product pays €0`
  - `Next shift: Short belt, One product slot fewer`
  - `Next shift: inspected (announced at checkout).`
- `STOCK  (every card a reward or the impulse rack can offer this run)`. Note that this player string still says "card".
- `Aisles: Cold cases, Pantry, Household`, then the stock grid (8 columns). New arrivals carry `NEW` under them; the issue calls this a "NEW mark".
- A full collection stocks about 22 products, up to 3 new arrivals and 9 coupons, roughly 34 cells or 5 rows. It scrolls.

**Behaviour that stays:**
- Clicking a card does nothing outside the chooser (arrow cursor). In the chooser, clicking picks one copy to remove.
- Scanning is off while the deck view is open.
- Closing returns to the offer or the tickets without replaying their presentation.

**`PAGE_SIZE`:**
- Today it is `(8 × 120 + 7 × 8 + 16, 500)` = **1032x500**. It holds the starter page unscrolled: tags 20 + heading 20 + a 190 row (168 card + 2 + 20 line) + heading 20 + a 190 row, plus four 6 px gaps, is about 464.
- With **tray items (108x168)** the row height is unchanged, so 500 still fits, and the width drops to `8 × 108 + 56 + 16` = **936**.
- With the issue's old 120x200 cards, rows would be 222 and the page about 528, so it would *not* fit. That is the issue's "new `PAGE_SIZE`" question. It is mostly moot if the deck view uses tray items; state that as the default and show the number.
- **Panel height limit (derived; verify):** `pop_in` centres panels on the 720 screen, and the top bar (y 0–56; the shade starts at 64) must stay visible and clickable. So a centred panel must be at most about **592 px tall**. Today's deck view is about 30 header + 12 + 500 + 36 padding + 6 border ≈ 584.

**Decide with the user:** whether the Run info tab (and the tickets, section 3.4) shows the **perk stamp**. Section 5.2 puts perk icons on the loyalty card; they come from #59, and until then the initials sit in the stamp ring.

### 3.4 Exit kiosk and the still ticket panel (`ui/upgrade_panel.gd`, `ui/upgrade_ticket.gd`)
The kiosk appears on upgrade shifts 2, 4 and 6, after the reward pick or skip (and any deck-full removal), over the shaded shift screen.

**Today:** a paper panel that pops in, with:
- `EXIT KIOSK: pick your prize` (28 px)
- `Pick one ticket. It goes on your loyalty card for the rest of the run.` (16 px muted)
- 1–3 tickets (`upgrade_offer_size` = 3), 22 apart.

**Each ticket** (`UpgradeTicket`, 230 wide, at least 230 tall, cream with a 2 px ink border; hover when armed gives a 4 px tomato border, which must move off tomato under the colour rule) shows the same fields in the same order:

1. **Name**, for example `Slot engine` (22 px ink).
2. **Type** in capitals: `SLOT ENGINE`, `CATEGORY ENGINE`, `COUPON ENGINE`, `ECONOMY` or `RISKY` (12 px teal). `RULE BENDER` exists, but Rule bender is out of the pool.
3. **Effect** (16 px).
4. **Condition**, on its own line (14 px tomato today). When there is none it reads `No condition` (muted), so the line keeps its place.
5. **`Supports: <builds>`**, at the bottom (13 px muted): for example `Supports: Breakfast special`, `Supports: Clearance collector, Bulk buyer` or `Supports: Any build`.

**Rules:**
- Tickets are fully revealed. At most a cosmetic `INSTANT WINNER!` gag, never a hidden face.
- **No skip button**; the pick is compulsory.
- Tickets arm 350 ms after the show, once the mouse is up, and are 80% alpha until then. The top bar's Cart waits (`is_arming`).
- Cart during the kiosk hides the tickets; closing the deck view brings them back without a replay.
- The kiosk sells nothing and must **look different from the capsule machines** (#63; coin-op toy machines with figurines, one per aisle at the store exit). Both are props at the store exit.
- #66 animates it later: the torn receipt goes in, tickets drop, and the picked ticket flies to the loyalty box. The static prop must survive if #66 is cut (it is first on the cut list).
- The prop must leave a place for the receipt to go in. The red inspection notice prints before the kiosk; whether it stays readable during the pick is #66's question.

**Decide with the user:** the kiosk's look, and how the ticket panel sits in it: tickets dispensed into a tray, clipped on its front, or standing in its window. Also whether tickets show the perk stamp (from #59).

### 3.5 Results / final receipt (`ui/results_panel.gd`, `ui/final_receipt.gd`)
**#61 already landed.** The issue's `RunHistoryView` and `CoinReceipt` no longer exist. The results screen is the run's **final receipt**: a paper panel (4 px ink border, 12 px radius, 20 px padding) over the shaded shift screen. #61 owns the receipt's layout and where the history sits. #56 styles:
- the `RUN WON!` / `RUN OVER` headline: 44 px, green (`GOOD`) or tomato
- **New run**: armed 350 ms after showing, once the mouse is up; clickable mid-print
- **Export log** (it confirms itself)
- the history's text.

**Keep:**
- the words `pass` / `fail` and WON / OVER
- the mono font (JetBrains Mono, 16 px lines, 13 px dim detail lines)
- the 44-character column width (`FinalReceipt.WIDTH`).

**Print behaviour:**
- Lines print one by one every 80 ms; a tap prints the rest at once.
- Coins clink, at most 15 sounds.
- The loyalty card is stapled to the top-right corner beside the headline (staple 20x5, muted ink) and covers no line.

**Fixed sample: a won run.** Real quotas 34, 35, 53, 61, 73, 98, 111, 120. Upgrades taken on 2, 4 and 6; inspections on 3, 5 and 7. Strings are exact; the mono columns are `"%3d  %-13s  %-4s  %s"`.

```
RUN WON!
--------------------------------------------
  1  €41 / €34      pass  Tea bags
  2  €52 / €35      pass  Multipack
     upgrade Coupon engine
  3  €60 / €53      pass  skipped
     inspection Spot check
  4  €88 / €61      pass  Strawberries
     upgrade Slot engine
  5  €95 / €73      pass  2 for 1
     inspection Short belt
  6  €131 / €98     pass  Croissant
     upgrade Big basket
  7  €140 / €111    pass  Birthday candles
     inspection Coupon slot closed
  8  €151 / €120    pass  —
--------------------------------------------
Shifts passed 8                           +2
Overtime €173                             +0
COINS +2                          you have 5
```

**A lost run** (RUN OVER, red):
- Shifts 1–5 pass, then `  6  €86 / €98      fail  —`, with tomato fail lines and tomato-dim detail lines.
- Then the shortfall line `Shift 6 / 8: short by €12`.
- Coins: `Shifts passed 5 … +1`, `Overtime €… +0`, `COINS +1 … you have 4`.
- When the profile can't be saved, the last line ends `you have ?`.

**Tones:** rules muted ink; the COINS total line teal; detail lines at 55% alpha.

### 3.6 What the shift screen shows behind the panels
- The rack, deck view, kiosk and results sit over the shift screen, under `ScreenShade` (black 0.5) from y 64.
- The top bar stays unshaded and clickable (Cart, ☰).
- Only beside the reward print-out are the register column and the monitor left unshaded (#61/#80).
- Mock these screens over the real mirrored B2 scene, shaded, unless an option deliberately turns the panel into a prop *in* the scene (a rack by the register, a kiosk at the exit). The title is the only full-screen scene of its own.

### 3.7 Longest texts, to prove fit
- **Upgrade tickets** (in the pool: Coupon engine, Category engine, Extra redraw, Slot engine, Extra coupon slot, Big basket). Use the triple **Slot engine + Big basket + Category engine** (three different types, as the offer rule requires):
  - Slot engine / SLOT ENGINE / `Your 6th product pays ×2` / `Only the 6th product (coupons don't count): the 7th with Big basket, the 5th on a Short belt shift; no effect with fewer` / `Supports: Breakfast special`
  - Big basket / RISKY / `+1 product slot` / `Your quota is 15% higher from the next shift (rounded up)` / `Supports: Clearance collector, Bulk buyer`
  - Category engine / CATEGORY ENGINE / `+3 for each different tag among your products` / `Paid on the last product in the row` / `Supports: Mixed basket`
  - Also show a `No condition` ticket somewhere: Extra redraw / ECONOMY / `+1 redraw each shift` / `No condition` / `Supports: Any build`.
  - Other conditions: Coupon engine `Only the first coupon, and only if it pays something`; Extra coupon slot `Only a coupon can use it`.
- **Inspection notices** (`notice_text`): `The 3rd product pays €0`, `One product slot fewer` and `One coupon slot fewer` (the longest), each after `INSPECTION NEXT SHIFT: `. Names: Spot check, Short belt, Coupon slot closed.
- **Item names:**
  - longest product: `Birthday candles`
  - longest coupon: `Breakfast sticker`
  - others: `Flickering bulb`, `Reduced yogurt`, `Bruised apples`, `Day-old buns`, `Pick 'n' mix`.
- **Sticker summaries:**
  - longest: `+2 per earlier Clearance` (Dusty toffees), `+3 beside Clearance` (Reduced yogurt)
  - coupons: `Same both sides: 2nd ×2`, `×3 later with prior's tag`.
- **Builds:** Breakfast special, Bulk buyer, Clearance collector, Coupon specialist, Mixed basket.
- **Aisles** (`sign_color`):
  - Bakery #d2a874
  - Cold cases #4f9a94
  - Fruit & veg #3d7a45
  - Household #8a8172
  - Pantry #e2b33c
  - Snacks #7a5232.

## 4. Constraints from the plans

### 4.1 `docs/FULL_BUILD_PLAN.md`
- **§2 scope:** the screens are title, run start (shopping list, impulse rack), shift, reward print-out, upgrade choice (exit kiosk), deck view, results / final receipt (with coins), capsule machines and figurine shelf, settings and pause. Settings and pause are phase 4, so leave them out. The run has 8 shifts, a 15-card limit, and 6+1 slots.
- **§5.2:** upgrades live on the loyalty card; each stamps one box and shows its perk icon. The kiosk drops up to 3 prize tickets, fully revealed, and sells nothing. It is a separate prop from the capsule machines. Every ticket has the same fields in the same order. There is no skip.
- **§6.1 art pipeline:**
  - Pixel art at 1 art px = 2 canvas px, through the sharp-pixel shader.
  - Frames are 9-slices with stretching edges; a patterned frame is drawn at full size.
  - The palette, the fonts by role, the glyph test.
  - Every frame, icon and prop is a palette-indexed text source in `art/src/`, built by `tools/pixel_art.py`, logged in `art/src/production_log.tsv` and reviewed by the user.
  - Colour is never the only signal. Brands are fictional. One sprite per item, reused everywhere.
  - The shared kit: `UiKit` helpers (not a Theme), framed buttons, the notice style. #55's note says "the other panels follow in #56".
  - Player strings say **Cart** and **item**, not deck and card (code, data and telemetry keep "deck").
  - The capture tool `debug/screen_capture/` writes `docs/art/` captures; #56 adds the other screens.
- **§6.2:** the reward print-out (dessert 700–850 ms; promo products; the warning kept) and the final receipt (80 ms lines, coins, the stapled loyalty card, the New run arm) are decided and owned by #61. #56 restyles their parts only. The budget is about 1.2 s to the kiosk choice; longer variants play once per profile (#66). Reduced motion means nothing shakes and things fade in place. No information may be shown only inside an animation.
- **§7.1:**
  - Capsule machines: one per aisle at the store exit, coin-op toy machines. 1 coin = 1 capsule. Never say "gacha". They are separate from, and look different to, the exit kiosk.
  - Coins print at the bottom of the final receipt; the title shows the total.
- **§7.2:** the shopping-list note is "a note at the register before the impulse rack" (#65). The NEW price sticker goes on new arrivals (#65).
- **§10, cut list:** if art runs long, reuse frames and icons and simplify the title backdrop. The kiosk ceremony (#66) is cut first; then #56's static kiosk and still ticket panel are what players see. **The screens stay.** Never cut the counting presentation or the dessert.
- **§11:** the Steam store page waits for the final look (#43), so these screens are store-page material. There are no microtransactions; the machines are never called gacha.
- **§12:** the framing is the customer loyalty card (#55), not a staff timecard. Section 12 has no open decision for #56.

### 4.2 Issue #56's scope (summary)
**In scope:**
- panel frames in `art/src/frames/` replacing every placeholder `StyleBoxFlat` (`UiKit.paper_panel`, `RewardPanel`, `ResultsPanel`, `UpgradePanel`, `UpgradeTicket`, `DeckView`)
- items in place of `CardView` in the deck view and chooser
- the title restyle
- the rack and the reward panel's parts
- the deck view (re-measure `PAGE_SIZE`)
- the kiosk prop with the still tickets
- the results' headline, buttons and text
- a capture scene in `debug/` writing each screen at 1280x720 and 1920x1080.

**Out of scope:**
- the print-out and final receipt layouts (#61)
- the kiosk ceremony (#66)
- the capsule machines and shelf (#63)
- the list note and the NEW sticker (#65; only leave room)
- sounds (#62)
- settings and pause (phase 4).

**Fit tests the layouts must pass:**
- title without a save, with a save, and with the confirmation
- a 3-item offer with the warning and the full note
- the starter page unscrolled, and a full-collection stock in the scroll area
- the kiosk with 3 tickets of the longest texts
- an 8-shift history with coins.

Every panel's rect must sit inside 1280x720, and its buttons must not overlap.

### 4.3 `docs/PROTOTYPE_PLAN.md` §8, "Offer presentation times"
- `presented_ms` is the end of the pop-in (0.22 s of game time) for the rack and the tickets, and the end of the 150 ms lift for a reward print-out.
- `armed_ms` is 350 ms after the show, once the mouse is up, for the rack and the tickets. For the print-out it is when the lift ends and the mouse is up.
- `presentation_skipped` stays false for the rack and the tickets, because their pop-ins can't be skipped.
- Until an offer arms, the top bar's Cart does nothing.
- An offer shown again after the deck view or the chooser keeps its first timeline.
- These keep their meaning. **If a mock-up option changes the pop-in's length or end** (for example a rack that slides in, or a kiosk that dispenses), the option must say so: building it needs a §8 changelog row and the unchanged-times tests updated. The target is about 15 s or less of non-interactive offer time per run (the sum of `armed_ms`).

## 5. Decisions to put to the user (the mock-ups illustrate these)
Keep it to about 4 real choices, each with a recommendation; everything else is a stated default.

1. **Title backdrop:** a store scene (for example the store front at opening, or the B2 counter after hours with the logo as a shop sign) versus a plain backdrop with a logo. Should it reserve a spot for the capsule machines' entry (#63)?
2. **Impulse rack:** a styled `RewardPanel` pop-in (the same parts as the print-out) versus an impulse-buy rack prop by the register.
3. **Exit kiosk:** its look (a ticket-dispensing prize kiosk or a raffle drum, clearly not a coin-op capsule machine) and how the tickets sit in it.
4. **Perk stamp** on the tickets and the Run info tab (needs #59), or text only.

**Stated defaults** (the mock-ups assume these unless an option says otherwise):
- The deck view and chooser use tray items (108x168). `PAGE_SIZE` becomes about 936x500, and the starter page fits unscrolled.
- Paper and receipt panels become new 9-slice frames.
- Every button becomes a framed button: primary actions (Continue, New run, Yes) on `button.png`; secondary ones (Skip, View cart, Export log, No, Close, tabs) on `sign.png`. The kiosk has no buttons.
- The inspection warning and the abandon question take the notice style, with the mustard warning triangle (`art/icons/warning.png`) beside the warning, so colour is not the only signal.
- Ticket hover moves off tomato (to a mustard ring or a lift).
- The results keep #61's layout. Only the headline, the buttons and the history's tones are restyled.
- `NEW` stays text in the Run info tab until #65's sticker.

## 6. Deliverable per mock-up agent
- One or more HTML pages per option, plus a 1920x1080 capture of each state listed for its screen.
- A short header comment in each page saying:
  - the option's idea
  - which parts would be new `art/src/` sources (frames, icons, props)
  - any change to presentation timing
  - which texts are the longest-case fit check.
- Make no claims about game behaviour beyond section 3. Where a mock-up implies a behaviour change, label it as such.
