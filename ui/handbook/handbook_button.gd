class_name HandbookButton
extends Control
## A clickable part of the staff handbook (v1.06; the guide polish of 2026-11-11 dresses it in the
## game's pixel art): a binder index tab on the board's top edge (TAB: its name in hard pixel words
## on a teal tab, frames/handbook_tab, tucked under the board; the picked one paper,
## handbook_tab_picked, in front of the board and TAB_RISE px taller, its name in ink), a contents
## row on the index's receipt (ROW: the entry's mark and title over a dashed receipt rule; the
## picked one on a mustard pale band with the tomato price-gun tick at its left, as the title's
## menu marks its plate; the hovered one cream) or the CLOSE key (the primary tomato button,
## frames/button, lit under the pointer). pressed on a left click.

signal pressed

enum Kind { TAB, ROW, CLOSE }

const BORDER := 2.0
const TEXT_SCALE := 2
const ROW_TITLE_SIZE := 16
const ROW_PADDING := 8.0
## The room before a row's title for its mark (a wider mark, the MORNING chip, widens it: the
## page passes the widest mark of the tab).
const MARK_ROOM := 44.0
## The picked row's price-gun tick (5x7 art at 2x), TICK_LEFT in from the row's left edge.
const TICK := preload("res://art/icons/tick_marker.png")
const TICK_SIZE := Vector2(10, 14)
const TICK_LEFT := 4.0
## The receipt's dashed rule under a row: DASH px on, DASH px off, in grey light.
const DASH := 4.0
## A picked tab stands TAB_RISE px taller than the others (the page lifts it).
const TAB_RISE := 6.0
const TAB_FRAME := preload("res://art/frames/handbook_tab.png")
const TAB_PICKED_FRAME := preload("res://art/frames/handbook_tab_picked.png")
const TAB_MARGIN := 3
const CLOSE_FRAME := preload("res://art/frames/button.png")
const CLOSE_LIT_FRAME := preload("res://art/frames/button_lit.png")
const NEWLINE := "\n"

var kind: Kind = Kind.ROW
var picked: bool = false:
	set(value):
		picked = value
		_show_state()
var _hovered: bool = false
var _label: Label
var _tick: TextureRect


## A `button_kind` button reading `text`, `button_size` big; a ROW shows `mark` before it, in
## `mark_room` px.
func _init(
	button_kind: Kind,
	text: String,
	button_size: Vector2,
	mark: Control = null,
	mark_room: float = MARK_ROOM
) -> void:
	kind = button_kind
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = button_size
	custom_minimum_size = button_size
	if kind == Kind.ROW:
		_tick = UiKit.sprite(TICK)
		_tick.name = "Tick"
		_tick.size = TICK_SIZE
		_tick.position = Vector2(TICK_LEFT, roundf((button_size.y - TICK_SIZE.y) / 4.0) * 2.0)
		_tick.visible = false
		add_child(_tick)
		var mark_left: float = TICK_LEFT + TICK_SIZE.x + ROW_PADDING / 2.0
		if mark != null:
			mark.position = Vector2(
				mark_left + roundf((mark_room - mark.custom_minimum_size.x) / 2.0),
				roundf((button_size.y - mark.custom_minimum_size.y) / 2.0)
			)
			add_child(mark)
		_label = UiKit.body_label(text, ROW_TITLE_SIZE, Palette.INK)
		_label.add_theme_font_override("font", ArtStyle.bold_font(700))
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.position = Vector2(mark_left + mark_room + ROW_PADDING, 0)
		_label.size = Vector2(button_size.x - _label.position.x - ROW_PADDING, button_size.y)
		_label.clip_text = true
	else:
		ArtStyle.use_pixel_material(self)
		_label = UiKit.pixel_label(text, TEXT_SCALE, Palette.PAPER)
		centre_words(_label, _text_rect())
	_label.name = "Text"
	add_child(_label)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_show_state()


## Puts the pixel words `words` centred in `rect` (its parent's px), on the art grid: their drawn
## width is the pixel font's (a Label's minimum size runs wider, and a Label never shrinks under
## it, so its own centring would lean right).
static func centre_words(words: Label, rect: Rect2) -> void:
	var drawn: float = words_width(words)
	var left: float = rect.position.x + (rect.size.x - drawn) / 2.0
	left = roundf(left / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.place_pixel_label(words, Rect2(left, rect.position.y, drawn, rect.size.y), true)


## The drawn width of pixel words `words`' widest line, in canvas px.
static func words_width(words: Label) -> float:
	var widest: float = 0.0
	for line: String in words.text.split(NEWLINE):
		var line_size: Vector2 = ArtStyle.pixel_display_font().get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_TEXT_SIZE
		)
		widest = maxf(widest, ceilf(line_size.x * words.scale.x))
	return widest


func caption() -> String:
	return _label.text


## The picked row's price-gun tick (null for a tab or CLOSE).
func tick() -> TextureRect:
	return _tick


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sfx.play_at(self, UiKit.CLICK_SOUND)
		pressed.emit()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_show_state()


## The text's colour, the tick and the redraw for the state.
func _show_state() -> void:
	if _label == null:
		return
	match kind:
		Kind.TAB:
			_label.add_theme_color_override("font_color", Palette.INK if picked else Palette.PAPER)
		Kind.ROW:
			_tick.visible = picked
	queue_redraw()


## A tab's or CLOSE's text box: the face above its ledge (a tab has none: its foot is tucked).
func _text_rect() -> Rect2:
	var ledge: float = 0.0 if kind == Kind.TAB else FramedButton.PRESS_DEPTH
	var top: float = BORDER * 2.0 if kind == Kind.TAB else 0.0
	return Rect2(0, top, size.x, size.y - top - ledge)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	match kind:
		Kind.TAB:
			var frame: Texture2D = TAB_PICKED_FRAME if picked else TAB_FRAME
			draw_style_box(ArtStyle.frame_style(frame, TAB_MARGIN), rect)
			if _hovered and not picked:
				draw_rect(rect.grow(-BORDER * 2.0), Color(Palette.PAPER, 0.18))
		Kind.CLOSE:
			var lit: Texture2D = CLOSE_LIT_FRAME if _hovered else CLOSE_FRAME
			draw_style_box(ArtStyle.frame_style(lit, FramedButton.FRAME_MARGIN), rect)
		Kind.ROW:
			if picked:
				draw_rect(rect, Palette.MUSTARD_PALE)
				draw_rect(Rect2(0, size.y - BORDER, size.x, BORDER), Palette.MUSTARD)
			elif _hovered:
				draw_rect(rect, Palette.CREAM)
			if not picked:
				var x: float = 0.0
				while x < size.x:
					var dash: float = minf(DASH, size.x - x)
					draw_rect(Rect2(x, size.y - BORDER, dash, BORDER), Palette.GREY_LIGHT)
					x += DASH * 2.0
