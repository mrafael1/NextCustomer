class_name MedalSockets
extends Control
## The week chip's two medal sockets (2026-11-06, WeekMedals; mock-up
## docs/art/mockups/week_medals.html): after the day pips, SILVER then GOLD, each MedalArt's plain
## coin while AVAILABLE, the same coin shimmering (a glint running round its rim, a faint halo) and
## wobbling a screen pixel while PENDING (the plan would spend it), and an empty engraved socket
## once USED, for the rest of the week. When a used medal comes back (a new week) it pops back in.
## launch() empties a socket as its medal flies off (MedalFlight). Drawn in whole screen pixels, as
## the pips are (WeekChip.screen_transform), so the coins stay crisp at the 1.5x stretch. Hovering a
## socket shows its own tooltip; a click goes through to the chip (it opens the time card).

## The coins: MedalArt.SIZE canvas px across, GAP apart.
const GAP := 3.0
## PENDING: the glint goes round GLINT_TURNS times a second, the coin wobbles WOBBLE_HZ times a
## second (one screen pixel either way), the halo pulses round HALO_ALPHA.
const GLINT_TURNS := 0.45
const WOBBLE_HZ := 2.6
const HALO_ALPHA := 0.35
const HALO_PULSE := 0.15
## A medal back in its socket pops from POP_FROM of its size over POP_SECONDS, overshooting.
const POP_SECONDS := 0.35
const POP_FROM := 0.2
const POP_OVER := 1.25
const POP_PEAK := 0.7

## Reduced motion: no wobble, no running glint, no pop (a pending medal keeps a steady halo).
var reduced_motion: bool = false

## The states shown (WeekMedals.State), [SILVER, GOLD].
var _states: Array[int] = [WeekMedals.State.OFF, WeekMedals.State.OFF]
var _tips: PackedStringArray = PackedStringArray(["", ""])
var _time: float = 0.0
## Seconds into each medal's pop back in (below 0: none).
var _pops: Array[float] = [-1.0, -1.0]


func _init() -> void:
	name = "MedalSockets"
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(MedalArt.SIZE * 2.0 + GAP, MedalArt.SIZE)
	visible = false
	set_process(false)
	# The coins snap to the screen's pixels: a moved socket redraws them.
	item_rect_changed.connect(queue_redraw)


## Shows `shown` ([SILVER, GOLD], WeekMedals.State) with their tooltips `tips`. A medal back from
## USED pops back in (not under reduced motion); hidden while both are OFF.
func show_states(shown: Array[int], tips: PackedStringArray) -> void:
	for index: int in range(2):
		var back: bool = _states[index] == WeekMedals.State.USED and _is_coin(shown[index])
		if back and not reduced_motion:
			_pops[index] = 0.0
	_states = shown.duplicate()
	_tips = tips
	visible = _states.any(func(state: int) -> bool: return state != WeekMedals.State.OFF)
	# The OFF ones take no room: the GOLD's socket alone sits where the SILVER's was.
	var count: int = 2 - _states.count(WeekMedals.State.OFF)
	custom_minimum_size.x = MedalArt.SIZE * count + GAP * maxi(count - 1, 0)
	_update_process()
	queue_redraw()


## The states shown, [SILVER, GOLD].
func states() -> Array[int]:
	return _states.duplicate()


func state_of(gold: bool) -> int:
	return _states[1 if gold else 0]


## Medal `gold` leaves its socket (MedalFlight carries it): the socket is empty from now on.
func launch(gold: bool) -> void:
	_states[1 if gold else 0] = WeekMedals.State.USED
	_pops[1 if gold else 0] = -1.0
	_update_process()
	queue_redraw()


## Medal `gold`'s coin rect in this control (canvas px; empty while OFF).
func medal_rect(gold: bool) -> Rect2:
	var index: int = 1 if gold else 0
	if _states[index] == WeekMedals.State.OFF:
		return Rect2()
	var slot: int = 0 if index == 0 or _states[0] == WeekMedals.State.OFF else 1
	var top: float = (size.y - MedalArt.SIZE) / 2.0
	return Rect2(Vector2(slot * (MedalArt.SIZE + GAP), top), Vector2.ONE * MedalArt.SIZE)


## Medal `gold`'s coin rect on the canvas (with its canvas layer's transform: where a flight from
## it starts), empty while OFF or not shown.
func medal_canvas_rect(gold: bool) -> Rect2:
	var rect: Rect2 = medal_rect(gold)
	if not rect.has_area() or not is_visible_in_tree():
		return Rect2()
	return get_global_transform_with_canvas() * rect


## Whether medal `gold` wobbles now (PENDING, with motion).
func wobbling(gold: bool) -> bool:
	return _states[1 if gold else 0] == WeekMedals.State.PENDING and not reduced_motion


## Whether medal `gold` is popping back in.
func popping(gold: bool) -> bool:
	return _pops[1 if gold else 0] >= 0.0


## Moves the shimmer and the pops on by `seconds` (tests; _process moves them by the frame's).
func advance(seconds: float) -> void:
	_time += seconds
	for index: int in range(2):
		if _pops[index] >= 0.0:
			_pops[index] += seconds
			if _pops[index] >= POP_SECONDS:
				_pops[index] = -1.0
	_update_process()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _get_tooltip(at_position: Vector2) -> String:
	for index: int in range(2):
		if medal_rect(index == 1).grow(GAP / 2.0).has_point(at_position):
			return _tips[index]
	return ""


func _update_process() -> void:
	var pending: bool = _states.has(WeekMedals.State.PENDING) and not reduced_motion
	set_process(pending or _pops[0] >= 0.0 or _pops[1] >= 0.0)


static func _is_coin(state: int) -> bool:
	return state == WeekMedals.State.AVAILABLE or state == WeekMedals.State.PENDING


func _draw() -> void:
	var screen: Transform2D = Transform2D.IDENTITY
	if is_inside_tree():
		screen = WeekChip.screen_transform(self)
	var scale_x: float = screen.get_scale().x
	var cells: int = MedalArt.cells_at(scale_x)
	draw_set_transform_matrix(screen.affine_inverse())
	for index: int in range(2):
		var gold: bool = index == 1
		var rect: Rect2 = medal_rect(gold)
		if not rect.has_area():
			continue
		var on_screen: Rect2 = screen * rect
		var origin: Vector2 = (on_screen.get_center() - Vector2(cells, cells) / 2.0).round()
		var state: int = _states[index]
		if state == WeekMedals.State.USED:
			MedalArt.draw_socket(self, origin, cells, 1.0)
		elif state == WeekMedals.State.AVAILABLE and _pops[index] >= 0.0:
			MedalArt.draw_socket(self, origin, cells, 1.0)
			_draw_pop(index, on_screen.get_center(), cells)
		elif state == WeekMedals.State.AVAILABLE:
			MedalArt.draw_coin(self, origin, cells, 1.0, gold)
		elif state == WeekMedals.State.PENDING:
			_draw_pending(gold, origin, cells)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A pending coin: its halo pulsing, wobbling a pixel, its glint running round (reduced motion:
## a steady halo, no glint, no wobble).
func _draw_pending(gold: bool, origin: Vector2, cells: int) -> void:
	var colours: Array[Color] = MedalArt.metal(gold)
	var halo: float = HALO_ALPHA
	var glint: float = -1.0
	var at: Vector2 = origin
	if not reduced_motion:
		halo += HALO_PULSE * sin(TAU * _time * WOBBLE_HZ / 2.0)
		glint = fposmod(TAU * _time * GLINT_TURNS, TAU) - PI
		at.x += roundf(sin(TAU * _time * WOBBLE_HZ))
	MedalArt.draw_halo(self, origin, cells, 1.0, Color(colours[2], halo))
	MedalArt.draw_coin(self, at, cells, 1.0, gold, 1.0, glint)


## A medal popping back in: the coin from POP_FROM of its size past POP_OVER and back, centred.
func _draw_pop(index: int, centre: Vector2, cells: int) -> void:
	var k: float = clampf(_pops[index] / POP_SECONDS, 0.0, 1.0)
	var grow: float = lerpf(POP_OVER, 1.0, (k - POP_PEAK) / (1.0 - POP_PEAK))
	if k < POP_PEAK:
		grow = lerpf(POP_FROM, POP_OVER, k / POP_PEAK)
	var shown: int = maxi(3, roundi(cells * grow))
	var origin: Vector2 = (centre - Vector2(shown, shown) / 2.0).round()
	MedalArt.draw_coin(self, origin, shown, 1.0, index == 1)
