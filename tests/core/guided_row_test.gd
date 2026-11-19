extends GdUnitTestSuite
## The guided shift 1's free planning (play test 1, 2026-11-15) on the live card data, with the
## guided deal (the 4 regulars, Yogurt, Cereal, Tea bags and Cheese from the Dairy and
## Breakfast boosters): shift 1's quota is 30€; the script's answer row
## (TutorialScript.answer: Banana, Yogurt, Banana, Eggs, Milk, Cereal, Cheese) pays 36€, over
## it; the same cards with Eggs last waste the Eggs and miss it, so the order is the lesson; and
## the two reactive hints fire on what the rules did (PlanHint.pick). A card or balance change that
## breaks the lesson fails here.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261114
## Shift 1's hand places (GuidedStartDefinition.hand).
const BANANA_1 := 0
const BANANA_2 := 1
const MILK := 2
const EGGS := 3
const YOGURT := 4
const CEREAL := 5
const TEA_BAGS := 6
const CHEESE := 7


func test_the_answer_reaches_the_quota_and_order_matters() -> void:
	var guide: GuidedStartDefinition = StartChoice.guided_start()
	var script: TutorialScript = TutorialScript.guided()
	var run: RunState = _shift_one(guide)
	var why: String = "guided shift 1"
	assert_int(run.quota()).override_failure_message(why).is_equal(run.balance.quotas[0])
	assert_int(run.quota()).override_failure_message(why).is_equal(30)
	var places: Array[CardInstance] = run.hand_places()
	var ids: Array[StringName] = []
	for card: CardInstance in places:
		ids.append(card.definition.id)
	assert_array(ids).override_failure_message(why).is_equal(script.hand)
	# The answer: 36, over the quota, its Eggs not WASTED; Tea bags stay in their basket.
	_lay(run, places, [BANANA_1, YOGURT, BANANA_2, EGGS, MILK, CEREAL, CHEESE])
	assert_array(_row_ids(run)).override_failure_message(why).is_equal(script.answer)
	var answer: ScoreResult = run.preview()
	assert_int(answer.total).override_failure_message(why).is_equal(36)
	assert_bool(PlanHint.wasted_at(answer, 3)).override_failure_message(why).is_false()
	assert_bool(run.can_place(places[TEA_BAGS])).override_failure_message(why).is_false()
	# The same seven with Eggs last: WASTED, under the quota.
	_lay(run, places, [BANANA_1, YOGURT, BANANA_2, MILK, CEREAL, CHEESE, EGGS])
	var wrong: ScoreResult = run.preview()
	assert_int(wrong.total).override_failure_message(why).is_less(run.quota())
	assert_bool(PlanHint.wasted_at(wrong, 6)).override_failure_message(why).is_true()


## The two hints (v1.40): the first rule that works pops COMBO over its item (Eggs' ×2 once a
## Food item follows it; Eggs alone waits, which is no mistake yet); a rule WASTED in a complete
## row pops WASTED over its item (Eggs last), never in a row still being built; a hint shown is
## never picked again.
func test_the_hints_fire_on_what_the_rules_did() -> void:
	var guide: GuidedStartDefinition = StartChoice.guided_start()
	var hints: Array[PlanHint] = TutorialScript.guided().hints
	var run: RunState = _shift_one(guide)
	var places: Array[CardInstance] = run.hand_places()
	var shown: Array[StringName] = []
	_place(run, places[EGGS], 0)
	assert_bool(PlanHint.wasted_at(run.preview(), 0)).is_true()
	assert_str(String(_pick(run, hints, places[EGGS], shown))).is_empty()
	_place(run, places[YOGURT], 1)
	var fired: PlanHint.Pick = PlanHint.pick(
		hints, run.row, run.preview(), places[YOGURT], false, shown
	)
	assert_str(String(fired.hint.id)).is_equal("combo")
	assert_int(fired.slot).is_equal(0)  # Over Eggs: the rule that works is theirs.
	shown.append(fired.hint.id)
	_place(run, places[BANANA_1], 2)
	assert_str(String(_pick(run, hints, places[BANANA_1], shown))).is_empty()
	# The same seven as the answer with Eggs last: the row is complete, the Eggs WASTED.
	_lay(run, places, [BANANA_1, YOGURT, BANANA_2, MILK, CEREAL, CHEESE, EGGS])
	var wasted: PlanHint.Pick = PlanHint.pick(
		hints, run.row, run.preview(), places[EGGS], true, shown
	)
	assert_str(String(wasted.hint.id)).is_equal("wasted")
	assert_int(wasted.slot).is_equal(6)
	shown.append(wasted.hint.id)
	assert_str(String(_pick(run, hints, places[EGGS], shown))).is_empty()
	assert_array(shown).is_equal([&"combo", &"wasted"])


## The hint PlanHint.pick finds after `placed` (its id, added to `shown`; &"" for none); the row
## is complete when it is full.
static func _pick(
	run: RunState, hints: Array[PlanHint], placed: CardInstance, shown: Array[StringName]
) -> StringName:
	var complete: bool = run.row.size() >= RowCapacity.card_limit(run.limits)
	var found: PlanHint.Pick = PlanHint.pick(hints, run.row, run.preview(), placed, complete, shown)
	if found == null:
		return &""
	shown.append(found.hint.id)
	return found.hint.id


## Empties the row, then lays `order` (hand places) left to right.
func _lay(run: RunState, places: Array[CardInstance], order: Array[int]) -> void:
	for card: CardInstance in run.row.duplicate():
		run.remove(card)
	for slot: int in order.size():
		_place(run, places[order[slot]], slot)


static func _row_ids(run: RunState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in run.row:
		ids.append(card.definition.id)
	return ids


## Shift 1 of a guided-deal run, its store opened and the fixed hand dealt.
static func _shift_one(guide: GuidedStartDefinition) -> RunState:
	var profile: ProfileState = ProfileState.new()
	var run: RunState = StartSetupRules.setup_run(
		SEED,
		Kit.balance(),
		guide.recipe,
		profile,
		EventLogService.derived_stream(SEED, EventLogService.STOCK_AISLES_STREAM)
	)
	StartSetupRules.deal_fixed(run, profile, guide)
	run.guided = true
	Kit.open_all(run)
	run.open_store()
	run.kept = guide.hand_ids(run.deck.cards)
	run.start_shift()
	return run


func _place(run: RunState, card: CardInstance, slot: int) -> void:
	(
		assert_bool(run.place(card, slot))
		. override_failure_message(String(card.definition.id))
		. is_true()
	)
