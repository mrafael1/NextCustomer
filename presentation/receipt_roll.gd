class_name ReceiptRoll
extends RefCounted
## The planning receipt's PROJECTED number rolling to a new projection (2026-11-08 feedback):
## when an item goes onto the belt, comes off it or moves, the hero (and its line against the
## target) counts in whole euros from the number shown to the new one, eased out over
## MIN_SECONDS to MAX_SECONDS (longer for a bigger change); a rise lifts the hero RISE_LIFT px (one
## art px) while it counts and drops it as the last euro shows (it lands), a fall settles calmly (a
## sine ease, no lift).
## A new projection arriving mid-roll rolls on from the number shown. ReceiptTarget.show_planned
## starts it; reduced motion, a first show and the count (which drives the hero itself) show the
## number at once (stop). Only the planning ScoreResult's total shows: nothing is scored here.
## Display only.

const MIN_SECONDS := 0.25
const MAX_SECONDS := 0.45
const SECONDS_PER_EURO := 0.01
const RISE_LIFT := 2.0

## The number on the hero now (whole euros), and the one it rolls to.
var shown: int = 0
var goal: int = 0

var _host: Node
## Shows a number on the hero: `show.call(value: int, landed: bool)`.
var _show: Callable
## Lifts the hero: `lift.call(px: float)`.
var _lift: Callable
var _tween: Tween


func _init(host: Node, show: Callable, lift: Callable) -> void:
	_host = host
	_show = show
	_lift = lift


## How long a roll over `change` euros takes.
static func seconds_for(change: int) -> float:
	return clampf(MIN_SECONDS + absi(change) * SECONDS_PER_EURO, MIN_SECONDS, MAX_SECONDS)


## Whether a roll is under way.
func rolling() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Rolls from the number shown to `value` (at once when it is shown already, or the host is out
## of the tree). The same projection again (a refresh that changed nothing) keeps the roll going.
func to(value: int) -> void:
	if value == goal and _tween != null and _tween.is_valid():
		return
	goal = value
	stop()
	if value == shown or not _host.is_inside_tree():
		snap(value)
		return
	var rising: bool = value > shown
	_lift.call(RISE_LIFT if rising else 0.0)
	_tween = _host.create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC if rising else Tween.TRANS_SINE)
	_tween.tween_method(_step, float(shown), float(value), seconds_for(value - shown))
	_tween.tween_callback(snap.bind(value))


## Shows `value` at once, ending any roll.
func snap(value: int) -> void:
	stop()
	goal = value
	shown = value
	_show.call(value, true)


## Ends any roll where it stands (the hero lands), without showing anything. With no roll under
## way it leaves the hero alone (the count's row-landing bump shares the lift).
func stop() -> void:
	if _tween == null:
		return
	_tween.kill()
	_tween = null
	_lift.call(0.0)


func _step(at: float) -> void:
	var value: int = roundi(at)
	if value == shown:
		return
	shown = value
	_show.call(value, false)
	if value == goal:
		_lift.call(0.0)
