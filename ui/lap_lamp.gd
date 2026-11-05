class_name LapLamp
extends RefCounted
## The quota gauge's lap lamp (mock-up docs/art/mockups/shift_scene_polish_v4.html, A1): a round
## lamp over the gauge's steel housing, drawn on the art grid by QuotaMeter. An ink rim, a steel
## bezel (lit top left), and the lens inside it, 9 art px across: dark (steel dark, rubber dark)
## until the quota is made, then lit in the newest full lap's colours with its glyph: a check for
## the first lap, "×N" once N laps are made, in 3x5 pixel digits (from BARE_FROM laps the number
## alone, capped at MAX_SHOWN, so the glyph always stays inside the lens). A soft glow pulses round
## a lit lamp. Display arithmetic and drawing only.

## The lamp and its glow: art px diameters, and the squared radii of their discs. The lens is the
## lamp's disc inside its bezel, its shading measured from LENS_INSET art px in.
const SIZE := 13
const SIZE_R2 := 37
const LENS_INSET := 2
const GLOW := 17
const GLOW_R2 := 66
## The bezel's lit half (x + y under this, art px from the lamp's top left).
const BEZEL_LIGHT_SUM := 12
## The lens's lit corner and dark corner (x + y, art px from LENS_INSET in).
const LENS_LIT_SUM := 5
const LENS_DARK_SUM := 12
## The glyphs: 3x5 digits, a 3x3 "×" on their middle rows, a 7x5 check; GAP art px apart.
const DIGITS: Array[String] = [
	"###,#.#,#.#,#.#,###",
	".#.,##.,.#.,.#.,###",
	"###,..#,###,#..,###",
	"###,..#,.##,..#,###",
	"#.#,#.#,###,..#,..#",
	"###,#..,###,..#,###",
	"###,#..,###,#.#,###",
	"###,..#,..#,.#.,.#.",
	"###,#.#,###,#.#,###",
	"###,#.#,###,..#,###",
]
const TIMES := "...,#.#,.#.,#.#,..."
const CHECK := "......#,.....#.,#...#..,.#.#...,..#...."
const GAP := 1
const GLYPH_HEIGHT := 5
const CHECK_TEXT := "✓"
const TIMES_TEXT := "×"
## From this many laps the lamp drops the "×" (two digits fill the lens), and it never shows more
## than MAX_SHOWN.
const BARE_FROM := 10
const MAX_SHOWN := 99
## A disc cell's layer inside the bezel (the lens).
const LENS_LAYER := 3

static var _discs: Dictionary[int, Array] = {}


## The lamp's text for `laps` laps made: none for 0, the check for 1, "×N" from 2, the number
## alone from BARE_FROM (MAX_SHOWN at most).
static func text_for(laps: int) -> String:
	if laps <= 0:
		return ""
	if laps == 1:
		return CHECK_TEXT
	if laps >= BARE_FROM:
		return str(mini(laps, MAX_SHOWN))
	return TIMES_TEXT + str(laps)


## Whether every inked cell of `text`'s glyph, placed as draw() places it, falls on the lens.
static func glyph_fits(text: String) -> bool:
	var rows: PackedStringArray = glyph_rows(text)
	var layers: Array = _layers(SIZE, SIZE_R2)
	var at: Vector2i = _glyph_origin(rows)
	for row: int in range(rows.size()):
		for column: int in range(rows[row].length()):
			if rows[row][column] != "#":
				continue
			var x: int = at.x + column
			var y: int = at.y + row
			if x < 0 or x >= SIZE or y < 0 or y >= SIZE:
				return false
			var line: PackedInt32Array = layers[y]
			if line[x] != LENS_LAYER:
				return false
	return true


## The rows of `text`'s glyphs side by side ('#' inked), GLYPH_HEIGHT rows.
static func glyph_rows(text: String) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	rows.resize(GLYPH_HEIGHT)
	for index: int in range(text.length()):
		var character: String = text[index]
		var glyph: String = CHECK
		if character == TIMES_TEXT:
			glyph = TIMES
		elif character.is_valid_int():
			glyph = DIGITS[character.to_int()]
		var lines: PackedStringArray = glyph.split(",")
		for row: int in range(GLYPH_HEIGHT):
			rows[row] += ("." if index > 0 else "").repeat(GAP) + lines[row]
	return rows


## Draws the lamp on `item` with its top left at `origin` (px), `cell` px per art px: dark with no
## `ramp`, else lit in it with `text`, its glow at `glow` alpha (0 for none), the lens and glyph
## scaled by `pop` about the lamp's middle.
static func draw(
	item: CanvasItem,
	origin: Vector2,
	cell: float,
	ramp: Array[Color],
	text: String,
	glow: float = 0.0,
	pop: float = 1.0
) -> void:
	var lit: bool = not ramp.is_empty()
	if lit and glow > 0.0:
		var shift: float = (GLOW - SIZE) / 2.0
		_disc(
			item,
			origin - Vector2(shift, shift) * cell,
			cell,
			GLOW,
			GLOW_R2,
			func(_layer: int, _x: int, _y: int) -> Color: return Color(ramp[0], glow)
		)
	_disc(
		item,
		origin,
		cell,
		SIZE,
		SIZE_R2,
		func(layer: int, x: int, y: int) -> Color:
			if layer == 2:
				return Palette.STEEL_LIGHT if x + y < BEZEL_LIGHT_SUM else Palette.STEEL_SHADE
			return Palette.INK
	)
	var middle: Vector2 = origin + Vector2(SIZE, SIZE) * cell / 2.0
	item.draw_set_transform(middle * (1.0 - pop), 0.0, Vector2.ONE * pop)
	_disc(
		item,
		origin,
		cell,
		SIZE,
		SIZE_R2,
		func(layer: int, x: int, y: int) -> Color:
			var sum: int = x + y - 2 * LENS_INSET
			if layer < LENS_LAYER:
				return Color(Palette.INK, 0.0)
			if not lit:
				return Palette.STEEL_DARK if sum <= LENS_LIT_SUM else Palette.RUBBER_DARK
			if sum <= LENS_LIT_SUM:
				return ramp[0]
			return ramp[2] if sum >= LENS_DARK_SUM else ramp[1]
	)
	if lit and not text.is_empty():
		var rows: PackedStringArray = glyph_rows(text)
		var ink: Color = QuotaLaps.lamp_ink(ramp)
		var glyph_at: Vector2i = _glyph_origin(rows)
		for row: int in range(rows.size()):
			for column: int in range(rows[row].length()):
				if rows[row][column] == "#":
					var at: Vector2 = origin + Vector2(glyph_at + Vector2i(column, row)) * cell
					item.draw_rect(Rect2(at, Vector2(cell, cell)), ink)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)


## The top left (art px in the lamp) of the glyph `rows`: centred, left-leaning on odd room.
static func _glyph_origin(rows: PackedStringArray) -> Vector2i:
	return Vector2i(floori((SIZE - rows[0].length()) / 2.0), floori((SIZE - GLYPH_HEIGHT) / 2.0))


## A disc `size` art px across (squared radius `r2`) at `origin`: each cell coloured by
## `colour`(layer, x, y), layer 1 its rim, 2 the ring inside it, 3 the rest.
static func _disc(
	item: CanvasItem, origin: Vector2, cell: float, size: int, r2: int, colour: Callable
) -> void:
	var layers: Array = _layers(size, r2)
	for y: int in range(size):
		var line: PackedInt32Array = layers[y]
		for x: int in range(size):
			if line[x] > 0:
				var at: Vector2 = origin + Vector2(x, y) * cell
				var shade: Color = colour.call(line[x], x, y)
				if shade.a > 0.0:
					item.draw_rect(Rect2(at, Vector2(cell, cell)), shade)


## A disc's layers (the mock-up's discLayers), cached: rows of 0 (outside), 1 (rim: an edge
## cell), 2 (next to the rim) or 3.
static func _layers(size: int, r2: int) -> Array:
	var key: int = size * 1000 + r2
	if _discs.has(key):
		return _discs[key]
	var centre: float = (size - 1) / 2.0
	var inside: Array[PackedInt32Array] = []
	for y: int in range(size):
		var line: PackedInt32Array = PackedInt32Array()
		for x: int in range(size):
			var reach: float = (x - centre) ** 2 + (y - centre) ** 2
			line.append(3 if reach <= r2 else 0)
		inside.append(line)
	var rim: Array[PackedInt32Array] = []
	for y: int in range(size):
		var line: PackedInt32Array = inside[y].duplicate()
		for x: int in range(size):
			if line[x] > 0 and _edge(inside, x, y, 0):
				line[x] = 1
		rim.append(line)
	var layers: Array = []
	for y: int in range(size):
		var line: PackedInt32Array = rim[y].duplicate()
		for x: int in range(size):
			if line[x] == 3 and _edge(rim, x, y, 1):
				line[x] = 2
		layers.append(line)
	_discs[key] = layers
	return layers


## Whether a 4-neighbour of (x, y) in `grid` is `value` (outside the grid counts as 0).
static func _edge(grid: Array[PackedInt32Array], x: int, y: int, value: int) -> bool:
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var at: Vector2i = Vector2i(x, y) + step
		var cell_value: int = 0
		if at.y >= 0 and at.y < grid.size() and at.x >= 0 and at.x < grid[at.y].size():
			cell_value = grid[at.y][at.x]
		if cell_value == value:
			return true
	return false
