extends GdUnitTestSuite
## EffectGraph and EffectLink (#71): on the 66 golden rows (each on its frozen fixture) and the
## #60 reference row (live data, Coupon engine, Slot engine and a Spot check), every FLAT,
## MULTIPLIER, COPY, PAYOUT_OVERRIDE and WASTED step gives exactly one link on its slot, every
## EFFECT_ARMED step one pip; every cause resolves to a slot of the row or an index of the
## upgrades or inspections; armed links follow EffectLinks; the graph covers
## EffectChip's rule; and building it changes no total or payout. Pure data: no saves, no event
## log, no Node.

const GoldenRows := preload("res://tests/ui/scan_popup_golden_rows_test.gd")
const PlanTest := preload("res://tests/presentation/count_up_plan_test.gd")
const SHOWN: Array[ScoreStep.StepType] = [
	ScoreStep.StepType.FLAT,
	ScoreStep.StepType.MULTIPLIER,
	ScoreStep.StepType.COPY,
	ScoreStep.StepType.PAYOUT_OVERRIDE,
	ScoreStep.StepType.WASTED,
	ScoreStep.StepType.EFFECT_ARMED,
]


func test_every_golden_row_and_the_reference_row_link_each_effect_step_once() -> void:
	var failures: PackedStringArray = PackedStringArray()
	var rows: int = 0
	for fixture: String in GoldenRows.GOLDEN_ROWS:
		for ids: String in GoldenRows.GOLDEN_ROWS[fixture]:
			var row: Array[CardInstance] = GoldenRows._fixture_row(fixture, ids)
			failures.append_array(_check(Scoring.score(row), row.size(), 0, 0, ids))
			rows += 1
	assert_int(rows).is_equal(66)
	failures.append_array(_check(_full_result(), 7, 2, 1, PlanTest.FULL_ROW))
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


func test_the_reference_row_links_its_causes_and_targets() -> void:
	var graph: EffectGraph = EffectGraph.build(_full_result())
	# Eggs (slot 0) arms ×2 and lands on Bread; Multipack (slot 3) arms ×3 and lands on the
	# three Milks after it.
	var eggs: Array[EffectLink] = graph.pips(0)
	assert_int(eggs.size()).is_equal(1)
	assert_array(Array(eggs[0].landing_slots)).is_equal([1])
	assert_str(eggs[0].token).is_equal("×2")
	assert_bool(eggs[0].fizzled).is_false()
	var multipack: Array[EffectLink] = graph.pips(3)
	assert_int(multipack.size()).is_equal(1)
	assert_array(Array(multipack[0].landing_slots)).is_equal([4, 5, 6])
	assert_str(multipack[0].token).is_equal("×3")
	# Bread gets Eggs' stamp.
	var bread: Array[EffectLink] = graph.incoming(1)
	assert_int(bread.size()).is_equal(1)
	assert_int(bread[0].kind).is_equal(EffectLink.Kind.STAMP)
	assert_int(bread[0].cause_slot).is_equal(0)
	assert_bool(bread[0].own).is_false()
	assert_int(bread[0].armed_step).is_equal(eggs[0].step_index)
	# The Spot check denies the 3rd product, after its own bonus.
	var milk: Array[EffectLink] = graph.incoming(2)
	assert_array(_kinds(milk)).is_equal([EffectLink.Kind.BONUS, EffectLink.Kind.DENIED])
	assert_bool(milk[0].own).is_true()
	assert_int(milk[1].cause_kind).is_equal(ScoreStep.SourceKind.INSPECTION)
	assert_int(milk[1].cause_index).is_equal(0)
	assert_str(milk[1].token).is_equal("€0")
	assert_int(graph.by_inspection(0).size()).is_equal(1)
	assert_bool(graph.by_inspection(0)[0] == milk[1]).is_true()
	# Coupon engine fizzles on Multipack; Slot engine stamps the 6th product (slot 6).
	var coupon_engine: Array[EffectLink] = graph.by_upgrade(0)
	assert_int(coupon_engine.size()).is_equal(1)
	assert_int(coupon_engine[0].kind).is_equal(EffectLink.Kind.FIZZLE)
	assert_int(coupon_engine[0].target_slot).is_equal(3)
	assert_int(coupon_engine[0].armed_step).is_equal(-1)
	assert_str(coupon_engine[0].reason).is_not_empty()
	var slot_engine: Array[EffectLink] = graph.by_upgrade(1)
	assert_int(slot_engine.size()).is_equal(1)
	assert_int(slot_engine[0].kind).is_equal(EffectLink.Kind.STAMP)
	assert_int(slot_engine[0].target_slot).is_equal(6)
	assert_int(slot_engine[0].cause_slot).is_equal(-1)
	assert_str(slot_engine[0].token).is_equal("×2")
	assert_array(_kinds(graph.incoming(6))).is_equal(
		[EffectLink.Kind.BONUS, EffectLink.Kind.STAMP, EffectLink.Kind.STAMP]
	)
	# Relations: Multipack gives to the Milks after it; a Milk gets from Multipack.
	assert_int(graph.outgoing(3).size()).is_equal(3)
	assert_array(Array(graph.related_slots(3))).is_equal([4, 5, 6])
	assert_array(Array(graph.related_slots(5))).is_equal([3])
	assert_array(Array(graph.related_slots(0))).is_equal([1])
	assert_array(Array(graph.related_slots(2))).is_empty()


func test_copies_soups_and_resets_name_their_causes() -> void:
	var fixture: String = "res://tests/fixtures/cards_v0_4"
	# Repeat copies the Banana before it.
	var copy: EffectGraph = EffectGraph.build(
		Scoring.score(GoldenRows._fixture_row(fixture, "banana,repeat,banana"))
	)
	var repeat: Array[EffectLink] = copy.incoming(1)
	assert_int(repeat.size()).is_equal(1)
	assert_int(repeat[0].kind).is_equal(EffectLink.Kind.COPY)
	assert_int(repeat[0].cause_slot).is_equal(0)
	assert_bool(repeat[0].own).is_false()
	assert_str(repeat[0].token).is_equal("=€%d" % repeat[0].value)
	assert_array(Array(copy.related_slots(0))).is_equal([1])
	# A Soup beside Frozen denies itself: no neighbour is guessed.
	var soup: EffectGraph = EffectGraph.build(
		Scoring.score(GoldenRows._fixture_row(fixture, "soup,frozen_peas"))
	)
	var denied: Array[EffectLink] = []
	for link: EffectLink in soup.incoming(0):
		if link.kind == EffectLink.Kind.DENIED:
			denied.append(link)
	assert_int(denied.size()).is_equal(1)
	assert_int(denied[0].cause_slot).is_equal(0)
	assert_bool(denied[0].own).is_true()
	# The first Eggs lands on the second, which then resets its last charge: the first Eggs'
	# fizzle is caused by the second, and its pip has fizzled.
	var resets: EffectGraph = EffectGraph.build(
		Scoring.score(GoldenRows._fixture_row(fixture, "eggs,eggs,bread,bread,bread"))
	)
	var fizzles: Array[EffectLink] = []
	for link: EffectLink in resets.incoming(0):
		if link.kind == EffectLink.Kind.FIZZLE:
			fizzles.append(link)
	assert_int(fizzles.size()).is_equal(1)
	assert_int(fizzles[0].cause_slot).is_equal(1)
	assert_int(fizzles[0].armed_step).is_equal(resets.pips(0)[0].step_index)
	assert_bool(resets.pips(0)[0].fizzled).is_true()
	assert_array(Array(resets.pips(0)[0].landing_slots)).is_equal([1])
	assert_array(Array(resets.pips(1)[0].landing_slots)).is_equal([2, 3])
	assert_bool(resets.pips(1)[0].fizzled).is_false()


func test_an_empty_or_missing_result_has_no_links() -> void:
	var empty: Array[CardInstance] = []
	assert_array(EffectGraph.build(Scoring.score(empty)).links).is_empty()
	assert_array(EffectGraph.build(null).links).is_empty()


## The checks on one scored row of `size` cards with `upgrades` upgrades and `inspections`
## inspections; returns the failures.
static func _check(
	result: ScoreResult, size: int, upgrades: int, inspections: int, where: String
) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	var total: int = result.total
	var payouts: Array = Array(result.payouts)
	var graph: EffectGraph = EffectGraph.build(result)
	var steps: Array[ScoreStep] = result.steps
	var landings: PackedInt32Array = EffectLinks.armed_landings(steps)
	var by_step: Dictionary[int, Array] = {}
	for link: EffectLink in graph.links:
		var found: Array = by_step.get(link.step_index, [])
		found.append(link)
		by_step[link.step_index] = found
	for index: int in range(steps.size()):
		var step: ScoreStep = steps[index]
		var at: String = (
			"%s, step %d (%s)" % [where, index, ScoreStep.StepType.keys()[step.step_type]]
		)
		var found: Array = by_step.get(index, [])
		if not SHOWN.has(step.step_type):
			if not found.is_empty():
				failures.append("%s: a link on a step that shows none" % at)
			continue
		if found.size() != 1:
			failures.append("%s: %d links" % [at, found.size()])
			continue
		var link: EffectLink = found[0]
		if link.target_slot != step.slot:
			failures.append("%s: on slot %d" % [at, link.target_slot])
		if EffectChip.qualifies(step) and link.kind == EffectLink.Kind.ARMED:
			failures.append("%s: a disc's step is a pip" % at)
		failures.append_array(_check_cause(link, step, size, upgrades, inspections, at))
		failures.append_array(_check_armed(link, steps, landings, at))
	if result.total != total or Array(result.payouts) != payouts:
		failures.append("%s: the result changed" % where)
	# A superset of EffectChip's rule: every step that marks an item has a link.
	for slot: int in range(size):
		for index: int in EffectChip.step_indices(result, slot):
			if not by_step.has(index):
				failures.append("%s, step %d: a disc's step has no link" % [where, index])
	return failures


static func _check_cause(
	link: EffectLink, step: ScoreStep, size: int, upgrades: int, inspections: int, at: String
) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	if link.cause_kind != step.source_kind:
		failures.append("%s: cause kind %d" % [at, link.cause_kind])
	match link.cause_kind:
		ScoreStep.SourceKind.CARD:
			var expected: int = step.source_slot
			if step.step_type == ScoreStep.StepType.COPY:
				expected = step.linked_slot
			if link.cause_slot != expected or link.cause_slot < 0 or link.cause_slot >= size:
				failures.append("%s: cause slot %d" % [at, link.cause_slot])
		ScoreStep.SourceKind.UPGRADE:
			if link.cause_index != step.source_index or link.cause_index >= upgrades:
				failures.append("%s: upgrade %d" % [at, link.cause_index])
		ScoreStep.SourceKind.INSPECTION:
			if link.cause_index != step.source_index or link.cause_index >= inspections:
				failures.append("%s: inspection %d" % [at, link.cause_index])
	if link.cause_kind != ScoreStep.SourceKind.CARD and link.cause_index < 0:
		failures.append("%s: no cause index" % at)
	return failures


static func _check_armed(
	link: EffectLink, steps: Array[ScoreStep], landings: PackedInt32Array, at: String
) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	match link.kind:
		EffectLink.Kind.BONUS, EffectLink.Kind.STAMP:
			if link.armed_step != landings[link.step_index]:
				failures.append("%s: lands from %d" % [at, link.armed_step])
		EffectLink.Kind.FIZZLE:
			if link.armed_step != EffectLinks.armed_of_waste(steps, link.step_index):
				failures.append("%s: fizzles %d" % [at, link.armed_step])
		EffectLink.Kind.ARMED:
			var expected: PackedInt32Array = PackedInt32Array()
			var slots: PackedInt32Array = PackedInt32Array()
			for index: int in range(landings.size()):
				if landings[index] == link.step_index:
					expected.append(index)
					slots.append(steps[index].slot)
			if link.landings != expected or link.landing_slots != slots:
				failures.append("%s: landings %s" % [at, link.landings])
			if not link.own:
				failures.append("%s: a pip off its arming card" % at)
		_:
			if link.armed_step != -1:
				failures.append("%s: armed step %d" % [at, link.armed_step])
	return failures


static func _full_result() -> ScoreResult:
	var upgrades: Array[UpgradeDefinition] = [
		load("res://data/upgrades/coupon_engine.tres"),
		load("res://data/upgrades/slot_engine.tres"),
	]
	var inspections: Array[InspectionDefinition] = [load("res://data/inspections/spot_check.tres")]
	return Scoring.score(PlanTest._row(PlanTest.FULL_ROW, PlanTest.CARDS), upgrades, inspections)


static func _kinds(links: Array[EffectLink]) -> Array:
	var kinds: Array = []
	for link: EffectLink in links:
		kinds.append(link.kind)
	return kinds
