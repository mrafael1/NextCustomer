extends GdUnitTestSuite
## Tests on the live data/inspections/ files (plan section 3.9). Unlike the fixture-based
## inspection tests, these expected values are updated when inspection numbers are tuned.

const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const CARDS_DIR := "res://data/cards"
const DAY := "res://data/inspections/%s.tres"


func test_the_placeholder_inspection_matches_the_plan() -> void:
	var spot_check: InspectionDefinition = load(SPOT_CHECK)
	assert_str(String(spot_check.id)).is_equal("spot_check")
	assert_str(spot_check.display_name).is_equal("Spot check")
	assert_str(spot_check.notice_text).is_equal("Slot 3 pays €0")
	assert_str(spot_check.chip_text).is_equal("Slot 3 pays €0")
	assert_int(spot_check.rules.size()).is_equal(1)
	var rule: NthSlotZeroPayoutRule = spot_check.rules[0]
	assert_int(rule.slot_number).is_equal(3)


func test_the_live_inspection_scores_the_plan_example() -> void:
	var inspections: Array[InspectionDefinition] = [load(SPOT_CHECK)]
	var no_upgrades: Array[UpgradeDefinition] = []
	# Banana 2, Bread 5, Milk 3 + 2 (Bread is Breakfast) = 5, paid 0 in slot 3.
	var row: Array[CardInstance] = _row(["banana", "bread", "milk"])
	assert_int(Scoring.score(row, no_upgrades).total).is_equal(12)
	var inspected: ScoreResult = Scoring.score(row, no_upgrades, inspections)
	assert_array(Array(inspected.payouts)).is_equal([2, 5, 0])
	var lines: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = PackedStringArray(["Spot check"])
	for step: ScoreStep in inspected.steps:
		if step.source_kind == ScoreStep.SourceKind.INSPECTION:
			lines.append(ReceiptView.source_text(step, PackedStringArray(), names))
	assert_array(Array(lines)).is_equal(["Spot check: slot 3 pays €0"])


## v0.69's day events: each file's tone and the numbers it changes (the limits' fields; every
## other limit field stays 0), as the plan lists them.
func test_the_day_events_match_the_plan() -> void:
	# id: [boon, extra_slots, extra_redraws, hand_size_delta, quota_percent, rules]
	var cases: Dictionary = {
		"spot_check": [false, 0, 0, 0, 0, 1],
		"short_belt": [false, -1, 0, 0, 0, 0],
		"till_jam": [false, 0, -1, 0, 0, 0],
		"small_baskets": [false, 0, 0, -1, 0, 0],
		"rush_hour": [false, 0, 0, 0, 10, 0],
		"late_delivery": [false, 0, 0, 0, 0, 1],
		"quiet_morning": [true, 0, 0, 0, -10, 0],
		"extra_till": [true, 1, 0, 0, 0, 0],
		"regulars_day": [true, 0, 1, 0, 0, 0],
		"big_trolleys": [true, 0, 0, 1, 0, 0],
		"free_samples": [true, 0, 0, 0, 0, 1],
		"happy_hour": [true, 0, 0, 0, 0, 1],
	}
	for id: String in cases:
		var expected: Array = cases[id]
		var event: InspectionDefinition = load("res://data/inspections/%s.tres" % id)
		var got: Array = [
			event.is_boon(),
			event.extra_slots,
			event.extra_redraws,
			event.hand_size_delta,
			event.quota_percent,
			event.rules.size(),
		]
		assert_array(got).override_failure_message(id).is_equal(expected)
		assert_str(event.chip_text).override_failure_message(id).is_not_empty()
	var late: TagFlatBonusRule = (load(DAY % "late_delivery") as InspectionDefinition).rules[0]
	assert_array([late.tag, late.bonus]).is_equal(["Dairy", -2])
	var samples: NthProductMultiplierRule = (
		(load(DAY % "free_samples") as InspectionDefinition).rules[0]
	)
	assert_array([samples.product_number, samples.factor]).is_equal([1, 2])
	var happy: LastCardBonusRule = (load(DAY % "happy_hour") as InspectionDefinition).rules[0]
	assert_int(happy.bonus).is_equal(3)


## The boons' rules on live cards: Free samples doubles the 1st product, Happy hour adds €3 to
## the last card, Late delivery takes €2 off a Dairy product.
func test_the_live_day_event_rules_score() -> void:
	var no_upgrades: Array[UpgradeDefinition] = []
	var row: Array[CardInstance] = _row(["banana", "bread", "milk"])
	var plain: ScoreResult = Scoring.score(row, no_upgrades)
	for case: Array in [["free_samples", 0, 2], ["happy_hour", 2, 3], ["late_delivery", 2, -2]]:
		var events: Array[InspectionDefinition] = [load(DAY % case[0])]
		var result: ScoreResult = Scoring.score(row, no_upgrades, events)
		var slot: int = case[1]
		var expected: int = plain.payouts[slot]
		expected = expected * 2 if case[0] == "free_samples" else expected + int(case[2])
		assert_int(result.payouts[slot]).override_failure_message(case[0]).is_equal(expected)


static func _row(ids: Array) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids:
		row.append(CardInstance.new(load("%s/%s.tres" % [CARDS_DIR, id]), row.size() + 1))
	return row
