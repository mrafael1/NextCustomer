class_name StorefrontArt
extends RefCounted
## The title's storefront at night (#56, mock-up title_premium_directions.html, direction C+),
## painted once into images on the 640x360 art grid (one art px = ArtStyle.ART_SCALE canvas px)
## and shown with nearest filtering by Storefront. Every colour is the palette's. The painting
## follows the mock-up's canvas code rect for rect, in stage art coordinates (the 640x360
## stage's top left is 0,0).
##
## The backdrop holds everything that never changes: the sky and its stars, the cornice, the
## brick, the fascia with its teal and tomato stripe and brass rail (since v0.80 it ends left of
## the REWARDS bay), the sconce, the left window's shelves, the doors' warm inside (the leaves are
## a layer), the right window with its tube off (the store's light dimmed; since v0.80 both
## windows show the same warm store as the doors, the left one's shelves stocked row by row),
## the sidewalk and the street. It is painted as wide and tall as the window needs (`extend`), so
## the sky, the brick and the street run on past the stage with no letterbox gap. The live parts
## are separate layers, each painted at its own rect: the sconce's light wedge, the right window
## with its tube on, the sidewalk's neon reflections, the doors' light spill (calm and bright),
## one door leaf, the REWARDS bay at night and lit, and the bay's sliding glass.

## The stage in art px.
const STAGE := Vector2i(640, 360)
## The layers' rects, in stage art px.
const WEDGE_RECT := Rect2i(12, 128, 172, 168)
const TUBE_WINDOW_RECT := Rect2i(376, 128, 124, 164)
const REFLECTIONS_RECT := Rect2i(206, 300, 224, 28)
const SPILL_RECT := Rect2i(252, 296, 136, 38)
const DOORS_RECT := Rect2i(268, 132, 104, 160)
const LEAF_SIZE := Vector2i(52, 160)
const BAY_RECT := Rect2i(504, 108, 128, 184)
const LEFT_WINDOW_RECT := Rect2i(200, 128, 64, 164)
## The bay's toy machine (BareToyMachine, 72x118 art) and its glass pane's rect, from the bay's
## top left.
const BAY_MACHINE := Vector2i(28, 62)
const BAY_GLASS := Rect2i(2, 26, 124, 154)
## The sconce over the menu and the door's sensor.
const SCONCE := Vector2i(92, 120)
## Each live layer's rect (the bay's two looks take BAY_RECT).
const LAYER_RECTS: Dictionary[String, Rect2i] = {
	"wedge": WEDGE_RECT,
	"tube_on": TUBE_WINDOW_RECT,
	"reflections": REFLECTIONS_RECT,
	"spill": SPILL_RECT,
	"spill_hot": SPILL_RECT,
	"leaf": Rect2i(DOORS_RECT.position, LEAF_SIZE),
	"glass": Rect2i(BAY_RECT.position + BAY_GLASS.position, BAY_GLASS.size),
}
const SENSOR := Vector2i(312, 122)
## The bands that run past the stage: the sky's dither rows, the cornice, the brick, the sidewalk
## (its joints JOINT apart), the curb and the street (its dashes DASH apart).
const SKY_HAZE := Vector2i(28, 40)
const CORNICE := Vector2i(40, 48)
const UPPER_BRICK := Vector2i(48, 116)
const LOWER_BRICK := Vector2i(116, 296)
const SIDEWALK := Vector2i(296, 334)
const CURB := Vector2i(334, 336)
const JOINT := 32
const DASH := 48
## The bricks: BRICK_W apart (11 px and a mortar px), BRICK_H rows (4 px and mortar), every other
## row offset by half a brick; one in BRICK_DARK_EVERY is the dark brown.
const BRICK_W := 12
const BRICK_H := 5
const BRICK_DARK_EVERY := 5
## The stars (the mock-up's 26, their x STAR_STEP apart round the stage, on the sky's top rows);
## every STAR_GOLD_EVERY one is a pale mustard star, and one in STAR_HIDDEN_EVERY is not out.
const STARS := 26
const STAR_STEP := 137
const STAR_ROW_STEP := 53
const STAR_ROWS := 34
const STAR_GOLD_EVERY := 3
const STAR_HIDDEN_EVERY := 9
## The sky above a tall window's stage repeats the stars in bands this many rows high.
const STAR_BAND := 40
## The fascia (stage art px): centred over the doors, clear of the REWARDS bay.
const FASCIA_RECT := Rect2i(140, 48, 360, 68)
const MINI_PATH := "res://art/minis/%s.png"
## The left window's four shelves, top to bottom, each its own aisle (v0.80: no shelf repeats
## another); a shelf of five sits its minis WINDOW_GAPS[1] apart, one of four WINDOW_GAPS[0].
const WINDOW_SHELVES: Array[String] = [
	"milk cheese eggs yogurt butter",
	"banana lemon strawberries potatoes",
	"bread croissant baguette scone iced_bun",
	"coffee tea_bags soup cereal",
]
const WINDOW_GAPS: Array[int] = [13, 11]
## The doors' aisles: the left one's two shelves, then the right one's (two minis a shelf).
const DOOR_MINIS: Array[String] = [
	"milk", "cheese", "bread", "croissant", "banana", "lemon", "coffee", "cereal"
]
## The store's lit back wall in 20-row bands, top down (the doors' and the windows').
const STORE_BANDS: Array[Color] = [
	Palette.MUSTARD_LIGHT, Palette.MUSTARD_PALE, Palette.PLASTER_LIGHT, Palette.PLASTER
]
## The till letters (3x5) of the props' small lettering: the bay's REWARDS vinyl, the poster's
## LOYAL and SOON, the doors' OPEN, register 3's number and the sign's € tag; the toy
## machines' OUT OF ORDER tape (ToyExitArt, #121).
const TILL: Dictionary[String, String] = {
	"A": "010101111101101",
	"D": "110101101101110",
	"E": "111100110100111",
	"F": "111100110100100",
	"L": "100100100100111",
	"N": "110101101101101",
	"O": "010101101101010",
	"P": "110101110100100",
	"R": "110101110101101",
	"S": "011100010001110",
	"T": "111010010010010",
	"U": "101101101101111",
	"W": "101101111111101",
	"Y": "101101010010010",
	"3": "110001010001110",
	"€": "011100111100011",
	" ": "000000000000000",
}

## The cached backdrops, by size and origin (a window size seen once is often seen again).
static var _backdrops: Dictionary[Vector4i, ImageTexture] = {}
static var _layers: Dictionary[String, ImageTexture] = {}

## The image being painted and the stage's top left in it, in art px.
var image: Image
var origin: Vector2i


func _init(size_px: Vector2i, stage_origin: Vector2i) -> void:
	image = Image.create_empty(maxi(size_px.x, 1), maxi(size_px.y, 1), false, Image.FORMAT_RGBA8)
	origin = stage_origin


## The backdrop for a window that shows `extend` art px past the stage on each side (left, top,
## right, bottom), with the stage at (left, top) in it.
static func backdrop(extend: Vector4i) -> ImageTexture:
	if not _backdrops.has(extend):
		if _backdrops.size() > 6:
			_backdrops.clear()
		var size_px: Vector2i = STAGE + Vector2i(extend.x + extend.z, extend.y + extend.w)
		var art: StorefrontArt = StorefrontArt.new(size_px, Vector2i(extend.x, extend.y))
		art._paint_backdrop()
		_backdrops[extend] = ImageTexture.create_from_image(art.image)
	return _backdrops[extend]


## A live layer's texture, painted once: "wedge", "tube_on", "reflections", "spill", "spill_hot",
## "leaf", "glass", "bay_night" or "bay_lit".
static func layer(id: String) -> ImageTexture:
	if not _layers.has(id):
		var art: StorefrontArt = _paint_layer(id)
		_layers[id] = ImageTexture.create_from_image(art.image)
	return _layers[id]


## The rect a layer is shown at, in stage art px.
static func layer_rect(id: String) -> Rect2i:
	return LAYER_RECTS.get(id, BAY_RECT)


static func _paint_layer(id: String) -> StorefrontArt:
	var area: Rect2i = layer_rect(id)
	var art: StorefrontArt = StorefrontArt.new(area.size, -area.position)
	match id:
		"wedge":
			art.cone(97, 128, 296, Vector2i(14, 170), Palette.MUSTARD_DARKEST, 1)
		"tube_on":
			art._window_register(TUBE_WINDOW_RECT, true)
		"reflections":
			for i: int in 14:
				var colour: Color = Palette.TEAL_SHADE if i < 4 else Palette.TOMATO_DARK
				art.dither(
					Rect2i(206 + i * 17, 300 + (i % 3) * 3, 3, 28 - (i % 3) * 6), colour, 1, i % 2
				)
		"spill", "spill_hot":
			var colour: Color = (
				Palette.MUSTARD_DARK if id == "spill_hot" else Palette.MUSTARD_DARKEST
			)
			art.cone(320, 296, 334, Vector2i(104, 136), colour, 1)
		"leaf":
			art._leaf(area.position)
		"glass":
			art.dither(area, Palette.TEAL_PALE, 1)
		_:
			art._bay(id == "bay_lit")
	return art


## Fills a rect (stage art px), clipped to the image.
func rect(area: Rect2i, colour: Color) -> void:
	var clipped: Rect2i = Rect2i(area.position + origin, area.size).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	if clipped.has_area():
		image.fill_rect(clipped, colour)


func px(x: int, y: int, colour: Color) -> void:
	rect(Rect2i(x, y, 1, 1), colour)


## Dithers a rect with `colour` on the stage's 2x2 grid: level 1 one px in four, 2 a checker,
## 3 three in four; `phase` shifts the pattern one px right.
func dither(area: Rect2i, colour: Color, level: int, phase: int = 0) -> void:
	var clipped: Rect2i = Rect2i(area.position + origin, area.size).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)
	for y: int in range(clipped.position.y, clipped.end.y):
		var row: int = posmod(y - origin.y, 2)
		for x: int in range(clipped.position.x, clipped.end.x):
			if _dithered(posmod(x - origin.x - phase, 2), row, level):
				image.set_pixel(x, y, colour)


## A dithered cone of light widening from `widths.x` at y0 to `widths.y` at y1, centred on cx,
## in 2-row steps; `level` 0 makes its top quarter a checker and the rest one px in four.
func cone(cx: int, y0: int, y1: int, widths: Vector2i, colour: Color, level: int) -> void:
	for y: int in range(y0, y1, 2):
		var share: float = float(y - y0) / float(y1 - y0)
		var width: int = roundi(lerpf(widths.x, widths.y, share) / 2.0) * 2
		var step: int = level if level > 0 else (2 if share < 0.25 else 1)
		dither(Rect2i(cx - floori(width / 2.0), y, width, 2), colour, step)


## The till letters of `text` with their top left at (x, y) (align "c" centres them on x).
func till(text: String, x: int, y: int, colour: Color, align: String = "") -> void:
	var left: int = x
	if align == "c":
		left -= floori((text.length() * 4 - 1) / 2.0)
	for character: String in text:
		var bits: String = TILL.get(character, TILL[" "])
		for i: int in 15:
			if bits[i] == "1":
				px(left + i % 3, y + floori(i / 3.0), colour)
		left += 4


## A filled pixel disc of diameter `d` with its box's top left at (x, y).
func disc(x: int, y: int, d: int, colour: Color) -> void:
	var r: float = d / 2.0
	for j: int in d:
		var dy: float = j + 0.5 - r
		var half: int = floori(sqrt(maxf(0.0, r * r - dy * dy)) + 0.5)
		rect(Rect2i(x + floori(r - half + 0.5), y + j, half * 2, 1), colour)


## Draws a sprite's pixels with its top left at (x, y), hazed towards the night's teal black by
## `haze` (0 keeps its colours).
func blit(texture: Texture2D, x: int, y: int, haze: float = 0.0) -> void:
	var source: Image = texture.get_image()
	if source.is_compressed():
		source.decompress()
	for j: int in source.get_height():
		for i: int in source.get_width():
			var colour: Color = source.get_pixel(i, j)
			if colour.a < 0.5:
				continue
			px(x + i, y + j, Color(colour.lerp(Palette.TEAL_BLACK, haze), 1.0))


static func _dithered(column: int, row: int, level: int) -> bool:
	match level:
		1:
			return column == 0 and row == 0
		2:
			return column == row
		_:
			return row == 0 or column == 1


func _paint_backdrop() -> void:
	var left: int = -origin.x
	var width: int = image.get_width()
	var all_x := Vector2i(left, width)
	rect(Rect2i(left, -origin.y, width, origin.y + SKY_HAZE.y + 8), Palette.TEAL_BLACK)
	dither(Rect2i(left, SKY_HAZE.x, width, 12), Palette.VELVET_DARKEST, 1)
	_stars(all_x)
	rect(Rect2i(560, 14, 8, 1), Palette.TEAL_SHADE)
	rect(Rect2i(left, CORNICE.x, width, 8), Palette.STEEL_DARKEST)
	rect(Rect2i(left, CORNICE.x, width, 1), Palette.STEEL_SHADE)
	rect(Rect2i(left, CORNICE.y - 1, width, 1), Palette.CHARCOAL)
	_brick(all_x, UPPER_BRICK)
	_fascia()
	_brick(all_x, LOWER_BRICK)
	# The sconce over the menu (its wedge of light is a layer).
	rect(Rect2i(SCONCE, Vector2i(10, 6)), Palette.INK)
	rect(Rect2i(SCONCE + Vector2i(1, 1), Vector2i(8, 4)), Palette.BRASS)
	rect(Rect2i(SCONCE + Vector2i(2, 6), Vector2i(6, 2)), Palette.MUSTARD_LIGHT)
	_window_shelves(LEFT_WINDOW_RECT)
	_doors_inside(DOORS_RECT)
	rect(Rect2i(SENSOR, Vector2i(10, 6)), Palette.CHARCOAL)
	px(SENSOR.x + 8, SENSOR.y + 2, Palette.TOMATO)
	_window_register(TUBE_WINDOW_RECT, false)
	_street(all_x)


## The stars: the stage's pattern repeated across `span` (left, width), and up the sky above the
## stage in STAR_BAND-row bands.
func _stars(span: Vector2i) -> void:
	var first: int = floori(float(span.x) / STAGE.x)
	var last: int = floori(float(span.x + span.y) / STAGE.x)
	var top_band: int = floori(float(-origin.y) / STAR_BAND)
	for band: int in range(top_band, 1):
		for tile: int in range(first, last + 1):
			for i: int in STARS:
				if i % STAR_HIDDEN_EVERY == 0:
					continue
				var x: int = (i * STAR_STEP + band * STAR_ROW_STEP) % STAGE.x + tile * STAGE.x
				var y: int = (i * STAR_ROW_STEP) % STAR_ROWS + 2 + band * STAR_BAND
				px(x, y, Palette.TEAL_LIGHT if i % STAR_GOLD_EVERY else Palette.MUSTARD_PALE)


## Star `i`'s place on the stage (art px), as _stars paints it.
static func star_at(i: int) -> Vector2i:
	return Vector2i((i * STAR_STEP) % STAGE.x, (i * STAR_ROW_STEP) % STAR_ROWS + 2)


## The brick between rows `rows` (top, bottom) across `span` (left, width): the velvet mortar,
## the bricks in rows, every other row half a brick over, then the night's one-in-four dither.
func _brick(span: Vector2i, rows: Vector2i) -> void:
	rect(Rect2i(span.x, rows.x, span.y, rows.y - rows.x), Palette.VELVET_DARKEST)
	var row: int = 0
	while rows.x + row * BRICK_H < rows.y:
		var offset: int = floori(BRICK_W / 2.0) if row % 2 else 0
		var first: int = floori(float(span.x + offset) / BRICK_W) * BRICK_W - offset
		var x: int = first
		while x < span.x + span.y:
			var dark: bool = posmod(row * 7 + x, BRICK_DARK_EVERY) == 0
			var top: int = rows.x + row * BRICK_H
			var brick := Rect2i(x, top, BRICK_W - 1, BRICK_H - 1)
			rect(brick, Palette.BROWN_DARKEST if dark else Palette.VELVET_DARK)
			x += BRICK_W
		row += 1
	dither(Rect2i(span.x, rows.x, span.y, rows.y - rows.x), Palette.TEAL_BLACK, 1)


## The fascia: an ink frame round the teal black board, its top shadow, the teal and tomato
## stripe along its foot and the brass rail under it (the neon sign is a layer).
func _fascia() -> void:
	var x: int = FASCIA_RECT.position.x
	var w: int = FASCIA_RECT.size.x
	rect(FASCIA_RECT, Palette.INK)
	rect(FASCIA_RECT.grow(-1), Palette.TEAL_BLACK)
	rect(Rect2i(x + 3, 51, w - 6, 2), Palette.BACKGROUND)
	rect(Rect2i(x + 1, 105, w - 2, 2), Palette.TEAL_SHADE)
	rect(Rect2i(x + 1, 107, w - 2, 3), Palette.TOMATO_DARK)
	rect(Rect2i(x - 2, 114, w + 4, 2), Palette.BRASS)
	rect(Rect2i(x - 2, 116, w + 4, 1), Palette.BRASS_DARK)


## A window's steel frame round its dark glass.
func _pane(area: Rect2i) -> void:
	rect(area, Palette.STEEL_DARKEST)
	rect(area.grow(-2), Palette.TEAL_BLACK)


## The glass glints and the sill of a window.
func _glints(area: Rect2i) -> void:
	for i: int in 10:
		px(area.position.x + 6 + i, area.position.y + 20 - i, Palette.TEAL_SHADE)
	for i: int in 6:
		px(area.position.x + 6 + i, area.position.y + 30 - i, Palette.TEAL_DARK)
	rect(Rect2i(area.position.x, area.end.y - 4, area.size.x, 4), Palette.STEEL_DARK)


## The left window: the lit store behind the glass and four shelves of minis, one aisle each.
func _window_shelves(area: Rect2i) -> void:
	_pane(area)
	_store_wall(area.grow(-2), true)
	var x: int = area.position.x
	for row: int in WINDOW_SHELVES.size():
		var shelf_y: int = area.position.y + 34 + row * 34
		rect(Rect2i(x + 4, shelf_y, area.size.x - 8, 2), Palette.BROWN)
		var names: PackedStringArray = WINDOW_SHELVES[row].split(" ")
		var five: bool = names.size() > 4
		var gap: int = WINDOW_GAPS[1] if five else WINDOW_GAPS[0]
		var left: int = x + (5 if five else 7 + (row % 2) * 4)
		for i: int in names.size():
			blit(load(MINI_PATH % names[i]) as Texture2D, left + i * gap, shelf_y - 7)
	_glints(area)


## The store's lit inside over `area`: STORE_BANDS down from its top, the plaster shade under
## them; `glass` dithers the window's pale glass over it.
func _store_wall(area: Rect2i, glass: bool) -> void:
	rect(area, Palette.PLASTER_SHADE)
	for i: int in STORE_BANDS.size():
		rect(Rect2i(area.position.x, area.position.y + i * 20, area.size.x, 20), STORE_BANDS[i])
	if glass:
		dither(area, Palette.TEAL_PALE, 1)


## The right window: register 3 in silhouette against the lit store under its tube, lit (`lit`:
## the tube glows, the monitor's glass is slate) or off (the tube dark, the store's light dimmed
## by a plaster-dark dither).
func _window_register(area: Rect2i, lit: bool) -> void:
	_pane(area)
	var x: int = area.position.x
	var y: int = area.position.y
	_store_wall(area.grow(-2), true)
	if not lit:
		dither(area.grow(-2), Palette.PLASTER_DARK, 2)
	rect(Rect2i(x + 20, y + 12, 84, 3), Palette.GLASS_GLOW if lit else Palette.TEAL_SHADE)
	rect(Rect2i(x + 30, y + 78, 30, 20), Palette.CHARCOAL)
	rect(Rect2i(x + 32, y + 80, 26, 14), Palette.SLATE if lit else Palette.SLATE_DARK)
	rect(Rect2i(x + 43, y + 98, 4, 22), Palette.CHARCOAL)
	till("3", x + 46, y + 84, Palette.MUSTARD_DARK, "c")
	rect(Rect2i(x + 2, y + 120, area.size.x - 4, 42), Palette.CHARCOAL)
	rect(Rect2i(x + 2, y + 118, area.size.x - 4, 2), Palette.STEEL_DARK)
	rect(Rect2i(x + 70, y + 106, 50, 12), Palette.RUBBER_DARK)
	_glints(area)


## The doors' frame and the warm store inside them: the lit back wall in bands, the tiled floor,
## an aisle of shelves on each side and the OPEN sign over the aisle.
func _doors_inside(area: Rect2i) -> void:
	var x: int = area.position.x
	var y: int = area.position.y
	var w: int = area.size.x
	rect(Rect2i(x - 2, y - 4, w + 4, area.size.y + 4), Palette.STEEL_DARKEST)
	rect(Rect2i(x - 2, y - 4, w + 4, 2), Palette.STEEL_SHADE)
	_store_wall(area, false)
	for tile_y: int in range(y + 100, area.end.y, 8):
		var start: int = x if floori(tile_y / 8.0) % 2 else x + 8
		for tile_x: int in range(start, area.end.x, 16):
			rect(Rect2i(tile_x, tile_y, 8, 8), Palette.PLASTER)
	for side: int in [6, 72]:
		rect(Rect2i(x + side, y + 30, 26, 74), Palette.CREAM_SHADE)
		for row: int in 4:
			rect(Rect2i(x + side, y + 44 + row * 16, 26, 2), Palette.BROWN)
	for i: int in DOOR_MINIS.size():
		var aisle_mini: Texture2D = load(MINI_PATH % DOOR_MINIS[i]) as Texture2D
		var right: bool = i >= 4
		var row: int = floori((i % 4) / 2.0)
		var left: int = x + (75 if right else 8) + (i % 2) * 11
		blit(aisle_mini, left, y + (53 if right else 37) + row * 16)
	rect(Rect2i(x + 40, y + 50, 24, 4), Palette.TEAL)
	till("OPEN", x + 52, y + 46, Palette.TOMATO, "c")


## One sliding leaf (LEAF_SIZE) at `at`: steel stiles and rails round dithered pale glass, its
## push bar and a glint; the rest is clear, so the store shows through.
func _leaf(at: Vector2i) -> void:
	var x: int = at.x
	var y: int = at.y
	var w: int = LEAF_SIZE.x
	var h: int = LEAF_SIZE.y
	dither(Rect2i(x + 3, y + 3, w - 6, h - 6), Palette.TEAL_PALE, 1)
	rect(Rect2i(x, y, w, 3), Palette.STEEL_LIGHT)
	rect(Rect2i(x, y + h - 6, w, 6), Palette.STEEL_LIGHT)
	rect(Rect2i(x, y, 3, h), Palette.STEEL_LIGHT)
	rect(Rect2i(x + w - 3, y, 3, h), Palette.STEEL_LIGHT)
	rect(Rect2i(x, y + 3, w, 1), Palette.STEEL_PALE)
	rect(Rect2i(x + 3, y + 80, w - 6, 3), Palette.STEEL)
	for i: int in 12:
		px(x + 8 + i, y + 30 - i, Palette.GLASS_GLOW)


## The REWARDS bay, a glass annex: its frame, the glass (dark, or lit when the REWARDS entry is
## hot), the REWARDS vinyl and its rule, the locked Loyalty poster (SOON), the glints and the
## frame's bars. The toy machine stands in it as its own node.
func _bay(lit: bool) -> void:
	var x: int = BAY_RECT.position.x
	var y: int = BAY_RECT.position.y
	var w: int = BAY_RECT.size.x
	var h: int = BAY_RECT.size.y
	rect(BAY_RECT, Palette.STEEL_DARKEST)
	rect(BAY_RECT.grow(-2), Palette.TEAL_DARK if lit else Palette.TEAL_BLACK)
	dither(BAY_RECT.grow(-2), Palette.TEAL_SHADE if lit else Palette.BACKGROUND, 2)
	till("REWARDS", x + 64, y + 10, Palette.PAPER if lit else Palette.CREAM_SHADE, "c")
	rect(Rect2i(x + 34, y + 17, 60, 1), Palette.GOLD if lit else Palette.BRASS)
	var poster := Vector2i(x + 6, y + 32)
	rect(Rect2i(poster, Vector2i(24, 32)), Palette.INK)
	var card: Color = Palette.CREAM if lit else Palette.CREAM_DARKEST
	rect(Rect2i(poster + Vector2i.ONE, Vector2i(22, 30)), card)
	var header: Color = Palette.TEAL if lit else Palette.TEAL_SHADE
	rect(Rect2i(poster + Vector2i.ONE, Vector2i(22, 7)), header)
	till("LOYAL", poster.x + 12, poster.y + 2, Palette.PAPER, "c")
	for i: int in 6:
		disc(poster.x + 3 + (i % 3) * 6, poster.y + 11 + floori(i / 3.0) * 7, 5, Palette.GREY)
	till("SOON", poster.x + 12, poster.y + 25, Palette.TOMATO, "c")
	for i: int in 16:
		px(x + 90 + i, y + 60 - i, Palette.GLASS_GLOW if lit else Palette.TEAL_SHADE)
	rect(Rect2i(x + 2, y + 24, w - 4, 2), Palette.STEEL_DARKEST)
	rect(Rect2i(x, y + h - 4, w, 4), Palette.STEEL_DARK)


## The sidewalk (slabs with joints), the curb and the street with its dashes, across `span`, and
## the dark street on past the stage's foot.
func _street(span: Vector2i) -> void:
	rect(Rect2i(span.x, SIDEWALK.x, span.y, SIDEWALK.y - SIDEWALK.x), Palette.STEEL_DARKEST)
	var joint: int = floori(float(span.x) / JOINT) * JOINT
	while joint < span.x + span.y:
		rect(Rect2i(joint, SIDEWALK.x, 1, SIDEWALK.y - SIDEWALK.x), Palette.STEEL_DARK)
		joint += JOINT
	rect(Rect2i(span.x, 314, span.y, 1), Palette.STEEL_DARK)
	rect(Rect2i(span.x, CURB.x, span.y, CURB.y - CURB.x), Palette.STEEL_SHADE)
	var bottom: int = image.get_height() - origin.y
	rect(Rect2i(span.x, CURB.y, span.y, bottom - CURB.y), Palette.CHARCOAL)
	var dash: int = floori(float(span.x - 8) / DASH) * DASH + 8
	while dash < span.x + span.y:
		rect(Rect2i(dash, 348, 20, 2), Palette.MUSTARD_DARKEST)
		dash += DASH
