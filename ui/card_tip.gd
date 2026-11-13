class_name CardTip
extends Control
## The deck view's hover tip (the cart as cards, mock-up docs/art/mockups/cart_cards.html's
## cardTip, showTip and kwBox: hover_tips.html's variant B, the paper card; approved by the user
## on 2026-11-13, "perfect with your recommended"): a paper card (the pin_card 9-slice, its hard ink
## drop shadow) whose header band takes the card's rarity colour (cream, a coupon's cream shade,
## RARE teal, LEGENDARY gold) with the item's icon in a paper box, its name and its rarity tag
## ("RARE · BIG", "LEGENDARY COUPON"). A Cart card's tip (show_card) says what its colour means
## ("Works with Breakfast", the family as its chip) over a dotted line, then only what the face
## does not show (the user, 2026-11-14: no price or rule repeated): the full rule when the face cut
## it short, "Counts as" its families and, for a START item, where it came from. A stock icon's tip
## (show_stock) is narrower and shows the card face, the colour's meaning and the families, then
## "In your cart: N" or "Not in your cart". Each keyword of the rule
## gets its own KEYWORD box (mustard band, the keyword family's glyph, GlyphText.keyword_tip),
## stacked on the main card's far side. place_beside opens it beside the item (right, else left),
## inside the stage, the tail at the item's middle. Display only: it takes no clicks.

enum Placement { RIGHT, LEFT }

const WIDTH := 262.0
const FACE_WIDTH := 196.0
## A keyword box is wider than the mock-up's 200 px: its title prints at the item name's size.
const KEYWORD_WIDTH := 224.0
## The gap between the item and the tip, between the tip and its keyword boxes (and between
## them), and the stage's margin.
const GAP := 12.0
const KEYWORD_GAP := 6.0
const MARGIN := 8.0
const PRODUCT_TAGS: Array[String] = ["COMMON", "RARE · BIG", "LEGENDARY · GOLDEN"]
const COUPON_TAGS: Array[String] = ["COUPON", "RARE COUPON", "LEGENDARY COUPON"]
const KEYWORD_TAG := "KEYWORD"
const COUNTS_AS := "Counts as %s"
const START_TEXT := "START: %s"
const IN_CART := "In your cart: %d"
const NOT_IN_CART := "Not in your cart"
const PLAIN_COUPON := "Plain coupon: works with whatever is beside it"

var side: Placement = Placement.RIGHT
var _main: TipCard
var _keywords: Array[TipCard] = []
var _face: DeckCell


func _init() -> void:
	name = "CardTip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The tip of a Cart card: only what its face does not show (the user, 2026-11-14: no price or
## rule repeated under the card): its colour's meaning, its full rule when the face cut it short
## (`rule_cut`), the families it counts as, where a START item came from (`start_source`, "" for
## none), and its keywords' boxes. `machine` gives a coupon's rarity.
func show_card(
	card: CardDefinition, machine: MachineDefinition, start_source: String, rule_cut := false
) -> void:
	_clear()
	_main = _card_box(card, machine, WIDTH)
	var meaning: String = works_with(card)
	if not meaning.is_empty():
		_main.add_text(meaning, TipCard.Style.WHY)
	var rule: String = DeckCell.rule_line(card)
	if rule_cut and not rule.is_empty():
		_main.add_text(rule, TipCard.Style.BODY)
	var families: String = counts_as(card)
	if not families.is_empty():
		_main.add_text(families, TipCard.Style.COND)
	if not start_source.is_empty():
		_main.add_text(START_TEXT % start_source, TipCard.Style.COND)
	_add_keywords(card)


## The tip of a stock icon: the card face, its colour's meaning, its families, then
## whether the cart holds it (`in_cart` copies), and its keywords' boxes.
func show_stock(card: CardDefinition, machine: MachineDefinition, in_cart: int) -> void:
	_clear()
	_main = _card_box(card, machine, FACE_WIDTH)
	_face = DeckCell.new(CardInstance.new(card, 0), machine, 1)
	_main.add_face(_face)
	var meaning: String = works_with(card)
	if not meaning.is_empty():
		_main.add_text(meaning, TipCard.Style.WHY)
	var families: String = counts_as(card)
	if not families.is_empty():
		_main.add_text(families, TipCard.Style.BODY)
	_main.add_text(IN_CART % in_cart if in_cart > 0 else NOT_IN_CART, TipCard.Style.COND)
	_add_keywords(card)


## What `card`'s colour means, capitalised ("Works with Breakfast"); a plain coupon's line; "" for
## none.
static func works_with(card: CardDefinition) -> String:
	var meaning: String = FamilyPalette.shared().colour_meaning(card)
	if meaning.is_empty():
		return PLAIN_COUPON if card.is_coupon() else ""
	return meaning.left(1).to_upper() + meaning.substr(1)


## The families `card` counts as ("Counts as Dairy Breakfast"); "" for a coupon or none.
static func counts_as(card: CardDefinition) -> String:
	if not card.is_product():
		return ""
	var families: PackedStringArray = FamilyPalette.shared().shelf_families(card.tags)
	return COUNTS_AS % " ".join(families) if not families.is_empty() else ""


## The rarity tag `card` wears in its tip's header.
static func tag_of(card: CardDefinition, machine: MachineDefinition) -> String:
	var look: BoosterArt.Look = CartCardDraw.look_of(card, machine)
	return COUPON_TAGS[look] if card.is_coupon() else PRODUCT_TAGS[look]


## Opens the tip beside `item` (in this tip's parent's coordinates) inside `stage`: right of it
## when the tip and its keyword boxes fit there, else left, else right clamped to the stage; its
## middle level with the item's, the keyword boxes on the far side, the tail at the item.
func place_beside(item: Rect2, stage: Rect2) -> void:
	if _main == null:
		return
	position = Vector2.ZERO
	var main_size: Vector2 = _main.size
	var column: Vector2 = _column_size()
	var beside: float = column.x + KEYWORD_GAP if column.x > 0.0 else 0.0
	var x: float = item.end.x + GAP
	side = Placement.RIGHT
	if x + main_size.x + beside > stage.end.x - MARGIN:
		side = Placement.LEFT
		x = item.position.x - GAP - main_size.x
		if x - beside < stage.position.x + MARGIN:
			side = Placement.RIGHT
			x = clampf(
				item.end.x + GAP,
				stage.position.x + MARGIN,
				stage.end.x - MARGIN - main_size.x - beside
			)
	var y: float = clampf(
		item.get_center().y - main_size.y / 2.0,
		stage.position.y + MARGIN,
		stage.end.y - MARGIN - main_size.y
	)
	# On even px (whole screen px at 1920x1080's 1.5 scale: the icon and the face stay crisp),
	# rounded away from the item.
	x = ceilf(x / 2.0) * 2.0 if side == Placement.RIGHT else floorf(x / 2.0) * 2.0
	y = floorf(y / 2.0) * 2.0
	_main.position = Vector2(x, y)
	_main.point_tail(
		TipCard.TAIL_LEFT if side == Placement.RIGHT else TipCard.TAIL_RIGHT,
		item.get_center().y - _main.position.y
	)
	var column_x: float = x + main_size.x + KEYWORD_GAP if side == Placement.RIGHT else x - beside
	var column_y: float = clampf(
		y, stage.position.y + MARGIN, maxf(stage.position.y, stage.end.y - MARGIN - column.y)
	)
	for box: TipCard in _keywords:
		box.position = StockIcon.even_floor(Vector2(column_x, column_y))
		column_y += box.size.y + KEYWORD_GAP


## The main card and the keyword boxes (for tests).
func main_card() -> TipCard:
	return _main


func keyword_cards() -> Array[TipCard]:
	return _keywords


## The stock tip's card face, or null.
func face() -> DeckCell:
	return _face


## Every card's global rect, the main card's first.
func card_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if _main != null:
		rects.append(_main.get_global_rect())
	for box: TipCard in _keywords:
		rects.append(box.get_global_rect())
	return rects


## The main card's lines' texts, in order (under the header).
func lines() -> Array[String]:
	var found: Array[String] = []
	if _main != null:
		found = _main.texts()
	return found


func _card_box(card: CardDefinition, machine: MachineDefinition, width: float) -> TipCard:
	var look: BoosterArt.Look = CartCardDraw.look_of(card, machine)
	var band: Color = Palette.CREAM_SHADE if card.is_coupon() else Palette.CREAM
	var ink: Color = Palette.INK
	if look == BoosterArt.Look.RARE:
		band = Palette.TEAL
		ink = Palette.PAPER
	elif look == BoosterArt.Look.LEGENDARY:
		band = Palette.GOLD
	var icon: Texture2D = (
		ArtStyle.coupon_icon(card) if card.is_coupon() else ArtStyle.item_sprite(card)
	)
	var box: TipCard = TipCard.new(width, band, ink, icon, card.display_name, tag_of(card, machine))
	box.name = "Main"
	add_child(box)
	return box


## A KEYWORD box for each keyword of `card`'s rule, in order, once each.
func _add_keywords(card: CardDefinition) -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var seen: PackedStringArray = PackedStringArray()
	for keyword: String in GlyphText.keywords(DeckCell.rule_line(card), palette):
		if seen.has(keyword):
			continue
		seen.append(keyword)
		var family: FamilyStyle = palette.style(str(KeywordChip.KEYWORD_FAMILIES.get(keyword, "")))
		var box: TipCard = TipCard.new(
			KEYWORD_WIDTH,
			Palette.MUSTARD,
			Palette.INK,
			family.glyph if family != null else null,
			keyword,
			KEYWORD_TAG
		)
		box.name = "Keyword%s" % keyword.capitalize()
		add_child(box)
		box.add_text(GlyphText.keyword_tip(keyword), TipCard.Style.SUB)
		_keywords.append(box)
	propagate_call(&"set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])


## The keyword boxes' column: its width and its height (gaps included); zero without one.
func _column_size() -> Vector2:
	var height: float = 0.0
	var width: float = 0.0
	for box: TipCard in _keywords:
		height += box.size.y + (KEYWORD_GAP if height > 0.0 else 0.0)
		width = maxf(width, box.size.x)
	return Vector2(width, height)


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_main = null
	_keywords.clear()
	_face = null


## One paper card of the tip: the header band (its colour, the icon in a paper box, the title and
## the tag), then lines of text (GlyphLabels: keywords and families as chips) and an optional card
## face; a dotted line under the colour's meaning; the tail on a side edge (point_tail).
class TipCard:
	extends Control

	enum Style { BODY, WHY, COND, SUB }

	const TAIL_NONE := 0
	const TAIL_LEFT := 1
	const TAIL_RIGHT := 2
	const FRAME := preload("res://art/frames/pin_card.png")
	const FRAME_MARGIN := 3
	const TAIL := preload("res://art/frames/pin_card_tail.png")
	const TAIL_SIZE := Vector2(14, 8)
	const TAIL_OVERLAP := 2.0
	## The tail keeps this far from the card's top and foot.
	const TAIL_INSET := 14.0
	const BORDER := 6.0
	const HEAD_PAD := Vector2(5, 4)
	const ICON := 28.0
	const ICON_INNER := 24.0
	const ICON_GAP := 7.0
	const HEAD_LINE := 2.0
	const TAG_SIZE := 10
	const TAG_WEIGHT := 800
	const TAG_PAD := Vector2(4, 2)
	const TAG_ALPHA := 0.16
	## The gap between the title and the tag, and the title's least room beside the tag (else the
	## tag drops under it).
	const TAG_GAP := 6.0
	const TITLE_ROOM_MIN := 96.0
	## The body's padding (sides, top and foot), the gap between lines and around a dotted line.
	const PAD := Vector2(9, 6)
	const LINE_GAP := 4.0
	const DOT_GAP := 4.0
	const FACE_TOP := 8.0
	const FACE_FOOT := 6.0
	const SHADOW_OFFSET := Vector2(0, 6)
	const SHADOW_ALPHA := 0.5
	## Each style's text size, weight, colour and leading (line pitch over size).
	const SIZES: Array[int] = [14, 13, 13, 13]
	const WEIGHTS: Array[int] = [600, 600, 700, 600]
	const COLOURS: Array[Color] = [Palette.INK, Palette.INK_LIGHT, Palette.GREY_DARK, Palette.INK]
	const LEADING := 1.36

	var band: Color
	var ink: Color
	var tail_edge: int = TAIL_NONE
	var tail_y: float = 0.0
	var _y: float = 0.0
	var _dots: Array[float] = []
	var _icon_rect: Rect2 = Rect2()
	var _tag_rect: Rect2 = Rect2()
	var _head_height: float = 0.0
	var _title: Control
	var _tag: Label
	var _texts: Array[GlyphLabel] = []

	func _init(
		width: float,
		band_colour: Color,
		ink_colour: Color,
		icon: Texture2D,
		heading: String,
		tag_words: String
	) -> void:
		band = band_colour
		ink = ink_colour
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		ArtStyle.use_pixel_material(self)
		var head_top: float = BORDER + HEAD_PAD.y
		var x: float = BORDER + HEAD_PAD.x
		if icon != null:
			_icon_rect = Rect2(x, head_top, ICON, ICON)
			var sprite: TextureRect = UiKit.sprite(icon)
			sprite.name = "Icon"
			var shown: Vector2 = icon.get_size()
			if shown.x > ICON_INNER or shown.y > ICON_INNER:
				shown *= ICON_INNER / maxf(shown.x, shown.y)
			sprite.size = shown
			sprite.position = StockIcon.even_floor(_icon_rect.get_center() - shown / 2.0)
			add_child(sprite)
			x += ICON + ICON_GAP
		_tag = UiKit.body_label(tag_words, TAG_SIZE, ink)
		_tag.name = "Tag"
		var tag_font: Font = ArtStyle.bold_font(TAG_WEIGHT)
		_tag.add_theme_font_override("font", tag_font)
		_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_tag)
		# Measured with its font: out of the tree a Label measures at the default size.
		var tag_size: Vector2 = (
			Vector2(
				tag_font.get_string_size(tag_words, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x,
				tag_font.get_height(TAG_SIZE)
			)
			. ceil()
		)
		var tag_box: Vector2 = tag_size + TAG_PAD * 2.0
		var right: float = width - BORDER - HEAD_PAD.x
		var room: float = right - tag_box.x - TAG_GAP - x
		_head_height = ICON + HEAD_PAD.y * 2.0
		if room >= TITLE_ROOM_MIN:
			_tag_rect = Rect2(
				Vector2(right - tag_box.x, head_top + roundf((ICON - tag_box.y) / 2.0)), tag_box
			)
		else:
			# A long tag in a narrow tip (a stock tip's "LEGENDARY · GOLDEN") takes a row of its
			# own under the title, so the title keeps the header's width.
			room = right - x
			_tag_rect = Rect2(Vector2(x, head_top + ICON), tag_box)
			_head_height += tag_box.y
		_tag.position = _tag_rect.position + TAG_PAD
		_tag.size = tag_size
		_title = ItemName.make(heading, room, ICON, ink)
		_title.name = "Title"
		_title.position = Vector2(x, head_top)
		add_child(_title)
		_y = BORDER + _head_height + HEAD_LINE + PAD.y
		size = Vector2(width, 0.0)
		_fit()

	## Adds a line of `text` in `style` under the content so far (the colour's meaning gets a
	## dotted line under it).
	func add_text(text: String, style: Style) -> void:
		var text_size: int = SIZES[style]
		var label: GlyphLabel = GlyphLabel.new(
			text,
			ArtStyle.bold_font(WEIGHTS[style]),
			text_size,
			COLOURS[style],
			roundf(text_size * LEADING),
			size.x - 2.0 * (BORDER + PAD.x),
			0,
			false,
			null,
			true
		)
		label.name = "Line%d" % _texts.size()
		label.position = Vector2(BORDER + PAD.x, _y)
		add_child(label)
		_texts.append(label)
		_y += label.size.y
		if style == Style.WHY:
			_dots.append(_y + DOT_GAP)
			_y += DOT_GAP * 2.0 + 2.0
		else:
			_y += LINE_GAP
		_fit()

	## Adds `face` (a card face) centred under the content so far.
	func add_face(face: DeckCell) -> void:
		face.propagate_call(&"set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
		add_child(face)
		face.position = Vector2(
			roundf((size.x - face.size.x) / 2.0), _y + FACE_TOP + DeckCell.TOP_ROOM
		)
		_y = face.position.y + face.size.y + FACE_FOOT + LINE_GAP
		_fit()

	## Points the tail out of `edge` (TAIL_LEFT, TAIL_RIGHT) at `y` (this card's coordinates),
	## kept TAIL_INSET from its top and foot.
	func point_tail(edge: int, y: float) -> void:
		tail_edge = edge
		tail_y = clampf(y, TAIL_INSET, maxf(TAIL_INSET, size.y - TAIL_INSET))
		queue_redraw()

	## The tail's tip (the point at the item), in this card's coordinates.
	func tail_tip() -> Vector2:
		if tail_edge == TAIL_LEFT:
			return Vector2(TAIL_OVERLAP - TAIL_SIZE.y, tail_y)
		if tail_edge == TAIL_RIGHT:
			return Vector2(size.x + TAIL_SIZE.y - TAIL_OVERLAP, tail_y)
		return Vector2(-1, -1)

	func title_text() -> String:
		return ItemName.text_of(_title)

	func tag_text() -> String:
		return _tag.text

	## Whether the title shows whole in its room (a fallback Label is clipped when it doesn't).
	func title_fits() -> bool:
		var label: Label = _title as Label
		if label == null:
			return _title.get_combined_minimum_size().x <= _title.size.x + 0.5
		var font: Font = label.get_theme_font("font")
		var text_size: int = label.get_theme_font_size("font_size")
		return (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
			<= (label.size.x + 0.5)
		)

	func texts() -> Array[String]:
		var found: Array[String] = []
		for label: GlyphLabel in _texts:
			found.append(label.text)
		return found

	func text_labels() -> Array[GlyphLabel]:
		return _texts

	func band_rect() -> Rect2:
		return Rect2(BORDER, BORDER, size.x - 2.0 * BORDER, _head_height)

	func _fit() -> void:
		size = Vector2(size.x, ceilf(_y - LINE_GAP + PAD.y + BORDER))
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(SHADOW_OFFSET, size), Color(Palette.INK, SHADOW_ALPHA))
		draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), rect)
		var head: Rect2 = band_rect()
		draw_rect(head, band)
		draw_rect(Rect2(head.position.x, head.end.y, head.size.x, HEAD_LINE), Palette.INK)
		if _icon_rect.has_area():
			draw_rect(_icon_rect, Palette.INK)
			draw_rect(_icon_rect.grow(-2.0), Palette.PAPER)
		draw_rect(_tag_rect, Color(Palette.INK, TAG_ALPHA))
		for dot_y: float in _dots:
			var x: float = BORDER + PAD.x
			while x < size.x - BORDER - PAD.x:
				draw_rect(Rect2(x, dot_y, 2, 2), Palette.CREAM_SHADE)
				x += 4.0
		if tail_edge == TAIL_LEFT:
			draw_set_transform(
				Vector2(TAIL_OVERLAP - TAIL_SIZE.y, tail_y + TAIL_SIZE.x / 2.0), -PI / 2.0
			)
			draw_texture_rect(TAIL, Rect2(Vector2.ZERO, TAIL_SIZE), false)
			draw_set_transform(Vector2.ZERO)
		elif tail_edge == TAIL_RIGHT:
			draw_set_transform(
				Vector2(size.x + TAIL_SIZE.y - TAIL_OVERLAP, tail_y - TAIL_SIZE.x / 2.0), PI / 2.0
			)
			draw_texture_rect(TAIL, Rect2(Vector2.ZERO, TAIL_SIZE), false)
			draw_set_transform(Vector2.ZERO)
