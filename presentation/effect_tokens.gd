class_name EffectTokens
extends RefCounted
## The count-up's armed effects on screen (#60, decisions D8 and D9), for one row. At an armed
## beat, one token per landing flies from the arming card to its target card, where it waits as
## a dimmed EffectMarker ("×3 · Multipack"); the arming card keeps a pip (a token icon and "×3")
## while any token waits. A landing brightens its marker and absorbs it, and the pip clears
## after the last one. The effect's fizzle greys the pip for good (a lasting state). At the
## row's end, tokens that never landed dissolve. Reduced motion: markers fade in on their
## target instead of flying.
##
## Everything comes from the CountUpPlan (its armed beats' targets) and the steps. The tweens
## come from the count-up (`make_tween`), so they follow its speed and hit-stops. clear() frees
## what is left (the grey pips) before the next row.

## A token flies to its target this long; markers fade this long.
const FLIGHT := 0.25
const FADE := 0.15
## A landing marker shows at full brightness this long before it is absorbed.
const BRIGHT := 0.06
const ABSORB := 0.12
## Markers on one card stack this far apart.
const STACK := 20.0

## The dimmed markers waiting for their landing, by the landing's beat index.
var markers: Dictionary[int, EffectMarker] = {}
## The arming cards' pips, by the ARMED beat index.
var pips: Dictionary[int, EffectMarker] = {}
var _overlay: Control
var _plan: CountUpPlan
var _steps: Array[ScoreStep] = []
var _views: Array[CardView] = []
var _names: PackedStringArray = PackedStringArray()
## Returns a new Tween that follows the count-up's speed.
var _make_tween: Callable
## Each armed beat's tokens still to land.
var _unresolved: Dictionary[int, int] = {}
## Markers already on each slot's card, to stack the next one below them.
var _stacked: Dictionary[int, int] = {}
## Tokens still flying to their target.
var _flights: Dictionary[EffectMarker, Tween] = {}
## Every marker and pip made, freed by clear().
var _made: Array[EffectMarker] = []


func _init(
	overlay: Control,
	plan: CountUpPlan,
	steps: Array[ScoreStep],
	views: Array[CardView],
	names: PackedStringArray,
	make_tween: Callable
) -> void:
	_overlay = overlay
	_plan = plan
	_steps = steps
	_views = views
	_names = names
	_make_tween = make_tween


## Armed beat `armed`: its pip, and a token flying to each of its landings. Does nothing for an
## effect without a landing.
func arm(armed: int) -> void:
	var beat: CountUpBeat = _plan.beats[armed]
	if beat.targets.is_empty():
		return
	_make_pip(armed)
	_unresolved[armed] = beat.targets.size()
	for target: int in beat.targets:
		_send(armed, target)


## Beat `index` lands an armed effect: its marker brightens and is absorbed, and the arming
## card's pip clears once its last token has landed. `landed` is called once the marker is gone,
## or at once without one (any other beat), so what shows the landing next (a belt item's chip,
## #75) never shows beside its marker.
func land(index: int, landed: Callable = Callable()) -> void:
	var beat: CountUpBeat = _plan.beats[index]
	if beat.armed_from < 0:
		if landed.is_valid():
			landed.call()
		return
	var marker: EffectMarker = markers.get(index) as EffectMarker
	markers.erase(index)
	if marker != null and is_instance_valid(marker):
		_stop_flight(marker)
		marker.following = true
		marker.set_dimmed(false)
		marker.pivot_offset = marker.size / 2.0
		var absorb: Tween = _tween()
		absorb.tween_interval(BRIGHT)
		absorb.tween_property(marker, "scale", Vector2(0.4, 0.4), ABSORB)
		absorb.parallel().tween_property(marker, "modulate:a", 0.0, ABSORB)
		absorb.tween_callback(marker.queue_free)
		if landed.is_valid():
			absorb.tween_callback(landed)
	elif landed.is_valid():
		landed.call()
	var left: int = _unresolved.get(beat.armed_from, 0) - 1
	_unresolved[beat.armed_from] = left
	if left <= 0:
		_fade_out_pip(beat.armed_from)


## Fizzle beat `index` (its step `step`): when it is an armed effect's (the latest ARMED beat
## before it on the same card with the same text), that effect's pip greys and stays grey; one
## whose tokens all landed gets its pip back, grey.
func spend(index: int, step: ScoreStep) -> void:
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return
	for armed: int in range(index - 1, -1, -1):
		var beat: CountUpBeat = _plan.beats[armed]
		var armed_step: ScoreStep = _steps[beat.steps[0]]
		if (
			beat.kind != CountUpBeat.Kind.ARMED
			or armed_step.slot != step.slot
			or armed_step.text != step.text
		):
			continue
		var pip: EffectMarker = pips.get(armed) as EffectMarker
		if pip == null or not is_instance_valid(pip):
			pip = _make_pip(armed)
			pip.modulate.a = 0.0
			_tween().tween_property(pip, "modulate:a", 1.0, FADE)
		pip.set_spent(true)
		return


## The row is over: tokens that never landed dissolve, and so do the pips still waiting. Grey
## pips stay.
func dissolve() -> void:
	for target: int in markers.keys():
		var marker: EffectMarker = markers[target]
		if marker == null or not is_instance_valid(marker):
			continue
		_stop_flight(marker)
		marker.following = true
		var fade: Tween = _tween()
		fade.tween_property(marker, "modulate:a", 0.0, FADE)
		fade.tween_callback(marker.queue_free)
	markers.clear()
	for armed: int in pips.keys():
		_fade_out_pip(armed)


## Frees every marker and pip still there (the grey pips), before the next row.
func clear() -> void:
	for flight: Tween in _flights.values():
		if flight != null and flight.is_valid():
			flight.kill()
	_flights.clear()
	for marker: EffectMarker in _made:
		if is_instance_valid(marker):
			marker.queue_free()
	_made.clear()
	markers.clear()
	pips.clear()


## What a landing does, on its token: "×3" or "+3".
func token_text(target: int) -> String:
	var step: ScoreStep = _steps[_plan.beats[target].steps[0]]
	var multiplies: bool = step.step_type == ScoreStep.StepType.MULTIPLIER
	return ("×%d" if multiplies else "+%d") % step.value


## The token of armed beat `armed` for its landing at beat `target`: it flies from the arming
## card and parks dimmed on the target card (reduced motion: it fades in there).
func _send(armed: int, target: int) -> void:
	var arming: CountUpBeat = _plan.beats[armed]
	var landing: CountUpBeat = _plan.beats[target]
	var marker: EffectMarker = _add("%s · %s" % [token_text(target), _names[arming.slot]], false)
	var stacked: int = _stacked.get(landing.slot, 0)
	_stacked[landing.slot] = stacked + 1
	marker.attach(_views[landing.slot].body, EffectMarker.Pin.TOP_RIGHT, stacked * STACK)
	markers[target] = marker
	if _plan.reduced_motion:
		marker.modulate.a = 0.0
		_tween().tween_property(marker, "modulate:a", EffectMarker.DIMMED_ALPHA, FADE)
		return
	marker.following = false
	marker.set_dimmed(true)
	marker.size = marker.get_combined_minimum_size()
	marker.global_position = _views[arming.slot].center() - marker.size / 2.0
	var flight: Tween = _tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flight.tween_property(marker, "global_position", marker.parked_position(), FLIGHT)
	flight.tween_callback(marker.set.bind(&"following", true))
	_flights[marker] = flight


## The pip on armed beat `armed`'s card: the token icon and what the effect does (its receipt
## text when it has no landing).
func _make_pip(armed: int) -> EffectMarker:
	var beat: CountUpBeat = _plan.beats[armed]
	var text: String = _steps[beat.steps[0]].text
	if not beat.targets.is_empty():
		text = token_text(beat.targets[0])
	var pip: EffectMarker = _add(text, true)
	pip.attach(_views[beat.slot].body, EffectMarker.Pin.TOP_LEFT)
	pips[armed] = pip
	return pip


func _fade_out_pip(armed: int) -> void:
	var pip: EffectMarker = pips.get(armed) as EffectMarker
	if pip == null or not is_instance_valid(pip) or pip.is_spent():
		return
	pips.erase(armed)
	var fade: Tween = _tween()
	fade.tween_property(pip, "modulate:a", 0.0, FADE)
	fade.tween_callback(pip.queue_free)


func _add(text: String, with_icon: bool) -> EffectMarker:
	var marker: EffectMarker = EffectMarker.new(text, with_icon)
	_overlay.add_child(marker)
	_made.append(marker)
	return marker


func _stop_flight(marker: EffectMarker) -> void:
	var flight: Tween = _flights.get(marker) as Tween
	if flight != null and flight.is_valid():
		flight.kill()
	_flights.erase(marker)


func _tween() -> Tween:
	return _make_tween.call() as Tween
