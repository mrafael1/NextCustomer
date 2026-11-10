extends GdUnitTestSuite
## The planning receipt's PROJECTED roll (ReceiptRoll, 2026-11-08 feedback): a new projection rolls
## the hero (and its line against the target) through the whole euros between the number shown and
## the new one, ending exactly on it, lifted while it rises and not while it falls; a projection
## arriving mid-roll rolls on from the number shown; a first show, reduced motion (ReceiptView's
## planning_still) and the count show the number at once, and the count stops a roll.

const QUOTA := 80
const MAX_FRAMES := 300

var _target: ReceiptTarget


func before_test() -> void:
	_target = auto_free(ReceiptTarget.new())
	add_child(_target)
	_target.size = Vector2(ReceiptTarget.DEFAULT_WIDTH, ReceiptTarget.HEIGHT)
	_target.show_quota(QUOTA)


## A rise: from 10€ to 40€ through values in between, never falling back, ending on 40€ with its
## line against the target; the hero lifted RISE_LIFT px while it rolls, back down once landed.
func test_a_rise_rolls_through_the_values_between_and_ends_exact() -> void:
	_target.show_planned(10, QUOTA)
	await _frames(2)
	var rest_y: float = _target.hero.position.y
	_target.show_planned(40, QUOTA, true)
	assert_bool(_target.roll.rolling()).is_true()
	assert_str(_target.hero.text).is_equal("10€")
	assert_float(_target.hero.position.y).is_equal(rest_y - ReceiptRoll.RISE_LIFT)
	var seen: Array[int] = await _roll_values()
	assert_int(seen.size()).override_failure_message(str(seen)).is_greater(3)
	for index: int in range(1, seen.size()):
		assert_int(seen[index]).override_failure_message(str(seen)).is_greater_equal(
			seen[index - 1]
		)
	assert_int(seen[0]).is_greater(10)
	assert_int(seen[0]).is_less(40)
	assert_str(_target.hero.text).is_equal("40€")
	assert_str(_target.over.text).is_equal(ReceiptTarget.against_text(40, QUOTA))
	assert_float(_target.hero.position.y).is_equal(rest_y)
	assert_int(_target.roll.shown).is_equal(40)


## A fall: from 60€ to 20€, never rising, no lift, ending on 20€ with its line against the target.
func test_a_fall_rolls_down_calmly_and_ends_exact() -> void:
	_target.show_planned(60, QUOTA)
	await _frames(2)
	var rest_y: float = _target.hero.position.y
	_target.show_planned(20, QUOTA, true)
	assert_float(_target.hero.position.y).is_equal(rest_y)
	var seen: Array[int] = await _roll_values()
	assert_int(seen.size()).override_failure_message(str(seen)).is_greater(3)
	for index: int in range(1, seen.size()):
		assert_int(seen[index]).override_failure_message(str(seen)).is_less_equal(seen[index - 1])
	assert_str(_target.hero.text).is_equal("20€")
	assert_str(_target.over.text).is_equal(ReceiptTarget.against_text(20, QUOTA))
	assert_float(_target.hero.position.y).is_equal(rest_y)


## A new projection mid-roll rolls on from the number shown, never back to the old start or on to
## the old goal, and ends exactly on the new one.
func test_a_new_projection_mid_roll_rolls_on_from_the_number_shown() -> void:
	_target.show_planned(10, QUOTA)
	_target.show_planned(110, QUOTA, true)
	while _target.roll.shown < 40:
		await get_tree().process_frame
	var mid: int = _target.roll.shown
	assert_bool(_target.roll.rolling()).is_true()
	_target.show_planned(20, QUOTA, true)
	assert_str(_target.hero.text).is_equal("%d€" % mid)
	var seen: Array[int] = await _roll_values()
	for index: int in range(seen.size()):
		var previous: int = mid if index == 0 else seen[index - 1]
		assert_int(seen[index]).override_failure_message(str(seen)).is_less_equal(previous)
		assert_int(seen[index]).is_greater_equal(20)
	assert_str(_target.hero.text).is_equal("20€")
	assert_int(_target.roll.shown).is_equal(20)


## The same projection again mid-roll (a refresh that changed nothing) keeps the roll going on.
func test_the_same_projection_again_keeps_rolling() -> void:
	_target.show_planned(10, QUOTA)
	_target.show_planned(60, QUOTA, true)
	await _frames(3)
	var mid: int = _target.roll.shown
	_target.show_planned(60, QUOTA, true)
	assert_bool(_target.roll.rolling()).is_true()
	assert_int(_target.roll.shown).is_equal(mid)
	var seen: Array[int] = await _roll_values()
	assert_int(seen[-1]).is_equal(60)


## Shown at once: a first show, a show without animate (reduced motion), and the first projection
## after a count (TOTAL on the caption).
func test_a_first_show_and_reduced_motion_are_instant() -> void:
	_target.show_planned(30, QUOTA, true)
	assert_bool(_target.roll.rolling()).is_false()
	assert_str(_target.hero.text).is_equal("30€")
	_target.show_planned(70, QUOTA)
	assert_bool(_target.roll.rolling()).is_false()
	assert_str(_target.hero.text).is_equal("70€")
	assert_str(_target.over.text).is_equal(ReceiptTarget.against_text(70, QUOTA))
	_target.begin_count(0)
	_target.show_running(55)
	_target.show_planned(12, QUOTA, true)
	assert_bool(_target.roll.rolling()).is_false()
	assert_str(_target.hero.text).is_equal("12€")
	assert_str(_target.total_caption.text).is_equal(ReceiptTarget.PROJECTED_TEXT)


## The receipt's planning_still (the screen's reduced motion setting) shows a new projection at
## once; unset, it rolls.
func test_the_receipts_reduced_motion_shows_the_projection_at_once() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	add_child(receipt)
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 0)
	var names: PackedStringArray = PackedStringArray()
	var still: Array[bool] = [true]
	receipt.planning_still = func() -> bool: return still[0]
	receipt.show_planning(PackedStringArray(), _result(10), names, 7, QUOTA)
	receipt.show_planning(PackedStringArray(), _result(50), names, 7, QUOTA)
	assert_bool(receipt.target.roll.rolling()).is_false()
	assert_str(receipt.target.hero.text).is_equal("50€")
	still[0] = false
	receipt.show_planning(PackedStringArray(), _result(5), names, 7, QUOTA)
	assert_bool(receipt.target.roll.rolling()).is_true()
	assert_str(receipt.target.hero.text).is_equal("50€")


## The count drives the hero itself: starting it stops a roll, and the reading stays.
func test_the_count_stops_a_roll() -> void:
	_target.show_planned(10, QUOTA)
	_target.show_planned(90, QUOTA, true)
	await _frames(2)
	assert_bool(_target.roll.rolling()).is_true()
	_target.begin_count(0)
	assert_bool(_target.roll.rolling()).is_false()
	_target.show_running(5)
	await _frames(30)
	assert_str(_target.hero.text).is_equal("5€")
	assert_str(_target.total_caption.text).is_equal(ReceiptTarget.TOTAL_TEXT)


## The count's readings leave a row landing's bump alone (no roll under way): the hero stays
## lifted BUMP px until the bump drops it.
func test_the_counts_readings_keep_a_row_landings_bump() -> void:
	_target.show_planned(10, QUOTA)
	await _frames(2)
	var rest_y: float = _target.hero.position.y
	_target.begin_count(0)
	_target.show_running(3)
	_target.bump()
	_target.show_running(4)
	_target.show_running(5)
	assert_float(_target.hero.position.y).is_equal(rest_y - ReceiptTarget.BUMP)
	await get_tree().create_timer(ReceiptTarget.BUMP_SECONDS + 0.1).timeout
	assert_float(_target.hero.position.y).is_equal(rest_y)


## A count started mid-roll keeps the sizes of the projection it rolled to.
func test_a_count_started_mid_roll_sizes_from_the_new_projection() -> void:
	_target.show_planned(10, QUOTA)
	_target.show_planned(99999, QUOTA, true)
	await _frames(1)
	assert_bool(_target.roll.rolling()).is_true()
	_target.begin_count(0)
	assert_that(_target.cells).is_equal(
		ReceiptTarget.cells_for(99999, ReceiptTarget.DEFAULT_WIDTH - 12.0)
	)


## A rise drops its lift as the last euro shows (the land), before the roll's tail ends.
func test_a_rise_lands_as_its_last_euro_shows() -> void:
	_target.show_planned(10, QUOTA)
	await _frames(2)
	var rest_y: float = _target.hero.position.y
	_target.show_planned(40, QUOTA, true)
	for _frame: int in range(MAX_FRAMES):
		await get_tree().process_frame
		if _target.hero.text == "40€":
			break
	assert_str(_target.hero.text).is_equal("40€")
	assert_float(_target.hero.position.y).is_equal(rest_y)


## A roll lasts MIN_SECONDS to MAX_SECONDS, longer for a bigger change.
func test_a_roll_lasts_a_short_count() -> void:
	assert_float(ReceiptRoll.seconds_for(1)).is_equal_approx(ReceiptRoll.MIN_SECONDS, 0.02)
	assert_float(ReceiptRoll.seconds_for(-1000)).is_equal(ReceiptRoll.MAX_SECONDS)
	assert_float(ReceiptRoll.seconds_for(10)).is_greater(ReceiptRoll.seconds_for(2))
	assert_float(ReceiptRoll.MIN_SECONDS).is_greater_equal(0.25)
	assert_float(ReceiptRoll.MAX_SECONDS).is_less_equal(0.45)


## The values the hero changes to, frame by frame, until the roll lands (each change once; not
## the number shown when it starts).
func _roll_values() -> Array[int]:
	var seen: Array[int] = []
	var last: int = _target.hero.text.to_int()
	for _frame: int in range(MAX_FRAMES):
		if not _target.roll.rolling():
			break
		await get_tree().process_frame
		var value: int = _target.hero.text.to_int()
		if value != last:
			seen.append(value)
			last = value
	assert_bool(_target.roll.rolling()).is_false()
	return seen


static func _result(total: int) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = total
	return result


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
