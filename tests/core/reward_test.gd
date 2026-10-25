extends GdUnitTestSuite
## The reward data (generally useful cards, coupon pools, the starting stock) and taking a
## reward from the run's stock through the RECEIPT REWARDS machine (#77; plan sections 2 and 5,
## full build plan 7.2). The machine's draw and odds are tested in machine_draw_test and
## machine_odds_test.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const BUNDLE := "res://data/cards/bundle.tres"
const CHEESE := "res://data/cards/cheese.tres"
## Bundle returned as 2 for 1, which took its place in both pools (plan v0.23).
const COMBINATION_COUPONS := [&"breakfast_sticker", &"multipack", &"two_for_one"]
## The starter's stock with the 3 base aisles: the staples, the aisles' products and every
## coupon but Bundle, in stock order.
const STARTING_STOCK := [
	"banana",
	"bread",
	"milk",
	"eggs",
	"coffee",
	"soup",
	"cheese",
	"frozen_peas",
	"butter",
	"yogurt",
	"reduced_yogurt",
	"cereal",
	"tea_bags",
	"crackers",
	"dented_can",
	"day_old_buns",
	"carrier_bag",
	"scissors",
	"batteries",
	"flickering_bulb",
	"repeat",
	"final_markdown",
	"breakfast_sticker",
	"multipack",
	"two_for_one",
	"shelf_swap",
	"clearance_tag",
	"opening_deal",
]


## The prototype's four (Banana, Bread, Eggs, Milk), one per base aisle (Butter, Cereal,
## Carrier bag, v0.22) and the capsule items' (Mixed herbs in Pantry, Strawberries, Scone and
## Crisps in the machine-opened aisles, v0.27), and Reduced yogurt and Flickering bulb so offers
## show Clearance cards (#42, full build plan v0.27), all decided with the user.
func test_generally_useful_cards_are_the_decided_ones() -> void:
	var useful: Array = []
	for file: String in DirAccess.get_files_at("res://data/cards"):
		if file.ends_with(".tres"):
			var card: CardDefinition = load("res://data/cards/" + file)
			# Item tiers (#77) copy their plain card's flag but are never offered or stocked.
			if card.generally_useful and card.tier == CardDefinition.Tier.PLAIN:
				useful.append(String(card.id))
	useful.sort()
	(
		assert_array(useful)
		. is_equal(
			[
				"banana",
				"bread",
				"butter",
				"carrier_bag",
				"cereal",
				"crisps",
				"eggs",
				"flickering_bulb",
				"milk",
				"mixed_herbs",
				"reduced_yogurt",
				"scone",
				"strawberries",
			]
		)
	)


func test_coupon_pool_and_first_pool_hold_the_agreed_coupons() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var coupons: Array = balance.coupon_pool.map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	(
		assert_array(coupons)
		. is_equal(
			[
				"repeat",
				"final_markdown",
				"breakfast_sticker",
				"multipack",
				"two_for_one",
				"shelf_swap",
				"clearance_tag",
				"opening_deal",
			]
		)
	)
	assert_int(balance.machine.prizes_per_visit).is_equal(3)
	var first: Array = balance.first_offer_pool.map(
		func(card: CardDefinition) -> StringName: return card.id
	)
	assert_array(first).contains_exactly_in_any_order(COMBINATION_COUPONS)


## A new profile stocks the staples and every base aisle (they fit the budget), plus the coupons.
func test_the_starting_stock_is_the_base_aisles_and_the_coupon_pool() -> void:
	(
		assert_array(_stock().map(func(card: CardDefinition) -> String: return String(card.id)))
		. is_equal(STARTING_STOCK)
	)


func test_no_offer_pool_contains_bundle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var bundle: CardDefinition = load(BUNDLE)
	assert_bool(balance.coupon_pool.has(bundle)).is_false()
	assert_bool(balance.first_offer_pool.has(bundle)).is_false()
	assert_bool(_stock().has(bundle)).is_false()
	for card: CardDefinition in balance.coupon_pool + balance.first_offer_pool:
		assert_str(String(card.id)).is_not_equal("bundle")


## The machine's first NEW ITEMS draw holds one coupon, a combination coupon (first_offer_pool,
## #108: the first coupon draw draws from it only).
func test_the_first_new_items_draw_holds_a_combination_coupon() -> void:
	for seed_value: int in range(1, 60):
		var run: RunState = _passed_run(seed_value)
		assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		var ids: Array = _prize_ids(run)
		assert_int(ids.size()).is_equal(3)
		var coupons: Array = run.machine.prizes().filter(
			func(prize: MachinePrize) -> bool: return prize.kind == MachinePrize.Kind.COUPON
		)
		assert_int(coupons.size()).override_failure_message("seed %d" % seed_value).is_equal(1)
		var coupon: MachinePrize = coupons[0]
		(
			assert_bool(COMBINATION_COUPONS.has(coupon.card.id))
			. override_failure_message("seed %d" % seed_value)
			. is_true()
		)


## The machine draws only from the run's stock: a product outside it is never a prize.
func test_the_run_draws_from_its_own_stock() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var stock: RunStock = RunStock.starting(balance)
	stock.cards.erase(load(CHEESE))
	for seed_value: int in range(1, 40):
		var run: RunState = RunState.new(seed_value, deck, balance, stock)
		run.start_shift()
		_fill_and_pass(run)
		assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		assert_array(run.machine.prizes()).has_size(3)
		for prize: MachinePrize in run.machine.prizes():
			# A BIG or GOLDEN product (#108) is its plain card's.
			assert_str(String(prize.plain_id())).is_not_equal("cheese")
			var plain: CardDefinition = prize.card
			if plain.tier != CardDefinition.Tier.PLAIN:
				plain = plain.variant_of
			assert_bool(stock.cards.has(plain)).is_true()


func test_same_seed_gives_same_prizes() -> void:
	var first: RunState = _passed_run(99)
	var second: RunState = _passed_run(99)
	for run: RunState in [first, second]:
		MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_array(_prize_ids(first)).is_equal(_prize_ids(second))


func test_a_passed_shift_opens_the_machine_and_a_pick_grows_the_deck() -> void:
	var run: RunState = _passed_run(5)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(run.next_shift()).is_false()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_int(run.machine.prizes().size()).is_equal(3)
	assert_object(MachineSteps.take(run, 0)).is_not_null()
	assert_int(run.deck.size()).is_equal(14)
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_array(run.machine.prizes()).is_empty()
	assert_object(MachineSteps.take(run, 0)).is_null()


func test_at_the_deck_limit_a_card_must_be_replaced() -> void:
	var run: RunState = _passed_run(7)
	var bread: CardDefinition = load(BREAD)
	while run.deck.size() < run.balance.deck_limit:
		run.deck.add_card(bread)
	assert_bool(run.deck_is_full()).is_true()
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_bool(run.machine.needs_replace(run, 1)).is_true()
	assert_object(run.machine.pick(run, 1)).is_null()
	var replaced: CardInstance = run.deck.cards[0]
	assert_object(run.machine.pick(run, 1, replaced)).is_not_null()
	assert_int(run.deck.size()).is_equal(run.balance.deck_limit)
	assert_bool(run.deck.cards.has(replaced)).is_false()


func test_a_bin_keeps_the_deck() -> void:
	var run: RunState = _passed_run(8)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_bool(run.machine.bin(run)).is_true()
	assert_int(run.deck.size()).is_equal(13)
	assert_bool(run.machine.bin(run)).is_false()


## Only the run's first NEW ITEMS draw is the combination draw: the flag is spent at the draw.
func test_only_the_first_new_items_draw_is_the_combination_draw() -> void:
	var run: RunState = _passed_run(9)
	assert_bool(run.machine.coupons_first_done).is_false()
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	assert_bool(run.machine.coupons_first_done).is_true()
	MachineSteps.next_shift(run)
	_fill_and_pass(run)
	assert_bool(run.machine.coupons_first_done).is_true()


func test_the_last_shift_wins_without_a_visit() -> void:
	# Late quotas expect upgrades (plan v0.28): a copy whose every quota the row below passes.
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	var quotas: PackedInt32Array = PackedInt32Array()
	quotas.resize(balance.quotas.size())
	quotas.fill(1)
	balance.quotas = quotas
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(10, deck, balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(run.shift_count() - 1)
	assert_bool(run.is_last_shift()).is_true()
	# Milk, Multipack, then four Milks at x3 (they share Dairy): 4 + 0 + 3 * (5 + 6 + 7 + 8) = 82.
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	var result: ScoreResult = run.checkout()
	assert_int(result.total).is_equal(82)
	assert_int(result.total).is_greater_equal(run.quota())
	assert_object(run.machine.current_visit()).is_null()
	assert_int(run.phase).is_equal(RunState.Phase.WON)


static func _passed_run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	_fill_and_pass(run)
	return run


## Milk, Multipack, then five Milks: 109, enough for the first five quotas.
static func _fill_and_pass(run: RunState) -> void:
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()


static func _stock() -> Array[CardDefinition]:
	return RunStock.starting(load(BALANCE)).cards


static func _prize_ids(run: RunState) -> Array:
	return run.machine.prizes().map(func(prize: MachinePrize) -> StringName: return prize.id())
