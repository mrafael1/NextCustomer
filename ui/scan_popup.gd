class_name ScanPopup
extends Control
## The scan popup (#75; style frame v2's spec section 4.5): what a hovered item does, in full. A
## paper panel with a gold trim and a hard drop shadow: a header (aisle glyph, name and a mini
## sticker with the base, or COUPON), the tag line (the item's tags and its aisle, or Staple), the
## card's rule text verbatim and, for a belt item, a footer under a dashed brass rule with its
## payout and its step lines, as the caller words them. Its tail points at the item. place() is
## the pure placement rule. A belt item's popup (delta section 11) sits above the item with room
## for its marks, clamped to the stage, flipped below the item's sticker and chips when it would
## reach the top bar, or held under the top bar over the sprite's top when it fits neither way
## (B2's belt stands mid-screen). A hand item's popup (round 3) never covers the belt: it opens
## beside the item, over the tray, its tail pointing sideways at the item. The popup grows with
## its text up to MAX_HEIGHT; footer lines that don't fit fold into a last "+N more" line. A
## step line's amount (or "fizzle", after ReceiptView.joined_line's two spaces) sits at the
## popup's right edge on the line's last row, as on the receipt (ScanFooter, which the monitor
## shares). Since #80 the shift screen opens it for the offers only (ScanController.cover_offers):
## a belt or hand item's scan shows on the monitor (MonitorView).

## Where the popup opened: above or below a belt item, or right or left of a hand item.
enum Placement { ABOVE, BELOW, RIGHT, LEFT }

const WIDTH := 288.0
const MIN_HEIGHT := 140.0
## The cap: the longest rule text with its header, tag line and payout row fits well within it,
## and a belt item's popup held under the top bar still ends above its chips.
const MAX_HEIGHT := 280.0
const PADDING := 12.0
const CONTENT_WIDTH := 264.0
## The popup's bottom sits this far above the lifted sprite (the scan's marks fit in the gap); a
## flipped one's top this far below the item's sticker and chips.
const GAP_ABOVE := 36.0
const FLIP_GAP := 8.0
## The stage's side margin, and the gap a belt item's popup keeps under the top bar before it
## flips.
const SIDE_MARGIN := 16.0
const TOP_GAP := 4.0
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
## Spec 4.5 says Atkinson 13; 12 fits more of a step line on a row. A line wraps when its text and
## the amount kept at its right don't fit on one row, with the amount on its last row.
const FOOTER_SIZE := 12
const FOOTER_GAP := 4.0
const COUPON_TITLE_WIDTH := 76.0
const RULE_DASH := 4.0
const STAPLE := "Staple"
const COUPON_TITLE := "COUPON"
const PAYS_TEXT := "Pays €%d"
## The footer's last line when the rest don't fit under MAX_HEIGHT: how many were folded.
const MORE_TEXT := ScanFooter.MORE_TEXT
const TAG_SEPARATOR := " · "

const FRAME := preload("res://art/frames/popup.png")
const TAIL := preload("res://art/frames/popup_tail.png")
const TAIL_SIDE := preload("res://art/frames/popup_tail_side.png")

var placement: Placement = Placement.ABOVE

var _content: Control
var _rule: Label
var _name: Label
## Each footer line's text as the caller gave it, its amount included.
var _footer_texts: PackedStringArray = PackedStringArray()
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
	draw_rect(Rect2(SHADOW_OFFSET, size), Color(Palette.INK, SHADOW_ALPHA))
	draw_style_box(ArtStyle.frame_style(FRAME, FRAME_MARGIN), rect)
	if _footer_top < 0.0:
		return
	var x: float = PADDING
	while x < _rule_end:
		draw_rect(Rect2(x, _footer_top, RULE_DASH, ArtStyle.ART_SCALE), Palette.BRASS)
		x += 2.0 * RULE_DASH


## Fills the popup for `definition` (its `aisle`, or null) with its `tags` (on the belt the
## scored ones, granted tags included). A belt item passes its `payout` and footer lines (each
## with whether it is a fizzle); a hand item passes payout -1. Call it once the popup is in the
## tree: the text's height is measured with the real font. The popup takes its height
## (MIN_HEIGHT to MAX_HEIGHT), folding the footer lines that don't fit into "+N more"; place it
## with place_at().
func show_card(
	definition: CardDefinition,
	aisle: AisleDefinition,
	tags: PackedStringArray,
	payout: int,
	footer_lines: PackedStringArray,
	footer_fizzles: Array[bool]
) -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_footer_texts.clear()
	_footer_top = -1.0
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
	if payout >= 0:
		# The payout sits at the end of the footer's dashed rule, on one row.
		y += FOOTER_GAP
		var pays: Label = UiKit.body_label(PAYS_TEXT % payout, FOOTER_SIZE, Palette.INK)
		pays.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_keep_footer(pays.text)
		var row_height: float = _add_text(pays, y, -1.0) - y
		_rule_end = WIDTH - PADDING - pays.get_minimum_size().x - FOOTER_GAP * 2.0
		_footer_top = y + roundf((row_height - ArtStyle.ART_SCALE) / 2.0)
		# The step lines (ScanFooter) under the payout, folded to end within MAX_HEIGHT.
		var footer: ScanFooter = ScanFooter.new(CONTENT_WIDTH, FOOTER_SIZE)
		_content.add_child(footer)
		footer.position = Vector2(PADDING, y + row_height)
		footer.fill(footer_lines, footer_fizzles, MAX_HEIGHT - PADDING - footer.position.y)
		for text: String in footer.texts():
			_keep_footer(text)
		y = footer.position.y + footer.size.y
	size = Vector2(WIDTH, clampf(y + PADDING, MIN_HEIGHT, MAX_HEIGHT))
	queue_redraw()


## Places the popup for an item whose lifted sprite is `item_rect` and whose sticker (and chips,
## on the belt) cover `below_rect`, within `layout`, all global (an item in a scaled row is placed
## where it is drawn), with its tail at the sprite's centre: under or over it for a belt item,
## beside it for a hand item (its sprite in the layout's tray).
func place_at(item_rect: Rect2, below_rect: Rect2, layout: ScanLayout) -> void:
	var to_parent: Transform2D = Transform2D.IDENTITY
	var parent: CanvasItem = get_parent() as CanvasItem
	if parent != null:
		to_parent = parent.get_global_transform().affine_inverse()
	var item: Rect2 = to_parent * item_rect
	var rect: Rect2 = place(item, to_parent * below_rect, size, layout.transformed(to_parent))
	position = rect.position
	placement = placement_of(rect, item)
	var beside: bool = placement == Placement.RIGHT or placement == Placement.LEFT
	_tail.texture = TAIL_SIDE if beside else TAIL
	_tail.size = TAIL_SIDE_SIZE if beside else TAIL_SIZE
	_tail.flip_v = placement == Placement.BELOW
	_tail.flip_h = placement == Placement.LEFT
	var tail_x: float = item.get_center().x - rect.position.x - TAIL_SIZE.x / 2.0
	var tail_y: float = clampf(
		item.get_center().y - rect.position.y - TAIL_SIDE_SIZE.y / 2.0,
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


## The popup's rect for an item, in `layout`'s coordinates. A hand item's (its sprite in the
## layout's tray): place_beside(). A belt item's (delta section 11): centred on the sprite and
## clamped to the stage's side margins, its bottom GAP_ABOVE above the lifted sprite; when its top
## would come within TOP_GAP of the top bar it flips FLIP_GAP below `below_rect` (the item's
## sticker and chips). When the flipped popup would run past the stage's foot too (a tall popup
## on B2's mid-screen belt), it stays above, its top TOP_GAP under the top bar, over the sprite's
## top: it never covers `below_rect`, what its footer lists. `popup_size` is the popup's size.
static func place(
	item_rect: Rect2, below_rect: Rect2, popup_size: Vector2, layout: ScanLayout
) -> Rect2:
	if layout.is_in_tray(item_rect):
		return place_beside(item_rect, below_rect, popup_size, layout)
	var stage: Rect2 = layout.stage
	var x: float = item_rect.get_center().x - popup_size.x / 2.0
	x = clampf(x, stage.position.x + SIDE_MARGIN, stage.end.x - SIDE_MARGIN - popup_size.x)
	var top: float = item_rect.position.y - GAP_ABOVE - popup_size.y
	var highest: float = layout.top_bar_bottom + TOP_GAP
	if top < highest:
		var flipped: float = below_rect.end.y + FLIP_GAP
		var fits_below: bool = flipped + popup_size.y <= stage.end.y - SIDE_MARGIN
		top = flipped if fits_below else highest
	return Rect2(Vector2(x, top), popup_size)


## A hand item's popup (round 3): it never covers the belt, so the row's stickers and chips stay
## readable. It opens SIDE_GAP beside the item's column (`item_rect`, the lifted sprite, merged
## with `below_rect`, its sticker): on the right when it fits over the tray, else on the left when
## that fits over the tray, else on whichever side fits the stage, else clamped to the stage's side
## margins (no hand position needs that: the tray always has room on one side). Its top is level
## with the lifted sprite's (the scan's marks stand above it), never above the counter line, and
## its bottom stays SIDE_MARGIN above the stage's foot. It may cover the neighbouring hand items.
static func place_beside(
	item_rect: Rect2, below_rect: Rect2, popup_size: Vector2, layout: ScanLayout
) -> Rect2:
	var stage: Rect2 = layout.stage
	var tray: Rect2 = layout.tray
	var column: Rect2 = item_rect.merge(below_rect)
	var right: float = column.end.x + SIDE_GAP
	var left: float = column.position.x - SIDE_GAP - popup_size.x
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
	var top: float = minf(maxf(item_rect.position.y, layout.counter_top), lowest)
	return Rect2(Vector2(x, top), popup_size)


## Where a placed popup `rect` opened relative to its item's sprite `item_rect`.
static func placement_of(rect: Rect2, item_rect: Rect2) -> Placement:
	if rect.position.x >= item_rect.end.x:
		return Placement.RIGHT
	if rect.end.x <= item_rect.position.x:
		return Placement.LEFT
	return Placement.BELOW if rect.position.y > item_rect.position.y else Placement.ABOVE


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


## The footer's lines ("Pays €N", then each step line shown, then "+N more" when some were
## folded), empty for a hand item.
func footer_texts() -> PackedStringArray:
	return _footer_texts.duplicate()


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


## Keeps `text` as the footer's next line, read back by footer_texts().
func _keep_footer(text: String) -> void:
	_footer_texts.append(text)


static func _collect_labels(node: Node, labels: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			labels.append(child as Label)
		_collect_labels(child, labels)
