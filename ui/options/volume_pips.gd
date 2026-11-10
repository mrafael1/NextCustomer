class_name VolumePips
extends Control
## A volume of the OPTIONS popup (mock-up options_pause.html): a − key, ten rising pips, a + key
## and the register's counter window with the value (0 is its alert look: MUTE). Clicking a pip
## sets that value. Drawn in code on the 2 px grid; the keys are RegisterKeys.

## The value changed by a key or a pip (the popup stores and applies it).
signal value_picked(value: int)

const KEY_SIZE := Vector2(32, 40)
const PIP_LEFT := 44.0
const PIP_STEP := 16.0
const PIP_WIDTH := 12.0
const WINDOW_SIZE := Vector2(48, 40)

var value: int = ProfileState.VOLUME_DEFAULT:
	set(new_value):
		value = clampi(new_value, 0, ProfileState.VOLUME_MAX)
		_number.text = str(value)
		_number.add_theme_color_override(
			"font_color", Palette.TOMATO_DARK if value == 0 else Palette.INK
		)
		_mute.visible = value == 0
		queue_redraw()

var _minus: RegisterKey
var _plus: RegisterKey
var _number: Label
var _mute: Label
var _window_x: float


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_minus = RegisterKey.new(RegisterKey.Kind.CREAM, "-", 16, KEY_SIZE)
	_minus.pressed.connect(func() -> void: value_picked.emit(maxi(value - 1, 0)))
	add_child(_minus)
	var pips_end: float = PIP_LEFT + PIP_STEP * ProfileState.VOLUME_MAX
	_plus = RegisterKey.new(RegisterKey.Kind.CREAM, "+", 16, KEY_SIZE)
	_plus.position = Vector2(pips_end + 8, 0)
	_plus.pressed.connect(
		func() -> void: value_picked.emit(mini(value + 1, ProfileState.VOLUME_MAX))
	)
	add_child(_plus)
	_window_x = pips_end + 52
	_number = UiKit.pixel_label("", 4, Palette.INK)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_number)
	_mute = UiKit.pixel_label("MUTE", 2, Palette.TOMATO_DARK)
	_mute.position = Vector2(_window_x + 60, 14)
	add_child(_mute)
	size = Vector2(_window_x + WINDOW_SIZE.x, KEY_SIZE.y)
	custom_minimum_size = size
	value = ProfileState.VOLUME_DEFAULT


## The pip for `volume` (1 to VOLUME_MAX), in local px.
func pip_rect(volume: int) -> Rect2:
	var h: float = 12.0 + volume * 2.0
	return Rect2(PIP_LEFT + (volume - 1) * PIP_STEP, 38.0 - h, PIP_WIDTH, h)


func minus_key() -> RegisterKey:
	return _minus


func plus_key() -> RegisterKey:
	return _plus


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for volume: int in range(1, ProfileState.VOLUME_MAX + 1):
		var rect: Rect2 = pip_rect(volume)
		if Rect2(rect.position.x - 2, 0, PIP_STEP, KEY_SIZE.y).has_point(click.position):
			accept_event()
			value_picked.emit(volume)
			return


func _draw() -> void:
	for volume: int in range(1, ProfileState.VOLUME_MAX + 1):
		var rect: Rect2 = pip_rect(volume)
		var on: bool = volume <= value
		OptionChip.cut_box(self, rect, Palette.GOLD if on else Palette.GREY_LIGHT)
		var foot: float = rect.end.y
		if on:
			draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, 8, 2), Palette.MUSTARD_PALE)
			draw_rect(Rect2(rect.position.x + 2, foot - 4, 8, 2), Palette.MUSTARD_DARK)
		else:
			draw_rect(Rect2(rect.position.x + 2, foot - 4, 8, 2), Palette.GREY)
	var wx: float = _window_x
	var mute: bool = value == 0
	draw_rect(Rect2(wx, 0, WINDOW_SIZE.x, WINDOW_SIZE.y), Palette.INK)
	draw_rect(Rect2(wx + 2, 2, 44, 36), Palette.CREAM_SHADE if mute else Palette.PAPER)
	draw_rect(Rect2(wx + 2, 2, 44, 2), Palette.CREAM_SHADE)
	draw_rect(Rect2(wx + 2, 2, 2, 36), Palette.CREAM_SHADE)
	var number_size: Vector2 = UiKit.pixel_text_size(_number)
	_number.position = (Vector2(wx + 26 - number_size.x / 2.0, 4)).round()
	if mute:
		draw_rect(Rect2(wx + 8, 18, 34, 4), Palette.TOMATO_DARK)
