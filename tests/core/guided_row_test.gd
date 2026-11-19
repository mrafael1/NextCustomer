extends GdUnitTestSuite
## The guided shift 1's free planning (play test 1, 2026-11-15) on the live card data, with the
## guided deal (the 4 regulars, Yogurt, Cereal, Tea bags and Cheese from the Dairy and
## Breakfast boosters): shift 1's quota is 30€; the script's answer row
## (TutorialScript.answer: Banana, Yogurt, Banana, Eggs, Milk, Cereal, Cheese) pays 36€, over
## it; the same cards with Eggs last waste the Eggs and miss it, so the order is the lesson; and
## the reactive hints fire on what the rules did (PlanHint.pick). A card or balance change that
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


## The hints: Eggs placed first introduce themselves; alone at the end they are WASTED (once
## introduced); a Banana beside Yogurt fires Yogurt's PAIR; the CHAIN fires on the second Banana;
## the quota hint waits for the row to reach it, then comes first, and the hint left behind it
## shows next with no move; a hint shown is never picked again.
func test_the_hints_fire_on_what_the_rules_did() -> void:
	var guide: GuidedStartDefinition = StartChoice.guided_start()
	var hints: Array[PlanHint] = TutorialScript.guided().hints
	var run: RunState = _shift_one(guide)
	var places: Array[CardInstance] = run.hand_places()
	var shown: Array[StringName] = []
	_place(run, places[EGGS], 0)
	assert_str(String(_pick(run, hints, places[EGGS], shown))).is_equal("eggs_placed")
	assert_str(String(_pick(run, hints, places[EGGS], shown))).is_equal("eggs_wasted")
	_place(run, places[YOGURT], 1)
	assert_str(String(_pick(run, hints, places[YOGURT], shown))).is_equal("eggs_fired")
	assert_str(String(_pick(run, hints, places[YOGURT], shown))).is_equal("yogurt_placed")
	_place(run, places[BANANA_1], 2)
	assert_str(String(_pick(run, hints, places[BANANA_1], shown))).is_equal("yogurt_fired")
	_place(run, places[BANANA_2], 3)
	assert_str(String(_pick(run, hints, places[BANANA_2], shown))).is_equal("banana_fired")
	assert_bool(shown.has(&"quota")).is_false()
	_place(run, places[MILK], 4)
	_place(run, places[CEREAL], 5)
	# The row reaches the quota: its hint first, Cereal's PAIR waits behind it (placed: none).
	assert_int(run.preview().total).is_greater_equal(run.quota())
	assert_str(String(_pick(run, hints, places[CEREAL], shown))).is_equal("quota")
	assert_str(String(_pick(run, hints, null, shown))).is_equal("cereal_fired")
	assert_array(shown).contains_same([&"eggs_placed", &"eggs_wasted", &"eggs_fired"])
	var counts: Dictionary = {}
	for hint_id: StringName in shown:
		counts[hint_id] = int(counts.get(hint_id, 0)) + 1
	for hint_id: StringName in counts:
		assert_int(int(counts[hint_id])).override_failure_message(String(hint_id)).is_equal(1)


## The medals: the best row (Tea bags ×4 on Milk) reaches SILVER, whose hint pops over the
## medal case in place of QUOTA's (the highest level reached is told, never a lower one after:
## the full row's hint comes next);
## a redraw's hint points at REDRAW, once.
func test_the_medal_and_redraw_hints() -> void:
	var guide: GuidedStartDefinition = StartChoice.guided_start()
	var hints: Array[PlanHint] = TutorialScript.guided().hints
	var run: RunState = _shift_one(guide)
	var places: Array[CardInstance] = run.hand_places()
	var shown: Array[StringName] = []
	for hint: PlanHint in hints:
		if not hint.card.is_empty():
			shown.append(hint.id)
	_lay(run, places, [YOGURT, CEREAL, EGGS, TEA_BAGS, MILK, BANANA_1, BANANA_2])
	var machine: MachineDefinition = run.balance.machine
	assert_int(run.preview().total).is_greater_equal(run.quota() * machine.overtime_ticket_laps)
	assert_int(run.preview().total).is_less(run.quota() * machine.overtime_premium_laps)
	assert_str(String(_pick(run, hints, places[BANANA_2], shown))).is_equal("silver")
	assert_str(String(_pick(run, hints, places[BANANA_2], shown))).is_equal("row_full")
	assert_bool(shown.has(&"quota")).is_false()
	var redrawn: PlanHint.Pick = PlanHint.pick_redrawn(hints, shown)
	assert_str(String(redrawn.hint.id)).is_equal("redrawn")
	assert_str(String(redrawn.anchor)).is_equal(String(TutorialAnchors.REDRAW))
	shown.append(redrawn.hint.id)
	assert_object(PlanHint.pick_redrawn(hints, shown)).is_null()


## The hint PlanHint.pick finds after `placed` (its id, added to `shown`; &"" for none).
static func _pick(
	run: RunState, hints: Array[PlanHint], placed: CardInstance, shown: Array[StringName]
) -> StringName:
	var full: bool = run.row.size() >= RowCapacity.card_limit(run.limits)
	var machine: MachineDefinition = run.balance.machine
	var quota: int = run.quota()
	var totals: Array[int] = [
		quota, quota * machine.overtime_ticket_laps, quota * machine.overtime_premium_laps
	]
	var found: PlanHint.Pick = PlanHint.pick(
		hints, run.row, run.preview(), placed, totals, full, shown
	)
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
