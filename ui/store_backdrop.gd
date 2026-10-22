class_name StoreBackdrop
extends RefCounted
## The shift screen's store backdrop (#80, mock-up B2; steps 3 and 11): bands that fill the
## window behind the centred stage, so nothing drifts when the window isn't 1280x720, and the
## back of the store on the wall. Back to front: the plaster wall (it takes the background
## clicks), the warm light pool on it (StoreShelves.wall_light), its cornice under the ceiling
## and the darker lower wall under the dado rail (tinted like the sections, as in B2), the store
## sections (StoreShelves, stage-sized and centred like the stage), the haze over them,
## the cashier behind the counter, the cool wall shade over the whole wall, the lamp; then the
## counter's wood from the belt's back down, and the slate floor. The wall's bands, the haze and
## the shade span the window, so the letterbox bands beside the stage read as more of the same
## wall, and run on past its right edge as far as the camera at the machine shows
## (ShiftStage.WORLD_RIGHT; #77 machine v2: screen_parts go in the StoreCamera, which zooms them).
## The top bar's dark teal band with B2's ink line along its foot never zooms: top_parts adds it
## over the camera. Decor only, with no game information.

## The window's middle is the stage's (the stage is centred), so the bands are placed from it.
const STAGE_MIDDLE := ShiftStage.SIZE.y / 2.0
const TOP_BAND_COLOR := Palette.BACKGROUND
const WALL_COLOR := Palette.PLASTER
const COUNTER_COLOR := Palette.WOOD_DARK
const FLOOR_COLOR := Palette.SLATE
## The ink line along the top band's foot (B2's 2 px border-bottom), inside the band.
const TOP_EDGE := 2.0
## How far the zoomed bands run past the window's right edge (the camera at the machine shows the
## stage up to ShiftStage.WORLD_RIGHT).
const WORLD_EXTRA := ShiftStage.WORLD_RIGHT - ShiftStage.SIZE.x
## The wall's bands (B2's wall coordinates, from TOP_BAR_BOTTOM): the cornice and its shadow
## line, then the dado rail with its lit edge, the lower wall and the cool step over both. They
## take the sections' depth tint (StoreShelves.depth_modulate): B2 draws them in its filtered back
## layer, and only the plain wall colour sits outside it.
const CORNICE := Vector2(0, 6)
const CORNICE_EDGE := Vector2(6, 8)
const DADO_RAIL := Vector2(192, 196)
const DADO_LIGHT := Vector2(192, 193)
const LOWER_WALL := Vector2(196, 270)
const LOWER_SHADE := Vector2(192, 270)
const LOWER_SHADE_COLOR := Color(Palette.CHARCOAL, 0.3)
## Over the store sections the haze pushes them back (B2's plaster at 0.2, nudged up for B2's
## desaturation filter, which a flat band can't do); the cool wall shade tints the whole wall,
## the cashier too (B2's teal at 0.2, a modulate on the layer in B2's notes).
const HAZE_COLOR := Color(Palette.PLASTER, 0.28)
const WALL_SHADE_COLOR := Color(Palette.TEAL, 0.2)


## Adds the zoomed backdrop to `parent` (the StoreCamera's content), behind the stage's world:
## the wall (its first child), the warm pool, its bands, the store sections with their signs in
## the colours of `aisles` (the run's balance), the haze, the cashier, the wall shade and the
## lamp, then the counter and the floor. Returns the wall, which takes the background clicks;
## nothing else does.
static func screen_parts(parent: Control, aisles: Array[AisleDefinition] = []) -> ColorRect:
	var wall: ColorRect = _band("Wall", WALL_COLOR, 0.0, 1.0, 0.0, 0.0, WORLD_EXTRA)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(wall)
	parent.add_child(StoreShelves.wall_light())
	var bands: Array[ColorRect] = [
		_wall_band("Cornice", Palette.PLASTER_SHADE, CORNICE),
		_wall_band("CorniceEdge", Palette.PLASTER_DARK, CORNICE_EDGE),
		_wall_band("LowerWall", Palette.CREAM_SHADE, LOWER_WALL),
		_wall_band("DadoRail", Palette.PLASTER_DARK, DADO_RAIL),
		_wall_band("DadoLight", Palette.PLASTER_LIGHT, DADO_LIGHT),
		_wall_band("LowerShade", LOWER_SHADE_COLOR, LOWER_SHADE),
	]
	for band: ColorRect in bands:
		band.modulate = StoreShelves.depth_modulate()
		parent.add_child(band)
	parent.add_child(StoreShelves.new(aisles))
	var wall_span: Vector2 = Vector2(0, ShiftStage.COUNTER_TOP - ShiftStage.TOP_BAR_BOTTOM)
	parent.add_child(_wall_band("Haze", HAZE_COLOR, wall_span))
	parent.add_child(
		StoreShelves.stage_sprite(StoreShelves.CASHIER, StoreShelves.CASHIER_RECT, "Cashier")
	)
	parent.add_child(_wall_band("WallShade", WALL_SHADE_COLOR, wall_span))
	parent.add_child(StoreShelves.stage_sprite(StoreShelves.LAMP, StoreShelves.LAMP_RECT, "Lamp"))
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


## A full-width band of `color` on the wall, from `span.x` to `span.y` under the top bar (B2's
## wall coordinates).
static func _wall_band(band_name: String, color: Color, span: Vector2) -> ColorRect:
	var top: float = ShiftStage.TOP_BAR_BOTTOM - STAGE_MIDDLE
	return _band(band_name, color, 0.5, 0.5, top + span.x, top + span.y, WORLD_EXTRA)


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
