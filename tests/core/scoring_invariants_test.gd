extends GdUnitTestSuite
## Invariants of Scoring.score() from core/AGENTS.md: pure and deterministic, definitions never
## changed, and every value change appears as a step that the receipt can replay.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const SAMPLE_ROWS := [
	"eggs,bread,cheese,banana,banana,repeat",
	"breakfast_sticker,banana,multipack,coffee,bread",
	"coffee,breakfast_sticker,soup,frozen_peas",
	"eggs,soup,frozen_peas,bread",
	"bread,multipack,bread,multipack,bread",
	"banana,bundle,bundle,banana",
	"bread,final_markdown",
]


func test_empty_row_scores_zero() -> void:
	var result: ScoreResult = Scoring.score([])
	assert_int(result.total).is_equal(0)
	assert_array(result.steps).is_empty()


func test_same_row_gives_same_result() -> void:
	for ids: String in SAMPLE_ROWS:
		var first: Array = _steps_as_data(Scoring.score(_row(ids)))
		var second: Array = _steps_as_data(Scoring.score(_row(ids)))
		assert_array(second).override_failure_message(ids).is_equal(first)


func test_scoring_never_changes_definitions() -> void:
	var banana: CardDefinition = load("%s/banana.tres" % FIXTURE_DIR)
	var tags_before: PackedStringArray = banana.tags.duplicate()
	var rules_before: int = banana.rules.size()
	Scoring.score(_row("breakfast_sticker,banana,multipack,banana"))
	assert_array(Array(banana.tags)).is_equal(Array(tags_before))
	assert_int(banana.rules.size()).is_equal(rules_before)


func test_payout_steps_add_up_to_total() -> void:
	for ids: String in SAMPLE_ROWS:
		var result: ScoreResult = Scoring.score(_row(ids))
		var sum: int = 0
		for step: ScoreStep in result.steps:
			if step.step_type == ScoreStep.StepType.PAYOUT:
				sum += step.value
		assert_int(sum).override_failure_message(ids).is_equal(result.total)
		assert_int(result.steps[-1].subtotal).override_failure_message(ids).is_equal(result.total)


## Replaying the value steps of each slot must reproduce its payout, so the receipt and the
## count-up can be driven from the steps alone.
func test_steps_replay_to_each_payout() -> void:
	for ids: String in SAMPLE_ROWS:
		var result: ScoreResult = Scoring.score(_row(ids))
		var running: Dictionary = {}
		for step: ScoreStep in result.steps:
			match step.step_type:
				ScoreStep.StepType.BASE:
					running[step.slot] = step.value
				ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
					running[step.slot] = int(running[step.slot]) + step.value
				ScoreStep.StepType.MULTIPLIER:
					running[step.slot] = int(running[step.slot]) * step.value
				ScoreStep.StepType.PAYOUT_OVERRIDE:
					running[step.slot] = step.value
				ScoreStep.StepType.PAYOUT:
					(
						assert_int(int(running[step.slot]))
						. override_failure_message("%s slot %d" % [ids, step.slot])
						. is_equal(result.payouts[step.slot])
					)
				ScoreStep.StepType.EFFECT_ARMED, ScoreStep.StepType.WASTED:
					pass  # Value unchanged: checked by value_after below.
				ScoreStep.StepType.TAG_ADDED, ScoreStep.StepType.LINKED:
					pass  # Context only: no running value.
			var context_only: Array = [ScoreStep.StepType.TAG_ADDED, ScoreStep.StepType.LINKED]
			if context_only.has(step.step_type):
				continue
			# A fizzle before the card is scanned (context pass) carries 0.
			assert_int(step.value_after).is_equal(int(running.get(step.slot, 0)))


## The subtotal changes only on PAYOUT steps, so a count-up can tick it from the steps alone.
func test_subtotal_changes_only_on_payouts() -> void:
	for ids: String in SAMPLE_ROWS:
		var previous: int = 0
		for step: ScoreStep in Scoring.score(_row(ids)).steps:
			if step.step_type == ScoreStep.StepType.PAYOUT:
				assert_int(step.subtotal).is_equal(previous + step.value)
			else:
				assert_int(step.subtotal).override_failure_message(ids).is_equal(previous)
			previous = step.subtotal


func test_context_pass_steps_are_recorded() -> void:
	var sticker: ScoreResult = Scoring.score(_row("breakfast_sticker,banana,milk"))
	var tag_step: ScoreStep = sticker.steps[0]
	assert_int(tag_step.step_type).is_equal(ScoreStep.StepType.TAG_ADDED)
	assert_int(tag_step.slot).is_equal(1)
	assert_int(tag_step.source_slot).is_equal(0)
	assert_str(tag_step.tag).is_equal("Breakfast")
	assert_bool(sticker.tags[1].has("Breakfast")).is_true()

	var bundle: ScoreResult = Scoring.score(_row("banana,bundle,bundle,banana"))
	var link_step: ScoreStep = bundle.steps[0]
	assert_int(link_step.step_type).is_equal(ScoreStep.StepType.LINKED)
	assert_int(link_step.slot).is_equal(0)
	assert_int(link_step.linked_slot).is_equal(3)
	assert_int(link_step.source_slot).is_equal(1)


func test_effect_steps_name_their_source() -> void:
	var result: ScoreResult = Scoring.score(_row("eggs,coffee,bread"))
	var found_coffee: bool = false
	var found_eggs: bool = false
	for step: ScoreStep in result.steps:
		if step.slot == 2 and step.step_type == ScoreStep.StepType.FLAT:
			found_coffee = step.source_slot == 1
		if step.slot == 2 and step.step_type == ScoreStep.StepType.MULTIPLIER:
			found_eggs = step.source_slot == 0
	assert_bool(found_coffee).is_true()
	assert_bool(found_eggs).is_true()


func test_wasted_sticker_adds_no_tag() -> void:
	var result: ScoreResult = Scoring.score(_row("breakfast_sticker,bread,milk"))
	assert_int(Array(result.tags[1]).count("Breakfast")).is_equal(1)
	for step: ScoreStep in result.steps:
		assert_int(step.step_type).is_not_equal(ScoreStep.StepType.TAG_ADDED)


## Scoring tells coupons apart by `kind`, not by tags: a coupon that carries product tags
## still never receives effects, and Milk doesn't count it.
func test_coupons_never_receive_effects_even_with_tags() -> void:
	var tagged_coupon: CardDefinition = CardDefinition.new()
	tagged_coupon.id = &"tagged_coupon"
	tagged_coupon.display_name = "Tagged coupon"
	tagged_coupon.kind = CardDefinition.Kind.COUPON
	tagged_coupon.tags = PackedStringArray(["Food", "Breakfast"])
	var row: Array[CardInstance] = _row("eggs,coffee")
	row.append(CardInstance.new(tagged_coupon, 90))
	row.append_array(_row("bread,milk"))
	var result: ScoreResult = Scoring.score(row)
	assert_array(Array(result.payouts)).is_equal([1, 2, 0, 12, 18])


static func _steps_as_data(result: ScoreResult) -> Array:
	var data: Array = []
	for step: ScoreStep in result.steps:
		data.append(step.to_dictionary())
	data.append(result.total)
	return data


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
