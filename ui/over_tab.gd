class_name OverTab
extends Control
## The "+€N" tab (#86 v6 scan count-up, mock-up count_up_86_v6_scan.html; since the monitor bay
## follow-up, mock-up monitor_bay_v1.html, at stage POSITION: beside the SPEND MET stamp, one row
## under the number and its €, the two centred together under them): how far past the quota the
## shown amount is, "+€N" (core's ShiftMargin, LedBeat.to_go_text), in ink on gold inside a
## BORDER-wide ink border with a SHADOW px mustard-dark shadow, turned TILT_DEG about its centre. It
## shows only once the quota is met and only while the amount is over it. arm() with a pop brings it
## in DELAY_S after the burst, popping from POP_FROM to its size over POP_S; arm() without one
## (reduced motion, a resumed checkout) shows it at once. punch() (each later payout) swells it to
## PUNCH and back over PUNCH_S. Its motion is real time (_process), so the count-up's hit-stops
## never freeze it; reduced motion (`reduced_motion`) keeps the states and drops the pop and the
## punches. Display only: the amount and the quota are the LED's (MonitorView hands on its reading);
## it takes no clicks.

## Its top left on the stage (on the monitor's paper, 8 px right of MonitorView.STAMP_RECT).
const POSITION := Vector2(804, 187)
const HEIGHT := 28.0
const PAD_X := 6.0
const BORDER := 2.0
const SHADOW := 2.0
const FONT_SIZE := 19
const WEIGHT := 800
const TILT_DEG := -3.0
const FACE_COLOR := Palette.GOLD
const INK_COLOR := Palette.INK
const SHADOW_COLOR := Palette.MUSTARD_DARK
## The pop after the burst, and each later payout's punch (a swell that eases back).
const DELAY_S := 1.0
const POP_FROM := 1.9
const POP_S := 0.14
const PUNCH := 1.5
const PUNCH_S := 0.3

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var _label: Label
var _armed: bool = false
var _over: bool = false
## Seconds until the tab comes in (an arm with a pop), or -1 for none waiting.
var _delay: float = -1.0
## The pop's and the punch's ages (seconds), -1 when not running.
var _pop_age: float = -1.0
var _punch_age: float = -1.0


func _init() -> void:
	name = "OverTab"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = POSITION
	rotation_degrees = TILT_DEG
	_label = UiKit.body_label("", FONT_SIZE, INK_COLOR)
	_label.add_theme_font_override("font", ArtStyle.bold_font(WEIGHT))
	_label.add_theme_constant_override("outline_size", 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_apply()


func _ready() -> void:
	_lay_out()


## The LED's reading: the tab says how far `amount` is past `quota` and shows only while over it.
func set_reading(amount: int, quota: int, _met: bool) -> void:
	var margin: ShiftMargin = ShiftMargin.of(amount, quota)
	_over = margin.kind() == ShiftMargin.Kind.OVER
	if _over:
		_label.text = LedBeat.to_go_text(margin)
		_lay_out()
	_apply()


## The quota is met: with `pop` the tab comes in DELAY_S later, popping; without one (or under
## reduced motion) at once.
func arm(pop: bool) -> void:
	_armed = true
	_punch_age = -1.0
	if pop and not _reduced():
		_delay = DELAY_S
	else:
		_delay = -1.0
		_pop_age = -1.0
	_apply()


## A later payout punches the tab (none while it is hidden, or under reduced motion).
func punch() -> void:
	if is_showing() and not _reduced():
		_punch_age = 0.0


## A new count: hidden, nothing waiting.
func reset() -> void:
	_armed = false
	_over = false
	_delay = -1.0
	_pop_age = -1.0
	_punch_age = -1.0
	_label.text = ""
	_apply()


## Whether the tab shows now.
func is_showing() -> bool:
	return visible


## Whether its pop or punch is running (or the pop still waiting).
func is_moving() -> bool:
	return _delay >= 0.0 or _pop_age >= 0.0 or _punch_age >= 0.0


func label() -> Label:
	return _label


func _process(delta: float) -> void:
	if not is_moving():
		return
	if _delay >= 0.0:
		_delay -= delta
		if _delay < 0.0:
			_delay = -1.0
			_pop_age = 0.0
	elif _pop_age >= 0.0:
		_pop_age += delta
		if _pop_age >= POP_S:
			_pop_age = -1.0
	if _punch_age >= 0.0:
		_punch_age += delta
		if _punch_age >= PUNCH_S:
			_punch_age = -1.0
	_apply()


func _draw() -> void:
	var face: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(face.position + Vector2(SHADOW, SHADOW), face.size), SHADOW_COLOR)
	draw_rect(face, INK_COLOR)
	draw_rect(face.grow(-BORDER), FACE_COLOR)


## Shown once armed (its pop no longer waiting) and over the quota, at the pop's or the punch's
## scale.
func _apply() -> void:
	visible = _armed and _over and _delay < 0.0
	var swell: float = 1.0
	if _pop_age >= 0.0:
		swell = lerpf(POP_FROM, 1.0, _pop_age / POP_S)
	if _punch_age >= 0.0:
		var left: float = 1.0 - _punch_age / PUNCH_S
		swell = maxf(swell, 1.0 + (PUNCH - 1.0) * left * left)
	scale = Vector2.ONE * swell


## The tab as wide as its text with PAD_X each side inside its border, turning about its centre.
func _lay_out() -> void:
	var font: Font = _label.get_theme_font("font")
	var font_size: int = _label.get_theme_font_size("font_size")
	var text_width: float = (
		font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	)
	size = Vector2(ceilf(text_width + 2.0 * (PAD_X + BORDER)), HEIGHT)
	pivot_offset = size / 2.0
	_label.position = Vector2.ZERO
	_label.size = size
	queue_redraw()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
