class_name ScanPopup
extends Control
## The scan popup (#75; style frame v2's spec section 4.5): what a scanned offer does, in full.
## A paper panel with a gold trim and a hard drop shadow: a header (aisle glyph, name and a mini
## sticker with the base, or COUPON), the tag line (the item's tags and its aisle, or Staple) and
## the card's rule text verbatim. It grows with its text up to MAX_HEIGHT. place() is the pure
## placement rule: it opens beside the item, over the offers' panel, its tail pointing sideways at
## the item. Since #80 the shift screen opens it for the offers only (ScanController.cover_offers):
## a belt or hand item's scan shows on the monitor (MonitorView), with its payout and step lines.

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
const GLYPH_SIZE := Vector2(18, 18)
const NAME_SIZE := 20
const COUPON_TITLE_SIZE := 14
const MINI_STICKER_SIZE := Vector2(56, 26)
const MINI_BASE_SIZE := 18
const TAG_HEIGHT := 16.0
const TAG_SIZE := 12
const RULE_SIZE := 15
const RULE_LINE_SPACING := 2
const COUPON_TITLE_WIDTH := 76.0
const STAPLE := "Staple"
const COUPON_TITLE := "COUPON"
const TAG_SEPARATOR := " · "

const FRAME := preload("res://art/frames/popup.png")
const TAIL := preload("res://art/frames/popup_tail_side.png")

var placement: Placement = Placement.RIGHT

var _content: Control
var _rule: Label
var _name: Label
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
	draw_rect(Rect2(SHADOW_OFFSET, size), Color(Palette.INK, SHADOW_ALPHA))
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), rect)


## Fills the popup for `definition` (its `aisle`, or null) with its `tags`. Call it once the popup
## is in the tree: the text's height is measured with the real font. The popup takes its height
## (MIN_HEIGHT to MAX_HEIGHT); place it with place_at().
func show_card(definition: CardDefinition, aisle: AisleDefinition, tags: PackedStringArray) -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var y: float = PADDING
	_build_header(definition, aisle, y)
	y += HEADER_HEIGHT
	var tag_text: String = tag_line(tags, definition, aisle)
	if not tag_text.is_empty():
		var tag_label: Label = UiKit.body_label(tag_text, TAG_SIZE, Palette.GREY_DARK)
		var top: float = y
		y = _add_text(tag_label, top, TAG_HEIGHT)
		# One TAG_HEIGHT row; a tag line too wide for it (three tags and an aisle) wraps.
		if tag_label.get_minimum_size().x > CONTENT_WIDTH:
			tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tag_label.size = Vector2(CONTENT_WIDTH, 1.0)
			tag_label.size.y = tag_label.get_minimum_size().y
			y = top + tag_label.size.y
	_rule = UiKit.body_label(definition.rule_text, RULE_SIZE, Palette.INK)
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


## The tag line: the item's `tags` and, for a product, its aisle (or Staple), unless a tag
## already reads the same (Batteries' Household tag in the Household aisle); a coupon shows only
## its tags.
static func tag_line(
	tags: PackedStringArray, definition: CardDefinition, aisle: AisleDefinition
) -> String:
	var parts: PackedStringArray = tags.duplicate()
	if definition.is_product():
		var where: String = aisle.display_name if aisle != null else STAPLE
		if not parts.has(where):
			parts.append(where)
	return TAG_SEPARATOR.join(parts)


func rule_label() -> Label:
	return _rule


func name_label() -> Label:
	return _name


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


func _build_header(definition: CardDefinition, aisle: AisleDefinition, top: float) -> void:
	var x: float = PADDING
	if aisle != null:
		var glyph: TextureRect = UiKit.sprite(load(ArtStyle.glyph_path(aisle)) as Texture2D)
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
		title.add_theme_color_override("font_color", Palette.VELVET)
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
