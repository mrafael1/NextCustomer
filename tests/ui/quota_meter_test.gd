extends GdUnitTestSuite
## The quota gauge (#86, gauge TA; the tube beside the receipt since the shift scene polish,
## mock-up shift_scene_polish_v2.html section 2, A2; QuotaMeter and QuotaFlag): a tube that prints
## no number and fills up toward the target line on its top; full exactly at the quota while short;
## the flag planted on the tube's top once the amount meets it (the count's ding, or a projected
## total reaching it), and the quota line sinking as the tube re-scales to the amount; the liquid's
## colour by status; the tube's glow from NEAR_SHARE of the quota while short; a drag's preview
## kept apart from the shown amount; reduced motion plants the flag standing still; from twice the
## quota the count laps the tube (the quota crossing's E). Drawn checks: the flag stands on the
## tube's top, its cloth (a lap's too) right of the pole.


## No number in the tube (the user's call of 2026-11-02): the receipt says the amounts.
func test_the_tube_prints_no_number() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(52, 80)
	await _frames(1)
	assert_array(meter.find_children("*", "Label", true, false)).is_empty()
	assert_int(meter.amount()).is_equal(52)
	assert_that(QuotaMeter.TARGET_COLOR).is_equal(Palette.TOMATO)
	assert_object(meter.bar()).is_same(meter)


func test_the_flag_anchors_the_quota() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(73)
	assert_bool(meter.flag_shown()).is_false()
	led.show_subtotal(60, false)
	assert_bool(meter.flag_shown()).is_false()
	_assert_quota_line_at(meter, 1.0)
	# Past the quota before the ding: full, no flag yet.
	led.show_subtotal(80, false)
	assert_bool(meter.flag_shown()).is_false()
	assert_float(meter.fill()).is_equal(1.0)
	led.show_subtotal(80, true)
	assert_bool(meter.flag_shown()).is_true()
	await _frames(2)
	_assert_flag_on_top(meter)
	_assert_quota_line_at(meter, QuotaMeter.flag_fraction(80, 73))
	# The quota line sinks as the amount climbs (short of twice the quota, where the laps start).
	led.show_subtotal(130, true)
	await _frames(2)
	_assert_quota_line_at(meter, QuotaMeter.flag_fraction(130, 73))
	_assert_flag_on_top(meter)
	led.show_total()
	assert_bool(meter.flag_shown()).is_true()
	# The next count frees it.
	led.start_count(90)
	assert_bool(meter.flag_shown()).is_false()


## In planning the flag stands once the projected total reaches the quota, and goes when it falls
## short again.
func test_the_projected_total_plants_the_flag() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(50, 73)
	assert_bool(meter.flag_shown()).is_false()
	meter.show_projected(73, 73)
	assert_bool(meter.flag_shown()).is_true()
	meter.show_projected(70, 73)
	assert_bool(meter.flag_shown()).is_false()


func test_flag_fraction() -> void:
	assert_float(QuotaMeter.flag_fraction(40, 73)).is_equal(1.0)
	assert_float(QuotaMeter.flag_fraction(73, 73)).is_equal(1.0)
	assert_float(QuotaMeter.flag_fraction(146, 73)).is_equal(0.5)
	assert_float(QuotaMeter.flag_fraction(10, 0)).is_equal(1.0)


## The tube glows from NEAR_SHARE of the quota while short, never once it is met.
func test_the_tube_glows_near_the_quota() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(22, 73)
	assert_bool(meter.is_near()).is_false()
	meter.show_projected(60, 73)
	assert_bool(meter.is_near()).is_true()
	meter.show_projected(73, 73)
	assert_bool(meter.is_near()).is_false()
	meter.show_projected(117, 73)
	assert_bool(meter.is_near()).is_false()


## A drag's landing (#71) previews its would-be total apart from the projected one, which the tube
## keeps as its amount; the projection puts it back.
func test_a_drag_previews_its_total() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(10, 73)
	assert_int(meter.hypothetical()).is_equal(-1)
	meter.show_hypothetical(16, 6, 73)
	assert_int(meter.hypothetical()).is_equal(16)
	assert_int(meter.amount()).is_equal(10)
	meter.show_hypothetical(4, -6, 73)
	assert_int(meter.hypothetical()).is_equal(4)
	meter.show_projected(46, 73)
	assert_int(meter.hypothetical()).is_equal(-1)
	assert_int(meter.amount()).is_equal(46)


## The tube keeps its size through a count.
func test_the_tube_keeps_its_size() -> void:
	var meter: QuotaMeter = await _meter()
	var sizes: Array[Vector2] = []
	for amount: int in [0, 9, 72, 73, 900, 1500]:
		meter.show_projected(amount, 999)
		await _frames(1)
		sizes.append(meter.size)
	for tube_size: Vector2 in sizes:
		assert_that(tube_size).is_equal(ShiftStage.TUBE_RECT.size)


## The liquid's colour follows the status (the user's idea, 2026-10-19): red while short, orange
## from NEAR_SHARE of the quota (and past it before the ding), green once met; gold over the line.
func test_the_liquid_colour_follows_the_status() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(100)
	led.show_subtotal(40, false)
	await _frames(2)
	assert_array(meter.ramp()).is_equal(QuotaMeter.SHORT_RAMP)
	led.show_subtotal(80, false)
	await _frames(2)
	assert_array(meter.ramp()).is_equal(QuotaMeter.NEAR_RAMP)
	led.show_subtotal(104, false)
	await _frames(2)
	assert_array(meter.ramp()).is_equal(QuotaMeter.NEAR_RAMP)
	led.show_subtotal(104, true)
	await _frames(2)
	assert_array(meter.ramp()).is_equal(QuotaMeter.MET_RAMP)
	assert_that(QuotaMeter.SHORT_RAMP[1]).is_equal(Palette.TOMATO)
	assert_that(QuotaMeter.MET_RAMP[1]).is_equal(Palette.GOOD)
	assert_that(QuotaMeter.PAST_RAMP[1]).is_equal(Palette.MUSTARD_LIGHT)


## Reduced motion plants the flag at once, standing still.
func test_reduced_motion_plants_the_flag_still() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(80, 73)
	assert_bool(meter.flag().is_planting()).is_false()
	var moving: QuotaMeter = await _meter(false)
	moving.show_projected(80, 73)
	assert_bool(moving.flag().is_planting()).is_true()


## The quota crossing's E: twice the quota laps the tube once, while counting only: the flag names
## the next multiple, the quota mark stays on the tube's top, and each new multiple emits
## lap_reached once; the next count ends the laps.
func test_twice_the_quota_laps_the_gauge() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	var laps: Array[int] = []
	meter.lap_reached.connect(func(lap: int) -> void: laps.append(lap))
	led.start_count(40)
	led.show_subtotal(79, true)
	assert_int(meter.shown_lap()).is_equal(0)
	assert_str(meter.flag().lap_text).is_empty()
	led.show_subtotal(80, true)
	assert_int(meter.shown_lap()).is_equal(2)
	assert_array(laps).is_equal([2])
	assert_str(meter.flag().lap_text).is_equal("×3")
	await _frames(2)
	_assert_flag_on_top(meter)
	_assert_quota_line_at(meter, 1.0)
	led.show_subtotal(95, true)
	assert_array(laps).is_equal([2])
	led.show_subtotal(121, true)
	assert_array(laps).is_equal([2, 3])
	assert_str(meter.flag().lap_text).is_equal("×4")
	led.start_count(40)
	assert_int(meter.shown_lap()).is_equal(0)
	assert_str(meter.flag().lap_text).is_empty()


## In planning a projected total at twice the quota keeps re-scaling: no laps.
func test_the_projected_total_never_laps() -> void:
	var meter: QuotaMeter = await _meter()
	var laps: Array[int] = []
	meter.lap_reached.connect(func(lap: int) -> void: laps.append(lap))
	meter.show_projected(100, 40)
	assert_int(meter.shown_lap()).is_equal(0)
	assert_array(laps).is_empty()


func test_lap_of() -> void:
	assert_int(QuotaMeter.lap_of(79, 40)).is_equal(1)
	assert_int(QuotaMeter.lap_of(80, 40)).is_equal(2)
	assert_int(QuotaMeter.lap_of(-5, 40)).is_equal(0)
	assert_int(QuotaMeter.lap_of(80, 0)).is_equal(0)


## A tube the stage's size, with reduced motion unless `reduced` is false.
func _meter(reduced: bool = true) -> QuotaMeter:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	if reduced:
		meter.reduced_motion = func() -> bool: return true
	meter.position = ShiftStage.TUBE_RECT.position
	meter.size = ShiftStage.TUBE_RECT.size
	add_child(meter)
	await _frames(2)
	return meter


## The flag stands on the tube's top at its middle: its pole and cloth above the tube, its cloth
## (a lap's too) right of the pole, never left of the tube.
func _assert_flag_on_top(meter: QuotaMeter) -> void:
	var bar: Rect2 = meter.bar().get_global_rect()
	var flag: QuotaFlag = meter.flag()
	assert_float(flag.global_position.x).is_equal_approx(bar.get_center().x, ArtStyle.ART_SCALE)
	assert_float(flag.global_position.y).is_equal_approx(bar.position.y, 0.5)
	var rest: Rect2 = flag.rest_rect()
	rest.position += flag.global_position
	assert_float(rest.position.y).is_less(bar.position.y - QuotaFlag.CLOTH_SIZE.y)
	assert_float(rest.position.x).is_greater_equal(bar.position.x)


## The quota mark stands `fraction` up the tube's inside from its foot (to the art pixel): on the
## target line over the tube's top while it is 1.
func _assert_quota_line_at(meter: QuotaMeter, fraction: float) -> void:
	var bar: Rect2 = meter.bar().get_global_rect()
	var cell: float = ArtStyle.ART_SCALE
	var inner: float = floorf(bar.size.y / cell) - 2.0
	var expected: float = bar.end.y - cell - inner * fraction * cell
	if fraction >= 1.0:
		expected = bar.position.y - cell / 2.0
	assert_float(meter.quota_mark().y).is_equal_approx(expected, cell * 1.5)
	assert_float(meter.quota_mark().x).is_equal_approx(bar.get_center().x, 0.5)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
