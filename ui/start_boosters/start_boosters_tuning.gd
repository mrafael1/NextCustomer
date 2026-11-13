class_name StartBoostersTuning
extends Resource
## YOUR STORE's booster opening beats (v1.32, the user's pick of 2026-11-13 on mock-up
## docs/art/mockups/start_boosters_v3.html, its TEMPO table). It lives in
## data/balance/start_boosters.tres so it can be tuned by feel without code changes. Only the main
## beats (the mock-up's TEMPO table) are here; small secondary beats (STOCKED!'s lamp steps, the
## hint flash, RESTOCK's lamp flicker, page 2's deal staggers, the store flight's phases, the pin
## confirm) are still code literals next to their drawing. The defaults are neutral (0), like
## CartRevealTuning's, so
## a script edit can never silently change the tuned values in the file. Geometry stays in code
## constants (BoosterArt). Every time is in seconds.

## The storefront: the shutters wait auto_roll_s (desktop game; the web build waits for a click),
## roll up over shutter_up_s, then the view walks in through the door over walk_in_s.
@export var auto_roll_s: float = 0.0
@export var shutter_up_s: float = 0.0
@export var walk_in_s: float = 0.0

## The lamps come on lamp_gap_s apart, flickering lamp_flicker_s a step; each booster drops from
## the ceiling over drop_s (a back ease of drop_overshoot), then squashes in over squash_in_s and
## back out over squash_out_s.
@export var lamp_gap_s: float = 0.0
@export var lamp_flicker_s: float = 0.0
@export var drop_s: float = 0.0
@export var drop_overshoot: float = 0.0
@export var squash_in_s: float = 0.0
@export var squash_out_s: float = 0.0

## Opening, on the booster's own clock: the grab ends at grab_s, the rattle at rattle_end_s, the
## tear at tear_end_s; the foil bursts at burst_s; the cards rise from rise_start_s to rise_end_s
## and spread until spread_end_s; the empty pouch drops away over pouch_drop_s.
@export var grab_s: float = 0.0
@export var rattle_end_s: float = 0.0
@export var tear_end_s: float = 0.0
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

## OPEN ALL (the primary key, A, or Space held hold_space_s): tears open_all_tear_s apart, commons
## open_all_flip_s apart, the hits and RAREs queued last open_all_gap_s apart, the whole
## sequence within open_all_cap_s. A skip plays a booster `boost` times as fast.
@export var open_all_tear_s: float = 0.0
@export var open_all_flip_s: float = 0.0
@export var open_all_gap_s: float = 0.0
@export var open_all_cap_s: float = 0.0
@export var hold_space_s: float = 0.0
@export var boost: float = 0.0

## STOCKED!: it starts complete_delay_s after the last card lands. Under reduced motion a booster
## fades open over rm_fade_s.
@export var complete_delay_s: float = 0.0
@export var rm_fade_s: float = 0.0

## RESTOCK: the old cards flip to their backs restock_flip_s apart, fly into the returns tote over
## restock_fly_s, the tote drops away restock_tote_at_s after the RESTOCK over restock_tote_s and
## comes back over restock_tote_back_s, and its dust puffs as it lands; the old cards are gone
## restock_clear_s after the drop. The fresh booster drops restock_drop_s after the RESTOCK.
@export var restock_flip_s: float = 0.0
@export var restock_fly_s: float = 0.0
@export var restock_tote_at_s: float = 0.0
@export var restock_tote_s: float = 0.0
@export var restock_tote_back_s: float = 0.0
@export var restock_clear_s: float = 0.0
@export var restock_drop_s: float = 0.0

## PICK 2 OF 3: the booster not picked sinks over pick_sink_s; the kept pair slides to the two
## aisle places pick_move_at_s after the second pick (over pick_sink_s too), and the counter's
## two-aisle dress (RESTOCK, the tote, the board, the RUN-ONLY sign) comes in with it.
@export var pick_sink_s: float = 0.0
@export var pick_move_at_s: float = 0.0

## YOUR BUILD (page 2): the packs deal p2_deal_delay_s after the page opens, a pack every
## p2_pack_gap_s and a card every p2_card_gap_s, each flying p2_fly_s from the deck and flipping
## over p2_flip_s; a hovered pack spreads over p2_spread_s while the others sink over p2_sink_s.
@export var p2_deal_delay_s: float = 0.0
@export var p2_pack_gap_s: float = 0.0
@export var p2_card_gap_s: float = 0.0
@export var p2_fly_s: float = 0.0
@export var p2_flip_s: float = 0.0
@export var p2_spread_s: float = 0.0
@export var p2_sink_s: float = 0.0
## NEW PACKS: the new packs deal new_packs_deal_s after the press (a pack every p2_pack_gap_s).
@export var new_packs_deal_s: float = 0.0
## The BADGE PINS step: it pops in over pins_pop_s (pins_delay_s after the page opens); the worn
## pin flies to the corkboard over pin_fly_s and the packs deal pins_deal_s after the confirm.
@export var pins_delay_s: float = 0.0
@export var pins_pop_s: float = 0.0
@export var pin_fly_s: float = 0.0
@export var pins_deal_s: float = 0.0

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
