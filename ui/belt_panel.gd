class_name BeltPanel
extends Control
## The shift screen's conveyor belt (#80, mock-up B2; greybox, step 3): the steel guard at its
## back, the rubber top face the items stand on, the steel front lip, the apron under it and the
## price rail the tickets clip onto, with the rail's shadow on the counter. Flat palette fills
## for now; the perspective art lands in a later step. Its size is fixed (ShiftStage.BELT_RECT);
## the row of slots stands on it as its child. Decor only: it takes no clicks.

## The bands, in the belt's coordinates (ShiftStage.BELT_RECT starts at the guard's top).
const GUARD := Rect2(0, 0, 918, 12)
const TOP_FACE := Rect2(8, 12, 902, 74)
const LIP := Rect2(0, 86, 918, 14)
const APRON := Rect2(0, 100, 918, 8)
const RAIL := Rect2(0, 108, 918, 68)
const RAIL_SHADOW := Rect2(2, 176, 918, 4)
const RAIL_SHADOW_ALPHA := 0.35
const OUTLINE := 2.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(GUARD, Palette.STEEL_SHADE)
	draw_rect(TOP_FACE, Palette.RUBBER)
	draw_rect(LIP, Palette.STEEL)
	draw_rect(Rect2(LIP.position, Vector2(LIP.size.x, 4)), Palette.STEEL_LIGHT)
	draw_rect(APRON, Palette.STEEL_DARK)
	draw_rect(RAIL, Palette.STEEL_PALE)
	draw_rect(RAIL, Palette.INK, false, OUTLINE)
	draw_rect(RAIL_SHADOW, Color(Palette.INK, RAIL_SHADOW_ALPHA))


## The rubber top face the items stand on, in the belt's coordinates.
func top_face() -> Rect2:
	return TOP_FACE


## The price rail the tickets clip onto, in the belt's coordinates.
func rail() -> Rect2:
	return RAIL
