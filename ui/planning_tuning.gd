class_name PlanningTuning
extends Resource
## The planning effects' tuning (#71, mock-up h1, H1_BUILD_SPEC.md section 3.4): when a boosted
## item's halo gains its 2nd and 3rd ring, and the hover's fades and the stickers' motion. It
## lives in data/balance/planning.tres so it can be tuned by feel without code changes;
## PlanningModel and PlanningEffects read it and never hard-code it. The defaults are neutral (0
## or empty), like ScanTuning's, so a script edit can never silently change the tuned values in
## the file. Geometry stays in code constants, as everywhere else in ui/.

## A boosted item's halo: 1 ring for any boost, a 2nd once its pay is at least `halo_ratios[0]`
## times its base (at least 1), a 3rd at `halo_ratios[1]` times. Display only: the pay and the
## base come from the score's steps.
@export var halo_ratios: PackedInt32Array = PackedInt32Array()

## Seconds the hover takes to fade the unrelated items, tickets and strips (0 under reduced
## motion).
@export var focus_fade_s: float = 0.0

## Seconds the pointer may be off a hovered giver before its focus ends (so moving between two
## related items doesn't flicker).
@export var unfocus_delay_s: float = 0.0

## The sprite's alpha of an item unrelated to the hovered one.
@export var dim_item_alpha: float = 0.0

## The ticket's and pay tag's alpha of an item unrelated to the hovered one.
@export var dim_ticket_alpha: float = 0.0

## A rail strip's alpha while an unrelated item is hovered.
@export var dim_strip_alpha: float = 0.0

## Seconds of each frame of a new sticker's squash (the slap).
@export var slap_frame_s: float = 0.0

## Seconds between two rings of a boosted item's halo stepping out.
@export var halo_step_s: float = 0.0
