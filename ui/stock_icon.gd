class_name StockIcon
extends Control
## One item of the Run info's MACHINE STOCK (the slim Run info, mock-up
## docs/art/mockups/cart_cards.html's RUN INFO · SLIM, approved by the user on 2026-11-13): the
## item's sprite at 1x (a coupon's slip at 2x) over its price (a coupon: COUPON, "◆ RARE" with a
## pixel diamond, or LEGENDARY, machine.tres's rarity), and a badge on its top left when the cart
## holds copies of it (Badge: "×N", teal with a diamond when one is BIG, gold with a star when one
## is GOLDEN). Hovering it (the pointer on it) rings it mustard; DeckView opens the tip with its
## card face. `dimmed` fades it (the family filter: not of the previewed family).
## Every pixel mark and sprite stands on an even layout px (crisp at 1280x720 and at 1920x1080's
## 1.5 scale, where an even px is a whole screen px): the marks' pixels are 2 layout px (3 screen
## px at 1080p).

signal hovered(icon: StockIcon)
signal unhovered(icon: StockIcon)

const SIZE := Vector2(60, 76)
const SPRITE_AT := Vector2(6, 2)
const SPRITE_SIZE := Vector2(48, 48)
## A coupon's slip: 2x, centred in the sprite's box (on an even px).
const COUPON_SCALE := 2.0
const PRICE_TOP := 52.0
const PRICE_SIZE := 15
const COUPON_WORD_SIZE := 11
const COUPON_WORD_MIN := 9
const COUPON_WORD_WEIGHT := 800
const COUPON_WORDS: Array[String] = ["COUPON", "RARE", "LEGENDARY"]
## The RARE coupon word's pixel diamond (the mock-up's "◆ RARE"; a 3-row one read as a "+"): its
## rows, DIAMOND_PIXEL px a cell (2: whole screen px at 1x and 1.5x; a 1 px cell was 1.5 screen
## px at 1080p and blurred), and its gap before the word.
const RARE_DIAMOND: Array[String] = ["..#..", ".###.", "#####", ".###.", "..#.."]
const DIAMOND_PIXEL := 2.0
const DIAMOND_GAP := 2.0
## The coupon word's widest (px): the old 58 px icon less a margin, so LEGENDARY (the mock-up's
## 9.5 px) keeps clear of its neighbour's "◆ RARE".
const COUPON_WORD_WIDTH := 56.0
const HOVER_FILL := Color("2f5552")
const HOVER_LINE := 2.0
const DIM_ALPHA := 0.3
const BADGE_AT := Vector2(-4, -4)
## Node names (for tests).
const PRICE := "Price"
const BADGE := "InCart"

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


## The icon of `definition` (a stocked card), its look from `machine`, with `copies` copies in
## the cart, the highest of them `tier`.
func _init(
	definition: CardDefinition,
	machine: MachineDefinition,
	copies: int,
	tier: CardDefinition.Tier = CardDefinition.Tier.PLAIN
) -> void:
	card = definition
	in_cart = copies
	cart_tier = tier
	look = CartCardDraw.look_of(definition, machine)
	name = "Stock%s" % String(definition.id).to_pascal_case()
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SIZE
	custom_minimum_size = SIZE
	var art: TextureRect
	if definition.is_coupon():
		art = UiKit.sprite(ArtStyle.coupon_icon(definition))
		var shown: Vector2 = (
			art.texture.get_size() * COUPON_SCALE if art.texture != null else Vector2()
		)
		art.size = shown
		art.position = SPRITE_AT + even_floor((SPRITE_SIZE - shown) / 2.0)
	else:
		art = UiKit.sprite(ArtStyle.item_sprite(definition))
		art.size = SPRITE_SIZE
		art.position = SPRITE_AT
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	if definition.is_coupon():
		var word: String = COUPON_WORDS[look]
		_price = UiKit.body_label(word, coupon_word_size(word), _coupon_ink())
		_price.add_theme_font_override("font", ArtStyle.bold_font(COUPON_WORD_WEIGHT))
		_price.add_theme_constant_override("line_spacing", 0)
	else:
		_price = UiKit.number_label(PriceSticker.price_text(definition.base), PRICE_SIZE, true)
	_price.name = PRICE
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price.position = Vector2(-4, PRICE_TOP)
	_price.size = Vector2(SIZE.x + 8, SIZE.y - PRICE_TOP)
	if look == BoosterArt.Look.RARE and definition.is_coupon():
		# The word moves right by half the diamond's room; the diamond stands before it.
		_price.position.x += _diamond_room() / 2.0
	add_child(_price)
	if copies > 0:
		_badge = Badge.new(copies, tier)
		_badge.name = BADGE
		_badge.position = BADGE_AT
		add_child(_badge)


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
	var at: Vector2 = even_floor(
		Vector2(
			word_left - DIAMOND_GAP - side,
			_price.position.y + font.get_ascent(text_size) - text_size * 0.35 - side / 2.0
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
	if lit:
		var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
		draw_rect(rect, HOVER_FILL)
		draw_rect(rect.grow(-HOVER_LINE / 2.0), Palette.MUSTARD, false, HOVER_LINE)
	for cell: Rect2 in diamond_pixels():
		draw_rect(cell, _coupon_ink())


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
