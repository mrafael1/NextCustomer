class_name StoreArt
extends RefCounted
## The store behind the counter (#123, mock-up docs/art/mockups/scene_123.html, direction A),
## painted once into an image on the 640x360 art grid (one art px = ArtStyle.ART_SCALE stage px)
## and shown by StoreShelves with nearest filtering. Every colour is the palette's. The store is
## flat planes with no ink outline (outlines belong to what the player can touch), back to front:
## the ceiling, the far wall, the storefront glass with the evening outside (sky bands, a thin
## warm horizon, the town's roofs with a few lit windows, two reflections), the mullions, and a
## run of shelving with flat blocks of stock on two shelves. Each part has an unlit and a lit
## colour; the pendant lamps' cones (LAMP_XS) pick the lit one, flat inside, with a narrow
## dithered band at each pool's edge (Bayer order), so the light steps like the title's.
##
## The image spans the art columns from LEFT to RIGHT (the stage's art x, so a letterbox band
## beside the stage and the camera's stop at the machine both show more store) and the rows from
## the top bar's foot down to the counter's top.

## The image's art columns and rows (stage art px: stage px / ArtStyle.ART_SCALE).
const LEFT := -160
const RIGHT := int(ShiftStage.WORLD_RIGHT / 2.0)
const TOP := int(ShiftStage.TOP_BAR_BOTTOM / 2.0)
const BOTTOM := int(ShiftStage.COUNTER_TOP / 2.0)
## The ceiling's foot and its seam, then the far wall.
const CEILING_FOOT := 39
## The storefront glass (art px): from GLASS_LEFT on, between its top and its sill, a mullion
## every MULLION_STEP.
const GLASS_LEFT := 150
const GLASS_TOP := 46
const GLASS_BOTTOM := 100
const MULLION_STEP := 70
const MULLION_WIDTH := 3
## The sky's bands as shares of the glass's height (top to bottom) and their colours, with a
## 50 % dither row at the first edge and a 25 % one at the second.
const SKY_STOPS: Array[float] = [0.5, 0.86, 0.92]
const SKY: Array[Color] = [
	Palette.TEAL_DARK, Palette.TEAL_SHADE, Palette.TEAL, Palette.TOMATO_LIGHT
]
## The town's roofs: heights (art px) and widths cycle; one window in WINDOW_EVERY is lit.
const ROOF_HEIGHTS: Array[int] = [9, 13, 7, 15, 11, 6, 12, 17, 8, 10, 14, 7, 11, 16, 9, 12, 6, 13]
const WINDOW_EVERY := 4
## The reflections on the glass: a 1 px stair from each x, REFLECTION_STEPS long.
const REFLECTION_XS: Array[int] = [204, 418, 632]
const REFLECTION_STEPS := 14
## The shelving run: its top, its two shelves (each stock's foot on a lip LIP_HEIGHT tall).
const SHELVING_TOP := 100
const SHELF_YS: Array[int] = [105, 124]
const STOCK_FOOT := 15
const LIP_HEIGHT := 3
const STOCK_WIDTH := 5
const STOCK_GAP := 1
const FACING_GAP := 4
## The stock's colours, unlit and lit, in turn along a shelf.
const STOCK: Array[Array] = [
	[Palette.TEAL_DARK, Palette.TEAL_SHADE],
	[Palette.RUBBER, Palette.STEEL_SHADE],
	[Palette.WOOD_DARKEST, Palette.BROWN_DARK],
	[Palette.SLATE, Palette.GREY_DARK],
	[Palette.TOMATO_DARKEST, Palette.TOMATO_DARK],
	[Palette.TEAL_DARK, Palette.TEAL_SHADE],
	[Palette.RUBBER, Palette.GREY],
	[Palette.MUSTARD_DARKEST, Palette.MUSTARD_DARK],
]
## The pendant lamps (art x of each cone's centre), their cone's top, its widening per row and its
## reach; the pool is lit where the light beats a Bayer threshold squeezed into DITHER_BAND.
const LAMP_XS: Array[int] = [196, 494, 588, 724, 830]
const CONE_TOP := 39
const CONE_SLOPE := 0.42
const CONE_REACH := 150.0
const CONE_STRENGTH := 1.6
const DITHER_BAND := 0.45
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _texture: ImageTexture


## The store's texture (painted on first use, then kept).
static func texture() -> ImageTexture:
	if _texture == null:
		_texture = ImageTexture.create_from_image(paint())
	return _texture


## The image's size in art px.
static func art_size() -> Vector2i:
	return Vector2i(RIGHT - LEFT, BOTTOM - TOP)


## Paints the store: the unlit and the lit planes, then the lamps' pools choose between them.
static func paint() -> Image:
	var size: Vector2i = art_size()
	var dark: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var lit: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var planes: Array[Image] = [dark, lit]
	_rect(
		planes, LEFT, TOP, RIGHT - LEFT, CEILING_FOOT - TOP, Palette.TEAL_BLACK, Palette.BACKGROUND
	)
	_rect(planes, LEFT, CEILING_FOOT, RIGHT - LEFT, 1, Palette.SLATE_DARK, Palette.SLATE)
	_rect(planes, LEFT, CEILING_FOOT + 1, RIGHT - LEFT, BOTTOM, Palette.BACKGROUND, Palette.PANEL)
	_paint_glass(planes)
	_paint_shelving(planes)
	var out: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var ax: int = x + LEFT
			var ay: int = y + TOP
			var threshold: float = (BAYER[(ay & 3) * 4 + (ax & 3)] + 0.5) / 16.0
			var on: bool = light_at(ax, ay) > 0.5 + (threshold - 0.5) * DITHER_BAND
			out.set_pixel(x, y, lit.get_pixel(x, y) if on else dark.get_pixel(x, y))
	return out


## How lit the art px (ax, ay) is (0 none; over 0.5 lit): the brightest lamp cone over it.
static func light_at(ax: int, ay: int) -> float:
	var best: float = 0.0
	var dy: float = ay - CONE_TOP
	if dy < 0.0 or dy > CONE_REACH:
		return 0.0
	var half: float = 3.0 + dy * CONE_SLOPE
	for cx: int in LAMP_XS:
		var t: float = absf(ax - cx) / half
		if t < 1.0:
			best = maxf(best, (1.0 - t * t) * (1.0 - pow(dy / CONE_REACH, 2.0)) * CONE_STRENGTH)
	return best


static func _paint_glass(planes: Array[Image]) -> void:
	var height: int = GLASS_BOTTOM - GLASS_TOP
	for y: int in range(GLASS_TOP, GLASS_BOTTOM):
		var share: float = float(y - GLASS_TOP) / height
		var band: int = 0
		while band < SKY_STOPS.size() and share >= SKY_STOPS[band]:
			band += 1
		_rect(planes, GLASS_LEFT, y, RIGHT - GLASS_LEFT, 1, SKY[band], SKY[band])
	var first_edge: int = GLASS_TOP + int(height * SKY_STOPS[0]) - 2
	var second_edge: int = GLASS_TOP + int(height * SKY_STOPS[1]) - 2
	_dither(planes, GLASS_LEFT, first_edge, RIGHT - GLASS_LEFT, 2, SKY[1], 2)
	_dither(planes, GLASS_LEFT, second_edge, RIGHT - GLASS_LEFT, 2, SKY[2], 1)
	# The town's roofs, never outlined, with a few lit windows.
	var x: int = GLASS_LEFT
	var n: int = 0
	while x < RIGHT:
		var width: int = 14 + (n * 7) % 12
		var roof: int = ROOF_HEIGHTS[n % ROOF_HEIGHTS.size()]
		_rect(planes, x, GLASS_BOTTOM - roof, width, roof, Palette.BACKGROUND, Palette.BACKGROUND)
		for k: int in 2:
			var wy: int = GLASS_BOTTOM - roof + 3 + k * 4
			if (n + k) % WINDOW_EVERY == 0 and wy < GLASS_BOTTOM - 2:
				var wx: int = x + 3 + (n * 5 + k * 6) % maxi(1, width - 5)
				_rect(planes, wx, wy, 1, 1, Palette.MUSTARD_LIGHT, Palette.MUSTARD_LIGHT)
		x += width
		n += 1
	for rx: int in REFLECTION_XS:
		for k: int in REFLECTION_STEPS:
			_rect(planes, rx + k, GLASS_TOP + 30 - k * 2, 1, 2, Palette.TEAL_SHADE, Palette.TEAL)
	# The frame and the mullions, lit from the store side.
	var mx: int = GLASS_LEFT
	while mx < RIGHT:
		_rect(
			planes, mx, GLASS_TOP - 2, MULLION_WIDTH, height + 4, Palette.SLATE, Palette.TEAL_SHADE
		)
		mx += MULLION_STEP
	_rect(
		planes, GLASS_LEFT, GLASS_TOP - 3, RIGHT - GLASS_LEFT, 3, Palette.SLATE, Palette.TEAL_SHADE
	)
	_rect(
		planes, GLASS_LEFT, GLASS_BOTTOM, RIGHT - GLASS_LEFT, 2, Palette.SLATE, Palette.TEAL_SHADE
	)


static func _paint_shelving(planes: Array[Image]) -> void:
	_rect(planes, LEFT, SHELVING_TOP, RIGHT - LEFT, BOTTOM, Palette.SLATE_DARK, Palette.SLATE)
	_rect(planes, LEFT, SHELVING_TOP, RIGHT - LEFT, 2, Palette.SLATE, Palette.STEEL_DARKEST)
	for row: int in SHELF_YS.size():
		var shelf_y: int = SHELF_YS[row]
		var x: int = LEFT - 6 * row
		var n: int = row * 3
		while x < RIGHT:
			var colours: Array = STOCK[(n * 3 + row) % STOCK.size()]
			var facings: int = 4 + (n * 3) % 3
			var stock_height: int = 12 - (n % 2) * 2
			for f: int in facings:
				var fx: int = x + f * (STOCK_WIDTH + STOCK_GAP)
				_rect(
					planes,
					fx,
					shelf_y + STOCK_FOOT - stock_height,
					STOCK_WIDTH,
					stock_height,
					colours[0],
					colours[1]
				)
			x += facings * (STOCK_WIDTH + STOCK_GAP) + FACING_GAP
			n += 1
		var lip_y: int = shelf_y + STOCK_FOOT
		_rect(
			planes, LEFT, lip_y, RIGHT - LEFT, LIP_HEIGHT, Palette.RUBBER_DARK, Palette.STEEL_DARK
		)
		_rect(planes, LEFT, lip_y, RIGHT - LEFT, 1, Palette.RUBBER, Palette.STEEL)


## Fills the art rect (stage art px) with `dark` on the unlit plane and `light` on the lit one,
## clipped to the image.
static func _rect(
	planes: Array[Image], x: int, y: int, w: int, h: int, dark: Color, light: Color
) -> void:
	var area: Rect2i = Rect2i(x - LEFT, y - TOP, w, h).intersection(
		Rect2i(Vector2i.ZERO, art_size())
	)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	planes[0].fill_rect(area, dark)
	planes[1].fill_rect(area, light)


## A dither row on both planes: level 1 = 25 %, 2 = 50 % of the art px take `colour`.
static func _dither(
	planes: Array[Image], x: int, y: int, w: int, h: int, colour: Color, level: int
) -> void:
	var size: Vector2i = art_size()
	for ay: int in range(y, y + h):
		for ax: int in range(x, x + w):
			var on: bool = (ax + ay) % 2 == 0 if level == 2 else (ax % 2 == 0 and ay % 2 == 0)
			var px: Vector2i = Vector2i(ax - LEFT, ay - TOP)
			if on and px.x >= 0 and px.y >= 0 and px.x < size.x and px.y < size.y:
				planes[0].set_pixelv(px, colour)
				planes[1].set_pixelv(px, colour)
