class_name CountUpContext
extends RefCounted
## What a count-up knows about the run besides the row (#60, D3): the shift, the best checkout
## so far, the player's speed setting and reduced motion. The quota is never part of it, so a
## different quota can never change the count-up's intensity.

## The shift being checked out, 1-based.
var shift: int = 1
## The best checkout total of the run's EARLIER shifts (never the current one), 0 if none.
## CountUpPlan raises it to the tuning's first_best_floor.
var best_so_far: int = 0
## The player's count-up speed setting (ProfileState.settings "count_up_speed"): 1.0 or 1.5.
var speed_setting: float = 1.0
## Reduced motion (ProfileState.settings "reduced_motion"): no shakes or rattles.
var reduced_motion: bool = false


func _init(
	shift_number: int = 1, best: int = 0, speed: float = 1.0, reduce_motion: bool = false
) -> void:
	shift = shift_number
	best_so_far = best
	speed_setting = speed
	reduced_motion = reduce_motion
