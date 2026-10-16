class_name CountUpContext
extends RefCounted
## What a count-up knows about the run besides the row (#60, D3): the shift, the best checkout
## so far, the player's speed setting, reduced motion, and the receipt's header (#75). The quota
## is never part of it, so a different quota can never change the count-up's intensity.

## The shift being checked out, 1-based.
var shift: int = 1
## The best checkout total of the run's EARLIER shifts (never the current one), 0 if none.
## CountUpPlan raises it to the tuning's first_best_floor.
var best_so_far: int = 0
## The player's count-up speed setting (ProfileState.settings "count_up_speed"): 1.0 or 1.5.
var speed_setting: float = 1.0
## Reduced motion (ProfileState.settings "reduced_motion"): no shakes or rattles.
var reduced_motion: bool = false
## The receipt's header lines (#75, ReceiptView.header_lines), printed at once when the count-up
## starts (ReceiptView.begin), so its lines print under the planning stub's header. None by
## default.
var receipt_header: PackedStringArray = PackedStringArray()


func _init(
	shift_number: int = 1,
	best: int = 0,
	speed: float = 1.0,
	reduce_motion: bool = false,
	header: PackedStringArray = PackedStringArray()
) -> void:
	shift = shift_number
	best_so_far = best
	speed_setting = speed
	reduced_motion = reduce_motion
	receipt_header = header
