class_name ScanPopup
extends Control
## The scan popup of style frame v2 (#75, spec section 4.5): what a hovered item does, in full.
## A paper panel with a gold trim and a hard drop shadow: a header (aisle glyph, name and a mini
## sticker with the base, or COUPON), the tag line (tags and the aisle, or Staple), the card's
## rule text verbatim and, for a belt item, a footer under a dashed brass rule with its payout
## and every chip step's full line. Its tail points at the item. place() is the pure placement
## rule. A belt item's popup (round 2, delta section 11) sits above the item with room for the
## posed scanner, clamped to the stage, flipped below the item's sticker and chips when it would
## reach the top bar. A hand item's popup (round 3) never covers the belt: it opens beside the
## item, over the tray, its tail pointing sideways at the item.

## Where the popup opened: above or below a belt item, or right or left of a hand item.
enum Placement { ABOVE, BELOW, RIGHT, LEFT }

const WIDTH := 288.0
const MIN_HEIGHT := 140.0
const MAX_HEIGHT := 200.0
const PADDING := 12.0
const CONTENT_WIDTH := 264.0
## The popup's bottom sits this far above the lifted sprite (the posed scanner fits in the gap); a
## flipped one's top this far below the item's sticker and chips.
const GAP_ABOVE := 36.0
const FLIP_GAP := 8.0
## The stage's side margin and the highest top before the popup flips (under the top bar).
const SIDE_MARGIN := 16.0
const TOP_LIMIT := 68.0
const FRAME_MARGIN := 4
const TAIL_SIZE := Vector2(16, 10)
## A hand item's popup opens SIDE_GAP beside the item's column (its sprite and sticker), its top
## level with the lifted sprite's and never above the counter line; the side tail spans the gap.
const SIDE_GAP := 8.0
const TAIL_SIDE_SIZE := Vector2(10, 16)
## The tail's first art row covers the popup's outline.
const TAIL_OVERLAP := 2.0
const SHADOW_OFFSET := Vector2(4, 4)
const SHADOW_ALPHA := 0.3
const HEADER_HEIGHT := 28.0
const GLYPH_SIZE := Vector2(18, 18)
const NAME_SIZE := 20
const COUPON_TITLE_SIZE := 14
const MINI_STICKER_SIZE := Vector2(56, 26)
const MINI_BASE_SIZE := 18
const TAG_HEIGHT := 16.0
const TAG_SIZE := 12
const RULE_SIZE := 15
const RULE_LINE_SPACING := 2
## Spec 4.5 says Atkinson 13, but at 13 the hovered Multipack's fizzle line wraps to a second
## line and its popup needs 216 px, over the spec's 200 px cap; 12 keeps every popup within it.
const FOOTER_SIZE := 12
const FOOTER_GAP := 4.0
const COUPON_TITLE_WIDTH := 76.0
const RULE_DASH := 4.0
const ICON_SIZE := Vector2(14, 14)
const STAPLE := "Staple"
const COUPON_TITLE := "COUPON"
const PAYS_TEXT := "Pays €%d"
const TAG_SEPARATOR := " · "

const FRAME := preload("res://art/frames/popup.png")
const TAIL := preload("res://art/frames/popup_tail.png")
const TAIL_SIDE := preload("res://art/frames/popup_tail_side.png")
const FIZZLE_ICON := preload("res://art/icons/fizzle.png")

var placement: Placement = Placement.ABOVE

var _content: Control
var _rule: Label
var _name: Label
var _footer: Array[Label] = []
var _footer_top: float = -1.0
var _rule_end: float = 0.0
var _tail: TextureRect


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
	draw_rect(Rect2(SHADOW_OFFSET, size), Color(StyleFrameV2.INK, SHADOW_ALPHA))
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), rect)
	if _footer_top < 0.0:
		return
	var x: float = PADDING
	while x < _rule_end:
		draw_rect(Rect2(x, _footer_top, RULE_DASH, ArtStyle.ART_SCALE), StyleFrameV2.BRASS)
		x += 2.0 * RULE_DASH


## Fills the popup for `definition` (its `aisle`, or null). A belt item passes its `payout`
## and footer lines (each with whether it is a fizzle); a hand item passes payout -1. Call it
## once the popup is in the tree: the rule's height is measured with the real font. The popup
## takes its height (MIN_HEIGHT to MAX_HEIGHT); place it with place_at().
func show_card(
	definition: CardDefinition,
	aisle: AisleDefinition,
	payout: int,
	footer_lines: PackedStringArray,
	footer_fizzles: Array[bool]
) -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_footer.clear()
	_footer_top = -1.0
	var y: float = PADDING
	_build_header(definition, aisle, y)
	y += HEADER_HEIGHT
	var tag_text: String = tag_line(definition, aisle)
	if not tag_text.is_empty():
		var tags: Label = UiKit.body_label(tag_text, TAG_SIZE, StyleFrameV2.GREY_DARK)
		y = _add_text(tags, y, TAG_HEIGHT)
	_rule = UiKit.body_label(definition.rule_text, RULE_SIZE, StyleFrameV2.INK)
	_rule.add_theme_constant_override("line_spacing", RULE_LINE_SPACING)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y = _add_text(_rule, y, -1.0)
	if payout >= 0:
		# The payout sits at the end of the footer's dashed rule, on one row.
		y += FOOTER_GAP
		var pays: Label = UiKit.body_label(PAYS_TEXT % payout, FOOTER_SIZE, StyleFrameV2.INK)
		pays.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_footer.append(pays)
		var row_height: float = _add_text(pays, y, -1.0) - y
		_rule_end = WIDTH - PADDING - pays.get_minimum_size().x - FOOTER_GAP * 2.0
		_footer_top = y + roundf((row_height - ArtStyle.ART_SCALE) / 2.0)
		y += row_height
		for index: int in range(footer_lines.size()):
			y = _add_footer_line(footer_lines[index], footer_fizzles[index], y)
	size = Vector2(WIDTH, clampf(y + PADDING, MIN_HEIGHT, MAX_HEIGHT))
	queue_redraw()


## Places the popup for an item whose lifted sprite is `item_rect` and whose sticker (and chips,
## on the belt) cover `below_rect` (stage coordinates), on `stage` (the stage's own rect), with its
## tail at the sprite's centre: under or over it for a belt item (`on_belt`), beside it for a hand
## item.
func place_at(item_rect: Rect2, below_rect: Rect2, stage: Rect2, on_belt: bool) -> void:
	var rect: Rect2 = place(item_rect, below_rect, size, stage, on_belt)
	position = rect.position
	placement = placement_of(rect, item_rect)
	var beside: bool = placement == Placement.RIGHT or placement == Placement.LEFT
	_tail.texture = TAIL_SIDE if beside else TAIL
	_tail.size = TAIL_SIDE_SIZE if beside else TAIL_SIZE
	_tail.flip_v = placement == Placement.BELOW
	_tail.flip_h = placement == Placement.LEFT
	var tail_x: float = item_rect.get_center().x - rect.position.x - TAIL_SIZE.x / 2.0
	var tail_y: float = clampf(
		item_rect.get_center().y - rect.position.y - TAIL_SIDE_SIZE.y / 2.0,
		PADDING,
		size.y - PADDING - TAIL_SIDE_SIZE.y
	)
	match placement:
		Placement.ABOVE:
			_tail.position = Vector2(tail_x, size.y - TAIL_OVERLAP)
		Placement.BELOW:
			_tail.position = Vector2(tail_x, TAIL_OVERLAP - TAIL_SIZE.y)
		Placement.RIGHT:
			_tail.position = Vector2(TAIL_OVERLAP - TAIL_SIDE_SIZE.x, tail_y)
		Placement.LEFT:
			_tail.position = Vector2(size.x - TAIL_OVERLAP, tail_y)


## The popup's rect for an item. A belt item's (`on_belt`, delta section 11): centred on the
## sprite and clamped to the stage's side margins, its bottom GAP_ABOVE above the lifted sprite;
## when its top would be above TOP_LIMIT it flips FLIP_GAP below `below_rect` (the item's
## sticker and chips), so it never covers what its footer lists. A hand item's: place_beside().
## `popup_size` is the popup's size.
static func place(
	item_rect: Rect2, below_rect: Rect2, popup_size: Vector2, stage: Rect2, on_belt: bool
) -> Rect2:
	if not on_belt:
		return place_beside(item_rect, below_rect, popup_size, stage)
	var x: float = item_rect.get_center().x - popup_size.x / 2.0
	x = clampf(x, stage.position.x + SIDE_MARGIN, stage.end.x - SIDE_MARGIN - popup_size.x)
	var top: float = item_rect.position.y - GAP_ABOVE - popup_size.y
	if top < stage.position.y + TOP_LIMIT:
		top = below_rect.end.y + FLIP_GAP
	return Rect2(Vector2(x, top), popup_size)


## A hand item's popup (round 3): it never covers the belt, so the row's stickers and chips stay
## readable. It opens SIDE_GAP beside the item's column (`item_rect`, the lifted sprite, merged
## with `below_rect`, its sticker): on the right when it fits over the tray, else on the left when
## that fits over the tray, else on whichever side fits the stage, else clamped to the stage's side
## margins (no hand position needs that: the tray always has room on one side). Its top is level
## with the lifted sprite's (the posed scanner stands above it), never above the counter line, and
## its bottom stays SIDE_MARGIN above the stage's foot. It may cover the neighbouring hand items.
static func place_beside(
	item_rect: Rect2, below_rect: Rect2, popup_size: Vector2, stage: Rect2
) -> Rect2:
	var column: Rect2 = item_rect.merge(below_rect)
	var right: float = column.end.x + SIDE_GAP
	var left: float = column.position.x - SIDE_GAP - popup_size.x
	var tray: Rect2 = StyleFrameV2.TRAY_RECT
	tray.position += stage.position
	var x: float = left
	if right + popup_size.x <= tray.end.x:
		x = right
	elif left >= tray.position.x:
		x = left
	elif right + popup_size.x <= stage.end.x - SIDE_MARGIN:
		x = right
	# Neither side fits: it stays on the stage, over the item if it must.
	x = clampf(x, stage.position.x + SIDE_MARGIN, stage.end.x - SIDE_MARGIN - popup_size.x)
	var lowest: float = stage.end.y - SIDE_MARGIN - popup_size.y
	var top: float = minf(
		maxf(item_rect.position.y, stage.position.y + StyleFrameV2.COUNTER_TOP), lowest
	)
	return Rect2(Vector2(x, top), popup_size)


## Where a placed popup `rect` opened relative to its item's sprite `item_rect`.
static func placement_of(rect: Rect2, item_rect: Rect2) -> Placement:
	if rect.position.x >= item_rect.end.x:
		return Placement.RIGHT
	if rect.end.x <= item_rect.position.x:
		return Placement.LEFT
	return Placement.BELOW if rect.position.y > item_rect.position.y else Placement.ABOVE


## The tag line: the card's tags and its aisle (or Staple); a coupon shows only its tags.
static func tag_line(definition: CardDefinition, aisle: AisleDefinition) -> String:
	var parts: PackedStringArray = definition.tags.duplicate()
	if definition.is_product():
		parts.append(aisle.display_name if aisle != null else STAPLE)
	return TAG_SEPARATOR.join(parts)


func rule_label() -> Label:
	return _rule


func name_label() -> Label:
	return _name


func tail() -> TextureRect:
	return _tail


## The footer's lines ("Pays €N", then each chip step's line), empty for a hand item.
func footer_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Label in _footer:
		texts.append(label.text)
	return texts


## Every text label in the popup, for layout checks.
func text_labels() -> Array[Label]:
	var labels: Array[Label] = []
	_collect_labels(_content, labels)
	return labels


## The tail's tip (the middle of its pointed end), in the popup's parent's coordinates.
func tail_tip() -> Vector2:
	var box: Rect2 = Rect2(_tail.position, _tail.size)
	match placement:
		Placement.BELOW:
			return position + Vector2(box.get_center().x, box.position.y)
		Placement.RIGHT:
			return position + Vector2(box.position.x, box.get_center().y)
		Placement.LEFT:
			return position + Vector2(box.end.x, box.get_center().y)
	return position + Vector2(box.get_center().x, box.end.y)


func _build_header(definition: CardDefinition, aisle: AisleDefinition, top: float) -> void:
	var x: float = PADDING
	if aisle != null:
		var glyph: TextureRect = UiKit.sprite(load(ArtCardView.glyph_path(aisle)) as Texture2D)
		glyph.position = Vector2(x, top + (HEADER_HEIGHT - GLYPH_SIZE.y) / 2.0)
		glyph.size = GLYPH_SIZE
		_content.add_child(glyph)
		x += GLYPH_SIZE.x + 6.0
	_name = UiKit.display_label(definition.display_name, NAME_SIZE, false)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.position = Vector2(x, top)
	var badge: float = COUPON_TITLE_WIDTH if definition.is_coupon() else MINI_STICKER_SIZE.x
	_name.size = Vector2(WIDTH - PADDING - badge - 6.0 - x, HEADER_HEIGHT)
	_content.add_child(_name)
	var right: float = WIDTH - PADDING
	if definition.is_coupon():
		var title: Label = UiKit.display_label(COUPON_TITLE, COUPON_TITLE_SIZE, false)
		title.add_theme_color_override("font_color", StyleFrameV2.VELVET)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.position = Vector2(right - COUPON_TITLE_WIDTH, top)
		title.size = Vector2(COUPON_TITLE_WIDTH, HEADER_HEIGHT)
		_content.add_child(title)
		return
	var sticker: Panel = Panel.new()
	sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sticker.add_theme_stylebox_override("panel", PriceSticker.frame_style())
	ArtStyle.use_pixel_material(sticker)
	sticker.position = Vector2(
		right - MINI_STICKER_SIZE.x, top + (HEADER_HEIGHT - MINI_STICKER_SIZE.y) / 2.0
	)
	sticker.size = MINI_STICKER_SIZE
	_content.add_child(sticker)
	var base: Label = UiKit.number_label("€%d" % definition.base, MINI_BASE_SIZE, false)
	base.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	base.position = Vector2(0, 4)
	base.size = MINI_STICKER_SIZE - Vector2(0, 4)
	sticker.add_child(base)


## Adds `label` at `top` across the content width: `height`, or its measured height when
## negative. Returns the next line's top.
func _add_text(label: Label, top: float, height: float) -> float:
	label.position = Vector2(PADDING, top)
	label.size = Vector2(CONTENT_WIDTH, maxf(height, 1.0))
	_content.add_child(label)
	if height < 0.0:
		label.size.y = label.get_minimum_size().y
	return top + label.size.y


func _add_footer_line(text: String, fizzle: bool, top: float) -> float:
	var label: Label = UiKit.body_label(
		text, FOOTER_SIZE, StyleFrameV2.TOMATO_DARK if fizzle else StyleFrameV2.INK
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.append(label)
	if not fizzle:
		return _add_text(label, top, -1.0)
	var icon: TextureRect = UiKit.sprite(FIZZLE_ICON)
	icon.position = Vector2(PADDING, top + 2.0)
	icon.size = ICON_SIZE
	_content.add_child(icon)
	var indent: float = ICON_SIZE.x + 4.0
	label.position = Vector2(PADDING + indent, top)
	label.size = Vector2(CONTENT_WIDTH - indent, 1.0)
	_content.add_child(label)
	label.size.y = label.get_minimum_size().y
	return top + label.size.y


static func _collect_labels(node: Node, labels: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			labels.append(child as Label)
		_collect_labels(child, labels)
