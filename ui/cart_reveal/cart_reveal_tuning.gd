class_name CartRevealTuning
extends Resource
## The start-of-run cart reveal's motion (v0.51, variant A "dispenser" of mock-up
## cart_reveal_v1.html, approved by the user on 2026-10-23). It lives in
## data/balance/cart_reveal.tres so it can be tuned by feel without code changes; CartReveal reads
## it and never hard-codes it. The defaults are neutral (0), like RedrawTuning's, so a script edit
## can never silently change the tuned values in the file. Geometry (the panel, the tiles, the
## dispenser) stays in code constants, as everywhere else in ui/. Every time is in seconds from
## the panel's pop-in.

## The panel pops in over `pop_s`, from a scale of 1 - pop_from.
@export var pop_s: float = 0.0
@export var pop_from: float = 0.0

## The staples' padlocks clunk on at lock_start_s + lock_gap_s * i, each over `lock_s`, from a
## scale of lock_scale and a turn of lock_turn_deg.
@export var lock_start_s: float = 0.0
@export var lock_gap_s: float = 0.0
@export var lock_s: float = 0.0
@export var lock_scale: float = 0.0
@export var lock_turn_deg: float = 0.0

## The starter pack choice (#107): the packs drop in from pack_start_s, pack_gap_s apart, each
## over pack_drop_s from pack_drop_px above; a raised pack sits pack_raise_px higher.
@export var pack_start_s: float = 0.0
@export var pack_gap_s: float = 0.0
@export var pack_drop_s: float = 0.0
@export var pack_drop_px: float = 0.0
@export var pack_raise_px: float = 0.0

## Pick k leaves the chute at pick_start_s + pick_gap_s * k: it pops out over `exit_s` (from a
## scale of exit_scale, sliding exit_drop px down), then arcs into its slot over `fly_s`, an arc
## `arc_height` px high (a coupon's coupon_arc_height, fluttering coupon_flutter_deg); a product
## tilts product_tilt_deg and rights itself on the way.
@export var pick_start_s: float = 0.0
@export var pick_gap_s: float = 0.0
@export var exit_s: float = 0.0
@export var exit_scale: float = 0.0
@export var exit_drop: float = 0.0
@export var fly_s: float = 0.0
@export var arc_height: float = 0.0
@export var coupon_arc_height: float = 0.0
@export var coupon_flutter_deg: float = 0.0
@export var product_tilt_deg: float = 0.0

## A landing: the tile pops from 1 + land_pop over `land_s` with a white flash of land_flash,
## and its sparkles fly out over burst_s, from burst_radius px, burst_speed px a second.
@export var land_s: float = 0.0
@export var land_pop: float = 0.0
@export var land_flash: float = 0.0
@export var burst_s: float = 0.0
@export var burst_radius: float = 0.0
@export var burst_speed: float = 0.0

## The dispenser: the cabinet jolts jolt_px for jolt_s as each pick leaves, the flap opens for
## flap_s, the bulbs chase at chase_hz (blinking at blink_hz once sold out) and the heap sinks
## heap_sink px per pick.
@export var jolt_s: float = 0.0
@export var jolt_px: float = 0.0
@export var flap_s: float = 0.0
@export var chase_hz: float = 0.0
@export var blink_hz: float = 0.0
@export var heap_sink: float = 0.0

## The CART chip grows by chip_pop for chip_pop_s at each landing. The summary line follows the
## last landing by summary_delay_s and rises summary_rise px into place over summary_s; the
## reveal is done end_delay_s after the summary starts (a tap before then skips to that point).
@export var chip_pop: float = 0.0
@export var chip_pop_s: float = 0.0
@export var summary_delay_s: float = 0.0
@export var summary_s: float = 0.0
@export var summary_rise: float = 0.0
@export var end_delay_s: float = 0.0
## The end's tap hint blinks at hint_hz.
@export var hint_hz: float = 0.0

## The outro (the tap at the end): the panel folds into the Cart button over fold_s and the
## button's ring flashes from ring_start_s to outro_s, when the reveal closes.
@export var fold_s: float = 0.0
@export var ring_start_s: float = 0.0
@export var outro_s: float = 0.0


## When pick `index` leaves the chute.
func pick_start(index: int) -> float:
	return pick_start_s + pick_gap_s * index


## When pick `index` lands in its slot.
func pick_land(index: int) -> float:
	return pick_start(index) + exit_s + fly_s


## When the summary line starts, for `count` picks.
func summary_start(count: int) -> float:
	return (pick_land(count - 1) if count > 0 else pick_start_s) + summary_delay_s


## When the reveal is done (the summary shown), for `count` picks.
func end_time(count: int) -> float:
	return summary_start(count) + end_delay_s
