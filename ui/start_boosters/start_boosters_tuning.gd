class_name StartBoostersTuning
extends Resource
## YOUR STORE's booster opening beats (v1.32, the user's pick of 2026-11-13 on mock-up
## docs/art/mockups/start_boosters_v3.html, its TEMPO table). It lives in
## data/balance/start_boosters.tres so it can be tuned by feel without code changes. Only the main
## beats (the mock-up's TEMPO table) are here; small secondary beats (the message flash, page 2's
## deal staggers, the store flight's phases, the pin confirm) are still code literals next to
## their drawing. The defaults are neutral (0), like
## CartRevealTuning's, so
## a script edit can never silently change the tuned values in the file. Geometry stays in code
## constants (BoosterArt). Every time is in seconds.

## A swap window booster drops onto its shelf over drop_s.
@export var drop_s: float = 0.0

## Opening, on the booster's own clock: the grab ends at grab_s, the rattle at rattle_end_s; the
## foil bursts at burst_s; the cards rise from rise_start_s to rise_end_s
## and spread until spread_end_s; the empty pouch drops away over pouch_drop_s.
@export var grab_s: float = 0.0
@export var rattle_end_s: float = 0.0
@export var burst_s: float = 0.0
@export var rise_start_s: float = 0.0
@export var rise_end_s: float = 0.0
@export var spread_end_s: float = 0.0
@export var pouch_drop_s: float = 0.0

## A card flips over flip_s, the commons flip_step_s apart. The hit card hangs hit_hang_s (rising),
## trembles hit_tremble_s, then waits for its click (TAP IT). A RARE freezes freeze_s edge-on,
## pops back from 1.15 over rare_pop_s and rests rare_rest_s; a plain hit rests heavy_rest_s. The
## RARE's sunburst grows over sun_grow_s, holds sun_hold_s and shrinks over sun_shrink_s.
@export var flip_s: float = 0.0
@export var flip_step_s: float = 0.0
@export var hit_hang_s: float = 0.0
@export var hit_tremble_s: float = 0.0
@export var freeze_s: float = 0.0
@export var rare_pop_s: float = 0.0
@export var rare_rest_s: float = 0.0
@export var heavy_rest_s: float = 0.0
@export var sun_grow_s: float = 0.0
@export var sun_hold_s: float = 0.0
@export var sun_shrink_s: float = 0.0

## A skipped booster flips its commons open_all_flip_s apart and plays `boost` times as fast.
@export var open_all_flip_s: float = 0.0
@export var boost: float = 0.0

## NEXT is armed complete_delay_s after the last card lands. Under reduced motion a booster
## fades open over rm_fade_s.
@export var complete_delay_s: float = 0.0
@export var rm_fade_s: float = 0.0

## RESTOCK: the old cards turn to their backs restock_flip_s apart (their flight back to the bay
## is the aisle board's, below).
@export var restock_flip_s: float = 0.0

## The armed primary key's press-bob (NEXT on page 1, the pack key on page 2 and the pins step's
## key; v1.32 feedback, the user's pick C on docs/art/mockups/next_key_idle.html;
## BoosterPageDraw.key_lift): the arm hop lifts the face next_hop_lifts[k] art px until
## next_hop_ends_s[k] after arming (1, 2, 1, 0 px by 0.08, 0.2, 0.28, 0.36 s); then, every
## next_bob_s counted from next_bob_from_s, the face rises next_bob_px (the ledge doubling under
## it) for next_bob_hold_s. Neutral empty / 0: no hop, no bob.
@export var next_hop_ends_s: PackedFloat32Array = PackedFloat32Array()
@export var next_hop_lifts: PackedInt32Array = PackedInt32Array()
@export var next_bob_from_s: float = 0.0
@export var next_bob_s: float = 0.0
@export var next_bob_hold_s: float = 0.0
@export var next_bob_px: int = 0

## The BADGE PINS step: it pops in over pins_pop_s (pins_delay_s after the page opens); the worn
## pin flies to the corkboard over pin_fly_s.
@export var pins_delay_s: float = 0.0
@export var pins_pop_s: float = 0.0
@export var pin_fly_s: float = 0.0

## OPEN STORE: the cards gather over store_gather_s, turn into items over store_wipe_s (each
## store_item_gap_s after the last), drop into the cart over store_drop_s from store_drop_at_s,
## the cart rolls out from store_roll_at_s over store_roll_s, and the shutter starts at
## store_end_s.
@export var store_gather_s: float = 0.0
@export var store_wipe_s: float = 0.0
@export var store_item_gap_s: float = 0.0
@export var store_wipe_at_s: float = 0.0
@export var store_drop_at_s: float = 0.0
@export var store_drop_s: float = 0.0
@export var store_roll_at_s: float = 0.0
@export var store_roll_s: float = 0.0
@export var store_end_s: float = 0.0

## The swap window (YOUR REGULARS, v1.32 swap window): it slides in over swap_in_s and out over
## swap_out_s; its boosters drop swap_drop_gap_s apart. A card flies between its fan and the
## basket in swap_fly_min_s + its distance / swap_fly_px_s (at most swap_fly_max_s; a refused drop
## bounces home swap_bounce_s longer).
@export var swap_in_s: float = 0.0
@export var swap_out_s: float = 0.0
@export var swap_drop_gap_s: float = 0.0
@export var swap_fly_min_s: float = 0.0
@export var swap_fly_max_s: float = 0.0
@export var swap_fly_px_s: float = 0.0
@export var swap_bounce_s: float = 0.0

## The aisle board (v1.40, mock-up start_roulette.html, variant A). The fan cards are compact
## (picture, price, family glyph, name; the full card with its rule pops on hover) while
## compact_fan_cards; false stands the full cards with their rules on the counter.
@export var compact_fan_cards: bool = false
## The light starts spin_delay_s after the page shows. Its first run makes at least
## spin_first_hops hops in spin_first_s, the first gap spin_first_gap_s; each next run starts
## spin_pause_s after the landing and makes at least spin_next_hops hops in spin_next_s from
## a gap of spin_next_gap_s; a run's last gap is stretched spin_last_stretch times. The other
## bays close spin_close_at_s after the last landing, their shutters shutter_gap_s apart, each
## rolling down over shutter_down_s and bouncing shutter_bounce_s.
@export var spin_delay_s: float = 0.0
@export var spin_first_hops: int = 0
@export var spin_first_s: float = 0.0
@export var spin_first_gap_s: float = 0.0
@export var spin_pause_s: float = 0.0
@export var spin_next_hops: int = 0
@export var spin_next_s: float = 0.0
@export var spin_next_gap_s: float = 0.0
@export var spin_last_stretch: float = 0.0
@export var spin_close_at_s: float = 0.0
@export var shutter_gap_s: float = 0.0
@export var shutter_down_s: float = 0.0
@export var shutter_bounce_s: float = 0.0
## The first open bay throws its booster throw_at_s after the bays close (fixed_throw_at_s after
## the page shows when no light runs: the guided first run, a resume), the next throw_gap_s later;
## a throw flies throw_s. A thrown booster waits sealed on the counter until the player opens it
## (a click, 1-2, Enter: the user's play test of 2026-11-19, round 2).
@export var throw_at_s: float = 0.0
@export var fixed_throw_at_s: float = 0.0
@export var throw_gap_s: float = 0.0
@export var throw_s: float = 0.0
## RESTOCK: the old cards fly back to their bay over restock_return_s each (restock_flip_s apart),
## the bay's sign punches restock_land_at_s after the key, it throws the fresh booster
## restock_throw_at_s later, and that one waits sealed on the counter.
@export var restock_return_s: float = 0.0
@export var restock_land_at_s: float = 0.0
@export var restock_throw_at_s: float = 0.0
