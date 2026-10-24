extends GdUnitTestSuite
## The Banana chain (issue #106, plan section 5): a Banana immediately after a Banana adds the
## previous Banana's price, so 4 Bananas pay 2, 4, 6, 8. The chain's first Banana pays its full
## price, multipliers included, and that price seeds the chain; anything between two Bananas
## starts a new chain; a multiplier reaching the middle of a chain pays once and never carries.
## Big Banana adds the previous price, Golden Banana twice it. The cards are built here, so
## tuning data/ never changes these rows; the frozen fixtures keep the old pair rule.

const V0_4 := "res://tests/fixtures/cards_v0_4"


func test_chain_rows(
	row: String,
	payouts: Array,
	_test_parameters := [
		# 4 plain Bananas: each adds the previous one's price.
		["banana,banana,banana,banana", [2, 4, 6, 8]],
		# Eggs ×2 on the chain's first Banana: its final price 4 seeds the chain.
		["eggs,banana,banana,banana,banana", [1, 4, 6, 8, 10]],
		# A product between two Bananas breaks the chain: the next one is a new first Banana,
		# its own Eggs ×2 counts, and its price seeds the new chain.
		["banana,banana,eggs,banana,banana", [2, 4, 1, 4, 6]],
		# A coupon between them breaks it too: the lone Banana pays its base.
		["banana,banana,coupon,banana", [2, 4, 0, 2]],
		# Golden Eggs ×2 on the next 2 Food: the second Banana (2 + 4) × 2 = 12 pays it, but
		# the third adds its price before the multiplier, 6: 2 + 6 = 8, not 2 + 12.
		["golden_eggs,banana,banana,banana", [3, 4, 12, 8]],
		# 2 for 1 links the first two (2 + 2) × 2 = 8; the next adds 4, not 8.
		["banana,two_for_one,banana,banana", [2, 0, 8, 6]],
		# Big Banana adds the previous price on top of its base 4.
		["banana,big", [2, 6]],
		["big,big", [4, 8]],
		# Golden Banana adds twice the previous price.
		["banana,golden", [2, 8]],
		["golden,golden", [4, 12]],
		# Mixed tiers: what passes on is the previous Banana's price, whatever its tier.
		["banana,big,golden,banana", [2, 6, 16, 18]],
		["golden,banana,big", [4, 6, 10]],
		# 2 for 1 links a plain and a Big Banana: (4 + 2) × 2.
		["banana,two_for_one,big", [2, 0, 12]],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	assert_array(Array(result.payouts)).is_equal(payouts)
	assert_int(Scoring.total(_row(row))).is_equal(result.total)


## Rule bender (coupons don't break adjacency): the chain runs on through a coupon.
func test_rule_bender_keeps_the_chain_through_a_coupon() -> void:
	var bender: UpgradeDefinition = UpgradeDefinition.new()
	bender.id = &"rule_bender"
	bender.rules.append(CouponBridgeRule.new())
	var upgrades: Array[UpgradeDefinition] = [bender]
	var result: ScoreResult = Scoring.score(_row("banana,banana,coupon,banana"), upgrades)
	assert_array(Array(result.payouts)).is_equal([2, 4, 0, 6])


## The chain bonus is one FLAT step per link, worth the bonus, with the rule's receipt text,
## so the receipt and the count-up show it like any other bonus; only a lone Banana fizzles.
func test_each_link_is_one_flat_step() -> void:
	var flats: Array = []
	var wasted: Array = []
	for step: ScoreStep in Scoring.score(_row("banana,banana,golden,eggs,banana")).steps:
		if step.step_type == ScoreStep.StepType.FLAT:
			flats.append([step.slot, step.value, step.value_after, step.text])
		elif step.step_type == ScoreStep.StepType.WASTED:
			wasted.append([step.slot, step.reason])
	assert_array(flats).is_equal([[1, 2, 4, "Banana chain"], [2, 8, 12, "Banana chain"]])
	assert_array(wasted).is_equal([[4, "no Banana beside it"]])


## The frozen fixtures' Banana keeps the old pair rule (+ its base): other cards using
## AdjacentMatchBonusRule without the chain are unchanged.
func test_the_pair_rule_without_the_chain_is_unchanged() -> void:
	var banana: CardDefinition = load("%s/banana.tres" % V0_4)
	var cheese: CardDefinition = load("%s/cheese.tres" % V0_4)
	var bread: CardDefinition = load("%s/bread.tres" % V0_4)
	var row: Array[CardInstance] = []
	for card: CardDefinition in [banana, banana, banana, bread, cheese]:
		row.append(CardInstance.new(card, row.size() + 1))
	assert_array(Array(Scoring.score(row).payouts)).is_equal([2, 4, 4, 3, 7])


static func _row(ids: String) -> Array[CardInstance]:
	var cards: Dictionary[String, CardDefinition] = _cards()
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(cards[id], row.size() + 1))
	return row


static func _cards() -> Dictionary[String, CardDefinition]:
	var banana: CardDefinition = _banana("banana", 2, 1)
	var big: CardDefinition = _banana("banana_big", 4, 1)
	var golden: CardDefinition = _banana("banana_golden", 4, 2)
	big.variant_of = banana
	golden.variant_of = banana
	var coupon: CardDefinition = _card("coupon", 0)
	coupon.kind = CardDefinition.Kind.COUPON
	var two_for_one: CardDefinition = _card("two_for_one", 0)
	two_for_one.kind = CardDefinition.Kind.COUPON
	var linking: TwoForOneRule = TwoForOneRule.new()
	linking.factor = 2
	two_for_one.rules.append(linking)
	return {
		"banana": banana,
		"big": big,
		"golden": golden,
		"eggs": _eggs("eggs", 1, 1),
		"golden_eggs": _eggs("golden_eggs", 3, 2),
		"coupon": coupon,
		"two_for_one": two_for_one,
	}


static func _banana(id: String, base: int, bonus_factor: int) -> CardDefinition:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.SAME_CARD
	rule.position = AdjacentMatchBonusRule.Position.IMMEDIATELY_AFTER
	rule.bonus_is_previous_price = true
	rule.bonus_factor = bonus_factor
	rule.receipt_text = "Banana chain"
	var card: CardDefinition = _card(id, base)
	card.display_name = "Banana"
	card.tags = PackedStringArray(["Food", "Produce"])
	card.rules.append(rule)
	return card


## Eggs: ×2 on the next `charges` Food products.
static func _eggs(id: String, base: int, charges: int) -> CardDefinition:
	var rule: GrantChargedMultiplierRule = GrantChargedMultiplierRule.new()
	rule.tag = "Food"
	rule.factor = 2
	rule.charges = charges
	rule.group = &"egg_charges"
	var card: CardDefinition = _card(id, base)
	card.tags = PackedStringArray(["Food", "Breakfast"])
	card.rules.append(rule)
	return card


static func _card(id: String, base: int) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.display_name = id.capitalize()
	card.kind = CardDefinition.Kind.PRODUCT
	card.base = base
	return card
