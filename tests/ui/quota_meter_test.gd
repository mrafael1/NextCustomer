extends GdUnitTestSuite
## The top bar's liquid gauge (#86, gauge TA; QuotaMeter and QuotaFlag): SPEND and "€N+" as its
## words; full exactly at the quota while short; the flag planted at the quota once the amount meets
## it (the count's ding, or a projected total reaching it), sliding back as the gauge re-scales to
## the amount; the liquid's colour by status; the tag's text and colours from core's ShiftMargin;
## the chip's glow from NEAR_SHARE of the quota while short; a drag's preview keeps the tag's slot
## for its change; reduced motion plants the flag standing still; from twice the quota the count
## laps the gauge (the quota crossing's E). Drawn checks: the flag stands on the gauge.


func test_the_words_are_spend_and_the_quota_plus() -> void:
	var meter: QuotaMeter = await _meter()
	var key: Label = meter.get_child(0) as Label
	assert_str(key.text).is_equal("SPEND")
	assert_str(QuotaMeter.QUOTA_AMOUNT % 73).is_equal("€73+")


func test_the_flag_anchors_the_quota() -> void:
	var meter: QuotaMeter = await _meter()
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	meter.follow(led)
	led.start_count(73)
	assert_bool(meter.flag_shown()).is_false()
	led.show_subtotal(60, false)
	assert_bool(meter.flag_shown()).is_false()
	# Past the quota before the ding: full, no flag yet.
	led.show_subtotal(80, false)
	assert_bool(meter.flag_shown()).is_false()
	assert_float(meter.fill()).is_equal(1.0)
	led.show_subtotal(80, true)
	assert_bool(meter.flag_shown()).is_true()
	await _frames(2)
	_assert_flag_at(meter, QuotaMeter.flag_fraction(80, 73))
	# It slides back as the amount climbs (short of twice the quota, where the laps start).
	led.show_subtotal(130, true)
	await _frames(2)
	_assert_flag_at(meter, QuotaMeter.flag_fraction(130, 73))
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


## The tag: "€N to go" in dark tomato on paper, in ink once near; "Spot on" and "+€N" on mustard.
func test_the_tag_says_how_far_the_quota_is() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(22, 73)
	assert_str(meter.tag_label.text).is_equal("€51 to go")
	assert_that(meter.tag_label.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
	assert_bool(meter.is_near()).is_false()
	meter.show_projected(60, 73)
	assert_bool(meter.is_near()).is_true()
	assert_that(meter.tag_label.get_theme_color("font_color")).is_equal(Palette.INK)
	meter.show_projected(73, 73)
	assert_str(meter.tag_label.text).is_equal(QuotaMeter.ON_QUOTA_TEXT)
	assert_bool(meter.is_near()).is_false()
	meter.show_projected(117, 73)
	assert_str(meter.tag_label.text).is_equal("+€44")
	var style: StyleBoxFlat = meter.tag_label.get_theme_stylebox("normal") as StyleBoxFlat
	assert_that(style.bg_color).is_equal(Palette.MUSTARD)
	# A drag shows its change in the tag's slot instead.
	meter.show_hypothetical(52, 6, 73)
	assert_bool(meter.tag_label.visible).is_false()
	assert_str(meter.shown_text()).is_equal(QuotaMeter.HYPOTHETICAL_TEXT % [52, 6])
	meter.show_projected(46, 73)
	assert_bool(meter.tag_label.visible).is_true()


## The widest tag fits its slot, and the slot keeps the gauge's width through a count.
func test_the_tag_fits_its_slot() -> void:
	var meter: QuotaMeter = await _meter()
	var widths: Array[float] = []
	for amount: int in [0, 9, 72, 73, 900]:
		meter.show_projected(amount, 999)
		await _frames(1)
		var tag: Label = meter.tag_label
		assert_float(tag.get_minimum_size().x).is_less_equal(QuotaMeter.tag_width())
		widths.append(meter.bar().size.x)
	for width: float in widths:
		assert_float(width).is_equal(widths[0])


## The tag is a sticker fitted to its text (v0.83), at the readout's end, and the readout shares
## its room between the amount and the tag (or a drag's change), so it is narrower than an amount's
## and a tag's reserves side by side: the gauge gets the rest.
func test_the_tag_fits_its_text_and_the_gauge_gets_the_room() -> void:
	var meter: QuotaMeter = await _meter()
	var bar_width: float = meter.bar().size.x
	for amount: int in [0, 72, 73, 900]:
		meter.show_projected(amount, 999)
		await _frames(2)
		var tag: Label = meter.tag_label
		assert_float(tag.size.x).is_equal_approx(tag.get_minimum_size().x, 0.5)
		assert_float(tag.size.y).is_equal_approx(tag.get_combined_minimum_size().y, 0.5)
		assert_float(tag.size.y).is_greater_equal(QuotaMeter.TAG_HEIGHT)
		var rect: Rect2 = tag.get_global_rect()
		var middle: float = meter.get_global_rect().get_center().y
		assert_float(rect.get_center().y).is_equal_approx(middle, 1.0)
		(
			assert_bool(meter.get_global_rect().encloses(rect))
			. override_failure_message(str(rect))
			. is_true()
		)
		assert_float(meter.bar().size.x).is_equal(bar_width)
	var side_by_side: float = (
		QuotaMeter.amount_width()
		+ maxf(QuotaMeter.tag_width(), QuotaMeter.delta_width())
		+ QuotaMeter.SEPARATION
	)
	assert_float(QuotaMeter.readout_width()).is_less(side_by_side)
	# The widest lap tag ("€999 to ×99") fits its reserve.
	meter.show_projected(0, 999)
	meter.tag_label.text = QuotaMeter.LAP_TAG_TEXT % [999, 99]
	assert_float(meter.tag_label.get_minimum_size().x).is_less_equal(QuotaMeter.tag_width())


## The liquid's colour follows the status (the user's idea, 2026-10-19): red while short, orange
## from NEAR_SHARE of the quota (and past it before the ding), green once met; gold past the flag.
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


## A meter in a 560 px chip-sized box, with reduced motion unless `reduced` is false.
## The quota crossing's E: twice the quota laps the gauge once, while counting only: the flag
## moves to the end naming the next multiple, the tag says how far it is, and each new multiple
## emits lap_reached once; the next count ends the laps.
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
	assert_str(meter.tag_label.text).is_equal("€40 to ×3")
	await _frames(2)
	_assert_flag_at(meter, 1.0)
	led.show_subtotal(95, true)
	assert_array(laps).is_equal([2])
	assert_str(meter.tag_label.text).is_equal("€25 to ×3")
	led.show_subtotal(121, true)
	assert_array(laps).is_equal([2, 3])
	assert_str(meter.tag_label.text).is_equal("€39 to ×4")
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
	assert_str(meter.tag_label.text).is_equal("+€60")


func test_lap_of() -> void:
	assert_int(QuotaMeter.lap_of(79, 40)).is_equal(1)
	assert_int(QuotaMeter.lap_of(80, 40)).is_equal(2)
	assert_int(QuotaMeter.lap_of(-5, 40)).is_equal(0)
	assert_int(QuotaMeter.lap_of(80, 0)).is_equal(0)


func _meter(reduced: bool = true) -> QuotaMeter:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	if reduced:
		meter.reduced_motion = func() -> bool: return true
	meter.size = Vector2(560, TopBar.ROW_SIZE.y)
	add_child(meter)
	await _frames(2)
	return meter


## The flag stands `fraction` along the gauge's inside (to the art pixel), on top of the gauge
## from above it to its foot.
func _assert_flag_at(meter: QuotaMeter, fraction: float) -> void:
	var bar: Rect2 = meter.bar().get_global_rect()
	var cell: float = ArtStyle.ART_SCALE
	var inner: float = floorf(bar.size.x / cell) - 2.0
	var expected: float = bar.position.x + (1.0 + inner * fraction) * cell
	var flag: QuotaFlag = meter.flag()
	assert_float(flag.global_position.x).is_equal_approx(expected, cell)
	var rest: Rect2 = flag.rest_rect()
	rest.position += flag.global_position
	assert_float(rest.position.y).is_less(bar.position.y)
	assert_float(rest.end.y).is_greater_equal(bar.end.y)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
