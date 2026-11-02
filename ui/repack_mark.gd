class_name RepackMark
extends Control
## An empty hand place that takes the picked item (#122, a badge pin's repack: RepackFlow): an
## invisible click target over the place's item cell (ItemView.BASKET_SIZE), showing only the
## pointing-hand cursor. The user's call of 2026-11-01: no highlighted zone on the baskets.

## The hand place it marks.
var place: int = -1


func _init(at_place: int) -> void:
	name = "RepackMark"
	place = at_place
	size = ItemView.BASKET_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
