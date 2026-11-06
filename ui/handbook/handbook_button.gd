class_name HandbookButton
extends Control
## A clickable part of the staff handbook (v1.06): a tab on the binder's top edge (TAB: its name
## in hard pixel words on a cream shade tab; the picked one cream like the page it opens, its foot
## open onto it), an index row (ROW: the entry's mark and title; the picked one mustard pale in an
## ink box, the hovered one cream) or the CLOSE plate. pressed on a left click.

signal pressed

enum Kind { TAB, ROW, CLOSE }

const BORDER := 2.0
const TEXT_SCALE := 2
const ROW_TITLE_SIZE := 16
const ROW_PADDING := 8.0
const MARK_ROOM := 44.0

var kind: Kind = Kind.ROW
var picked: bool = false:
	set(value):
		picked = value
		queue_redraw()
var _hovered: bool = false
var _label: Label


## A `button_kind` button reading `text`, `button_size` big; a ROW shows `mark` before it.
func _init(button_kind: Kind, text: String, button_size: Vector2, mark: Control = null) -> void:
	kind = button_kind
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = button_size
	custom_minimum_size = button_size
	if kind == Kind.ROW:
		if mark != null:
			mark.position = Vector2(
				ROW_PADDING + roundf((MARK_ROOM - mark.custom_minimum_size.x) / 2.0),
				roundf((button_size.y - mark.custom_minimum_size.y) / 2.0)
			)
			add_child(mark)
		_label = UiKit.body_label(text, ROW_TITLE_SIZE, Palette.INK)
		_label.add_theme_font_override("font", ArtStyle.bold_font(700))
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.position = Vector2(ROW_PADDING * 2.0 + MARK_ROOM, 0)
		_label.size = Vector2(button_size.x - _label.position.x - ROW_PADDING, button_size.y)
		_label.clip_text = true
	else:
		_label = UiKit.pixel_label(text, TEXT_SCALE, Palette.INK)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiKit.place_pixel_label(_label, Rect2(Vector2.ZERO, button_size), true)
	_label.name = "Text"
	add_child(_label)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


func caption() -> String:
	return _label.text


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sfx.play_at(self, UiKit.CLICK_SOUND)
		pressed.emit()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	match kind:
		Kind.TAB:
			var face: Color = Palette.CREAM if picked else Palette.CREAM_SHADE
			if _hovered and not picked:
				face = Palette.MUSTARD_PALE
			draw_rect(rect, Palette.INK)
			var inner: Rect2 = Rect2(BORDER, BORDER, size.x - BORDER * 2.0, size.y - BORDER)
			if picked:
				inner.size.y += BORDER
			draw_rect(inner, face)
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, BORDER)), Palette.PAPER)
		Kind.CLOSE:
			draw_rect(rect, Palette.INK)
			var lit: Color = Palette.TOMATO_LIGHT if _hovered else Palette.TOMATO_PALE
			draw_rect(rect.grow(-BORDER), lit)
		Kind.ROW:
			if picked:
				draw_rect(rect, Palette.INK)
				draw_rect(rect.grow(-BORDER), Palette.MUSTARD_PALE)
			elif _hovered:
				draw_rect(rect, Palette.CREAM_SHADE)
