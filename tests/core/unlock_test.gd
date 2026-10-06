extends GdUnitTestSuite
## Unlock data (full build plan section 7.3): unlock conditions and their pure check at the end
## of a run, a deck's starting upgrade, and card variants. Uses the live starter deck and
## balance with every quota at 5, and builds conditions and decks in code.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const MULTIPACK := "res://data/cards/multipack.tres"
const REPEAT := "res://data/cards/repeat.tres"
const BANANA := "res://data/cards/banana.tres"
const COUPON_ENGINE := "res://data/upgrades/coupon_engine.tres"
const EXTRA_REDRAW := "res://data/upgrades/extra_redraw.tres"


func test_win_with_card_needs_a_win_and_the_card_in_the_final_deck() -> void:
	var with_repeat: UnlockCondition = _condition(UnlockCondition.Kind.WIN_WITH_CARD, REPEAT, 0)
	var with_multipack: UnlockCondition = _condition(
		UnlockCondition.Kind.WIN_WITH_CARD, MULTIPACK, 0
	)
	var won: RunState = _won_run(51)
	# The starter deck holds a Repeat, not a Multipack.
	assert_bool(UnlockCheck.is_met(with_repeat, won)).is_true()
	assert_bool(UnlockCheck.is_met(with_multipack, won)).is_false()
	var lost: RunState = _run(52)
	lost.checkout()
	assert_int(lost.phase).is_equal(RunState.Phase.LOST)
	assert_bool(UnlockCheck.is_met(with_repeat, lost)).is_false()


func test_score_in_one_checkout_looks_at_every_shift() -> void:
	var run: RunState = _run(53)
	_pass(run, [BREAD, BREAD, BREAD])
	run.skip_reward()
	run.next_shift()
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	var nine: UnlockCondition = _condition(UnlockCondition.Kind.SCORE_IN_ONE_CHECKOUT, "", 9)
	var ten: UnlockCondition = _condition(UnlockCondition.Kind.SCORE_IN_ONE_CHECKOUT, "", 10)
	assert_bool(UnlockCheck.is_met(nine, run)).is_true()
	assert_bool(UnlockCheck.is_met(ten, run)).is_false()


func test_use_coupon_counts_every_checked_out_copy_across_runs() -> void:
	var run: RunState = _run(54)
	_pass(run, [BREAD, REPEAT, BREAD, REPEAT])
	run.skip_reward()
	run.next_shift()
	_pass(run, [BREAD, BREAD, REPEAT])
	var uses: Dictionary[StringName, int] = UnlockCheck.coupon_uses(run.history)
	assert_dict(uses).is_equal({&"repeat": 3})
	var five: UnlockCondition = _condition(UnlockCondition.Kind.USE_COUPON_TIMES, REPEAT, 5)
	assert_bool(UnlockCheck.is_met(five, run)).is_false()
	var earlier: Dictionary[StringName, int] = {&"repeat": 2}
	assert_bool(UnlockCheck.is_met(five, run, earlier)).is_true()


func test_the_history_records_the_cards_checked_out() -> void:
	var run: RunState = _run(55)
	_pass(run, [BREAD, REPEAT, BREAD])
	var played: Array = run.history[0].played.map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	assert_array(played).is_equal(["bread", "repeat", "bread"])
	assert_array(run.history[0].to_dictionary()["played"]).is_equal(["bread", "repeat", "bread"])


func test_conditions_read_as_text_and_report_problems() -> void:
	var multipack: UnlockCondition = _condition(UnlockCondition.Kind.WIN_WITH_CARD, MULTIPACK, 0)
	assert_str(multipack.summary()).is_equal("Win a run with Multipack in your deck")
	var score: UnlockCondition = _condition(UnlockCondition.Kind.SCORE_IN_ONE_CHECKOUT, "", 40)
	assert_str(score.summary()).is_equal("Score €40 in one checkout")
	var repeat: UnlockCondition = _condition(UnlockCondition.Kind.USE_COUPON_TIMES, REPEAT, 10)
	assert_str(repeat.summary()).is_equal("Use Repeat 10 times")
	for condition: UnlockCondition in [multipack, score, repeat]:
		assert_array(condition.problems()).is_empty()
	assert_array(UnlockCondition.new().problems()).is_equal(["kind is UNSET"])
	var no_card: UnlockCondition = _condition(UnlockCondition.Kind.WIN_WITH_CARD, "", 0)
	assert_int(no_card.problems().size()).is_equal(1)
	# A product can't be a coupon-use condition, and an amount must be above 0.
	var product: UnlockCondition = _condition(UnlockCondition.Kind.USE_COUPON_TIMES, BANANA, 0)
	assert_int(product.problems().size()).is_equal(2)
	var zero: UnlockCondition = _condition(UnlockCondition.Kind.SCORE_IN_ONE_CHECKOUT, "", 0)
	assert_int(zero.problems().size()).is_equal(1)


func test_a_starting_upgrade_is_owned_from_the_first_shift() -> void:
	var run: RunState = _run_with_deck(56, _deck_with_upgrade(EXTRA_REDRAW))
	assert_array(run.upgrades).is_equal([load(EXTRA_REDRAW)])
	assert_int(run.redraws_allowed).is_equal(2)
	# Offers skip it, as any owned upgrade.
	run.debug_skip_to_shift(1)
	_pass(run, [BREAD, BREAD])
	assert_bool(run.upgrade_offer.has(load(EXTRA_REDRAW))).is_false()
	assert_int(run.upgrade_offer.size()).is_equal(2)


func test_a_starting_upgrade_scores_from_the_first_shift() -> void:
	var run: RunState = _run_with_deck(57, _deck_with_upgrade(COUPON_ENGINE))
	run.place(run.debug_add_to_hand(load(BREAD)), 0)
	run.place(run.debug_add_to_hand(load("res://data/cards/final_markdown.tres")), 1)
	assert_int(run.preview().total).is_equal(15)
	var upgrade_steps: Array = run.preview().steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.UPGRADE
	)
	assert_int(upgrade_steps[0].source_index).is_equal(0)


func test_the_starter_deck_has_no_upgrade_or_condition() -> void:
	var starter: DeckDefinition = load(STARTER)
	assert_object(starter.starting_upgrade).is_null()
	assert_object(starter.unlock_condition).is_null()
	assert_str(starter.description).is_not_empty()
	assert_array(_run(58).upgrades).is_empty()


## A variant is a variant of another card that is not itself a variant, of the same kind.
func test_variant_rules() -> void:
	var banana: CardDefinition = load(BANANA)
	assert_array(banana.variant_problems()).is_empty()
	var organic: CardDefinition = _variant_of(banana)
	assert_array(organic.variant_problems()).is_empty()
	var own: CardDefinition = banana.duplicate()
	own.variant_of = own
	assert_array(own.variant_problems()).is_equal(["variant_of is itself"])
	# A resource that references itself is never freed: break the loop.
	own.variant_of = null
	var chained: CardDefinition = _variant_of(organic)
	assert_array(chained.variant_problems()).is_equal(["variant_of is a variant"])
	var mixed: CardDefinition = _variant_of(load(REPEAT))
	mixed.kind = CardDefinition.Kind.PRODUCT
	assert_array(mixed.variant_problems()).is_equal(["variant_of has a different kind"])
	# Making a variant never changes the shared base card.
	assert_object(banana.variant_of).is_null()


static func _variant_of(base: CardDefinition) -> CardDefinition:
	var variant: CardDefinition = base.duplicate()
	variant.id = StringName("organic_" + String(base.id))
	variant.variant_of = base
	return variant


static func _condition(
	kind: UnlockCondition.Kind, card_path: String, amount: int
) -> UnlockCondition:
	var condition: UnlockCondition = UnlockCondition.new()
	condition.kind = kind
	if not card_path.is_empty():
		condition.card = load(card_path)
	condition.amount = amount
	return condition


static func _deck_with_upgrade(upgrade_path: String) -> DeckDefinition:
	var deck: DeckDefinition = (load(STARTER) as DeckDefinition).duplicate()
	deck.starting_upgrade = load(upgrade_path)
	return deck


static func _low_quotas() -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	return balance


static func _run(seed_value: int) -> RunState:
	return _run_with_deck(seed_value, load(STARTER))


static func _run_with_deck(seed_value: int, deck: DeckDefinition) -> RunState:
	var balance: BalanceDefinition = _low_quotas()
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


static func _pass(run: RunState, paths: Array) -> void:
	for path: String in paths:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	run.checkout()


## A run won on its last shift (every quota is 5).
static func _won_run(seed_value: int) -> RunState:
	var run: RunState = _run(seed_value)
	run.debug_skip_to_shift(run.shift_count() - 1)
	_pass(run, [BREAD, BREAD])
	return run
