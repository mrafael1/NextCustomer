extends GdUnitTestSuite
## Tests on the live data/inspections/ files (plan section 3.9). Unlike the fixture-based
## inspection tests, these expected values are updated when inspection numbers are tuned.

const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const CARDS_DIR := "res://data/cards"


func test_the_placeholder_inspection_matches_the_plan() -> void:
	var spot_check: InspectionDefinition = load(SPOT_CHECK)
	assert_str(String(spot_check.id)).is_equal("spot_check")
	assert_str(spot_check.display_name).is_equal("Spot check")
	assert_str(spot_check.notice_text).is_equal("The 3rd product pays €0")
	assert_int(spot_check.rules.size()).is_equal(1)
	var rule: NthProductZeroPayoutRule = spot_check.rules[0]
	assert_int(rule.product_number).is_equal(3)


func test_the_live_inspection_scores_the_plan_example() -> void:
	var inspections: Array[InspectionDefinition] = [load(SPOT_CHECK)]
	var no_upgrades: Array[UpgradeDefinition] = []
	# Banana 2, Bread 3, Milk 3 + 2 (Bread is Breakfast) = 5, paid 0 as the 3rd product.
	var row: Array[CardInstance] = _row(["banana", "bread", "milk"])
	assert_int(Scoring.score(row, no_upgrades).total).is_equal(10)
	var inspected: ScoreResult = Scoring.score(row, no_upgrades, inspections)
	assert_array(Array(inspected.payouts)).is_equal([2, 3, 0])
	var lines: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = PackedStringArray(["Spot check"])
	for step: ScoreStep in inspected.steps:
		if step.source_kind == ScoreStep.SourceKind.INSPECTION:
			lines.append(ReceiptView.source_text(step, PackedStringArray(), names))
	assert_array(Array(lines)).is_equal(["Spot check: the 3rd product pays €0"])


static func _row(ids: Array) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids:
		row.append(CardInstance.new(load("%s/%s.tres" % [CARDS_DIR, id]), row.size() + 1))
	return row
