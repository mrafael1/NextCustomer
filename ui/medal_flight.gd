class_name MedalFlight
extends Node
## A week medal's spending at the checkout (2026-11-06, mock-up docs/art/mockups/week_medals.html
## section 3; since v1.17 from the register's medal case). Since the user's play test of
## 2026-11-10 it reads as one chain, the gauge to the medal to the receipt: the gauge's lap lamp
## pops (QuotaMeter.pop_lamp) and sends a token (LampToken: the lamp lit in the medal's metal) down
## to the medal in the case over TOKEN_SECONDS; as it lands, the medal leaves the case
## (MedalCase.launch: its socket is empty and WON shows from then on) and flies up onto the
## receipt's target (ReceiptTarget's digits) on an arc over FLIGHT_SECONDS; as it lands a coin
## rings and `landed` is called (the receipt turns its metal). The chains run in CHECKOUT's medal
## prelude (MedalPrelude), while the gauge still shows. Two medals close together go one after the
## other, at least STAGGER apart. Reduced motion: no flight, the socket empties and `landed` is
## called at once. With no lamp on screen the medal flies alone.
## The token and the medal fly on their own canvas layer, over the stage and the top bar. Display
## only.

## The token's and the medal's flights, the second medal's delay, the arcs' lift (canvas px, at
## their middle).
const TOKEN_SECONDS := 0.3
const FLIGHT_SECONDS := 0.5
const STAGGER := 0.25
const ARC_LIFT := 60.0
## Over the stage, the top bar and the machine.
const LAYER := 90

var _case: MedalCase
var _meter: QuotaMeter
var _target: ReceiptTarget
var _layer: CanvasLayer
## The tokens and medals in flight, and the chains' tweens.
var _flyers: Array[Control] = []
var _tweens: Array[Tween] = []
## When the next chain may start (seconds on the flights' clock), for the stagger.
var _next_at: float = 0.0
var _clock: float = 0.0


## Chains from `meter`'s lap lamp to `medal_case`'s medals to `target` (the receipt's).
func _init(medal_case: MedalCase, meter: QuotaMeter, target: ReceiptTarget = null) -> void:
	name = "MedalFlight"
	_case = medal_case
	_meter = meter
	_target = target
	_layer = CanvasLayer.new()
	_layer.name = "MedalLayer"
	_layer.layer = LAYER
	add_child(_layer)


## Spends medal `gold`: the lamp's token flies to it, it leaves the case for the receipt's target,
## and `landed` is called as it lands (`instant`: at once, with no flight, still with its coin
## sound: reduced motion drops the motion only).
func fly(gold: bool, instant: bool, landed: Callable) -> void:
	var from: Rect2 = _case.medal_canvas_rect(gold) if _case != null else Rect2()
	var to: Rect2 = _destination(from.size)
	if instant or not from.has_area() or not to.has_area() or not is_inside_tree():
		_launch(gold)
		_land(gold, landed)
		return
	var delay: float = maxf(0.0, _next_at - _clock)
	_next_at = _clock + delay + STAGGER
	var tween: Tween = create_tween()
	_tweens.append(tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	var lamp: Rect2 = _meter.lamp_canvas_rect() if _meter != null else Rect2()
	if lamp.has_area():
		var token: LampToken = LampToken.new(gold)
		_wait(token)
		var onto: Rect2 = Rect2(from.get_center() - lamp.size / 2.0, lamp.size)
		tween.tween_callback(_send.bind(token, lamp, true))
		tween.tween_method(
			func(k: float) -> void: token.place(_arc(lamp, onto, k)), 0.0, 1.0, TOKEN_SECONDS
		)
		tween.tween_callback(_drop.bind(token))
	var flyer: MedalFlyer = MedalFlyer.new(gold)
	_wait(flyer)
	tween.tween_callback(_launch.bind(gold))
	tween.tween_callback(_send.bind(flyer, from, false))
	tween.tween_method(
		func(k: float) -> void: flyer.place(_arc(from, to, k)), 0.0, 1.0, FLIGHT_SECONDS
	)
	tween.tween_callback(_drop.bind(flyer))
	tween.tween_callback(
		func() -> void:
			_tweens.erase(tween)
			_land(gold, landed)
	)


## The tokens and medals in flight now.
func flyers() -> Array[Control]:
	return _flyers.duplicate()


## Whether a chain is under way (its token or its medal flying, or waiting its turn).
func is_flying() -> bool:
	return not _tweens.is_empty()


## Lands every chain at once (a skipped count, tests).
func finish() -> void:
	for tween: Tween in _tweens.duplicate():
		if tween.is_valid():
			tween.custom_step(TOKEN_SECONDS + FLIGHT_SECONDS + STAGGER * 4.0)


func _process(delta: float) -> void:
	_clock += delta


## The coin's rect `k` of the way from `from` to `to`: an eased arc lifted ARC_LIFT at its middle.
static func _arc(from: Rect2, to: Rect2, k: float) -> Rect2:
	var e: float = StoreCamera.ease_in_out(k)
	var centre: Vector2 = from.get_center().lerp(to.get_center(), e)
	centre.y -= ARC_LIFT * sin(PI * k)
	var side: float = lerpf(from.size.x, to.size.x, e)
	return Rect2(centre - Vector2(side, side) / 2.0, Vector2(side, side))


## The landing's rect on the canvas: `size` large, centred on the receipt's target digits (none
## without a receipt on screen).
func _destination(size: Vector2) -> Rect2:
	if _target == null or not _target.is_visible_in_tree():
		return Rect2()
	var digits: Rect2 = _target.get_global_transform_with_canvas() * _target.digits_rect()
	return Rect2((digits.get_center() - size / 2.0).round(), size)


## `flyer` (a token or a medal) waits its turn on the layer, hidden.
func _wait(flyer: Control) -> void:
	flyer.visible = false
	_layer.add_child(flyer)


## `flyer` (a token or a medal) takes off from `from`; a token's take-off pops the lamp.
func _send(flyer: Control, from: Rect2, from_lamp: bool) -> void:
	flyer.visible = true
	_flyers.append(flyer)
	flyer.call(&"place", from)
	if from_lamp and _meter != null:
		_meter.pop_lamp()


func _drop(flyer: Control) -> void:
	_flyers.erase(flyer)
	flyer.queue_free()


func _launch(gold: bool) -> void:
	if _case != null:
		_case.launch(gold)


func _land(gold: bool, landed: Callable) -> void:
	Sfx.play_at(self, "coin")
	if landed.is_valid():
		landed.call(gold)


## The lap lamp's token in flight: the lamp lit in the medal's metal (silver, or gold), with its
## check, as big as the lamp.
class LampToken:
	extends Control

	var gold: bool = false

	func _init(medal_gold: bool) -> void:
		name = "LampToken"
		gold = medal_gold
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Puts the token in `rect` (its layer's coordinates).
	func place(rect: Rect2) -> void:
		position = rect.position.round()
		size = rect.size
		queue_redraw()

	func _draw() -> void:
		var ramp: Array[Color] = QuotaLaps.backdrop_ramp(QuotaLaps.FIRST_LAP + (2 if gold else 1))
		LapLamp.draw(self, Vector2.ZERO, size.x / LapLamp.SIZE, ramp, LapLamp.CHECK_TEXT)
