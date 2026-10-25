extends GdUnitTestSuite
## Which cards a card works with (CardAffinity, #105 piece 3, the mix highlight; mock-up
## readability v3's ruleHits): a family rule names that family's products (a broad family, Food,
## only WEAKly), a product rule names that product and its tiers, a pair rule its own product, a
## penalty its tag's products as a PENALTY and coupon counting every coupon, both ways round; the
## other rules name nothing. Every rule the cards in data/cards use is read or listed.

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS_DIR := "res://data/cards"


func test_a_family_rule_names_its_family_and_food_weakly() -> void:
	var milk: CardDefinition = _live("milk")
	var bread: CardDefinition = _live("bread")
	var batteries: CardDefinition = _live("batteries")
	# Milk counts earlier Breakfast: Bread is Breakfast.
	assert_int(_between(milk, bread)).is_equal(CardAffinity.Match.YES)
	assert_int(_between(bread, milk)).is_equal(CardAffinity.Match.YES)
	assert_int(_between(milk, batteries)).is_equal(CardAffinity.Match.NONE)
	# Eggs' "×2 next Food": every Food product, but only weakly.
	var eggs: CardDefinition = _live("eggs")
	assert_int(_between(eggs, _live("strawberries"))).is_equal(CardAffinity.Match.WEAK)
	assert_int(_between(eggs, batteries)).is_equal(CardAffinity.Match.NONE)
	# Eggs and Milk: Milk counts Eggs as Breakfast, which beats Eggs' weak Food.
	assert_int(_between(eggs, milk)).is_equal(CardAffinity.Match.YES)
	# Coffee's next Breakfast, Frozen peas beside Frozen.
	assert_int(_between(_live("coffee"), _live("tea_bags"))).is_equal(CardAffinity.Match.YES)
	assert_int(_between(_live("frozen_peas"), _live("frozen_peas"))).is_equal(
		CardAffinity.Match.YES
	)


func test_granted_tags_count_where_they_are_given() -> void:
	var milk: CardDefinition = _live("milk")
	var batteries: CardDefinition = _live("batteries")
	var tagged: PackedStringArray = batteries.tags.duplicate()
	tagged.append("Breakfast")
	assert_int(CardAffinity.between(milk, milk.tags, batteries, tagged, _broad())).is_equal(
		CardAffinity.Match.YES
	)


## A tag grant (Breakfast sticker, Clearance tag) names the cards its granted tag feeds: those
## counting, boosting or pairing with that tag, both ways round; not the cards that only carry it.
func test_a_tag_grant_names_the_cards_its_tag_feeds() -> void:
	var sticker: CardDefinition = _live("breakfast_sticker")
	for id: String in ["milk", "coffee"]:
		assert_int(_between(sticker, _live(id))).override_failure_message(id).is_equal(
			CardAffinity.Match.YES
		)
		assert_int(_between(_live(id), sticker)).override_failure_message(id).is_equal(
			CardAffinity.Match.YES
		)
	assert_int(_between(sticker, _live("batteries"))).is_equal(CardAffinity.Match.NONE)
	var clearance: CardDefinition = _live("clearance_tag")
	for id: String in ["dented_can", "flickering_bulb"]:
		assert_int(_between(clearance, _live(id))).override_failure_message(id).is_equal(
			CardAffinity.Match.YES
		)
	assert_int(_between(clearance, _live("milk"))).is_equal(CardAffinity.Match.NONE)
	assert_int(CardAffinity.uses_tag(_live("milk"), "Breakfast", _broad())).is_equal(
		CardAffinity.Match.YES
	)
	assert_int(CardAffinity.uses_tag(_live("soup"), "Frozen", _broad())).is_equal(
		CardAffinity.Match.PENALTY
	)
	assert_int(CardAffinity.uses_tag(_live("eggs"), "Food", _broad())).is_equal(
		CardAffinity.Match.WEAK
	)


func test_a_penalty_beats_a_match() -> void:
	var soup: CardDefinition = _live("soup")
	var peas: CardDefinition = _live("frozen_peas")
	assert_int(_between(soup, peas)).is_equal(CardAffinity.Match.PENALTY)
	assert_int(_between(peas, soup)).is_equal(CardAffinity.Match.PENALTY)
	assert_int(_between(soup, _live("bread"))).is_equal(CardAffinity.Match.NONE)


func test_coupon_counting_names_every_coupon() -> void:
	var scissors: CardDefinition = _live("scissors")
	assert_int(_between(scissors, _live("multipack"))).is_equal(CardAffinity.Match.YES)
	assert_int(_between(_live("two_for_one"), scissors)).is_equal(CardAffinity.Match.YES)
	assert_int(_between(scissors, _live("bread"))).is_equal(CardAffinity.Match.NONE)


func test_a_product_rule_names_that_product_and_its_tiers() -> void:
	var cheese: CardDefinition = _live("cheese")
	for target: String in ["bread", "bread_big", "bread_golden"]:
		assert_int(_between(cheese, _live(target))).override_failure_message(target).is_equal(
			CardAffinity.Match.YES
		)
	assert_int(_between(_live("cheese_golden"), _live("bread"))).is_equal(CardAffinity.Match.YES)
	assert_int(_between(cheese, _live("milk"))).is_equal(CardAffinity.Match.NONE)


func test_a_pair_rule_names_its_own_product_across_tiers() -> void:
	var banana: CardDefinition = _live("banana")
	assert_int(_between(banana, _live("banana_golden"))).is_equal(CardAffinity.Match.YES)
	assert_int(_between(_live("banana_big"), banana)).is_equal(CardAffinity.Match.YES)
	assert_int(_between(banana, _live("bread"))).is_equal(CardAffinity.Match.NONE)


func test_rules_naming_no_card_name_nothing() -> void:
	var anything: Array[CardDefinition] = [_live("bread"), _live("multipack"), _live("milk")]
	for id: String in ["multipack", "two_for_one", "batteries"]:
		var card: CardDefinition = _live(id)
		for rule: Rule in card.rules:
			for other: CardDefinition in anything:
				(
					assert_int(CardAffinity.rule_names(rule, card, other, other.tags, _broad()))
					. override_failure_message("%s > %s" % [id, other.id])
					. is_equal(CardAffinity.Match.NONE)
				)


func test_in_family() -> void:
	assert_bool(CardAffinity.in_family(PackedStringArray(["Food", "Dairy"]), "Dairy")).is_true()
	assert_bool(CardAffinity.in_family(PackedStringArray(["Food"]), "Dairy")).is_false()
	assert_bool(CardAffinity.in_family(PackedStringArray(["Food"]), "")).is_false()


## The guard: every rule on every card in data/cards is read (it can name cards) or listed as
## naming none, so a new rule class can't silently match nothing.
func test_every_rule_in_the_data_is_read() -> void:
	var seen: int = 0
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if not file.ends_with(".tres"):
			continue
		seen += 1
		var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
		for rule: Rule in card.rules:
			var rule_name: String = String(rule.get_script().get_global_name())
			(
				assert_bool(CardAffinity.reads(rule))
				. override_failure_message("%s: %s" % [file, rule_name])
				. is_true()
			)
	assert_int(seen).is_equal(LiveCardCount.CARDS)
	for listed: String in CardAffinity.NAMES_NONE:
		(
			assert_bool(FileAccess.file_exists("res://core/rules/%s.gd" % listed.to_snake_case()))
			. override_failure_message(listed)
			. is_true()
		)


static func _between(a: CardDefinition, b: CardDefinition) -> CardAffinity.Match:
	return CardAffinity.between(a, a.tags, b, b.tags, _broad())


static func _broad() -> PackedStringArray:
	return FamilyPalette.shared().quiet_families


static func _live(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS_DIR, id]) as CardDefinition
