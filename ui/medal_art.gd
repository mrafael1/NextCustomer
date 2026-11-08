class_name MedalArt
extends RefCounted
## The week's medals' pixel art (2026-11-06, mock-up docs/art/mockups/week_medals.html: drawCoin,
## drawSocket): a plain metal coin with no symbol on it (the user found the star weird), its metal
## alone saying which is which. An ink edge, a raised rim (lit top left, shaded bottom right), the
## face with a lighter top-left part and a small paper shine. An empty socket is a quiet engraved
## circle: a dark top-left edge, a light bottom-right one and a faint recess, drawn in ink and paper
## at low alpha so it reads on every week colour of the chip. Drawn on a grid of `cells` square
## pixels, `cell` px each, the mock-up's 13-pixel coin scaled to any grid (the chip draws it in
## whole screen pixels). Display only.

## The coin's grid in the mock-up (canvas px).
const SIZE := 13
## The disc's layers by the squared distance from the middle over the squared radius (the
## mock-up's 42, 30 and 17 of 6.5²): inside the coin, the ink edge past EDGE, the rim past RIM.
const OUTSIDE := 0.994
const EDGE := 0.71
const RIM := 0.40
## The lit and shaded sides: (dx + dy) / radius under -LIT is lit, over LIT shaded; the face's lit
## part under -FACE_LIT.
const LIT := 0.31
const FACE_LIT := 0.46
## The shine: paper pixels at these shares of the radius from the middle (up and left).
const SHINE: Array[Vector2] = [Vector2(-0.3, -0.5), Vector2(-0.5, -0.3)]
## A glint running round the rim (pending): its half-width in radians.
const GLINT_SPREAD := 0.5
## The socket's engraving, in ink and paper over the chip's colour.
const SOCKET_DEEP := 0.45
const SOCKET_FAINT := 0.35
const SOCKET_RECESS := 0.16
## Each metal's rim, face, lit part and shade (the mock-up's METAL), in Palette's steels and golds
## (the silver a step darker than the mock-up's, so it reads as metal, not paper).
const SILVER: Array[Color] = [
	Palette.STEEL, Palette.STEEL_LIGHT, Palette.STEEL_HIGHLIGHT, Palette.STEEL_SHADE
]
const GOLD: Array[Color] = [
	Palette.MUSTARD, Palette.GOLD, Palette.MUSTARD_PALE, Palette.MUSTARD_DARK
]


## Metal `gold`'s colours: rim, face, lit part, shade.
static func metal(gold: bool) -> Array[Color]:
	return GOLD if gold else SILVER


## The grid for a coin drawn at `scale_x` screen pixels per canvas pixel: SIZE scaled, odd so the
## coin has a middle pixel.
static func cells_at(scale_x: float) -> int:
	var cells: int = maxi(5, roundi(SIZE * scale_x))
	return cells if cells % 2 == 1 else cells - 1


## The coin of metal `gold` with its top left at `origin`, `cells` pixels of `cell` px across, at
## `alpha`; a glint on its rim at angle `glint` (radians, below 0: none).
static func draw_coin(
	item: CanvasItem,
	origin: Vector2,
	cells: int,
	cell: float,
	gold: bool,
	alpha: float = 1.0,
	glint: float = -1.0
) -> void:
	var colours: Array[Color] = metal(gold)
	var radius: float = cells / 2.0
	var middle: float = (cells - 1) / 2.0
	var shine: Array[Vector2i] = []
	for share: Vector2 in SHINE:
		shine.append(Vector2i((Vector2(middle, middle) + share * radius).round()))
	for y: int in range(cells):
		for x: int in range(cells):
			var d: Vector2 = Vector2(x - middle, y - middle)
			var reach: float = d.length_squared() / (radius * radius)
			if reach > OUTSIDE:
				continue
			var side: float = (d.x + d.y) / radius
			var colour: Color = colours[1]
			if reach > EDGE:
				colour = Palette.INK
			elif reach > RIM:
				colour = colours[2] if side < -LIT else (colours[3] if side > LIT else colours[0])
				if glint >= 0.0 and absf(angle_difference(d.angle(), glint)) < GLINT_SPREAD:
					colour = Palette.PAPER
			elif shine.has(Vector2i(x, y)):
				colour = Palette.PAPER
			elif side < -FACE_LIT:
				colour = colours[2]
			_pixel(item, origin, cell, x, y, Color(colour, colour.a * alpha))


## The empty socket, `cells` pixels of `cell` px across from `origin`: an engraved circle.
static func draw_socket(item: CanvasItem, origin: Vector2, cells: int, cell: float) -> void:
	var radius: float = cells / 2.0
	var middle: float = (cells - 1) / 2.0
	for y: int in range(cells):
		for x: int in range(cells):
			var d: Vector2 = Vector2(x - middle, y - middle)
			var reach: float = d.length_squared() / (radius * radius)
			if reach > OUTSIDE:
				continue
			var colour: Color = Color(Palette.INK, SOCKET_RECESS)
			if reach > EDGE:
				if d.x + d.y < 0.0:
					colour = Color(Palette.INK, SOCKET_DEEP)
				else:
					colour = Color(Palette.PAPER, SOCKET_FAINT)
			_pixel(item, origin, cell, x, y, colour)


## A soft halo round a coin `cells` across from `origin`: one ring of pixels just outside it in
## `colour` (a pending medal's).
static func draw_halo(
	item: CanvasItem, origin: Vector2, cells: int, cell: float, colour: Color
) -> void:
	var radius: float = cells / 2.0
	var middle: float = (cells - 1) / 2.0
	for y: int in range(-1, cells + 1):
		for x: int in range(-1, cells + 1):
			var reach: float = Vector2(x - middle, y - middle).length_squared() / (radius * radius)
			if reach > OUTSIDE and reach <= 1.35:
				_pixel(item, origin, cell, x, y, colour)


static func _pixel(
	item: CanvasItem, origin: Vector2, cell: float, x: int, y: int, colour: Color
) -> void:
	if colour.a <= 0.0:
		return
	item.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), colour)
