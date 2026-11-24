class_name PuzzleCheer
extends Control
## A puzzle's EXACT moment (#183 polish 5, play test 2026-11-23: "the EXACT moment is flat"), in
## the game's juice vocabulary: the receipt's EXACT stamp slams down from big through
## STAMP_SCALES (one step every STAMP_STEP, the rubber stamp's overshoot and settle) with the
## PAID stamp's thud; on its impact the gauge's target notch blinks and the tube flashes
## (QuotaMeter.pop_lamp), the register's bell rings and the checkout cheering's pixel confetti
## (CheerConfetti) bursts from the stamp and from the notch. Reduced motion (`still`): the stamp
## and the notch lit at once, the thud alone. Over the shift screen (its overlay layer, full
## rect), under the pin cards; decor only, it takes no clicks.

const STAMP_SCALES: Array[float] = [2.2, 1.6, 1.15, 0.9, 1.05, 1.0]
const STAMP_STEP := 0.045
## The step the stamp lands on (0.9: its overshoot under 1).
const IMPACT_STEP := 3
const STAMP_SOUND := "stamp_paid"
const BELL_SOUND := "register_bell"
const BELL_DELAY := 0.12
const STAMP_CONFETTI := 40
const NOTCH_CONFETTI := 20
const SEED := 183

var _confetti: CheerConfetti
var _slam: Tween
var _stamp: Control


func _init() -> void:
	name = "PuzzleCheer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti = CheerConfetti.new()
	_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confetti)


## Celebrates an EXACT solve: `stamp` (the receipt's verdict stamp, shown) slams down and the
## notch of `meter` flashes.
func celebrate(stamp: Control, meter: QuotaMeter, still: bool) -> void:
	stop()
	if still:
		meter.pop_lamp(true)
		Sfx.play_at(self, STAMP_SOUND, 0.0)
		return
	_stamp = stamp
	stamp.pivot_offset = stamp.size / 2.0
	_slam = create_tween()
	for step: int in STAMP_SCALES.size():
		_slam.tween_callback(_scale.bind(stamp, STAMP_SCALES[step]))
		if step == IMPACT_STEP:
			_slam.tween_callback(_impact.bind(stamp, meter))
		_slam.tween_interval(STAMP_STEP)
	_slam.tween_interval(BELL_DELAY)
	_slam.tween_callback(Sfx.play_at.bind(self, BELL_SOUND, 0.0))


## Whether the stamp is still slamming down.
func is_slamming() -> bool:
	return _slam != null and _slam.is_running()


## The confetti pieces flying now.
func pieces() -> int:
	return _confetti.pieces()


## Ends the celebration at once (a RETRY or NEXT before it is over).
func stop() -> void:
	if _slam != null:
		_slam.kill()
		_slam = null
	if _stamp != null and is_instance_valid(_stamp):
		_stamp.scale = Vector2.ONE
	_confetti.clear()


func _scale(stamp: Control, factor: float) -> void:
	stamp.pivot_offset = stamp.size / 2.0  # Its size settles once its row sorts it.
	stamp.scale = Vector2.ONE * factor


func _impact(stamp: Control, meter: QuotaMeter) -> void:
	Sfx.play_at(self, STAMP_SOUND, 0.0)
	meter.pop_lamp(true)
	var to_local: Transform2D = get_global_transform().affine_inverse()
	_confetti.burst(to_local * stamp.get_global_rect().get_center(), STAMP_CONFETTI, SEED)
	_confetti.burst(to_local * meter.quota_mark(), NOTCH_CONFETTI, SEED + 1)
