class_name RedrawTag
extends Control
## The teal REDRAW tag on a basket's front in redraw mode (plan section 3.8; mock-up
## redraw_basket_v1.html, approved by the user on 2026-10-22): a TAG_HEIGHT px tag, a teal face in
## a BORDER px ink border with a BAND px teal shade band inside its foot and a hard ink drop shadow,
## the round redraw arrow (art/src/icons/redraw_arrow.txt, shown at 2x) and the word in paper with
## a teal dark shadow. Hovered (set_hot), it names how many items go ("REDRAW 2" / "REDRAW 1"),
## turns teal light with ink text and an ink arrow, and wears a RING px gold ring. It sizes itself
## to its text; BasketTags centres it on its basket. Display only: it takes no clicks.

const TAG_HEIGHT := 30.0
const BORDER := 2.0
const BAND := 3.0
const PADDING := 8.0
const SHADOW := Vector2(2, 2)
const SHADOW_ALPHA := 0.45
const RING := 3.0
const FONT_SIZE := 12
const LETTER_SPACING := 1
const ARROW_SIZE := Vector2(18, 16)
const ARROW_GAP := 5.0
const WORD := "REDRAW"
const ARROW := preload("res://art/icons/redraw_arrow.png")
const ARROW_HOT := preload("res://art/icons/redraw_arrow_hot.png")

var _hot: bool = false
var _arrow: TextureRect
var _label: Label


func _init() -> void:
	name = "RedrawTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow = UiKit.sprite(ARROW)
	_arrow.name = "Arrow"
	_arrow.size = ARROW_SIZE
	add_child(_arrow)
	_label = UiKit.display_label(WORD, FONT_SIZE, false)
	_label.name = "Word"
	_label.add_theme_font_override("font", ArtStyle.spaced_display_font(LETTER_SPACING))
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.add_theme_constant_override("shadow_outline_size", 0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.minimum_size_changed.connect(_lay_out)
	set_hot(false, 0)


## Hovered (`hot`, naming `count` items: "REDRAW 2" or "REDRAW 1"), or at rest ("REDRAW").
func set_hot(hot: bool, count: int) -> void:
	_hot = hot
	_label.text = "%s %d" % [WORD, count] if hot and count > 0 else WORD
	_arrow.texture = ARROW_HOT if hot else ARROW
	_label.add_theme_color_override("font_color", Palette.INK if hot else Palette.PAPER)
	var shadow: Color = Color(Palette.TEAL_DARK, 0.0 if hot else 1.0)
	_label.add_theme_color_override("font_shadow_color", shadow)
	_lay_out()


func is_hot() -> bool:
	return _hot


## The word on the tag ("REDRAW", "REDRAW 2" or "REDRAW 1").
func text() -> String:
	return _label.text


func word_label() -> Label:
	return _label


func arrow() -> TextureRect:
	return _arrow


## The tag's width for its text: the border, the padding, the arrow, the gap and the word.
func tag_width() -> float:
	var word: float = _label.get_minimum_size().x
	return roundf(2.0 * (BORDER + PADDING) + ARROW_SIZE.x + ARROW_GAP + word)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_lay_out()  # A label measures with its real font only in the tree.


func _lay_out() -> void:
	size = Vector2(tag_width(), TAG_HEIGHT)
	var inner: float = TAG_HEIGHT - 2.0 * BORDER - BAND
	var left: float = BORDER + PADDING
	_arrow.position = Vector2(left, roundf(BORDER + (inner - ARROW_SIZE.y) / 2.0))
	_label.position = Vector2(left + ARROW_SIZE.x + ARROW_GAP, BORDER)
	_label.size = Vector2(_label.get_minimum_size().x, inner)
	queue_redraw()


## The gold ring (hovered), the drop shadow, the ink border, the face and its shade band.
func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if _hot:
		draw_rect(rect.grow(RING), Palette.GOLD)
	draw_rect(Rect2(SHADOW, size), Color(Palette.INK, SHADOW_ALPHA))
	draw_rect(rect, Palette.INK)
	var face: Rect2 = rect.grow(-BORDER)
	draw_rect(face, Palette.TEAL_LIGHT if _hot else Palette.TEAL)
	var band: Rect2 = Rect2(face.position.x, face.end.y - BAND, face.size.x, BAND)
	draw_rect(band, Palette.TEAL if _hot else Palette.TEAL_SHADE)
