extends GdUnitTestSuite
## The price sticker's summary (CardText, #75): a card's digit-free template filled in from its
## own data, with only CardText.STICKER_KEYS, a variant falling back to its base card's template
## and `{bonus}` meaning the base when the rule's bonus is its base. Built on cards made here, so
## tuning data/ never changes these.


func test_fills_the_keys_from_the_card_and_its_rule() -> void:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.TAG
	rule.match_value = "Produce"
	rule.position = AdjacentMatchBonusRule.Position.BESIDE
	rule.bonus = 3
	var card: CardDefinition = _card("Strawberries", 2, rule)
	card.sticker_text = "€{base} {name}: +{bonus} beside {match_value}"
	assert_str(card.sticker_summary()).is_equal("€2 Strawberries: +3 beside Produce")
	assert_str(CardText.sticker_summary(card)).is_equal(card.sticker_summary())


func test_fills_tags_factors_and_counts() -> void:
	var charged: GrantChargedMultiplierRule = GrantChargedMultiplierRule.new()
	charged.tag = "Food"
	charged.factor = 2
	charged.charges = 1
	var eggs: CardDefinition = _card("Eggs", 1, charged)
	eggs.sticker_text = "×{factor} next {tag}"
	assert_str(eggs.sticker_summary()).is_equal("×2 next Food")
	var counting: CountEarlierTagBonusRule = CountEarlierTagBonusRule.new()
	counting.tag = "Breakfast"
	counting.bonus_each = 1
	var milk: CardDefinition = _card("Milk", 4, counting)
	milk.sticker_text = "+{bonus_each} per earlier {tag}"
	assert_str(milk.sticker_summary()).is_equal("+1 per earlier Breakfast")


## Banana's bonus is its own base: `{bonus}` and `{base}` both read the base, not the rule's 0.
func test_bonus_is_base_reads_the_base() -> void:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.SAME_CARD
	rule.position = AdjacentMatchBonusRule.Position.IMMEDIATELY_AFTER
	rule.bonus_is_base = true
	var banana: CardDefinition = _card("Banana", 2, rule)
	banana.sticker_text = "+{bonus} or +{base} after {name}"
	assert_str(banana.sticker_summary()).is_equal("+2 or +2 after Banana")


## Keys outside STICKER_KEYS (enums, charges, bools, the card's id) stay unformatted, braces
## and all, so the live-data test catches them instead of printing "2" for an enum.
func test_other_keys_are_left_unformatted() -> void:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.TAG
	rule.position = AdjacentMatchBonusRule.Position.BESIDE
	rule.bonus_is_base = true
	var card: CardDefinition = _card("Frozen peas", 3, rule)
	card.sticker_text = "{match_by} {position} {bonus_is_base} {id} {charges} {receipt_text}"
	assert_str(card.sticker_summary()).is_equal(card.sticker_text)
	assert_array(CardText.sticker_values(card).keys()).contains_exactly_in_any_order(
		["base", "name", "bonus", "match_value"]
	)


## A card with no rule has an empty template: its sticker shows only the price. A template on
## a card with no rule can still name the card's base and name.
func test_a_card_with_no_rule() -> void:
	var bread: CardDefinition = _card("Bread", 5, null)
	assert_str(bread.sticker_summary()).is_empty()
	bread.sticker_text = "{name} €{base}, {bonus}"
	assert_str(bread.sticker_summary()).is_equal("Bread €5, {bonus}")


## A variant with no template of its own takes its base card's, filled in from the variant's own
## data; `{name}` is the product's name, which the variant shares with its base card. Its own
## template wins.
func test_a_variant_falls_back_to_its_base_cards_template() -> void:
	var base_rule: LastSlotBonusRule = LastSlotBonusRule.new()
	base_rule.bonus = 3
	var batteries: CardDefinition = _card("Batteries", 1, base_rule)
	batteries.sticker_text = "+{bonus} in last slot, {name}"
	var variant_rule: LastSlotBonusRule = LastSlotBonusRule.new()
	variant_rule.bonus = 5
	var variant: CardDefinition = _card("Long-life batteries", 2, variant_rule)
	variant.variant_of = batteries
	assert_str(CardText.sticker_template(variant)).is_equal(batteries.sticker_text)
	assert_str(variant.sticker_summary()).is_equal("+5 in last slot, Batteries")
	variant.sticker_text = "+{bonus} last, €{base}"
	assert_str(variant.sticker_summary()).is_equal("+5 last, €2")
	assert_str(batteries.sticker_summary()).is_equal("+3 in last slot, Batteries")


## Formatting changes nothing on the shared definition or its rule.
func test_formatting_leaves_the_card_unchanged() -> void:
	var rule: GrantNextTagBonusRule = GrantNextTagBonusRule.new()
	rule.tag = "Breakfast"
	rule.bonus = 3
	var coffee: CardDefinition = _card("Coffee", 2, rule)
	coffee.sticker_text = "+{bonus} next {tag}"
	assert_str(coffee.sticker_summary()).is_equal("+3 next Breakfast")
	assert_str(coffee.sticker_summary()).is_equal("+3 next Breakfast")
	assert_str(coffee.sticker_text).is_equal("+{bonus} next {tag}")
	assert_int(rule.bonus).is_equal(3)


static func _card(display_name: String, base: int, rule: Rule) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(display_name.to_snake_case())
	card.display_name = display_name
	card.kind = CardDefinition.Kind.PRODUCT
	card.base = base
	if rule != null:
		card.rules.append(rule)
	return card
