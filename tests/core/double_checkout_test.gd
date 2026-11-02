extends GdUnitTestSuite
## Double checkout (#122 part 2, a badge pin: RunPins, decided with the user on 2026-10-31 and
## 2026-11-01): two rows of the pin's row_slots (4) a shift, Big basket adding one to each; row 1's
## checkout scores it alone, spends its cards and refills the hand, with the shift still planning
## and its redraws shared; row 2's checkout ends the shift on both rows' total. Each row is scored
## on its own, but the upgrades' slot numbers count across both rows (Slot engine's slot 6 is row
## 2's slot 2). The run save keeps row 1 between the checkouts. Uses the live pin, starter deck and
## balance with every quota at 5.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const DOUBLE := "res://data/pins/double_checkout.tres"
const BIG_BASKET := "res://data/upgrades/big_basket.tres"
const SLOT_ENGINE := "res://data/upgrades/slot_engine.tres"

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	EightShiftLoop.apply(_balance)


func test_a_shift_has_two_rows_of_the_pins_slots() -> void:
	var plain: RunState = _run(3, false)
	assert_int(plain.limits.slot_count).is_equal(_balance.slot_count)
	assert_int(RunPins.row_slots(plain)).is_equal(0)
	var run: RunState = _run(3)
	var pin: PinDefinition = load(DOUBLE)
	assert_int(RunPins.row_slots(run)).is_equal(pin.row_slots)
	assert_int(run.limits.slot_count).is_equal(pin.row_slots)
	# Big basket adds one slot to each row.
	run.upgrades.append(load(BIG_BASKET))
	run.start_shift()
	assert_int(run.limits.slot_count).is_equal(pin.row_slots + 1)


## Row 1's checkout: scored alone, its cards spent (out of the hand), the hand refilled in their
## places, the row emptied, the shift still planning with its redraws as they were, no record.
func test_row_one_is_scored_spent_and_refilled() -> void:
	var run: RunState = _run(4)
	var hand: Array[CardInstance] = run.hand()
	var row_one: Array[CardInstance] = []
	for place: int in [0, 2, 3, 5]:
		row_one.append(hand[place])
		run.place(hand[place], run.row.size())
	var alone: int = Scoring.score(row_one, [], WeekSchedule.shift_events(run), null, 0, true).total
	var result: ScoreResult = run.checkout()
	assert_int(result.total).is_equal(alone)
	assert_object(run.first_result).is_same(result)
	assert_object(run.row_result).is_same(result)
	assert_array(run.first_row).is_equal(row_one)
	assert_array(run.row).is_empty()
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(run.history).is_empty()
	assert_int(run.redraws_used).is_equal(0)
	assert_bool(run.can_redraw_basket(0)).is_true()  # Redraws carry on into row 2.
	var refilled: Array[CardInstance] = run.hand()
	assert_int(refilled.size()).is_equal(hand.size())
	for card: CardInstance in row_one:
		assert_bool(refilled.has(card)).is_false()
	for place: int in [1, 4]:
		assert_object(refilled[place]).is_same(hand[place])


## Row 2's checkout ends the shift on both rows: one record of both rows' cards and total, the
## shift's result joined (row 2's slots after row 1's), row 2's own result kept for its count-up.
func test_row_two_ends_the_shift_on_both_rows() -> void:
	var run: RunState = _run(5)
	_place(run, 4)
	var first: ScoreResult = run.checkout()
	var row_two: Array[CardInstance] = _place(run, 3)
	var whole: ScoreResult = run.checkout()
	assert_int(run.phase).is_not_equal(RunState.Phase.PLANNING)
	assert_int(whole.total).is_equal(first.total + run.row_result.total)
	assert_int(run.history.size()).is_equal(1)
	assert_int(run.history[0].total).is_equal(whole.total)
	assert_int(run.history[0].played.size()).is_equal(7)
	assert_int(whole.payouts.size()).is_equal(7)
	assert_int(whole.steps.size()).is_equal(first.steps.size() + run.row_result.steps.size())
	var last: ScoreStep = whole.steps[-1]
	assert_int(last.subtotal).is_equal(whole.total)
	assert_int(run.row_result.steps[-1].slot).is_less(row_two.size())
	assert_int(last.slot).is_equal(run.row_result.steps[-1].slot + 4)
	assert_bool(run.passed()).is_equal(whole.total >= run.quota())


## The upgrades' slot numbers count across both rows: Slot engine's slot 6 is row 2's slot 2;
## row 1 never fizzles for it, and row 2 fizzles when it has fewer than 2 cards.
func test_slot_numbers_count_across_both_rows() -> void:
	var engine: UpgradeDefinition = load(SLOT_ENGINE)
	var rule: NthSlotMultiplierRule = engine.rules[0] as NthSlotMultiplierRule
	assert_int(rule.slot_number).is_equal(6)
	var upgrades: Array[UpgradeDefinition] = [engine]
	var breads: Array[CardInstance] = _breads(2)
	var plain: int = Scoring.score(breads, [], [], null, 4).total
	var boosted: ScoreResult = Scoring.score(breads, upgrades, [], null, 4)
	assert_int(boosted.payouts[1]).is_equal(boosted.payouts[0] * rule.factor)
	assert_int(boosted.total).is_greater(plain)
	var row_one: ScoreResult = Scoring.score(_breads(4), upgrades, [], null, 0, true)
	assert_bool(_wasted(row_one)).is_false()
	var short: ScoreResult = Scoring.score(_breads(1), upgrades, [], null, 4)
	assert_bool(_wasted(short)).is_true()


## The planning preview scores row 2 as its checkout will (the slot offset).
func test_the_preview_of_row_two_counts_the_slot_offset() -> void:
	var run: RunState = _run(6)
	run.upgrades.append(load(SLOT_ENGINE))
	_place(run, 4)
	run.checkout()
	_place(run, 2)
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	var expected: int = Scoring.score(run.row, run.upgrades, events, null, 4).total
	assert_int(run.preview().total).is_equal(expected)


## A short draw pile refills the first places only; the hand gets smaller.
func test_a_short_pile_refills_the_first_places() -> void:
	var run: RunState = _run(7)
	var pile: int = run.deck.draw_pile().size()
	var hand: Array[CardInstance] = run.hand()
	var places: Array[int] = []
	for place: int in range(pile + 2):
		places.append(place)
	var filled: Array[int] = run.deck.refill_places(places)
	assert_int(filled.size()).is_equal(pile)
	assert_int(run.hand().size()).is_equal(hand.size() - 2)
	assert_bool(run.deck.draw_pile().is_empty()).is_true()


## The run save keeps row 1 between the two checkouts and after the shift's.
func test_the_run_save_keeps_row_one() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _run(8)
	_place(run, 4)
	var first: ScoreResult = run.checkout()
	var data: Dictionary = _saved(run)
	var restored: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(restored).is_not_null()
	var back: RunState = restored.run
	assert_int(back.first_row.size()).is_equal(4)
	for index: int in range(4):
		assert_int(back.first_row[index].instance_id).is_equal(run.first_row[index].instance_id)
	assert_int(back.first_result.total).is_equal(first.total)
	assert_int(back.limits.slot_count).is_equal(4)
	_place(run, 2)
	var whole: ScoreResult = run.checkout()
	var ended: RunSave = RunSave.from_dictionary(_saved(run), lookup)
	assert_object(ended).is_not_null()
	assert_int(ended.run.last_result.total).is_equal(whole.total)
	# A row 1 without its pin is refused.
	data["pins"] = []
	assert_object(RunSave.from_dictionary(data, lookup)).is_null()


func _run(seed_value: int, with_pin: bool = true) -> RunState:
	var run: RunState = RunState.new(
		seed_value, load(STARTER), _balance, RunStock.starting(_balance)
	)
	if with_pin:
		RunPins.wear(run, [load(DOUBLE)])
	run.start_shift()
	return run


## Places the first `count` hand cards (by place) on the belt.
static func _place(run: RunState, count: int) -> Array[CardInstance]:
	var placed: Array[CardInstance] = []
	for card: CardInstance in run.hand():
		if placed.size() == count:
			break
		if run.place(card, run.row.size()):
			placed.append(card)
	return placed


static func _breads(count: int) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for index: int in range(count):
		cards.append(CardInstance.new(load(BREAD), index + 1))
	return cards


static func _wasted(result: ScoreResult) -> bool:
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.row_wide:
			return true
	return false


static func _saved(run: RunState) -> Dictionary:
	return JSON.parse_string(JSON.stringify(RunSave.to_dictionary(run, "id", 0)))


## The joined result carries both rows' belt marks (#128's batches and chains, merged onto #122):
## row 2's slots move past row 1's cards, a helper's -1 (none) stays -1; continued keeps them.
func test_the_joined_result_moves_row_twos_batches_and_chains() -> void:
	var first: ScoreResult = ScoreResult.new()
	first.total = 10
	first.batches = [PackedInt32Array([0, 1])]
	first.chains = [PackedInt32Array([2, 3])]
	first.knot_factors = {2: 2}
	first.chain_feeds = PackedInt32Array([-1])
	first.chain_tallies = PackedInt32Array([3])
	var second: ScoreResult = ScoreResult.new()
	second.total = 7
	second.batches = [PackedInt32Array([1, 2])]
	second.chains = [PackedInt32Array([0, 1])]
	second.knot_factors = {1: 3}
	second.chain_feeds = PackedInt32Array([-1])
	second.chain_tallies = PackedInt32Array([2])
	var joined: ScoreResult = ScoreResult.joined(first, second, 4)
	assert_int(joined.total).is_equal(17)
	assert_array(joined.batches).is_equal([PackedInt32Array([0, 1]), PackedInt32Array([5, 6])])
	assert_array(joined.chains).is_equal([PackedInt32Array([2, 3]), PackedInt32Array([4, 5])])
	assert_dict(joined.knot_factors).is_equal({2: 2, 5: 3})
	assert_array(joined.chain_feeds).is_equal(PackedInt32Array([-1, -1]))
	assert_array(joined.chain_tallies).is_equal(PackedInt32Array([3, 6]))
	var on: ScoreResult = ScoreResult.continued(second, first.total)
	assert_int(on.total).is_equal(17)
	assert_array(on.chains).is_equal(second.chains)
	assert_dict(on.knot_factors).is_equal(second.knot_factors)
