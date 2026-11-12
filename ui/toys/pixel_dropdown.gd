class_name PixelDropdown
extends Control
## A dropdown in hard pixel words (v1.26 round 7; it generalises round 5's SORT dropdown, the user:
## "sort by family can be removed from sort and have its own dropdown"): one teal plate reading its
## prefix and the picked option ("SORT: BOOK ORDER", "FAMILY: [glyph] BAKERY") with a paper arrow at
## its right end, which opens a list in the pixel popup frame (frames/popup.png, the title popups')
## on the plate, above it or (`opens_down`) under it: a plate per option, the picked one's in the
## tomato frames, the marked one lit with the price-gun tick. Every caption is a PixelLine (its
## hyphens drawn, an option's icon before its words), centred on its face with its NEW dot
## (set_options' `dots`: a tomato pip ringed in ink, DOT_GAP after the words); the closed plate
## carries the dot when any option has one. The arrow points to the list while it is open. The mouse
## marks the plate it enters and a click picks it; open_list, Up and Down, Enter or Space and Esc
## are the keys' way (the owner routes them here: handle_key); a click anywhere else in the window
## closes the list and does nothing more (a full-window catcher keeps the mouse off what lies under
## it), but a click on a pass_through control (the other dropdown's plate) closes it and runs that
## control's action (opening the other list), so one click opens the other list. Opening emits
## `opened` (the owner closes any other list), picking emits `picked` and closes the list; the owner
## sets the shown option back with show_value. Nothing moves on its own, so reduced motion needs
## nothing from it. Sizes in canvas px.

signal picked(index: int)
signal opened

## The list: as wide as the plate, LIST_GAP from it; the options OPTION_HEIGHT tall, OPTION_GAP
## apart, LIST_PADDING inside the frame (wide enough at the left for the tick).
const LIST_GAP := 4.0
const LIST_PADDING := Vector2(24, 12)
const OPTION_HEIGHT := 40.0
const OPTION_GAP := 4.0
const FRAME := preload("res://art/frames/popup.png")
const FRAME_MARGIN := 4
## The arrow: ARROW_ROWS rows of art px (5, 3, 1 wide), its right edge ARROW_RIGHT inside the
## face's right edge.
const ARROW_ROWS := 3
const ARROW_RIGHT := 16.0
## The NEW dot: DOT art px square (its tomato core 1 art px in), DOT_GAP art px after the words.
const DOT := 4
const DOT_GAP := 3
## The plates' hover tick, left of a plate (the TOY MACHINES').
const TICK_LEFT := 14.0
## How far a pressed plate sinks under its face (MenuPlate.PLATE_SINK): a list opening down
## keeps clear of it.
const PLATE_SINK_ROOM := MenuPlate.PLATE_SINK
const PICKED_FRAMES: Array[Texture2D] = [
	preload("res://art/frames/button.png"), preload("res://art/frames/button_lit.png")
]
const PLATE_FRAMES: Array[Texture2D] = [
	preload("res://art/frames/button_teal.png"), preload("res://art/frames/button_teal_lit.png")
]

var _prefix: String = ""
var _plate_rect: Rect2
var _opens_down: bool = false
var _captions: Array[String] = []
var _icons: Array[Texture2D] = []
var _dots: Array[bool] = []
var _value: int = 0
var _marked: int = 0
var _plate: MenuPlate
var _plate_line: PixelLine
var _arrow: Control
var _catcher: Control
var _list: Control
var _options: Array[MenuPlate] = []
var _pass_through: Dictionary[Control, Callable] = {}


## A dropdown whose plate fills `plate_rect` and reads `prefix` before the picked option, its
## list opening under the plate when `opens_down` (else above); the control covers `area` (from
## its top left).
func _init(prefix: String, plate_rect: Rect2, opens_down: bool, area: Vector2) -> void:
	_prefix = prefix
	_plate_rect = plate_rect
	_opens_down = opens_down
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = area
	_catcher = Control.new()
	_catcher.name = "Catcher"
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	add_child(_catcher)
	_plate = _make_plate(plate_rect, PLATE_FRAMES)
	_plate.name = "Plate"
	_plate.pressed.connect(_on_plate_pressed)
	_plate.mouse_entered.connect(func() -> void: _plate.marked = true)
	_plate.mouse_exited.connect(func() -> void: _plate.marked = false)
	add_child(_plate)
	_add_arrow()
	_list = Control.new()
	_list.name = "List"
	_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_list.visible = false
	add_child(_list)


## Hidden (the owner or its screen closed, even from code), the list closes, so it never comes
## back open with its catcher eating the first click.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		close_list()


## While the list is open, a mouse press outside the list (and a click outside the plate too) is
## eaten before the GUI sees it, a left or right click closing the list (the wheel, the plate's
## too, does nothing); a left click on a pass_through control then runs its action. (The action is
## run here rather than letting the press through: the control lay under the catcher, so the GUI
## never saw the pointer enter it and the button would not take that first click.)
func _input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if not is_open() or press == null or not press.pressed:
		return
	var click: bool = press.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
	if _hits(_list, press.position) or (click and _hits(_plate, press.position)):
		return
	get_viewport().set_input_as_handled()
	if not click:
		return
	close_list()
	if press.button_index != MOUSE_BUTTON_LEFT:
		return
	for control: Control in _pass_through:
		if control.is_visible_in_tree() and _hits(control, press.position):
			_pass_through[control].call()
			return


## Lays out the options: `captions` (words), each after its icon of `icons` (null or missing:
## none), with a NEW dot where `dots` is true; closes the list and keeps the shown option when
## it is still there (else the first).
func set_options(
	captions: Array[String], icons: Array[Texture2D] = [], dots: Array[bool] = []
) -> void:
	close_list()
	_captions = captions.duplicate()
	_icons = []
	_dots = []
	for index: int in _captions.size():
		_icons.append(icons[index] if index < icons.size() else null)
		_dots.append(dots[index] if index < dots.size() else false)
	for option: MenuPlate in _options:
		_list.remove_child(option)
		option.free()
	_options = []
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	var count: int = _captions.size()
	var height: float = LIST_PADDING.y * 2.0 + count * OPTION_HEIGHT + (count - 1) * OPTION_GAP
	_list.size = Vector2(_plate_rect.size.x + MenuPlate.HOT_SHIFT, height)
	var top: float = _plate_rect.position.y - LIST_GAP - height
	if _opens_down:
		top = _plate_rect.end.y + PLATE_SINK_ROOM + LIST_GAP
	_list.position = Vector2(_plate_rect.position.x, top)
	var frame: PanelContainer = UiKit.frame_panel(FRAME, FRAME_MARGIN)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = _list.size
	_list.add_child(frame)
	var width: float = _list.size.x - LIST_PADDING.x * 2.0
	for index: int in count:
		var row_top: float = LIST_PADDING.y + index * (OPTION_HEIGHT + OPTION_GAP)
		var rect: Rect2 = Rect2(LIST_PADDING.x, row_top, width, OPTION_HEIGHT)
		var option: MenuPlate = _make_plate(rect, PLATE_FRAMES)
		option.name = "Option_%d" % index
		_put_words(option, _tokens(index, false), _dots[index])
		option.pressed.connect(_pick.bind(index))
		option.mouse_entered.connect(_mark.bind(index))
		_list.add_child(option)
		_options.append(option)
	show_value(clampi(_value, 0, maxi(count - 1, 0)))


## A control a left click on which, with the list open, closes the list and runs `action` (the
## other dropdown's plate and its open_list: one click opens that list).
func pass_through(control: Control, action: Callable) -> void:
	_pass_through[control] = action


## Shows option `index` on the plate and as the picked one (no signal).
func show_value(index: int) -> void:
	_value = index
	if index < _captions.size():
		_plate_line = _put_words(_plate, _tokens(index, true), _dots.has(true))
	for option_index: int in _options.size():
		_options[option_index].use_frames(PICKED_FRAMES if option_index == index else PLATE_FRAMES)


func value() -> int:
	return _value


func is_open() -> bool:
	return _list.visible


## Opens the list, the picked option marked; emits `opened`.
func open_list() -> void:
	if is_open():
		return
	Sfx.play_at(self, UiKit.CLICK_SOUND)
	_list.visible = true
	_cover_window()
	_catcher.visible = true
	_mark(_value)
	_arrow.queue_redraw()
	opened.emit()


## Closes the list (no pick).
func close_list() -> void:
	if not is_open():
		return
	_list.visible = false
	_catcher.visible = false
	for option: MenuPlate in _options:
		option.marked = false
	_arrow.queue_redraw()


## The keys while the list is open: Up and Down move the mark (wrapping), Enter or Space picks
## the marked option, Esc or Backspace closes it; every other key does nothing. Closed, Enter (or
## Space) opens it. True when the key was the dropdown's.
func handle_key(keycode: Key) -> bool:
	var enter: bool = keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if not is_open():
		if enter:
			open_list()
		return enter
	match keycode:
		KEY_UP, KEY_DOWN:
			var step: int = 1 if keycode == KEY_DOWN else -1
			_mark(posmod(_marked + step, _options.size()))
		KEY_ESCAPE, KEY_BACKSPACE:
			close_list()
		_:
			if enter:
				_pick(_marked)
	return true


## The marked option's index (the keys' and the mouse's).
func marked() -> int:
	return _marked


## The pieces, for tests and the screen capture: the plate, the list, the option plates, the
## arrow, the plate's words and an option's words (PixelLines) and whether a dot is shown.
func plate() -> MenuPlate:
	return _plate


func list() -> Control:
	return _list


func options() -> Array[MenuPlate]:
	return _options


func arrow() -> Control:
	return _arrow


func caption_line() -> PixelLine:
	return _plate_line


func option_line(index: int) -> PixelLine:
	return _options[index].find_child("Words", true, false) as PixelLine


## The NEW dot of option `index`, or of the plate (-1); null when it shows none.
func dot(index: int = -1) -> Control:
	var host: MenuPlate = _plate if index < 0 else _options[index]
	return host.find_child("Dot", true, false) as Control


func _make_plate(rect: Rect2, frames: Array[Texture2D]) -> MenuPlate:
	var made: MenuPlate = MenuPlate.new("", MenuPlate.Kind.PLATE, rect.size)
	made.use_frames(frames)
	made.position = rect.position
	made.tick().position.x = -TICK_LEFT
	return made


## The words of option `index`: its icon and caption, after the prefix on the plate.
func _tokens(index: int, on_plate: bool) -> Array:
	var tokens: Array = []
	if on_plate and not _prefix.is_empty():
		tokens.append(_prefix)
	if _icons[index] != null:
		tokens.append(_icons[index])
	tokens.append(_captions[index])
	return tokens


## Puts `tokens` in paper on `host`'s face (replacing its words), with the NEW dot after them
## when `with_dot`; the pair centred on the face (between its pale top row and its shade row and
## ledge), on the 2 px grid. Returns the words.
func _put_words(host: MenuPlate, tokens: Array, with_dot: bool) -> PixelLine:
	var art: float = ArtStyle.ART_SCALE
	var content: Node = host.caption_label().get_parent()
	for old: String in ["Words", "Dot"]:
		var found: Node = content.get_node_or_null(old)
		if found != null:
			content.remove_child(found)
			found.free()
	var line: PixelLine = PixelLine.new()
	line.name = "Words"
	line.show_tokens(tokens, Palette.PAPER, Palette.PAPER)
	var face: Vector2 = host.face_size()
	var group: float = line.width() + ((DOT_GAP + DOT) * art if with_dot else 0.0)
	var room: float = face.y - MenuPlate.PLATE_FACE_TOP - MenuPlate.PLATE_FACE_BOTTOM
	var top: float = MenuPlate.PLATE_FACE_TOP + (room - line.size.y) / 2.0
	line.position = Vector2(art * floorf((face.x - group) / 2.0 / art), art * floorf(top / art))
	content.add_child(line)
	if with_dot:
		var pip: ColorRect = ColorRect.new()
		pip.name = "Dot"
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = Palette.INK
		pip.size = Vector2(DOT, DOT) * art
		pip.position = Vector2(
			line.position.x + line.width() + DOT_GAP * art,
			line.position.y + floorf((line.size.y - pip.size.y) / 2.0 / art) * art
		)
		var core: ColorRect = ColorRect.new()
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		core.color = Palette.TOMATO
		core.position = Vector2(art, art)
		core.size = Vector2(DOT - 2, DOT - 2) * art
		pip.add_child(core)
		content.add_child(pip)
	return line


## The arrow on the plate's face: pointing down, up while the list is open; in paper.
func _add_arrow() -> void:
	var art: float = ArtStyle.ART_SCALE
	_arrow = Control.new()
	_arrow.name = "Arrow"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(ARROW_ROWS * 2 - 1, ARROW_ROWS) * art
	var face: Vector2 = _plate.face_size()
	var lift: float = MenuPlate.PLATE_FACE_TOP - MenuPlate.PLATE_FACE_BOTTOM
	var top_left: Vector2 = Vector2(
		face.x - ARROW_RIGHT - _arrow.size.x, (face.y + lift - _arrow.size.y) / 2.0
	)
	_arrow.position = (top_left / art).floor() * art
	_arrow.draw.connect(
		func() -> void:
			for row: int in ARROW_ROWS:
				var shown_row: int = ARROW_ROWS - 1 - row if is_open() else row
				var cells: int = (ARROW_ROWS - row) * 2 - 1
				var rect: Rect2 = Rect2(Vector2(row, shown_row) * art, Vector2(cells, 1) * art)
				_arrow.draw_rect(rect, Palette.PAPER)
	)
	_plate.caption_label().get_parent().add_child(_arrow)


func _mark(index: int) -> void:
	_marked = index
	for option_index: int in _options.size():
		_options[option_index].marked = option_index == index


func _pick(index: int) -> void:
	close_list()
	picked.emit(index)


func _on_plate_pressed() -> void:
	if is_open():
		close_list()
	else:
		open_list()


## The catcher over the whole window (the stage is centred unscaled in a bigger one), so no
## control under the open list takes the mouse, the stage's margins included.
func _cover_window() -> void:
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var window: Rect2 = get_viewport().get_visible_rect()
	_catcher.position = to_local * window.position
	_catcher.size = window.size


## Whether viewport point `at` lies on `control` (in the canvas, as the GUI picks it).
static func _hits(control: Control, at: Vector2) -> bool:
	var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * at
	return Rect2(Vector2.ZERO, control.size).has_point(local)
