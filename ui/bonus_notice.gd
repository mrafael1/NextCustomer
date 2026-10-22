class_name BonusNotice
extends Node
## The planning notice's pulse (#77 machine v2, B1): when passing the shift earns the bonus ticket,
## the inspection chip pulses once as planning opens (PlanningTuning.notice_pulse_ms), then the
## monitor brief's gold PASS IT plate (monitor_pulse_ms): each scales by 1 ± notice_pulse_scale at
## notice_pulse_rate (rad/s) about its pivot, and is back at 1 after. None under reduced motion.
## The plate is fetched each frame (the brief's slides are rebuilt when the state changes). Its
## clock is its own (`time`, seconds; show_at for tests).

const TUNING_PATH := "res://data/balance/planning.tres"

var tuning: PlanningTuning
## Seconds since play(), or -1 while it doesn't play.
var time: float = -1.0
var _chip: Control
var _line: Callable


func _init() -> void:
	name = "BonusNotice"
	tuning = load(TUNING_PATH) as PlanningTuning


## Pulses `chip`, then the Control `line` returns (null: none), unless `reduced` motion.
func play(chip: Control, line: Callable, reduced: bool) -> void:
	stop()
	if reduced:
		return
	_chip = chip
	_line = line
	show_at(0.0)


## Stops the pulse, both back at their size.
func stop() -> void:
	if time >= 0.0:
		_scale(_chip, 1.0)
		_scale(_current_line(), 1.0)
	time = -1.0


func is_playing() -> bool:
	return time >= 0.0


## The whole pulse's length (s).
func length() -> float:
	return (tuning.notice_pulse_ms + tuning.monitor_pulse_ms) / 1000.0


## The chip's scale and the plate's at `t` seconds (1 outside their pulse).
func chip_scale(t: float) -> float:
	return _pulse(t, 0.0, tuning.notice_pulse_ms / 1000.0)


func line_scale(t: float) -> float:
	return _pulse(t, tuning.notice_pulse_ms / 1000.0, length())


## Renders the pulse at `t` seconds; past length() it stops.
func show_at(t: float) -> void:
	time = t
	if t >= length():
		stop()
		return
	_scale(_chip, chip_scale(t))
	_scale(_current_line(), line_scale(t))


func _process(delta: float) -> void:
	if time >= 0.0:
		show_at(time + delta)


func _pulse(t: float, from: float, to: float) -> float:
	if t < from or t >= to:
		return 1.0
	return 1.0 + tuning.notice_pulse_scale * sin((t - from) * tuning.notice_pulse_rate)


func _current_line() -> Control:
	if not _line.is_valid():
		return null
	return _line.call() as Control


static func _scale(control: Control, factor: float) -> void:
	if control == null or not is_instance_valid(control):
		return
	if is_equal_approx(factor, 1.0):
		control.scale = Vector2.ONE
		return
	control.pivot_offset = control.size / 2.0 if control is InspectionTag else control.pivot_offset
	control.scale = Vector2(factor, factor)
