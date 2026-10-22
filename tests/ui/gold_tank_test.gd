extends GdUnitTestSuite
## The count's gold tank (GoldTank; the monitor juice, mock-up monitor_juice_v2.html, K1 "one
## tank" with FILL A and FONT C): one liquid level across the number and the € at the shown total
## / the quota, held at tank_hold until the landing that meets the quota fills it over the brim
## (tank_overfill) in the same call, following on a spring that settles; the gold shader on the
## digits and the € in the count layout only, one waterline for both (the LED's px, each label
## mapped from its own place in the LED, so neither a punch nor the monitor's shake moves it); the
## fill pass found through an ancestor's grey dim or fade; the dessert slam's still copy mapped to
## its own glyphs; a punch ended when the tank hides; the € fixed for the count's final total
## whatever the amount shown, the digits alone punching (at most digits_punch_max); the shine
## rising up the group; reduced motion's level at once with a flat surface and no shine, twinkles
## or punch; and on the real monitor the group on the paper, right of the bay, for one- to
## four-digit totals. The real saves and logs are never touched.

const STEP := 1.0 / 60.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_gold_tank_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The level follows the shown total / the quota on its spring (settling at the target), holds at
## tank_hold short of the win (even at the quota before its landing) and goes over the brim the
## call the met reading comes in, never past tank_overfill_max.
func test_the_level_holds_until_the_win() -> void:
	var led: LedDisplay = await _led()
	var tank: GoldTank = led.gold_tank
	var tune: CountUpTuning = tank.tuning()
	led.start_count(100, 104)
	assert_float(tank.level()).is_equal(0.0)
	led.show_subtotal(50, false)
	assert_float(tank.target()).is_equal_approx(0.5, 0.0001)
	_step(tank, 1.5)
	assert_float(tank.level()).is_equal_approx(0.5, 0.005)
	led.show_subtotal(99, false)
	assert_float(tank.target()).is_equal(tune.tank_hold)
	led.show_subtotal(100, false)
	assert_float(tank.target()).is_equal(tune.tank_hold)
	var highest: float = 0.0
	for _frame: int in range(roundi(1.5 / STEP)):
		tank.advance(STEP)
		highest = maxf(highest, tank.level())
	assert_float(highest).is_less_equal(tune.tank_hold + tune.tank_hold_slack + 0.0001)
	assert_float(tank.level()).is_equal_approx(tune.tank_hold, 0.005)
	# The landing that meets the quota: over the brim in the same call.
	led.show_subtotal(100, true)
	assert_float(tank.target()).is_equal(tune.tank_overfill)
	highest = 0.0
	for _frame: int in range(roundi(1.5 / STEP)):
		tank.advance(STEP)
		highest = maxf(highest, tank.level())
	assert_float(highest).is_greater(1.0)
	assert_float(highest).is_less_equal(tune.tank_overfill_max + 0.0001)
	assert_float(tank.level()).is_equal_approx(tune.tank_overfill, 0.005)
	# A new count empties it.
	led.start_count(100, 20)
	assert_float(tank.level()).is_equal(0.0)


## The gold shader repaints the digits' and the €'s fill in the count layout only (one material
## each, the same waterline in the LED's px); on the glass the digits have none and the tank hides.
func test_the_gold_fills_the_count_layout_only() -> void:
	var led: LedDisplay = await _led()
	var tank: GoldTank = led.gold_tank
	led.show_projected(20, 34)
	assert_object(led.digits_label().material).is_null()
	assert_bool(tank.visible).is_false()
	led.start_count(34, 20)
	led.show_subtotal(20, false)
	assert_object(led.digits_label().material).is_same(tank.fill_material)
	assert_object(led.euro_label().material).is_same(tank.euro_material)
	assert_bool(tank.visible).is_true()
	assert_object(tank.fill_material.shader).is_same(GoldTank.SHADER)
	assert_object(tank.euro_material.shader).is_same(GoldTank.SHADER)
	for parameter: StringName in [&"level_y", &"ink_top", &"ink_base", &"glare_count"]:
		assert_that(tank.euro_material.get_shader_parameter(parameter)).is_equal(
			tank.fill_material.get_shader_parameter(parameter)
		)
	_assert_mapped(tank.fill_material, led.digits_label())
	_assert_mapped(tank.euro_material, led.euro_label())
	led.clear()
	assert_object(led.digits_label().material).is_null()
	assert_bool(tank.visible).is_false()


## The € stays put through a count (sized for its final total): at 0, 9, 35 and 104 of a final
## 104 its ink is the same, with the digits ending EURO_GAP before it; the group at the final
## total is centred in COUNT_DIGITS_RECT and inside it.
func test_the_euro_stays_put_across_totals() -> void:
	var led: LedDisplay = await _counting_led()
	led.start_count(140, 104)
	var euro: Rect2 = Rect2()
	for amount: int in [0, 9, 35, 104]:
		led.show_subtotal(amount, false)
		await _frames(1)
		var ink: Rect2 = led.euro_text_rect()
		if amount == 0:
			euro = ink
		assert_that(ink).override_failure_message("%d: %s" % [amount, ink]).is_equal(euro)
		var gap: float = led.euro_label().position.x - led.digits_label().get_rect().end.x
		assert_float(gap).is_equal_approx(LedDisplay.EURO_GAP, 0.001)
	var room: Rect2 = Rect2(
		led.get_global_rect().position + LedDisplay.COUNT_DIGITS_RECT.position,
		LedDisplay.COUNT_DIGITS_RECT.size
	)
	var group: Rect2 = led.gold_tank.group_rect()
	assert_bool(room.encloses(group)).override_failure_message(str(group)).is_true()
	var box: Rect2 = led.digits_label().get_global_rect().merge(led.euro_label().get_global_rect())
	assert_float(absf(box.get_center().x - room.get_center().x)).is_less_equal(1.0)


## A punch scales the digits alone (about their bottom right corner, up to digits_punch_max and
## back to 1): the € and the waterline (the shader's level, in the LED's px) stay where they are.
func test_a_punch_moves_the_digits_alone() -> void:
	var led: LedDisplay = await _counting_led()
	var tank: GoldTank = led.gold_tank
	var tune: CountUpTuning = tank.tuning()
	led.start_count(140, 8)
	led.show_subtotal(8, false)
	_step(tank, 1.5)
	await _frames(1)
	var euro: Rect2 = led.euro_text_rect()
	var line: float = tank.fill_material.get_shader_parameter(&"level_y")
	var euro_origin: Vector2 = tank.euro_material.get_shader_parameter(&"label_origin")
	var right: float = led.digits_text_rect().end.x
	tank.punch(3.0)
	var peak: float = 1.0
	for _frame: int in range(
		roundi((tune.digits_punch_up_s + tune.digits_punch_down_s) / 0.005) + 4
	):
		tank.advance(0.005)
		peak = maxf(peak, led.digits_label().scale.x)
		assert_that(led.euro_text_rect()).is_equal(euro)
		assert_vector(led.euro_label().scale).is_equal(Vector2.ONE)
		assert_float(tank.fill_material.get_shader_parameter(&"level_y")).is_equal_approx(
			line, 0.01
		)
		# Each label's gold follows its glyphs: the digits' mapping scales with them.
		_assert_mapped(tank.fill_material, led.digits_label())
		var euro_now: Vector2 = tank.euro_material.get_shader_parameter(&"label_origin")
		assert_vector(euro_now).is_equal(euro_origin)
		assert_float(led.digits_text_rect().end.x).is_less_equal(right + 0.5)
	assert_float(peak).is_greater(1.1)
	assert_float(peak).is_less_equal(tune.digits_punch_max + 0.001)
	assert_vector(led.digits_label().scale).is_equal(Vector2.ONE)


## FONT C's shine rises up the group and is gone after shine_s (the total's two); a landing kicks
## the surface (a ripple); twinkles come with the shine.
func test_the_shine_rises_up_the_group() -> void:
	var led: LedDisplay = await _counting_led()
	var tank: GoldTank = led.gold_tank
	var tune: CountUpTuning = tank.tuning()
	led.start_count(140, 56)
	led.show_subtotal(56, false)
	_step(tank, 1.0)
	tank.shine()
	tank.advance(STEP)
	var last: float = tank.shine_tops()[0]
	assert_int(tank.twinkle_count()).is_equal(tune.twinkles)
	for _frame: int in range(4):
		tank.advance(tune.shine_s / 6.0)
		var top: float = tank.shine_tops()[0]
		assert_float(top).is_less_equal(last)
		last = top
	tank.advance(tune.shine_s)
	assert_int(tank.shine_tops().size()).is_equal(0)
	tank.shine(true)
	tank.advance(tune.shine_second_s + STEP)
	assert_int(tank.shine_tops().size()).is_equal(2)
	var calm_line: float = tank.waterline_at(140.0)
	tank.land()
	tank.advance(0.02)
	assert_float(absf(tank.waterline_at(140.0) - calm_line)).is_greater(0.1)


## Reduced motion: the level is its target at once, the surface flat, and a landing, a shine and
## a punch do nothing.
func test_reduced_motion_is_still() -> void:
	var led: LedDisplay = await _counting_led()
	var tank: GoldTank = led.gold_tank
	tank.reduced_motion = func() -> bool: return true
	led.start_count(100, 104)
	led.show_subtotal(40, false)
	assert_float(tank.level()).is_equal_approx(0.4, 0.0001)
	led.show_subtotal(100, true)
	assert_float(tank.level()).is_equal(tank.tuning().tank_overfill)
	tank.land()
	tank.shine(true)
	tank.punch(2.0)
	tank.advance(0.05)
	assert_float(tank.waterline_at(0.0)).is_equal(tank.waterline_at(150.0))
	assert_int(tank.shine_tops().size()).is_equal(0)
	assert_int(tank.twinkle_count()).is_equal(0)
	assert_int(tank.bubble_count()).is_equal(0)
	assert_vector(led.digits_label().scale).is_equal(Vector2.ONE)
	assert_float(tank.fill_material.get_shader_parameter(&"wave_px")).is_equal(0.0)


## On the real monitor the group (the number and €'s ink) sits on the paper, right of the scanner
## bay, for one- to four-digit totals, its € fixed while the count rolls up to that total.
func test_the_group_stays_inside_the_monitor() -> void:
	var stage: ShiftStage = auto_free(ShiftStage.new(7))
	get_tree().root.add_child(stage)
	await _frames(1)
	var monitor: MonitorView = stage.monitor
	var led: LedDisplay = monitor.led
	var bay: Rect2 = monitor.bay().get_global_rect()
	var paper: Rect2 = MonitorView.PAPER_RECT
	paper.position += stage.get_global_rect().position
	for total: int in [7, 56, 104, 1118, 9999]:
		led.start_count(140, total)
		var euro: Rect2 = Rect2()
		for amount: int in [0, floori(total / 2.0), total]:
			led.show_subtotal(amount, false)
			await _frames(1)
			var group: Rect2 = led.gold_tank.group_rect()
			var message: String = "%d of %d: %s" % [amount, total, group]
			assert_bool(paper.encloses(group)).override_failure_message(message).is_true()
			assert_bool(group.intersects(bay)).override_failure_message(message).is_false()
			if amount == 0:
				euro = led.euro_text_rect()
			assert_that(led.euro_text_rect()).override_failure_message(message).is_equal(euro)


## The monitor's shake (TankBurst moving the whole monitor, later in the frame than the tank)
## never offsets the gold against the glyphs: each label's mapping is its place in the LED, the
## same before, during and after the shake, whatever order the frame runs in.
func test_the_shake_never_moves_the_gold_against_the_glyphs() -> void:
	var stage: ShiftStage = auto_free(ShiftStage.new(7))
	get_tree().root.add_child(stage)
	await _frames(1)
	var monitor: MonitorView = stage.monitor
	var tank: GoldTank = monitor.led.gold_tank
	monitor.led.start_count(100, 56)
	monitor.led.show_subtotal(40, false)
	await _frames(1)
	var digits: Vector2 = tank.fill_material.get_shader_parameter(&"label_origin")
	var euro: Vector2 = tank.euro_material.get_shader_parameter(&"label_origin")
	_assert_mapped(tank.fill_material, monitor.led.digits_label())
	var burst: TankBurst = stage.tank_burst
	burst.shake(4.0, 0.4)
	var moved: bool = false
	for _frame: int in range(12):
		# The tank first, then the shake, as ShiftStage's tree order runs them.
		tank.advance(STEP)
		burst.advance(STEP)
		moved = moved or monitor.position != ShiftStage.MONITOR_RECT.position
		assert_vector(tank.fill_material.get_shader_parameter(&"label_origin")).is_equal(digits)
		assert_vector(tank.euro_material.get_shader_parameter(&"label_origin")).is_equal(euro)
	assert_bool(moved).is_true()
	# Nothing in the shader reads the canvas: it maps each label's own vertices.
	assert_bool(GoldTank.SHADER.code.contains("MODEL_MATRIX")).is_false()
	burst.clear()


## The fill pass is found by its hue (GoldTank.is_fill_colour, the shader's test): the font's gold
## under an ancestor's grey dim, a fade or both still repaints; the ink outline, the mustard shadow,
## the paper and black never do.
func test_the_fill_pass_is_found_through_a_dim_or_fade() -> void:
	var gold: Color = LedDisplay.COUNT_DIGITS_COLOR
	for modulate: Color in [
		Color.WHITE, Color(0.6, 0.6, 0.6), Color(1, 1, 1, 0.3), Color(0.4, 0.4, 0.4, 0.5)
	]:
		var message: String = "gold under %s" % modulate
		var drawn: Color = gold * modulate
		assert_bool(GoldTank.is_fill_colour(drawn)).override_failure_message(message).is_true()
	for other: Color in [
		LedDisplay.COUNT_OUTLINE_COLOR,
		LedDisplay.COUNT_SHADOW_COLOR,
		LedDisplay.COUNT_SHADOW_COLOR * Color(0.6, 0.6, 0.6),
		Palette.PAPER,
		Palette.MUSTARD_PALE,
		Color.BLACK,
	]:
		var message: String = "%s" % other
		assert_bool(GoldTank.is_fill_colour(other)).override_failure_message(message).is_false()
	# A dimmed ancestor of the LED: the digits' fill colour as drawn is still the gold's hue.
	var led: LedDisplay = await _counting_led()
	led.start_count(100, 56)
	led.show_subtotal(30, false)
	var holder: Control = led.get_parent() as Control
	holder.modulate = Color(0.6, 0.6, 0.6, 0.5)
	var drawn_fill: Color = led.digits_label().get_theme_color("font_color") * holder.modulate
	assert_bool(GoldTank.is_fill_colour(drawn_fill)).is_true()
	var drawn_ink: Color = led.digits_label().get_theme_color("font_outline_color")
	assert_bool(GoldTank.is_fill_colour(drawn_ink * holder.modulate)).is_false()


## The dessert slam's gold is a still copy of the tank mapped to the slam's own glyphs (the
## digits' box at rest): its level at the tank's target (over the brim when met), flat, with no
## glares, ripple, bubbles or shine; the tank's own materials go on moving.
func test_the_slam_gets_a_still_copy_of_the_gold() -> void:
	var led: LedDisplay = await _counting_led()
	var tank: GoldTank = led.gold_tank
	led.start_count(50, 56)
	led.show_subtotal(56, true)
	tank.land()
	tank.shine(true)
	_step(tank, 0.1)
	var slam: Label = auto_free(Label.new())
	var copy: ShaderMaterial = tank.slam_material(slam)
	assert_object(copy).is_not_same(tank.fill_material)
	assert_object(copy.shader).is_same(GoldTank.SHADER)
	assert_vector(copy.get_shader_parameter(&"label_scale")).is_equal(Vector2.ONE)
	var origin: Vector2 = copy.get_shader_parameter(&"label_origin")
	assert_float(origin.x).is_equal(led.digits_label().position.x)
	for parameter: StringName in [&"glare_count", &"bubble_count", &"shine_count"]:
		assert_int(int(copy.get_shader_parameter(parameter))).is_equal(0)
	assert_float(copy.get_shader_parameter(&"wave_px")).is_equal(0.0)
	assert_float(copy.get_shader_parameter(&"ripple_age")).is_less(0.0)
	# Over the brim: its waterline above the group's ink top.
	var top: float = tank.group_rect().position.y - tank.get_global_transform().origin.y
	assert_float(copy.get_shader_parameter(&"level_y")).is_less(top)
	assert_int(int(tank.fill_material.get_shader_parameter(&"glare_count"))).is_greater(0)
	# A slam of the digits' own alignment and box maps as they do.
	slam.vertical_alignment = led.digits_label().vertical_alignment
	slam.add_theme_font_override("font", led.digits_label().get_theme_font("font"))
	slam.add_theme_font_size_override(
		"font_size", led.digits_label().get_theme_font_size("font_size")
	)
	slam.size = led.digits_label().size
	var same: Vector2 = tank.slam_material(slam).get_shader_parameter(&"label_origin")
	assert_vector(same).is_equal(led.digits_label().position)


## A punch still running when the tank hides (the compact layout, e.g. planning right after a
## skipped dessert) ends at once: the digits are back at 1.
func test_hiding_the_tank_ends_its_punch() -> void:
	var led: LedDisplay = await _counting_led()
	var tank: GoldTank = led.gold_tank
	led.start_count(100, 30)
	led.show_subtotal(30, false)
	tank.punch(1.5)
	tank.advance(0.05)
	assert_float(led.digits_label().scale.x).is_greater(1.0)
	led.show_projected(30, 100)
	assert_bool(tank.visible).is_false()
	assert_vector(led.digits_label().scale).is_equal(Vector2.ONE)
	assert_float(tank.punch_scale()).is_equal(1.0)


## `material` maps `label`'s own points to the LED's px through the label's transform there.
func _assert_mapped(material: ShaderMaterial, label: Label) -> void:
	var transform: Transform2D = label.get_transform()
	var origin: Vector2 = material.get_shader_parameter(&"label_origin")
	var label_scale: Vector2 = material.get_shader_parameter(&"label_scale")
	assert_vector(origin).is_equal_approx(transform.origin, Vector2.ONE * 0.001)
	assert_vector(label_scale).is_equal_approx(transform.get_scale(), Vector2.ONE * 0.001)


## Steps `tank` by `seconds` of real time.
static func _step(tank: GoldTank, seconds: float) -> void:
	for _frame: int in range(roundi(seconds / STEP)):
		tank.advance(STEP)


## A LED in the window.
func _led() -> LedDisplay:
	var led: LedDisplay = LedDisplay.new()
	var holder: Control = auto_free(Control.new())
	holder.position = ShiftStage.LED_RECT.position
	get_tree().root.add_child(holder)
	holder.add_child(led)
	await _frames(1)
	return led


## A LED at the monitor's LED_COUNT_RECT (the count layout's place).
func _counting_led() -> LedDisplay:
	var led: LedDisplay = await _led()
	led.position = MonitorView.LED_COUNT_RECT.position - ShiftStage.LED_RECT.position
	return led


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
