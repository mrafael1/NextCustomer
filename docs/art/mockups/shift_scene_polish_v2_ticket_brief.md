TICKET BRIEF FOR THE MOCK-UP BUILDER (shift screen price tickets, #-polish round 2)

Context: the user saw the first proposal (taller 108x76 tickets, bigger rule text, zones "shelf-edge label" and "icon column") and said: "not a fan of ticket improvement. still feel unpolished, not sure what is missing." Don't make the ticket bigger. Keep the slot at 54x32 art px (108x64 screen, ART_SCALE 2) and fix the finish. All coordinates below are art px, and the outline is at x0/x53, y0/y31. Palette keys come from art/src/palette.txt. Light comes from the top left.

Verified against now_planning.png (zooms) and the NC-clarity code:

== 1. WHAT IS MISSING (ranked by polish payoff) ==

1. The ticket mixes two pixel resolutions. The face, outline, bevel and glyphs are hard 2x2 blocks. Every word and number is smooth 1x anti-aliased type: Atkinson 800 13 px rules (TICKET_TEXT_SIZE), 22/21 px burst digits (BURST_PRICE_SIZE), 15 px struck price (STRUCK_PRICE_SIZE), and the pay tag's warning sign, which is drawn at 1x (pay_tag.gd WARNING_AT). Zoomed in, "€14", "€21", "€4" and "+1 per earlier" have soft fringes next to crisp 2 px ink. This mix is most of what reads as unfinished.
   Fix: draw every number on a ticket from a new hard-pixel digit sheet (art/src/price_digits.txt). Big digits are 4x7 art ("1" is 3 wide), the € is 3x7, with 1 art of gap. Mini digits are 3x5. Draw them at 2x with nearest filtering. Atkinson stays for rule words only, with baselines on even screen y, no outline and no shadow. Redraw the warning sign at 2x.

2. AA text sits on saturated family colour. Ink Atkinson on mustard e2b33c and tomato-light ec8a6e makes muddy off-palette fringes. The coupon ticket (ink on paper w) is the only one that reads cleanly in the capture.
   Fix: rule text always goes on paper w fbf7ee or cream c f3e9d2. The family colour moves to a band that holds only glyphs and hard pixels.

3. The price has 4 different objects and no fixed place. They are a white plain tag (PLAIN_TAG_AT 60,-4), a gold starburst (about 60x32), a tomato "warning €0" tag and a tomato "scissors €0" tag. All of them poke 2-6 px above the ticket into the rail and quota light. The struck price also jumps between STRUCK_TOP 26 and STRUCK_BESIDE_TOP 6.
   Fix: one inset PRICE WINDOW at a fixed rect. It changes state only by fill and digit colour and never overhangs in planning. The burst appears only during the count, blooming behind the window.

4. Gold on gold. The projected-price bursts (€21/€48/€63) are gold on mustard tickets. Only the burst's paper rim separates them, so the most important number has the weakest edge.
   Fix: this is solved by item 3's window (paper or pale fill, ink or brass-dark outline) on every family colour.

5. The struck base price reads as part of the rule. The 15 px "€4" sits on the same baseline as "+1 per", in the same ink, so it reads as "+1 per €4 earlier".
   Fix: show the base price as mini 3x5 digits in grey dark `=` 5e574d, in a fixed spot right under the window, with a 1 art R d9534f strike.

6. Halos everywhere. Every glyph (header and inline) wears a paper ring plus an ink ring, which adds up to 3 white blobs per ticket and 15+ across the belt. It is the same look as the effect stickers above the items, so ticket and sticker blur together.
   Fix: ticket glyphs get an ink outline only, with no paper ring. Rings stay for stickers, talkers and the burst, which sit over other surfaces.

7. No material and no mounting. ticket_face.gd draws a pillow bevel (light top row, shade right and bottom), the same treatment as the CHECKOUT and Redraw buttons. The ticket casts no shadow, while the pay tags cast one (SHADOW_OFFSET 3,3, alpha 0.42), so the light is inconsistent. The top and bottom edges are 4 px of ink (rail ink plus ticket ink, measured at x=626, rows 456-459 and 520-523), while the sides are 2 px.
   Fix: die-cut paper with 2-px rounded corners (cut the corner pixel and its 2 neighbours). Add a 1 art drop shadow of ink 2b2420 at 35%, offset (1,1), the same as the price objects. Make every edge a single art px of ink: the ticket's top and bottom outline rows replace the rail channel's ink lines instead of stacking on them.

8. Uneven density, and no tier on the ticket. The plain Bread ticket is about 60% empty face. The coupon is packed edge to edge. A GOLDEN item (the gold-rimmed Bread sprite) has an ordinary ticket.
   Fix: a plain product prints its name (and optionally a barcode) on its paper. GOLDEN and BIG show as material (gold band or frame), never as text, because the user removed the tier text tag.

== 2. THREE DIRECTIONS TO MOCK UP ==

Draw each direction as the same 7-ticket belt row as the capture (Eggs, Bread, Milk on the €0 Spot check slot 3, Multipack coupon, Milk €21, €48, €63), plus a STRESS ticket. The stress ticket is a GOLDEN Milk with 3 family glyphs, a boosted pay of €128, the struck old price €4, and the 2-line rule "+1 per earlier [breakfast glyph]". Also show each direction mid-count: the burst on the €128 ticket.

--- A. Shelf-edge label (RECOMMENDED) ---
Pitch: the white shelf-edge label every cashier knows. It is paper die-cut and clipped into the steel rail, with a family-colour band on top and a fixed price window. Ink sits on paper for all text, so it gets the palette's strongest contrast. Five mustard cards in a row then read as five labels, not one yellow strip.

- Body: 54x32. Outline 1 art ink #, with 2-px die-cut corners. Shadow: ink at 35%, offset (1,1).
- BAND y1-10: family light on row y1, family face on y2-9, family shade on y10. A split ticket draws today's 45° stair inside the band only.
- Header glyphs: 9x9, ink outline, no ring, at x2, x11, x20, y1. A 3rd glyph ends at x28.
- PAPER y11-29: c on row y11 (the paper's top edge), w body, b ddcba5 on row y29 (thickness). Row y30 is a 1-row lip in family shade.
- PRICE WINDOW x30-52, y1-12. It starts in the band and hangs 2 rows into the paper, like a tag clipped to the band. 1 art ink outline, with a 1 art b inset on the inner top and left.
  - Digits: big 4x7, right-aligned 1 art inside the window, rows y4-10.
  - "€128" is 3+1+4+1+4+1+4 = 18 art wide and fits the window's 21 inner px with no shift, so the 3 glyphs never squeeze or hide.
  - Window states:
    - base: w fill, # digits
    - boosted (projected > base): Y faecbc fill, k 4a3010 digits, 1 art n ffcf3f top highlight row
    - lowered: O f5bfa0 fill, r a83a3c digits
    - €0: R fill, w digits
- STRUCK base price: mini 3x5 digits in `=`, right-aligned to x51, rows y14-18. 1 art R strike on row y16, running 1 px past each end. Shown only when the shown price differs from the base price.
- RULE: Atkinson 800 13 px, ink, 15 px pitch, 2 lines in screen box x6-104, y28-58. Line 1 ends at screen x84 when the struck price is shown. Fall back to 12 px, never 3 lines. Inline target glyph: 7x7, ink outline, no ring.
- PLAIN product: its name in Atkinson 700 13 px `=` on line 1, plus a 16x5 ink barcode (bars 1,1,2,1,1,3,1,2) at screen x6 on line 2.
- GOLDEN: band face n, shade row L c8932b, light row y. The outline turns l 8a5d1a instead of ink, and so does the window's outline. Add a 3x3 sparkle (w centre, n arms) on the top-left corner. Optional glint: a 3-art w diagonal crosses the band in 0.35 s every 5 s, with a random phase per ticket.
- BIG: band row y1 in n. No text.
- COUPON:
  - Band in teal shade 3 3a7672, with "COUPON" in hard Pixelify (PIXEL_TEXT_SIZE 11, like the rail labels) in w at x2. A family coupon's band uses the family face and keeps the teal perforation.
  - Row y11 is a dashed perforation (% 2 on, 1 off), with 2x3 semicircle bites cut into both short sides at y10-12.
  - Body w.
  - The window becomes a STUB: teal 4 fill with a w scissors glyph and no €. Fizzle: the stub turns `:` c7beab with an R diagonal strike, and no € shows.
- COUNT: the existing pay_burst / pay_burst_wide art is drawn centred behind the window. It scales 1.0→1.25→1.0 over 0.18 s, overhangs the top by at most 2 art, and never covers the glyphs. The window's digits tick to the new value. The €0 slot plays one pay_zero flash on the window.
- Stress ticket: gold band, 3 glyphs at x2/11/20, a boosted Y window showing "€128" in k, mini struck "€4" under it, a 2-line rule ending at screen x84 on line 1, and the brass outline with sparkle.

--- B. Full-colour face, fixed window (conservative, keeps #105) ---
Pitch: keep the approved full-colour family faces and today's layout, so the count's flights land where they do now, and fix only the finish. Show it next to A so the user can choose between "colour card" and "paper label".

- Body: face as today (family light row y1, face fill, shade right column and bottom row). The bevel becomes 2 visible steps: light y1, then a 50% checker of light and face on y2; shade y30, then a 50% checker on y29. Same shadow, die-cut corners and single-ink-edge fix as A.
- Header glyphs: 9x9, ink outline, no ring, at x2/11/20, y2. They read as stamps on the face.
- PRICE WINDOW x30-52, y2-13, the same states and digits as A. The paper fill is what fixes gold-on-mustard.
- STRUCK: a MINI TAB hanging under the window, right-aligned to x52, rows y14-20. Family-shade fill, 1 art ink outline on 3 sides (none on top), 3x5 digits in % 4a3f38, R strike on the digits' middle row.
- RULE: same box and size as A, but on a recessed CREAM PLATE so the AA text sits on a light ground. The plate spans x2-51, y21-29, is filled c with a 1 art b inset on its top and left, and the colour face shows around it. The 2 lines use a 13 px pitch inside the plate. If that doesn't fit, drop to 12 px.
- PLAIN product: the plate holds the name.
- GOLDEN: l outline, n top row, l window outline, corner sparkle.
- BIG: a 1 art y inner frame.
- COUPON: today's paper face and teal perforated top two rows, with the window as the scissors stub (as in A).
- COUNT: as A.
- Stress ticket: the same content as A, on a mustard face with the gold trim.

--- C. Electronic shelf label (ESL) ---
Pitch: the modern supermarket's e-ink shelf label. A steel housing is clipped on the rail, and a paper-white screen sits inside it. It belongs with the register, monitor and belt (same steel ramp). A pay becomes a screen-refresh flash instead of a burst on the face, which gives the count a new beat. This is the most different of the three.

- Housing 54x32: outline 1 art ink, corner pixel cut.
  - Clip rows: A ecebe4 on y1, B c7c3b8 on y2, with a 2-px K 2c2926 notch at x26-27.
  - Face C a9a59b, with a light left column B and a dark right column and bottom row E 6f6b63.
  - Shadow: ink at 40%, offset (1,1).
- FAMILY stripe: y3-4 in family face, its light colour on row y3. A split ticket gives two families with a step at x27.
- WINDOW x2-51, y6-29: a 1 art J 3d3a36 inset on its top and left (the screen is recessed), w fill, c bottom row.
- Inside the window:
  - Glyphs: 9x9, ink only, at (3,7), (12,7), (21,7).
  - Price: big digits in ink, right-aligned to x50, rows y8-14.
  - Struck: mini `=` digits with an R strike, to the left of the price after the glyphs (x31-38) if there is room, otherwise under the price at y16-20.
  - Rule: Atkinson 800 13 px, screen box x6-102, y34-58, 2 lines.
- GOLDEN: the housing ramp turns brass: L face, n light column and clip, l dark edges.
- BIG: an n clip.
- COUPON: a paper w housing with a perforated top row and a teal 4 stripe. "COUPON" is in hard Pixelify teal 3 in the stripe's place. The window shows the scissors glyph instead of a price.
- €0: window fill O, "€0" in r big digits, the struck old price at its left. The housing stays steel.
- COUNT, no burst on the face:
  - frame 1 (60 ms): the window fills ink
  - frame 2 (60 ms): the window fills y f1d27a
  - then the new price settles on w, with a 1 art M underline under the digits
  - a big gain drops a 14x7 R "SALE" flag (hard Pixelify w) over the housing's top-right
- Stress ticket: brass housing, 3 glyphs, €128 big digits (18 art wide, ends at x50), struck €4 under the price, 2-line rule.

== 3. THE DOUBLE €0 (one owner per fact) ==

Today, slot 3 says €0 twice: the ticket's tomato "warning €0" pay tag (top right) and, about 30 px below, the Spot check talker "warning €0" (slot_mark.gd INSPECTION_TEXT "€0", slot_talker_inspection art).

Rule: the ticket owns the amount, and the talker owns the cause.

- Card in the slot:
  - The ticket's price window shows "€0" in its €0 state (R fill, w digits) with the struck base price ("€4") beside or under it, so the loss is visible.
  - The ticket shows no warning sign.
  - The talker drops its text and shrinks to a cause-only chip: 13x13 art, R face, r rim, ink outline, holding the warning sign redrawn at 2x, centred under the ticket. Its hover tip keeps "Spot check: this slot pays €0".
- Slot empty (planning): there is no ticket, so the talker keeps the full "warning €0" as it does today. It is the only €0 shown then.
- Count: the window gives one pay_zero flash, and the talker only swings, with no second €0 flying.
- Coupons never show a € amount. The "scissors €0" goes away: the stub shows the scissors, and a fizzle greys and strikes the stub. A €0 on screen then always means "this slot pays nothing".
- The same rule applies to any NthSlotZeroPayoutRule.
- The top bar's day chip "Slot 3 pays €0" and the receipt's "€0.00" line stay. They are the event announcement and the list, not the slot.

Deliverable: one HTML page in C:/dev/projects/NextCustomer/docs/art/mockups/ with A, B and C side by side at 1:1 and at 3x zoom. Each shows the belt row, the stress ticket and the €0 slot with its talker, using the planning screen from now_planning_plain.png as the backdrop.