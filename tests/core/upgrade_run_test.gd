extends GdUnitTestSuite
## The upgrade step in a run (plan section 3.8): offers on the shifts in upgrade_shifts, built
## at checkout from the run's RNG, after the reward pick or skip; a pick is required and only
## an offered upgrade is accepted; the Extra redraw adds a redraw; and the run history.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const UPGRADE_DIR := "res://data/upgrades"


func test_balance_upgrade_data_fits_the_run() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_array(Array(balance.upgrade_shifts)).is_equal([2, 4, 6])
	for shift_number: int in balance.upgrade_shifts:
		# A shift of the run, and never the last one (the last shift has no reward or upgrade).
		assert_int(shift_number).is_between(1, balance.quotas.size() - 1)
	var ids: Array = []
	var types: Dictionary = {}
	for upgrade: UpgradeDefinition in balance.upgrade_pool:
		ids.append(String(upgrade.id))
		types[upgrade.type] = true
	ids.sort()
	(
		assert_array(ids)
		. is_equal(
			[
				"big_basket",
				"category_engine",
				"coupon_engine",
				"extra_coupon_slot",
				"extra_redraw",
				"rule_bender",
				"slot_engine",
			]
		)
	)
	# One per type, and two Economy upgrades (plan v0.24).
	assert_int(types.size()).is_equal(6)
	assert_int(balance.upgrade_offer_size).is_equal(3)


func test_upgrade_step_comes_only_on_upgrade_shifts_after_the_reward() -> void:
	var run: RunState = _run(21)
	# Shift 1 is not an upgrade shift.
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_array(run.upgrade_offer).is_empty()
	assert_bool(run.skip_reward()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_bool(run.next_shift()).is_true()
	# Shift 2: the offer is built at checkout, but the reward comes first.
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_int(run.upgrade_offer.size()).is_equal(3)
	var first: UpgradeDefinition = run.upgrade_offer[0]
	assert_bool(run.pick_upgrade(first)).is_false()
	assert_bool(run.skip_reward()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	# No skip and no way past the step without a pick.
	assert_bool(run.skip_reward()).is_false()
	assert_bool(run.next_shift()).is_false()
	assert_bool(run.pick_upgrade(UpgradeDefinition.new())).is_false()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	assert_bool(run.pick_upgrade(first)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_array(run.upgrades).contains_exactly([first])
	assert_array(run.upgrade_offer).is_empty()
	assert_bool(run.pick_upgrade(first)).is_false()
	assert_bool(run.next_shift()).is_true()
	# Shift 3: no upgrade step.
	_pass(run)
	assert_array(run.upgrade_offer).is_empty()
	run.skip_reward()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)


## The upgrade step also follows a pick that needed a deck-full replacement.
func test_upgrade_step_follows_a_deck_full_replacement() -> void:
	var run: RunState = _run(22)
	run.debug_skip_to_shift(1)
	while not run.deck_is_full():
		run.deck.add_card(load(BREAD))
	_pass(run)
	var card: CardDefinition = run.offer[0]
	assert_bool(run.take_reward(card)).is_false()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	assert_bool(run.take_reward(card, run.deck.cards[0])).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)


## With 7 upgrades of 6 types, the offers on shifts 2, 4 and 6 always hold 3 upgrades, never
## one the run owns, each of a different type.
func test_offers_hold_only_unowned_upgrades_of_different_types() -> void:
	var run: RunState = _run(23)
	var sizes: Array = []
	while run.phase != RunState.Phase.WON:
		_pass(run)
		run.skip_reward()
		if run.phase == RunState.Phase.UPGRADE:
			sizes.append(run.upgrade_offer.size())
			var types: Dictionary = {}
			for upgrade: UpgradeDefinition in run.upgrade_offer:
				assert_bool(run.upgrades.has(upgrade)).is_false()
				assert_bool(types.has(upgrade.type)).is_false()
				types[upgrade.type] = true
			assert_bool(run.pick_upgrade(run.upgrade_offer[-1])).is_true()
		if run.phase == RunState.Phase.SCORED:
			run.next_shift()
	assert_array(sizes).is_equal([3, 3, 3])
	assert_int(run.upgrades.size()).is_equal(3)


func test_offer_is_the_same_for_the_same_seed() -> void:
	var first: Array = _offer_ids_on_shift_two(31)
	assert_array(_offer_ids_on_shift_two(31)).is_equal(first)
	var balance: BalanceDefinition = load(BALANCE)
	var none: Array[UpgradeDefinition] = []
	var one: Array[UpgradeDefinition] = UpgradeOffer.make(_rng(5), balance, none, _no_cards())
	assert_array(UpgradeOffer.make(_rng(5), balance, none, _no_cards())).is_equal(one)
	# The pool is shuffled with the run's RNG, so seeds give different orders.
	var orders: Dictionary = {}
	for seed_value: int in range(40):
		var offer: Array[UpgradeDefinition] = UpgradeOffer.make(
			_rng(seed_value), balance, none, _no_cards()
		)
		orders[str(_ids(offer))] = true
	assert_int(orders.size()).is_greater(1)


## Repeats of a type, duplicates in the pool and owned upgrades never reach an offer.
func test_offer_skips_owned_upgrades_and_repeated_types() -> void:
	var balance: BalanceDefinition = load(BALANCE).duplicate()
	# Phase 1's three upgrades, so only two types are left once Category engine is owned.
	var pool: Array[UpgradeDefinition] = [
		_upgrade("coupon_engine"), _upgrade("category_engine"), _upgrade("extra_redraw")
	]
	var second_coupon_engine: UpgradeDefinition = UpgradeDefinition.new()
	second_coupon_engine.id = &"second_coupon_engine"
	second_coupon_engine.type = UpgradeDefinition.Type.COUPON_ENGINE
	pool.append(second_coupon_engine)
	pool.append(pool[0])
	balance.upgrade_pool = pool
	var owned: Array[UpgradeDefinition] = [_upgrade("category_engine")]
	for seed_value: int in range(30):
		var offer: Array[UpgradeDefinition] = UpgradeOffer.make(
			_rng(seed_value), balance, owned, _no_cards()
		)
		assert_int(offer.size()).is_equal(2)
		var types: Array = offer.map(func(upgrade: UpgradeDefinition) -> int: return upgrade.type)
		types.sort()
		assert_array(types).is_equal(
			[UpgradeDefinition.Type.COUPON_ENGINE, UpgradeDefinition.Type.ECONOMY]
		)
		assert_bool(offer.has(owned[0])).is_false()
	# Every pool upgrade owned: an empty offer.
	balance.upgrade_pool = owned
	assert_array(UpgradeOffer.make(_rng(1), balance, owned, _no_cards())).is_empty()


## The offer is built at checkout, so it is fixed before the player chooses anything.
func test_offer_is_built_at_checkout_and_kept_through_the_reward() -> void:
	var run: RunState = _run(24)
	run.debug_skip_to_shift(1)
	_pass(run)
	var at_checkout: Array = _ids(run.upgrade_offer)
	assert_int(at_checkout.size()).is_equal(3)
	run.take_reward(run.offer[0])
	assert_array(_ids(run.upgrade_offer)).is_equal(at_checkout)


## Owning every pool upgrade leaves nothing to offer, so the step is skipped.
func test_an_empty_offer_skips_the_step() -> void:
	var run: RunState = _run(25)
	run.upgrades.assign(run.balance.upgrade_pool)
	run.debug_skip_to_shift(1)
	_pass(run)
	assert_array(run.upgrade_offer).is_empty()
	run.skip_reward()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)


func test_losing_an_upgrade_shift_ends_the_run_without_an_upgrade() -> void:
	var run: RunState = _run(26)
	run.debug_skip_to_shift(1)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_array(run.upgrade_offer).is_empty()
	assert_bool(run.pick_upgrade(run.balance.upgrade_pool[0])).is_false()
	assert_bool(run.history[-1].passed).is_false()
	assert_object(run.history[-1].upgrade_taken).is_null()


## Even if balance data listed the last shift, winning it offers nothing.
func test_the_last_shift_has_no_upgrade() -> void:
	var balance: BalanceDefinition = _low_quotas()
	balance.upgrade_shifts = PackedInt32Array([balance.quotas.size()])
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(27, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	run.debug_skip_to_shift(balance.quotas.size() - 1)
	_pass(run)
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	assert_array(run.upgrade_offer).is_empty()


func test_history_has_one_entry_per_played_shift() -> void:
	var run: RunState = _run(28)
	# Shift 1: a reward card picked.
	_pass(run)
	var card: CardDefinition = run.offer[0]
	run.take_reward(card)
	run.next_shift()
	# Shift 2: the reward skipped, an upgrade taken.
	_pass(run)
	run.skip_reward()
	var upgrade: UpgradeDefinition = run.upgrade_offer[0]
	run.pick_upgrade(upgrade)
	run.next_shift()
	# Shift 3: lost with an empty row.
	run.checkout()
	assert_int(run.history.size()).is_equal(3)
	var first: Dictionary = run.history[0].to_dictionary()
	(
		assert_dict(first)
		. is_equal(
			{
				"shift": 1,
				"quota": 5,
				"total": 6,
				"passed": true,
				"card_picked": String(card.id),
				"reward_skipped": false,
				"upgrade_taken": "",
				"inspection": "",
				"played": ["bread", "bread"],
			}
		)
	)
	assert_object(run.history[1].card_picked).is_null()
	assert_bool(run.history[1].reward_skipped).is_true()
	assert_object(run.history[1].upgrade_taken).is_same(upgrade)
	assert_int(run.history[1].shift).is_equal(2)
	var lost: ShiftRecord = run.history[2]
	assert_int(lost.shift).is_equal(3)
	assert_int(lost.total).is_equal(0)
	assert_bool(lost.passed).is_false()
	assert_object(lost.card_picked).is_null()
	assert_bool(lost.reward_skipped).is_false()
	assert_object(lost.upgrade_taken).is_null()


## Extra redraw: one more redraw each shift, each of up to redraw_limit hand cards, and no
## redraw brings back a card that an earlier one replaced.
func test_extra_redraw_allows_a_second_redraw() -> void:
	var run: RunState = _run(29)
	assert_int(run.redraws_allowed).is_equal(1)
	run.debug_skip_to_shift(1)
	_pass(run)
	run.skip_reward()
	var extra: UpgradeDefinition = _upgrade("extra_redraw")
	# With 7 upgrades the seed's offer may not hold it: offer it for this test.
	run.upgrade_offer = [extra]
	run.pick_upgrade(extra)
	# It applies from the next shift on.
	assert_bool(run.next_shift()).is_true()
	assert_int(run.redraws_allowed).is_equal(2)
	assert_int(run.redraws_used).is_equal(0)
	var hand: Array[CardInstance] = run.hand()
	assert_bool(run.can_redraw([hand[0], hand[1], hand[2]])).is_false()
	var replaced: Array[CardInstance] = [hand[0], hand[1]]
	assert_int(run.redraw([hand[0], hand[1]]).size()).is_equal(2)
	assert_int(run.redraws_used).is_equal(1)
	hand = run.hand()
	assert_bool(run.can_redraw([hand[2], hand[3]])).is_true()
	replaced.append_array([hand[2], hand[3]])
	assert_int(run.redraw([hand[2], hand[3]]).size()).is_equal(2)
	assert_int(run.redraws_used).is_equal(2)
	assert_bool(run.can_redraw([run.hand()[4]])).is_false()
	assert_array(run.redraw([run.hand()[4]])).is_empty()
	# Neither redraw brought back a replaced card.
	for card: CardInstance in replaced:
		assert_bool(run.hand().has(card)).is_false()


func test_without_the_upgrade_a_shift_has_one_redraw() -> void:
	var run: RunState = _run(30)
	var hand: Array[CardInstance] = run.hand()
	run.redraw([hand[0]])
	assert_bool(run.can_redraw([run.hand()[1]])).is_false()


## The preview and the checkout both score with the run's upgrades.
func test_preview_and_checkout_use_the_run_upgrades() -> void:
	var run: RunState = _run(32)
	run.upgrades.append(_upgrade("coupon_engine"))
	run.place(run.debug_add_to_hand(load(BREAD)), 0)
	run.place(run.debug_add_to_hand(load("res://data/cards/final_markdown.tres")), 1)
	var preview: ScoreResult = run.preview()
	assert_int(preview.total).is_equal(15)
	var upgrade_steps: Array = preview.steps.filter(
		func(step: ScoreStep) -> bool: return step.source_kind == ScoreStep.SourceKind.UPGRADE
	)
	assert_int(upgrade_steps.size()).is_equal(1)
	assert_int(run.checkout().total).is_equal(15)


static func _low_quotas() -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	return balance


## A run whose quotas are all 5, so two Breads (6) pass any shift.
static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = _low_quotas()
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


static func _pass(run: RunState) -> void:
	for _index: int in range(2):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


static func _offer_ids_on_shift_two(seed_value: int) -> Array:
	var run: RunState = _run(seed_value)
	_pass(run)
	run.skip_reward()
	run.next_shift()
	_pass(run)
	return _ids(run.upgrade_offer)


static func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADE_DIR, id])


static func _ids(upgrades: Array) -> Array:
	var ids: Array = []
	for upgrade: UpgradeDefinition in upgrades:
		ids.append(String(upgrade.id))
	return ids


static func _no_cards() -> Array[CardDefinition]:
	return []


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
