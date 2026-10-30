extends GdUnitTestSuite
## The title's storefront (#56, direction C+, Storefront): the stage is centred and the backdrop
## fills any window round it; the hit rects are the art's on the stage at 2x; the sign lights
## letter by letter (at once when still) and then shows the wedge and the reflections; the doors
## crack on hover and open in DOOR_STEP steps before the light floods in FLOOD_STEPS; the bay
## lights and the machine jiggles once; `still` holds every loop and slide.


func _front(window: Vector2 = Storefront.STAGE_SIZE) -> Storefront:
	var front: Storefront = auto_free(Storefront.new())
	add_child(front)
	front.set_anchors_preset(Control.PRESET_TOP_LEFT)
	front.size = window
	return front


func test_hit_rects_are_the_art_on_the_stage() -> void:
	var front: Storefront = _front()
	var art_scale: float = ArtStyle.ART_SCALE
	assert_vector(front.stage().position).is_equal(Vector2.ZERO)
	assert_vector(front.doors_rect().position).is_equal(Vector2(268, 132) * art_scale)
	assert_vector(front.doors_rect().size).is_equal(Vector2(104, 160) * art_scale)
	assert_vector(front.bay_rect().position).is_equal(Vector2(504, 108) * art_scale)
	assert_vector(front.bay_rect().size).is_equal(Vector2(128, 184) * art_scale)
	var sign_rect: Rect2 = front.sign_rect()
	assert_bool(Rect2(Vector2(224, 96), Vector2(832, 136)).encloses(sign_rect)).is_true()
	assert_bool(sign_rect.intersects(front.doors_rect())).is_false()
	assert_bool(front.doors_rect().intersects(front.bay_rect())).is_false()


func test_a_wider_or_taller_window_shows_more_street() -> void:
	for window: Vector2 in [Vector2(1900, 800), Vector2(1100, 900), Vector2(1600, 900)]:
		var front: Storefront = _front(window)
		var stage: Control = front.stage()
		assert_vector(stage.position).is_equal(((window - Storefront.STAGE_SIZE) / 2.0).floor())
		var backdrop: Rect2 = Rect2(front.get_child(0).position, front.get_child(0).size)
		assert_bool(backdrop.encloses(Rect2(Vector2.ZERO, window))).is_true()
		var stage_in_art: Vector2 = (stage.position - backdrop.position) / ArtStyle.ART_SCALE
		assert_vector(stage_in_art).is_equal(stage_in_art.round())
		assert_vector(front.doors_rect().position).is_equal(stage.position + Vector2(536, 264))


func test_the_sign_lights_letter_by_letter() -> void:
	var front: Storefront = _front()
	var neon: NeonSign = front.neon_sign()
	var lit: Array[bool] = [false]
	front.sign_lit.connect(func() -> void: lit[0] = true)
	assert_int(neon.lit_letters()).is_equal(0)
	assert_bool(front.layer("wedge").visible).is_false()
	front.light_up()
	neon._process(0.0)
	assert_int(neon.lit_letters()).is_equal(1)
	neon._process(NeonSign.LETTER_STEP * 3.0 + 0.001)
	assert_int(neon.lit_letters()).is_equal(4)
	assert_bool(lit[0]).is_false()
	neon._process(NeonSign.LETTER_STEP * NeonSign.LETTERS.size())
	assert_bool(front.is_lit()).is_true()
	assert_bool(lit[0]).is_true()
	assert_bool(front.layer("wedge").visible).is_true()
	assert_bool(front.layer("reflections").visible).is_true()


func test_doors_crack_then_open_in_steps_and_the_light_floods() -> void:
	var front: Storefront = _front()
	front.doors_hot = true
	assert_int(front.door_gap()).is_equal(Storefront.DOORS_AJAR)
	front.doors_hot = false
	assert_int(front.door_gap()).is_equal(0)
	var tween: Tween = front.open_doors()
	tween.pause()
	var gaps: Array[int] = []
	for step: int in 20:
		tween.custom_step(Storefront.DOOR_TIME / 20.0)
		gaps.append(front.door_gap())
		assert_int(front.door_gap() % Storefront.DOOR_STEP).is_equal(0)
	assert_int(gaps.max()).is_equal(Storefront.DOORS_OPEN)
	var floods: Dictionary[float, bool] = {}
	for step: int in 12:
		tween.custom_step(Storefront.FLOOD_TIME / 10.0)
		floods[snappedf(front.flood(), 0.001)] = true
	assert_float(front.flood()).is_equal(1.0)
	assert_int(floods.size()).is_less_equal(Storefront.FLOOD_STEPS + 1)


func test_the_bay_lights_and_the_machine_jiggles_once() -> void:
	var front: Storefront = _front()
	var rest: Vector2 = front.machine().position
	front.bay_hot = true
	assert_bool(front.layer("bay_lit").visible).is_true()
	assert_bool(front.machine().lit).is_true()
	front._process(0.01)
	assert_float(absf(front.machine().position.x - rest.x)).is_equal(float(ArtStyle.ART_SCALE))
	front._process(Storefront.JIGGLE_TIME)
	assert_vector(front.machine().position).is_equal(rest)
	front.bay_hot = false
	assert_bool(front.layer("bay_lit").visible).is_false()
	assert_bool(front.machine().lit).is_false()


func test_still_holds_every_loop_and_slide() -> void:
	var front: Storefront = _front()
	front.still = true
	front.light_up()
	assert_bool(front.is_lit()).is_true()
	var neon: NeonSign = front.neon_sign()
	var rest: Vector2 = front.machine().position
	front.bay_hot = true
	for tenth: int in 300:
		front._process(0.1)
		neon._process(0.1)
		assert_bool(front.layer("tube_on").visible).is_true()
		assert_bool(neon.is_stuttering()).is_false()
		assert_int(neon.swing()).is_equal(0)
		assert_bool(neon.halo_is_soft()).is_false()
		assert_vector(front.machine().position).is_equal(rest)
	front.slide_bay_glass().custom_step(1.0)
	assert_bool(front.layer("glass").visible).is_false()
	var tween: Tween = front.open_doors()
	tween.pause()
	tween.custom_step(Storefront.FLOOD_TIME / 2.0)
	assert_int(front.door_gap()).is_equal(0)
	assert_float(front.flood()).is_greater(0.0)


func test_the_lit_sign_stutters_and_swings() -> void:
	var neon: NeonSign = auto_free(NeonSign.new())
	neon.still = true
	neon.light_up()
	neon.still = false
	var stuttered: bool = false
	var swings: Dictionary[int, bool] = {}
	var soft: bool = false
	for step: int in 400:
		neon._process(0.05)
		stuttered = stuttered or neon.is_stuttering()
		swings[neon.swing()] = true
		soft = soft or neon.halo_is_soft()
	assert_bool(stuttered).is_true()
	assert_array(swings.keys()).contains_exactly_in_any_order([-1, 0, 1])
	assert_bool(soft).is_true()
	neon.scan()
	neon._process(NeonSign.SCAN_TIME + 0.01)
	assert_bool(neon.is_blinking()).is_true()
	neon._process(NeonSign.BLINK)
	assert_bool(neon.is_blinking()).is_false()
