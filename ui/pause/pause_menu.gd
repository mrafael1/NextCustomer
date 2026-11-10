class_name PauseMenu
extends Control
## The shift's pause (mock-up options_pause.html, direction A): a ScreenShade in ink at 72 % over
## the whole window with its hole on the ☰ button, and a column of MenuPlates stepping in like the
## title's: RESUME (primary, its sub-line the shift and phase), OPTIONS, HOW TO PLAY and
## SAVE & QUIT, the marked plate's note under them in the body font, and a small EXPORT LOG link.
##
## The column stands in the dimmed space right of the register column, under the sign's place,
## so the receipt, the target and the CHECKOUT key stay clear and the note never runs over the
## key (the mock-up had them over the receipt). It runs while the tree is paused
## (PROCESS_MODE_ALWAYS); its owner (PauseFlow) pauses the tree. Up / Down / Enter work as on the
## title; Esc, P or the ☰ button resume.

signal resume_pressed
signal options_pressed
signal guide_pressed
signal quit_pressed
signal export_pressed
## A key nothing else took (its owner opens, drives or closes the pause with it).
signal key_event(event: InputEvent)

enum Entry { RESUME, OPTIONS, GUIDE, QUIT }

## The shade's colour: palette ink at 72 %.
const SHADE := Color(Palette.INK, 0.72)
## The column's left edge from the middle of the space right of the register column, and its
## plates' tops from the window's vertical middle (at 1280x720: x 656, y 344 / 440 / 496 / 552).
const REGISTER_COLUMN := 336.0
const PLATE_TOPS: Array[float] = [-16.0, 80.0, 136.0, 192.0]
const NOTE_GAP := 16.0
const NOTE_FONT := 14
const CAPTIONS: Array[String] = ["RESUME", "OPTIONS", "HOW TO PLAY", "SAVE & QUIT"]
const NOTES: Array[String] = [
	"Back to the shift, everything where it was.",
	"Display, sound, text size, motion and count-up speed.",
	"The staff handbook: controls, terms and families.",
	"",
]
const EXPORT_TEXT := "EXPORT LOG"

## Shows the plates at once (reduced motion).
var still: bool = false
## SAVE & QUIT's note: where CONTINUE will bring the player back.
var quit_note: String = ""

var _shade: ScreenShade
var _sign: LaneClosedSign
var _column: Control
var _plates: Array[MenuPlate] = []
var _note: Label
var _export: Control
var _marked: int = -1
var _stepping: Tween


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_shade = ScreenShade.new()
	_shade.color = SHADE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	_sign = LaneClosedSign.new()
	add_child(_sign)
	_column = Control.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	for i: int in CAPTIONS.size():
		var primary: bool = i == Entry.RESUME
		var entry_plate: MenuPlate = MenuPlate.new(
			CAPTIONS[i], MenuPlate.Kind.PRIMARY if primary else MenuPlate.Kind.PLATE
		)
		entry_plate.position = Vector2(0, PLATE_TOPS[i] - PLATE_TOPS[0])
		entry_plate.mouse_entered.connect(mark.bind(i))
		entry_plate.pressed.connect(activate.bind(i))
		_column.add_child(entry_plate)
		_plates.append(entry_plate)
	var esc: Label = UiKit.pixel_label("ESC", 2, Palette.TOMATO_PALE)
	UiKit.place_pixel_label(esc, Rect2(MenuPlate.PRIMARY_SIZE.x - 50, 22, 0, 0))
	_plates[Entry.RESUME].add_child(esc)
	_note = UiKit.body_label("", NOTE_FONT, Palette.TEAL_PALE)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_note)
	_export = _export_link()
	_column.add_child(_export)
	resized.connect(_place)


func is_open() -> bool:
	return visible


func plate(entry: Entry) -> MenuPlate:
	return _plates[entry]


func note_label() -> Label:
	return _note


func export_link() -> Control:
	return _export


func shade() -> ScreenShade:
	return _shade


func lane_sign() -> LaneClosedSign:
	return _sign


func marked_entry() -> int:
	return _marked


## Opens the pause with RESUME's sub-line `sub_line`, the shade's hole on `hole` (the ☰ button,
## global). The plates step in unless `still`.
func open(sub_line: String, hole: Rect2) -> void:
	visible = true
	_plates[Entry.RESUME].sub_line = sub_line
	_shade.set_hole(hole)
	_note.add_theme_font_size_override("font_size", UiKit.text_size(NOTE_FONT))
	_place()
	_sign.drop(still)
	mark(Entry.RESUME)
	if _stepping != null:
		_stepping.kill()
	if still:
		for each: MenuPlate in _plates:
			_slide(1.0, each)
		return
	_stepping = create_tween().set_parallel()
	for i: int in _plates.size():
		_slide(0.0, _plates[i])
		_stepping.tween_method(_slide.bind(_plates[i]), 0.0, 1.0, TitleMenu.SLIDE_TIME).set_delay(
			i * TitleMenu.STEP_DELAY
		)


func close() -> void:
	if _stepping != null:
		_stepping.kill()
		_stepping = null
	visible = false


func mark(entry: int) -> void:
	_marked = entry
	for i: int in _plates.size():
		_plates[i].marked = i == entry
	_note.text = quit_note if entry == Entry.QUIT else NOTES[maxi(entry, 0)]


func activate(entry: int) -> void:
	match entry:
		Entry.RESUME:
			resume_pressed.emit()
		Entry.OPTIONS:
			options_pressed.emit()
		Entry.GUIDE:
			guide_pressed.emit()
		Entry.QUIT:
			quit_pressed.emit()


## A key while the pause is open and nothing is over it: Up / Down / Enter on the plates; Esc and
## P resume. True when the key was the pause's.
func handle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if not visible or key == null or not key.pressed:
		return false
	match key.keycode:
		KEY_DOWN:
			mark(posmod(_marked + 1, _plates.size()))
		KEY_UP:
			mark(posmod(_marked - 1, _plates.size()))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not key.echo:
				activate(_marked)
		KEY_ESCAPE, KEY_P:
			if not key.echo:
				resume_pressed.emit()
		_:
			return false
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	key_event.emit(event)


## A click in the shade's hole is a click on the ☰ button under it: it resumes.
func _on_shade_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_shade.accept_event()
	if _shade.hole().has_point(_shade.get_global_transform() * click.position):
		resume_pressed.emit()


func _place() -> void:
	var left: float = (
		2.0 * roundf(((size.x + REGISTER_COLUMN) / 2.0 - MenuPlate.PRIMARY_SIZE.x / 2.0) / 2.0)
	)
	var top: float = 2.0 * roundf((size.y / 2.0 + PLATE_TOPS[0]) / 2.0)
	_column.position = Vector2(left, top)
	var last: MenuPlate = _plates[Entry.QUIT]
	_note.position = Vector2(2, last.position.y + MenuPlate.PLATE_SIZE.y + NOTE_GAP)
	_note.size = Vector2(MenuPlate.PRIMARY_SIZE.x, 0)
	var link_top: float = size.y - top - 36.0
	_export.position = Vector2(0, link_top)


## The EXPORT LOG link: small pixel words that light under the mouse.
func _export_link() -> Control:
	var link: Control = Control.new()
	link.mouse_filter = Control.MOUSE_FILTER_STOP
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var words: Label = UiKit.pixel_label(EXPORT_TEXT, 2, Palette.TEAL_PALE)
	UiKit.place_pixel_label(words, Rect2(0, 0, 0, 0))
	link.add_child(words)
	link.size = Vector2(OptionChip.pixel_width(EXPORT_TEXT, 2), 28)
	link.mouse_entered.connect(
		func() -> void: words.add_theme_color_override("font_color", Palette.PAPER)
	)
	link.mouse_exited.connect(
		func() -> void: words.add_theme_color_override("font_color", Palette.TEAL_PALE)
	)
	link.gui_input.connect(
		func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				link.accept_event()
				export_pressed.emit()
	)
	return link


## `slid_plate` `share` (0 to 1) of the way through its slide (the title's step in).
func _slide(share: float, slid_plate: MenuPlate) -> void:
	slid_plate.visible = share > 0.0
	var left: float = TitleMenu.SLIDE * (1.0 - share)
	slid_plate.position.x = -TitleMenu.SLIDE_STEP * roundf(left / TitleMenu.SLIDE_STEP)
