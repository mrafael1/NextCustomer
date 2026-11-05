class_name RestockHover
extends RefCounted
## The start screen's RESTOCK pick hover, as the shift's redraw hover (BasketRedraw.hover): with
## motion a hovered basket eases up hover_lift px and wobbles about its pivot, then eases back on
## leaving. One tween per basket; the redraw's own RedrawTuning gives the timings.

var _tuning: RedrawTuning = load(BasketRedraw.TUNING_PATH)
var _tweens: Dictionary[int, Tween] = {}


## Starts basket `basket`'s hover (or its ease back) on `bob`; returns the tween.
func play(basket: int, bob: Control, inside: bool) -> Tween:
	stop(basket)
	var tween: Tween = bob.create_tween()
	var lift: float = -_tuning.hover_lift if inside else 0.0
	tween.tween_property(bob, "position:y", lift, _tuning.hover_in_s).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bob, "rotation", 0.0, _tuning.hover_in_s)
	if inside:
		var span: float = _tuning.hover_wobble_s
		tween.tween_method(_wobble.bind(bob), 0.0, span, span)
	_tweens[basket] = tween
	return tween


func stop(basket: int) -> void:
	var running: Tween = _tweens.get(basket) as Tween
	if running != null and running.is_valid():
		running.kill()
	_tweens.erase(basket)


func clear() -> void:
	_tweens.clear()


## The wobble `since` seconds in: hover_wobble_deg of sin(hover_wobble_rate t), fading out.
func _wobble(since: float, bob: Control) -> void:
	var fade: float = clampf(1.0 - since / maxf(_tuning.hover_wobble_s, 0.001), 0.0, 1.0)
	var angle: float = _tuning.hover_wobble_deg * sin(since * _tuning.hover_wobble_rate) * fade
	bob.rotation = deg_to_rad(angle)
