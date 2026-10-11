extends GdUnitTestSuite
## The balance simulator's build:<id> player as revised in #42 (full build plan section 8,
## decided with the user): it drafts towards its build only while the measure is under
## min_count + BUILD_MARGIN, keeps the cards that hold the measure up at the deck limit, and
## takes the upgrade listing its build only within LISTED_UPGRADE_SHARE of the best offer.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"


## The build strategy (revised in #42) drafts towards its build only while the measure is under
## min_count + BUILD_MARGIN, and at the deck limit keeps the cards whose loss would lower it.
func test_build_strategy_aims_for_min_count_plus_a_margin() -> void:
	var dairy: BuildDefinition = _build("dairy", BuildDefinition.Measure.TAG, 2)
	var aim: int = dairy.min_count + SimPlayer.BUILD_MARGIN
	var deck: Array[CardDefinition] = _defs("banana,cheese,bread")
	assert_bool(SimPlayer.still_building(dairy, deck)).is_true()
	# Only the Cheese counts: losing it lowers the measure, losing the others doesn't.
	assert_array(SimPlayer.kept_for_build(dairy, deck)).is_equal([1])
	while dairy.count(deck) < aim:
		deck.append(_card("cheese"))
	assert_bool(SimPlayer.still_building(dairy, deck)).is_false()
	assert_int(SimPlayer.kept_for_build(dairy, deck).size()).is_equal(aim)
	# Over the aim, nothing is kept: the strategy drafts and lets go as greedy does.
	deck.append(_card("cheese"))
	assert_array(SimPlayer.kept_for_build(dairy, deck)).is_empty()
	# For copies, only the copies of the most common product count.
	var copies: BuildDefinition = _build("copies", BuildDefinition.Measure.COPIES, 3)
	assert_array(SimPlayer.kept_for_build(copies, _defs("banana,bread,banana"))).is_equal([0, 2])


## The build strategy takes the upgrade listing its build only when greedy values it at least
## LISTED_UPGRADE_SHARE of the best offered upgrade (#42).
func test_build_strategy_takes_its_upgrade_within_a_share_of_the_best() -> void:
	assert_bool(SimPlayer.prefers_listed(100.0, 100.0)).is_true()
	assert_bool(SimPlayer.prefers_listed(100.0 * SimPlayer.LISTED_UPGRADE_SHARE, 100.0)).is_true()
	assert_bool(SimPlayer.prefers_listed(80.0, 100.0)).is_false()


## Viability's formation check (#42, decided with the user): the runs whose final deck fits the
## build strategy's target build, whatever its main build.
func test_viability_counts_runs_whose_final_deck_fits_the_target() -> void:
	var builds: SimBuilds = (
		SimBuilds
		. new(
			[
				_build("dairy", BuildDefinition.Measure.TAG, 2),
				_build("copies", BuildDefinition.Measure.COPIES, 3),
			]
		)
	)
	assert_array(Array(builds.fitted(_defs("cheese,milk,banana")))).is_equal(["dairy"])
	assert_array(Array(builds.fitted(_defs("cheese,cheese,cheese")))).is_equal(["dairy", "copies"])
	assert_array(Array(builds.fitted(_defs("banana,bread")))).is_empty()
	var summary: SimSummary = SimSummary.new("build:dairy@sensible", PackedInt32Array([10]))
	for fitted: PackedStringArray in [PackedStringArray(["dairy", "copies"]), PackedStringArray()]:
		var record: SimRunRecord = SimRunRecord.new()
		record.main_build = "copies" if not fitted.is_empty() else SimBuilds.NO_BUILD
		record.fitted_builds = fitted
		summary.add(record)
	assert_str(summary.target_build()).is_equal("dairy")
	assert_int(summary.build_fits["dairy"]).is_equal(1)
	assert_str(summary.format()).contains(
		"Target build dairy fits the final deck: 1 of 2 runs (50.0%)"
	)
	var greedy: SimSummary = SimSummary.new("greedy@sensible", PackedInt32Array([10]))
	assert_str(greedy.target_build()).is_empty()
	assert_str(greedy.format()).not_contains("Target build")


static func _build(
	id: StringName, measure: BuildDefinition.Measure, min_count: int
) -> BuildDefinition:
	var build: BuildDefinition = BuildDefinition.new()
	build.id = id
	build.measure = measure
	build.tag = "Dairy" if measure == BuildDefinition.Measure.TAG else ""
	build.min_count = min_count
	return build


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [FIXTURE_DIR, id])


static func _defs(ids: String) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for id: String in ids.split(","):
		cards.append(_card(id))
	return cards
