class_name TitlePopup
extends Control
## A popup over the title (#56, mock-up title_premium_directions.html, direction C+): the whole
## window dimmed in teal black (DIM), and a sheet in the pixel popup frame (frames/popup.png, a
## paper face with a gold inner trim) centred on it, on the 640x360 art grid at 2x. The REWARDS
## menu and the New run question (RewardsMenu, AbandonConfirm) are popups; the dim takes every
## click, so nothing behind it can be pressed while one is open.
##
## It steps in: the sheet fades in OPEN_STEPS steps over OPEN_TIME as it rises OPEN_DROP art px
## into place (the mock-up's stepFrac). `still` (the profile's reduced motion) shows it at once.
## It closes at once. Its entries are lit by one marker that the mouse and the keys share
## (Up, Down, Left and Right move it; Enter or Space presses the marked entry; Esc cancels), so
## the mouse and the keyboard never light two entries.

## The popup was closed (by a key, an entry or close()).
signal closed

const FRAME := preload("res://art/frames/popup.png")
const FRAME_MARGIN := 4
## The dim over the title: the night's teal black, at the mock-up's 78 %.
const DIM := Color(Palette.TEAL_BLACK, 0.78)
const OPEN_TIME := 0.18
const OPEN_STEPS := 3
const OPEN_DROP := 8

## Shows the popup at once, with no step in (the profile's reduced motion).
var still: bool = false

var _sheet: Control
var _sheet_size: Vector2
## The sheet's rise still to go (canvas px below its place, on the 2 px grid) while it steps in.
var _drop: float = 0.0
var _opening: Tween
## The entries in key order, and the marked one's index (-1: none).
var _entries: Array[Control] = []
var _marked: int = -1


## A popup whose sheet is `sheet_art` art px.
func _init(sheet_art: Vector2i) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_sheet_size = Vector2(sheet_art) * ArtStyle.ART_SCALE
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.size = _sheet_size
	add_child(_sheet)
	var frame: PanelContainer = UiKit.frame_panel(FRAME, FRAME_MARGIN)
	frame.size = _sheet_size
	_sheet.add_child(frame)
	resized.connect(_place_sheet)


## The sheet the popup's content goes on, in canvas px from its top left.
func sheet() -> Control:
	return _sheet


func is_open() -> bool:
	return visible


## The marked entry, or null.
func marked() -> Control:
	return _entries[_marked] if _marked >= 0 else null


## Moves the marker `step` entries on (wrapping); from no marker, Down starts on the first and
## Up on the last.
func move_marker(step: int) -> void:
	if _entries.is_empty():
		return
	if _marked < 0:
		_set_marked(0 if step > 0 else _entries.size() - 1)
	else:
		_set_marked(posmod(_marked + step, _entries.size()))


## A key while the popup is open: the arrows move the marker, Enter or Space presses the marked
## entry (none marked: nothing), Esc cancels. True when the key was the popup's.
func handle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if not is_open() or key == null or not key.pressed:
		return false
	match key.keycode:
		KEY_DOWN, KEY_RIGHT:
			move_marker(1)
		KEY_UP, KEY_LEFT:
			move_marker(-1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _marked >= 0 and not key.echo:
				_press(_entries[_marked])
		KEY_ESCAPE:
			if not key.echo:
				_cancel()
		_:
			return false
	return true


## Hides the popup at once and clears the marker.
func close() -> void:
	if _opening != null:
		_opening.kill()
		_opening = null
	_set_marked(-1)
	visible = false
	closed.emit()


## Shows the popup, stepping it in unless `still`, and clears the marker. Returns the step-in
## (null when still).
func _show_popup() -> Tween:
	_set_marked(-1)
	visible = true
	if _opening != null:
		_opening.kill()
		_opening = null
	if still:
		_open_share(1.0)
		return null
	_open_share(0.0)
	_opening = create_tween()
	_opening.tween_method(_open_share, 0.0, 1.0, OPEN_TIME)
	return _opening


## Adds `entry` to the key order: the mouse on it marks it, leaving it unmarks it.
func _add_entry(entry: Control) -> void:
	_entries.append(entry)
	entry.mouse_entered.connect(func() -> void: _set_marked(_entries.find(entry)))
	entry.mouse_exited.connect(
		func() -> void:
			if _marked == _entries.find(entry):
				_set_marked(-1)
	)


## Shows the marker on entry `index` (-1: none). Popups light their entries in _show_marked.
func _set_marked(index: int) -> void:
	_marked = index
	for i: int in _entries.size():
		_show_marked(_entries[i], i == index)


## Lights `entry` (marked) or not; the popup's own entries say how.
func _show_marked(_entry: Control, _on: bool) -> void:
	pass


## Presses `entry` (Enter or Space on the marked one).
func _press(_entry: Control) -> void:
	pass


## Esc: the popup's cancel (closes it by default).
func _cancel() -> void:
	close()


## The step-in at `share` (0 to 1), in OPEN_STEPS steps: the sheet's opacity and its rise.
func _open_share(share: float) -> void:
	var stepped: float = floorf(share * OPEN_STEPS) / OPEN_STEPS
	_sheet.modulate.a = stepped
	_drop = roundf((1.0 - stepped) * OPEN_DROP) * ArtStyle.ART_SCALE
	_place_sheet()


## The sheet centred on the window (like the storefront's stage, so it keeps the art grid), plus
## the rise still to go.
func _place_sheet() -> void:
	_sheet.position = ((size - _sheet_size) / 2.0).floor() + Vector2(0.0, _drop)
