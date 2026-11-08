class_name MedalFlight
extends Node
## A week medal's flight at the checkout (2026-11-06, mock-up docs/art/mockups/week_medals.html
## section 3): when the count crosses a medal's laps while it is still to spend, the coin leaves
## its socket on the week badge (MedalSockets.launch: the socket is empty from then on) and flies
## down into the quota gauge's lap lamp (QuotaMeter.lamp_canvas_rect) on an arc, growing to the
## lamp's size, over FLIGHT_SECONDS; as it lands the lamp pops (QuotaMeter.pop_lamp), a coin rings
## and `landed` is called (the receipt turns its metal). Two medals at once (a total jumping past
## both) fly one after the other, STAGGER apart. Reduced motion: no flight, the socket empties and
## `landed` is called at once. The coin flies on its own canvas layer, over the stage and the top
## bar. Display only.

## The flight's length, the second medal's delay, the arc's lift (canvas px, at its middle).
const FLIGHT_SECONDS := 0.6
const STAGGER := 0.25
const ARC_LIFT := 60.0
## Over the stage, the top bar and the machine.
const LAYER := 90

var _sockets: MedalSockets
var _meter: QuotaMeter
var _layer: CanvasLayer
## The coins in flight, and their tweens.
var _flyers: Array[Control] = []
var _tweens: Array[Tween] = []
## When the next flight may start (seconds on the flights' clock), for the stagger.
var _next_at: float = 0.0
var _clock: float = 0.0


## Flies from `sockets`' coins into `meter`'s lap lamp.
func _init(sockets: MedalSockets, meter: QuotaMeter) -> void:
	name = "MedalFlight"
	_sockets = sockets
	_meter = meter
	_layer = CanvasLayer.new()
	_layer.name = "MedalLayer"
	_layer.layer = LAYER
	add_child(_layer)


## Medal `gold` leaves its socket for the lap lamp; `landed` is called as it lands (`instant`:
## at once, with no flight, still with its coin sound: reduced motion drops the motion only).
func fly(gold: bool, instant: bool, landed: Callable) -> void:
	var from: Rect2 = _sockets.medal_canvas_rect(gold) if _sockets != null else Rect2()
	if _sockets != null:
		_sockets.launch(gold)
	var to: Rect2 = _meter.lamp_canvas_rect() if _meter != null else Rect2()
	if instant or not from.has_area() or not to.has_area() or not is_inside_tree():
		_land(gold, landed)
		return
	var flyer: MedalFlyer = MedalFlyer.new(gold)
	_layer.add_child(flyer)
	_flyers.append(flyer)
	flyer.place(from)
	var delay: float = maxf(0.0, _next_at - _clock)
	_next_at = _clock + delay + STAGGER
	var tween: Tween = flyer.create_tween()
	_tweens.append(tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	var move: Callable = func(k: float) -> void: flyer.place(_arc(from, to, k))
	tween.tween_method(move, 0.0, 1.0, FLIGHT_SECONDS)
	tween.finished.connect(
		func() -> void:
			_flyers.erase(flyer)
			_tweens.erase(tween)
			flyer.queue_free()
			_land(gold, landed)
	)


## The coins in flight now.
func flyers() -> Array[Control]:
	return _flyers.duplicate()


func is_flying() -> bool:
	return not _flyers.is_empty()


## Lands every coin in flight at once (a skipped count, tests).
func finish() -> void:
	for tween: Tween in _tweens.duplicate():
		if tween.is_valid():
			tween.custom_step(FLIGHT_SECONDS + STAGGER * 4.0)


func _process(delta: float) -> void:
	_clock += delta


## The coin's rect `k` of the way from `from` to `to`: an eased arc lifted ARC_LIFT at its middle.
static func _arc(from: Rect2, to: Rect2, k: float) -> Rect2:
	var e: float = StoreCamera.ease_in_out(k)
	var centre: Vector2 = from.get_center().lerp(to.get_center(), e)
	centre.y -= ARC_LIFT * sin(PI * k)
	var side: float = lerpf(from.size.x, to.size.x, e)
	return Rect2(centre - Vector2(side, side) / 2.0, Vector2(side, side))


func _land(gold: bool, landed: Callable) -> void:
	if _meter != null:
		_meter.pop_lamp()
	Sfx.play_at(self, "coin")
	if landed.is_valid():
		landed.call(gold)
