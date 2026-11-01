class_name StoreBackdrop
extends RefCounted
## The shift screen's store backdrop (#80; redrawn for the clean scene of #123, mock-up
## docs/art/mockups/scene_123.html, direction A): bands that fill the window behind the centred
## stage, so nothing drifts when the window isn't 1280x720, and the store over them. Back to
## front: the far wall (it takes the background clicks), the store (StoreShelves: StoreArt's
## painted store, the pendant lamps and the aisle signs, stage-sized and centred like the stage),
## then the counter's charcoal laminate from the belt's back down (the counter, the belt's frame
## and the register read as one piece of furniture), and the floor under the basket ledge. The
## bands span the window, so the letterbox bands beside the stage read as more of the same store,
## and run on past its right edge as far as the camera at the machine shows
## (ShiftStage.WORLD_RIGHT; #77 machine v2: screen_parts go in the StoreCamera, which zooms them).
## The top bar's dark teal band with B2's ink line along its foot never zooms: top_parts adds it
## over the camera. Decor only, with no game information.

## The window's middle is the stage's (the stage is centred), so the bands are placed from it.
const STAGE_MIDDLE := ShiftStage.SIZE.y / 2.0
const TOP_BAND_COLOR := Palette.BACKGROUND
const WALL_COLOR := Palette.BACKGROUND
const COUNTER_COLOR := Palette.RUBBER_DARK
const FLOOR_COLOR := Palette.TEAL_BLACK
## The ink line along the top band's foot (B2's 2 px border-bottom), inside the band.
const TOP_EDGE := 2.0
## How far the zoomed bands run past the window's right edge (the camera at the machine shows the
## stage up to ShiftStage.WORLD_RIGHT).
const WORLD_EXTRA := ShiftStage.WORLD_RIGHT - ShiftStage.SIZE.x


## Adds the zoomed backdrop to `parent` (the StoreCamera's content), behind the stage's world:
## the wall (its first child), the store with its signs in the colours of `aisles` (the run's
## balance), then the counter and the floor. Returns the wall, which takes the background clicks;
## nothing else does.
static func screen_parts(parent: Control, aisles: Array[AisleDefinition] = []) -> ColorRect:
	var wall: ColorRect = _band("Wall", WALL_COLOR, 0.0, 1.0, 0.0, 0.0, WORLD_EXTRA)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(wall)
	parent.add_child(StoreShelves.new(aisles))
	var counter_top: float = ShiftStage.COUNTER_TOP - STAGE_MIDDLE
	parent.add_child(_band("Counter", COUNTER_COLOR, 0.5, 1.0, counter_top, 0.0, WORLD_EXTRA))
	var floor_top: float = ShiftStage.FLOOR_TOP - STAGE_MIDDLE
	parent.add_child(_band("Floor", FLOOR_COLOR, 0.5, 1.0, floor_top, 0.0, WORLD_EXTRA))
	return wall


## Adds the top bar's band to `parent` (over the StoreCamera, under the stage's hud): the dark teal
## band from the window's top to the top bar's foot and B2's ink line along its foot, inside it.
## It never zooms and takes no click.
static func top_parts(parent: Control) -> void:
	parent.add_child(
		_band("TopBand", TOP_BAND_COLOR, 0.0, 0.5, 0.0, ShiftStage.TOP_BAR_BOTTOM - STAGE_MIDDLE)
	)
	var edge_bottom: float = ShiftStage.TOP_BAR_BOTTOM - STAGE_MIDDLE
	parent.add_child(_band("TopEdge", Palette.INK, 0.5, 0.5, edge_bottom - TOP_EDGE, edge_bottom))


## A full-width band of `color` between the anchors `top` and `bottom` (0 the window's top, 0.5
## its middle, 1 its bottom), moved by the offsets, running `extra` px past the window's right
## edge; it takes no clicks.
static func _band(
	band_name: String,
	color: Color,
	top: float,
	bottom: float,
	offset_top: float,
	offset_bottom: float,
	extra: float = 0.0
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
	band.offset_right = extra
	return band
