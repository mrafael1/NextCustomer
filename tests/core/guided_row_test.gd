extends GdUnitTestSuite
## The guided shift 1's rows (the tutorial's G10-G21 lines, mock-up tutorial.html) scored through
## RunState.preview on the live card data, with the guided deal (Cold cases + Pantry boosters,
## Frozen peas the 8th card): Bread 5 → Cheese PAIR 13 → Eggs at the end WASTED 14 → Eggs first
## 19 (Bread ×2 pays 10) → the Banana CHAIN 25 (the second pays 4) → Milk 31 → Coffee 35 (each
## +2 from Eggs and Bread), over shift 1's 30€ quota with Frozen peas left in its basket. Every
## pack gives the same rows. A card or balance change that breaks a line's numbers fails here.

const Kit := preload("res://tests/core/start_setup_kit.gd")
const SEED := 20261114
## Shift 1's hand places (GuidedStartDefinition.hand).
const BANANA_1 := 0
const BANANA_2 := 1
const BREAD := 2
const CHEESE := 3
const EGGS := 4
const MILK := 5
const COFFEE := 6
const FROZEN_PEAS := 7


func test_the_guided_rows_pay_the_approved_totals() -> void:
	var guide: GuidedStartDefinition = StartChoice.guided_start()
	for pack_index: int in guide.recipe.starter_packs.size():
		var run: RunState = _shift_one(guide, pack_index)
		var places: Array[CardInstance] = run.hand_places()
		var why: String = "pack %d" % pack_index
		assert_int(run.quota()).override_failure_message(why).is_equal(run.balance.quotas[0])
		assert_int(run.quota()).override_failure_message(why).is_equal(30)
		# G10/G11: Bread has no rule, it pays its price.
		_place(run, places[BREAD], 0)
		assert_int(run.preview().total).override_failure_message(why).is_equal(5)
		# G12/G13: Cheese beside Bread is a PAIR: 3 + 5 = 8, the row 13.
		_place(run, places[CHEESE], 1)
		var pair: ScoreResult = run.preview()
		assert_int(pair.total).override_failure_message(why).is_equal(13)
		assert_int(pair.payouts[1]).override_failure_message(why).is_equal(8)
		# G14/G15: Eggs last: no Food item later, its rule is WASTED; the row 14.
		_place(run, places[EGGS], 2)
		var wrong: ScoreResult = run.preview()
		assert_int(wrong.total).override_failure_message(why).is_equal(14)
		assert_bool(_wasted(wrong, 2)).override_failure_message(why).is_true()
		# G16: Eggs first: Bread pays ×2 (10), the row 19, not 14.
		assert_bool(run.remove(places[EGGS])).is_true()
		_place(run, places[EGGS], 0)
		var right: ScoreResult = run.preview()
		assert_int(right.total).override_failure_message(why).is_equal(19)
		assert_int(right.payouts[1]).override_failure_message(why).is_equal(10)
		assert_bool(_wasted(right, 0)).override_failure_message(why).is_false()
		# G18/G19: the Bananas in slots 4 and 5 CHAIN: 2, then 2 + 2 = 4; the row 25.
		_place(run, places[BANANA_1], 3)
		_place(run, places[BANANA_2], 4)
		var chain: ScoreResult = run.preview()
		assert_int(chain.total).override_failure_message(why).is_equal(25)
		assert_int(chain.payouts[3]).override_failure_message(why).is_equal(2)
		assert_int(chain.payouts[4]).override_failure_message(why).is_equal(4)
		# G20/G21: Milk and Coffee each +2 from Eggs and Bread; 31, then 35 over the quota.
		var milk_price: int = places[MILK].definition.base
		var coffee_price: int = places[COFFEE].definition.base
		_place(run, places[MILK], 5)
		assert_int(run.preview().total).override_failure_message(why).is_equal(31)
		_place(run, places[COFFEE], 6)
		var full: ScoreResult = run.preview()
		assert_int(full.total).override_failure_message(why).is_equal(35)
		assert_int(full.total).override_failure_message(why).is_greater_equal(run.quota())
		assert_int(full.payouts[5]).override_failure_message(why).is_equal(milk_price + 2)
		assert_int(full.payouts[6]).override_failure_message(why).is_equal(coffee_price + 2)
		# 7 slots, 8 cards: Frozen peas stays in its basket.
		assert_bool(run.can_place(places[FROZEN_PEAS])).override_failure_message(why).is_false()
		assert_array(run.hand()).contains_exactly([places[FROZEN_PEAS]])


## Shift 1 of a guided-deal run with pack `pack_index` taken and the fixed hand dealt.
static func _shift_one(guide: GuidedStartDefinition, pack_index: int) -> RunState:
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
	run.take_pack(run.start_offer.packs[pack_index])
	run.kept = guide.hand_ids(run.deck.cards)
	run.start_shift()
	return run


func _place(run: RunState, card: CardInstance, slot: int) -> void:
	(
		assert_bool(run.place(card, slot))
		. override_failure_message(String(card.definition.id))
		. is_true()
	)


## Whether `result` holds a WASTED step for the card's own rule at `slot`.
static func _wasted(result: ScoreResult, slot: int) -> bool:
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.slot == slot and not step.row_wide:
			return true
	return false
