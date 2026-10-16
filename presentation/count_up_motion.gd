class_name CountUpMotion
extends RefCounted
## The count-up's small motions on any control: punches, sideways shakes, the scan lift, a
## glow, and labels that fly or pop over the overlay. Every tween comes from the count-up
## (`make_tween`), so it follows the count-up's speed and hit-stops.
##
## A new punch on a node replaces the one running on it, and a new shake replaces a running
## shake from the same rest position, so a node always ends at scale 1 and at the x it rested
## at. Under reduced_motion nothing shakes.

const SCAN_LIFT := -22.0
const GLOW := Color(1.3, 1.3, 1.15)
## A shake swings this long each way, then settles back.
const SHAKE_SWING := 0.03
const SHAKE_SETTLE := 0.04

## No shakes (the player's reduced motion setting).
var reduced_motion: bool = false
var _overlay: Control
## Returns a new Tween that follows the count-up's speed.
var _make_tween: Callable
## Each shaken node's rest x and its running shake.
var _shake_rest: Dictionary[Control, float] = {}
var _shakes: Dictionary[Control, Tween] = {}
## Each punched node's running scale tween.
var _scales: Dictionary[Control, Tween] = {}


func _init(overlay: Control, make_tween: Callable) -> void:
	_overlay = overlay
	_make_tween = make_tween


## Forgets the nodes of the last count-up (their tweens have ended).
func reset(reduce_motion: bool) -> void:
	reduced_motion = reduce_motion
	_shake_rest.clear()
	_shakes.clear()
	_scales.clear()


func punch(node: Control, strength: float) -> void:
	node.pivot_offset = node.size / 2.0
	var tween: Tween = scale_tween(node).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(strength, strength), 0.07)
	tween.tween_property(node, "scale", Vector2.ONE, 0.18)


## A new scale tween for `node`, replacing the one running on it.
func scale_tween(node: Control) -> Tween:
	var running: Tween = _scales.get(node) as Tween
	if running != null and running.is_valid():
		running.kill()
	var tween: Tween = _tween()
	_scales[node] = tween
	return tween


## Shakes `node` sideways around its rest x, `swings` times with a fading amplitude, and always
## ends at that rest: a shake on a node already shaking replaces it from the same rest. None
## under reduced motion.
func shake(node: Control, amount: float, swings: int = 4) -> void:
	if node == null or amount <= 0.0 or reduced_motion:
		return
	var running: Tween = _shakes.get(node) as Tween
	if running != null and running.is_valid():
		running.kill()
	else:
		_shake_rest[node] = node.position.x
	var rest: float = _shake_rest[node]
	node.position.x = rest
	var tween: Tween = _tween()
	for swing: int in range(swings):
		var side: float = 1.0 if swing % 2 == 0 else -1.0
		var fade: float = 1.0 - float(swing) / swings
		tween.tween_property(node, "position:x", rest + side * amount * fade, SHAKE_SWING)
	tween.tween_property(node, "position:x", rest, SHAKE_SETTLE)
	tween.tween_callback(_end_shake.bind(node))
	_shakes[node] = tween


## The card lifts off the belt with its badge, as the scanner reads it.
func lift(view: CardView, seconds: float) -> void:
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view.body, "position:y", SCAN_LIFT, seconds)
	tween.tween_property(view.badge, "position:y", view.badge_rest_y() + SCAN_LIFT, seconds)


## The card drops back onto the belt with its badge.
func drop(view: CardView, seconds: float) -> void:
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_BOUNCE).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(view.body, "position:y", 0.0, seconds)
	tween.tween_property(view.badge, "position:y", view.badge_rest_y(), seconds)


## A control lights up for a moment.
func glow(node: Control) -> void:
	var tween: Tween = _tween()
	tween.tween_property(node, "modulate", GLOW, 0.05)
	tween.tween_property(node, "modulate", Color.WHITE, 0.13)


## A label flies from `from` to `to` (centres, global) over `duration`, growing a little or,
## with `fade_out`, fading away; it is freed when it arrives.
func fly_text(
	text: String,
	from: Vector2,
	to: Vector2,
	color: Color,
	font_size: int,
	duration: float,
	fade_out: bool = false
) -> void:
	var label: Label = text_label(text, color, font_size)
	_overlay.add_child(label)
	label.global_position = from - label.size / 2.0
	label.pivot_offset = label.size / 2.0
	var tween: Tween = _tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	tween.tween_property(label, "global_position", to - label.size / 2.0, duration)
	if fade_out:
		tween.tween_property(label, "modulate:a", 0.0, duration)
	else:
		tween.tween_property(label, "scale", Vector2(1.25, 1.25), duration)
	await tween.finished
	label.queue_free()


## A label pops onto `at` (big, then its size over `seconds`) and fades away there.
func pop_text(text: String, at: Vector2, color: Color, font_size: int, seconds: float) -> void:
	var label: Label = text_label(text, color, font_size)
	_overlay.add_child(label)
	label.global_position = at - label.size / 2.0
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.4, 1.4)
	var tween: Tween = _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, seconds)
	tween.tween_interval(0.1)
	tween.tween_property(label, "modulate:a", 0.0, 0.15)
	tween.tween_callback(label.queue_free)


## A big outlined label, sized to its text.
static func text_label(text: String, color: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.size = label.get_minimum_size()
	return label


func _end_shake(node: Control) -> void:
	_shakes.erase(node)
	_shake_rest.erase(node)


func _tween() -> Tween:
	return _make_tween.call() as Tween
