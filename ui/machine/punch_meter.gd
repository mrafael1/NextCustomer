class_name PunchMeter
extends Control
## One chute's REGULAR meter (#77, look F; build spec 4.2): a paper punch ticket (92x30 over a
## 2 px ink shadow) reading "REGULAR" and "n/3", with a hole per level: punched holes are open
## (steel, the cabinet's teal showing through), the others dashed rings. It shows the level
## RewardMachine gives it.
##
## frame(t) plays the punch when the visit's landing raises this chute's meter (plan.rises): the
## jaw comes down on the next hole, the chad falls out turning, the hole opens and a "REGULAR +1"
## tab rises above the ticket. Until the punch the ticket still shows the level before it.
## Reduced motion: the hole opens at the punch, no jaw, chad or rising tab.

const SIZE := Vector2(92, 30)
const LABEL_SIZE := 8
const BOLD_WEIGHT := 800
const WORD_RECT := Rect2(6, 2, 50, 10)
const LEVEL_RECT := Rect2(56, 2, 30, 10)
const HOLE_SIZE := 14.0
const HOLE_TOP := 12.0
const HOLE_GAP := 12.0
const BORDER := 2.0
const DASH := 2.0
const DASH_ARM := 5.0
const SHADOW := 2.0
const JAW_SIZE := Vector2(24, 12)
const CHAD_SIZE := 8.0
const PLUS_TEXT := "REGULAR +1"
const PLUS_SIZE := 12
const PLUS_RECT := Rect2(6, -26, 80, 18)
const PLUS_RISE := 10.0
## Look F's punch, as shares of the tuned punch length (MachineTuning.punch_length_ms; pure
## look): the jaw's stroke, the chad's fall, the hole opening and the +1 tab's time up.
const JAW_SPAN := 0.87
const CHAD_FROM := 0.33
const CHAD_TO := 1.33
const OPENS_AT := 0.3
const PLUS_SPAN := 2.0
## The jaw's stroke (y from the ticket's inner top edge, in 8 steps) and the chad's fall
## (10 steps).
const JAW_STEPS := 8.0
const CHAD_STEPS := 10.0
const JAW_FROM := -26.0
const JAW_DOWN := 2.0
const JAW_TO := -32.0
const CHAD_DROP := 50.0
const CHAD_DRIFT := 12.0

var chute: int = 0
var level: int = 0
var max_level: int = 3
## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _word: Label
var _level_label: Label
var _plus: Label
## The level shown now (one less than `level` until a rising punch opens its hole).
var _shown: int = 0
## The jaw's top-left and the chad's (centre, turn), or none.
var _jaw_at: Vector2 = Vector2.ZERO
var _jaw_on: bool = false
var _chad_at: Vector2 = Vector2.ZERO
var _chad_turn: float = 0.0
var _chad_on: bool = false


func _init(meter_chute: int) -> void:
	chute = meter_chute
	name = "PunchMeter%d" % chute
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word = _label("REGULAR", Palette.TEAL_SHADE, WORD_RECT, HORIZONTAL_ALIGNMENT_LEFT)
	_level_label = _label("", Palette.INK, LEVEL_RECT, HORIZONTAL_ALIGNMENT_RIGHT)
	_plus = UiKit.display_label(PLUS_TEXT, PLUS_SIZE, false)
	_plus.name = "PlusOne"
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var plus_style: StyleBoxFlat = StyleBoxFlat.new()
	plus_style.bg_color = Palette.MUSTARD_LIGHT
	plus_style.border_color = Palette.INK
	plus_style.set_border_width_all(2)
	_plus.add_theme_stylebox_override("normal", plus_style)
	RewardMachineView.fit(_plus, PLUS_RECT)
	_plus.visible = false
	add_child(_plus)
	show_level(0, 3)


## Shows `meter_level` of `top` (both from RewardMachine's chute info).
func show_level(meter_level: int, top: int) -> void:
	level = meter_level
	max_level = top
	_set_shown(level)


## "REGULAR n/3" as shown now.
func text() -> String:
	return "REGULAR %d/%d" % [_shown, max_level]


## The level shown now (the punched holes).
func shown_level() -> int:
	return _shown


func is_punching() -> bool:
	return _jaw_on or _chad_on


func plus_shown() -> bool:
	return _plus.visible


## The "+1" tab (above the ticket), for layout tests.
func plus_label() -> Label:
	return _plus


## Hole `index`'s rect (local).
func hole_rect(index: int) -> Rect2:
	var width: float = max_level * HOLE_SIZE + (max_level - 1) * HOLE_GAP
	var left: float = floorf((SIZE.x - width) / 2.0)
	return Rect2(left + index * (HOLE_SIZE + HOLE_GAP), HOLE_TOP, HOLE_SIZE, HOLE_SIZE)


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## The ticket at time `t` (seconds) of view.plan: while the landing raises this chute's meter,
## the level before the punch until its hole opens, the jaw and the chad around plan.punch and
## the +1 tab after it.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	var punch: float = _punch_time(plan)
	if punch < 0.0:
		_set_motion(false, false, false)
		_set_shown(level)
		return
	var length: float = MachineTuning.sec(plan.tuning.punch_length_ms)
	var opens: float = punch if plan.reduced_motion else punch + OPENS_AT * length
	_set_shown(level if t >= opens else maxi(0, level - 1))
	if plan.reduced_motion:
		_set_motion(false, false, false)
		return
	var hole: Rect2 = hole_rect(clampi(level - 1, 0, max_level - 1))
	var jaw: float = _progress(t, punch, punch + JAW_SPAN * length)
	var chad: float = _progress(t, punch + CHAD_FROM * length, punch + CHAD_TO * length)
	var plus: float = _progress(t, punch, punch + PLUS_SPAN * length)
	if jaw > 0.0 and jaw < 1.0:
		var step: float = floorf(jaw * JAW_STEPS) / JAW_STEPS
		var y: float = JAW_DOWN
		if step < 0.35:
			y = lerpf(JAW_FROM, JAW_DOWN, step / 0.35)
		elif step >= 0.55:
			y = lerpf(JAW_DOWN, JAW_TO, (step - 0.55) / 0.45)
		# Look F places the jaw at y in the ticket's padding box (inside its border).
		_jaw_at = Vector2(hole.position.x + (HOLE_SIZE - JAW_SIZE.x) / 2.0, _snap(BORDER + y))
	if chad > 0.0 and chad < 1.0:
		var fall: float = floorf(chad * CHAD_STEPS) / CHAD_STEPS
		_chad_at = Vector2(
			_snap(hole.get_center().x + fall * CHAD_DRIFT),
			_snap(hole.get_center().y + fall * fall * CHAD_DROP)
		)
		_chad_turn = deg_to_rad(roundf(fall * 90.0))
	var plus_on: bool = plus > 0.0 and plus < 1.0
	if plus_on:
		var up: float = clampf(plus * 3.0, 0.0, 1.0)
		var rise: float = 1.0 - (1.0 - up) * (1.0 - up)
		_plus.position.y = PLUS_RECT.position.y - _snap(rise * PLUS_RISE)
	_set_motion(jaw > 0.0 and jaw < 1.0, chad > 0.0 and chad < 1.0, plus_on)


## The punch's time when the landing raises this chute's meter (STAMP DAY never punches), else
## NOT_SET.
func _punch_time(plan: MachinePlan) -> float:
	if plan == null or not plan.has_landing or not plan.rises:
		return MachinePlan.NOT_SET
	if plan.kind == MachineVisit.Kind.STAMP_DAY or view.run == null or view.run.history.is_empty():
		return MachinePlan.NOT_SET
	var visits: Array[MachineVisit] = view.run.history[-1].visits
	if visits.is_empty() or visits[-1].chute != chute:
		return MachinePlan.NOT_SET
	return plan.punch


static func _progress(t: float, from: float, to: float) -> float:
	if to <= from:
		return 1.0 if t >= to else 0.0
	return (t - from) / (to - from)


static func _snap(value: float) -> float:
	return roundf(value / 2.0) * 2.0


func _set_shown(shown: int) -> void:
	if shown == _shown and _level_label.text != "":
		return
	_shown = shown
	_level_label.text = "%d/%d" % [_shown, max_level]
	queue_redraw()


func _set_motion(jaw: bool, chad: bool, plus: bool) -> void:
	_plus.visible = plus
	if not plus:
		_plus.position.y = PLUS_RECT.position.y
	# The falling chad passes over the stockroom window, drawn after the meters.
	z_index = 1 if chad else 0
	if jaw or chad or jaw != _jaw_on or chad != _chad_on:
		_jaw_on = jaw
		_chad_on = chad
		queue_redraw()


func _label(
	text_shown: String, colour: Color, rect: Rect2, alignment: HorizontalAlignment
) -> Label:
	var result: Label = UiKit.body_label(text_shown, LABEL_SIZE, colour)
	result.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	result.horizontal_alignment = alignment
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(result, rect)
	add_child(result)
	return result


func _draw() -> void:
	draw_rect(Rect2(Vector2(0, SHADOW), SIZE), Palette.INK)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PAPER)
	draw_rect(Rect2(Vector2.ZERO, SIZE).grow(-BORDER / 2.0), Palette.INK, false, BORDER)
	for hole: int in range(max_level):
		var rect: Rect2 = hole_rect(hole)
		if hole < _shown:
			_draw_punched(rect)
		else:
			_draw_dashed(rect)
	if _jaw_on:
		var jaw: Rect2 = Rect2(_jaw_at, JAW_SIZE)
		draw_rect(jaw, Palette.STEEL_LIGHT)
		draw_rect(Rect2(jaw.position.x, jaw.end.y - 5.0, jaw.size.x, 3.0), Palette.STEEL)
		draw_rect(jaw.grow(-BORDER / 2.0), Palette.INK, false, BORDER)
	if _chad_on:
		draw_set_transform(_chad_at, _chad_turn)
		var chad: Rect2 = Rect2(-Vector2.ONE * CHAD_SIZE / 2.0, Vector2.ONE * CHAD_SIZE)
		draw_rect(chad, Palette.PAPER)
		draw_rect(chad.grow(-BORDER / 2.0), Palette.INK, false, BORDER)
		draw_set_transform(Vector2.ZERO)


## An open hole: steel inside an ink ring, its top-left in charcoal, the cabinet's teal through it.
func _draw_punched(rect: Rect2) -> void:
	draw_rect(rect, Palette.STEEL_DARK)
	var inner: Rect2 = rect.grow(-BORDER)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, BORDER)), Palette.CHARCOAL)
	draw_rect(Rect2(inner.position, Vector2(BORDER, inner.size.y)), Palette.CHARCOAL)
	draw_rect(Rect2(inner.position + Vector2(3, 3), Vector2(4, 4)), Palette.PANEL)
	draw_rect(rect.grow(-BORDER / 2.0), Palette.INK, false, BORDER)


## A hole still to punch: a dashed grey ring as the mock-up's browser draws a 2 px dashed border
## on a 14 px box: a 5 px arm from each corner along each side, a gap in the middle.
func _draw_dashed(rect: Rect2) -> void:
	for corner: Vector2 in [rect.position, Vector2(rect.end.x - DASH, rect.position.y)]:
		draw_rect(Rect2(corner, Vector2(DASH, DASH_ARM)), Palette.GREY)
		draw_rect(
			Rect2(corner + Vector2(0, rect.size.y - DASH_ARM), Vector2(DASH, DASH_ARM)),
			Palette.GREY
		)
	for corner: Vector2 in [rect.position, Vector2(rect.position.x, rect.end.y - DASH)]:
		draw_rect(Rect2(corner, Vector2(DASH_ARM, DASH)), Palette.GREY)
		draw_rect(
			Rect2(corner + Vector2(rect.size.x - DASH_ARM, 0), Vector2(DASH_ARM, DASH)),
			Palette.GREY
		)
