extends GdUnitTestSuite
## The live item tiers (#77, build spec 1.2-1.3): data/item_upgrades/ holds one chain per
## upgradable product, each tier card is a variant of its plain card with the same kind, tags and
## rule wording, and a tier scores as its base card wherever "same product" counts. These values
## are tuned between playtests (balance pass 7.3), so the expected totals here change with them.

const CARDS_DIR := "res://data/cards"
const CHAINS_DIR := "res://data/item_upgrades"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const DECKS_DIR := "res://data/decks"
## The products with a chain: the starter's 4 (#77), then Bread, Soup and the 14 base aisle
## items (#89 data, v0.48), then the 30 capsule products, aisle by aisle (#89 + #58, v0.52).
const CHAINED: Array[StringName] = [
	&"banana",
	&"milk",
	&"eggs",
	&"coffee",
	&"bread",
	&"soup",
	&"cheese",
	&"frozen_peas",
	&"butter",
	&"yogurt",
	&"reduced_yogurt",
	&"cereal",
	&"tea_bags",
	&"crackers",
	&"dented_can",
	&"day_old_buns",
	&"carrier_bag",
	&"scissors",
	&"batteries",
	&"flickering_bulb",
	&"baguette",
	&"scone",
	&"croissant",
	&"broken_biscuit",
	&"iced_bun",
	&"birthday_candles",
	&"squashed_cake",
	&"stale_doughnut",
	&"cream",
	&"ham_ends",
	&"fruit_salad",
	&"strawberries",
	&"grapefruit",
	&"wonky_carrot",
	&"lemon",
	&"bruised_apples",
	&"soft_tomatoes",
	&"potatoes",
	&"egg_timer",
	&"chipped_mug",
	&"odd_socks",
	&"sugar_cubes",
	&"mixed_herbs",
	&"crisps",
	&"cereal_bar",
	&"bent_lolly",
	&"pick_n_mix",
	&"stale_popcorn",
	&"breadsticks",
	&"dusty_toffees",
]
## The tier rule (v0.48): BIG adds `TIER_BASE_STEP` to the base and keeps the rule; GOLDEN keeps
## BIG's base and doubles the bonus (`bonus`, `bonus_each`, or `bonus_factor` when the bonus is the
## base), a charged multiplier gains 1 charge instead, and a card with no bonus (Bread, Soup,
## Potatoes) adds `TIER_BASE_STEP` to the base again. HAND_SET lists the GOLDEN rule values set by
## hand instead (plan section 7.2): Carrier bag's +5 per earlier Food would double to +10 each.
const TIER_BASE_STEP := 2
const HAND_SET: Dictionary[StringName, Dictionary] = {&"carrier_bag": {"bonus_each": 7}}
const DOUBLED_FIELDS: Array[String] = ["bonus", "bonus_each"]


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
	assert_array(products).contains_exactly_in_any_order(CHAINED)


## Every tier card is in exactly one chain, and every card in a chain's tiers is a tier card.
func test_tiers_are_exactly_the_chains_cards() -> void:
	var chained: Array[CardDefinition] = []
	for chain: ItemUpgradeDefinition in _chains():
		chained.append_array([chain.big, chain.golden])
	var tiers: Array[CardDefinition] = []
	for card: CardDefinition in _cards():
		if card.tier != CardDefinition.Tier.PLAIN:
			tiers.append(card)
	assert_int(tiers.size()).is_equal(2 * CHAINED.size())
	assert_array(chained).contains_exactly_in_any_order(tiers)


## Tiers are run upgrades, not unlocks: the catalogue lists none, and no aisle or deck stocks
## them. A tier still counts as its product's aisle (build spec 1.2, "same product").
func test_tiers_are_never_catalogued_or_stocked() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var balance: BalanceDefinition = load(BALANCE)
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


## Every chain follows the tier rule (v0.48, see TIER_BASE_STEP), or its documented HAND_SET
## value: BIG keeps the plain card's rule, GOLDEN changes only its bonus (or charges).
func test_every_chain_follows_the_tier_rule() -> void:
	var flat: Array[StringName] = []
	for chain: ItemUpgradeDefinition in _chains():
		var plain: CardDefinition = chain.product
		var where: String = String(plain.id)
		assert_int(chain.big.base).override_failure_message(where).is_equal(
			plain.base + TIER_BASE_STEP
		)
		var bonuses: int = 0
		for index: int in range(plain.rules.size()):
			var plain_rule: Rule = plain.rules[index]
			var big_rule: Rule = chain.big.rules[index]
			var golden_rule: Rule = chain.golden.rules[index]
			for key: String in _rule_fields(plain_rule):
				var message: String = "%s.%s" % [where, key]
				assert_that(big_rule.get(key)).override_failure_message(message).is_equal(
					plain_rule.get(key)
				)
				var expected: Variant = _golden_value(big_rule, key)
				if expected != big_rule.get(key):
					bonuses += 1
				var hand_set: Dictionary = HAND_SET.get(plain.id, {})
				if hand_set.has(key):
					expected = hand_set[key]
				assert_that(golden_rule.get(key)).override_failure_message(message).is_equal(
					expected
				)
		if bonuses == 0:
			flat.append(plain.id)
		var golden_base: int = chain.big.base + (TIER_BASE_STEP if bonuses == 0 else 0)
		assert_int(chain.golden.base).override_failure_message(where).is_equal(golden_base)
	assert_array(flat).contains_exactly_in_any_order([&"bread", &"soup", &"potatoes"])
	for id: StringName in HAND_SET:
		assert_array(CHAINED).contains([id])


## The machine's UPGRADES chute (its `item_upgrades` table) can step every chained product: a
## plain copy goes to BIG (COMMON) or straight to GOLDEN (RARE), and SHELF UPGRADE needs its
## `shelf_min_copies`.
func test_upgrades_can_step_every_chained_product() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var machine: MachineDefinition = balance.machine
	var table: Array[ItemUpgradeDefinition] = machine.item_upgrades
	var listed: Array[StringName] = []
	for chain: ItemUpgradeDefinition in table:
		listed.append(chain.product.id)
	assert_array(listed).contains_exactly_in_any_order(CHAINED)
	for id: StringName in CHAINED:
		var where: String = String(id)
		var plain: CardDefinition = _card(where)
		var deck: Deck = Deck.new(null)
		deck.add_card(plain)
		for rarity: int in [ItemUpgrades.COMMON, ItemUpgrades.RARE]:
			var offered: bool = ItemUpgrades.can_offer(
				table, machine.shelf_min_copies, deck, plain, rarity
			)
			assert_bool(offered).override_failure_message(where).is_true()
		assert_object(ItemUpgrades.tier_step(table, plain, 1)).is_same(_card(where + "_big"))
		var steps: int = ItemUpgrades.step_count(ItemUpgrades.RARE)
		assert_object(ItemUpgrades.tier_step(table, plain, steps)).is_same(_card(where + "_golden"))
		var shelf: bool = ItemUpgrades.can_offer(
			table, machine.shelf_min_copies, deck, plain, ItemUpgrades.LEGENDARY
		)
		assert_bool(shelf).override_failure_message(where).is_equal(machine.shelf_min_copies <= 1)
		deck.add_card(_card(where + "_big"))
		shelf = ItemUpgrades.can_offer(
			table, machine.shelf_min_copies, deck, plain, ItemUpgrades.LEGENDARY
		)
		assert_bool(shelf).override_failure_message(where).is_equal(machine.shelf_min_copies <= 2)


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
		["bread_big", 7, ""],
		["bread_golden", 9, ""],
		["soup_big", 7, "Pays nothing beside Frozen"],
		["soup_golden", 9, "Pays nothing beside Frozen"],
		["cheese_big", 5, "+4 after Bread"],
		["cheese_golden", 5, "+8 after Bread"],
		["frozen_peas_big", 5, "+5 beside Frozen"],
		["frozen_peas_golden", 5, "+10 beside Frozen"],
		["butter_big", 4, "+3 beside Bakery"],
		["butter_golden", 4, "+6 beside Bakery"],
		["yogurt_big", 4, "+3 after Banana"],
		["yogurt_golden", 4, "+6 after Banana"],
		["reduced_yogurt_big", 4, "+3 beside Clearance"],
		["reduced_yogurt_golden", 4, "+6 beside Clearance"],
		["cereal_big", 4, "+3 beside Milk"],
		["cereal_golden", 4, "+6 beside Milk"],
		["tea_bags_big", 3, "×4 next Breakfast"],
		["tea_bags_golden", 3, "×4 next 2 Breakfast"],
		["crackers_big", 4, "+3 beside Soup"],
		["crackers_golden", 4, "+6 beside Soup"],
		["dented_can_big", 4, "+2 per earlier Clearance"],
		["dented_can_golden", 4, "+4 per earlier Clearance"],
		["day_old_buns_big", 4, "+3 after Clearance"],
		["day_old_buns_golden", 4, "+6 after Clearance"],
		["carrier_bag_big", 3, "+5 per earlier Food"],
		["carrier_bag_golden", 3, "+7 per earlier Food"],
		["scissors_big", 3, "+2 per earlier coupon"],
		["scissors_golden", 3, "+4 per earlier coupon"],
		["batteries_big", 3, "+4 in last slot"],
		["batteries_golden", 3, "+8 in last slot"],
		["flickering_bulb_big", 3, "+3 next Clearance"],
		["flickering_bulb_golden", 3, "+6 next Clearance"],
		# A few of the capsule products' (v0.52): the charged multipliers and the flat Potatoes.
		["lemon_big", 3, "×2 next Produce"],
		["lemon_golden", 3, "×2 next 2 Produce"],
		["iced_bun_golden", 3, "×2 next 2 Bakery"],
		["squashed_cake_golden", 4, "×2 next 2 Clearance"],
		["potatoes_big", 5, ""],
		["potatoes_golden", 7, ""],
		["pick_n_mix_golden", 3, "+4 per earlier Snack"],
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
		["bread", PackedStringArray(["base"]), PackedStringArray(["base"])],
		["soup", PackedStringArray(["base"]), PackedStringArray(["base"])],
		["cheese", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["frozen_peas", PackedStringArray(["base", "bonus"]), PackedStringArray(["bonus"])],
		["butter", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["yogurt", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["reduced_yogurt", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["cereal", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["tea_bags", PackedStringArray(["base"]), PackedStringArray(["charges"])],
		["crackers", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["dented_can", PackedStringArray(["base"]), PackedStringArray(["bonus_each"])],
		["day_old_buns", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["carrier_bag", PackedStringArray(["base"]), PackedStringArray(["bonus_each"])],
		["scissors", PackedStringArray(["base"]), PackedStringArray(["bonus_each"])],
		["batteries", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["flickering_bulb", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
		["lemon", PackedStringArray(["base"]), PackedStringArray(["charges"])],
		["potatoes", PackedStringArray(["base"]), PackedStringArray(["base"])],
		["mixed_herbs", PackedStringArray(["base"]), PackedStringArray(["bonus"])],
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
		# Golden Cheese 5 + 8 after Bread; a plain Cheese still matches a Big Bread.
		["bread,cheese_golden", [5, 13]],
		["bread_big,cheese", [7, 7]],
		# A Frozen pair across tiers: plain 3 + 3, Golden 5 + twice its base.
		["frozen_peas,frozen_peas_golden", [6, 15]],
		# Golden Tea bags: ×4 on the next 2 Breakfast payouts (Bread 5).
		["tea_bags_golden,bread,bread,bread", [3, 20, 20, 5]],
		# Golden Carrier bag 3 + 7 per earlier Food (hand-set).
		["bread,soup,carrier_bag_golden", [5, 5, 17]],
		# Golden Soup still pays 0 beside a Frozen product.
		["soup_golden,frozen_peas", [0, 3]],
	]
) -> void:
	var instances: Array[CardInstance] = []
	for id: String in row.split(","):
		instances.append(CardInstance.new(_card(id), instances.size() + 1))
	assert_array(Array(Scoring.score(instances).payouts)).is_equal(payouts)


## The rule's own exported fields (its numbers, tags and names).
static func _rule_fields(rule: Rule) -> Array[String]:
	var found: Array[String] = []
	for property: Dictionary in rule.get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			found.append(String(property["name"]))
	return found


## A BIG rule field's GOLDEN value under the tier rule: a charged multiplier gains 1 charge, a
## bonus that is the base counts twice (`bonus_factor`), any other bonus doubles.
static func _golden_value(rule: Rule, key: String) -> Variant:
	var value: Variant = rule.get(key)
	if rule is GrantChargedMultiplierRule and key == "charges":
		return int(value) + 1
	var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
	if adjacent != null and key == "bonus_factor":
		return int(value) * 2 if adjacent.bonus_is_base else value
	if DOUBLED_FIELDS.has(key):
		return int(value) * 2
	return value


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
