class_name ScanPopup
extends Control
## The scan popup (#75; style frame v2's spec section 4.5; #105's readability pass, mock-up
## readability v3): what a scanned offer does, in full. A paper panel with a gold trim and a hard
## drop shadow: a header band in the colour of the card's ticket (FamilyPalette, data; a plain
## coupon keeps the paper) with its name (ItemName: Pixelify at 22 px, or the bold body font when
## too long) and its price "€N" (or COUPON); under a coloured header, the line that teaches the
## colour (a swatch of it and FamilyPalette.ticket_line, "Breakfast ticket: works with Breakfast",
## with the glyph of the family it names); a "Counts as" row of the family glyphs it counts as
## (FamilyPalette.shelf_families of its tags) and the card's long rule text verbatim. No aisle and
## no staple mark (the padlock is only on the cart reveal). Its glyphs' tooltips open above them
## (GlyphTips) where the pointer can reach them: over the offers, whose popup stays while the
## pointer is on it (ScanController); the Cart's and the machine's popups close as the pointer
## leaves their item, so there the words say it. It grows with its text up to MAX_HEIGHT. place() is
## the pure placement rule: it opens beside the item, over the offers' panel, its tail pointing
## sideways at the item. Since #80 the shift screen opens it for the offers only
## (ScanController.cover_offers): a belt or hand item's scan shows on the monitor (MonitorView),
## with its payout and step lines.

## Where the popup opened: right or left of the item.
enum Placement { RIGHT, LEFT }

const WIDTH := 288.0
const MIN_HEIGHT := 140.0
## The cap: the longest rule text with its header and tag line fits well within it.
const MAX_HEIGHT := 280.0
const PADDING := 12.0
const CONTENT_WIDTH := 264.0
## The stage's side margin.
const SIDE_MARGIN := 16.0
const FRAME_MARGIN := 4
## The popup opens SIDE_GAP beside the item's column (its sprite and sticker), its top level with
## the lifted sprite's and never above the panel's top; the tail spans the gap.
const SIDE_GAP := 8.0
const TAIL_SIZE := Vector2(10, 16)
## The tail's first art row covers the popup's outline.
const TAIL_OVERLAP := 2.0
const SHADOW_OFFSET := Vector2(4, 4)
const SHADOW_ALPHA := 0.3
const HEADER_HEIGHT := 28.0
## The header band (a coloured ticket's): inside the popup's outline, BAND_HEIGHT tall, its top
## BAND_EDGE px in the family's light colour and its foot BAND_EDGE px of ink; the content starts
## BAND_GAP under it.
const BAND_INSET := 2.0
const BAND_HEIGHT := 40.0
const BAND_EDGE := 2.0
const BAND_GAP := 6.0
const PRICE_SIZE := 18
const PRICE_GAP := 8.0
const COUPON_TITLE_SIZE := 14
## The "Counts as" row: its words (the body font at COUNTS_WEIGHT, COUNTS_SIZE px, grey dark) and
## the glyphs after them, COUNTS_GAP apart.
const COUNTS_HEIGHT := 22.0
const COUNTS_SIZE := 12
const COUNTS_WEIGHT := 700
const COUNTS_GAP := 4.0
const COUNTS_TEXT := "Counts as"
## The colour's line (#105, mock-up readability v3): the body font at LINE_WEIGHT, LINE_SIZE px, in
## ink, LINE_TOP under the band and LINE_GAP over the next row, wrapping; before it a swatch of the
## ticket's colour (SWATCH_SIZE, an ink ring SWATCH_RING wide, LINE_SWATCH_ROOM wide with its gap)
## and after its last line the glyph of the family it names (LINE_GLYPH_GAP before it).
const LINE_SIZE := 13
const LINE_WEIGHT := 700
## Its wrapped lines' spacing (the font's own line is loose for a two-line note).
const LINE_SPACING := -4
const LINE_TOP := 1.0
const LINE_GAP := 2.0
const SWATCH_SIZE := Vector2(14, 12)
const SWATCH_RING := 2.0
const LINE_SWATCH_ROOM := 20.0
const LINE_GLYPH_GAP := 4.0
const LINE_NAME := "ColourLine"
const RULE_SIZE := 15
const RULE_LINE_SPACING := 2
const COUPON_TITLE_WIDTH := 76.0
const COUPON_TITLE := "COUPON"
## A LOYALTY perk's title (show_upgrade), its name's size, its tag line and when it applies.
const LOYALTY_TITLE := "LOYALTY"
const LOYALTY_WHEN := "from the next shift"
const NAME_SIZE := 20
const TAG_HEIGHT := 16.0
const TAG_SIZE := 12
const TAG_SEPARATOR := " · "

const FRAME := preload("res://art/frames/popup.png")
const TAIL := preload("res://art/frames/popup_tail_side.png")

var placement: Placement = Placement.RIGHT

var _content: Control
var _rule: Label
var _name: Control
var _price: Label
var _glyphs: Array[FamilyGlyph] = []
var _line: Label
var _line_glyph: FamilyGlyph
## The colour line's swatch (empty: none).
var _swatch: Rect2 = Rect2()
var _tail: TextureRect
## The header band's colours (none: a paper header).
var _band: Array[FamilyStyle] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_tail = UiKit.sprite(TAIL)
	_tail.size = TAIL_SIZE
	add_child(_tail)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(SHADOW_OFFSET, size), Color(Palette.INK, SHADOW_ALPHA))
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), rect)
	if _band.is_empty():
		return
	var band: Rect2 = band_rect()
	var half: float = roundf(band.size.x / _band.size())
	for index: int in _band.size():
		var family: FamilyStyle = _band[index]
		var left: float = band.position.x + half * index
		var right: float = band.end.x if index == _band.size() - 1 else left + half
		var part: Rect2 = Rect2(left, band.position.y, right - left, band.size.y)
		draw_rect(part, family.face)
		draw_rect(Rect2(part.position, Vector2(part.size.x, BAND_EDGE)), family.light)
	draw_rect(Rect2(band.position.x, band.end.y - BAND_EDGE, band.size.x, BAND_EDGE), Palette.INK)
	if _swatch.has_area():
		draw_rect(_swatch, Palette.INK)
		var inside: Rect2 = _swatch.grow(-SWATCH_RING)
		var part: float = roundf(inside.size.x / _band.size())
		for index: int in _band.size():
			var left: float = inside.position.x + part * index
			var right: float = inside.end.x if index == _band.size() - 1 else left + part
			draw_rect(
				Rect2(left, inside.position.y, right - left, inside.size.y), _band[index].face
			)


## Fills the popup for `definition` with its `tags`. Call it once the popup is in the tree: the
## text's height is measured with the real font. The popup takes its height (MIN_HEIGHT to
## MAX_HEIGHT); place it with place_at().
func show_card(definition: CardDefinition, tags: PackedStringArray) -> void:
	_clear_content()
	var palette: FamilyPalette = FamilyPalette.shared()
	var families: PackedStringArray = palette.ticket_families(definition)
	_band.clear()
	for style: FamilyStyle in palette.styles(families):
		if style.has_ticket_colours():
			_band.append(style)
	var ink: Color = palette.text_color(families) if not _band.is_empty() else Palette.INK
	var y: float = PADDING
	if not _band.is_empty():
		var band: Rect2 = band_rect()
		_build_header(definition, band.position.y, band.size.y - BAND_EDGE, ink)
		y = _build_line(definition, palette, band.end.y + LINE_TOP)
	else:
		_build_header(definition, y, HEADER_HEIGHT, ink)
		y += HEADER_HEIGHT
	var shown: PackedStringArray = (
		palette.shelf_families(tags) if definition.is_product() else PackedStringArray()
	)
	if not shown.is_empty():
		y = _build_counts(shown, palette, y)
	_rule = UiKit.body_label(definition.rule_text, RULE_SIZE, Palette.INK)
	_rule.add_theme_constant_override("line_spacing", RULE_LINE_SPACING)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y = _add_text(_rule, y, -1.0)
	size = Vector2(WIDTH, clampf(y + PADDING, MIN_HEIGHT, MAX_HEIGHT))
	queue_redraw()


## The header band's rect (in the popup's coordinates), drawn when the card's ticket has colours.
func band_rect() -> Rect2:
	return Rect2(BAND_INSET, BAND_INSET, WIDTH - 2.0 * BAND_INSET, BAND_HEIGHT)


## The header band's families (none: a paper header).
func band_families() -> Array[FamilyStyle]:
	return _band


## Fills the popup for a LOYALTY perk (v0.53, a prize ticket's hover): its name with LOYALTY in
## the coupon title's place, its type and when it applies as the tag line, its effect and its
## condition (when it has one) as the rule. Call it once the popup is in the tree, as show_card.
func show_upgrade(upgrade: UpgradeDefinition) -> void:
	_clear_content()
	_band.clear()
	var y: float = PADDING
	_build_title(upgrade.display_name, LOYALTY_TITLE, y)
	y += HEADER_HEIGHT
	var tag_label: Label = UiKit.body_label(
		TAG_SEPARATOR.join([upgrade.type_label(), LOYALTY_WHEN]), TAG_SIZE, Palette.GREY_DARK
	)
	y = _add_text(tag_label, y, TAG_HEIGHT)
	var rule: String = upgrade.effect_text
	if not upgrade.condition_text.is_empty():
		rule += "\n" + upgrade.condition_text
	_rule = UiKit.body_label(rule, RULE_SIZE, Palette.INK)
	_rule.add_theme_constant_override("line_spacing", RULE_LINE_SPACING)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y = _add_text(_rule, y, -1.0)
	size = Vector2(WIDTH, clampf(y + PADDING, MIN_HEIGHT, MAX_HEIGHT))
	queue_redraw()


## Places the popup for an item whose lifted sprite is `item_rect` and whose sticker covers
## `below_rect`, beside it over `area` (the offers' panel) on `stage`, all global (an item in a
## scaled panel is placed where it is drawn), with its tail at the sprite's middle.
func place_at(item_rect: Rect2, below_rect: Rect2, stage: Rect2, area: Rect2) -> void:
	var to_parent: Transform2D = Transform2D.IDENTITY
	var parent: CanvasItem = get_parent() as CanvasItem
	if parent != null:
		to_parent = parent.get_global_transform().affine_inverse()
	var item: Rect2 = to_parent * item_rect
	var rect: Rect2 = place(item, to_parent * below_rect, size, to_parent * stage, to_parent * area)
	position = rect.position
	placement = Placement.LEFT if rect.end.x <= item.position.x else Placement.RIGHT
	_tail.flip_h = placement == Placement.LEFT
	var tail_y: float = clampf(
		item.get_center().y - rect.position.y - TAIL_SIZE.y / 2.0,
		PADDING,
		size.y - PADDING - TAIL_SIZE.y
	)
	if placement == Placement.LEFT:
		_tail.position = Vector2(size.x - TAIL_OVERLAP, tail_y)
	else:
		_tail.position = Vector2(TAIL_OVERLAP - TAIL_SIZE.x, tail_y)


## The popup's rect (round 3's hand rule, kept for the offers): it opens SIDE_GAP beside the
## item's column (`item_rect`, the lifted sprite, merged with `below_rect`, its sticker): on the
## right when it fits over `area`, else on the left when that fits over `area`, else on whichever
## side fits `stage`, else clamped to the stage's side margins. Its top is level with the lifted
## sprite's (the scan's marks stand above it), never above the area's top, and its bottom stays
## SIDE_MARGIN above the stage's foot. It may cover the neighbouring items. `popup_size` is the
## popup's size; every rect is in one set of coordinates.
static func place(
	item_rect: Rect2, below_rect: Rect2, popup_size: Vector2, stage: Rect2, area: Rect2
) -> Rect2:
	var column: Rect2 = item_rect.merge(below_rect)
	var right: float = column.end.x + SIDE_GAP
	var left: float = column.position.x - SIDE_GAP - popup_size.x
	var x: float = left
	if right + popup_size.x <= area.end.x:
		x = right
	elif left >= area.position.x:
		x = left
	elif right + popup_size.x <= stage.end.x - SIDE_MARGIN:
		x = right
	# Neither side fits: it stays on the stage, over the item if it must.
	x = clampf(x, stage.position.x + SIDE_MARGIN, stage.end.x - SIDE_MARGIN - popup_size.x)
	var lowest: float = stage.end.y - SIDE_MARGIN - popup_size.y
	var top: float = minf(maxf(item_rect.position.y, area.position.y), lowest)
	return Rect2(Vector2(x, top), popup_size)


func rule_label() -> Label:
	return _rule


## The name (ItemName.make's control: a MixedLabel, or the fallback's Label; a LOYALTY perk's
## Label).
func name_control() -> Control:
	return _name


## The name's text.
func name_text() -> String:
	return ItemName.text_of(_name)


## The price "€N", or null (a coupon, a LOYALTY perk).
func price_label() -> Label:
	return _price


## The "Counts as" row's glyphs, left to right (none for a coupon).
func glyphs() -> Array[FamilyGlyph]:
	return _glyphs


## The colour's line under a coloured header, or null (a plain coupon, a LOYALTY perk).
func colour_line() -> Label:
	return _line


## The glyph after the colour's line (the family it names), or null.
func colour_line_glyph() -> FamilyGlyph:
	return _line_glyph


## The colour line's swatch (empty: none).
func swatch_rect() -> Rect2:
	return _swatch


func tail() -> TextureRect:
	return _tail


## Every text label in the popup, for layout checks.
func text_labels() -> Array[Label]:
	var labels: Array[Label] = []
	_collect_labels(_content, labels)
	return labels


## The tail's tip (the middle of its pointed end), in the popup's parent's coordinates.
func tail_tip() -> Vector2:
	var box: Rect2 = Rect2(_tail.position, _tail.size)
	if placement == Placement.LEFT:
		return position + Vector2(box.end.x, box.get_center().y)
	return position + Vector2(box.position.x, box.get_center().y)


## A header with `title_text` in the coupon title's style at the right (show_upgrade).
func _build_title(heading: String, title_text: String, top: float) -> void:
	var name_label: Label = UiKit.display_label(heading, NAME_SIZE, false)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(PADDING, top)
	name_label.size = Vector2(WIDTH - 2.0 * PADDING - COUPON_TITLE_WIDTH - 6.0, HEADER_HEIGHT)
	_content.add_child(name_label)
	_name = name_label
	_price = null
	var title: Label = UiKit.display_label(title_text, COUPON_TITLE_SIZE, false)
	title.add_theme_color_override("font_color", Palette.TEAL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(WIDTH - PADDING - COUPON_TITLE_WIDTH, top)
	title.size = Vector2(COUPON_TITLE_WIDTH, HEADER_HEIGHT)
	_content.add_child(title)


## The header row at `top`, `height` tall: the name, then the price (or COUPON) at the right, in
## `ink`.
func _build_header(definition: CardDefinition, top: float, height: float, ink: Color) -> void:
	var right: float = WIDTH - PADDING
	var badge: float = COUPON_TITLE_WIDTH
	_price = null
	if definition.is_coupon():
		var title: Label = UiKit.display_label(COUPON_TITLE, COUPON_TITLE_SIZE, false)
		title.add_theme_color_override("font_color", Palette.VELVET if _band.is_empty() else ink)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.position = Vector2(right - COUPON_TITLE_WIDTH, top)
		title.size = Vector2(COUPON_TITLE_WIDTH, height)
		_content.add_child(title)
	else:
		_price = UiKit.number_label(PriceSticker.price_text(definition.base), PRICE_SIZE, false)
		_price.name = "Price"
		_price.add_theme_color_override("font_color", ink)
		_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_content.add_child(_price)
		badge = ceilf(_price.get_minimum_size().x)
		_price.position = Vector2(right - badge, top)
		_price.size = Vector2(badge, height)
	_name = ItemName.make(definition.display_name, right - badge - PRICE_GAP - PADDING, height, ink)
	_name.position = Vector2(PADDING, top)
	_content.add_child(_name)


## The colour's line at `top` (FamilyPalette.ticket_line): the swatch, the words wrapping in the
## room left of the glyph, and the glyph of the family it works with or gives after its last line.
## Returns the next top.
func _build_line(definition: CardDefinition, palette: FamilyPalette, top: float) -> float:
	var text: String = palette.ticket_line(definition)
	if text.is_empty():
		return top + BAND_GAP - LINE_TOP
	var why: CardFamilies.Why = palette.colour_reason(definition)
	var named: FamilyStyle = null
	if why.reason == CardFamilies.Reason.FAMILY or why.reason == CardFamilies.Reason.GIVES:
		named = palette.style(why.subject)
		if named != null and named.glyph == null:
			named = null
	var font: Font = ArtStyle.bold_font(LINE_WEIGHT)
	var glyph_room: float = ArtStyle.FAMILY_GLYPH_SIZE + LINE_GLYPH_GAP if named != null else 0.0
	var width: float = CONTENT_WIDTH - LINE_SWATCH_ROOM - glyph_room
	_line = UiKit.body_label(text, LINE_SIZE, Palette.INK)
	_line.name = LINE_NAME
	_line.add_theme_font_override("font", font)
	_line.add_theme_constant_override("line_spacing", LINE_SPACING)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_line)
	_line.position = Vector2(PADDING + LINE_SWATCH_ROOM, top)
	_line.size = Vector2(width, 1.0)
	_line.size.y = _line.get_minimum_size().y
	var line_height: float = font.get_height(LINE_SIZE)
	_swatch = Rect2(
		Vector2(PADDING, roundf(top + (line_height - SWATCH_SIZE.y) / 2.0)), SWATCH_SIZE
	)
	if named != null:
		_line_glyph = FamilyGlyph.new(named)
		var last: float = _last_line_width(text, font, width)
		var pitch: float = line_height + LINE_SPACING
		var last_top: float = top + pitch * (_line.get_line_count() - 1)
		_line_glyph.position = Vector2(
			roundf(_line.position.x + last + LINE_GLYPH_GAP),
			roundf(last_top + (line_height - _line_glyph.size.y) / 2.0)
		)
		_content.add_child(_line_glyph)
	return top + _line.size.y + LINE_GAP


## How wide the last line of `text` is, wrapped at `width` as a smart-wrapping label wraps it.
static func _last_line_width(text: String, font: Font, width: float) -> float:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(text, font, LINE_SIZE)
	paragraph.width = width
	paragraph.break_flags = (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	var lines: int = paragraph.get_line_count()
	return ceilf(paragraph.get_line_width(lines - 1)) if lines > 0 else 0.0


## The "Counts as" row at `top`: its words, then the glyphs of `families`. Returns the next top.
func _build_counts(families: PackedStringArray, palette: FamilyPalette, top: float) -> float:
	var words: Label = UiKit.body_label(COUNTS_TEXT, COUNTS_SIZE, Palette.GREY_DARK)
	words.name = "CountsAs"
	words.add_theme_font_override("font", ArtStyle.bold_font(COUNTS_WEIGHT))
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(words)
	var width: float = ceilf(words.get_minimum_size().x)
	words.position = Vector2(PADDING, top)
	words.size = Vector2(width, COUNTS_HEIGHT)
	var x: float = PADDING + width + COUNTS_GAP
	_glyphs.clear()
	for family: String in families:
		var style: FamilyStyle = palette.style(family)
		if style == null or style.glyph == null:
			continue
		var glyph: FamilyGlyph = FamilyGlyph.new(style)
		glyph.position = Vector2(x, top + (COUNTS_HEIGHT - glyph.size.y) / 2.0)
		_content.add_child(glyph)
		_glyphs.append(glyph)
		x += glyph.size.x + COUNTS_GAP
	return top + COUNTS_HEIGHT


func _clear_content() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_glyphs.clear()
	_line = null
	_line_glyph = null
	_swatch = Rect2()


## Adds `label` at `top` across the content width: `height`, or its measured height when
## negative. Returns the next line's top.
func _add_text(label: Label, top: float, height: float) -> float:
	# In the tree first: out of it a label measures with the default font size.
	_content.add_child(label)
	label.position = Vector2(PADDING, top)
	label.size = Vector2(CONTENT_WIDTH, maxf(height, 1.0))
	if height < 0.0:
		label.size.y = label.get_minimum_size().y
	return top + label.size.y


static func _collect_labels(node: Node, labels: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			labels.append(child as Label)
		_collect_labels(child, labels)
