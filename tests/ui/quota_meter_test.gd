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


## The tag, printed in the gauge: "€N to go" in light tomato on the well, mustard once near; none
## once the quota is met (on it or past it).
func test_the_tag_says_how_far_the_quota_is() -> void:
	var meter: QuotaMeter = await _meter()
	meter.show_projected(22, 73)
	assert_str(meter.tag_label.text).is_equal("€51 to go")
	assert_that(_tag_color(meter)).is_equal(QuotaMeter.SHORT_TAG_COLOR)
	assert_bool(meter.is_near()).is_false()
	meter.show_projected(60, 73)
	assert_bool(meter.is_near()).is_true()
	assert_that(_tag_color(meter)).is_equal(QuotaMeter.NEAR_TAG_COLOR)
	meter.show_projected(73, 73)
	assert_bool(meter.tag_label.visible).is_false()
	assert_bool(meter.is_near()).is_false()
	meter.show_projected(117, 73)
	assert_bool(meter.tag_label.visible).is_false()
	# A drag shows its change in the tag's place instead, green for a gain, tomato for a loss.
	meter.show_projected(10, 73)
	meter.show_hypothetical(16, 6, 73)
	assert_bool(meter.tag_label.visible).is_false()
	assert_str(meter.shown_text()).is_equal(QuotaMeter.HYPOTHETICAL_TEXT % [16, 6])
	assert_that(_color(meter.delta_label)).is_equal(QuotaMeter.GAIN_TAG_COLOR)
	meter.show_hypothetical(4, -6, 73)
	assert_that(_color(meter.delta_label)).is_equal(QuotaMeter.SHORT_TAG_COLOR)
	meter.show_projected(46, 73)
	assert_bool(meter.tag_label.visible).is_true()


## The tag is split at the liquid's front (2026-11-01): the part over the well keeps its colour,
## its twin over the liquid reads in paper on the short (red) liquid and in ink once near; each
## side is clipped to its share of the gauge, so the two never overlap.
func test_the_tag_splits_at_the_liquid() -> void:
	var meter: QuotaMeter = await _meter()
	var bar: Rect2 = meter.bar().get_global_rect()
	for amount: int in [10, 70, 96]:
		meter.show_projected(amount, 100)
		await _frames(2)
		meter.call("_place_tags")
		var twin: Label = meter.wet_twin(meter.tag_label)
		assert_str(twin.text).is_equal(meter.tag_label.text)
		assert_that(twin.get_global_rect()).is_equal(meter.tag_label.get_global_rect())
		var front: float = bar.size.x * amount / 100.0
		assert_float(meter.wet_width()).is_equal_approx(front, 6.0)
		assert_that(_color(twin)).is_equal(QuotaMeter.WET_TAG_COLOR)
		var dry: Color = (
			QuotaMeter.SHORT_TAG_COLOR if not meter.is_near() else QuotaMeter.NEAR_TAG_COLOR
		)
		assert_that(_color(meter.tag_label)).is_equal(dry)


## The gauge keeps its width through a count: only the amount's reserve follows it.
func test_the_gauge_keeps_its_width() -> void:
	var meter: QuotaMeter = await _meter()
	var widths: Array[float] = []
	for amount: int in [0, 9, 72, 73, 900, 1500]:
		meter.show_projected(amount, 999)
		await _frames(1)
		widths.append(meter.bar().size.x)
	for width: float in widths:
		assert_float(width).is_equal(widths[0])


## The tag is printed inside the gauge (v0.83, the user's choice of 2026-11-01): centred in it
## (2026-11-01) and on its height, its whole text inside the gauge, and the amount right after the
## gauge with no reserve but its three digits. The widest lap tag fits too.
func test_the_tag_is_printed_inside_the_gauge() -> void:
	var meter: QuotaMeter = await _meter()
	for amount: int in [0, 72, 73, 900]:
		meter.show_projected(amount, 999)
		await _frames(2)
		_assert_inside_the_gauge(meter, meter.tag_label)
	meter.show_projected(0, 999)
	meter.tag_label.text = QuotaMeter.LAP_TAG_TEXT % [999, 99]
	meter.call("_fit_readout")
	_assert_inside_the_gauge(meter, meter.tag_label)
	meter.show_hypothetical(152, 120, 999)
	await _frames(2)
	_assert_inside_the_gauge(meter, meter.delta_label)
	var bar: Rect2 = meter.bar().get_global_rect()
	var amount_rect: Rect2 = meter.amount_label.get_global_rect()
	assert_float(amount_rect.position.x - bar.end.x).is_less_equal(QuotaMeter.SEPARATION + 1.0)
	assert_float(amount_rect.size.x).is_equal_approx(QuotaMeter.readout_width(), 1.0)


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
	assert_bool(meter.tag_label.visible).is_false()


func test_lap_of() -> void:
	assert_int(QuotaMeter.lap_of(79, 40)).is_equal(1)
	assert_int(QuotaMeter.lap_of(80, 40)).is_equal(2)
	assert_int(QuotaMeter.lap_of(-5, 40)).is_equal(0)
	assert_int(QuotaMeter.lap_of(80, 0)).is_equal(0)


func _assert_inside_the_gauge(meter: QuotaMeter, label: Label) -> void:
	var bar: Rect2 = meter.bar().get_global_rect()
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var drawn: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var rect: Rect2 = label.get_global_rect()
	var ink: Rect2 = Rect2(rect.get_center().x - drawn / 2.0, rect.position.y, drawn, rect.size.y)
	var room: Rect2 = bar.grow_individual(
		-QuotaMeter.TAG_INSET + 1.0, 0.0, -QuotaMeter.TAG_INSET + 1.0, 0.0
	)
	assert_bool(room.encloses(ink)).override_failure_message("%s in %s" % [ink, room]).is_true()
	assert_float(rect.get_center().x).is_equal_approx(bar.get_center().x, 1.0)
	assert_float(rect.get_center().y).is_equal_approx(bar.get_center().y, 1.0)


static func _tag_color(meter: QuotaMeter) -> Color:
	meter.call("_place_tags")
	return _color(meter.tag_label)


static func _color(label: Label) -> Color:
	return label.get_theme_color("font_color")


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
