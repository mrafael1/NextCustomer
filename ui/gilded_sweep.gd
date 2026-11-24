class_name GildedSweep
extends Control
## The light on a maxed perk's gilded box (alpha feedback v1.48, mock-up maxed_perk.html A),
## laid over the whole box (LoyaltyCard): every SWEEP_PERIOD a light band crosses the disc on the
## art grid, top left to bottom right, in SWEEP_LENGTH. Reaching the top level (play_reach) wipes
## the box's previous face off from the bottom up over FILL_S, showing the gold under it, then
## the disc flashes (FLASH_S) and four plus sparkles burst out past its corners (SPARKLE_S); the
## first sweep follows. Reduced motion (`reduced_motion`): no sweep, no wipe, no flash, no
## sparkles; the gilded box stands still.

const SWEEP_PERIOD := 3.0
const SWEEP_LENGTH := 0.6
## The band: its core within SWEEP_CORE art px of its diagonal, its edge within SWEEP_EDGE.
const SWEEP_CORE := 0.6
const SWEEP_EDGE := 1.6
const SWEEP_CORE_COLOUR := Color(Palette.PAPER, 0.8)
const SWEEP_EDGE_COLOUR := Color(Palette.MUSTARD_PALE, 0.45)
## Reaching max: the wipe, the flash and the sparkles, then the first sweep after SWEEP_AFTER.
const FILL_S := 0.45
const FLASH_S := 0.1
const FLASH_COLOUR := Color(Palette.MUSTARD_PALE, 0.7)
const SPARKLE_S := 0.5
## A sparkle's plus is big (paper heart, gold arms) for its first SPARKLE_BIG of its life, then
## one mustard pale texel; it starts SPARKLE_OUT art px past the disc's corner square and drifts
## SPARKLE_DRIFT art px further out.
const SPARKLE_BIG := 0.7
const SPARKLE_OUT := 1.0
const SPARKLE_DRIFT := 1.5
const SWEEP_AFTER := 0.55
## The node holding the previous face during the wipe.
const WINDOW_NAME := "Window"

## Returns the profile's reduced motion (unset: full motion).
var reduced_motion: Callable = Callable()

var _box: Vector2
## Seconds into the sweep's cycle (below 0: none yet).
var _clock: float = SWEEP_LENGTH
## Seconds since reaching max began (below 0: not reaching).
var _reach: float = -1.0
var _window: Control
var _drawn: bool = false


## Over a `box` px box.
func _init(box: Vector2) -> void:
	_box = box
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = box


## Reaches max over the box's previous face `old_face` (a box built at the level before): wipes it
## off bottom to top, then flashes and sparkles. Under reduced motion `old_face` is dropped at once.
func play_reach(old_face: Control) -> void:
	if _wants_reduced_motion():
		old_face.free()
		return
	_reach = 0.0
	_clock = -SWEEP_AFTER
	_window = Control.new()
	_window.name = WINDOW_NAME
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.clip_contents = true
	_window.size = _box
	add_child(_window)
	_mute(old_face)
	old_face.position = Vector2.ZERO
	old_face.size = _box
	_window.add_child(old_face)


## Whether the box is still reaching max (wipe, flash or sparkles).
func is_reaching() -> bool:
	return _reach >= 0.0


## Whether the previous face still shows (the wipe).
func has_old_face() -> bool:
	return _window != null


## Whether the light band is crossing the disc now.
func is_sweeping() -> bool:
	return _clock >= 0.0 and fposmod(_clock, SWEEP_PERIOD) < SWEEP_LENGTH


func _process(delta: float) -> void:
	if _wants_reduced_motion():
		_reach = -1.0
		_drop_window()
		if _drawn:
			queue_redraw()
		return
	_clock += delta
	if _reach >= 0.0:
		_reach += delta
		if _window != null:
			var texel: float = float(ArtStyle.ART_SCALE)
			var left: float = _box.y * (1.0 - clampf(_reach / FILL_S, 0.0, 1.0))
			_window.size = Vector2(_box.x, floorf(left / texel) * texel)
			if _reach >= FILL_S:
				_drop_window()
		if _reach >= FILL_S + SPARKLE_S:
			_reach = -1.0
	if _drawn or is_sweeping() or is_reaching():
		queue_redraw()


func _draw() -> void:
	_drawn = false
	if _wants_reduced_motion():
		return
	var texel: float = float(ArtStyle.ART_SCALE)
	var cells: int = int(_box.x / texel)
	var since: float = _reach - FILL_S
	if _reach >= 0.0 and since >= 0.0:
		if since < FLASH_S:
			for cell: Vector2i in _disc(cells):
				_put(cell, FLASH_COLOUR)
		_draw_sparkles(cells, since / SPARKLE_S)
	if is_sweeping():
		var along: float = fposmod(_clock, SWEEP_PERIOD) / SWEEP_LENGTH
		var at: float = -3.0 + along * float(2 * cells + 4)
		for cell: Vector2i in _disc(cells):
			var off: float = absf(float(cell.x + cell.y) - at)
			if off < SWEEP_CORE:
				_put(cell, SWEEP_CORE_COLOUR)
			elif off < SWEEP_EDGE:
				_put(cell, SWEEP_EDGE_COLOUR)


## The four plus sparkles `k` (0 .. 1) of the way through their life, past the disc's corners.
func _draw_sparkles(cells: int, k: float) -> void:
	if k >= 1.0:
		return
	var half: float = float(cells) / 2.0
	var out: float = half + SPARKLE_OUT + roundf(k * SPARKLE_DRIFT)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var at: Vector2i = Vector2i((Vector2(half, half) + corner * out).floor())
		if k < SPARKLE_BIG:
			for arm: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_put(at + arm, Palette.GOLD)
			_put(at, Palette.PAPER)
		else:
			_put(at, Palette.MUSTARD_PALE)


## The art cells inside the round box of `cells` x `cells`.
func _disc(cells: int) -> Array[Vector2i]:
	var inside: Array[Vector2i] = []
	var half: float = float(cells) / 2.0
	for y: int in cells:
		for x: int in cells:
			if Vector2(x + 0.5 - half, y + 0.5 - half).length_squared() <= half * half:
				inside.append(Vector2i(x, y))
	return inside


func _put(cell: Vector2i, colour: Color) -> void:
	var texel: Vector2 = Vector2.ONE * ArtStyle.ART_SCALE
	draw_rect(Rect2(Vector2(cell) * texel, texel), colour)
	_drawn = true


func _drop_window() -> void:
	if _window != null:
		_window.queue_free()
		_window = null


## Takes the mouse off `face` and everything in it, so the wiped face never takes a hover.
static func _mute(face: Control) -> void:
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in face.get_children():
		if child is Control:
			_mute(child as Control)


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
