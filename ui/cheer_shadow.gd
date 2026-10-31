class_name CheerShadow
extends Control
## A cardboard standee's ground shadow (#120, for the clean scene of #123). The pendant lamps hang
## over the store behind the counter, so a standee's shadow falls forward onto the visible ground
## under it: the lit top face of the belt's steel guard, the first thing in front of where it
## stands (the store's dark wall would hide a darker patch). It is drawn as the store is painted:
## flat palette cells (COLOR) on the 2 px art grid in a Bayer dither, solid at the core and
## sparser to its rim, no outline; the near half of a flat ellipse centred under the standee.
## Its standee (CheerStandee.shadow) poses it: it stays on the ground, narrows and lightens as
## the standee hops (CountUpTuning's cheer_shadow_*), rises in and fades with its `level`, narrows
## with its `fold` (a fold, a topple), and CheckoutCrowd frees it with its standee. It lives in
## the crowd's shadow layer (CheckoutCrowd.shadow_layer, which the stage lays on the belt under
## the row), and takes no clicks.

## The art grid every cell lands on (the store's: StoreArt at ArtStyle.ART_SCALE).
const GRID := CheerStandee.GRID
## The guard's lit face starts this many art rows under the ground line (the belt's top: belt_top's
## clear row, then the guard's ink edge) and is ROWS art rows tall.
const DROP_ROWS := 2
const ROWS := 2
## The dither's share of cells at the core, falling off to EDGE_DENSITY at the rim.
const CORE_DENSITY := 1.0
const EDGE_DENSITY := 0.35
## A 4x4 Bayer matrix (as StoreArt's), indexed on the art grid so the dither never crawls.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## The guard's face in shade (its own steel ramp, a step under the lit face).
const COLOR := Palette.STEEL_SHADE

## Where the crowd's origin is in this shadow's parent (the shadow layer): its poses are given in
## the crowd's coordinates.
var origin: Vector2 = Vector2.ZERO
## The ground line it lies on and its centre, in the crowd's coordinates.
var ground_y: float = 0.0
var center_x: float = 0.0
## Its full width (px, on the grid) and darkness (0 gone, 1 at rest).
var width: float = 0.0
var strength: float = 0.0


func _init() -> void:
	name = "Shadow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lies `full_width` px wide (snapped to the grid), centred on `center`, on the ground line
## `ground` (the crowd's coordinates), at `dark` (0 to 1) of its rest darkness.
func set_pose(center: float, ground: float, full_width: float, dark: float) -> void:
	center_x = center
	ground_y = ground
	strength = clampf(dark, 0.0, 1.0)
	width = maxf(0.0, floorf(full_width / (2.0 * GRID)) * 2.0 * GRID)
	visible = width >= 2.0 * GRID and strength > 0.0
	size = Vector2(width, ROWS * GRID)
	var left: float = snappedf(center - width / 2.0, GRID)
	position = origin + Vector2(left, ground + DROP_ROWS * GRID)
	queue_redraw()


## Its rect in the crowd's coordinates, empty when it shows nothing.
func ground_rect() -> Rect2:
	return Rect2(position - origin, size if visible else Vector2.ZERO)


## The cells it draws (local px rects), for its _draw and the tests.
func cells() -> Array[Rect2]:
	var drawn: Array[Rect2] = []
	if not visible:
		return drawn
	var columns: int = int(width / GRID)
	for row: int in range(ROWS):
		# The ellipse's centre line is just behind the face: row 0 is nearest it.
		var v: float = (row + 0.5) / (ROWS + 1)
		for column: int in range(columns):
			var u: float = (column + 0.5) / columns * 2.0 - 1.0
			var reach: float = u * u + v * v
			if reach > 1.0:
				continue
			var density: float = lerpf(CORE_DENSITY, EDGE_DENSITY, reach) * strength
			var art_x: int = int(roundf((position.x - origin.x) / GRID)) + column
			var art_y: int = int(roundf((position.y - origin.y) / GRID)) + row
			if BAYER[posmod(art_y, 4) * 4 + posmod(art_x, 4)] < density * BAYER.size():
				drawn.append(Rect2(column * GRID, row * GRID, GRID, GRID))
	return drawn


func _draw() -> void:
	for cell: Rect2 in cells():
		draw_rect(cell, COLOR)
