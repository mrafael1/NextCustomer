extends GdUnitTestSuite
## Aisle and stock rules on the live data/ files (full build plan 7.2), including the aisle-size
## rule (6–9 items per complete aisle) since the capsule aisles of issue #35.

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


## Every product is a staple (the balance's list, v0.49) or in exactly one aisle, never both.
## Item tiers (#77) are run upgrades from the machine, never stocked: they are in no aisle and
## skipped here.
func test_every_product_is_a_staple_or_in_exactly_one_aisle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var staples: Array[CardDefinition] = RunStock.staples(balance)
	for file: String in _tres_files(CARD_DIR):
		var card: CardDefinition = load("%s/%s" % [CARD_DIR, file])
		if not card.is_product() or card.tier != CardDefinition.Tier.PLAIN:
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
func test_the_staples_hold_at_least_two_generally_useful_products() -> void:
	var useful: int = 0
	for card: CardDefinition in RunStock.staples(load(BALANCE)):
		if card.generally_useful:
			useful += 1
	assert_int(useful).is_greater_equal(2)


## Every deck's products (a fixed deck's cards, a recipe's core cards) are staples, so a run
## stocks every product it starts with (v0.49: the staples are their own list).
func test_every_decks_fixed_and_core_cards_are_staples() -> void:
	var staples: Array[CardDefinition] = RunStock.staples(load(BALANCE))
	for file: String in _tres_files(DECK_DIR):
		var deck: DeckDefinition = load("%s/%s" % [DECK_DIR, file])
		for card: CardDefinition in deck.cards + deck.core_cards:
			if card.is_product():
				(
					assert_bool(staples.has(card))
					. override_failure_message("%s: %s" % [file, card.id])
					. is_true()
				)


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


## The 6 aisles (issues #34 and #35, decided with the user): the 3 base aisles hold 5/5/4
## products open from the start, 14 in all, within the stock budget, so a new profile stocks every
## one and skips the list; their machines add 2/2/3 capsules. The 3 machine-opened aisles hold
## 8/8/7 capsules and no base products. Each capsule list starts with its key item: Cream, Sugar
## cubes, Egg timer, Fruit salad, Baguette, Crisps.
func test_the_aisles_hold_the_agreed_products() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var base: Dictionary[StringName, Array] = {
		&"cold_cases": [&"cheese", &"frozen_peas", &"butter", &"yogurt", &"reduced_yogurt"],
		&"pantry": [&"cereal", &"tea_bags", &"crackers", &"dented_can", &"day_old_buns"],
		&"household": [&"carrier_bag", &"scissors", &"batteries", &"flickering_bulb"],
		&"fruit_and_veg": [],
		&"bakery": [],
		&"snacks": [],
	}
	var capsules: Dictionary[StringName, Array] = {
		&"cold_cases": [&"cream", &"ham_ends"],
		&"pantry": [&"sugar_cubes", &"mixed_herbs"],
		&"household": [&"egg_timer", &"chipped_mug", &"odd_socks"],
		&"fruit_and_veg":
		[
			&"fruit_salad",
			&"strawberries",
			&"grapefruit",
			&"wonky_carrot",
			&"lemon",
			&"bruised_apples",
			&"soft_tomatoes",
			&"potatoes",
		],
		&"bakery":
		[
			&"baguette",
			&"scone",
			&"croissant",
			&"broken_biscuit",
			&"iced_bun",
			&"birthday_candles",
			&"squashed_cake",
			&"stale_doughnut",
		],
		&"snacks":
		[
			&"crisps",
			&"cereal_bar",
			&"bent_lolly",
			&"pick_n_mix",
			&"stale_popcorn",
			&"breadsticks",
			&"dusty_toffees",
		],
	}
	(
		assert_array(
			balance.aisles.map(func(aisle: AisleDefinition) -> StringName: return aisle.id)
		)
		. is_equal(base.keys())
	)
	var products: int = 0
	var capsule_count: int = 0
	for aisle: AisleDefinition in balance.aisles:
		assert_array(_ids(aisle.base_cards)).is_equal(base[aisle.id])
		assert_array(_ids(aisle.capsule_cards)).is_equal(capsules[aisle.id])
		products += aisle.base_cards.size()
		capsule_count += aisle.capsule_cards.size()
	assert_int(products).is_equal(14)
	assert_int(capsule_count).is_equal(30)
	assert_int(products).is_less_equal(balance.aisle_stock_budget)
	var unlocked: Dictionary[StringName, int] = {}
	assert_bool(RunStock.needs_list(balance, unlocked)).is_false()


## Full build plan 7.2: a complete aisle (every capsule unlocked) holds 6 to 9 items.
func test_complete_aisles_hold_six_to_nine_items() -> void:
	for aisle: AisleDefinition in (load(BALANCE) as BalanceDefinition).aisles:
		var size: int = aisle.base_cards.size() + aisle.capsule_cards.size()
		assert_int(size).override_failure_message(String(aisle.id)).is_between(6, 9)


## Machine-opened aisles can be cut whole, with their machines (full build plan section 10): no
## staple and no card of a base aisle names one of their cards, or a tag only they print.
func test_machine_opened_aisles_can_be_cut_whole() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var kept: Array[CardDefinition] = RunStock.staples(balance)
	var cuttable: Array[CardDefinition] = []
	for aisle: AisleDefinition in balance.aisles:
		if aisle.base_cards.is_empty():
			cuttable.append_array(aisle.capsule_cards)
		else:
			kept.append_array(aisle.base_cards + aisle.capsule_cards)
	assert_array(cuttable).is_not_empty()
	var kept_tags: Array[String] = []
	for card: CardDefinition in kept:
		for tag: String in card.tags:
			if not kept_tags.has(tag):
				kept_tags.append(tag)
	var only_cuttable: Array[String] = []
	for card: CardDefinition in cuttable:
		only_cuttable.append(String(card.id))
		for tag: String in card.tags:
			if not kept_tags.has(tag) and not only_cuttable.has(tag):
				only_cuttable.append(tag)
	for card: CardDefinition in kept:
		for rule: Rule in card.rules:
			for field: String in ["tag", "match_value"]:
				var named: Variant = rule.get(field)
				if named is String:
					(
						assert_bool(only_cuttable.has(named))
						. override_failure_message("%s names %s" % [card.id, named])
						. is_false()
					)


static func _ids(cards: Array[CardDefinition]) -> Array:
	return cards.map(func(card: CardDefinition) -> StringName: return card.id)


static func _tres_files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			files.append(file)
	return files


## The cards' aisle mark (#55): every aisle product finds its own aisle; staples and coupons
## find none.
func test_aisle_of_finds_each_products_aisle() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var checked: int = 0
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			assert_object(balance.aisle_of(card)).override_failure_message(String(card.id)).is_same(
				aisle
			)
			checked += 1
	assert_int(checked).is_greater(0)
	var staples: Array[CardDefinition] = RunStock.staples(balance)
	assert_int(staples.size()).is_greater(0)
	for card: CardDefinition in staples:
		assert_object(balance.aisle_of(card)).override_failure_message(String(card.id)).is_null()
	for card: CardDefinition in balance.coupon_pool:
		assert_object(balance.aisle_of(card)).override_failure_message(String(card.id)).is_null()
	assert_object(balance.aisle_of(null)).is_null()
	# A variant (made here; none is in data yet) counts as its base product.
	var aisle: AisleDefinition = balance.aisles[0]
	var variant: CardDefinition = CardDefinition.new()
	variant.id = &"test_variant"
	variant.kind = CardDefinition.Kind.PRODUCT
	variant.variant_of = (aisle.base_cards + aisle.capsule_cards)[0]
	assert_object(balance.aisle_of(variant)).is_same(aisle)


## Every aisle has its glyph (art/icons/aisle_<id>.png), shown on its products' cards.
func test_every_aisle_has_a_glyph() -> void:
	for aisle: AisleDefinition in (load(BALANCE) as BalanceDefinition).aisles:
		var path: String = ArtStyle.glyph_path(aisle)
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


## A capsule costs at least one coin (#63, full build plan 7.1): 1 in balance.tres, which the
## TOY MACHINES' "1 coin" copy reads.
func test_a_capsule_costs_at_least_one_coin() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	assert_int(balance.capsule_price).is_greater_equal(1)
	assert_int(balance.capsule_price).is_equal(1)


## Every aisle of the balance has its TOY MACHINE, its capsule and its shelf sign (#63, built from
## art/src by the aisle derives).
func test_every_aisle_has_its_toy_machine_art() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	for aisle: AisleDefinition in balance.aisles:
		for path: String in [
			"res://art/scenery/toy_machine_%s.png" % aisle.id,
			"res://art/scenery/toy_capsule_%s.png" % aisle.id,
			"res://art/frames/aisle_sign_%s.png" % aisle.id,
		]:
			assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
