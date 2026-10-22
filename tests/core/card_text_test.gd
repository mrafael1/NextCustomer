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


## Keys outside STICKER_KEYS (enums, bools, the card's id) stay unformatted, braces
## and all, so the live-data test catches them instead of printing "2" for an enum.
func test_other_keys_are_left_unformatted() -> void:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.TAG
	rule.position = AdjacentMatchBonusRule.Position.BESIDE
	rule.bonus_is_base = true
	var card: CardDefinition = _card("Frozen peas", 3, rule)
	card.sticker_text = "{match_by} {position} {bonus_is_base} {id} {receipt_text}"
	assert_str(card.sticker_summary()).is_equal(card.sticker_text)
	assert_array(CardText.sticker_values(card).keys()).contains_exactly_in_any_order(
		["base", "name", "bonus", "match_value"]
	)


## A charged multiplier's charges are a sticker key (Golden Eggs, #77).
func test_fills_charges() -> void:
	var charged: GrantChargedMultiplierRule = GrantChargedMultiplierRule.new()
	charged.tag = "Food"
	charged.factor = 2
	charged.charges = 2
	var eggs: CardDefinition = _card("Golden eggs", 3, charged)
	eggs.sticker_text = "×{factor} next {charges} {tag}"
	assert_str(eggs.sticker_summary()).is_equal("×2 next 2 Food")


## A match bonus counted twice (Golden Banana, #77): `{bonus}` is what a match pays, the base
## counted `bonus_factor` times; `{base}` stays the base.
func test_bonus_reads_the_bonus_factor() -> void:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = AdjacentMatchBonusRule.Match.SAME_CARD
	rule.position = AdjacentMatchBonusRule.Position.IMMEDIATELY_AFTER
	rule.bonus_is_base = true
	rule.bonus_factor = 2
	var banana: CardDefinition = _card("Banana", 4, rule)
	banana.sticker_text = "+{bonus} after {name}, €{base}"
	assert_str(banana.sticker_summary()).is_equal("+8 after Banana, €4")
	var flat: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	flat.match_by = AdjacentMatchBonusRule.Match.TAG
	flat.match_value = "Produce"
	flat.position = AdjacentMatchBonusRule.Position.BESIDE
	flat.bonus = 3
	flat.bonus_factor = 2
	var berries: CardDefinition = _card("Strawberries", 2, flat)
	berries.sticker_text = "+{bonus} beside {match_value}"
	assert_str(berries.sticker_summary()).is_equal("+6 beside Produce")


## changed_fields lists the sticker values (base, then the rule keys) that differ between two
## cards, e.g. an item tier and the tier below it; a card against itself has none.
func test_changed_fields_between_tiers() -> void:
	var plain_rule: GrantChargedMultiplierRule = GrantChargedMultiplierRule.new()
	plain_rule.tag = "Food"
	plain_rule.factor = 2
	plain_rule.charges = 1
	var plain: CardDefinition = _card("Eggs", 1, plain_rule)
	var big: CardDefinition = _card("Big eggs", 3, plain_rule)
	var golden_rule: GrantChargedMultiplierRule = plain_rule.duplicate()
	golden_rule.charges = 2
	var golden: CardDefinition = _card("Golden eggs", 3, golden_rule)
	assert_array(CardText.changed_fields(plain, big)).is_equal(PackedStringArray(["base"]))
	assert_array(CardText.changed_fields(big, golden)).is_equal(PackedStringArray(["charges"]))
	assert_array(CardText.changed_fields(plain, golden)).is_equal(
		PackedStringArray(["base", "charges"])
	)
	assert_array(CardText.changed_fields(golden, golden)).is_empty()
	# A card with no rule against one with a rule: every key the rule has differs.
	var bread: CardDefinition = _card("Bread", 1, null)
	assert_array(CardText.changed_fields(bread, plain)).is_equal(
		PackedStringArray(["factor", "charges", "tag"])
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
