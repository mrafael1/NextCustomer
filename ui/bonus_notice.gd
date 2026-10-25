class_name BonusNotice
extends Node
## The planning notice's pulse (#77 machine v2, B1): when passing the shift earns the bonus ticket,
## the inspection chip pulses once as planning opens (PlanningTuning.notice_pulse_ms), scaling by
## 1 ± notice_pulse_scale at notice_pulse_rate (rad/s) about its pivot, and is back at 1 after.
## None under reduced motion. (The monitor's PASS IT plate went with the store channel, #105
## piece 2.) Its clock is its own (`time`, seconds; show_at for tests).

const TUNING_PATH := "res://data/balance/planning.tres"

var tuning: PlanningTuning
## Seconds since play(), or -1 while it doesn't play.
var time: float = -1.0
var _chip: Control


func _init() -> void:
	name = "BonusNotice"
	tuning = load(TUNING_PATH) as PlanningTuning


## Pulses `chip`, unless `reduced` motion.
func play(chip: Control, reduced: bool) -> void:
	stop()
	if reduced:
		return
	_chip = chip
	show_at(0.0)


## Stops the pulse, the chip back at its size.
func stop() -> void:
	if time >= 0.0:
		_scale(_chip, 1.0)
	time = -1.0


func is_playing() -> bool:
	return time >= 0.0


## The whole pulse's length (s).
func length() -> float:
	return tuning.notice_pulse_ms / 1000.0


## The chip's scale at `t` seconds (1 outside its pulse).
func chip_scale(t: float) -> float:
	if t < 0.0 or t >= length():
		return 1.0
	return 1.0 + tuning.notice_pulse_scale * sin(t * tuning.notice_pulse_rate)


## Renders the pulse at `t` seconds; past length() it stops.
func show_at(t: float) -> void:
	time = t
	if t >= length():
		stop()
		return
	_scale(_chip, chip_scale(t))


func _process(delta: float) -> void:
	if time >= 0.0:
		show_at(time + delta)


static func _scale(control: Control, factor: float) -> void:
	if control == null or not is_instance_valid(control):
		return
	if is_equal_approx(factor, 1.0):
		control.scale = Vector2.ONE
		return
	control.pivot_offset = control.size / 2.0 if control is InspectionTag else control.pivot_offset
	control.scale = Vector2(factor, factor)
