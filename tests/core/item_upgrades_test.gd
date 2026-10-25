extends GdUnitTestSuite
## Item tiers (#77, build spec 1.3-1.4): Deck.upgrade replaces one copy and leaves the others
## alone, ItemUpgrades picks the copies a prize steps up by its rarity, and the Golden Banana's
## chain bonus counts twice (`bonus_factor`, decided with the user). The chains and the Banana
## rows are built here, so tuning data/ never changes them; the upgraded-copy test uses the live
## Milk chain, as issue #77 asks.

const MILK_CHAIN := "res://data/item_upgrades/milk.tres"
const COFFEE := "res://data/cards/coffee.tres"


## Issue #77: an upgraded copy scores its upgraded value; the other copies of the same item don't
## change. The upgrade keeps the copy's id and place, and never touches the old instance.
func test_an_upgraded_copy_scores_its_upgraded_value() -> void:
	var chain: ItemUpgradeDefinition = load(MILK_CHAIN)
	var deck: Deck = Deck.new(RandomNumberGenerator.new())
	var coffee: CardInstance = deck.add_card(load(COFFEE))
	var first: CardInstance = deck.add_card(chain.product)
	var second: CardInstance = deck.add_card(chain.product)
	var upgraded: CardInstance = deck.upgrade(first, chain.big)
	assert_object(upgraded.definition).is_same(chain.big)
	assert_int(upgraded.instance_id).is_equal(first.instance_id)
	assert_array(deck.cards).is_equal([coffee, upgraded, second])
	assert_object(first.definition).is_same(chain.product)
	assert_object(second.definition).is_same(chain.product)
	# Coffee 2; Milk base + 1 per earlier Breakfast (Coffee) + Coffee's 3.
	var plain_total: int = 2 + chain.product.base + 1 + 3
	var big_total: int = 2 + chain.big.base + 1 + 3
	assert_int(chain.big.base).is_greater(chain.product.base)
	assert_int(Scoring.score(_row([coffee, second])).total).is_equal(plain_total)
	assert_int(Scoring.score(_row([coffee, upgraded])).total).is_equal(big_total)
	# The old instance, still held by a checked-out row, scores as it did.
	assert_int(Scoring.score(_row([coffee, first])).total).is_equal(plain_total)


func test_upgrading_a_card_outside_the_deck_does_nothing() -> void:
	var chain: ItemUpgradeDefinition = _chain("milk")
	var deck: Deck = Deck.new(RandomNumberGenerator.new())
	var kept: CardInstance = deck.add_card(chain.product)
	var stranger: CardInstance = CardInstance.new(chain.product, 99)
	assert_object(deck.upgrade(stranger, chain.big)).is_null()
	assert_array(deck.cards).is_equal([kept])


## A missing step (past GOLDEN, outside a chain) or another product's card never reaches the deck.
func test_upgrading_to_no_card_or_another_product_does_nothing() -> void:
	var chain: ItemUpgradeDefinition = _chain("milk")
	var deck: Deck = Deck.new(RandomNumberGenerator.new())
	var kept: CardInstance = deck.add_card(chain.golden)
	assert_object(deck.upgrade(kept, null)).is_null()
	assert_object(deck.upgrade(kept, _chain("banana").big)).is_null()
	assert_array(deck.cards).is_equal([kept])
	assert_object(kept.definition).is_same(chain.golden)


func test_chains_and_tier_steps() -> void:
	var milk: ItemUpgradeDefinition = _chain("milk")
	var eggs: ItemUpgradeDefinition = _chain("eggs")
	var table: Array[ItemUpgradeDefinition] = [milk, eggs]
	assert_object(ItemUpgrades.chain_for(table, eggs.big)).is_same(eggs)
	assert_object(ItemUpgrades.chain_for(table, milk.golden)).is_same(milk)
	assert_object(ItemUpgrades.tier_step(table, milk.product, 1)).is_same(milk.big)
	assert_object(ItemUpgrades.tier_step(table, milk.product, 2)).is_same(milk.golden)
	assert_object(ItemUpgrades.tier_step(table, milk.big, 1)).is_same(milk.golden)
	assert_object(ItemUpgrades.tier_step(table, milk.big, 2)).is_null()
	assert_object(ItemUpgrades.tier_step(table, milk.golden, 1)).is_null()
	assert_int(ItemUpgrades.step_count(ItemUpgrades.COMMON)).is_equal(1)
	assert_int(ItemUpgrades.step_count(ItemUpgrades.RARE)).is_equal(2)
	assert_int(ItemUpgrades.step_count(ItemUpgrades.LEGENDARY)).is_equal(1)
	# A same-product card that isn't one of the chain's own (another variant) never joins it.
	var organic: CardDefinition = _card("organic_milk", 4)
	organic.variant_of = milk.product
	assert_object(ItemUpgrades.chain_for(table, organic)).is_null()
	assert_object(ItemUpgrades.tier_step(table, organic, 1)).is_null()
	assert_object(ItemUpgrades.chain_for(table, _card("bread", 5))).is_null()


## COMMON steps the most advanced copy that can step (BIG before plain, ties to the lowest deck
## index), RARE the first plain copy, LEGENDARY every copy below GOLDEN; GOLDEN copies, other
## products and same-product variants outside the chain are never targets.
func test_targets_by_rarity() -> void:
	var milk: ItemUpgradeDefinition = _chain("milk")
	var table: Array[ItemUpgradeDefinition] = [milk]
	var organic: CardDefinition = _card("organic_milk", 4)
	organic.variant_of = milk.product
	var deck: Deck = Deck.new(RandomNumberGenerator.new())
	deck.add_card(_card("bread", 5))
	var plain_a: CardInstance = deck.add_card(milk.product)
	deck.add_card(milk.golden)
	deck.add_card(organic)
	var big_a: CardInstance = deck.add_card(milk.big)
	var plain_b: CardInstance = deck.add_card(milk.product)
	var big_b: CardInstance = deck.add_card(milk.big)
	assert_array(_targets(table, deck, milk.product, ItemUpgrades.COMMON)).is_equal([big_a])
	assert_array(_targets(table, deck, milk.product, ItemUpgrades.RARE)).is_equal([plain_a])
	assert_array(_targets(table, deck, milk.product, ItemUpgrades.LEGENDARY)).is_equal(
		[plain_a, big_a, plain_b, big_b]
	)
	# Only plain copies: COMMON takes the first one.
	var plain_only: Deck = Deck.new(RandomNumberGenerator.new())
	var first: CardInstance = plain_only.add_card(milk.product)
	plain_only.add_card(milk.product)
	assert_array(_targets(table, plain_only, milk.product, ItemUpgrades.COMMON)).is_equal([first])
	# A product outside every chain has no targets.
	var bread: CardDefinition = _card("bread", 5)
	assert_array(_targets(table, deck, bread, ItemUpgrades.COMMON)).is_empty()


func test_can_offer_needs_a_copy_that_can_step() -> void:
	var milk: ItemUpgradeDefinition = _chain("milk")
	var table: Array[ItemUpgradeDefinition] = [milk]
	var deck: Deck = Deck.new(RandomNumberGenerator.new())
	deck.add_card(milk.golden)
	for rarity: int in [ItemUpgrades.COMMON, ItemUpgrades.RARE, ItemUpgrades.LEGENDARY]:
		assert_bool(ItemUpgrades.can_offer(table, 2, deck, milk.product, rarity)).is_false()
	deck.add_card(milk.big)
	assert_bool(ItemUpgrades.can_offer(table, 2, deck, milk.product, ItemUpgrades.COMMON)).is_true()
	# RARE needs a plain copy; SHELF UPGRADE needs 2 copies below GOLDEN.
	assert_bool(ItemUpgrades.can_offer(table, 2, deck, milk.product, ItemUpgrades.RARE)).is_false()
	(
		assert_bool(ItemUpgrades.can_offer(table, 2, deck, milk.product, ItemUpgrades.LEGENDARY))
		. is_false()
	)
	deck.add_card(milk.product)
	assert_bool(ItemUpgrades.can_offer(table, 2, deck, milk.product, ItemUpgrades.RARE)).is_true()
	(
		assert_bool(ItemUpgrades.can_offer(table, 2, deck, milk.product, ItemUpgrades.LEGENDARY))
		. is_true()
	)
	(
		assert_bool(ItemUpgrades.can_offer(table, 3, deck, milk.product, ItemUpgrades.LEGENDARY))
		. is_false()
	)


## Applying each rarity's targets with its step: COMMON BIG to GOLDEN, RARE plain to GOLDEN,
## SHELF UPGRADE one step on every copy below GOLDEN; the deck keeps its size and order.
func test_applying_targets_steps_each_copy() -> void:
	var milk: ItemUpgradeDefinition = _chain("milk")
	var table: Array[ItemUpgradeDefinition] = [milk]
	var deck: Deck = Deck.new(RandomNumberGenerator.new())
	deck.add_card(milk.product)
	deck.add_card(milk.big)
	deck.add_card(milk.product)
	_apply(table, deck, milk.product, ItemUpgrades.LEGENDARY)
	assert_array(_definitions(deck)).is_equal([milk.big, milk.golden, milk.big])
	_apply(table, deck, milk.product, ItemUpgrades.COMMON)
	assert_array(_definitions(deck)).is_equal([milk.golden, milk.golden, milk.big])
	deck.add_card(milk.product)
	_apply(table, deck, milk.product, ItemUpgrades.RARE)
	assert_array(_definitions(deck)).is_equal([milk.golden, milk.golden, milk.big, milk.golden])


## Decided with the user (#77 answer 1, plan section 3.4; the chain since #106): the Golden
## Banana's chain bonus counts twice. Banana 2 and Big Banana 4 (+ the previous Banana's price
## after a Banana); Golden Banana 4 (+ twice that price).
func test_golden_banana_chain_counts_twice(
	row: String,
	payouts: Array,
	total: int,
	_test_parameters := [
		["banana,golden", [2, 8], 10],
		["golden,banana", [4, 6], 10],
		["golden,golden", [4, 12], 16],
		["banana,big", [2, 6], 8],
		["big,golden", [4, 12], 16],
		["golden,big", [4, 8], 12],
		["golden", [4], 4],
	]
) -> void:
	var cards: Dictionary[String, CardDefinition] = _bananas()
	var instances: Array[CardInstance] = []
	for id: String in row.split(","):
		instances.append(CardInstance.new(cards[id], instances.size() + 1))
	var result: ScoreResult = Scoring.score(instances)
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(result.total).is_equal(total)


## The doubled bonus is one FLAT step worth the whole bonus, with the rule's receipt text.
func test_golden_banana_bonus_is_one_step() -> void:
	var cards: Dictionary[String, CardDefinition] = _bananas()
	var row: Array[CardInstance] = [
		CardInstance.new(cards["banana"], 1), CardInstance.new(cards["golden"], 2)
	]
	var flats: Array = []
	for step: ScoreStep in Scoring.score(row).steps:
		if step.step_type == ScoreStep.StepType.FLAT:
			flats.append([step.slot, step.value, step.text])
	assert_array(flats).is_equal([[1, 4, "Banana chain"]])


static func _bananas() -> Dictionary[String, CardDefinition]:
	var banana: CardDefinition = _banana("banana", 2, 1)
	var big: CardDefinition = _banana("banana_big", 4, 1)
	var golden: CardDefinition = _banana("banana_golden", 4, 2)
	big.variant_of = banana
	golden.variant_of = banana
	return {"banana": banana, "big": big, "golden": golden}


static func _banana(id: String, base: int, bonus_factor: int) -> CardDefinition:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.SAME_CARD
	rule.position = AdjacentMatchBonusRule.Position.IMMEDIATELY_AFTER
	rule.bonus_is_previous_price = true
	rule.bonus_factor = bonus_factor
	rule.receipt_text = "Banana chain"
	var card: CardDefinition = _card(id, base)
	card.tags = PackedStringArray(["Food", "Produce"])
	card.rules.append(rule)
	return card


static func _chain(id: String) -> ItemUpgradeDefinition:
	var chain: ItemUpgradeDefinition = ItemUpgradeDefinition.new()
	chain.product = _card(id, 4)
	chain.big = _card(id + "_big", 6)
	chain.big.variant_of = chain.product
	chain.big.tier = CardDefinition.Tier.BIG
	chain.golden = _card(id + "_golden", 6)
	chain.golden.variant_of = chain.product
	chain.golden.tier = CardDefinition.Tier.GOLDEN
	return chain


static func _card(id: String, base: int) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.display_name = id.capitalize()
	card.kind = CardDefinition.Kind.PRODUCT
	card.base = base
	return card


static func _targets(
	table: Array[ItemUpgradeDefinition], deck: Deck, product: CardDefinition, rarity: int
) -> Array:
	return Array(ItemUpgrades.targets(table, deck, product, rarity))


static func _apply(
	table: Array[ItemUpgradeDefinition], deck: Deck, product: CardDefinition, rarity: int
) -> void:
	for card: CardInstance in ItemUpgrades.targets(table, deck, product, rarity):
		var to: CardDefinition = ItemUpgrades.tier_step(
			table, card.definition, ItemUpgrades.step_count(rarity)
		)
		deck.upgrade(card, to)


static func _definitions(deck: Deck) -> Array:
	var found: Array = []
	for card: CardInstance in deck.cards:
		found.append(card.definition)
	return found


static func _row(cards: Array[CardInstance]) -> Array[CardInstance]:
	return cards.duplicate()
