class_name AisleBoardArt
extends RefCounted
## The aisle board's geometry and painted art (YOUR STORE, v1.40; mock-up
## docs/art/mockups/start_roulette.html, variant A): the seven aisles as bays on the back wall, each
## under its hung sign and stocked with its own products, the room behind them, and the compact
## card face (picture, price, family glyph, name; the rule shows on hover). Everything is in art
## px (640x360, 2 stage px each); the images are painted once and cached.

## The line the pouches and the cards stand on (the counter's top is BoosterArt.COUNTER_Y).
const STAND := 272
## A compact fan card's height; a fan's step (its cards 1 art px apart, so one booster's cards
## read as one group: play test 2026-11-19) and half a four-card fan's width (start_booster_size
## 4, v1.41: FAN_STEP * 3 + BoosterArt.CW is 307 art px; two fans and their gap fill the 640).
const MH := 88
const FAN_STEP := BoosterArt.CW + 1
const FAN_HALF := 154
## The fewest art px between two fans' centres beyond their widths (a clear gap between the
## boosters of two aisles), and between a fan and the screen's edge.
const FAN_GAP := 16
const FAN_EDGE := 4
## The compact fans' rows (play test 2026-11-19): the left bay's booster opens into the top row,
## the right bay's into the bottom one (its foot on STAND), ROW_GAP art px apart, each card
## ROW_STEP from the last (6 px between two: round 2 of the play test widened the gaps); both rows
## start at ROW_X, a vertical tab in their aisle's sign colours with its glyph (ROW_TAB_W wide) at
## ROW_TAB_X just left of them, so each row reads as its aisle's without words. A hovered card's
## full card pops up from the top row and down over the counter from the bottom one, so it never
## covers the other row (AisleBoardDraw.hover_rect). Round 3 of the play test: the tab is odd-sized
## (ROW_TAB_W x ROW_TAB_H) so its 11 px glyph tile sits dead centre on whole pixels, and each
## booster lands and waits sealed at its own row's start, right of its tab (row_pouch_pos), its
## top POUCH_ROW_DY above the row's (so the two pouches clear each other; the bottom one's foot
## stands behind the counter's lip).
const ROW_GAP := 28
const ROW_STEP := BoosterArt.CW + 6
const ROW_TAB_W := 15
const ROW_TAB_H := MH - 1
const ROW_TAB_X := 157
const ROW_TILE := 11
const ROW_X := ROW_TAB_X + ROW_TAB_W + 3
const POUCH_ROW_DY := 8
## The bays: their top, the board's left edge and its width (they share it evenly, BAY_GAP
## between two), the sign hung over each.
const BAY_Y := 66
const BAY_H := BoosterArt.COUNTER_Y - BAY_Y
const BOARD_X := 10
const BOARD_W := 624
const BAY_GAP := 4
const SIGN_Y := 47
const SIGN_W := 94
const SIGN_H := 16
## A shut bay's padlock (a locked aisle), from the bay's top.
const PADLOCK_DY := 70
## A dimmed bay's modulate (the mock-up's #6f8482).
const HALF := Color("6f8482")
const PLANK := preload("res://art/scenery/shelf_plank.png")

static var _room: ImageTexture
static var _bays: Dictionary[String, ImageTexture] = {}
static var _compact: Dictionary[String, ImageTexture] = {}


## Bay k of `count`: its left edge and its width.
static func bay_x(k: int, count: int) -> float:
	return BOARD_X + roundf(k * BOARD_W / float(maxi(1, count)))


static func bay_w(count: int) -> float:
	return roundf(BOARD_W / float(maxi(1, count))) - BAY_GAP


static func bay_rect(k: int, count: int) -> Rect2:
	return Rect2(bay_x(k, count), BAY_Y, bay_w(count), BAY_H)


static func bay_centre(k: int, count: int) -> float:
	return bay_x(k, count) + bay_w(count) / 2.0


## The sign over bay k: as wide as its words need, never wider than the bay.
static func sign_rect(k: int, count: int) -> Rect2:
	var w: float = minf(SIGN_W, bay_w(count))
	return Rect2(roundf(bay_centre(k, count) - w / 2.0), SIGN_Y, w, SIGN_H)


## Where the fans of the boosters in front of bays `bays` (left to right) are centred: each under
## its own bay, pushed just far enough to stay on screen and FAN_GAP clear of its neighbour, so
## the left fan is always the left bay's.
static func fan_centres(bays: Array[int], count: int) -> Array[float]:
	var centres: Array[float] = []
	for k: int in bays:
		centres.append(bay_centre(k, count))
	var lo: float = FAN_HALF + FAN_EDGE
	var hi: float = BoosterArt.AW - FAN_HALF - FAN_EDGE
	var step: float = FAN_HALF * 2 + FAN_GAP
	for k: int in centres.size():
		centres[k] = clampf(centres[k], lo, hi)
		if k > 0:
			centres[k] = maxf(centres[k], centres[k - 1] + step)
	for k: int in range(centres.size() - 1, -1, -1):
		var most: float = hi if k == centres.size() - 1 else centres[k + 1] - step
		centres[k] = minf(centres[k], most)
	return centres


## Row `row`'s foot (art px): the bottom row's on the counter's line, the top row's above it.
static func row_foot(row: int) -> float:
	return float(STAND - (MH + ROW_GAP) * (1 - clampi(row, 0, 1)))


## Row `row`'s aisle tab: from a compact card's top (one px short of its foot), left of the
## row's first card.
static func row_tab_rect(row: int) -> Rect2:
	return Rect2(ROW_TAB_X, row_foot(row) - MH, ROW_TAB_W, ROW_TAB_H)


## Row `row`'s glyph tile (ROW_TILE square), centred in its tab on whole pixels.
static func row_tile_rect(row: int) -> Rect2:
	var tab: Rect2 = row_tab_rect(row)
	return Rect2(
		tab.position + ((tab.size - Vector2(ROW_TILE, ROW_TILE)) / 2.0).floor(),
		Vector2(ROW_TILE, ROW_TILE)
	)


## Where the booster of row `row` waits sealed (its pouch's top left): at the row's start, right of
## its tab, its top POUCH_ROW_DY above the row's.
static func row_pouch_pos(row: int) -> Vector2:
	return Vector2(ROW_X, row_foot(row) - MH - POUCH_ROW_DY)


static func _r(image: Image, x: int, y: int, w: int, h: int, colour: Color) -> void:
	var rect: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x > 0 and rect.size.y > 0:
		image.fill_rect(rect, colour)


static func _d(image: Image, x: int, y: int, w: int, h: int, colour: Color, level: int) -> void:
	var right: int = mini(x + w, image.get_width())
	var bottom: int = mini(y + h, image.get_height())
	for yy: int in range(maxi(0, y), bottom):
		for xx: int in range(maxi(0, x), right):
			if ArtPen.BAYER[(yy % 4) * 4 + xx % 4] < level:
				image.set_pixel(xx, yy, colour)


## A texture's pixels (a clear image of its size when the renderer can't read it back: the
## headless test run), each multiplied by `tint`.
static func _pixels(texture: Texture2D, tint: Color = Color.WHITE) -> Image:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Image.create(
			maxi(1, texture.get_width()), maxi(1, texture.get_height()), false, Image.FORMAT_RGBA8
		)
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if tint != Color.WHITE:
		_tint(image, tint)
	return image


static func _tint(image: Image, tint: Color) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				image.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))


## The room behind the board: the ceiling rail the signs hang from, the back wall, the counter
## with its panelled front, the checkered floor.
static func room() -> ImageTexture:
	if _room != null:
		return _room
	var aw: int = BoosterArt.AW
	var ah: int = BoosterArt.AH
	var art: Image = Image.create(aw, ah, false, Image.FORMAT_RGBA8)
	art.fill(Palette.TEAL_BLACK)
	_r(art, 0, 28, aw, 16, Palette.CHARCOAL)
	_d(art, 0, 28, aw, 10, Palette.TEAL_BLACK, 8)
	_r(art, 0, 38, aw, 1, Palette.STEEL_DARKEST)
	_r(art, 0, 39, aw, 1, Palette.STEEL_DARK)
	_r(art, 0, 40, aw, 3, Palette.STEEL_DARKEST)
	_r(art, 0, 40, aw, 1, Palette.STEEL_SHADE)
	_r(art, 0, 43, aw, 1, Palette.INK)
	_d(art, 0, 44, aw, 226, Palette.BACKGROUND, 4)
	var cy0: int = BoosterArt.COUNTER_Y
	_r(art, 0, cy0, aw, 1, Palette.INK)
	_r(art, 0, cy0 + 1, aw, 1, Palette.WOOD)
	_r(art, 0, cy0 + 2, aw, 5, Palette.WOOD_DARK)
	_r(art, 0, cy0 + 7, aw, 1, Palette.WOOD_DARKEST)
	_r(art, 0, cy0 + 8, aw, 28, Palette.BROWN_DARKEST)
	for x: int in range(20, aw, 40):
		_r(art, x, cy0 + 10, 1, 24, Palette.WOOD_DARKEST)
		_r(art, x + 1, cy0 + 10, 1, 24, Palette.WOOD_DARK)
	_r(art, 0, cy0 + 8, aw, 2, Palette.WOOD_DARKEST)
	_r(art, 0, cy0 + 33, aw, 3, Palette.WOOD_DARKEST)
	_r(art, 0, cy0 + 36, aw, 1, Palette.INK)
	var fy: int = cy0 + 37
	_r(art, 0, fy, aw, ah - fy, Palette.BACKGROUND)
	var row: int = 0
	for y: int in range(fy, ah, 10):
		for x: int in range((row % 2) * 20, aw, 40):
			_r(art, x, y, 20, 10, Palette.TEAL_DARK)
		row += 1
	_d(art, 0, fy, aw, ah - fy, Palette.TEAL_BLACK, 4)
	_d(art, 0, ah - 18, aw, 18, Palette.TEAL_BLACK, 8)
	_r(art, 0, fy, aw, 1, Palette.INK)
	_r(art, 0, fy + 1, aw, 2, Palette.TEAL_BLACK)
	_room = ImageTexture.create_from_image(art)
	return _room


## Aisle `aisle`'s bay, `w` art px wide, lit or dimmed: its shelves stocked with its own products
## (their minis, five a plank, each over its price strip) on the aisle's ramp, in a steel frame.
static func bay(aisle: AisleDefinition, w: int, lit: bool) -> ImageTexture:
	var key: String = "%s|%d|%s" % [aisle.id, w, lit]
	if _bays.has(key):
		return _bays[key]
	var ramp: Array[Color] = BoosterArt.ramp(aisle.id)
	var art: Image = Image.create(w, BAY_H, false, Image.FORMAT_RGBA8)
	art.fill(ramp[3])
	_d(art, 0, 0, w, BAY_H, Palette.TEAL_BLACK, 6)
	var minis: Array[Image] = []
	for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
		if card.mini_art_ref != "" and ResourceLoader.exists(card.mini_art_ref):
			var mini_image: Image = _pixels(load(card.mini_art_ref) as Texture2D)
			mini_image.resize(
				mini_image.get_width() * 2, mini_image.get_height() * 2, Image.INTERPOLATE_NEAREST
			)
			minis.append(mini_image)
	var plank: Image = _pixels(PLANK)
	plank.resize(plank.get_width() >> 1, plank.get_height() >> 1, Image.INTERPOLATE_NEAREST)
	var n: int = String(aisle.id).length()
	var step: int = maxi(1, int((w - 15) / 5.0))
	for py: int in range(32, BAY_H, 34):
		_r(art, 4, py - 25, w - 8, 1, ramp[2])
		for j: int in 5:
			if minis.is_empty():
				break
			var small: Image = minis[n % minis.size()]
			n += 1
			art.blend_rect(
				small,
				Rect2i(Vector2i.ZERO, small.get_size()),
				Vector2i(9 + j * step, py - small.get_height())
			)
		_plank(art, plank, py)
		_r(art, 0, py + 7, w, 1, Palette.INK)
		for j: int in 5:
			_r(art, 12 + j * step, py + 2, 8, 4, Palette.CREAM)
			_r(art, 13 + j * step, py + 3, 2, 2, ramp[1])
	_r(art, 0, 0, w, 5, Palette.STEEL_SHADE)
	_r(art, 0, 0, w, 1, Palette.STEEL_LIGHT)
	_r(art, 0, 5, w, 1, Palette.INK)
	for x: int in [0, w - 4]:
		_r(art, x, 0, 4, BAY_H, Palette.STEEL_SHADE)
		_r(art, x, 0, 1, BAY_H, Palette.STEEL_LIGHT)
		_r(art, x + 3, 0, 1, BAY_H, Palette.INK)
	if not lit:
		_tint(art, HALF)
	_bays[key] = ImageTexture.create_from_image(art)
	return _bays[key]


## The shelf plank stretched across `art` at row `y` (its 3 px ends kept).
static func _plank(art: Image, plank: Image, y: int) -> void:
	var pw: int = plank.get_width()
	var w: int = art.get_width()
	for x: int in w:
		var sx: int = x
		if x >= w - 3:
			sx = pw - (w - x)
		elif x >= 3:
			sx = 3 + (x - 3) % maxi(1, pw - 6)
		for yy: int in mini(7, plank.get_height()):
			var c: Color = plank.get_pixel(clampi(sx, 0, pw - 1), yy)
			if c.a > 0.5 and y + yy < art.get_height():
				art.set_pixel(x, y + yy, c)


## The compact face of `card` (CW x MH): the full face's top (frame, art window, price, family
## chips, BIG chip) over a name band that fills the rest; its name is drawn live
## (BoosterCardDraw). A RARE keeps its frame clear for the foil.
static func compact_face(card: CardDefinition, rare: bool) -> ImageTexture:
	var key: String = "%s|%s" % [card.id, rare]
	if _compact.has(key):
		return _compact[key]
	var cw: int = BoosterArt.CW
	var full: Image = _pixels(BoosterArt.face(card, rare))
	var text: Dictionary = BoosterArt.face_text(card, rare)
	var band_y: int = text.band_y
	var foot: int = 5 if rare else 2
	var art: Image = Image.create(cw, MH, false, Image.FORMAT_RGBA8)
	art.blit_rect(full, Rect2i(0, 0, cw, band_y), Vector2i.ZERO)
	for y: int in range(band_y, MH - foot):
		art.blit_rect(full, Rect2i(0, band_y, cw, 1), Vector2i(0, y))
	if rare:
		art.blit_rect(full, Rect2i(0, BoosterArt.CH - foot, cw, foot), Vector2i(0, MH - foot))
	else:
		var win: Rect2i = text.window
		_r(art, win.position.x, MH - foot - 1, win.size.x, 1, BoosterArt.TAN_DARK)
		_r(art, 0, MH - 2, cw, 2, Palette.INK)
		_r(art, 1, MH - 2, cw - 2, 1, BoosterArt.TAN_DARK)
	_compact[key] = ImageTexture.create_from_image(art)
	return _compact[key]
