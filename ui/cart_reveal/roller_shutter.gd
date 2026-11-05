class_name RollerShutter
extends Control
## Clock in, shutter down, warm flood, shutter up. CartReveal owns it (shift 1 is built behind it
## while it is down) and frees it when the reveal closes for anything but that hand-over. A click
## or Enter skips straight to opened (covered first, if it has not been yet); every other event
## goes on to the screen. Clicks never reach the screen through it (it stops the mouse).

signal covered
signal opened

var reduced: bool = false
var shift_count: int = 0
var _cover: float = 0.0
var _flood: bool = false
var _caption: Control
var _tween: Tween
var _covered: bool = false
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_caption = Control.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	var title: Label = StartBoardKit.words(
		_caption, "NEXT CUSTOMER", Rect2(0, 0, 620, 70), Palette.GOLD, 6
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shift: Label = StartBoardKit.words(
		_caption, "CLOCKED IN · SHIFT", Rect2(0, 82, 620, 30), Palette.MUSTARD_PALE, 3
	)
	shift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StartBoardKit.number(
		_caption, "1/%d" % shift_count, Rect2(248, 132, 160, 50), Palette.PAPER, 40
	)
	_caption.visible = false
	call_deferred("_begin")


func _begin() -> void:
	if _done:
		return
	if reduced:
		skip()
		return
	_tween = create_tween()
	_tween.tween_method(_set_cover, 0.0, 1.0, 0.4)
	_tween.tween_callback(
		func() -> void:
			_caption.visible = true
			Sfx.play_at(self, "ui_confirm")
			_cover_up()
	)
	_tween.tween_interval(0.35)
	_tween.tween_callback(
		func() -> void:
			_flood = true
			_caption.visible = false
	)
	_tween.tween_method(_set_cover, 1.0, 0.0, 0.45)
	_tween.tween_callback(_open)


## Jumps to the end: emits covered (when it has not yet) and opened, then frees itself.
func skip() -> void:
	if _done:
		return
	if _tween != null:
		_tween.kill()
	_cover_up()
	_open()


## Stops it with no further signal (the reveal closed under it: a new run, a resume).
func cancel() -> void:
	_done = true
	if _tween != null:
		_tween.kill()
	queue_free()


func is_done() -> bool:
	return _done


func _cover_up() -> void:
	if not _covered and not _done:
		_covered = true
		covered.emit()


func _open() -> void:
	if _done:
		return
	_done = true
	opened.emit()
	queue_free()


func _set_cover(value: float) -> void:
	_cover = floorf(value * 12) / 12.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _done:
		return
	var key: InputEventKey = event as InputEventKey
	var click: InputEventMouseButton = event as InputEventMouseButton
	var enter: bool = (
		key != null and key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER]
	)
	if enter or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		skip()


func _draw() -> void:
	var height: float = floorf(size.y * _cover / 2.0) * 2
	_caption.position = Vector2((size.x - 620) / 2.0, height / 2.0 - 80)
	draw_rect(Rect2(0, 0, size.x, height), Palette.MUSTARD_PALE if _flood else Palette.SLATE_DARK)
	if not _flood:
		for y: int in range(0, int(height), 16):
			draw_rect(Rect2(0, y, size.x, 2), Palette.TEAL_DARK)
			draw_rect(Rect2(0, y + 12, size.x, 2), Palette.CHARCOAL)
	draw_rect(Rect2(0, height - 6, size.x, 6), Palette.BRASS)
