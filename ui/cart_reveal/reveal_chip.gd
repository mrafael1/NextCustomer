class_name RevealChip
extends Control
## A small flat badge of the cart reveal (mock-up cart_reveal_v1.html, v0.51): a fill with a 2 px
## ink outline outside it (and an optional ledge under it), and an optional 2x pixel-art icon
## and/or a short text centred on it: the staples' padlock, a pick's "+", the coupon's token, the
## COUPON tab, a staple's 2nd copy "×2", the summary's icons and the CART chip. The Cart page's
## staple and pick marks use it too (DeckView).

## The outline's width, outside the chip's rect, and the ledge's drop under it.
const OUTLINE := 2.0
const LEDGE := 4.0
## The gap between the icon and the text.
const ICON_GAP := 3.0

var fill: Color = Palette.MUSTARD:
	set(value):
		fill = value
		queue_redraw()
## The ledge's colour under the chip (none when transparent).
var ledge: Color = Color.TRANSPARENT:
	set(value):
		ledge = value
		queue_redraw()
## The padding each side of a text chip's content.
var pad: float = 4.0:
	set(value):
		pad = value
		_lay_out()
var _least: Vector2
var _wanted: Vector2
var _icon: TextureRect
var _label: Label


## A chip of `chip_size` filled with `color`; `icon` (drawn at 2x, centred) and `text` are
## optional. A chip with text grows to fit them (`chip_size` is its least size).
func _init(
	color: Color,
	chip_size: Vector2,
	icon: Texture2D = null,
	text: String = "",
	font_size: int = 13,
	text_color: Color = Palette.INK
) -> void:
	fill = color
	_least = chip_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = chip_size
	if icon != null:
		_icon = UiKit.sprite(icon)
		_icon.size = icon.get_size() * ArtStyle.ART_SCALE
		add_child(_icon)
	if not text.is_empty():
		_label = UiKit.body_label(text, font_size, text_color)
		_label.add_theme_font_override("font", CartReveal.font(800))
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		# The text's width is known for sure once the label is in the tree.
		_label.minimum_size_changed.connect(_lay_out)
	_lay_out()


## Sets the chip's text (a chip made with text), growing it to fit; its left edge stays.
func set_text(text: String) -> void:
	if _label == null or _label.text == text:
		return
	_label.text = text
	_lay_out()


## The chip's label (for tests), or null.
func text_label() -> Label:
	return _label


## The chip's icon (for tests), or null.
func icon_rect() -> TextureRect:
	return _icon


## The chip's rect with its outline and ledge, in its parent's coordinates (for tests).
func outer_rect() -> Rect2:
	var rect: Rect2 = Rect2(position, size).grow(OUTLINE)
	if ledge.a > 0.0:
		rect.size.y += LEDGE
	return rect


func _get_minimum_size() -> Vector2:
	return _wanted


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY or what == NOTIFICATION_THEME_CHANGED:
		_lay_out()


func _lay_out() -> void:
	var content: float = 0.0
	if _icon != null:
		content += _icon.size.x
	var text_width: float = 0.0
	_wanted = _least
	if _label != null:
		text_width = _label.get_minimum_size().x
		content += text_width + (ICON_GAP if _icon != null else 0.0)
		_wanted.x = maxf(_least.x, ceilf(content + pad * 2.0))
	update_minimum_size()
	size = _wanted
	pivot_offset = size / 2.0
	var x: float = roundf((size.x - content) / 2.0)
	if _icon != null:
		_icon.position = Vector2(x, roundf((size.y - _icon.size.y) / 2.0))
		x += _icon.size.x + ICON_GAP
	if _label != null:
		_label.position = Vector2(x, 0)
		_label.size = Vector2(text_width, size.y)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if ledge.a > 0.0:
		draw_rect(Rect2(rect.position + Vector2(0, LEDGE), rect.size).grow(OUTLINE), ledge)
	draw_rect(rect.grow(OUTLINE), Palette.INK)
	draw_rect(rect, fill)
