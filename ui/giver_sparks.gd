class_name GiverSparks
extends Control
## A giver's sparks in the count (#86 v6, mock-up count_up_86_v6_scan's "zips"): as an armed
## giver (Coffee, Eggs, Multipack) is scanned, gold pixel sparks run from the scanner up the belt
## to each target's sticker, a spark with a short trail on an arc, and the sticker charges as one
## lands (BeltRide). Each run follows its sticker live, so a sticker riding toward the scanner is
## still met. Drawn on the 2 px art grid in Palette's gold and paper. Its own layer over the
## planning stickers (PlanningLayer's child, the stage's size); decor only: it takes no clicks.

## A run's arc over the straight line, at its middle (px).
const ARC := 26.0
## The trail: TRAIL dots behind the spark, each TRAIL_LAG of the run behind the one before.
const TRAIL := 3
const TRAIL_LAG := 0.06
## The spark's cells (art pixels about its centre): a plus, paper in the middle.
const SPARK_ARMS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)
]

var _runs: Array[Run] = []


## One spark's run: from `from` (layer coordinates) to the middle of `target`'s top edge.
class Run:
	extends RefCounted
	var from: Vector2 = Vector2.ZERO
	var target: Control
	var progress: float = 0.0
	var tween: Tween


func _init() -> void:
	name = "GiverSparks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE


func _draw() -> void:
	var cell: float = ArtStyle.ART_SCALE
	for run: Run in _runs:
		if not is_instance_valid(run.target) or run.progress <= 0.0:
			continue
		var to: Vector2 = _target_point(run.target)
		for dot: int in range(TRAIL, -1, -1):
			var along: float = clampf(run.progress - dot * TRAIL_LAG, 0.0, 1.0)
			var at: Vector2 = run.from.lerp(to, along) - Vector2(0, sin(along * PI) * ARC)
			at = at.snappedf(cell)
			if dot > 0:
				var colour: Color = Palette.PAPER if dot == 1 else Palette.MUSTARD_LIGHT
				draw_rect(Rect2(at, Vector2(cell, cell)), colour)
				continue
			for arm: Vector2i in SPARK_ARMS:
				draw_rect(Rect2(at + Vector2(arm) * cell, Vector2(cell, cell)), Palette.GOLD)
			draw_rect(Rect2(at, Vector2(cell, cell)), Palette.PAPER)


## Sends a spark from `from` (global) to `target` over `seconds`, after `delay` seconds, on
## `make_tween`'s tweens when given (the count-up's: its hit-stops and skips hold and speed it);
## `landed` is called as it reaches the target.
func send(
	from: Vector2,
	target: Control,
	seconds: float,
	delay: float = 0.0,
	make_tween: Callable = Callable(),
	landed: Callable = Callable()
) -> void:
	if not is_inside_tree() or target == null:
		return
	var run: Run = Run.new()
	run.from = get_global_transform().affine_inverse() * from
	run.target = target
	_runs.append(run)
	run.tween = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	if delay > 0.0:
		run.tween.tween_interval(delay)
	run.tween.tween_method(_advance.bind(run), 0.0, 1.0, maxf(seconds, 0.01))
	run.tween.tween_callback(_land.bind(run, landed))


## How many sparks are running.
func running() -> int:
	return _runs.size()


## Every running spark's head (layer coordinates), for tests.
func heads() -> Array[Vector2]:
	var found: Array[Vector2] = []
	for run: Run in _runs:
		if is_instance_valid(run.target):
			var to: Vector2 = _target_point(run.target)
			found.append(run.from.lerp(to, run.progress) - Vector2(0, sin(run.progress * PI) * ARC))
	return found


## Stops every spark.
func clear() -> void:
	for run: Run in _runs:
		if run.tween != null and run.tween.is_valid():
			run.tween.kill()
	_runs.clear()
	queue_redraw()


func _advance(progress: float, run: Run) -> void:
	run.progress = progress
	queue_redraw()


func _land(run: Run, landed: Callable) -> void:
	_runs.erase(run)
	queue_redraw()
	if landed.is_valid():
		landed.call()


## The middle of `target`'s top edge, in this layer's coordinates.
func _target_point(target: Control) -> Vector2:
	var rect: Rect2 = get_global_transform().affine_inverse() * target.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y)
