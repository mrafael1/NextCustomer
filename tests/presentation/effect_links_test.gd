extends GdUnitTestSuite
## EffectLinks (#71): the one armed-effect matcher gives the same landings, armed_from and pip
## fizzles as the count-up's beat-based matching did before #71 (re-implemented here as it was),
## and the same token wording, on every golden row, the #60 reference row and its prefixes, and
## the hand-built rows of count_up_plan_test. Pure data: no saves, no event log, no Node.

const GoldenRows := preload("res://tests/ui/scan_popup_golden_rows_test.gd")
const PlanTest := preload("res://tests/presentation/count_up_plan_test.gd")
const TUNING := "res://data/balance/count_up.tres"


func test_landings_match_the_count_ups_old_beat_matching() -> void:
	var landed: int = 0
	for row: Array in _rows():
		var steps: Array[ScoreStep] = []
		steps.assign(row)
		var plan: CountUpPlan = _plan(steps)
		var old: Dictionary = _old_link_armed(plan, steps)
		var old_from: PackedInt32Array = old["from"]
		var old_targets: Array[PackedInt32Array] = old["targets"]
		for index: int in range(plan.beats.size()):
			var beat: CountUpBeat = plan.beats[index]
			var at: String = "%s, beat %d" % [_describe(steps), index]
			assert_int(beat.armed_from).override_failure_message(at).is_equal(old_from[index])
			assert_array(Array(beat.targets)).override_failure_message(at).is_equal(
				Array(old_targets[index])
			)
			if beat.armed_from != -1:
				landed += 1
		# Landings are never the 2nd step of a merged plain beat.
		var landings: PackedInt32Array = EffectLinks.armed_landings(steps)
		for beat: CountUpBeat in plan.beats:
			for position: int in range(1, beat.steps.size()):
				assert_int(landings[beat.steps[position]]).is_equal(-1)
	# The rows do land armed effects: the check is not empty.
	assert_int(landed).is_greater(20)


func test_armed_of_waste_matches_the_old_pip_spend_walk() -> void:
	var spent: int = 0
	for row: Array in _rows():
		var steps: Array[ScoreStep] = []
		steps.assign(row)
		var plan: CountUpPlan = _plan(steps)
		for index: int in range(plan.beats.size()):
			var beat: CountUpBeat = plan.beats[index]
			if beat.kind != CountUpBeat.Kind.FIZZLE:
				continue
			var old: int = _old_spend(plan, steps, index)
			var armed_step: int = EffectLinks.armed_of_waste(steps, beat.steps[0])
			var found: int = -1
			for armed: int in range(plan.beats.size()):
				if armed_step != -1 and plan.beats[armed].steps[0] == armed_step:
					found = armed
			var at: String = "%s, beat %d" % [_describe(steps), index]
			assert_int(found).override_failure_message(at).is_equal(old)
			if old != -1:
				spent += 1
	assert_int(spent).is_greater(5)


func test_token_text_keeps_the_count_ups_wording() -> void:
	var checked: int = 0
	for row: Array in _rows():
		var steps: Array[ScoreStep] = []
		steps.assign(row)
		for step: ScoreStep in steps:
			if step.step_type == ScoreStep.StepType.MULTIPLIER:
				assert_str(EffectLinks.token_text(step)).is_equal("×%d" % step.value)
				checked += 1
			elif step.step_type == ScoreStep.StepType.FLAT:
				assert_str(EffectLinks.token_text(step)).is_equal("+%d" % step.value)
				checked += 1
	assert_int(checked).is_greater(50)


func test_the_reference_row_lands_eggs_once_and_multipack_three_times() -> void:
	var steps: Array[ScoreStep] = PlanTest._full_steps()
	var landings: PackedInt32Array = EffectLinks.armed_landings(steps)
	var by_armed: Dictionary[int, PackedInt32Array] = {}
	for index: int in range(landings.size()):
		if landings[index] == -1:
			continue
		var slots: PackedInt32Array = by_armed.get(landings[index], PackedInt32Array())
		slots.append(steps[index].slot)
		by_armed[landings[index]] = slots
	var found: Array = []
	for armed: int in by_armed:
		assert_int(steps[armed].step_type).is_equal(ScoreStep.StepType.EFFECT_ARMED)
		found.append([steps[armed].slot, Array(by_armed[armed])])
	found.sort()
	assert_array(found).is_equal([[0, [1]], [3, [4, 5, 6]]])
	# The key is the arming card and the text.
	var first_armed: int = int(by_armed.keys().min())
	assert_str(EffectLinks.armed_key(steps[first_armed])).is_equal("0|Eggs ×2")


## Every golden row on its fixture, the reference row and its prefixes on live data with
## Coupon engine, Slot engine and a Spot check, and the hand-built rows.
static func _rows() -> Array[Array]:
	var rows: Array[Array] = []
	for fixture: String in GoldenRows.GOLDEN_ROWS:
		for ids: String in GoldenRows.GOLDEN_ROWS[fixture]:
			rows.append(Scoring.score(GoldenRows._fixture_row(fixture, ids)).steps)
	var full: PackedStringArray = PlanTest.FULL_ROW.split(",")
	for length: int in range(1, full.size() + 1):
		rows.append(PlanTest._data_steps(",".join(full.slice(0, length))))
	rows.append(PlanTest._long_steps())
	rows.append(_taken_over())
	return rows


## A later arming of the same effect takes over the landings after it; a COPY and a stamp from
## another slot are no landings; each Egg fizzles its own pip.
static func _taken_over() -> Array[ScoreStep]:
	return [
		PlanTest._step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.BASE, 1, 1, 5, 0, "Bread"),
		PlanTest._step(ScoreStep.StepType.MULTIPLIER, 1, 0, 2, 0, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.PAYOUT, 1, 1, 10, 10, "Bread"),
		PlanTest._step(ScoreStep.StepType.EFFECT_ARMED, 2, 0, 2, 10, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.WASTED, 0, 2, 0, 10, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.BASE, 3, 3, 5, 10, "Bread"),
		PlanTest._step(ScoreStep.StepType.MULTIPLIER, 3, 0, 2, 10, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.FLAT, 3, 0, 3, 10, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.COPY, 3, 0, 3, 10, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.MULTIPLIER, 3, 2, 2, 10, "Eggs ×2"),
		PlanTest._step(ScoreStep.StepType.PAYOUT, 3, 3, 26, 36, "Bread"),
		PlanTest._step(ScoreStep.StepType.WASTED, 2, 2, 0, 36, "Eggs ×2"),
		PlanTest._step(
			ScoreStep.StepType.WASTED, 3, 3, 0, 36, "Eggs ×2", ScoreStep.SourceKind.UPGRADE
		),
	]


static func _plan(steps: Array[ScoreStep]) -> CountUpPlan:
	return CountUpPlan.build(steps, 40, CountUpContext.new(), load(TUNING))


## CountUpPlan._link_armed as it was before #71, on the plan's beats: {"from": armed_from per
## beat, "targets": targets per beat}.
static func _old_link_armed(plan: CountUpPlan, steps: Array[ScoreStep]) -> Dictionary:
	var from: PackedInt32Array = PackedInt32Array()
	var targets: Array[PackedInt32Array] = []
	for _beat: CountUpBeat in plan.beats:
		from.append(-1)
		targets.append(PackedInt32Array())
	var armed_by_key: Dictionary[String, int] = {}
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		var step: ScoreStep = steps[beat.steps[0]]
		var key: String = "%d|%s" % [step.source_slot, step.text]
		if beat.kind == CountUpBeat.Kind.ARMED:
			armed_by_key[key] = index
			continue
		var lands: bool = (
			step.source_kind == ScoreStep.SourceKind.CARD
			and (
				step.step_type == ScoreStep.StepType.FLAT
				or step.step_type == ScoreStep.StepType.MULTIPLIER
			)
			and armed_by_key.has(key)
		)
		if lands:
			from[index] = armed_by_key[key]
			targets[armed_by_key[key]].append(index)
	return {"from": from, "targets": targets}


## EffectTokens.spend's walk as it was before #71: the ARMED beat fizzle beat `index` greys, or
## -1.
static func _old_spend(plan: CountUpPlan, steps: Array[ScoreStep], index: int) -> int:
	var step: ScoreStep = steps[plan.beats[index].steps[0]]
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return -1
	for armed: int in range(index - 1, -1, -1):
		var beat: CountUpBeat = plan.beats[armed]
		var armed_step: ScoreStep = steps[beat.steps[0]]
		if (
			beat.kind != CountUpBeat.Kind.ARMED
			or armed_step.slot != step.slot
			or armed_step.text != step.text
		):
			continue
		return armed
	return -1


static func _describe(steps: Array[ScoreStep]) -> String:
	var names: PackedStringArray = PackedStringArray()
	for step: ScoreStep in steps:
		if step.step_type == ScoreStep.StepType.BASE:
			names.append(step.text)
	return ",".join(names)
