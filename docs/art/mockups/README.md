# Shift screen mock-ups (2026-10-16)

Static HTML mock-ups for the shift screen rework discussed in #80 ("shift scene: rework or livelier touches"). They are a direction check, not game code: nothing here is loaded by Godot (`docs/art/` has a `.gdignore`), and no rule or layout in the game changed.

All three show the same state as `docs/art/shift_screen_1920x1080.png` on `feature/items-and-scanner` (#79): shift 5 of 8, quota €73, projected €22, an inspection closing one slot, the Multipack coupon hovered.

| Page | Capture | Idea |
|---|---|---|
| `shift_screen_a.html` | `shift_screen_a_1920x1080.png` | **A: boutique, calmed.** The 2026-10-14 boutique tone kept, with one place per fact: one sticker per item, a single corner mark (fizzle or combo), per-item payouts on the receipt with the hovered item's details expanded there, the money on the register LED only, a shorter top bar, no status line or hint text. |
| `shift_screen_b.html` | `shift_screen_b_1920x1080.png` | **B: proposals 1 + 2.** Proposal 2's layout (quota bar in the top bar, a monitor showing the hovered item, a receipt list, one big CHECKOUT) with proposal 1's warmth (a stocked store behind the counter, the waiting customers as silhouettes, a wood counter, the hand in a shopping basket). Back to the art bible's cream, teal, tomato and mustard. |
| `shift_screen_b2.html` | `shift_screen_b2_1920x1080.png` | **B2: B with relief.** The belt seen at an angle, items standing on it with contact shadows (the hovered one lifted), price labels on a rail along the counter's front edge, stanchions for the closed slot, the hand sitting inside the basket, the printer and buttons with depth. |

`compare_now_a_b.png` puts the current screen, A and B side by side; `compare_b_b2.png` compares B and B2.

The user's feedback so far: the screen gets messy quickly and should be cleaner (proposal 2 appealed); B is the liveliest; the screen felt flat and seen from above, which B2 answers; the items still need a visual improvement (#80), which these mock-ups do not attempt beyond grounding them.

## What is real and what is not

- **Real:** the item sprites, icons and scenery in `assets/art/` (copied from `feature/items-and-scanner`, since `main` doesn't have them yet), and the three fonts, loaded from the repo's `fonts/`. Item rules, payouts and fizzle texts are the ones from the #79 screenshot.
- **Approximated:** every frame (belt, counter, labels, basket, monitor, register, buttons) is flat CSS in the palette, not the 9-slice pixel-art frames. B2's belt is a CSS 3D transform; in the game it would be drawn as pixel art.
- **Placeholders:** the customer silhouettes in B and B2. Real customer art would be new scope.

## Re-capturing

```sh
node docs/art/mockups/capture.js docs/art/mockups/shift_screen_b2.html /tmp/b2.png
```

It needs Playwright and a Chromium (`CHROMIUM_PATH=/path/to/chromium` to pick one).
