extends GdUnitTestSuite
## Plan section 8 (since v0.20): an offer's presentation timeline (OfferTimeline) and the reward,
## upgrade, run_start and count_up fields built from it and from the count-up, with their types.

const BREAD := "res://data/cards/bread.tres"
const MILK := "res://data/cards/milk.tres"
const SOUP := "res://data/cards/soup.tres"


## Every time is measured from the show; decide_ms is the choice.
func test_times_count_from_the_show() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(1000)
	timeline.mark_presented(1220)
	timeline.mark_armed(1350)
	assert_dict(timeline.fields(4000)).is_equal(
		{"decide_ms": 3000, "presented_ms": 220, "armed_ms": 350, "presentation_skipped": false}
	)
	# Logged in this order.
	assert_array(timeline.fields(4000).keys()).is_equal(
		["decide_ms", "presented_ms", "armed_ms", "presentation_skipped"]
	)


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


## An offer never shown (no rack, the debug replay) logs 0 for every time, and ignores marks.
func test_an_offer_never_shown_logs_zeros() -> void:
	var timeline: OfferTimeline = OfferTimeline.new()
	timeline.mark_presented(1220)
	timeline.mark_armed(1350)
	assert_dict(timeline.fields(5000)).is_equal(
		{"decide_ms": 0, "presented_ms": 0, "armed_ms": 0, "presentation_skipped": false}
	)


## presentation_skipped is the timeline's own field, set by a skippable presentation.
func test_a_skipped_presentation_is_logged() -> void:
	var timeline: OfferTimeline = OfferTimeline.new(0)
	timeline.presentation_skipped = true
	assert_bool(timeline.fields(10)["presentation_skipped"]).is_true()


## The reward event's fields, in order, with their types; plain strings in JSON.
func test_reward_event_fields() -> void:
	var bread: CardDefinition = load(BREAD)
	var milk: CardDefinition = load(MILK)
	var soup: CardDefinition = load(SOUP)
	var offered: Array[CardDefinition] = [bread, milk, soup]
	var timeline: OfferTimeline = OfferTimeline.new(500)
	timeline.mark_presented(730)
	timeline.mark_armed(860)
	var replaced: CardInstance = CardInstance.new(soup, 7)
	var event: Dictionary = RunEvents.reward(
		3, offered, milk, replaced, timeline.fields(2500), true
	)
	(
		assert_array(event.keys())
		. is_equal(
			[
				"shift",
				"offered",
				"picked",
				"skipped",
				"replaced",
				"decide_ms",
				"presented_ms",
				"armed_ms",
				"presentation_skipped",
				"deck_view_opened",
			]
		)
	)
	assert_int(event["shift"]).is_equal(3)
	assert_array(event["offered"]).is_equal(["bread", "milk", "soup"])
	assert_str(event["picked"]).is_equal("milk")
	assert_bool(event["skipped"]).is_false()
	assert_str(event["replaced"]).is_equal("soup")
	assert_int(event["decide_ms"]).is_equal(2000)
	assert_int(event["presented_ms"]).is_equal(230)
	assert_int(event["armed_ms"]).is_equal(360)
	assert_bool(event["presentation_skipped"]).is_false()
	assert_bool(event["deck_view_opened"]).is_true()
	assert_str(JSON.stringify(event)).contains('"picked":"milk"')
	var skip: Dictionary = RunEvents.reward(1, offered, null, null, timeline.fields(900), false)
	assert_str(skip["picked"]).is_empty()
	assert_bool(skip["skipped"]).is_true()
	assert_str(skip["replaced"]).is_empty()
	assert_int(skip["armed_ms"]).is_equal(360)


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
