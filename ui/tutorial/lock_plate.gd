class_name LockPlate
extends Control
## A LOCKED plate (mock-up docs/art/mockups/tutorial.html, .lock): over what a tutorial step blocks
## (REDRAW, the medals, CHECKOUT, the swap plate, NEW PACKS), a grey veil (what lies under it
## drawn without its colour, presentation/machine_dim.gdshader, then the slate tint) and a centred
## dark pill holding the padlock and its label ("LOCKED") in steel pale. A plate too small for the
## big pill (padlock at 2x, words at 2x) takes the small one (1x). It takes the clicks on it and
## says so (clicked: the callout shakes), so nothing under it lights on hover; the screens' gates
## still refuse the blocked move.

signal clicked

const DESATURATE := preload("res://presentation/machine_dim.gdshader")
const PADLOCK := preload("res://art/icons/padlock.png")
## The tint over the grey (the mock-up's rgba(20,26,26,.5)) and the pill's face.
const TINT := Color(Palette.SLATE, 0.5)
const PILL := Color(Palette.INK, 0.85)
const WORDS := Palette.STEEL_PALE
## The pill's padding and the gap between the padlock and the words, at 1x (doubled at 2x).
const PILL_PAD := Vector2(3, 2)
const ICON_GAP := 3.0

var label: String = StepView.LOCKED
var _veil: ColorRect
var _tint: ColorRect
var _pill: ColorRect
var _padlock: TextureRect
var _words: Label
var _scale: int = 2


func _init(words: String = StepView.LOCKED) -> void:
	name = "LockPlate"
	mouse_filter = Control.MOUSE_FILTER_STOP
	label = words
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grey: ShaderMaterial = ShaderMaterial.new()
	grey.shader = DESATURATE
	grey.set_shader_parameter("saturation", 0.0)
	_veil.material = grey
	add_child(_veil)
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = TINT
	add_child(_tint)
	_pill = ColorRect.new()
	_pill.name = "Pill"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.color = PILL
	add_child(_pill)
	_padlock = UiKit.sprite(PADLOCK)
	_padlock.name = "Padlock"
	_pill.add_child(_padlock)
	_words = UiKit.pixel_label(words, 2, WORDS)
	_words.name = "Words"
	_pill.add_child(_words)


## Covers `rect` (its parent's coordinates) and lays the pill out in its middle.
func cover(rect: Rect2) -> void:
	position = rect.position.floor()
	size = rect.size.ceil()
	_veil.size = size
	_tint.size = size
	_scale = 2 if pill_size(2).x <= size.x and pill_size(2).y <= size.y else 1
	var pill_box: Vector2 = pill_size(_scale)
	_pill.size = pill_box
	_pill.position = (((size - pill_box) / 2.0) / 2.0).floor() * 2.0
	var pad: Vector2 = PILL_PAD * _scale
	_padlock.size = PADLOCK.get_size() * _scale
	_padlock.position = Vector2(pad.x, roundf((pill_box.y - _padlock.size.y) / 2.0))
	_words.text = label
	_words.scale = Vector2.ONE * _scale
	var words_x: float = pad.x + _padlock.size.x + ICON_GAP * _scale
	UiKit.place_pixel_label(_words, Rect2(words_x, 0, _words_size(_scale).x, pill_box.y), true)


## The pill's size at `scale_by` (1 or 2): the padlock and the words side by side, padded.
func pill_size(scale_by: int) -> Vector2:
	var icon: Vector2 = PADLOCK.get_size() * scale_by
	var caps: Vector2 = _words_size(scale_by)
	var inner: Vector2 = Vector2(icon.x + ICON_GAP * scale_by + caps.x, maxf(icon.y, caps.y))
	return ((inner + PILL_PAD * scale_by * 2.0) / 2.0).ceil() * 2.0


## The pill (for checks).
func pill() -> Control:
	return _pill


func words_label() -> Label:
	return _words


func padlock() -> TextureRect:
	return _padlock


func _words_size(scale_by: int) -> Vector2:
	return TipCard.caps_size(label) * scale_by


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		accept_event()
		clicked.emit()
