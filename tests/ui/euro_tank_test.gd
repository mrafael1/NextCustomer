extends GdUnitTestSuite
## The big € tank (#86 v6 scan count-up; EuroTank) on its own and on the monitor's count view: its
## level is the shown amount over the quota, full at the quota and never a share of a larger total;
## past the quota it overflows (only once the count says the quota is met); a new count empties it
## at once; the sprite (60x75 art px at 2x) has its inside read from the cream shade pixels; the
## empty inside takes the top gauge's status colours (tomato short, brass from NEAR_SHARE of the
## quota, light shade on the lit columns); it exposes its top and surface points; the burst blinks
## only without reduced motion, which snaps the level and the colours, as settle() does; a gain
## reaches the level LAG_S late (#86 round 7). On the monitor it stands at TANK_RECT, shown in
## the count only, and follows the LED's reading.


func test_the_level_is_the_amount_over_the_quota() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	tank.reduced_motion = func() -> bool: return true
	add_child(tank)
	assert_vector(Vector2(EuroTank.TANK.get_size())).is_equal(Vector2(60, 75))
	assert_vector(tank.size).is_equal(Vector2(EuroTank.TANK.get_size()) * ArtStyle.ART_SCALE)
	assert_vector(tank.size).is_equal(MonitorView.TANK_RECT.size)
	tank.set_reading(0, 73, false)
	assert_float(tank.level()).is_equal(0.0)
	tank.set_reading(36, 73, false)
	assert_float(tank.level()).is_equal_approx(36.0 / 73.0, 0.0001)
	# Past the quota before the count's ding: full, not yet overflowing.
	tank.set_reading(80, 73, false)
	assert_float(tank.level()).is_equal(1.0)
	assert_bool(tank.is_overflowing()).is_false()
	tank.set_reading(117, 73, true)
	assert_float(tank.level()).is_equal(1.0)
	assert_bool(tank.is_overflowing()).is_true()
	# A new count empties it at once.
	tank.set_reading(0, 90, false)
	assert_float(tank.level()).is_equal(0.0)
	assert_bool(tank.is_overflowing()).is_false()
	assert_float(EuroTank.level_for(5, 0)).is_equal(1.0)


## Without reduced motion the level pours up to the amount over a few frames, never past it.
func test_the_level_pours_up_to_the_amount() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	add_child(tank)
	tank.set_reading(0, 100, false)
	tank.set_reading(50, 100, false)
	assert_float(tank.level()).is_less(0.5)
	await get_tree().create_timer(1.5).timeout
	assert_float(tank.level()).is_equal_approx(0.5, 0.0001)


## A gain reaches the level LAG_S after the reading (#86 round 7: as the pour arrives), while the
## status colours head for the new reading's at once and the met state is full at once; a lower
## amount (a new count) drops what is on its way; settle() takes it all in; under reduced motion
## nothing waits. The clock is stepped by hand (_process).
func test_the_level_lags_the_reading() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	var reduced: Array[bool] = [false]
	tank.reduced_motion = func() -> bool: return reduced[0]
	add_child(tank)
	tank.set_process(false)
	tank.set_reading(0, 100, false)
	tank.set_reading(85, 100, false)
	assert_int(tank.pending()).is_equal(1)
	_run(tank, EuroTank.LAG_S - 0.05)
	assert_float(tank.level()).is_equal(0.0)
	# The status colours head for brass at once (eased), never waiting for the level.
	assert_bool(tank.inside_colours()[1] == Palette.TOMATO).is_false()
	_run(tank, 0.1)
	assert_int(tank.pending()).is_equal(0)
	_run(tank, 1.0)
	assert_float(tank.level()).is_equal_approx(0.85, 0.0001)
	# Met: full at once, before its gain arrives.
	tank.set_reading(110, 100, true)
	assert_float(tank.level()).is_equal(1.0)
	assert_bool(tank.is_overflowing()).is_true()
	# A new count drops the gain on its way.
	tank.set_reading(20, 100, false)
	tank.set_reading(0, 100, false)
	assert_int(tank.pending()).is_equal(0)
	assert_float(tank.level()).is_equal(0.0)
	# settle() takes the gains in.
	tank.set_reading(40, 100, false)
	tank.settle()
	assert_int(tank.pending()).is_equal(0)
	assert_float(tank.level()).is_equal_approx(0.4, 0.0001)
	# Reduced motion: at once.
	reduced[0] = true
	tank.set_reading(70, 100, false)
	assert_int(tank.pending()).is_equal(0)
	assert_float(tank.level()).is_equal_approx(0.7, 0.0001)


## The sprite's inside is its cream shade pixels, ringed by ink: every inside pixel is surrounded
## by the inside or the outline, so the gold never leaks out of the sign; the last two columns and
## rows stay clear for the shadow.
func test_the_inside_is_the_sprites_cream_shade() -> void:
	var image: Image = EuroTank.TANK.get_image()
	var inside: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			var clear: bool = (
				x >= image.get_width() - EuroTank.SHADOW_OFFSET.x
				or y >= image.get_height() - EuroTank.SHADOW_OFFSET.y
			)
			if clear:
				assert_float(pixel.a).override_failure_message("(%d, %d)" % [x, y]).is_equal(0.0)
			if not pixel.is_equal_approx(EuroTank.INSIDE_COLOR):
				continue
			inside += 1
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = Vector2i(x, y) + step
				var message: String = "(%d, %d) leaks" % [x, y]
				assert_bool(next.x >= 0 and next.y >= 0).override_failure_message(message).is_true()
				var neighbour: Color = image.get_pixelv(next)
				assert_float(neighbour.a).override_failure_message(message).is_equal(1.0)
	assert_int(inside).is_greater(1500)


## The empty inside takes the top gauge's ramps (QuotaMeter): tomato short (its light shade on
## the lit columns), brass from NEAR_SHARE of the quota, green once met; snapped under reduced
## motion, eased without it.
func test_the_inside_takes_the_status_colours() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	var reduced: Array[bool] = [true]
	tank.reduced_motion = func() -> bool: return reduced[0]
	add_child(tank)
	tank.set_reading(10, 100, false)
	assert_array(tank.inside_colours()).is_equal([Palette.TOMATO_LIGHT, Palette.TOMATO])
	tank.set_reading(79, 100, false)
	assert_array(tank.inside_colours()).is_equal([Palette.TOMATO_LIGHT, Palette.TOMATO])
	tank.set_reading(80, 100, false)
	assert_array(tank.inside_colours()).is_equal([Palette.MUSTARD, Palette.BRASS])
	tank.set_reading(100, 100, true)
	assert_array(tank.inside_colours()).is_equal([Palette.GREEN_LIGHT, Palette.GOOD])
	# Eased without reduced motion: a new count's tomato comes back over a few frames.
	reduced[0] = false
	tank.set_reading(0, 100, false)
	await get_tree().process_frame
	assert_bool(tank.inside_colours()[1] == Palette.TOMATO).is_false()
	await get_tree().create_timer(1.5).timeout
	assert_bool(tank.inside_colours()[1].is_equal_approx(Palette.TOMATO)).is_true()


## The top point is the sign's top centre (sign_rect: the sign as drawn); the surface point climbs
## from the inside's bottom to its top as the level fills (global, for the burst and the pour).
func test_the_top_and_surface_points() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	tank.reduced_motion = func() -> bool: return true
	add_child(tank)
	tank.position = MonitorView.TANK_RECT.position
	var rect: Rect2 = tank.get_global_rect()
	var top: Vector2 = tank.top_point()
	assert_float(top.x).is_equal(rect.get_center().x)
	assert_float(top.y).is_greater_equal(rect.position.y)
	assert_float(top.y).is_less(rect.position.y + 8.0)
	# The sign as drawn: inside the rect, clear of its shadow's margin, its top at the top point.
	var drawn: Rect2 = tank.sign_rect()
	assert_bool(rect.encloses(drawn)).override_failure_message(str(drawn)).is_true()
	assert_float(drawn.end.x).is_less_equal(rect.end.x - EuroTank.SHADOW_OFFSET.x * 2.0)
	assert_float(drawn.end.y).is_less_equal(rect.end.y - EuroTank.SHADOW_OFFSET.y * 2.0)
	assert_float(drawn.position.y).is_equal(top.y)
	assert_float(drawn.size.x).is_greater(rect.size.x * 0.8)
	tank.set_reading(0, 100, false)
	var empty: Vector2 = tank.surface_point()
	tank.set_reading(50, 100, false)
	var half: Vector2 = tank.surface_point()
	tank.set_reading(100, 100, false)
	var full: Vector2 = tank.surface_point()
	assert_float(empty.y).is_greater(half.y)
	assert_float(half.y).is_greater(full.y)
	assert_float(full.y).is_greater_equal(top.y)
	assert_float(empty.y).is_less_equal(rect.end.y)


## The burst blinks the outline for BURST_SECONDS; nothing under reduced motion.
func test_the_burst_blinks_without_reduced_motion() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	var reduced: Array[bool] = [true]
	tank.reduced_motion = func() -> bool: return reduced[0]
	add_child(tank)
	tank.burst()
	assert_bool(tank.is_bursting()).is_false()
	reduced[0] = false
	tank.burst()
	assert_bool(tank.is_bursting()).is_true()
	await get_tree().create_timer(EuroTank.BURST_SECONDS + 0.2).timeout
	assert_bool(tank.is_bursting()).is_false()
	assert_vector(tank.scale).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))


## settle() (a resumed checkout's end state) puts it at rest at once: the level on the amount, the
## inside on its status colours, no blink and no kick.
func test_settle_rests_the_tank_at_once() -> void:
	var tank: EuroTank = auto_free(EuroTank.new())
	add_child(tank)
	tank.set_reading(0, 100, false)
	tank.set_reading(90, 100, false)
	tank.burst()
	await get_tree().process_frame
	assert_float(tank.level()).is_less(0.9)
	tank.settle()
	assert_float(tank.level()).is_equal_approx(0.9, 0.0001)
	assert_bool(tank.is_bursting()).is_false()
	assert_vector(tank.scale).is_equal(Vector2.ONE)
	assert_array(tank.inside_colours()).is_equal([QuotaMeter.NEAR_RAMP[0], QuotaMeter.NEAR_RAMP[1]])


## On the monitor the tank stands at TANK_RECT, on the paper, shown while the LED counts, and
## follows the LED's reading (reading_changed).
func test_the_monitor_shows_the_tank_while_counting() -> void:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	monitor.reduced_motion = func() -> bool: return true
	await get_tree().process_frame
	var tank: EuroTank = monitor.tank()
	assert_bool(tank.is_visible_in_tree()).is_false()
	monitor.led.start_count(73)
	assert_bool(tank.is_visible_in_tree()).is_true()
	assert_that(tank.get_global_rect()).is_equal(MonitorView.TANK_RECT)
	assert_bool(MonitorView.PAPER_RECT.encloses(tank.get_global_rect())).is_true()
	monitor.led.show_subtotal(40, false)
	assert_float(tank.level()).is_equal_approx(40.0 / 73.0, 0.0001)
	monitor.led.show_subtotal(90, true)
	assert_bool(tank.is_overflowing()).is_true()
	monitor.led.show_total()
	assert_bool(tank.is_visible_in_tree()).is_true()
	monitor.led.clear()
	assert_bool(tank.is_visible_in_tree()).is_false()
	# The next count starts empty.
	monitor.led.start_count(80)
	assert_float(tank.level()).is_equal(0.0)
	assert_bool(tank.is_overflowing()).is_false()


## Runs the tank's clock by `seconds`, a 60th of a second at a time.
static func _run(tank: EuroTank, seconds: float) -> void:
	var left: float = seconds
	while left > 0.00001:
		var step: float = minf(1.0 / 60.0, left)
		tank._process(step)
		left -= step
