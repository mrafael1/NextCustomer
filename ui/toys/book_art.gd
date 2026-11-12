class_name BookArt
extends RefCounted
## The FIGURINE BOOK's pixel art (v1.26 round 2, the user: "a card book, like a pokemon card
## book"), painted once into images on the 640x360 art grid with StorefrontArt's rects and
## dithers (as ToyExitArt paints the TOY MACHINES) and shown at 2x with nearest filtering. Every
## colour is the palette's.
##
## The backdrop holds what never changes: the stock room after closing (the teal-black wall with
## its pilasters and brass rail under a dark ceiling, two recessed lamps whose light falls on the
## counter), the wooden counter, and the open binder on it: a tomato vinyl cover with cream
## stitching, two pages of clear sleeves (three by two pockets on a slate backing, the page stack's
## edges outside them) and the steel rings over the spine. The live parts are their own images: a
## card's face in its family's colours (or grey, not collected yet, with a big ? where the
## figurine stands; a coupon's, round 3, in its ticket colours with no plinth and no price
## sticker: its window has the cart reveal's tomato scissors line instead) and the sleeves' sheen
## laid over a card (round 7 dropped the divider tabs).

## The stage in art px.
const STAGE := Vector2i(640, 360)
## The binder (its cover), its two pages and the spine between them, in stage art px.
const BINDER_RECT := Rect2i(12, 46, 616, 280)
const PAGE_RECTS: Array[Rect2i] = [Rect2i(20, 50, 296, 272), Rect2i(324, 50, 296, 272)]
const SPINE_RECT := Rect2i(316, 46, 8, 280)
## The rings' tops over the spine.
const RING_TOPS: Array[int] = [84, 182, 280]
## A page's pockets: COLUMNS x ROWS, POCKET_SIZE, the first POCKET_ORIGIN from the page's top
## left, POCKET_PITCH apart; a card sits CARD_INSET inside its pocket.
const COLUMNS := 3
const ROWS := 2
const POCKET_ORIGIN := Vector2i(4, 16)
const POCKET_SIZE := Vector2i(94, 124)
const POCKET_PITCH := Vector2i(97, 126)
const CARD_INSET := Vector2i(2, 2)
## A card (art px): its name band, the figurine's window and the description's panel, each
## inside the card's 3 px family-coloured rim. The window holds the figurine at the game's 2x
## (its 48x48 sprite is 48 art px; review fix: it was drawn at 1x), as on a trading card.
const CARD_SIZE := Vector2i(90, 120)
const BAND_RECT := Rect2i(3, 3, 84, 13)
const WINDOW_RECT := Rect2i(3, 17, 84, 51)
const TEXT_RECT := Rect2i(3, 69, 84, 48)
## The window's plinth: its top row (where the figurine stands) and its depth.
const PLINTH_TOP := 64
const PLINTH_ROWS := 3
## The ? of a card not collected yet: its top left in the card, its 3x5 pattern at
## MYSTERY_CELL art px a cell, standing on the plinth where the figurine would.
const MYSTERY_AT := Vector2i(33, 30)
const MYSTERY_CELL := 6
const MYSTERY_PATTERN := ["111", "001", "011", "000", "010"]
## The price sticker in the window's bottom right corner (art px, card coordinates).
const STICKER_RECT := Rect2i(67, 54, 18, 9)
## A coupon's window: its tomato scissors line COUPON_CUT_INSET inside the window's light,
## dashed every COUPON_DASH texels (the cart reveal's coupon tile's).
const COUPON_CUT_INSET := 2
const COUPON_DASH := 3
## The coupon mark's corner (BookCard.GLYPH_AT's 9x9 at art (6, 20), a texel clear round it): the
## scissors line leaves it out, so the mark cuts the corner instead of sitting on the dashes.
const COUPON_MARK_CLEAR := Rect2i(5, 19, 11, 11)
## A card not collected yet (review fix: grey read like an owned Household card): a pale empty
## sleeve card in pale grey, its ink outline broken every GREY_DASH texels, its window slate.
const GREY_DASH := 3
## The title board's height (TOY MACHINES' hanging board's style, its words a label on it).
const TITLE_BOARD_HEIGHT := 25

static var _backdrop: ImageTexture
static var _layers: Dictionary[String, ImageTexture] = {}


## The stock room, the counter and the open binder (640x360 art).
static func backdrop() -> ImageTexture:
	if _backdrop == null:
		var art: StorefrontArt = StorefrontArt.new(STAGE, Vector2i.ZERO)
		_paint_room(art)
		_paint_binder(art)
		for page: Rect2i in PAGE_RECTS:
			_paint_page(art, page)
		_paint_spine(art)
		_backdrop = ImageTexture.create_from_image(art.image)
	return _backdrop


## A card's face (CARD_SIZE) in `face`, `light` and `shade` (a family's ticket colours), or grey
## with the ? in the window when `grey` (not collected yet; the colours are then ignored); a
## `coupon`'s window has the scissors line and no plinth or sticker (a grey coupon's is the
## shared grey face).
static func card_face(
	face: Color, light: Color, shade: Color, grey: bool, coupon: bool = false
) -> ImageTexture:
	coupon = coupon and not grey
	var key: String = "card_grey" if grey else "card_%s_%s_%s" % [face, light, shade]
	key += "_coupon" if coupon else ""
	if not _layers.has(key):
		if grey:
			face = Palette.GREY_LIGHT
			light = Palette.CREAM_SHADE
			shade = Palette.GREY
		var art: StorefrontArt = StorefrontArt.new(CARD_SIZE, Vector2i.ZERO)
		var w: int = CARD_SIZE.x
		var h: int = CARD_SIZE.y
		art.rect(Rect2i(1, 0, w - 2, h), Palette.INK)
		art.rect(Rect2i(0, 1, w, h - 2), Palette.INK)
		art.rect(Rect2i(1, 1, w - 2, h - 2), face)
		art.rect(Rect2i(1, 1, w - 2, 1), light)
		art.rect(Rect2i(1, 1, 1, h - 2), light)
		art.rect(Rect2i(1, h - 2, w - 2, 1), shade)
		art.rect(Rect2i(w - 2, 1, 1, h - 2), shade)
		if grey:
			_dash_outline(art)
		if coupon:
			_paint_coupon_window(art, light, shade)
		else:
			_paint_window(art, light, shade, grey)
		_inset(art, TEXT_RECT, shade)
		art.rect(TEXT_RECT.grow(-1), Palette.CREAM if grey else Palette.PAPER)
		var foot: int = TEXT_RECT.end.y - 2
		art.rect(
			Rect2i(TEXT_RECT.position.x + 1, foot, TEXT_RECT.size.x - 2, 1), Palette.CREAM_SHADE
		)
		_layers[key] = ImageTexture.create_from_image(art.image)
	return _layers[key]


## The FIGURINE BOOK's title board `width` art px wide (TITLE_BOARD_HEIGHT): the TOY MACHINES'
## hanging board (ToyExitArt.board) on the stock-room wall, so the two screens' titles match: ink
## outline, a steel frame, a teal black face with a teal shade line and a tomato dark underline.
static func title_board(width: int) -> ImageTexture:
	var key: String = "title_%d" % width
	if not _layers.has(key):
		var h: int = TITLE_BOARD_HEIGHT
		var art: StorefrontArt = StorefrontArt.new(Vector2i(width, h), Vector2i.ZERO)
		art.rect(Rect2i(1, 0, width - 2, h), Palette.INK)
		art.rect(Rect2i(0, 1, width, h - 2), Palette.INK)
		art.rect(Rect2i(1, 1, width - 2, h - 2), Palette.STEEL_DARKEST)
		art.rect(Rect2i(1, 1, width - 2, 1), Palette.STEEL_SHADE)
		art.rect(Rect2i(3, 3, width - 6, h - 8), Palette.TEAL_BLACK)
		art.rect(Rect2i(3, h - 5, width - 6, 1), Palette.TEAL_SHADE)
		art.rect(Rect2i(3, h - 4, width - 6, 2), Palette.TOMATO_DARK)
		_layers[key] = ImageTexture.create_from_image(art.image)
	return _layers[key]


## A card not collected yet: its ink outline broken into dashes (every GREY_DASH texels one is
## left out), an empty sleeve's card rather than a family's.
static func _dash_outline(art: StorefrontArt) -> void:
	var w: int = CARD_SIZE.x
	var h: int = CARD_SIZE.y
	for x: int in range(3, w - 3):
		if x % GREY_DASH == 0:
			art.px(x, 0, Color.TRANSPARENT)
			art.px(x, h - 1, Color.TRANSPARENT)
	for y: int in range(3, h - 3):
		if y % GREY_DASH == 0:
			art.px(0, y, Color.TRANSPARENT)
			art.px(w - 1, y, Color.TRANSPARENT)


## The clear sleeve's sheen over a pocket (POCKET_SIZE, transparent but for its glints): short
## diagonal glints where the card shows no words, in the window's lower left (under the family
## glyph, left of the figurine) and along the pocket's right rim.
static func sheen() -> ImageTexture:
	if not _layers.has("sheen"):
		var art: StorefrontArt = StorefrontArt.new(POCKET_SIZE, Vector2i.ZERO)
		var glint: Color = Color(Palette.PAPER, 0.5)
		var faint: Color = Color(Palette.PAPER, 0.3)
		for i: int in 8:
			art.px(8 + i, 59 - i, glint)
		for i: int in 5:
			art.px(8 + i, 63 - i, faint)
		for i: int in 6:
			art.px(POCKET_SIZE.x - 3 - i % 2, 60 + i * 2, faint)
		_layers["sheen"] = ImageTexture.create_from_image(art.image)
	return _layers["sheen"]


## A pocket's top left on its page `side` (0 left, 1 right), in stage art px.
static func pocket_origin(side: int, slot: int) -> Vector2i:
	var page: Rect2i = PAGE_RECTS[side]
	@warning_ignore("integer_division")
	var row: int = slot / COLUMNS
	var column: int = slot % COLUMNS
	return page.position + POCKET_ORIGIN + Vector2i(column, row) * POCKET_PITCH


## A rect `area` set into the card: a `shade` line round it (its inside is the caller's).
static func _inset(art: StorefrontArt, area: Rect2i, shade: Color) -> void:
	art.rect(area, shade)


## The figurine's window: a backdrop lit from the top in the family's light colour (slate under
## the ? of a grey card), the wooden plinth and the price sticker's place.
static func _paint_window(art: StorefrontArt, light: Color, shade: Color, grey: bool) -> void:
	_inset(art, WINDOW_RECT, shade)
	var inner: Rect2i = WINDOW_RECT.grow(-1)
	if grey:
		art.rect(inner, Palette.SLATE)
		art.dither(Rect2i(inner.position, Vector2i(inner.size.x, 16)), Palette.SLATE_DARK, 1)
	else:
		art.rect(inner, Palette.CREAM)
		art.dither(Rect2i(inner.position, Vector2i(inner.size.x, 20)), light, 2)
		art.dither(Rect2i(inner.position + Vector2i(0, 20), Vector2i(inner.size.x, 12)), light, 1)
	var plinth: Rect2i = Rect2i(inner.position.x, PLINTH_TOP, inner.size.x, PLINTH_ROWS)
	plinth = plinth.intersection(inner)
	art.rect(plinth, Palette.SLATE_DARK if grey else Palette.WOOD)
	var top_line: Color = Palette.TEAL_SHADE if grey else Palette.WOOD_LIGHT
	art.rect(Rect2i(plinth.position, Vector2i(plinth.size.x, 1)), top_line)
	art.rect(Rect2i(plinth.position.x, plinth.end.y - 1, plinth.size.x, 1), Palette.WOOD_DARKEST)
	if grey:
		_paint_mystery(art)
	else:
		var s: Rect2i = STICKER_RECT
		art.rect(Rect2i(s.position.x + 1, s.position.y, s.size.x - 2, s.size.y), Palette.INK)
		art.rect(Rect2i(s.position.x, s.position.y + 1, s.size.x, s.size.y - 2), Palette.INK)
		art.rect(s.grow(-1), Palette.MUSTARD_LIGHT)
		art.rect(Rect2i(s.position.x + 1, s.end.y - 2, s.size.x - 2, 1), Palette.MUSTARD)


## A coupon's window: lit like an item's, with no plinth or sticker, and the tomato scissors
## line round it (the slip floats in it, as a coupon's in the cart reveal's tile).
static func _paint_coupon_window(art: StorefrontArt, light: Color, shade: Color) -> void:
	_inset(art, WINDOW_RECT, shade)
	var inner: Rect2i = WINDOW_RECT.grow(-1)
	art.rect(inner, Palette.CREAM)
	art.dither(Rect2i(inner.position, Vector2i(inner.size.x, 20)), light, 2)
	art.dither(Rect2i(inner.position + Vector2i(0, 20), Vector2i(inner.size.x, 12)), light, 1)
	var cut: Rect2i = inner.grow(-COUPON_CUT_INSET)
	var dashes: Array[Vector2i] = []
	for x: int in range(cut.position.x, cut.end.x):
		if (x - cut.position.x) % COUPON_DASH != COUPON_DASH - 1:
			dashes.append_array([Vector2i(x, cut.position.y), Vector2i(x, cut.end.y - 1)])
	for y: int in range(cut.position.y, cut.end.y):
		if (y - cut.position.y) % COUPON_DASH != COUPON_DASH - 1:
			dashes.append_array([Vector2i(cut.position.x, y), Vector2i(cut.end.x - 1, y)])
	for dash: Vector2i in dashes:
		if not COUPON_MARK_CLEAR.has_point(dash):
			art.rect(Rect2i(dash, Vector2i.ONE), Palette.TOMATO)


## The big ? of a card not collected yet: pale grey blocks with an ink shadow.
static func _paint_mystery(art: StorefrontArt) -> void:
	for pass_index: int in 2:
		var colour: Color = Palette.INK if pass_index == 0 else Palette.GREY_LIGHT
		var shift: Vector2i = Vector2i(1, 1) if pass_index == 0 else Vector2i.ZERO
		for row: int in MYSTERY_PATTERN.size():
			var line: String = MYSTERY_PATTERN[row]
			for column: int in line.length():
				if line[column] != "1":
					continue
				var at: Vector2i = MYSTERY_AT + Vector2i(column, row) * MYSTERY_CELL + shift
				art.rect(Rect2i(at, Vector2i(MYSTERY_CELL, MYSTERY_CELL)), colour)


## The stock room after closing: the ceiling, the wall with its pilasters and the brass rail,
## two recessed lamps, the wooden counter with its planks, and the lamps' pools on it.
static func _paint_room(art: StorefrontArt) -> void:
	art.rect(Rect2i(0, 0, 640, 10), Palette.CHARCOAL)
	art.dither(Rect2i(0, 0, 640, 10), Palette.TEAL_BLACK, 2)
	art.rect(Rect2i(0, 9, 640, 1), Palette.STEEL_DARK)
	art.rect(Rect2i(0, 10, 640, 22), Palette.TEAL_BLACK)
	art.dither(Rect2i(0, 10, 640, 22), Palette.BACKGROUND, 1)
	for x: int in range(40, 640, 80):
		art.rect(Rect2i(x, 10, 1, 22), Palette.BACKGROUND)
	art.rect(Rect2i(0, 32, 640, 2), Palette.BRASS_DARK)
	art.rect(Rect2i(0, 32, 640, 1), Palette.BRASS)
	art.rect(Rect2i(0, 34, 640, 1), Palette.BRASS_DARKEST)
	art.rect(Rect2i(0, 35, 640, 325), Palette.WOOD_DARK)
	var row: int = 0
	for y: int in range(35, 360, 9):
		art.rect(Rect2i(0, y, 640, 1), Palette.WOOD_DARKEST)
		for x: int in range((row * 37) % 61, 640, 61):
			art.rect(Rect2i(x, y + 3 + row % 3, 9, 1), Palette.WOOD)
			art.rect(Rect2i(x + 23, y + 5, 1, 3), Palette.WOOD_DARKEST)
		row += 1
	art.dither(Rect2i(0, 35, 640, 325), Palette.TEAL_BLACK, 1)
	art.dither(Rect2i(0, 330, 640, 30), Palette.TEAL_BLACK, 2)
	art.dither(Rect2i(0, 35, 10, 295), Palette.TEAL_BLACK, 2)
	art.dither(Rect2i(630, 35, 10, 295), Palette.TEAL_BLACK, 2)
	for cx: int in [160, 480]:
		art.rect(Rect2i(cx - 6, 8, 12, 3), Palette.STEEL_DARKEST)
		art.rect(Rect2i(cx - 5, 11, 10, 1), Palette.STEEL_DARK)
		art.rect(Rect2i(cx - 3, 12, 6, 1), Palette.MUSTARD_LIGHT)
		art.cone(cx, 13, 35, Vector2i(10, 30), Palette.MUSTARD_DARKEST, 0)
		art.dither(Rect2i(cx - 150, 35, 300, 10), Palette.MUSTARD_DARKEST, 1)
		art.dither(Rect2i(cx - 140, 326, 280, 4), Palette.MUSTARD_DARKEST, 1)


## The binder: its shadow on the counter, the tomato vinyl cover lit along its top and left with
## cream stitching round it.
static func _paint_binder(art: StorefrontArt) -> void:
	var b: Rect2i = BINDER_RECT
	art.dither(Rect2i(b.position.x + 3, b.end.y, b.size.x, 3), Palette.INK, 2)
	art.dither(Rect2i(b.end.x, b.position.y + 3, 3, b.size.y), Palette.INK, 2)
	art.rect(Rect2i(b.position.x + 1, b.position.y, b.size.x - 2, b.size.y), Palette.INK)
	art.rect(Rect2i(b.position.x, b.position.y + 1, b.size.x, b.size.y - 2), Palette.INK)
	var cover: Rect2i = b.grow(-1)
	art.rect(cover, Palette.TOMATO_DARK)
	art.rect(Rect2i(cover.position, Vector2i(cover.size.x, 1)), Palette.TOMATO)
	art.rect(Rect2i(cover.position, Vector2i(1, cover.size.y)), Palette.TOMATO)
	art.rect(Rect2i(cover.position.x, cover.end.y - 1, cover.size.x, 1), Palette.TOMATO_DARKEST)
	art.rect(Rect2i(cover.end.x - 1, cover.position.y, 1, cover.size.y), Palette.TOMATO_DARKEST)
	var stitch: Rect2i = b.grow(-3)
	for x: int in range(stitch.position.x + 2, stitch.end.x - 2, 4):
		art.rect(Rect2i(x, stitch.position.y, 2, 1), Palette.TOMATO_LIGHT)
		art.rect(Rect2i(x, stitch.end.y - 1, 2, 1), Palette.TOMATO_LIGHT)
	for y: int in range(stitch.position.y + 2, stitch.end.y - 2, 4):
		art.rect(Rect2i(stitch.position.x, y, 1, 2), Palette.TOMATO_LIGHT)
		art.rect(Rect2i(stitch.end.x - 1, y, 1, 2), Palette.TOMATO_LIGHT)


## One page of sleeves: the page stack's edges on its outer side, the slate backing and its
## pockets (an outline lit along the top, each pocket's open lip).
static func _paint_page(art: StorefrontArt, page: Rect2i) -> void:
	var outer_left: bool = page.position.x < SPINE_RECT.position.x
	for step: int in 3:
		var edge_x: int = page.position.x - 1 - step if outer_left else page.end.x + step
		art.rect(
			Rect2i(edge_x, page.position.y + 1 + step, 1, page.size.y - 2 - step * 2),
			Palette.SLATE if step % 2 == 0 else Palette.INK
		)
	art.rect(page, Palette.INK)
	var inner: Rect2i = page.grow(-1)
	art.rect(inner, Palette.SLATE_DARK)
	art.rect(Rect2i(inner.position, Vector2i(inner.size.x, 1)), Palette.SLATE)
	for slot: int in COLUMNS * ROWS:
		var side: int = 0 if outer_left else 1
		var at: Vector2i = pocket_origin(side, slot)
		var pocket: Rect2i = Rect2i(at, POCKET_SIZE)
		art.rect(pocket, Palette.TEAL_SHADE)
		art.rect(pocket.grow(-1), Palette.TEAL_BLACK)
		art.dither(pocket.grow(-1), Palette.SLATE, 1)
		art.rect(Rect2i(at.x + 1, at.y + 1, POCKET_SIZE.x - 2, 1), Palette.TEAL_DARK)
		art.rect(Rect2i(at.x + 6, at.y, POCKET_SIZE.x - 12, 1), Palette.TEAL_PALE)


## The spine: a dark gutter between the pages and the three steel rings over it.
static func _paint_spine(art: StorefrontArt) -> void:
	var s: Rect2i = SPINE_RECT
	art.rect(Rect2i(s.position.x, s.position.y + 4, s.size.x, s.size.y - 8), Palette.INK)
	art.rect(Rect2i(s.position.x + 3, s.position.y + 4, 2, s.size.y - 8), Palette.TOMATO_DARKEST)
	for top: int in RING_TOPS:
		var x0: int = s.position.x - 6
		art.rect(Rect2i(x0 + 1, top, 18, 8), Palette.INK)
		art.rect(Rect2i(x0, top + 1, 20, 6), Palette.INK)
		art.rect(Rect2i(x0 + 1, top + 1, 18, 6), Palette.STEEL_DARK)
		art.rect(Rect2i(x0 + 2, top + 1, 16, 1), Palette.STEEL_PALE)
		art.rect(Rect2i(x0 + 1, top + 2, 18, 2), Palette.STEEL)
		art.rect(Rect2i(x0 + 2, top + 6, 16, 1), Palette.STEEL_DARKEST)
		art.rect(Rect2i(x0 + 4, top + 3, 12, 2), Palette.INK)
