class_name RedrawPanel
extends Control
## The monitor's redraw panel (plan section 3.8; mock-up redraw_basket_v1.html, approved by the
## user on 2026-10-22): over the whole paper while redraw mode is armed or the redraw plays
## (MonitorView.show_redraw). The heading with the redraws left at its right; then either a small
## spaced key line ("PICK A BASKET") and the body line, or a row of the going items' icons, a ">"
## and the coming items' icons (or "N new items drawn" and the "-1 REDRAW" chip) over the body
## line; and the foot under a dashed rule, tomato dark when it warns. Display only: it lays out a
## RedrawNotice.

const PADDING := Vector2(16, 12)
const TITLE_HEIGHT := 30.0
const TITLE_SIZE := 24
const LEFT_SIZE := 12
const KEY_Y := 48.0
const KEY_HEIGHT := 14.0
const KEY_SIZE := 11
const KEY_WEIGHT := 700
const LINE_SIZE := 15
const BOLD_WEIGHT := 800
const LINE_GAP := 3.0
const ICON := 48.0
const ICON_GAP := 6.0
const ROW_Y := 44.0
const ARROW_TEXT := ">"
const ARROW_SIZE := 24
const ARROW_MARGIN := 4.0
const CHIP_TEXT := "-1 REDRAW"
const CHIP_HEIGHT := 24.0
const CHIP_PADDING := 8.0
const CHIP_BORDER := 2.0
const CHIP_SIZE := 12
const FOOT_BOTTOM := 9.0
const FOOT_HEIGHT := 16.0
const FOOT_SIZE := 12
const FOOT_WEIGHT := 700
const RULE := 2.0
const RULE_GAP := 4.0
const DASH := 6.0
const DASH_GAP := 4.0

var _notice: RedrawNotice
var _rule_y: float = 0.0
var _chip_rect: Rect2 = Rect2()


func _init() -> void:
	name = "RedrawPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = MonitorView.PAPER_RECT.size


## Lays out `shown` (null: empty).
func show_notice(shown: RedrawNotice) -> void:
	_notice = shown
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_chip_rect = Rect2()
	if shown == null:
		queue_redraw()
		return
	var width: float = size.x - 2.0 * PADDING.x
	var title: Label = UiKit.display_label(shown.title, TITLE_SIZE, false)
	title.name = "Title"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(title, Rect2(PADDING, Vector2(width, TITLE_HEIGHT)))
	var left_label: Label = UiKit.display_label("%d left" % shown.left, LEFT_SIZE, false)
	left_label.name = "Left"
	left_label.add_theme_color_override("font_color", Palette.TEAL_SHADE)
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(left_label, Rect2(PADDING, Vector2(width, TITLE_HEIGHT)))
	var y: float = KEY_Y
	if not shown.key.is_empty():
		var key_label: Label = UiKit.body_label(shown.key, KEY_SIZE, Palette.TEAL_SHADE)
		key_label.name = "Key"
		key_label.add_theme_font_override("font", ArtStyle.bold_font(KEY_WEIGHT))
		_add(key_label, Rect2(PADDING.x, y, width, KEY_HEIGHT))
		y += KEY_HEIGHT + LINE_GAP
	elif not shown.going.is_empty():
		_add_row(shown, ROW_Y, width)
		y = ROW_Y + ICON + LINE_GAP
	if not shown.line.is_empty():
		var body: RichTextLabel = _rich(shown.line, LINE_SIZE, Palette.INK)
		body.name = "Line"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_add(body, Rect2(PADDING.x, y, width, LINE_SIZE + 6.0))
	var foot_y: float = size.y - FOOT_BOTTOM - FOOT_HEIGHT
	_rule_y = foot_y - RULE_GAP - RULE
	if not shown.foot.is_empty():
		var color: Color = Palette.TOMATO_DARK if shown.foot_warning else Palette.INK_LIGHT
		var foot: Label = UiKit.body_label(shown.foot, FOOT_SIZE, color)
		foot.name = "Foot"
		foot.add_theme_font_override("font", ArtStyle.bold_font(FOOT_WEIGHT))
		foot.clip_text = true
		_add(foot, Rect2(PADDING.x, foot_y, width, FOOT_HEIGHT))
	queue_redraw()


## The notice shown, or null.
func notice() -> RedrawNotice:
	return _notice


## The going items' icons, a ">", then the coming items' icons or "N new items drawn" and the
## cost chip at the right.
func _add_row(shown: RedrawNotice, y: float, width: float) -> void:
	var x: float = PADDING.x
	for item: CardDefinition in shown.going:
		x = _add_icon(item, x, y)
	var arrow: Label = UiKit.display_label(ARROW_TEXT, ARROW_SIZE, false)
	arrow.name = "Arrow"
	arrow.add_theme_color_override("font_color", Palette.TEAL_SHADE)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	x += ARROW_MARGIN
	_add(arrow, Rect2(x, y, arrow.get_minimum_size().x, ICON))
	x += arrow.size.x + ARROW_MARGIN + ICON_GAP
	if not shown.coming.is_empty():
		for item: CardDefinition in shown.coming:
			x = _add_icon(item, x, y)
		return
	var word: String = "item" if shown.drawn == 1 else "items"
	var drawn: RichTextLabel = _rich(
		"[b]%d new[/b] %s drawn" % [shown.drawn, word], LINE_SIZE, Palette.INK
	)
	drawn.name = "Drawn"
	var chip_width: float = 0.0
	if shown.cost:
		var chip: Label = UiKit.display_label(CHIP_TEXT, CHIP_SIZE, true)
		chip.name = "Cost"
		chip.add_theme_constant_override("outline_size", 0)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(chip)
		chip_width = chip.get_minimum_size().x + 2.0 * (CHIP_PADDING + CHIP_BORDER)
		var chip_x: float = PADDING.x + width - chip_width
		_chip_rect = Rect2(chip_x, y + (ICON - CHIP_HEIGHT) / 2.0, chip_width, CHIP_HEIGHT)
		chip.position = _chip_rect.position
		chip.size = _chip_rect.size
	var text_width: float = PADDING.x + width - chip_width - ICON_GAP - x
	_add(drawn, Rect2(x, y + (ICON - LINE_SIZE - 6.0) / 2.0, text_width, LINE_SIZE + 6.0))


func _add_icon(item: CardDefinition, x: float, y: float) -> float:
	var art: TextureRect = ItemView.item_art(item)
	art.name = "Icon"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(x, y)
	art.scale = Vector2.ONE * (ICON / ItemView.SPRITE_SIZE.x)
	add_child(art)
	return x + ICON + ICON_GAP


## A one-line rich text label in the body font, its [b] in BOLD_WEIGHT.
static func _rich(text: String, font_size: int, color: Color) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", ArtStyle.BODY_FONT)
	label.add_theme_font_override("bold_font", ArtStyle.bold_font(BOLD_WEIGHT))
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.text = text
	return label


func _add(node: Control, rect: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	node.position = rect.position
	node.size = rect.size


## The paper under it all, the cost chip's face (teal in an ink border) and the foot's dashed
## rule.
func _draw() -> void:
	if _notice == null:
		return
	draw_rect(
		Rect2(0, MonitorView.SCREEN_SHADOW, size.x, size.y - MonitorView.SCREEN_SHADOW),
		Palette.PAPER
	)
	if _chip_rect.size.x > 0.0:
		draw_rect(_chip_rect, Palette.INK)
		draw_rect(_chip_rect.grow(-CHIP_BORDER), Palette.TEAL)
	if _notice.foot.is_empty():
		return
	var x: float = PADDING.x
	var end: float = size.x - PADDING.x
	while x < end:
		draw_rect(Rect2(x, _rule_y, minf(DASH, end - x), RULE), Palette.CREAM_SHADE)
		x += DASH + DASH_GAP
