class_name ToyExitArt
extends RefCounted
## The TOY MACHINES' night exit (#121, mock-up toy_machines_121_v2.html, the title's direction
## C+), painted once into images on the 640x360 art grid with StorefrontArt's rects, dithers and
## till letters, and shown at 2x with nearest filtering by ToyMachinesScreen. Every colour is the
## palette's. It paints the mock-up's canvas code rect for rect, in stage art px.
##
## The backdrop holds what never changes: the teal-black wall with its pilasters, the brass rail,
## the wainscot panels, the skirting, the dark tiled floor, the glass exit doors on the street at
## night and the unlit EXIT lightbox (its word is a label). The live parts are their own images:
## a machine's recessed lamp (off, on with its cone and floor pool, or hot under the hover), the
## hanging TOY MACHINES board with its chains, the OUT OF ORDER tape, a sold-out machine's SOLD
## OUT card, the LED housings (the COINS and FIGURINES readouts, the strip over the floor), the
## lineup's hanging price card and an unwon figurine's grey shape for the lineup (v0.78: store
## fixtures instead of plain boxes), and the doors again with a passing car's headlights on the
## street or the street lamp off, for the doors' idle (ToyStreet, v0.79).

## The stage in art px.
const STAGE := Vector2i(640, 360)
## A lamp layer: LAMP_WIDTH art px wide round the lamp's centre, from LAMP_TOP to the floor
## pool's foot.
const LAMP_TOP := 17
const LAMP_WIDTH := 68
const LAMP_BOTTOM := 268
## The cone: from CONE_TOP to CONE_BOTTOM, CONE_WIDTHS wide at its ends; its top share in a
## checker (CONE_CHECKER, or CONE_CHECKER_HOT under the hover), then one px in four.
const CONE_TOP := 23
const CONE_BOTTOM := 262
const CONE_WIDTHS := Vector2(10, 56)
const CONE_CHECKER := 0.3
const CONE_CHECKER_HOT := 0.55
## The hanging board (stage art px) and its two chains' x, CHAIN_LENGTH rows down from the top
## (v0.78: lower, in the wall the figurines on top of the machines left free).
const BOARD_RECT := Rect2i(165, 71, 180, 32)
const CHAIN_XS: Array[int] = [186, 322]
const CHAIN_LENGTH := 72
## The board layer's rect: the chains and the board.
const BOARD_LAYER := Rect2i(165, 0, 180, 103)
## The doors (stage art px) and the EXIT lightbox.
const DOORS_RECT := Rect2i(524, 34, 104, 212)
const EXIT_RECT := Rect2i(556, 10, 40, 15)
## The doors with their frame (stage art px): what the doors' variants hold.
const DOORS_LAYER := Rect2i(520, 30, 112, 216)
## The headlights light the street low, from HEADLIGHT_TOP (art px under the doors' top; the
## fringe's from HEADLIGHT_LOW) down to the kerb, whose lit rows end at KERB_BOTTOM.
const HEADLIGHT_TOP := 176
const HEADLIGHT_LOW := 184
const KERB_TOP := 194
const KERB_BOTTOM := 204
## The street lamp's head and its pool (stage art px), what its flicker covers.
const STREET_LAMP_RECT := Rect2i(588, 100, 44, 128)
## The OUT OF ORDER tape (art px): its size and its till lines' tops.
const TAPE_SIZE := Vector2i(68, 15)
const TAPE_LINES: Array[int] = [2, 8]
const TAPE_WORDS: Array[String] = ["OUT OF", "ORDER"]
## The hazard stripes at both ends of the tape: HAZARD_COLUMNS px wide.
const HAZARD_COLUMNS := 6
## The SOLD OUT card (art px): the card hung on a string from a nail STRING_ROWS rows above it,
## its till words on SOLD_OUT_LINE.
const SOLD_OUT_SIZE := Vector2i(42, 20)
const SOLD_OUT_CARD_TOP := 7
const SOLD_OUT_LINE := 11
const SOLD_OUT_WORDS := "SOLD OUT"
## An LED housing's steel rim (art px, inside the ink outline) round the dotted face.
const HOUSING_RIM := 3
## The price card: its tomato band's rows under the outline, and its chains' x from each end.
const CARD_BAND := 12
const CARD_CHAIN_INSET := 8

static var _backdrop: ImageTexture
static var _layers: Dictionary[String, ImageTexture] = {}
static var _silhouettes: Dictionary[Texture2D, ImageTexture] = {}


## The night exit's backdrop (640x360 art).
static func backdrop() -> ImageTexture:
	if _backdrop == null:
		var art: StorefrontArt = StorefrontArt.new(STAGE, Vector2i.ZERO)
		_paint_wall(art)
		_paint_doors(art)
		_paint_exit(art)
		_backdrop = ImageTexture.create_from_image(art.image)
	return _backdrop


## The doors (DOORS_LAYER) with the street lit by a passing car's headlights ("core", the beam's
## middle, or "fringe", its edges) or with the street lamp off ("lamp_off"). Everything outside
## the glass matches the backdrop, so a window onto one shows the light behind the frames only.
static func doors(kind: String) -> ImageTexture:
	var key: String = "doors_" + kind
	if not _layers.has(key):
		var art: StorefrontArt = StorefrontArt.new(DOORS_LAYER.size, -DOORS_LAYER.position)
		_paint_doors(art, kind)
		_layers[key] = ImageTexture.create_from_image(art.image)
	return _layers[key]


## A machine's lamp (LAMP_WIDTH x the lamp's height, its centre in the middle): "off", "on" (its
## cone and pool) or "hot" (the hovered machine's, hotter and deeper).
static func lamp(kind: String) -> ImageTexture:
	var key: String = "lamp_" + kind
	if not _layers.has(key):
		var half: int = floori(LAMP_WIDTH / 2.0)
		var art: StorefrontArt = StorefrontArt.new(
			Vector2i(LAMP_WIDTH, LAMP_BOTTOM - LAMP_TOP), Vector2i(0, -LAMP_TOP)
		)
		var on: bool = kind != "off"
		art.rect(Rect2i(half - 6, 17, 12, 3), Palette.STEEL_DARKEST)
		art.rect(Rect2i(half - 5, 20, 10, 2), Palette.STEEL_DARK)
		art.rect(Rect2i(half - 3, 22, 6, 1), Palette.MUSTARD_LIGHT if on else Palette.STEEL_SHADE)
		if on:
			_paint_cone(art, half, kind == "hot")
		_layers[key] = ImageTexture.create_from_image(art.image)
	return _layers[key]


## The hanging TOY MACHINES board with its chains (BOARD_LAYER; the words are a label).
static func board() -> ImageTexture:
	if not _layers.has("board"):
		var art: StorefrontArt = StorefrontArt.new(BOARD_LAYER.size, -BOARD_LAYER.position)
		for x: int in CHAIN_XS:
			for y: int in range(0, CHAIN_LENGTH, 4):
				art.rect(Rect2i(x, y, 2, 3), Palette.STEEL_DARK)
				art.rect(Rect2i(x, y + 3, 2, 1), Palette.STEEL_DARKEST)
		var x0: int = BOARD_RECT.position.x
		var y0: int = BOARD_RECT.position.y
		var w: int = BOARD_RECT.size.x
		var h: int = BOARD_RECT.size.y
		art.rect(Rect2i(x0 + 1, y0, w - 2, h), Palette.INK)
		art.rect(Rect2i(x0, y0 + 1, w, h - 2), Palette.INK)
		art.rect(Rect2i(x0 + 1, y0 + 1, w - 2, h - 2), Palette.STEEL_DARKEST)
		art.rect(Rect2i(x0 + 1, y0 + 1, w - 2, 1), Palette.STEEL_SHADE)
		art.rect(Rect2i(x0 + 3, y0 + 3, w - 6, h - 8), Palette.TEAL_BLACK)
		art.rect(Rect2i(x0 + 3, y0 + h - 5, w - 6, 1), Palette.TEAL_SHADE)
		art.rect(Rect2i(x0 + 3, y0 + h - 4, w - 6, 2), Palette.TOMATO_DARK)
		_layers["board"] = ImageTexture.create_from_image(art.image)
	return _layers["board"]


## The OUT OF ORDER tape (TAPE_SIZE): cream with hazard ends and two lines of till letters.
static func tape() -> ImageTexture:
	if not _layers.has("tape"):
		var art: StorefrontArt = StorefrontArt.new(TAPE_SIZE, Vector2i.ZERO)
		var w: int = TAPE_SIZE.x
		var h: int = TAPE_SIZE.y
		art.rect(Rect2i(0, 0, w, h), Palette.INK)
		art.rect(Rect2i(1, 1, w - 2, h - 2), Palette.CREAM)
		art.rect(Rect2i(1, 1, w - 2, 1), Palette.PAPER)
		art.rect(Rect2i(1, h - 2, w - 2, 1), Palette.CREAM_SHADE)
		for y: int in range(1, h - 1):
			for x: int in range(1, HAZARD_COLUMNS + 1):
				if (x + y) % 4 < 2:
					art.px(x, y, Palette.TOMATO)
					art.px(w - 1 - x, y, Palette.TOMATO)
		for line: int in TAPE_WORDS.size():
			art.till(TAPE_WORDS[line], floori(w / 2.0), TAPE_LINES[line], Palette.TOMATO_DARK, "c")
		_layers["tape"] = ImageTexture.create_from_image(art.image)
	return _layers["tape"]


## A sold-out machine's card (SOLD_OUT_SIZE): a nail, its string, and a paper card ringed in
## tomato with SOLD OUT in till letters.
static func sold_out() -> ImageTexture:
	if not _layers.has("sold_out"):
		var art: StorefrontArt = StorefrontArt.new(SOLD_OUT_SIZE, Vector2i.ZERO)
		var w: int = SOLD_OUT_SIZE.x
		var h: int = SOLD_OUT_SIZE.y
		var top: int = SOLD_OUT_CARD_TOP
		var centre: int = floori(w / 2.0)
		for step: int in range(top - 1):
			var spread: int = roundi(float(step) * (centre - 6) / float(top - 2))
			art.px(centre - 1 - spread, 1 + step, Palette.INK_LIGHT)
			art.px(centre + spread, 1 + step, Palette.INK_LIGHT)
		art.rect(Rect2i(centre - 1, 0, 2, 2), Palette.STEEL_LIGHT)
		art.px(centre, 1, Palette.STEEL_DARKEST)
		art.rect(Rect2i(1, top, w - 2, h - top), Palette.INK)
		art.rect(Rect2i(0, top + 1, w, h - top - 2), Palette.INK)
		art.rect(Rect2i(1, top + 1, w - 2, h - top - 2), Palette.PAPER)
		art.rect(Rect2i(2, top + 2, w - 4, h - top - 4), Palette.TOMATO)
		art.rect(Rect2i(3, top + 3, w - 6, h - top - 6), Palette.PAPER)
		art.rect(Rect2i(3, h - 4, w - 6, 1), Palette.CREAM)
		art.rect(Rect2i(5, top + 2, 2, 1), Palette.PAPER)
		art.rect(Rect2i(w - 7, top + 2, 2, 1), Palette.PAPER)
		art.till(SOLD_OUT_WORDS, centre, SOLD_OUT_LINE, Palette.TOMATO_DARK, "c")
		_layers["sold_out"] = ImageTexture.create_from_image(art.image)
	return _layers["sold_out"]


## An LED housing `area` art px: a steel rim with a screw in each corner, lit from the top left,
## round a slate face dotted like an LED matrix, in an ink outline.
static func housing(area: Vector2i) -> ImageTexture:
	var key: String = "housing_%d_%d" % [area.x, area.y]
	if not _layers.has(key):
		var art: StorefrontArt = StorefrontArt.new(area, Vector2i.ZERO)
		var w: int = area.x
		var h: int = area.y
		var rim: int = HOUSING_RIM
		art.rect(Rect2i(1, 0, w - 2, h), Palette.INK)
		art.rect(Rect2i(0, 1, w, h - 2), Palette.INK)
		art.rect(Rect2i(1, 1, w - 2, h - 2), Palette.STEEL_DARK)
		art.rect(Rect2i(1, 1, w - 2, 1), Palette.STEEL_SHADE)
		art.rect(Rect2i(1, 1, 1, h - 2), Palette.STEEL_SHADE)
		art.rect(Rect2i(1, h - 2, w - 2, 1), Palette.STEEL_DARKEST)
		for corner: Vector2i in [
			Vector2i(2, 2), Vector2i(w - 3, 2), Vector2i(2, h - 3), Vector2i(w - 3, h - 3)
		]:
			art.px(corner.x, corner.y, Palette.STEEL_PALE)
		var face: Rect2i = Rect2i(rim + 1, rim + 1, w - 2 * rim - 2, h - 2 * rim - 2)
		art.rect(face.grow(1), Palette.INK)
		art.rect(face, Palette.SLATE_DARK)
		for y: int in range(face.position.y + 1, face.end.y, 2):
			for x: int in range(face.position.x + 1, face.end.x, 2):
				art.px(x, y, Palette.SLATE)
		art.rect(Rect2i(face.position.x, face.end.y, face.size.x, 1), Palette.STEEL_SHADE)
		_layers[key] = ImageTexture.create_from_image(art.image)
	return _layers[key]


## The lineup's price card `area` art px, hung from the ceiling `drop` rows above it: two chains
## like the board's, a tomato band (CARD_BAND rows) over a paper body, a cream shade foot.
static func price_card(area: Vector2i, drop: int) -> ImageTexture:
	var key: String = "card_%d_%d_%d" % [area.x, area.y, drop]
	if not _layers.has(key):
		var art: StorefrontArt = StorefrontArt.new(Vector2i(area.x, area.y + drop), Vector2i.ZERO)
		var w: int = area.x
		var h: int = area.y
		for x: int in [CARD_CHAIN_INSET, w - CARD_CHAIN_INSET - 2]:
			for y: int in range(0, drop, 4):
				art.rect(Rect2i(x, y, 2, 3), Palette.STEEL_DARK)
				art.rect(Rect2i(x, y + 3, 2, 1), Palette.STEEL_DARKEST)
		var top: int = drop
		art.rect(Rect2i(1, top, w - 2, h), Palette.INK)
		art.rect(Rect2i(0, top + 1, w, h - 2), Palette.INK)
		art.rect(Rect2i(1, top + 1, w - 2, h - 2), Palette.PAPER)
		art.rect(Rect2i(1, top + 1, w - 2, CARD_BAND), Palette.TOMATO)
		art.rect(Rect2i(1, top + 1, w - 2, 1), Palette.TOMATO_LIGHT)
		art.rect(Rect2i(1, top + CARD_BAND, w - 2, 1), Palette.TOMATO_DARK)
		art.rect(Rect2i(1, top + h - 2, w - 2, 1), Palette.CREAM_SHADE)
		for x: int in [CARD_CHAIN_INSET, w - CARD_CHAIN_INSET - 2]:
			art.rect(Rect2i(x, top + 2, 2, 2), Palette.TOMATO_DARKEST)
		_layers[key] = ImageTexture.create_from_image(art.image)
	return _layers[key]


## An unwon figurine's shape for the lineup (the mock-up's silhouette): grey dark, a grey light
## rim where light from the top left meets its edge, ink on its other edges.
static func silhouette(texture: Texture2D) -> ImageTexture:
	if not _silhouettes.has(texture):
		var source: Image = texture.get_image()
		if source.is_compressed():
			source.decompress()
		var w: int = source.get_width()
		var h: int = source.get_height()
		var shape: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for y: int in h:
			for x: int in w:
				if not _solid(source, x, y):
					continue
				var colour: Color = Palette.GREY_DARK
				if not _solid(source, x, y - 1) or not _solid(source, x - 1, y):
					colour = Palette.GREY_LIGHT
				elif not _solid(source, x, y + 1) or not _solid(source, x + 1, y):
					colour = Palette.INK
				shape.set_pixel(x, y, colour)
		_silhouettes[texture] = ImageTexture.create_from_image(shape)
	return _silhouettes[texture]


static func _solid(source: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= source.get_width() or y >= source.get_height():
		return false
	return source.get_pixel(x, y).a >= 0.5


## A lamp's cone down to the floor and its pool, centred on cx (hot: mustard dark, a deeper
## checker), in 2-row steps.
static func _paint_cone(art: StorefrontArt, cx: int, hot: bool) -> void:
	var colour: Color = Palette.MUSTARD_DARK if hot else Palette.MUSTARD_DARKEST
	var checker: float = CONE_CHECKER_HOT if hot else CONE_CHECKER
	for y: int in range(CONE_TOP, CONE_BOTTOM, 2):
		var share: float = float(y - CONE_TOP) / float(CONE_BOTTOM - CONE_TOP)
		var width: int = floori(lerpf(CONE_WIDTHS.x, CONE_WIDTHS.y, share) / 2.0 + 0.5) * 2
		var level: int = 2 if share < checker else 1
		art.dither(Rect2i(cx - floori(width / 2.0), y, width, 2), colour, level)
	art.dither(Rect2i(cx - 22, CONE_BOTTOM, 44, 4), colour, 2)
	art.dither(Rect2i(cx - 34, CONE_BOTTOM, 12, 4), colour, 1)
	art.dither(Rect2i(cx + 22, CONE_BOTTOM, 12, 4), colour, 1)
	art.dither(Rect2i(cx - 26, CONE_BOTTOM + 4, 52, 2), colour, 1)


## The wall after closing: a dark ceiling band, the teal-black wall with its pilasters, the brass
## rail, the wainscot's panels, the skirting and the dark tiled floor.
static func _paint_wall(art: StorefrontArt) -> void:
	art.rect(Rect2i(0, 0, 640, 20), Palette.CHARCOAL)
	art.dither(Rect2i(0, 0, 640, 20), Palette.TEAL_BLACK, 2)
	art.rect(Rect2i(0, 18, 640, 1), Palette.STEEL_DARKEST)
	art.rect(Rect2i(0, 19, 640, 1), Palette.STEEL_DARK)
	art.rect(Rect2i(0, 20, 640, 228), Palette.TEAL_BLACK)
	art.dither(Rect2i(0, 20, 640, 174), Palette.BACKGROUND, 1)
	for x: int in range(40, 520, 80):
		art.rect(Rect2i(x, 20, 1, 174), Palette.BACKGROUND)
	art.rect(Rect2i(0, 194, 640, 2), Palette.BRASS_DARK)
	art.rect(Rect2i(0, 194, 640, 1), Palette.BRASS)
	art.rect(Rect2i(0, 196, 640, 1), Palette.BRASS_DARKEST)
	art.rect(Rect2i(0, 197, 640, 49), Palette.BACKGROUND)
	for x: int in range(0, 520, 40):
		art.rect(Rect2i(x + 4, 203, 32, 38), Palette.TEAL_DARK)
		art.rect(Rect2i(x + 4, 203, 32, 1), Palette.TEAL_BLACK)
		art.rect(Rect2i(x + 4, 203, 1, 38), Palette.TEAL_BLACK)
		art.rect(Rect2i(x + 5, 240, 31, 1), Palette.TEAL_SHADE)
	art.rect(Rect2i(0, 246, 640, 4), Palette.WOOD_DARKEST)
	art.rect(Rect2i(0, 246, 640, 1), Palette.WOOD_DARK)
	art.rect(Rect2i(0, 250, 640, 110), Palette.BACKGROUND)
	var row: int = 0
	for y: int in range(250, 360, 10):
		for x: int in range((row % 2) * 20, 640, 40):
			art.rect(Rect2i(x, y, 20, 10), Palette.TEAL_DARK)
		row += 1
	art.dither(Rect2i(0, 250, 640, 110), Palette.TEAL_BLACK, 1)
	art.dither(Rect2i(0, 310, 640, 50), Palette.TEAL_BLACK, 2)


## The glass exit doors: flat dark glass, the street as solid shapes (roofs with a few lit
## windows, a lamp post and its pool, the kerb), two leaves with glare lines and the mat;
## `light` adds a car's headlights on the street ("core" or "fringe") or turns the lamp off
## ("lamp_off").
static func _paint_doors(art: StorefrontArt, light: String = "") -> void:
	var x: int = DOORS_RECT.position.x
	var y: int = DOORS_RECT.position.y
	var w: int = DOORS_RECT.size.x
	var h: int = DOORS_RECT.size.y
	art.rect(Rect2i(x - 4, y - 4, w + 8, h + 4), Palette.STEEL_DARKEST)
	art.rect(Rect2i(x - 4, y - 4, w + 8, 1), Palette.STEEL_SHADE)
	art.rect(Rect2i(x, y, w, h), Palette.BACKGROUND)
	art.rect(Rect2i(x, y + 112, 34, 82), Palette.TEAL_BLACK)
	art.rect(Rect2i(x + 34, y + 96, 30, 98), Palette.SLATE_DARK)
	art.rect(Rect2i(x + 64, y + 122, 40, 72), Palette.TEAL_BLACK)
	for spot: Vector2i in [
		Vector2i(8, 124), Vector2i(42, 106), Vector2i(50, 122), Vector2i(76, 134)
	]:
		art.rect(Rect2i(x + spot.x, y + spot.y, 4, 4), Palette.MUSTARD_DARKEST)
	art.rect(Rect2i(x + 86, y + 70, 2, 124), Palette.CHARCOAL)
	art.rect(Rect2i(x + 81, y + 66, 12, 4), Palette.CHARCOAL)
	if light != "lamp_off":
		art.rect(Rect2i(x + 83, y + 70, 8, 1), Palette.MUSTARD_LIGHT)
		art.dither(Rect2i(x + 72, y + 186, 30, 8), Palette.MUSTARD_DARKEST, 2)
		art.dither(Rect2i(x + 64, y + 182, w - 64, 4), Palette.MUSTARD_DARKEST, 1)
	art.rect(Rect2i(x, y + 194, w, 18), Palette.SLATE_DARK)
	if light in ["core", "fringe"]:
		var core: bool = light == "core"
		var top: int = HEADLIGHT_TOP if core else HEADLIGHT_LOW
		var street: Rect2i = Rect2i(x, y + top, w, KERB_TOP - top)
		art.dither(street, Palette.MUSTARD_DARKEST, 2 if core else 1)
		var kerb: Rect2i = Rect2i(x, y + KERB_TOP, w, KERB_BOTTOM - KERB_TOP)
		art.dither(kerb, Palette.MUSTARD_DARK if core else Palette.MUSTARD_DARKEST, 2)
	for leaf_x: int in [x, x + 52]:
		var lw: int = 52
		art.rect(Rect2i(leaf_x, y, lw, 3), Palette.STEEL_SHADE)
		art.rect(Rect2i(leaf_x, y + h - 8, lw, 8), Palette.STEEL_SHADE)
		art.rect(Rect2i(leaf_x, y, 3, h), Palette.STEEL_SHADE)
		art.rect(Rect2i(leaf_x + lw - 3, y, 3, h), Palette.STEEL_SHADE)
		art.rect(Rect2i(leaf_x, y, lw, 1), Palette.STEEL)
		art.rect(Rect2i(leaf_x, y, 1, h), Palette.STEEL)
		art.rect(Rect2i(leaf_x + 3, y + 104, lw - 6, 3), Palette.STEEL)
		art.rect(Rect2i(leaf_x + 3, y + 104, lw - 6, 1), Palette.STEEL_PALE)
		for i: int in 12:
			art.px(leaf_x + 8 + i, y + 36 - i, Palette.TEAL_SHADE)
		for i: int in 6:
			art.px(leaf_x + 8 + i, y + 46 - i, Palette.TEAL_SHADE)
	art.rect(Rect2i(x + 52, y, 1, h), Palette.STEEL_DARKEST)
	art.rect(Rect2i(x - 10, 250, w + 20, 12), Palette.CHARCOAL)
	for mat_x: int in range(x - 8, x + w + 10, 4):
		art.rect(Rect2i(mat_x, 252, 2, 8), Palette.RUBBER_DARK)
	art.rect(Rect2i(x - 10, 250, w + 20, 1), Palette.RUBBER)


## The unlit EXIT lightbox above the doors (scenery: DONE is the way out).
static func _paint_exit(art: StorefrontArt) -> void:
	var x: int = EXIT_RECT.position.x
	var y: int = EXIT_RECT.position.y
	var w: int = EXIT_RECT.size.x
	var h: int = EXIT_RECT.size.y
	art.rect(Rect2i(x + 1, y, w - 2, h), Palette.INK)
	art.rect(Rect2i(x, y + 1, w, h - 2), Palette.INK)
	art.rect(Rect2i(x + 1, y + 1, w - 2, h - 2), Palette.TEAL_BLACK)
	art.rect(Rect2i(x + 1, y + 1, w - 2, 1), Palette.TEAL_DARK)
	art.rect(Rect2i(x + 6, y + h - 3, w - 12, 1), Palette.GREEN_DARK)
