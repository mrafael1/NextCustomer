extends GdUnitTestSuite
## Plan section 8 (since v0.20): an offer's presentation timeline (OfferTimeline, a machine
## visit's since #77: telemetry_test checks the machine_visit event) and the count_up fields,
## with their types.


## Every time is measured from the show; decide_ms is the choice.
func test_times_count_from_the_show() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(1000)
	timeline.mark_presented(1220)
	timeline.mark_armed(1350)
	(
		assert_dict(timeline.fields(4000))
		. is_equal(
			{
				"decide_ms": 3000,
				"presented_ms": 220,
				"armed_ms": 350,
				"presentation_skipped": false,
				"chute_wait_ms": 0,
			}
		)
	)
	# Logged in this order.
	assert_array(timeline.fields(4000).keys()).is_equal(
		["decide_ms", "presented_ms", "armed_ms", "presentation_skipped", "chute_wait_ms"]
	)


## The chute wait (the keys armed to the CONFIRM) is interactive: presented_ms and armed_ms leave
## it out, decide_ms keeps it, chute_wait_ms logs it. A player reading odds cards for 25 s on a
## machine with no animation logs a short armed_ms.
func test_the_chute_wait_is_left_out_of_the_presentation_times() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(1000)
	timeline.start_wait(1400)
	timeline.start_wait(2000)  # Only the first start counts.
	timeline.end_wait(26400)
	timeline.end_wait(27000)  # Not waiting: nothing.
	timeline.mark_presented(26500)
	timeline.mark_armed(26700)
	var fields: Dictionary = timeline.fields(30000)
	assert_int(fields["decide_ms"]).is_equal(29000)
	assert_int(fields["chute_wait_ms"]).is_equal(25000)
	assert_int(fields["presented_ms"]).is_equal(500)
	assert_int(fields["armed_ms"]).is_equal(700)


## A visit without a chute wait (STAMP DAY, a resumed pick) has none; a wait never started after
## the prizes showed.
func test_no_wait_without_the_keys() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(1000)
	timeline.end_wait(1500)
	timeline.mark_presented(1200)
	timeline.start_wait(1300)
	timeline.end_wait(1900)
	timeline.mark_armed(1350)
	var fields: Dictionary = timeline.fields(2000)
	assert_int(fields["chute_wait_ms"]).is_equal(0)
	assert_int(fields["armed_ms"]).is_equal(350)


## Only the first presented and armed moments count (the deck view hides and shows the panel).
func test_only_the_first_marks_count() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(1000)
	timeline.mark_presented(1220)
	timeline.mark_presented(1900)
	timeline.mark_armed(1350)
	timeline.mark_armed(2000)
	var fields: Dictionary = timeline.fields(2500)
	assert_int(fields["presented_ms"]).is_equal(220)
	assert_int(fields["armed_ms"]).is_equal(350)


## A moment the choice came before is NOT_REACHED (-1), even when it is marked later.
func test_a_moment_not_reached_by_the_choice_is_minus_one() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(1000)
	var early: Dictionary = timeline.fields(1100)
	assert_int(early["decide_ms"]).is_equal(100)
	assert_int(early["presented_ms"]).is_equal(OfferTimeline.NOT_REACHED)
	assert_int(early["armed_ms"]).is_equal(-1)
	timeline.mark_presented(1220)
	timeline.mark_armed(1350)
	assert_int(timeline.fields(1300)["presented_ms"]).is_equal(220)
	assert_int(timeline.fields(1300)["armed_ms"]).is_equal(-1)


## An offer never shown (a debug replay) logs 0 for every time, and ignores marks.
func test_an_offer_never_shown_logs_zeros() -> void:
	var timeline: OfferTimeline = OfferTimeline.new()
	timeline.mark_presented(1220)
	timeline.mark_armed(1350)
	(
		assert_dict(timeline.fields(5000))
		. is_equal(
			{
				"decide_ms": 0,
				"presented_ms": 0,
				"armed_ms": 0,
				"presentation_skipped": false,
				"chute_wait_ms": 0,
			}
		)
	)


## presentation_skipped is the timeline's own field, set by a skippable presentation.
func test_a_skipped_presentation_is_logged() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(0)
	timeline.presentation_skipped = true
	assert_bool(timeline.fields(10)["presentation_skipped"]).is_true()


## The count_up event: count-up time, the hold's fast-forward, and the taps (skip_at_ms from the
## checkout click to the first tap, -1 without one).
func test_count_up_event_fields() -> void:
	var tapped: Dictionary = RunEvents.count_up(2, 1000, 3400, false, 1600, true)
	(
		assert_array(tapped.keys())
		. is_equal(
			[
				"shift",
				"count_up_ms",
				"fast_forward_used",
				"skip_used",
				"skip_at_ms",
				"dessert_skipped",
				"base_speed",
				"speed_setting",
				"reduced_motion",
				"step_count",
				"planned_ms",
			]
		)
	)
	assert_int(tapped["shift"]).is_equal(2)
	assert_int(tapped["count_up_ms"]).is_equal(2400)
	assert_bool(tapped["fast_forward_used"]).is_false()
	assert_bool(tapped["skip_used"]).is_true()
	assert_int(tapped["skip_at_ms"]).is_equal(600)
	assert_bool(tapped["dessert_skipped"]).is_true()
	var untouched: Dictionary = RunEvents.count_up(1, 1000, 5000, true, -1, false)
	assert_int(untouched["count_up_ms"]).is_equal(4000)
	assert_bool(untouched["fast_forward_used"]).is_true()
	assert_bool(untouched["skip_used"]).is_false()
	assert_int(untouched["skip_at_ms"]).is_equal(-1)
	assert_bool(untouched["dessert_skipped"]).is_false()


## The count_up event's speed fields (since v0.30): the speed used, the player's settings, the
## row's step count and the beat plan's estimate, with their types; left out, 1.0, 1.0, false, 0
## and 0.
func test_count_up_event_speed_fields() -> void:
	var fast: Dictionary = RunEvents.count_up(
		3, 1000, 4200, false, -1, false, 1.875, 1.5, true, 27, 3100
	)
	assert_int(typeof(fast["base_speed"])).is_equal(TYPE_FLOAT)
	assert_float(fast["base_speed"]).is_equal(1.875)
	assert_int(typeof(fast["speed_setting"])).is_equal(TYPE_FLOAT)
	assert_float(fast["speed_setting"]).is_equal(1.5)
	assert_int(typeof(fast["reduced_motion"])).is_equal(TYPE_BOOL)
	assert_bool(fast["reduced_motion"]).is_true()
	assert_int(typeof(fast["step_count"])).is_equal(TYPE_INT)
	assert_int(fast["step_count"]).is_equal(27)
	assert_int(typeof(fast["planned_ms"])).is_equal(TYPE_INT)
	assert_int(fast["planned_ms"]).is_equal(3100)
	assert_int(fast["count_up_ms"]).is_equal(3200)
	var line: String = JSON.stringify(fast)
	assert_str(line).contains('"base_speed":1.875')
	assert_str(line).contains('"speed_setting":1.5')
	assert_str(line).contains('"reduced_motion":true')
	assert_str(line).contains('"step_count":27')
	assert_str(line).contains('"planned_ms":3100')
	var unset: Dictionary = RunEvents.count_up(1, 1000, 5000, false, -1, false)
	assert_int(typeof(unset["base_speed"])).is_equal(TYPE_FLOAT)
	assert_float(unset["base_speed"]).is_equal(1.0)
	assert_int(typeof(unset["speed_setting"])).is_equal(TYPE_FLOAT)
	assert_float(unset["speed_setting"]).is_equal(1.0)
	assert_bool(unset["reduced_motion"]).is_false()
	assert_int(typeof(unset["step_count"])).is_equal(TYPE_INT)
	assert_int(unset["step_count"]).is_equal(0)
	assert_int(typeof(unset["planned_ms"])).is_equal(TYPE_INT)
	assert_int(unset["planned_ms"]).is_equal(0)
	assert_str(JSON.stringify(unset)).contains('"base_speed":1.0')
