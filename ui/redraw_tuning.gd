class_name RedrawTuning
extends Resource
## The basket redraw's motion (plan section 3.8; mock-up redraw_basket_v1.html, approved by the
## user on 2026-10-22): the hover's lift and wobble, the picked basket's squash and tip toward the
## Cart, the old items' arcs into the Cart and its bumps, the new items' pops and sparks, and the
## reduced-motion fade. It lives in data/balance/redraw.tres so it can be tuned by feel without code
## changes; BasketRedraw reads it and never hard-codes it. The defaults are neutral (0), like
## PlanningTuning's, so a script edit can never silently change the tuned values in the file.
## Geometry (the pivots, the basket's size) stays in code constants, as everywhere else in ui/.

## Seconds from the click to the motion's end (input stays blocked until then).
@export var length_s: float = 0.0

## The squash: over `squash_s` the basket's height eases to 1 - squash_y and its width to
## 1 + squash_x about its centre-bottom, then eases back while it tips.
@export var squash_s: float = 0.0
@export var squash_y: float = 0.0
@export var squash_x: float = 0.0

## The tip about the basket's right corner: it eases to `tip_deg` over `tip_in_s` (from the
## squash's end), lifted `tip_lift` px and pulled `tip_pull` px left, holds `hold_s`, then rights
## itself over `right_s` with a back-ease overshoot of `right_overshoot` (the c1 of the ease).
@export var tip_deg: float = 0.0
@export var tip_lift: float = 0.0
@export var tip_pull: float = 0.0
@export var tip_in_s: float = 0.0
@export var hold_s: float = 0.0
@export var right_s: float = 0.0
@export var right_overshoot: float = 0.0

## The old items leave at out_start_s + out_gap_s * k (k: their order, left first), each flying
## `out_s` on an arc `arc_height` px above its higher end into the Cart, shrinking to
## `out_scale`, spinning `out_spin_deg` (alternating ways), fading over its last `out_fade`.
@export var out_start_s: float = 0.0
@export var out_gap_s: float = 0.0
@export var out_s: float = 0.0
@export var arc_height: float = 0.0
@export var out_scale: float = 0.0
@export var out_spin_deg: float = 0.0
@export var out_fade: float = 0.0

## The Cart button grows to 1 + cart_bump about its centre for `cart_bump_s` as each old item
## lands, and by `cart_leave` of that as each new item leaves it.
@export var cart_bump: float = 0.0
@export var cart_bump_s: float = 0.0
@export var cart_leave: float = 0.0

## The new items pop up at in_start_s + in_gap_s * k, each rising `pop_rise` px over `in_s` with
## a back-ease of `pop_overshoot`, its width from pop_scale_x and its height from pop_scale_y to
## 1; then a landing squash (to 1 - land_squash_y high, 1 + land_squash_x wide over land_in_s,
## back over land_out_s) while the basket dips `dip` px with a `dip_squash` squash for `dip_s`.
@export var in_start_s: float = 0.0
@export var in_gap_s: float = 0.0
@export var in_s: float = 0.0
@export var pop_rise: float = 0.0
@export var pop_overshoot: float = 0.0
@export var pop_scale_x: float = 0.0
@export var pop_scale_y: float = 0.0
@export var land_in_s: float = 0.0
@export var land_out_s: float = 0.0
@export var land_squash_y: float = 0.0
@export var land_squash_x: float = 0.0
@export var dip: float = 0.0
@export var dip_squash: float = 0.0
@export var dip_s: float = 0.0

## Each new item bursts `sparks` sparks from the rim for `spark_s`, flung at `spark_speed` px/s
## (plus up to `spark_speed_spread`) and pulled down by `spark_gravity` px/s², each at an angle
## spread over `spark_angle_span_deg` from `spark_angle_from_deg` (0: right, -90: up).
@export var sparks: int = 0
@export var spark_s: float = 0.0
@export var spark_speed: float = 0.0
@export var spark_speed_spread: float = 0.0
@export var spark_gravity: float = 0.0
@export var spark_angle_from_deg: float = 0.0
@export var spark_angle_span_deg: float = 0.0

## The hover: the basket eases up `hover_lift` px over `hover_in_s` and wobbles
## `hover_wobble_deg` (sin of `hover_wobble_rate` t), fading out over `hover_wobble_s`; leaving
## eases it back over `hover_in_s`.
@export var hover_lift: float = 0.0
@export var hover_in_s: float = 0.0
@export var hover_wobble_deg: float = 0.0
@export var hover_wobble_rate: float = 0.0
@export var hover_wobble_s: float = 0.0

## Reduced motion: no pose, flight, bump or sparks; the old items fade out over `rm_out_s` in
## place, then the new ones fade in over `rm_in_s`.
@export var rm_out_s: float = 0.0
@export var rm_in_s: float = 0.0


## Seconds the motion lasts: `length_s`, or the reduced-motion fade.
func duration(reduced_motion: bool) -> float:
	return rm_out_s + rm_in_s if reduced_motion else length_s


## When new item `k` starts to pop (its card_place sound plays then).
func pop_start(k: int, reduced_motion: bool) -> float:
	return rm_out_s if reduced_motion else in_start_s + in_gap_s * k
