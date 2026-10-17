class_name StoreBackdrop
extends RefCounted
## The shift screen's store backdrop (#80, mock-up B2; greybox, step 3): flat bands that fill
## the window behind the centred stage, so nothing drifts when the window isn't 1280x720. From
## the top: the top bar's dark teal band with B2's ink line along its foot, the plaster wall
## behind the counter (it takes the background clicks), the counter's wood from the belt's back
## down, and the slate floor. Decor only, with no game information. The store's back wall art
## lands in a later step.

## The window's middle is the stage's (the stage is centred), so the bands are placed from it.
const STAGE_MIDDLE := ShiftStage.SIZE.y / 2.0
const TOP_BAND_COLOR := Palette.BACKGROUND
const WALL_COLOR := Palette.PLASTER
const COUNTER_COLOR := Palette.WOOD_DARK
const FLOOR_COLOR := Palette.SLATE
## The ink line along the top band's foot (B2's 2 px border-bottom), inside the band.
const TOP_EDGE := 2.0


## Adds the window-sized bands to `parent`, behind the stage: the wall (its first child), then
## the top band, the counter and the floor. Returns the wall, which takes the background clicks.
static func screen_parts(parent: Control) -> ColorRect:
	var wall: ColorRect = _band("Wall", WALL_COLOR, 0.0, 1.0, 0.0, 0.0)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(wall)
	parent.add_child(
		_band("TopBand", TOP_BAND_COLOR, 0.0, 0.5, 0.0, ShiftStage.TOP_BAR_BOTTOM - STAGE_MIDDLE)
	)
	var edge_bottom: float = ShiftStage.TOP_BAR_BOTTOM - STAGE_MIDDLE
	parent.add_child(_band("TopEdge", Palette.INK, 0.5, 0.5, edge_bottom - TOP_EDGE, edge_bottom))
	parent.add_child(
		_band("Counter", COUNTER_COLOR, 0.5, 1.0, ShiftStage.COUNTER_TOP - STAGE_MIDDLE, 0.0)
	)
	parent.add_child(
		_band("Floor", FLOOR_COLOR, 0.5, 1.0, ShiftStage.FLOOR_TOP - STAGE_MIDDLE, 0.0)
	)
	return wall


## A full-width band of `color` between the anchors `top` and `bottom` (0 the window's top, 0.5
## its middle, 1 its bottom), moved by the offsets; it takes no clicks.
static func _band(
	band_name: String,
	color: Color,
	top: float,
	bottom: float,
	offset_top: float,
	offset_bottom: float
) -> ColorRect:
	var band: ColorRect = ColorRect.new()
	band.name = band_name
	band.color = color
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.anchor_top = top
	band.anchor_bottom = bottom
	band.offset_top = offset_top
	band.offset_bottom = offset_bottom
	return band
