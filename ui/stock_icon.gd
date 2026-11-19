class_name StockIcon
extends Control
## One sleeve of the deck view's STOCK BOOK (StockBook, 2026-11-19; it was the Run info's MACHINE
## STOCK icon): a stocked item. When the cart holds it, a cream insert in its section's light
## colour with the item's sprite at the game's 2x (a coupon's slip at 4x), its price on a mustard
## sticker (a coupon: COUPON, "◆ RARE" with a pixel diamond, or LEGENDARY, machine.tres's rarity,
## on an ink plate) and a badge on its top left (Badge: "×N", teal with a diamond when one is BIG,
## gold with a star when one is GOLDEN). Not owned yet: the sprite as a dark silhouette on the
## empty sleeve (the handbook's locked coupons' tint) over its price or rarity. Hovering it rings
## it mustard; DeckView opens the tip with its card face. `dimmed` fades it (the family filter: not
## of the picked family). Every pixel mark and sprite stands on an even layout px (crisp at
## 1280x720 and at 1920x1080's 1.5 scale).

signal hovered(icon: StockIcon)
signal unhovered(icon: StockIcon)

## The sleeve's inside (StockBook.pocket_rect's size), the insert's inset, the sprite's box.
const SIZE := Vector2(172, 168)
const INSERT_INSET := 4.0
const SPRITE_AT := Vector2(38, 14)
const SPRITE_SIZE := Vector2(96, 96)
## A coupon's slip: 4x, centred in the sprite's box (on an even px).
const COUPON_SCALE := 4.0
const PRICE_TOP := 118.0
const PRICE_HEIGHT := 30.0
const PRICE_SIZE := 18
const STICKER_PAD := 8.0
const COUPON_WORD_SIZE := 13
const COUPON_WORD_MIN := 10
const COUPON_WORD_WEIGHT := 800
const COUPON_WORDS: Array[String] = ["COUPON", "RARE", "LEGENDARY"]
## The RARE coupon word's pixel diamond (the mock-up's "◆ RARE"; a 3-row one read as a "+"): its
## rows, DIAMOND_PIXEL px a cell (2: whole screen px at 1x and 1.5x), and its gap before the word.
const RARE_DIAMOND: Array[String] = ["..#..", ".###.", "#####", ".###.", "..#.."]
const DIAMOND_PIXEL := 2.0
const DIAMOND_GAP := 4.0
## The coupon word's widest (px).
const COUPON_WORD_WIDTH := 120.0
## The silhouette of an item not owned yet (HandbookPage.LOCKED_TINT's).
const SILHOUETTE := Color(0.12, 0.12, 0.16)
## The insert's light top (px) and its dithered fade's rows (2 px each) under it.
const INSERT_LIGHT := 56.0
const INSERT_FADE_ROWS := 12
const HOVER_LINE := 4.0
const DIM_ALPHA := 0.3
const BADGE_AT := Vector2(8, 8)
## Node names (for tests).
const PRICE := "Price"
const BADGE := "InCart"
const ART_NAME := "Art"

var card: CardDefinition
## Copies of it in the cart, and the highest tier among them.
var in_cart: int = 0
var cart_tier: CardDefinition.Tier = CardDefinition.Tier.PLAIN
var look: BoosterArt.Look = BoosterArt.Look.COMMON
var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()
var dimmed: bool = false:
	set(value):
		dimmed = value
		modulate.a = DIM_ALPHA if value else 1.0
var _price: Label
var _badge: Badge
var _art: TextureRect
var _light: Color = Palette.CREAM_SHADE


## The slot of `definition` (a stocked card), its look from `machine`, with `copies` copies in
## the cart, the highest of them `tier`; its insert lit in `light` (its section's light colour).
func _init(
	definition: CardDefinition,
	machine: MachineDefinition,
	copies: int,
	tier: CardDefinition.Tier = CardDefinition.Tier.PLAIN,
	light: Color = Palette.CREAM_SHADE
) -> void:
	card = definition
	in_cart = copies
	cart_tier = tier
	_light = light
	look = CartCardDraw.look_of(definition, machine)
	name = "Stock%s" % String(definition.id).to_pascal_case()
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SIZE
	custom_minimum_size = SIZE
	if definition.is_coupon():
		_art = UiKit.sprite(ArtStyle.coupon_icon(definition))
		var shown: Vector2 = (
			_art.texture.get_size() * COUPON_SCALE if _art.texture != null else Vector2()
		)
		_art.size = shown
		_art.position = SPRITE_AT + even_floor((SPRITE_SIZE - shown) / 2.0)
	else:
		_art = UiKit.sprite(ArtStyle.item_sprite(definition))
		_art.size = SPRITE_SIZE
		_art.position = SPRITE_AT
	_art.name = ART_NAME
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if copies <= 0:
		_art.modulate = SILHOUETTE
	add_child(_art)
	if definition.is_coupon():
		var word: String = COUPON_WORDS[look]
		_price = UiKit.body_label(word, coupon_word_size(word), _coupon_ink())
		_price.add_theme_font_override("font", ArtStyle.bold_font(COUPON_WORD_WEIGHT))
		_price.add_theme_constant_override("line_spacing", 0)
	else:
		var ink: Color = Palette.INK if copies > 0 else Palette.TEAL_PALE
		_price = UiKit.number_label(PriceSticker.price_text(definition.base), PRICE_SIZE, false)
		_price.add_theme_color_override("font_color", ink)
	_price.name = PRICE
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price.position = Vector2(0, PRICE_TOP)
	_price.size = Vector2(SIZE.x, PRICE_HEIGHT)
	if look == BoosterArt.Look.RARE and definition.is_coupon():
		# The word moves right by half the diamond's room; the diamond stands before it.
		_price.position.x += _diamond_room() / 2.0
	add_child(_price)
	if copies > 0:
		_badge = Badge.new(copies, tier)
		_badge.name = BADGE
		_badge.position = BADGE_AT
		add_child(_badge)


## Whether the cart holds it (its sprite filled, not a silhouette).
func owned() -> bool:
	return in_cart > 0


## The sprite (for tests).
func art() -> TextureRect:
	return _art


## The coupon word's size: COUPON_WORD_SIZE, smaller (down to COUPON_WORD_MIN) while `word` is
## wider than COUPON_WORD_WIDTH (LEGENDARY).
static func coupon_word_size(word: String) -> int:
	var font: Font = ArtStyle.bold_font(COUPON_WORD_WEIGHT)
	var text_size: int = COUPON_WORD_SIZE
	while (
		text_size > COUPON_WORD_MIN
		and (
			font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
			> COUPON_WORD_WIDTH
		)
	):
		text_size -= 1
	return text_size


## `at` floored to even px (whole screen px at 1x and 1.5x).
static func even_floor(at: Vector2) -> Vector2:
	return (at / 2.0).floor() * 2.0


## The RARE word's diamond rect (empty for any other icon), in this icon's coordinates, on even px.
func diamond_rect() -> Rect2:
	if look != BoosterArt.Look.RARE or not card.is_coupon():
		return Rect2()
	var font: Font = ArtStyle.bold_font(COUPON_WORD_WEIGHT)
	var text_size: int = _price.get_theme_font_size("font_size")
	var word: float = font.get_string_size(_price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var side: float = RARE_DIAMOND.size() * DIAMOND_PIXEL
	var word_left: float = _price.position.x + (_price.size.x - word) / 2.0
	# Centred on the capitals (about 0.7 of the size tall, standing on the baseline).
	var text_top: float = (
		_price.position.y
		+ (_price.size.y - font.get_ascent(text_size) - font.get_descent(text_size)) / 2.0
	)
	var at: Vector2 = even_floor(
		Vector2(
			word_left - DIAMOND_GAP - side,
			text_top + font.get_ascent(text_size) - text_size * 0.35 - side / 2.0
		)
	)
	return Rect2(at, Vector2(side, side))


## The RARE word's diamond's pixel cells (none for any other icon), in this icon's coordinates.
func diamond_pixels() -> Array[Rect2]:
	var diamond: Rect2 = diamond_rect()
	if not diamond.has_area():
		return []
	return Badge.cells(RARE_DIAMOND, diamond.position, DIAMOND_PIXEL)


static func _diamond_room() -> float:
	return RARE_DIAMOND.size() * DIAMOND_PIXEL + DIAMOND_GAP


func price_label() -> Label:
	return _price


## The in-cart badge, or null when the cart holds none.
func badge() -> Badge:
	return _badge


func _coupon_ink() -> Color:
	match look:
		BoosterArt.Look.RARE:
			return Palette.TEAL_LIGHT
		BoosterArt.Look.LEGENDARY:
			return Palette.GOLD
	return Palette.TEAL_PALE


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hovered.emit(self)
	elif what == NOTIFICATION_MOUSE_EXIT:
		unhovered.emit(self)


func _draw() -> void:
	if owned():
		_draw_insert()
	if owned() or card.is_coupon():
		_draw_sticker()
	for cell: Rect2 in diamond_pixels():
		draw_rect(cell, _coupon_ink())
	if lit:
		var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
		draw_rect(rect.grow(-HOVER_LINE / 2.0), Palette.MUSTARD, false, HOVER_LINE)


## The cream insert (2 px art pixels): an ink rim, its light colour at the top fading to cream.
func _draw_insert() -> void:
	var outer: Rect2 = Rect2(Vector2.ZERO, SIZE).grow(-INSERT_INSET)
	draw_rect(outer.grow_individual(-2, 0, -2, 0), Palette.INK)
	draw_rect(outer.grow_individual(0, -2, 0, -2), Palette.INK)
	var inner: Rect2 = outer.grow(-2)
	draw_rect(inner, Palette.CREAM)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, INSERT_LIGHT)), _light)
	for row: int in range(INSERT_FADE_ROWS):
		for x: int in range((row % 2) * 2, int(inner.size.x), 4):
			var at: Vector2 = inner.position + Vector2(x, INSERT_LIGHT + row * 2)
			draw_rect(Rect2(at, Vector2(2, 2)), _light)
	draw_rect(Rect2(inner.position.x, inner.end.y - 2, inner.size.x, 2), Palette.CREAM_SHADE)


## The price's mustard sticker, or a coupon's ink plate, as wide as its words (on even px).
func _draw_sticker() -> void:
	var font: Font = _price.get_theme_font("font")
	var text_size: int = _price.get_theme_font_size("font_size")
	var words: float = font.get_string_size(_price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var width: float = ceilf((words + STICKER_PAD * 2.0) / 2.0) * 2.0
	if look == BoosterArt.Look.RARE and card.is_coupon():
		width += ceilf(_diamond_room() / 2.0) * 2.0
	var at: Vector2 = even_floor(Vector2((SIZE.x - width) / 2.0, PRICE_TOP))
	var sticker: Rect2 = Rect2(at, Vector2(width, PRICE_HEIGHT))
	var coupon: bool = card.is_coupon()
	draw_rect(sticker.grow_individual(-2, 0, -2, 0), Palette.INK)
	draw_rect(sticker.grow_individual(0, -2, 0, -2), Palette.INK)
	var face: Rect2 = sticker.grow(-2)
	draw_rect(face, Palette.TEAL_BLACK if coupon else Palette.MUSTARD_LIGHT)
	var foot: Color = Palette.TEAL_DARK if coupon else Palette.MUSTARD
	draw_rect(Rect2(face.position.x, face.end.y - 2, face.size.x, 2), foot)


## The in-cart badge: "×N" in the number font on green, teal with a pixel diamond after it when a
## copy is BIG, gold with a pixel star when one is GOLDEN, in an ink box. Its width and its
## marks' cells are on even px (crisp at 1.5x), the mark inside the ink border.
class Badge:
	extends Control

	const HEIGHT := 18.0
	const TEXT_SIZE := 12
	const PAD := 4.0
	const MARK_GAP := 2.0
	## The marks' pixels (2 px each), rows top to bottom: a 7-row diamond (a 5-row one read as a
	## "+") and a 5-row star.
	const DIAMOND: Array[String] = [
		"...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."
	]
	const STAR: Array[String] = ["..#..", "#####", ".###.", ".#.#.", "#...#"]
	const PIXEL := 2.0

	var count: int = 0
	var tier: CardDefinition.Tier = CardDefinition.Tier.PLAIN
	var _text: String = ""

	func _init(copies: int, highest: CardDefinition.Tier) -> void:
		count = copies
		tier = highest
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_text = "×%d" % copies
		var font: Font = ArtStyle.number_font()
		var width: float = ceilf(
			font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		)
		width += PAD * 2.0
		if tier != CardDefinition.Tier.PLAIN:
			width += MARK_GAP + _mark()[0].length() * PIXEL
		size = Vector2(ceilf(width / 2.0) * 2.0, HEIGHT)
		custom_minimum_size = size

	## The fill: green, teal for a BIG copy, gold for a GOLDEN one.
	func fill() -> Color:
		match tier:
			CardDefinition.Tier.BIG:
				return Palette.TEAL
			CardDefinition.Tier.GOLDEN:
				return Palette.GOLD
		return Palette.GREEN_DARK

	func text() -> String:
		return _text

	func _ink() -> Color:
		return Palette.INK if tier == CardDefinition.Tier.GOLDEN else Palette.PAPER

	func _mark() -> Array[String]:
		return STAR if tier == CardDefinition.Tier.GOLDEN else DIAMOND

	## The mark's pixel cells (none on a plain badge), in this badge's coordinates.
	func mark_rects() -> Array[Rect2]:
		if tier == CardDefinition.Tier.PLAIN:
			return []
		var rows: Array[String] = _mark()
		var at: Vector2 = StockIcon.even_floor(
			Vector2(size.x - PAD - rows[0].length() * PIXEL, (HEIGHT - rows.size() * PIXEL) / 2.0)
		)
		return cells(rows, at, PIXEL)

	## The cells of `rows`' "#"s, `pixel` px each, from `at`.
	static func cells(rows: Array[String], at: Vector2, pixel: float) -> Array[Rect2]:
		var result: Array[Rect2] = []
		for row: int in rows.size():
			for column: int in rows[row].length():
				if rows[row][column] == "#":
					result.append(Rect2(at + Vector2(column, row) * pixel, Vector2.ONE * pixel))
		return result

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), fill())
		var font: Font = ArtStyle.number_font()
		var ascent: float = font.get_ascent(TEXT_SIZE)
		var text_height: float = ascent + font.get_descent(TEXT_SIZE)
		var baseline: float = roundf((HEIGHT - text_height) / 2.0 + ascent)
		draw_string(
			font, Vector2(PAD, baseline), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, _ink()
		)
		for cell: Rect2 in mark_rects():
			draw_rect(cell, _ink())
