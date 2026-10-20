# #56 decide list: the screens outside the checkout

Decide prep, 2026-10-19. Nothing is decided. The mock-ups are on one page,
`docs/art/mockups/screens_index.html` (capture: `screens_index_1920x1080.png`). Every page sits next to its
1920x1080 capture. The shared brief is `screens_src/BRIEF.md`.

There are four real questions (Q1 to Q4). Everything after them is a stated default: say so if you want one changed.

## Before the questions: what changed since the issue was written

- **Items replaced cards (#75).** `ArtCardView` (120x200) no longer exists. Offers already show tray items
  (`ItemView` TRAY, 108x168: a 96x96 sprite over a `PriceSticker`). Only the deck view and the chooser still use the
  plain 120x168 `CardView`. So "switch to `ArtCardView`" now means "switch the deck view and chooser to tray items".
- **#61 already landed.** The issue's `RunHistoryView` and `CoinReceipt` are now the final receipt (`FinalReceipt` in
  `ResultsPanel`). #56 only restyles the headline, New run, Export log and the text tones. The receipt layout,
  44-column mono and print timing stay as #61 built them.

## PAGE_SIZE finding (the issue's phase 1 question goes away)

- Today: `PAGE_SIZE = (8 x 120 + 7 x 8 + 16, 500)` = **1032x500**. The starter page is about 464 px tall, so it
  fits.
- With tray items, a cell is 108x168, plus a 32 px caption (name, xN, NEW), so 108x200. The starter page is
  tags 20 + heading 20 + row 200 + heading 20 + row 200 + 4 gaps of 6 = **484 ≤ 500**: it fits without scrolling.
  The new size is **936x500** (8 x 108 + 7 x 8 + 16).
- The issue assumed 120x200 cards with today's separate 20 px count line. That gives rows of 222 and a page of
  528, which would **not** fit. Tray items avoid the problem, so the height stays 500.
- **Panel height limit (derived):** `pop_in` centres panels on the 720 px screen, and the top bar (y 0–56, shade from
  64) must stay clickable. So a centred panel is at most **592 px** tall. Deck A is exactly 592, deck B is 584, rack A
  is 414. Option props that stand on the floor (kiosk A and B, rack B) are not centred pop-ins, so the limit does
  not apply to them; they keep the top bar clear by layout instead.
- **Default:** `PAGE_SIZE` becomes `Vector2(8 * ItemView.TRAY_SIZE.x + 7 * GAP + 16, 500)`, and the full-collection
  stock (about 34 cells, 5 rows) scrolls.

## Q1. Title backdrop (and the #63 capsule-machine spot)

| Option | Pages | What it is |
|---|---|---|
| **A: store front at night** | `screens_title_a`, `_nosave`, `_confirm` | The supermarket front seen from the pavement: lit rooftop sign as the logo (brass frame, chasing bulbs), teal-and-cream awning, stocked windows, the cashier at her register through the open doors. Subtitle and coins on a taped paper notice. The buttons stand on the lit pavement. A lit spot by the right window is reserved for #63. |
| **B: giant receipt** | `screens_title_b`, `_nosave`, `_confirm` | A plain dark-teal backdrop with one long receipt hanging from the register's printer. The logo is printed as its header, the subtitle is in receipt mono, the coins are a gold price-gun starburst, and the loyalty card is stapled to the corner. The space on the right is reserved for #63. This is the cut-list option. |

**Recommendation: A**, with B kept as the cut-list fallback. Reasons:

- The title is the first frame on the store page (§11, #43), and the user's notes favour a believable store with
  physical objects over flat panels.
- A introduces the cashier and the store before the first shift. B is clean but flat, which is what playtesters
  complained about (fb-p2).
- Both reserve a spot for #63 without designing it.

Risk: A's window stock is drawn at half the pixel scale of the front. In `art/src` it has to become one
`store_front_interior` sprite drawn at that scale, otherwise the mixed scales show. This is the most expensive art
in #56. Also, Pixelify draws "(" and ")" like braces in "Continue (shift 3 / 8)". That comes from the font, so it
affects both options. A possible fix is the number font for the bracketed part.

## Q2. Impulse rack: styled panel or a prop by the register

| Option | Pages | What it is |
|---|---|---|
| **A: styled `RewardPanel` pop-in** | `screens_rack_a`, `_start`, `_scan` | Today's parts in today's order, on a paper frame with a teal shop-sign header strip (brass rivets). The items stand in a recessed teal display niche on a steel shelf whose rail holds the price stickers (the belt's rail again). The panel is 600x414 and centred. |
| **B: wire rack prop at the checkout** | `screens_rack_b`, `_start`, `_scan` | A free-standing impulse-buy rack (velvet and brass header, teal pegboard, steel shelf) at the belt's customer end. Skip and View cart hang from its crossbar. The note and the inspection warning print on the hung monitor. |

**Recommendation: A.** Reasons:

- It changes no behaviour and no timing: same 0.22 s pop-in, armed at 350 ms, no §8 changelog row.
- #61's reward print-out is built from the same parts, so styling the parts once serves both.
- The shelf niche and rail already make it read as store fixtures rather than a form.

B is more physical, but it changes behaviour (the monitor stays on during the offer and carries the note and
warning), it cuts belt slot 4 in half, it barely stands out from the lighter 0.35 shade, and it is front-on with no
perspective. Open point for A, which you may decide: the centred panel cuts the shaded monitor's "No inspection
this shift" line in half. The fix is either to switch the monitor off during the rack (recommended, no layout
change) or to offset the panel's anchor.

## Q3. Exit kiosk: its look and how the tickets sit in it

| Option | Pages | What it is |
|---|---|---|
| **A: lottery ticket dispenser** | `screens_kiosk_a`, `_hover` | A velvet-and-brass lottery kiosk with a chasing-bulb marquee ("EXIT KIOSK / pick your prize"), wheeled in front of the shaded checkout. The three prize tickets hang from its dispenser mouth like scratch tickets torn off a roll (perforated stub, serial number, gold inner frame). The lower panel has a RECEIPT IN slot for #66 and a ticket-roll window. Hover: the ticket lifts in a gold ring, an INSTANT WINNER! foil sticker goes on its stub, and the next LOYALTY box lights up. |
| **B: photo-booth prize printer at the exit** | `screens_kiosk_b`, `_hover` | The camera cuts to the store exit (sliding doors, EXIT sign, plaster wall, tiled floor). A teal booth with a velvet curtain holds printed tickets on brass bulldog clips. #63's corner is outlined on the right. Hover: the clip springs open, and INSTANT WINNER! lands as a rubber stamp. |

**Recommendation: A.** Reasons:

- It needs no extra full-screen backdrop and no camera cut, so the deck view (Cart) still opens over the familiar
  checkout.
- Timing is unchanged: the same pop-in, tickets armed at 350 ms, no §8 row.
- It looks unlike a coin-op capsule machine (no globe, no crank, no coin slot), and the RECEIPT IN slot gives #66
  its hook.
- If #66 is cut, A still reads as a prize kiosk on its own.

B's camera cut is a nice "you're leaving the store" beat, but it costs a backdrop, timing and deck-view questions,
and its large teal front is the flatter look. Known issue with A: the cabinet hides the receipt and cuts
"CHECKOUT" mid-word. It is shaded, but a reviewer may read it as a panel with props on it.

Both directions apply the same ticket rules:

- The fields come in the same order: name, TYPE, effect, condition (or "No condition" in muted italics), "Supports: …".
- The condition text moves off tomato, to ink-light under a dotted rule.
- The hover ring is gold, not tomato.
- There is no skip and there are no buttons.

The tickets have about 100 px of empty space when the condition is short. That is fine; the tallest ticket (Slot
engine) sets the height.

## Q4. Perk stamp on the tickets and in Run info (#59 dependency)

| Option | Shown in | What it is |
|---|---|---|
| **Yes (stamp ring)** | kiosk A (by each ticket's name), deck A Run info (beside each upgrade) | The same 13x13 mustard stamp ring as the top bar's LOYALTY chip. Until #59 draws the 7x7 perk glyphs, it holds the initials ("SlE", "BiB", "CaE"). |
| **No (text only)** | kiosk B, deck B Run info | Name and type only. The stamp appears only on the loyalty card. |

**Recommendation: yes.** Reasons:

- The ticket is what goes on the card, and the matching ring links the pick to the stamp it becomes. That is the
  one visual cue for "it goes on your loyalty card".
- It reuses `icons/stamp_ring.png` and the initials fallback the LOYALTY chip already uses, so #56 does **not** wait
  on #59. #59's glyphs drop in later through the same `stamp_ring` code path.

Cost: one ring per ticket and per Run info line, plus a fit check that the name still fits beside the ring. The longest
name, "Category engine", fits at 22 px in the 230 px ticket.

## Stated defaults (one line each)

- **Deck view look: B, the teal hand basket on steel shelves.** Copies stand stacked behind the first and wear a cream "×N" price-gun label (the loved sticker device). NEW stays plain text (#65 owns the starburst), stacked copies are dimmed with a modulate, and "Remove 1" is dropped because it is not game text. Alternative: A, the clipboard with clear pockets and binder tabs. Its tabs stick out over the scene.
- **Deck view and chooser use tray items (108x168) with a 32 px caption.** `PAGE_SIZE` 936x500 (see above); Close stays visible in the chooser and cancels the pick.
- **Results look: A, the end-of-day till report on the counter.** No camera cut. The register stays unshaded, and its keys relabel: CHECKOUT becomes **New run**, Redraw becomes **Export log**. The arming shows as the key's existing `_off` face. Alternative: B, the staff noticeboard. It needs a new full-screen backdrop, and its time clock leans towards staff framing, which §12 rules out.
- **Results decor:** a gold sparkle by RUN WON! (won runs only), the mustard band on the COINS line, `mark_check` and `mark_fizzle` in a gutter right of column 44. pass/fail and WON/OVER stay as words.
- **Buttons:** every button becomes a `FramedButton`. Primary (Continue, New run, Yes, start a new run) on `button.png`; secondary (Skip, View cart, Export log, No, keep it, Close, tabs) on `sign.png`.
- **Notices:** the abandon question and the inspection warning use the notice style (tomato Atkinson 16 px plus `warning.png`), so colour is never the only signal.
- **Timing:** no option above changes `presented_ms` or `armed_ms`. Rack A and kiosk A keep the 0.22 s pop-in and the 350 ms arm, so `docs/PROTOTYPE_PLAN.md` §8 needs no row.
- **NEW sticker room (#65):** left on the price sticker's PROMO corner on rack items (rack items never carry PROMO).
- **Capture scene:** `debug/screen_capture/` gains `--capture=title|title_save|title_confirm|rack|deck|deck_info|deck_chooser|kiosk|results|results_over` at 1280x720 and 1920x1080 into `docs/art/`.

## New frames, icons and props per direction (the art budget)

Every item is a palette-indexed source in `art/src/`, built by `tools/pixel_art.py`, logged in `production_log.tsv`
and reviewed by you. **Bold** = in the recommended set.

| Screen | Recommended (new sources) | Alternative (new sources) |
|---|---|---|
| Shared | **frames/paper_panel** (9-slice, replaces `UiKit.paper_panel` and the confirmation panel) | – |
| Title | A: **scenery/store_front** (facade, awning, doors, pavement), **scenery/store_front_interior** (stocked windows at half scale), **scenery/rooftop_sign** (brass 9-slice + bulb strip), **logo_title** (sprite), **frames/notice** (taped paper 9-slice) | B: frames/receipt_tall (torn-edge paper), frames/printer_slot, effects/sticker_burst_big, logo_title |
| Rack | A: **frames/offer_panel**, **frames/offer_header** (teal sign strip, brass rivets), **frames/offer_shelf** (niche + rail, 3-band tile) | B: scenery/impulse_rack (one prop), frames/rack_header (velvet + brass) |
| Deck | B (default): **frames/basket_panel** (teal basket 9-slice, rim, slot holes, cart badge), **scenery/shelf_rail** | A: frames/clipboard, frames/sheet, frames/pocket, frames/tape, frames/tab_paper, scenery/board_clip |
| Kiosk | A: **scenery/kiosk_lottery** (cabinet, marquee, mouth, roll window, receipt slot; drawn once at 1x), **frames/kiosk_ticket_lottery** (stub + gold inner frame), **effects/instant_winner** (foil sticker) | B: scenery/exit_backdrop (full screen), scenery/kiosk_booth, frames/kiosk_ticket_print, icons/bulldog_clip, effects/instant_winner_stamp |
| Results | A (default): **frames/till_report** (torn top and bottom), **icons/coin** (9x9), **effects/sparkle_gold** (9x9; the existing `sparkle.png` is too pale on paper) | B: scenery/noticeboard (cork + wood 9-slice), scenery/time_clock, effects/headline_stamp, icons/push_pin, icons/coin |
| Perk stamp | Yes: nothing new in #56 (reuses `icons/stamp_ring.png` and the initials); the 7x7 glyphs are #59's | – |

Count: the recommended set has **15 new sources** (1 shared + 5 title + 3 rack + 2 deck + 3 kiosk + 3 results). The
largest are store_front, store_front_interior and kiosk_lottery. With title B instead, the title drops to 4
smaller sources, which is the cut-list fallback.

Already in use and reused: `button.png`, `sign.png`, `warning.png`, `stamp_ring(_empty).png`, `loyalty_card.png`,
`mark_check`, `mark_fizzle`, `sticker_label`, `sticker_burst`, `sparkle`, `cashier`, `ceiling_lamp`, shelf props,
item sprites, `key_checkout(_off)` and the cream key face.

## Build plan sketch (after the decisions)

Each step ends with `sh tools/check.sh` on the changed scripts and `sh tools/test.sh`. You play each screen's capture
before any commit (`ui-tests-check-layout`).

1. **Art sources, part 1 (shared + rack + deck):** paper_panel, offer_panel, offer_header, offer_shelf, basket_panel and shelf_rail in `art/src/frames/`, then `python tools/pixel_art.py build`, `check`, `sheet` for review, and `sh tools/import.sh`.
2. **Kit:** `UiKit.paper_panel` moves onto the frame. Every `UiKit.button` on these screens becomes a `FramedButton` (primary or secondary). The notice style goes on the abandon question and the warning.
3. **Rack and `RewardPanel` parts:** header strip, shelf niche, rail stickers and the NEW corner reserved. The pop-in and the 350 ms arm stay untouched, and the monitor goes off during the rack if you approve.
4. **Deck view and chooser:** tray items replace `CardView`. Add the caption row (name, ×N, NEW), the new `PAGE_SIZE`, the basket frame, stacked copies, the Run info stamp rings (Q4) and the chooser keeping Close.
5. **Kiosk:** kiosk_lottery prop, ticket frame, the field order with "No condition", the condition off tomato, the gold hover ring, the INSTANT WINNER! sticker and the stamp ring. No buttons.
6. **Results:** till_report frame, headline styling with the gold sparkle, the register keys relabelled to New run and Export log (the arm shows as the `_off` face), the coin band and the gutter marks.
7. **Title:** store_front set, rooftop sign, logo, taped notice, the #63 spot left empty, the confirmation on paper_panel. The behaviour stays: a background click starts only without a save; Enter or Space continues.
8. **Capture scene:** the `--capture=` states above, written at both sizes into `docs/art/`.
9. **Docs:** a playtest-facing changelog row in `docs/FULL_BUILD_PLAN.md`, and the frames and kiosk look recorded in §6.1. `docs/PROTOTYPE_PLAN.md` §8 is untouched unless a timing changed.

**Tests (from #56):**
- Update `title_screen_test`, `deck_view_ui_test`, `upgrade_ui_test`, `impulse_rack_ui_test`, `offer_timeline_ui_test`, `profile_ui_test` and `save_resume_ui_test`.
- Geometry: each panel's or prop's `get_global_rect()` sits inside 1280x720, its buttons don't overlap, and centred pop-ins are ≤ 592 tall. Cases:
  - the title without a save, with a save, and with the confirmation
  - a 3-item offer with the warning and the deck-full note
  - the starter deck page unscrolled (content ≤ 500) and a full-collection stock scrolling
  - the kiosk with Slot engine + Big basket + Category engine
  - an 8-shift won history with coins, and the lost run
- A ticket fit test like the old `art_card_view_test`: with the real fonts, every upgrade's ticket fields, plus the stamp ring beside the name, and every inspection's `notice_text` fit their boxes.
- `ArtStyle.REQUIRED_GLYPHS` covers every string these screens print.
- `presented_ms` and `armed_ms` are unchanged for the rack and the kiosk.
- `CardView` is gone from the deck view and chooser, and no placeholder `StyleBoxFlat` is left in `RewardPanel`, `ResultsPanel`, `UpgradePanel`, `UpgradeTicket` or `DeckView`.
- Any new `.tres`/`.tscn` folder is added to `tests/resource_loading_test.gd`.
