class_name MedalArt
extends RefCounted
## The week's medals' pixel art (v1.17, the user's pick of 2026-11-08: the medal case of mock-up
## docs/art/mockups/main_scene_v2.html, its medal(), ribbon() and twinkles()): a big plain medal
## with no symbol on it, its metal alone saying which is which: an ink edge, a bevelled rim (lit
## top left, shaded bottom right), the face lighter to the top left and darker to the bottom
## right, a paper glint. PENDING (the plan would win it) sweeps a paper diagonal across its face.
## An empty (USED) socket is an engraved ring, rubber and steel dark in a checker, on the rubber.
## A striped ribbon hangs it from the coin rail (SILVER: teal and white; GOLD: tomato and gold),
## and a 4-point paper twinkle hops round it. Drawn on a grid of SIZE cells, `cell` px each (the
## case at 2 stage px per art px; the flight scales it). Palette colours only. Display only.

## A disc's cells' layers (layers_of): outside, the edge ring, the bevel ring, the face.
enum Layer { OUTSIDE, EDGE, BEVEL, FACE }

## The medal's grid (art px across).
const SIZE := 17
## The mask's squeeze (the mock-up's r² - 1.2 for a big disc).
const MASK_SQUEEZE := 1.2
## The PENDING sweep: one diagonal step every SWEEP_STEP s, over the face's SIZE * 3 diagonals.
const SWEEP_STEP := 0.07
## Each metal: its lit face, its face and its shade (the mock-up's METAL).
const SILVER: Array[Color] = [Palette.STEEL_HIGHLIGHT, Palette.STEEL_LIGHT, Palette.STEEL]
const GOLD: Array[Color] = [Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD_DARK]
## The ribbons' base and middle stripes.
const SILVER_RIBBON: Array[Color] = [Palette.TEAL_SHADE, Palette.STEEL_HIGHLIGHT]
const GOLD_RIBBON: Array[Color] = [Palette.TOMATO_DARK, Palette.GOLD]
## layers_of's grids by size.
static var _layers: Dictionary[int, PackedByteArray] = {}


## Metal `gold`'s colours: lit face, face, shade.
static func metal(gold: bool) -> Array[Color]:
	return GOLD if gold else SILVER


## Whether cell (`x`, `y`) of a `cells`-wide disc is inside it.
static func inside(x: int, y: int, cells: int) -> bool:
	if x < 0 or y < 0 or x >= cells or y >= cells:
		return false
	var r: float = cells / 2.0
	var a: float = x + 0.5 - r
	var b: float = y + 0.5 - r
	return a * a + b * b <= r * r - (MASK_SQUEEZE if cells > 8 else 0.6)


## The sweep's diagonal at `seconds` (PENDING's paper line), for draw_medal's `sweep`.
static func sweep_at(seconds: float, cells: int = SIZE) -> int:
	return floori(seconds / SWEEP_STEP) % (cells * 3)


## The medal of metal `gold` with its top left at `origin`, `cells` across, `cell` px each:
## `empty` draws its engraved socket instead; `sweep` (0 or more) a PENDING diagonal of paper.
static func draw_medal(
	item: CanvasItem,
	origin: Vector2,
	cells: int,
	cell: float,
	gold: bool,
	empty: bool = false,
	sweep: int = -1
) -> void:
	var colours: Array[Color] = metal(gold)
	var layers: PackedByteArray = layers_of(cells)
	for y: int in range(cells):
		for x: int in range(cells):
			var layer: int = layers[y * cells + x]
			if layer == Layer.OUTSIDE:
				continue
			var colour: Color = colours[1]
			if empty:
				colour = Palette.RUBBER
				if layer == Layer.EDGE and (x + y) % 2 == 0:
					colour = Palette.STEEL_DARK
			elif layer == Layer.EDGE:
				colour = Palette.INK
			elif layer == Layer.BEVEL:
				colour = colours[1] if x + y < cells else colours[2]
			else:
				if x + y <= cells - 4:
					colour = colours[0]
				if x + y >= cells + 3:
					colour = colours[2]
				if x + y == 5 and x >= 2 and y >= 2:
					colour = Palette.PAPER
				if sweep >= 0 and (x + y == sweep or x + y == sweep - 1):
					colour = Palette.PAPER
			item.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), colour)


## A `cells`-wide disc's layers, row by row (Layer): the edge one step from the outside, the
## bevel two, the face. Worked out once per size.
static func layers_of(cells: int) -> PackedByteArray:
	if not _layers.has(cells):
		var grid: PackedByteArray = PackedByteArray()
		grid.resize(cells * cells)
		for y: int in range(cells):
			for x: int in range(cells):
				var layer: int = Layer.FACE
				if not inside(x, y, cells):
					layer = Layer.OUTSIDE
				elif _ring(x, y, cells, 1):
					layer = Layer.EDGE
				elif _ring(x, y, cells, 2):
					layer = Layer.BEVEL
				grid[y * cells + x] = layer
		_layers[cells] = grid
	return _layers[cells]


## A ribbon in `rect` (px): ink sides, its base stripe inset `cell`, its middle stripe inset
## 3 `cell`s (SILVER teal and white, GOLD tomato and gold).
static func draw_ribbon(item: CanvasItem, rect: Rect2, gold: bool, cell: float) -> void:
	var stripes: Array[Color] = GOLD_RIBBON if gold else SILVER_RIBBON
	item.draw_rect(rect, Palette.INK)
	item.draw_rect(rect.grow_individual(-cell, 0, -cell, 0), stripes[0])
	item.draw_rect(rect.grow_individual(-3 * cell, 0, -3 * cell, 0), stripes[1])


## A 4-point twinkle: a paper plus of arms `arm` cells round the cell at `at` (its top left).
static func draw_twinkle(item: CanvasItem, at: Vector2, arm: int, cell: float) -> void:
	var square: Vector2 = Vector2(cell, cell)
	item.draw_rect(Rect2(at, square), Palette.PAPER)
	for step: int in range(1, arm + 1):
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			item.draw_rect(Rect2(at + direction * step * cell, square), Palette.PAPER)


## Whether cell (`x`, `y`) is within `reach` steps (diamond) of the disc's outside.
static func _ring(x: int, y: int, cells: int, reach: int) -> bool:
	for a: int in range(-reach, reach + 1):
		for b: int in range(-reach, reach + 1):
			if absi(a) + absi(b) <= reach and not inside(x + a, y + b, cells):
				return true
	return false
