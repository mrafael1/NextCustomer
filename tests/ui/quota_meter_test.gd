extends GdUnitTestSuite
## The quota gauge (#86, gauge TA; the tube beside the receipt since the shift scene polish,
## mock-up shift_scene_polish_v2.html section 2, A2; the laps since the user's feedback of
## 2026-11-03; QuotaMeter): a tube that prints no number and fills up toward the target line on
## its top; full exactly at the quota in its first lap; once the quota is met (the count's ding,
## or a projected total reaching it) it never re-scales: it refills from its foot lap by lap, each
## lap in its own colour over a full tube of the lap before's, with a "×N" badge on its top and
## no flag; the first lap's colour by status; the tube's glow from NEAR_SHARE of the quota while
## short; a drag's preview kept apart from the shown amount; reduced motion keeps the levels and
## the colours; from twice the quota the count emits lap_reached once per multiple (the quota
## crossing's E).

const PALETTE_FILE := "res://art/src/palette.txt"


## No number in the tube (the user's call of 2026-11-02): the receipt says the amounts.
func test_the_tube_prints_no_number() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(52, 80)
	await _frames(1)
	assert_array(meter.find_children("*", "Label", true, false)).is_empty()
	assert_int(meter.amount()).is_equal(52)
	assert_that(QuotaMeter.TARGET_COLOR).is_equal(Palette.TOMATO)
	assert_object(meter.bar()).is_same(meter)


## The tube never shows a flag: it has no child at all, whatever its amount, and the quota mark
## stays on the target line on its top.
func test_the_tube_never_shows_a_flag() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(73)
	for reading: Array in [[40, false], [80, false], [80, true], [150, true], [400, true]]:
		led.show_subtotal(reading[0], reading[1])
		await _frames(2)
		assert_int(meter.get_child_count()).is_equal(0)
		_assert_quota_mark_on_top(meter)
	meter.show_projected(500, 73)
	await _frames(1)
	assert_int(meter.get_child_count()).is_equal(0)


## The lap by amount, quota and met: 1 while short or before the ding, lap 2 from the quota, lap
## 3 from twice it, and so on.
func test_lap_for() -> void:
	assert_int(QuotaMeter.lap_for(0, 40, false)).is_equal(1)
	assert_int(QuotaMeter.lap_for(39, 40, false)).is_equal(1)
	assert_int(QuotaMeter.lap_for(90, 40, false)).is_equal(1)
	assert_int(QuotaMeter.lap_for(40, 40, true)).is_equal(2)
	assert_int(QuotaMeter.lap_for(79, 40, true)).is_equal(2)
	assert_int(QuotaMeter.lap_for(80, 40, true)).is_equal(3)
	assert_int(QuotaMeter.lap_for(120, 40, true)).is_equal(4)
	assert_int(QuotaMeter.lap_for(165, 40, true)).is_equal(5)
	assert_int(QuotaMeter.lap_for(10, 0, true)).is_equal(1)


## Each lap's fill runs from (lap - 1) to lap times the quota.
func test_lap_fill() -> void:
	assert_float(QuotaMeter.lap_fill(20.0, 40, 1)).is_equal(0.5)
	assert_float(QuotaMeter.lap_fill(60.0, 40, 1)).is_equal(1.0)
	assert_float(QuotaMeter.lap_fill(40.0, 40, 2)).is_equal(0.0)
	assert_float(QuotaMeter.lap_fill(60.0, 40, 2)).is_equal(0.5)
	assert_float(QuotaMeter.lap_fill(100.0, 40, 3)).is_equal(0.5)
	assert_float(QuotaMeter.lap_fill(30.0, 40, 3)).is_equal(0.0)
	assert_float(QuotaMeter.lap_fill(30.0, 0, 3)).is_equal(1.0)


## The lap colours: gold, orange, velvet, teal glass, then gold again; each over a full tube of
## the lap before's (the met green behind lap 2); all of them the art palette's.
func test_the_lap_colours_by_total_and_quota() -> void:
	var expected: Array = [
		[40, 2, Palette.GOLD, Palette.GOOD],
		[60, 2, Palette.GOLD, Palette.GOOD],
		[80, 3, Palette.TOMATO_LIGHT, Palette.GOLD],
		[100, 3, Palette.TOMATO_LIGHT, Palette.GOLD],
		[130, 4, Palette.VELVET, Palette.TOMATO_LIGHT],
		[170, 5, Palette.TEAL_BRIGHT, Palette.VELVET],
		[210, 6, Palette.GOLD, Palette.TEAL_BRIGHT],
	]
	for row: Array in expected:
		var lap: int = QuotaMeter.lap_for(row[0], 40, true)
		assert_int(lap).override_failure_message(str(row)).is_equal(row[1])
		assert_that(QuotaMeter.lap_ramp(lap)[1]).is_equal(row[2])
		assert_that(QuotaMeter.backdrop_ramp(lap)[1]).is_equal(row[3])
	var palette: Array[Color] = _palette()
	var ramps: Array = QuotaMeter.LAP_RAMPS.duplicate()
	ramps.append_array([QuotaMeter.SHORT_RAMP, QuotaMeter.NEAR_RAMP, QuotaMeter.MET_RAMP])
	for colour_ramp: Array in ramps:
		for colour: Color in colour_ramp:
			assert_bool(palette.has(colour)).override_failure_message(str(colour)).is_true()


## During a count: lap 2 pours gold over the full green tube from the foot up, lap 3 orange over
## gold; the badge names the lap.
func test_the_tube_refills_lap_by_lap() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(40)
	led.show_subtotal(30, false)
	await _frames(2)
	assert_int(meter.shown_lap()).is_equal(1)
	assert_float(meter.fill()).is_equal(0.75)
	assert_str(meter.badge_text()).is_empty()
	led.show_subtotal(50, true)
	await _frames(2)
	assert_int(meter.shown_lap()).is_equal(2)
	assert_float(meter.fill()).is_equal(0.25)
	assert_array(meter.liquid_ramp()).is_equal(QuotaMeter.lap_ramp(2))
	assert_that(QuotaMeter.backdrop_ramp(meter.shown_lap())).is_equal(QuotaMeter.MET_RAMP)
	assert_str(meter.badge_text()).is_equal("×2")
	led.show_subtotal(100, true)
	await _frames(2)
	assert_int(meter.shown_lap()).is_equal(3)
	assert_float(meter.fill()).is_equal(0.5)
	assert_str(meter.badge_text()).is_equal("×3")
	assert_array(meter.liquid_ramp()).is_equal(QuotaMeter.lap_ramp(3))


## The badge sits on the tube's top: its foot on the target line, centred over the tube, as wide
## as the tube's cap or wider, and right of no more than the receipt's left edge (RECEIPT_X).
func test_the_badge_sits_on_the_tube_top() -> void:
	var meter: QuotaMeter = await _meter()
	var cell: float = ArtStyle.ART_SCALE
	for lap: int in [2, 3, 9, 12]:
		var rect: Rect2 = meter.badge_rect(QuotaMeter.BADGE_TEXT % lap)
		assert_float(rect.end.y).is_equal(-cell)
		assert_float(rect.get_center().x).is_equal_approx(meter.size.x / 2.0, cell)
		var on_stage: Rect2 = Rect2(rect.position + ShiftStage.TUBE_RECT.position, rect.size)
		var why: String = "×%d at %s" % [lap, on_stage]
		(
			assert_bool(ShiftStage.TOWER_RECT.encloses(on_stage))
			. override_failure_message(why)
			. is_true()
		)
		assert_float(on_stage.end.x).override_failure_message(why).is_less_equal(
			ShiftStage.RECEIPT_X
		)


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


## The first lap's colour follows the status (the user's idea, 2026-10-19): red while short,
## orange from NEAR_SHARE of the quota (and past it before the ding), green once met.
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
	assert_int(meter.shown_lap()).is_equal(1)
	led.show_subtotal(104, true)
	await _frames(2)
	assert_array(meter.ramp()).is_equal(QuotaMeter.MET_RAMP)
	assert_that(QuotaMeter.SHORT_RAMP[1]).is_equal(Palette.TOMATO)
	assert_that(QuotaMeter.MET_RAMP[1]).is_equal(Palette.GOOD)


## Reduced motion keeps the level, the lap, its colours and the badge (no pop): at once.
func test_reduced_motion_keeps_the_levels_and_colours() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(100, 40)
	await _frames(1)
	assert_int(meter.shown_lap()).is_equal(3)
	assert_float(meter.fill()).is_equal(0.5)
	assert_str(meter.badge_text()).is_equal("×3")
	assert_array(meter.liquid_ramp()).is_equal(QuotaMeter.lap_ramp(3))
	assert_float(meter._pop).is_equal(0.0)
	# With motion, a new lap pops the badge.
	var moving: QuotaMeter = await _meter(false)
	moving.show_projected(100, 40)
	await _frames(30)
	moving.show_projected(130, 40)
	await _frames(30)
	assert_str(moving.badge_text()).is_equal("×4")


## The quota crossing's E: while counting, twice the quota and each later multiple emit
## lap_reached once; planning never does; the next count starts at lap 1 again.
func test_each_multiple_emits_lap_reached_while_counting() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	var laps: Array[int] = []
	meter.lap_reached.connect(func(multiple: int) -> void: laps.append(multiple))
	meter.show_projected(100, 40)
	assert_array(laps).is_empty()
	led.start_count(40)
	led.show_subtotal(45, true)
	led.show_subtotal(79, true)
	assert_array(laps).is_empty()
	led.show_subtotal(80, true)
	assert_array(laps).is_equal([2])
	_assert_quota_mark_on_top(meter)
	led.show_subtotal(95, true)
	assert_array(laps).is_equal([2])
	led.show_subtotal(121, true)
	assert_array(laps).is_equal([2, 3])
	led.start_count(40)
	assert_int(meter.shown_lap()).is_equal(1)
	assert_str(meter.badge_text()).is_empty()


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


## The quota mark stands on the target line over the tube's top, at its middle.
func _assert_quota_mark_on_top(meter: QuotaMeter) -> void:
	var bar: Rect2 = meter.bar().get_global_rect()
	var cell: float = ArtStyle.ART_SCALE
	assert_float(meter.quota_mark().y).is_equal_approx(bar.position.y - cell / 2.0, 0.5)
	assert_float(meter.quota_mark().x).is_equal_approx(bar.get_center().x, 0.5)


func _palette() -> Array[Color]:
	var colours: Array[Color] = []
	var file: FileAccess = FileAccess.open(PALETTE_FILE, FileAccess.READ)
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		var parts: PackedStringArray = line.split(" ")
		if parts.size() >= 2 and not line.begins_with(";") and parts[0] != ".":
			colours.append(Color(parts[1]))
	return colours


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
