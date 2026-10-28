extends GdUnitTestSuite
## The price rail's light (#86, kept by #105 piece 2: RailLight): a giver's run lights from its x
## to the target's over rail_run_s, holds to rail_hold_s, fades over rail_fade_s and is gone; it
## runs on `make_tween` (the count's clock); a bagged giver's run starts at the rail's left end
## (BeltRide's from x; D7); under reduced motion the light is in at once and fades the same; clear
## takes it off.

## Manual stepping of the tweens (seconds per step).
const STEP := 0.01

var _made: Array[Tween] = []


func before_test() -> void:
	_made.clear()


## A run: lit from `from` with its head moving to `to` over rail_run_s, at full alpha through the
## hold, fading after it, gone at its end.
func test_a_run_lights_holds_and_fades() -> void:
	var light: RailLight = await _light()
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	assert_bool(light.is_lit()).is_false()
	assert_float(light.alpha()).is_equal(0.0)
	light.run(100.0, 300.0, Rect2(80, 380, 40, 30), Rect2(280, 380, 40, 30))
	assert_bool(light.is_lit()).is_true()
	assert_int(_made.size()).is_equal(1)
	assert_float(light.lit_span().x).is_equal(100.0)
	assert_float(light.lit_span().y).is_equal(100.0)
	_advance(tuning.rail_run_s / 2.0)
	var middle: float = light.lit_span().y
	assert_float(middle).is_greater(100.0)
	assert_float(middle).is_less(300.0)
	_advance(tuning.rail_run_s / 2.0 + STEP)
	assert_float(light.lit_span().y).is_equal(300.0)
	assert_float(light.alpha()).is_equal(1.0)
	_advance(tuning.rail_hold_s - tuning.rail_run_s + tuning.rail_fade_s / 2.0)
	assert_float(light.alpha()).is_between(0.2, 0.8)
	_advance(tuning.rail_fade_s / 2.0 + STEP * 2.0)
	assert_bool(light.is_lit()).is_false()


## A run leftward (a target before its giver) moves its head left; a bagged giver (an empty
## rect) runs from the rail's left end all the same.
func test_a_run_can_go_left_or_start_at_the_rails_end() -> void:
	var light: RailLight = await _light()
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	light.run(400.0, 120.0, Rect2(380, 380, 40, 30), Rect2(100, 380, 40, 30))
	_advance(tuning.rail_run_s / 2.0)
	assert_float(light.lit_span().y).is_less(400.0)
	assert_float(light.lit_span().y).is_greater(120.0)
	light.clear()
	assert_bool(light.is_lit()).is_false()
	light.run(0.0, 200.0, Rect2(), Rect2(180, 380, 40, 30))
	assert_float(light.lit_span().x).is_equal(0.0)
	_advance(tuning.rail_run_s + STEP)
	assert_float(light.lit_span().y).is_equal(200.0)


## Reduced motion: the light is in at once, the whole span lit, and fades the same.
func test_reduced_motion_lights_it_at_once() -> void:
	var light: RailLight = await _light()
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	light.reduced_motion = func() -> bool: return true
	light.run(100.0, 300.0, Rect2(80, 380, 40, 30), Rect2(280, 380, 40, 30))
	assert_vector(light.lit_span()).is_equal(Vector2(100, 300))
	assert_float(light.alpha()).is_equal(1.0)
	_advance(tuning.rail_hold_s + tuning.rail_fade_s + STEP * 2.0)
	assert_bool(light.is_lit()).is_false()


## A rail light in the tree, its tweens paused and stepped by _advance.
func _light() -> RailLight:
	var light: RailLight = auto_free(RailLight.new())
	get_tree().root.add_child(light)
	light.size = Vector2(944, 540)
	light.make_tween = func() -> Tween:
		var tween: Tween = light.create_tween()
		tween.pause()
		_made.append(tween)
		return tween
	await get_tree().process_frame
	return light


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.00001:
		var step: float = minf(STEP, left)
		for tween: Tween in _made.duplicate():
			if tween.is_valid():
				tween.custom_step(step)
		left -= step
