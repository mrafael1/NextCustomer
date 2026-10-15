class_name ScanLayout
extends RefCounted
## Where a scan popup may open (#75): the stage, the hand's tray, the counter line and the top
## bar's foot, all in one set of coordinates (global ones for ScanPopup.place_at). The shift
## screen's stage gives its own; the popup never reads a screen's constants.

## The stage's rect: a popup stays inside it.
var stage: Rect2 = Rect2()
## The tray holding the hand: an item whose sprite's centre is in it is a hand item, and its
## popup opens beside it over the tray.
var tray: Rect2 = Rect2()
## The counter line's y: a hand item's popup never rises above it.
var counter_top: float = 0.0
## The top bar's foot's y: a belt item's popup flips below the item rather than reach it.
var top_bar_bottom: float = 0.0


func _init(
	stage_rect: Rect2 = Rect2(),
	tray_rect: Rect2 = Rect2(),
	counter_line: float = 0.0,
	top_bar_foot: float = 0.0
) -> void:
	stage = stage_rect
	tray = tray_rect
	counter_top = counter_line
	top_bar_bottom = top_bar_foot


## This layout moved by `transform` (a translation and a scale, e.g. global to a node's own
## coordinates).
func transformed(transform: Transform2D) -> ScanLayout:
	return ScanLayout.new(
		transform * stage,
		transform * tray,
		(transform * Vector2(0, counter_top)).y,
		(transform * Vector2(0, top_bar_bottom)).y
	)


## Whether `item_rect` (an item's sprite) is a hand item's: its centre is in the tray.
func is_in_tray(item_rect: Rect2) -> bool:
	return tray.has_point(item_rect.get_center())
