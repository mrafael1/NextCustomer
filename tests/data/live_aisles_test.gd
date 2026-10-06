extends GdUnitTestSuite
## Aisle and stock rules on the live data/ files (full build plan 7.2). The aisle-size rules
## (6–9 items per complete aisle) start in phase 2, with the real aisles.

const AISLE_DIR := "res://data/aisles"
const CARD_DIR := "res://data/cards"
const DECK_DIR := "res://data/decks"
const BALANCE := "res://data/balance/balance.tres"


## Every aisle file has an id matching its name, a name, at least one product, and is one of
## the balance data's aisles (exactly once).
func test_every_aisle_is_well_formed_and_in_the_balance_data() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var files: Array[String] = _tres_files(AISLE_DIR)
	assert_int(files.size()).is_equal(balance.aisles.size())
	for file: String in files:
		var aisle: AisleDefinition = load("%s/%s" % [AISLE_DIR, file])
		assert_str(String(aisle.id)).override_failure_message(file).is_equal(file.get_basename())
		assert_str(aisle.display_name).override_failure_message(file).is_not_empty()
		var size: int = aisle.base_cards.size() + aisle.capsule_cards.size()
		assert_int(size).override_failure_message(file).is_greater(0)
		assert_int(balance.aisles.count(aisle)).override_failure_message(file).is_equal(1)


## Coupons are never in aisles or capsules; aisles hold products only.
func test_aisles_hold_products_only() -> void:
	for aisle: AisleDefinition in (load(BALANCE) as BalanceDefinition).aisles:
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			assert_bool(card.is_product()).override_failure_message(String(card.id)).is_true()


## Every product is a staple of some deck or in exactly one aisle, never both.
func test_every_product_is_a_staple_or_in_exactly_one_aisle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var staples: Array[CardDefinition] = []
	for file: String in _tres_files(DECK_DIR):
		staples.append_array(RunStock.staples(load("%s/%s" % [DECK_DIR, file])))
	for file: String in _tres_files(CARD_DIR):
		var card: CardDefinition = load("%s/%s" % [CARD_DIR, file])
		if not card.is_product():
			continue
		var homes: int = 0
		for aisle: AisleDefinition in balance.aisles:
			homes += (aisle.base_cards + aisle.capsule_cards).count(card)
		if staples.has(card):
			assert_int(homes).override_failure_message(file).is_equal(0)
		else:
			assert_int(homes).override_failure_message(file).is_equal(1)


func test_aisles_hold_at_most_two_generally_useful_products() -> void:
	for aisle: AisleDefinition in (load(BALANCE) as BalanceDefinition).aisles:
		var useful: int = 0
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			if card.generally_useful:
				useful += 1
		assert_int(useful).override_failure_message(String(aisle.id)).is_less_equal(2)


## So the reward guarantee always has a candidate.
func test_every_deck_has_at_least_two_generally_useful_staples() -> void:
	for file: String in _tres_files(DECK_DIR):
		var useful: int = 0
		for card: CardDefinition in RunStock.staples(load("%s/%s" % [DECK_DIR, file])):
			if card.generally_useful:
				useful += 1
		assert_int(useful).override_failure_message(file).is_greater_equal(2)


## Every run stocks all of coupon_pool, so the first offer's combination coupons are in it.
func test_coupon_pool_holds_coupons_and_the_first_offer_pool() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for card: CardDefinition in balance.coupon_pool:
		assert_bool(card.is_coupon()).override_failure_message(String(card.id)).is_true()
	for card: CardDefinition in balance.first_offer_pool:
		(
			assert_bool(balance.coupon_pool.has(card))
			. override_failure_message(String(card.id))
			. is_true()
		)


func test_stock_numbers_match_the_plan() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(balance.run_aisle_picks).is_equal(2)
	assert_int(balance.aisle_stock_budget).is_equal(16)
	assert_int(balance.aisle_listable_min).is_equal(4)
	assert_int(balance.end_cap_max).is_equal(3)
	assert_int(balance.end_cap_window_runs).is_equal(3)


## Phase 1's placeholder base aisle: Cheese and Frozen peas, so the budget rule stocks it and
## the starting stock is the prototype's reward pool.
func test_the_placeholder_aisle_holds_cheese_and_frozen_peas() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(balance.aisles.size()).is_equal(1)
	var aisle: AisleDefinition = balance.aisles[0]
	(
		assert_array(aisle.base_cards.map(func(card: CardDefinition) -> StringName: return card.id))
		. is_equal([&"cheese", &"frozen_peas"])
	)
	assert_array(aisle.capsule_cards).is_empty()
	var unlocked: Dictionary[StringName, int] = {}
	assert_bool(RunStock.needs_list(balance, unlocked)).is_false()


static func _tres_files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			files.append(file)
	return files
