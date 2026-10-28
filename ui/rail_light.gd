class_name RailLight
extends Control
## #86's rail light, kept by #105 piece 2 (mock-up readability_v3.html's railLightHTML): as a
## giver's effect pays in the count, the price rail's top strip (RAIL_Y, RAIL_HEIGHT px, between
## its ink lines) lights gold from the giver's ticket to the target's over rail_run_s (its head a
## paper block with two sparks), the giver's ticket gets a gold edge at once and the target's once
## the light reaches it; the light holds to rail_hold_s and fades over rail_fade_s
## (CountTotalTuning). A giver already in the bag lights from the rail's left end. It runs on
## `make_tween` (the count's clock). Under reduced motion it shows no run: the light and both edges
## show at once and fade the same. Stage coordinates (the layer covers the stage). Decor only.

const RAIL_Y := 414.0
const RAIL_HEIGHT := 6.0
const HIGHLIGHT := 2.0
const HEAD_WIDTH := 8.0
const EDGE := 2.0
const GRID := 2.0
const FROM_COLOR := Palette.MUSTARD
const TO_COLOR := Palette.GOLD
const HIGHLIGHT_COLOR := Palette.MUSTARD_PALE
const EDGE_COLOR := Palette.GOLD

## Returns a new Tween on the count's clock; none: the layer's own.
var make_tween: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _tuning: CountTotalTuning
## The live runs: each with its from and to x, its tickets' rects and its age.
var _runs: Array[Dictionary] = []


func _init(tuning: CountTotalTuning = null) -> void:
	name = "RailLight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning


## A giver's effect pays: the light runs from `from_x` to `to_x` (this layer's coordinates) with
## the giver's ticket `giver` (an empty rect for a bagged giver) and the target's `target` edged.
func run(from_x: float, to_x: float, giver: Rect2, target: Rect2) -> void:
	var lit: Dictionary = {"from": from_x, "to": to_x, "giver": giver, "target": target, "q": 0.0}
	if _reduced():
		lit["q"] = _tuning.rail_run_s
	_runs.append(lit)
	queue_redraw()
	if not is_inside_tree():
		return
	var life: float = _tuning.rail_hold_s + _tuning.rail_fade_s
	var tween: Tween = _new_tween()
	var start: float = lit["q"]
	tween.tween_method(_age.bind(lit), start, life, maxf(0.01, life - start))
	tween.tween_callback(_end.bind(lit))


## Whether a light shows now, its lit span (from, head x) and its alpha, for checks.
func is_lit() -> bool:
	return not _runs.is_empty()


func lit_span() -> Vector2:
	if _runs.is_empty():
		return Vector2.ZERO
	var lit: Dictionary = _runs[-1]
	return Vector2(lit["from"], _head(lit))


func alpha() -> float:
	return _alpha(_runs[-1]) if not _runs.is_empty() else 0.0


func clear() -> void:
	_runs.clear()
	queue_redraw()


func _draw() -> void:
	for lit: Dictionary in _runs:
		_draw_run(lit)


func _draw_run(lit: Dictionary) -> void:
	var alpha_now: float = _alpha(lit)
	if alpha_now <= 0.0:
		return
	var from_x: float = lit["from"]
	var head: float = _head(lit)
	var left: float = minf(from_x, head)
	var width: float = absf(head - from_x)
	var column: float = 0.0
	while column < width:
		var share: float = column / maxf(1.0, width)
		var colour: Color = FROM_COLOR.lerp(TO_COLOR, share)
		colour.a = alpha_now
		draw_rect(Rect2(left + column, RAIL_Y, minf(GRID, width - column), RAIL_HEIGHT), colour)
		column += GRID
	if width > 0.0:
		draw_rect(Rect2(left, RAIL_Y, width, HIGHLIGHT), Color(HIGHLIGHT_COLOR, alpha_now))
	var arrived: bool = float(lit["q"]) >= _tuning.rail_run_s
	if not arrived:
		draw_rect(Rect2(head - HEAD_WIDTH / 2.0, RAIL_Y, HEAD_WIDTH, RAIL_HEIGHT), Palette.PAPER)
		_spark(Vector2(head - 6.0, RAIL_Y - 6.0), Palette.PAPER)
		_spark(Vector2(head - 10.0, RAIL_Y + 6.0), Palette.MUSTARD_LIGHT)
	var giver: Rect2 = lit["giver"]
	if giver.has_area():
		_edge(giver, alpha_now)
	var target: Rect2 = lit["target"]
	if arrived and target.has_area():
		_edge(target, alpha_now)


## A plus of gold cells round a centre of `centre_colour`.
func _spark(at: Vector2, centre_colour: Color) -> void:
	var cell: Vector2 = Vector2.ONE * GRID
	var spot: Vector2 = at.snapped(cell)
	for arm: Vector2 in [Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2)]:
		draw_rect(Rect2(spot + arm, cell), Palette.GOLD)
	draw_rect(Rect2(spot, cell), centre_colour)


func _edge(rect: Rect2, alpha_now: float) -> void:
	draw_rect(rect.grow(EDGE / 2.0), Color(EDGE_COLOR, alpha_now), false, EDGE)


func _head(lit: Dictionary) -> float:
	var from_x: float = lit["from"]
	var to_x: float = lit["to"]
	var run_q: float = clampf(float(lit["q"]) / maxf(0.01, _tuning.rail_run_s), 0.0, 1.0)
	var eased: float = run_q * run_q * (3.0 - 2.0 * run_q)
	return snappedf(lerpf(from_x, to_x, eased), GRID)


func _alpha(lit: Dictionary) -> float:
	var q: float = lit["q"]
	if q < _tuning.rail_hold_s:
		return 1.0
	return clampf(1.0 - (q - _tuning.rail_hold_s) / maxf(0.01, _tuning.rail_fade_s), 0.0, 1.0)


func _age(seconds: float, lit: Dictionary) -> void:
	lit["q"] = seconds
	queue_redraw()


func _end(lit: Dictionary) -> void:
	_runs.erase(lit)
	queue_redraw()


func _new_tween() -> Tween:
	if make_tween.is_valid():
		var tween: Tween = make_tween.call() as Tween
		if tween != null:
			return tween
	return create_tween()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
