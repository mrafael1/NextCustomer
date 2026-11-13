class_name StoreDawnArt
extends RefCounted
## YOUR STORE at dawn (v1.32, mock-up docs/art/mockups/start_boosters_v3.html), painted at
## 640x360 art px in code, as StaffRoomArt and ToyExitArt are: the room (a teal-black wall with
## its quiet dither, the ceiling track, the dawn window, the pillar, the wood counter, the toy
## street's dark tiled floor), each aisle's shelf run (dark, or lit by its booster's lamp: the
## aisle's darkest ramp step behind wood planks and its products' minis) and the storefront (brick,
## the fascia with the neon sign off, the windows, the door's opening left clear, the sidewalk and
## the street). Dither is used only for light; the colours are the palette's.

const DY := BoosterArt.DY
## A shelf run's size and its planks' tops (art px).
const SHELF_W := 240
const SHELF_H := 158 + DY
const PLANKS: Array[int] = [20, 56, 92, 128, 164]
## The facade's door, windows and fascia (art px).
const DOOR := Rect2i(262, 156, 116, 140)
const WINDOWS: Array[Rect2i] = [Rect2i(30, 160, 170, 136), Rect2i(440, 160, 170, 136)]
const FASCIA := Rect2i(140, 70, 360, 66)
## The minis' flat modulates on a lit and a dark shelf, and the dark plank's.
const LIT_MINI := Color("d6cebd")
const DARK_MINI := Color("3c5654")
const DARK_PLANK := Color("56605c")
const PLANK := preload("res://art/scenery/shelf_plank.png")
const NEON_OFF := preload("res://art/scenery/neon_sign_off.png")

static var _room: ImageTexture
static var _facade: ImageTexture
static var _shelves: Dictionary[String, ImageTexture] = {}


static func room() -> ImageTexture:
	if _room == null:
		_room = ImageTexture.create_from_image(_paint_room())
	return _room


static func facade() -> ImageTexture:
	if _facade == null:
		_facade = ImageTexture.create_from_image(_paint_facade())
	return _facade


## Aisle `aisle`'s shelf run, `lit` or dark (cached).
static func shelf(aisle: AisleDefinition, lit: bool) -> ImageTexture:
	var key: String = "%s|%s" % [aisle.id, lit]
	if not _shelves.has(key):
		_shelves[key] = ImageTexture.create_from_image(_paint_shelf(aisle, lit))
	return _shelves[key]


static func _r(image: Image, x: int, y: int, w: int, h: int, colour: Color) -> void:
	if w > 0 and h > 0:
		image.fill_rect(Rect2i(x, y, w, h), colour)


static func _d(image: Image, x: int, y: int, w: int, h: int, colour: Color, level: int) -> void:
	var right: int = mini(x + w, image.get_width())
	var bottom: int = mini(y + h, image.get_height())
	for yy: int in range(maxi(0, y), bottom):
		for xx: int in range(maxi(0, x), right):
			if ArtPen.BAYER[(yy % 4) * 4 + xx % 4] < level:
				image.set_pixel(xx, yy, colour)


static func _paint_room() -> Image:
	var art: Image = Image.create(BoosterArt.AW, BoosterArt.AH, false, Image.FORMAT_RGBA8)
	var aw: int = BoosterArt.AW
	art.fill(Palette.TEAL_BLACK)
	_r(art, 0, 28, aw, 16, Palette.CHARCOAL)
	_d(art, 0, 28, aw, 10, Palette.TEAL_BLACK, 8)
	_r(art, 0, 38, aw, 1, Palette.STEEL_DARKEST)
	_r(art, 0, 39, aw, 1, Palette.STEEL_DARK)
	_r(art, 150, 40, 486, 3, Palette.STEEL_DARKEST)
	_r(art, 150, 40, 486, 1, Palette.STEEL_SHADE)
	_r(art, 150, 43, 486, 1, Palette.INK)
	_r(art, 0, 44, aw, 186 + DY, Palette.TEAL_BLACK)
	_d(art, 0, 44, aw, 186 + DY, Palette.BACKGROUND, 4)
	_paint_window(art)
	_r(art, 112, 44, 44, 186 + DY, Palette.TEAL_BLACK)
	_r(art, 112, 44, 1, 186 + DY, Palette.BACKGROUND)
	_r(art, 155, 44, 1, 186 + DY, Palette.INK)
	var cy0: int = BoosterArt.COUNTER_Y
	_r(art, 0, cy0, aw, 1, Palette.INK)
	_r(art, 0, cy0 + 1, aw, 1, Palette.WOOD)
	_r(art, 0, cy0 + 2, aw, 5, Palette.WOOD_DARK)
	_r(art, 0, cy0 + 7, aw, 1, Palette.WOOD_DARKEST)
	_r(art, 0, cy0 + 8, aw, 28, Palette.BROWN_DARKEST)
	var x: int = 20
	while x < aw:
		_r(art, x, cy0 + 10, 1, 24, Palette.WOOD_DARKEST)
		_r(art, x + 1, cy0 + 10, 1, 24, Palette.WOOD_DARK)
		x += 40
	_r(art, 0, cy0 + 8, aw, 2, Palette.WOOD_DARKEST)
	_r(art, 0, cy0 + 33, aw, 3, Palette.WOOD_DARKEST)
	_r(art, 0, cy0 + 36, aw, 1, Palette.INK)
	var fy: int = cy0 + 37
	var ah: int = BoosterArt.AH
	_r(art, 0, fy, aw, ah - fy, Palette.BACKGROUND)
	var row: int = 0
	var y: int = fy
	while y < ah:
		x = (row % 2) * 20
		while x < aw:
			_r(art, x, y, 20, mini(10, ah - y), Palette.TEAL_DARK)
			x += 40
		row += 1
		y += 10
	_d(art, 0, fy, aw, ah - fy, Palette.TEAL_BLACK, 4)
	_d(art, 0, ah - 18, aw, 18, Palette.TEAL_BLACK, 8)
	_r(art, 0, fy, aw, 1, Palette.INK)
	_r(art, 0, fy + 1, aw, 2, Palette.TEAL_BLACK)
	return art


static func _paint_window(art: Image) -> void:
	var x0: int = 4
	var y0: int = 52
	var w: int = 108
	var h: int = 148 + DY
	_r(art, x0, y0, w, h, Palette.INK)
	_r(art, x0 + 1, y0 + 1, w - 2, h - 2, Palette.STEEL_DARKEST)
	_r(art, x0 + 1, y0 + 1, w - 2, 1, Palette.STEEL_SHADE)
	var gx: int = x0 + 4
	var gy: int = y0 + 4
	var gw: int = w - 8
	var gh: int = h - 8
	_r(art, gx, gy, gw, 36, Palette.TEAL_SHADE)
	_r(art, gx, gy + 36, gw, 40, Palette.PLASTER)
	for step: Vector2i in [
		Vector2i(0, 12), Vector2i(8, 8), Vector2i(16, 6), Vector2i(24, 4), Vector2i(32, 2)
	]:
		_d(art, gx, gy + 36 + step.x, gw, 8, Palette.TEAL_SHADE, step.y)
	_r(art, gx, gy + 76, gw, 38, Palette.MUSTARD_PALE)
	for step: Vector2i in [Vector2i(0, 8), Vector2i(8, 4), Vector2i(16, 2)]:
		_d(art, gx, gy + 76 + step.x, gw, 8, Palette.PLASTER, step.y)
	for r: int in 9:
		var hw: int = roundi(sqrt(81.0 - (8 - r) * (8 - r)) * 1.6)
		_r(
			art,
			gx + 70 - hw,
			gy + 106 + r,
			hw * 2,
			1,
			Palette.MUSTARD_LIGHT if r < 3 else Palette.MUSTARD_PALE
		)
	_r(art, gx, gy + 114, gw, 1, Palette.MUSTARD)
	_r(art, gx, gy + 116, gw, gh - 116, Palette.TEAL_BLACK)
	for b: Vector3i in [
		Vector3i(0, 122, 18),
		Vector3i(16, 118, 12),
		Vector3i(28, 124, 22),
		Vector3i(50, 117, 14),
		Vector3i(64, 121, 20),
		Vector3i(84, 115, 16)
	]:
		_r(art, gx + b.x, gy + b.y, b.z, gh - b.y, Palette.TEAL_BLACK)
	_r(art, gx + 51, gy + 113, 3, 4, Palette.TEAL_BLACK)
	_r(art, gx + 88, gy + 110, 2, 5, Palette.TEAL_BLACK)
	_r(art, gx + 33, gy + 128, 2, 3, Palette.MUSTARD_PALE)
	_r(art, gx + 90, gy + 124, 2, 3, Palette.MUSTARD_PALE)
	_r(art, gx + 70, gy + 132, 2, 2, Palette.MUSTARD_LIGHT)
	for k: int in 10:
		_r(art, gx + 8 + k, gy + 20 - k, 1, 1, Palette.GLASS_GLOW)
		_r(art, gx + 12 + k, gy + 24 - k, 1, 1, Palette.GLASS)
	_r(art, gx, gy + 66, gw, 2, Palette.STEEL_DARK)
	_r(art, gx, gy + 66, gw, 1, Palette.STEEL_SHADE)
	_r(art, gx + (gw >> 1) - 1, gy, 2, gh, Palette.STEEL_DARK)
	_r(art, gx + (gw >> 1) - 1, gy, 1, gh, Palette.STEEL_SHADE)
	_r(art, x0, y0 + h - 4, w, 4, Palette.STEEL_DARKEST)
	_r(art, x0, y0 + h - 4, w, 1, Palette.STEEL_SHADE)


## One 240-wide shelf run in flat ramp fills: dark (steel planks and minis modulated near to
## silhouettes on a teal-black back) or lit (the aisle's darkest step behind, wood planks, the
## minis one value step under the UI, price strips). No dither.
static func _paint_shelf(aisle: AisleDefinition, lit: bool) -> Image:
	var art: Image = Image.create(SHELF_W, SHELF_H, false, Image.FORMAT_RGBA8)
	var ramp: Array[Color] = BoosterArt.ramp(aisle.id)
	art.fill(ramp[3] if lit else Palette.TEAL_BLACK)
	var minis: Array[Image] = []
	for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
		if card.mini_art_ref != "" and ResourceLoader.exists(card.mini_art_ref):
			minis.append(
				_modulated(load(card.mini_art_ref) as Texture2D, LIT_MINI if lit else DARK_MINI)
			)
	var plank: Image = _modulated(PLANK, Color.WHITE if lit else DARK_PLANK)
	plank.resize(plank.get_width() >> 1, plank.get_height() >> 1, Image.INTERPOLATE_NEAREST)
	var n: int = (String(aisle.id).length() * 3) % maxi(1, minis.size())
	for row: int in PLANKS.size():
		var py: int = PLANKS[row]
		if lit:
			_r(art, 4, py - 26, 232, 1, ramp[2])
		var x: int = 6 + (row % 2) * 4
		while x < 226 and not minis.is_empty():
			var shelf_mini: Image = minis[n % minis.size()]
			n += 1
			for f: int in 3:
				art.blend_rect(
					shelf_mini,
					Rect2i(Vector2i.ZERO, shelf_mini.get_size()),
					Vector2i(x + f * 9, py - shelf_mini.get_height())
				)
			x += 34
		_plank(art, plank, py)
		_r(art, 0, py + 7, SHELF_W, 1, Palette.INK)
		if lit:
			x = 8 + (row % 2) * 4
			while x < 226:
				_r(art, x, py + 2, 8, 4, Palette.CREAM)
				_r(art, x + 1, py + 3, 2, 2, ramp[1])
				x += 34
	_r(art, 0, 0, SHELF_W, 4, Palette.STEEL_SHADE if lit else Palette.STEEL_DARKEST)
	_r(art, 0, 0, SHELF_W, 1, Palette.STEEL_LIGHT if lit else Palette.STEEL_DARK)
	_r(art, 0, 4, SHELF_W, 1, Palette.INK)
	for x: int in [0, 236]:
		_r(art, x, 0, 4, SHELF_H, Palette.STEEL_SHADE if lit else Palette.STEEL_DARKEST)
		_r(art, x, 0, 1, SHELF_H, Palette.STEEL_LIGHT if lit else Palette.STEEL_DARK)
		_r(art, x + 3, 0, 1, SHELF_H, Palette.INK)
	return art


## The 1x plank nine-sliced 3 px each side across the run at `y`, 7 px tall.
static func _plank(art: Image, plank: Image, y: int) -> void:
	var pw: int = plank.get_width()
	var ph: int = mini(7, plank.get_height())
	for x: int in SHELF_W:
		var sx: int = (
			x
			if x < 3
			else (pw - (SHELF_W - x) if x >= SHELF_W - 3 else 3 + (x - 3) % maxi(1, pw - 6))
		)
		for yy: int in ph:
			var c: Color = plank.get_pixel(clampi(sx, 0, pw - 1), yy)
			if c.a > 0.5:
				art.set_pixel(x, y + yy, c)


static func _modulated(texture: Texture2D, tint: Color) -> Image:
	var image: Image = texture.get_image().duplicate() as Image
	if image == null or image.is_empty():
		# No texture read-back (the headless test run): a clear image of the same size.
		return Image.create(texture.get_width(), texture.get_height(), false, Image.FORMAT_RGBA8)
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				image.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	return image


static func _brick(art: Image, y0: int, y1: int) -> void:
	_r(art, 0, y0, BoosterArt.AW, y1 - y0, Palette.VELVET_DARKEST)
	var row: int = 0
	var y: int = y0
	while y < y1:
		var offset: int = 6 if row % 2 else 0
		var x: int = -offset
		while x < BoosterArt.AW:
			var dark: bool = posmod(row * 7 + x, 5) == 0
			var left: int = maxi(0, x)
			_r(
				art,
				left,
				y,
				11 - (left - x),
				mini(4, y1 - y),
				Palette.BROWN_DARKEST if dark else Palette.VELVET_DARK
			)
			x += 12
		row += 1
		y += 5


static func _paint_facade() -> Image:
	var aw: int = BoosterArt.AW
	var art: Image = Image.create(aw, BoosterArt.AH, false, Image.FORMAT_RGBA8)
	_r(art, 0, 0, aw, 44, Palette.TEAL_SHADE)
	_r(art, 0, 38, aw, 3, Palette.TEAL_LIGHT)
	_r(art, 0, 41, aw, 3, Palette.PLASTER)
	_r(art, 560, 31, 1, 1, Palette.TEAL_PALE)
	_r(art, 0, 44, aw, 8, Palette.STEEL_DARKEST)
	_r(art, 0, 44, aw, 1, Palette.MUSTARD_DARK)
	_r(art, 0, 51, aw, 1, Palette.CHARCOAL)
	_brick(art, 52, 300)
	var f: Rect2i = FASCIA
	_r(art, f.position.x, f.position.y, f.size.x, f.size.y, Palette.INK)
	_r(art, f.position.x + 1, f.position.y + 1, f.size.x - 2, f.size.y - 2, Palette.TEAL_BLACK)
	_r(art, f.position.x + 3, f.position.y + 3, f.size.x - 6, 2, Palette.BACKGROUND)
	var neon: Image = NEON_OFF.get_image().duplicate() as Image
	if neon.is_compressed():
		neon.decompress()
	neon.convert(Image.FORMAT_RGBA8)
	art.blend_rect(
		neon, Rect2i(Vector2i.ZERO, neon.get_size()), Vector2i(320 - 81, f.position.y + 6)
	)
	_r(art, f.position.x + 1, f.position.y + 57, f.size.x - 2, 2, Palette.TEAL_SHADE)
	_r(art, f.position.x + 1, f.position.y + 59, f.size.x - 2, 3, Palette.TOMATO_DARK)
	_r(art, f.position.x - 2, f.position.y + 66, f.size.x + 4, 2, Palette.BRASS)
	_r(art, f.position.x - 2, f.position.y + 68, f.size.x + 4, 1, Palette.BRASS_DARK)
	for w: Rect2i in WINDOWS:
		_r(
			art,
			w.position.x - 3,
			w.position.y - 9,
			w.size.x + 6,
			w.size.y + 9,
			Palette.STEEL_DARKEST
		)
		_r(art, w.position.x - 3, w.position.y - 9, w.size.x + 6, 1, Palette.STEEL_SHADE)
		_r(art, w.position.x, w.position.y, w.size.x, w.size.y, Palette.TEAL_BLACK)
		for k: int in 4:
			var sy: int = w.position.y + 30 + k * 30
			_r(art, w.position.x + 6, sy, w.size.x - 12, 2, Palette.BROWN_DARKEST)
			var x: int = w.position.x + 10
			while x < w.end.x - 14:
				_r(art, x, sy - 6, 7, 6, Palette.TEAL_DARK)
				x += 11
		_d(art, w.position.x, w.position.y, w.size.x, w.size.y, Palette.TEAL_DARK, 3)
		_r(art, w.position.x - 3, w.end.y, w.size.x + 6, 4, Palette.STEEL_DARK)
		_r(art, w.position.x - 3, w.end.y, w.size.x + 6, 1, Palette.STEEL_SHADE)
	var d: Rect2i = DOOR
	_r(art, d.position.x - 4, d.position.y - 10, d.size.x + 8, d.size.y + 10, Palette.STEEL_DARKEST)
	_r(art, d.position.x - 4, d.position.y - 10, d.size.x + 8, 1, Palette.STEEL_SHADE)
	_r(art, 312, d.position.y - 7, 10, 4, Palette.CHARCOAL)
	_r(art, 320, d.position.y - 6, 1, 1, Palette.TOMATO_DARK)
	art.fill_rect(d, Color(0, 0, 0, 0))
	for x: int in [d.position.x - 22, d.end.x + 12]:
		_r(art, x, 168, 10, 6, Palette.INK)
		_r(art, x + 1, 169, 8, 4, Palette.BRASS_DARK)
		_r(art, x + 2, 174, 6, 2, Palette.STEEL_DARK)
	_r(art, 0, 300, aw, 38, Palette.STEEL_SHADE)
	_r(art, 0, 300, aw, 1, Palette.STEEL_PALE)
	var sx: int = 0
	while sx < aw:
		_r(art, sx, 301, 1, 37, Palette.STEEL_DARK)
		sx += 32
	_r(art, 0, 318, aw, 1, Palette.STEEL_DARK)
	_d(art, d.position.x - 10, 301, d.size.x + 20, 10, Palette.STEEL_DARKEST, 4)
	_r(art, 0, 338, aw, 2, Palette.STEEL_LIGHT)
	_r(art, 0, 340, aw, 20, Palette.CHARCOAL)
	_d(art, 0, 340, aw, 20, Palette.TEAL_BLACK, 4)
	sx = 8
	while sx < aw:
		_r(art, sx, 350, 22, 2, Palette.MUSTARD_DARK)
		sx += 48
	return art
