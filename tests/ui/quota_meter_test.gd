extends GdUnitTestSuite
## The quota gauge (#86, gauge TA; the tube beside the receipt since the shift scene polish,
## mock-up shift_scene_polish_v2.html section 2, A2; the laps since the user's feedback of
## 2026-11-03; QuotaMeter): a tube that prints no number and fills up toward the target line on
## its top; full exactly at the quota in its first lap; once the quota is met (the count's ding,
## or a projected total reaching it) it never re-scales: it refills from its foot lap by lap, each
## lap in its own colour over a full tube of the lap before's (gold, orange, velvet, violet: v4's
## A1), the lap lamp over the housing naming the laps made (a check, then "×N") and no flag; the
## first lap's colour by status; the tube's glow from NEAR_SHARE of the quota while short; a
## drag's preview kept apart from the shown amount; reduced motion keeps the levels and the
## colours; from twice the quota the count emits lap_reached once per multiple (the quota
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
	assert_int(QuotaLaps.lap_for(0, 40, false)).is_equal(1)
	assert_int(QuotaLaps.lap_for(39, 40, false)).is_equal(1)
	assert_int(QuotaLaps.lap_for(90, 40, false)).is_equal(1)
	assert_int(QuotaLaps.lap_for(39, 40, true)).is_equal(1)
	assert_int(QuotaLaps.lap_for(40, 40, true)).is_equal(2)
	assert_int(QuotaLaps.lap_for(79, 40, true)).is_equal(2)
	assert_int(QuotaLaps.lap_for(80, 40, true)).is_equal(3)
	assert_int(QuotaLaps.lap_for(120, 40, true)).is_equal(4)
	assert_int(QuotaLaps.lap_for(165, 40, true)).is_equal(5)
	assert_int(QuotaLaps.lap_for(10, 0, true)).is_equal(1)


## Each lap's fill runs from (lap - 1) to lap times the quota.
func test_lap_fill() -> void:
	assert_float(QuotaLaps.lap_fill(20.0, 40, 1)).is_equal(0.5)
	assert_float(QuotaLaps.lap_fill(60.0, 40, 1)).is_equal(1.0)
	assert_float(QuotaLaps.lap_fill(40.0, 40, 2)).is_equal(0.0)
	assert_float(QuotaLaps.lap_fill(60.0, 40, 2)).is_equal(0.5)
	assert_float(QuotaLaps.lap_fill(100.0, 40, 3)).is_equal(0.5)
	assert_float(QuotaLaps.lap_fill(30.0, 40, 3)).is_equal(0.0)
	assert_float(QuotaLaps.lap_fill(30.0, 0, 3)).is_equal(1.0)


## The lap colours (v4's A1): gold, orange, velvet, violet, then gold again; each over a full tube
## of the lap before's (the met green behind lap 2); all of them the art palette's, none shared
## with the first lap's short or near ramps.
func test_the_lap_colours_by_total_and_quota() -> void:
	var expected: Array = [
		[40, 2, Palette.GOLD, Palette.GOOD],
		[60, 2, Palette.GOLD, Palette.GOOD],
		[80, 3, Palette.ORANGE, Palette.GOLD],
		[100, 3, Palette.ORANGE, Palette.GOLD],
		[130, 4, Palette.VELVET, Palette.ORANGE],
		[170, 5, Palette.VIOLET, Palette.VELVET],
		[210, 6, Palette.GOLD, Palette.VIOLET],
	]
	for row: Array in expected:
		var lap: int = QuotaLaps.lap_for(row[0], 40, true)
		assert_int(lap).override_failure_message(str(row)).is_equal(row[1])
		assert_that(QuotaLaps.lap_ramp(lap)[1]).is_equal(row[2])
		assert_that(QuotaLaps.backdrop_ramp(lap)[1]).is_equal(row[3])
	var palette: Array[Color] = _palette()
	var ramps: Array = QuotaLaps.LAP_RAMPS.duplicate()
	ramps.append_array([QuotaMeter.SHORT_RAMP, QuotaMeter.NEAR_RAMP, QuotaMeter.MET_RAMP])
	for colour_ramp: Array in ramps:
		for colour: Color in colour_ramp:
			assert_bool(palette.has(colour)).override_failure_message(str(colour)).is_true()
	# No lap shares a colour with the short or near tube, and each lap's body differs from the
	# one behind it.
	for lap: int in range(QuotaLaps.FIRST_LAP, QuotaLaps.FIRST_LAP + QuotaLaps.LAP_RAMPS.size()):
		for colour: Color in QuotaLaps.lap_ramp(lap):
			var why: String = "lap %d %s" % [lap, colour]
			assert_bool(QuotaMeter.SHORT_RAMP.has(colour)).override_failure_message(why).is_false()
			assert_bool(QuotaMeter.NEAR_RAMP.has(colour)).override_failure_message(why).is_false()
		assert_that(QuotaLaps.lap_ramp(lap)[1]).is_not_equal(QuotaLaps.backdrop_ramp(lap)[1])


## The lap ramps: lit, body and dark from light to dark, and every lap's body HUE_GAP degrees or
## more from the short tube's tomato and the near tube's brass, or (gold and velvet, by decision:
## QuotaLaps.VALUE_SEPARATED) VALUE_GAP of value from the warning body it comes near in hue. The
## new orange and violet ramps (art/src/palette.txt) keep the hue gap.
func test_every_lap_keeps_clear_of_the_warning_hues() -> void:
	for lap: int in range(QuotaLaps.FIRST_LAP, QuotaLaps.FIRST_LAP + QuotaLaps.LAP_RAMPS.size()):
		var lap_ramp: Array[Color] = QuotaLaps.lap_ramp(lap)
		var body: Color = lap_ramp[1]
		assert_float(lap_ramp[0].get_luminance()).is_greater(body.get_luminance())
		assert_float(body.get_luminance()).is_greater(lap_ramp[2].get_luminance())
		for warning: Color in [QuotaMeter.SHORT_RAMP[1], QuotaMeter.NEAR_RAMP[1]]:
			var gap: float = absf(body.h - warning.h) * 360.0
			gap = minf(gap, 360.0 - gap)
			var why: String = "lap %d %s is %.1f deg from %s" % [lap, body, gap, warning]
			if gap >= QuotaLaps.HUE_GAP:
				continue
			assert_bool(QuotaLaps.VALUE_SEPARATED.has(body)).override_failure_message(why).is_true()
			assert_float(absf(body.v - warning.v)).override_failure_message(why).is_greater_equal(
				QuotaLaps.VALUE_GAP
			)
	for orange_or_violet: Color in [Palette.ORANGE, Palette.VIOLET]:
		assert_bool(QuotaLaps.VALUE_SEPARATED.has(orange_or_violet)).is_false()
	assert_array(QuotaLaps.lap_ramp(3)).is_equal(
		[Palette.ORANGE_LIGHT, Palette.ORANGE, Palette.ORANGE_DARK]
	)
	assert_array(QuotaLaps.lap_ramp(5)).is_equal(
		[Palette.VIOLET_LIGHT, Palette.VIOLET, Palette.VIOLET_DARK]
	)


## During a count: lap 2 pours gold over the full green tube from the foot up, lap 3 orange over
## gold; the lamp names the laps made (a check, then "×2").
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
	assert_array(meter.liquid_ramp()).is_equal(QuotaLaps.lap_ramp(2))
	assert_that(QuotaLaps.backdrop_ramp(meter.shown_lap())).is_equal(QuotaMeter.MET_RAMP)
	assert_str(meter.badge_text()).is_equal(LapLamp.CHECK_TEXT)
	led.show_subtotal(100, true)
	await _frames(2)
	assert_int(meter.shown_lap()).is_equal(3)
	assert_float(meter.fill()).is_equal(0.5)
	assert_str(meter.badge_text()).is_equal("×2")
	assert_array(meter.liquid_ramp()).is_equal(QuotaLaps.lap_ramp(3))


## The lap lamp (v4's A1) sits over the housing's top cap, centred over the glass, inside the
## tower's left margin (a gutter from the stage's left edge, clear of the receipt's well), with
## its glyph inside it from "×2" to "×9".
func test_the_lamp_sits_over_the_housing() -> void:
	var meter: QuotaMeter = await _meter()
	var cell: float = ArtStyle.ART_SCALE
	var rect: Rect2 = meter.badge_rect()
	var on_stage: Rect2 = Rect2(rect.position + ShiftStage.TUBE_RECT.position, rect.size)
	var why: String = str(on_stage)
	assert_bool(ShiftStage.TOWER_RECT.encloses(on_stage)).override_failure_message(why).is_true()
	assert_float(on_stage.end.y).override_failure_message(why).is_less_equal(
		ShiftStage.HOUSING_RECT.position.y
	)
	assert_float(on_stage.position.y).is_greater(0.0)
	assert_float(on_stage.position.x).is_greater_equal(cell)
	assert_float(on_stage.get_center().x).is_equal_approx(ShiftStage.TUBE_RECT.get_center().x, 0.01)
	assert_bool(on_stage.intersects(ShiftStage.RECEIPT_WELL_RECT)).is_false()
	assert_float(on_stage.end.x).is_less_equal(ShiftStage.RECEIPT_X)
	assert_float(rect.size.x).is_equal(LapLamp.SIZE * cell)
	for laps: int in range(2, 10):
		var rows: PackedStringArray = LapLamp.glyph_rows(LapLamp.text_for(laps))
		assert_int(rows.size()).is_equal(LapLamp.GLYPH_HEIGHT)
		# Inside the lens: 2 art px of bezel and rim each side.
		assert_int(rows[0].length()).is_less_equal(LapLamp.SIZE - 2 * LapLamp.LENS_INSET)


## The lamp's text by laps made: dark (none) short of the quota, a check for the first lap, "×N"
## from two; its glyphs ink on a light lap colour, paper on a dark one.
func test_the_lamp_names_the_laps_made() -> void:
	assert_str(LapLamp.text_for(0)).is_empty()
	assert_str(LapLamp.text_for(1)).is_equal(LapLamp.CHECK_TEXT)
	assert_str(LapLamp.text_for(2)).is_equal("×2")
	assert_str(LapLamp.text_for(9)).is_equal("×9")
	assert_str(LapLamp.text_for(12)).is_equal("12")
	assert_str(LapLamp.text_for(LapLamp.MAX_SHOWN + 40)).is_equal(str(LapLamp.MAX_SHOWN))
	# Every glyph, the check to the cap, stays inside the lens (never over the bezel or rim).
	for laps: int in range(1, LapLamp.MAX_SHOWN + 2):
		var text: String = LapLamp.text_for(laps)
		assert_bool(LapLamp.glyph_fits(text)).override_failure_message(text).is_true()
	assert_bool(LapLamp.glyph_fits("×10")).is_false()
	assert_array(LapLamp.glyph_rows("×2")).is_equal(
		PackedStringArray(["....###", "#.#...#", ".#..###", "#.#.#..", "....###"])
	)
	assert_that(QuotaLaps.lamp_ink(QuotaMeter.MET_RAMP)).is_equal(Palette.INK)
	assert_that(QuotaLaps.lamp_ink(QuotaLaps.lap_ramp(2))).is_equal(Palette.INK)
	assert_that(QuotaLaps.lamp_ink(QuotaLaps.lap_ramp(3))).is_equal(Palette.INK)
	assert_that(QuotaLaps.lamp_ink(QuotaLaps.lap_ramp(4))).is_equal(Palette.PAPER)
	assert_that(QuotaLaps.lamp_ink(QuotaLaps.lap_ramp(5))).is_equal(Palette.PAPER)
	var meter: QuotaMeter = await _meter()
	meter.show_projected(30, 40)
	assert_str(meter.badge_text()).is_empty()
	meter.show_projected(40, 40)
	assert_str(meter.badge_text()).is_equal(LapLamp.CHECK_TEXT)
	meter.show_projected(130, 40)
	assert_str(meter.badge_text()).is_equal("×3")


## With motion, the ding past the quota does not snap the tube to full green: the first lap keeps
## pouring (its green, the lamp dark) up to the target line before lap 2's gold starts.
func test_the_first_lap_pours_to_the_top_before_lap_two() -> void:
	var meter: QuotaMeter = await _meter(false)
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(40)
	led.show_subtotal(20, false)
	await _seconds(1.0)
	led.show_subtotal(60, true)
	await _frames(1)
	assert_int(meter.shown_lap()).is_equal(2)
	assert_int(meter._drawn_lap()).is_equal(1)
	assert_str(meter.badge_text()).is_empty()
	assert_array(meter.liquid_ramp()).is_equal(meter.ramp())
	assert_float(meter._front()).is_less(meter._inner())
	await _seconds(1.0)
	assert_int(meter._drawn_lap()).is_equal(2)
	assert_str(meter.badge_text()).is_equal(LapLamp.CHECK_TEXT)
	assert_array(meter.liquid_ramp()).is_equal(QuotaLaps.lap_ramp(2))


## A drop that would leave the lap previews in its own lap's terms: from lap 2 back under the
## quota, the would-be first-lap level in its status colour; from lap 1 past twice the quota,
## lap 3's level in its colour.
func test_a_drag_out_of_the_lap_previews_that_lap() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(52, 40)
	assert_int(meter._drawn_lap()).is_equal(2)
	meter.show_hypothetical(28, -24, 40)
	var plan: Dictionary = meter._preview_plan()
	assert_int(plan["lap"]).is_equal(1)
	assert_float(plan["level"]).is_equal_approx(meter._inner() * 28.0 / 40.0, 0.001)
	assert_array(plan["ramp"]).is_equal(QuotaMeter.SHORT_RAMP)
	meter.show_hypothetical(34, -18, 40)
	assert_array(meter._preview_plan()["ramp"]).is_equal(QuotaMeter.NEAR_RAMP)
	meter.show_projected(24, 40)
	meter.show_hypothetical(100, 76, 40)
	plan = meter._preview_plan()
	assert_int(plan["lap"]).is_equal(3)
	assert_float(plan["level"]).is_equal_approx(meter._inner() * 0.5, 0.001)
	assert_array(plan["ramp"]).is_equal(QuotaLaps.lap_ramp(3))
	meter.show_projected(24, 40)
	assert_bool(meter._preview_plan().is_empty()).is_true()


## Planning laps quietly: a projection crossing a multiple refills the tube and names the lap but
## neither flashes nor pops; a count does both.
func test_only_a_count_pops_a_new_lap() -> void:
	var meter: QuotaMeter = await _meter(false)
	meter.show_projected(60, 40)
	await _seconds(0.6)
	for amount: int in [90, 70, 90]:
		meter.show_projected(amount, 40)
		await _seconds(0.6)
	assert_str(meter.badge_text()).is_equal("×2")
	assert_float(meter._pop).is_equal(0.0)
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(40)
	led.show_subtotal(45, true)
	await _seconds(0.6)
	led.show_subtotal(85, true)
	var popped: bool = false
	for _frame: int in range(60):
		await _frames(1)
		popped = popped or meter._pop > 0.0
	assert_bool(popped).is_true()
	assert_str(meter.badge_text()).is_equal("×2")


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


## Reduced motion keeps the level, the lap, its colours and the lamp (no pop): at once.
func test_reduced_motion_keeps_the_levels_and_colours() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(100, 40)
	await _frames(1)
	assert_int(meter.shown_lap()).is_equal(3)
	assert_float(meter.fill()).is_equal(0.5)
	assert_str(meter.badge_text()).is_equal("×2")
	assert_array(meter.liquid_ramp()).is_equal(QuotaLaps.lap_ramp(3))
	assert_float(meter._pop).is_equal(0.0)
	# With motion, the lamp follows the laps made.
	var moving: QuotaMeter = await _meter(false)
	moving.show_projected(100, 40)
	await _frames(30)
	moving.show_projected(130, 40)
	await _frames(30)
	assert_str(moving.badge_text()).is_equal("×3")


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
	assert_int(QuotaLaps.lap_of(79, 40)).is_equal(1)
	assert_int(QuotaLaps.lap_of(80, 40)).is_equal(2)
	assert_int(QuotaLaps.lap_of(-5, 40)).is_equal(0)
	assert_int(QuotaLaps.lap_of(80, 0)).is_equal(0)


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


## The quota mark stands on the target line across the glass's top row, at its middle.
func _assert_quota_mark_on_top(meter: QuotaMeter) -> void:
	var bar: Rect2 = meter.bar().get_global_rect()
	var cell: float = ArtStyle.ART_SCALE
	assert_float(meter.quota_mark().y).is_equal_approx(bar.position.y + cell * 1.5, 0.5)
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


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
