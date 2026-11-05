class_name StaffRoomArt
extends RefCounted
## The v4 B staff room, painted at 640x360 then nearest-scaled. Rectangles are art pixels.
## Cinder blocks, tube, open double locker, four teal lockers, wood bench and lino floor.

## The badge pins corkboard's frame (art px; the stage is drawn 2x): a picked crate's halo stays
## under it.
const PIN_BOARD := Rect2i(42, 72, 138, 89)

## The painted room, made once (every board's page 2 shows the same one).
static var _cached: ImageTexture


static func texture() -> ImageTexture:
	if _cached == null:
		_cached = _paint()
	return _cached


static func _paint() -> ImageTexture:
	var art: Image = Image.create(640, 360, false, Image.FORMAT_RGBA8)
	art.fill(Palette.INK_LIGHT)
	for y: int in range(28, 360):
		for x: int in 640:
			var row: int = (y - 28) >> 3
			var offset: int = 8 if row % 2 else 0
			if (y - 28) % 8 != 0 and (x + offset) % 16 != 0:
				var lit: bool = absf(x - 322.0) < 70 + (y - 34) * 1.05
				art.set_pixel(
					x, y, Palette.GREY if lit and x % 2 == 0 and y % 2 == 0 else Palette.GREY_DARK
				)
	_rect(art, Rect2i(246, 28, 152, 7), Palette.INK)
	_rect(art, Rect2i(247, 28, 150, 3), Palette.STEEL)
	_rect(art, Rect2i(250, 32, 144, 2), Palette.PAPER)
	for box: Rect2i in [Rect2i(300, 36, 26, 16), Rect2i(328, 42, 20, 10), Rect2i(372, 40, 24, 12)]:
		_rect(art, box, Palette.INK)
		_rect(art, box.grow(-1), Palette.WOOD)
		_rect(
			art,
			Rect2i(box.position.x + (box.size.x >> 1), box.position.y + 1, 3, box.size.y - 2),
			Palette.MUSTARD_LIGHT
		)
	_rect(art, Rect2i(6, 52, 426, 5), Palette.INK)
	_rect(art, Rect2i(7, 53, 424, 2), Palette.TEAL_SHADE)
	_rect(art, Rect2i(36, 56, 150, 246), Palette.INK)
	_rect(art, Rect2i(37, 57, 148, 244), Palette.TEAL)
	_rect(art, Rect2i(40, 60, 142, 240), Palette.TEAL_BLACK)
	_rect(art, Rect2i(40, 170, 142, 130), Palette.SLATE_DARK)
	_rect(art, Rect2i(40, 68, 142, 3), Palette.INK)
	_rect(art, Rect2i(40, 68, 142, 1), Palette.TEAL_SHADE)
	_rect(art, Rect2i(118, 59, 9, 9), Palette.INK)
	_rect(art, Rect2i(119, 60, 7, 8), Palette.CREAM)
	_rect(art, Rect2i(119, 63, 7, 2), Palette.TOMATO)
	_rect(art, Rect2i(160, 62, 18, 6), Palette.BRASS)
	_rect(art, PIN_BOARD, Palette.INK)
	_rect(art, Rect2i(43, 73, 136, 87), Palette.BROWN_DARK)
	_rect(art, Rect2i(44, 75, 134, 84), Palette.INK)
	for y: int in range(76, 158):
		for x: int in range(45, 177):
			var grain: int = (x * 37 + y * 71 + x * y * 13) % 101
			art.set_pixel(
				x,
				y,
				(
					Palette.WOOD_PALE
					if grain < 9
					else Palette.BROWN if grain < 24 else Palette.BROWN_LIGHT
				)
			)
	_rect(art, Rect2i(8, 58, 28, 244), Palette.INK)
	_rect(art, Rect2i(9, 59, 26, 242), Palette.TEAL_SHADE)
	_rect(art, Rect2i(12, 62, 20, 236), Palette.TEAL_DARK)
	for vent: int in 4:
		_rect(art, Rect2i(13, 66 + vent * 4, 18, 2), Palette.INK)
	for index: int in 4:
		var left: int = 188 + index * 60
		_rect(art, Rect2i(left, 56, 61, 246), Palette.INK)
		_rect(art, Rect2i(left + 1, 57, 59, 244), Palette.TEAL)
		_rect(art, Rect2i(left + 1, 57, 1, 244), Palette.TEAL_LIGHT)
		_rect(art, Rect2i(left + 58, 57, 1, 244), Palette.TEAL_SHADE)
		for vent: int in 4:
			_rect(art, Rect2i(left + 14, 64 + vent * 4, 32, 2), Palette.INK)
			_rect(art, Rect2i(left + 14, 65 + vent * 4, 32, 1), Palette.TEAL_DARK)
		_rect(art, Rect2i(left + 20, 84, 21, 12), Palette.INK)
		_rect(art, Rect2i(left + 21, 85, 19, 10), Palette.BRASS)
		_rect(art, Rect2i(left + 50, 140, 5, 26), Palette.INK)
		_rect(art, Rect2i(left + 51, 141, 3, 24), Palette.STEEL_LIGHT)
		for vent: int in 3:
			_rect(art, Rect2i(left + 14, 268 + vent * 5, 32, 2), Palette.TEAL_DARK)
	_rect(art, Rect2i(0, 299, 436, 3), Palette.TEAL_BLACK)
	for y: int in range(302, 360):
		for x: int in 436:
			art.set_pixel(
				x, y, Palette.RUBBER if ((x >> 4) + floori(y / 6.0)) % 2 else Palette.CHARCOAL
			)
	# The bench (v1.01: 17 art px lower, under the taller crates), its legs clear of the footer's
	# ‹ STORE key.
	_rect(art, Rect2i(10, 298, 422, 11), Palette.INK)
	_rect(art, Rect2i(11, 299, 420, 1), Palette.WOOD_PALE)
	_rect(art, Rect2i(11, 300, 420, 4), Palette.BROWN)
	_rect(art, Rect2i(11, 304, 420, 4), Palette.BROWN_DARK)
	for left: int in [124, 216, 404]:
		_rect(art, Rect2i(left, 309, 7, 14), Palette.INK)
		_rect(art, Rect2i(left + 1, 309, 5, 13), Palette.STEEL)
	_rect(art, Rect2i(433, 28, 3, 332), Palette.INK)
	_rect(art, Rect2i(436, 28, 6, 332), Palette.TEAL_DARK)
	return ImageTexture.create_from_image(art)


static func _rect(art: Image, rect: Rect2i, color: Color) -> void:
	art.fill_rect(rect, color)
