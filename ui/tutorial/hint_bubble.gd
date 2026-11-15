class_name HintBubble
extends TipCard
## The guided shift's reactive hint (PlanHint, play test 1 2026-11-15): the hover tip's paper card
## with the tutorial's mustard band, popped over the item it is about (or the checkout key), its
## tail on it. It never takes a click, follows its target as the belt moves, holds HOLD_S and
## fades out; a new hint replaces it at once.

const HOLD_S := 4.0
const FADE_S := 0.2
## The bubble's width in canvas px (narrower than a hover tip: one or two short lines).
const BUBBLE_WIDTH := 260.0

## What the tail points at now: a Callable returning a global Rect2 (Rect2() hides the bubble).
var _target: Callable = Callable()
var _left: float = 0.0
var _fading: Tween


func _init() -> void:
	super()
	name = "HintBubble"
	visible = false
	width_override = BUBBLE_WIDTH


## Pops `title` and `line` (TipMarkup) over the rect `target` returns, for HOLD_S.
func pop(title: String, line: String, target: Callable, reduced_motion: bool = false) -> void:
	var tip: TipSpec = TipSpec.make(TipSpec.Kind.WORD, title, line)
	tip.band = Palette.MUSTARD
	tip.band_ink = Palette.INK
	width_override = roundf(BUBBLE_WIDTH * UiKit.reading_scale / PX) * PX
	show_spec(tip)
	_ignore_mouse(self)
	_target = target
	_left = HOLD_S
	if _fading != null:
		_fading.kill()
	visible = true
	modulate.a = 1.0 if reduced_motion else 0.0
	if not reduced_motion:
		_fading = create_tween()
		_fading.tween_property(self, "modulate:a", 1.0, FADE_S)
	_follow()


## Hides it now.
func clear() -> void:
	if _fading != null:
		_fading.kill()
	_left = 0.0
	visible = false


## Whether a hint shows now.
func is_showing() -> bool:
	return visible and _left > 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		if _fading == null or not _fading.is_running():
			_fading = create_tween()
			_fading.tween_property(self, "modulate:a", 0.0, FADE_S)
			_fading.tween_callback(func() -> void: visible = false)
		return
	_follow()


## Opens above the target (below when there is no room), its tail on it, inside the parent.
func _follow() -> void:
	var parent: Control = get_parent() as Control
	if parent == null or not _target.is_valid():
		return
	var global: Rect2 = _target.call()
	if not global.has_area():
		modulate.a = 0.0
		return
	var origin: Vector2 = parent.get_global_rect().position
	var local: Rect2 = Rect2(global.position - origin, global.size)
	var screen: Rect2 = Rect2(Vector2.ZERO, parent.size)
	var placed: Array = TipCard.place(local, local, Opens.ABOVE, size, screen)
	position = (placed[0] as Rect2).position
	point_tail(placed[1] as Opens, local)


static func _ignore_mouse(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
