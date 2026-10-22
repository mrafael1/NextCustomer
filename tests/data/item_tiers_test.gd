extends GdUnitTestSuite
## The live item tiers (#77, build spec 1.2-1.3): data/item_upgrades/ holds one chain per
## upgradable product, each tier card is a variant of its plain card with the same kind, tags and
## rule wording, and a tier scores as its base card wherever "same product" counts. These values
## are tuned between playtests (balance pass 7.3), so the expected totals here change with them.

const CARDS_DIR := "res://data/cards"
const CHAINS_DIR := "res://data/item_upgrades"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const DECKS_DIR := "res://data/decks"


func test_every_chain_is_well_formed() -> void:
	var products: Array[StringName] = []
	for chain: ItemUpgradeDefinition in _chains():
		var plain: CardDefinition = chain.product
		var message: String = String(plain.id)
		products.append(plain.id)
		assert_int(plain.tier).override_failure_message(message).is_equal(CardDefinition.Tier.PLAIN)
		assert_object(plain.variant_of).override_failure_message(message).is_null()
		assert_bool(plain.is_product()).override_failure_message(message).is_true()
		assert_int(chain.big.tier).override_failure_message(message).is_equal(
			CardDefinition.Tier.BIG
		)
		assert_int(chain.golden.tier).override_failure_message(message).is_equal(
			CardDefinition.Tier.GOLDEN
		)
		for tier: CardDefinition in [chain.big, chain.golden]:
			var where: String = String(tier.id)
			assert_str(where).is_equal(
				"%s_%s" % [plain.id, "big" if tier == chain.big else "golden"]
			)
			assert_object(tier.variant_of).override_failure_message(where).is_same(plain)
			assert_array(tier.variant_problems()).override_failure_message(where).is_empty()
			assert_int(tier.kind).override_failure_message(where).is_equal(plain.kind)
			assert_array(tier.tags).override_failure_message(where).is_equal(plain.tags)
			assert_bool(tier.generally_useful).is_equal(plain.generally_useful)
			assert_object(tier.unlock_condition).override_failure_message(where).is_null()
			assert_bool(tier.is_same_product(plain)).override_failure_message(where).is_true()
			assert_int(tier.base).override_failure_message(where).is_greater(plain.base)
			assert_int(tier.rules.size()).override_failure_message(where).is_equal(
				plain.rules.size()
			)
			for index: int in range(plain.rules.size()):
				var own: Rule = tier.rules[index]
				var base_rule: Rule = plain.rules[index]
				# Its own rule resource, never the plain card's shared one.
				assert_bool(own == base_rule).override_failure_message(where).is_false()
				assert_str(own.get_script().resource_path).is_equal(
					base_rule.get_script().resource_path
				)
				assert_str(own.receipt_text).override_failure_message(where).is_equal(
					base_rule.receipt_text
				)
				if "group" in base_rule:
					assert_that(own.get("group")).is_equal(base_rule.get("group"))
	assert_array(products).contains_exactly_in_any_order([&"banana", &"milk", &"eggs", &"coffee"])


## Every tier card is in exactly one chain, and every card in a chain's tiers is a tier card.
func test_tiers_are_exactly_the_chains_cards() -> void:
	var chained: Array[CardDefinition] = []
	for chain: ItemUpgradeDefinition in _chains():
		chained.append_array([chain.big, chain.golden])
	var tiers: Array[CardDefinition] = []
	for card: CardDefinition in _cards():
		if card.tier != CardDefinition.Tier.PLAIN:
			tiers.append(card)
	assert_int(tiers.size()).is_equal(8)
	assert_array(chained).contains_exactly_in_any_order(tiers)


## Tiers are run upgrades, not unlocks: the catalogue lists none, and no aisle or deck stocks
## them. A tier still counts as its product's aisle (build spec 1.2, "same product").
func test_tiers_are_never_catalogued_or_stocked() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var stocked: Array[CardDefinition] = []
	for aisle: AisleDefinition in balance.aisles:
		stocked.append_array(aisle.base_cards)
		stocked.append_array(aisle.capsule_cards)
	for file: String in DirAccess.get_files_at(DECKS_DIR):
		if file.ends_with(".tres"):
			stocked.append_array((load("%s/%s" % [DECKS_DIR, file]) as DeckDefinition).cards)
	for chain: ItemUpgradeDefinition in _chains():
		for tier: CardDefinition in [chain.big, chain.golden]:
			var where: String = String(tier.id)
			assert_bool(catalogue.variants.has(tier)).override_failure_message(where).is_false()
			assert_bool(stocked.has(tier)).override_failure_message(where).is_false()
			assert_object(balance.aisle_of(tier)).override_failure_message(where).is_same(
				balance.aisle_of(chain.product)
			)


## The changed numbers (build spec 1.3, placeholders tuned in 7.3) and the stickers they show.
func test_tier_values_and_stickers(
	id: String,
	base: int,
	sticker: String,
	_test_parameters := [
		["banana_big", 4, "+4 after Banana"],
		["banana_golden", 4, "+8 after Banana"],
		["milk_big", 6, "+1 per earlier Breakfast"],
		["milk_golden", 6, "+2 per earlier Breakfast"],
		["eggs_big", 3, "×2 next Food"],
		["eggs_golden", 3, "×2 next 2 Food"],
		["coffee_big", 4, "+3 next Breakfast"],
		["coffee_golden", 4, "+6 next Breakfast"],
	]
) -> void:
	var card: CardDefinition = _card(id)
	assert_int(card.base).is_equal(base)
	assert_str(card.sticker_summary()).is_equal(sticker)


## What the hover card highlights: the sticker values a tier changes from the tier below it.
func test_changed_fields_from_the_tier_below(
	product: String,
	big_changes: PackedStringArray,
	golden_changes: PackedStringArray,
	_test_parameters := [
		["banana", PackedStringArray(["base", "bonus"]), PackedStringArray(["bonus"])],
		["milk", PackedStringArray(["base"]), PackedStringArray(["bonus_each"])],
		["eggs", PackedStringArray(["base"]), PackedStringArray(["charges"])],
		["coffee", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
	]
) -> void:
	var plain: CardDefinition = _card(product)
	var big: CardDefinition = _card(product + "_big")
	var golden: CardDefinition = _card(product + "_golden")
	assert_array(CardText.changed_fields(plain, big)).is_equal(big_changes)
	assert_array(CardText.changed_fields(big, golden)).is_equal(golden_changes)


## A tier counts as its base card (plan section 3.4, "same product"): the Banana pair across
## tiers, 2 for 1 across tiers, Golden Eggs' two charges, Golden Coffee's +6.
func test_tiers_score_as_their_product(
	row: String,
	payouts: Array,
	_test_parameters := [
		# Big Banana 4 + its base 4 after a plain Banana.
		["banana,banana_big", [2, 8]],
		# Golden Banana 4 + its base counted twice after a Big Banana.
		["banana_big,banana_golden", [4, 12]],
		# A plain Banana after a Golden one: + its own base 2.
		["banana_golden,banana", [4, 4]],
		# 2 for 1 links a plain and a Big Banana: (4 + 4) × 2.
		["banana,two_for_one,banana_big", [2, 0, 16]],
		# Golden Eggs doubles the next 2 Food: Bread 5 × 2 twice.
		["eggs_golden,bread,bread,bread", [3, 10, 10, 5]],
		# Big Eggs keeps one charge.
		["eggs_big,bread,bread", [3, 10, 5]],
		# Golden Coffee 4, +6 to Milk (4 + 1 earlier Breakfast + 6).
		["coffee_golden,milk", [4, 11]],
		# Coffee's +3 goes to Eggs; Golden Milk (6 + 2 x 2 earlier Breakfast) x2 from Eggs.
		["coffee,eggs,milk_golden", [2, 4, 20]],
	]
) -> void:
	var instances: Array[CardInstance] = []
	for id: String in row.split(","):
		instances.append(CardInstance.new(_card(id), instances.size() + 1))
	assert_array(Array(Scoring.score(instances).payouts)).is_equal(payouts)


func _chains() -> Array[ItemUpgradeDefinition]:
	var chains: Array[ItemUpgradeDefinition] = []
	for file: String in DirAccess.get_files_at(CHAINS_DIR):
		if file.ends_with(".tres"):
			var chain: ItemUpgradeDefinition = load("%s/%s" % [CHAINS_DIR, file])
			assert_str(String(chain.product.id)).is_equal(file.get_basename())
			chains.append(chain)
	return chains


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS_DIR, file]) as CardDefinition)
	return cards


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS_DIR, id]) as CardDefinition
