extends GdUnitTestSuite
## Tests on the live data/ files. Unlike the golden rows, these expected values are updated
## when card values are tuned between playtest rounds (plan section 3.7).

const CARDS_DIR := "res://data/cards"
const STARTER := "res://data/decks/starter.tres"
const PLACEHOLDER := "\\{([a-z_]+)\\}"
const ORDINAL := "\\d+(st|nd|rd|th)"
## A number that isn't an ordinal ("2nd" stays): the data's numbers, which balance passes change.
const NUMBER := "\\d+(?!st|nd|rd|th)"


func test_live_cards_score_the_design_examples() -> void:
	# The design doc's 31 / 18 (kept on the frozen fixture) with Eggs' 1 charge and Bread 5 (#42).
	assert_int(Scoring.score(_row("eggs,bread,cheese,banana,banana,repeat")).total).is_equal(28)
	assert_int(Scoring.score(_row("banana,repeat,bread,eggs,banana,cheese")).total).is_equal(17)


func test_starter_deck_matches_the_plan() -> void:
	var deck: DeckDefinition = load(STARTER)
	var counts: Dictionary = {}
	for card: CardDefinition in deck.cards:
		counts[card.id] = int(counts.get(card.id, 0)) + 1
	(
		assert_dict(counts)
		. is_equal(
			{
				&"banana": 3,
				&"bread": 2,
				&"milk": 2,
				&"eggs": 2,
				&"coffee": 2,
				&"soup": 1,
				&"final_markdown": 1,
			}
		)
	)


## The phase 2 cards' rows (the base products, #34; 2 for 1 and Shelf swap, #37; Clearance tag
## and Opening deal, #36; the capsule items, #35), worked out by hand from the rules.
func test_phase_2_cards_score_the_design_examples(
	row: String,
	total: int,
	_test_parameters := [
		# Yogurt 2 x2 Eggs (its one charge); Multipack reads Yogurt's Dairy, never Food or
		# Breakfast (#42); Milk (4 + 1 x 2 earlier Breakfast) x3 Multipack = 18; 1 + 4 + 18.
		["eggs,yogurt,multipack,milk", 23],
		# Bulb 1; buns 2 + 3 after Clearance + 3 from the bulb; can 2 + 2 x 2 earlier Clearance.
		["flickering_bulb,day_old_buns,dented_can", 15],
		# Repeat copies Bread's 5; Scissors 1 + 2 for Repeat; Batteries 1 + 4 in the last slot.
		["bread,repeat,scissors,batteries", 18],
		# Butter 5, Bread 5, Crackers 5, Soup 5, Cereal 5, Milk 4 + 1 x 2 (Bread, Cereal) = 6.
		["butter,bread,crackers,soup,cereal,milk", 31],
		# Banana 2, Yogurt 5, Carrier bag 1 + 5 x 2 earlier Food, Reduced yogurt 5, Dented can 4.
		["banana,yogurt,carrier_bag,reduced_yogurt,dented_can", 27],
		# Tea bags isn't Food: Eggs skips it. Tea bags x4 on Bread: 1 + 20.
		["tea_bags,bread", 21],
		# 2 for 1 links the Bananas: the pair bonus applies, then ×2 (2 + 0 + 8).
		["banana,two_for_one,banana", 10],
		# Shelf swap: Cheese counts as just after Bread, the first product (5 + 2 + 0 + 7).
		["bread,banana,shelf_swap,cheese", 14],
		# Clearance tag makes Bread Clearance: Day-old buns 2 + 3 after it (0 + 5 + 5).
		["clearance_tag,bread,day_old_buns", 10],
		# Opening deal in the first slot: Soup pays 5 x5 (0 + 25 + 5).
		["opening_deal,soup,bread", 30],
		# Fruit & veg: Grapefruit 2; Banana 2 + 3; Lemon 1; Strawberries (2 + 3) x2; Wonky
		# carrot 2 + 3; Fruit salad 2 + 2 x 5 earlier Produce.
		["grapefruit,banana,lemon,strawberries,wonky_carrot,fruit_salad", 35],
		# Bakery: Bread 5; Iced bun 1; Birthday candles 1; Baguette (2 + 2 x 2 + 3) x2.
		["bread,iced_bun,birthday_candles,baguette", 25],
		# Snacks: Bread 5; Crisps 5; Stale popcorn 2; Cereal bar 2 + 2 + 3; Bent lolly 5; Pick 'n'
		# mix 1 + 2 x 4 earlier Snack.
		["bread,crisps,stale_popcorn,cereal_bar,bent_lolly,pick_n_mix", 33],
		# Clearance: Ham ends 2; Squashed cake 2; Reduced yogurt (2 + 3) x2; Dented can 2 + 2 x 3.
		["ham_ends,squashed_cake,reduced_yogurt,dented_can", 22],
		# Key items: Egg timer 1 + 4 after Eggs; Bread 5 x2 takes Eggs' one charge; Milk 4 + 1 x 3
		# earlier Breakfast.
		["eggs,egg_timer,bread,milk", 23],
		# Cream x2 = 4 (Eggs' one charge) and +2 to Milk: 3 + 2 + 2; Ham ends 2 + 3; Reduced
		# yogurt 2 + 3.
		["eggs,cream,milk,ham_ends,reduced_yogurt", 22],
		# Sugar cubes 2 + 4 after Coffee, not Breakfast: Coffee's +3 and Milk's count pass over
		# it. Milk 3 + 2 x 1 earlier Breakfast + 3 from Coffee (18 if Sugar cubes were Breakfast).
		["coffee,sugar_cubes,milk", 16],
		# Coffee 2; Chipped mug 1 + 3 beside Coffee; Egg timer 1 + Coffee's 3 (it is Breakfast);
		# Odd socks 1 + 2 x 2 earlier Household.
		["coffee,chipped_mug,egg_timer,odd_socks", 15],
	]
) -> void:
	assert_int(Scoring.score(_row(row)).total).is_equal(total)


## The base products' fizzles: Scissors with no earlier coupon, an unused Tea bags charge, a
## Flickering bulb with no Clearance product after it, Batteries not in the last slot.
func test_base_products_fizzle(
	row: String,
	expected: Array,
	_test_parameters := [
		["scissors", [[0, "Scissors: earlier coupons", "no coupon before it"]]],
		["bread,scissors", [[1, "Scissors: earlier coupons", "no coupon before it"]]],
		["repeat,scissors", [[0, "Repeat", "no product just before it to copy"]]],
		["tea_bags,soup", [[0, "Tea bags ×4", "1 charge unused"]]],
		["flickering_bulb,bread", [[0, "Flickering bulb bonus", "no Clearance product after it"]]],
		["batteries,bread", [[0, "Batteries last", "not in the last slot"]]],
		# The capsule items reuse these rules' fizzles (#35).
		["lemon,bread", [[0, "Lemon ×2", "1 charge unused"]]],
		["cream,bread", [[0, "Cream bonus", "no Dairy product after it"]]],
		["stale_doughnut,bread", [[0, "Stale doughnut last", "not in the last slot"]]],
		["eggs,carrier_bag,bread,bread", []],
		# Coffee is only Breakfast, which Multipack ignores (#42).
		[
			"coffee,multipack,milk",
			[[1, "Multipack ×3", "the product just before it has no tag but Food or Breakfast"]]
		],
	]
) -> void:
	var fizzles: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.source_slot, step.text, step.reason])
	assert_array(fizzles).is_equal(expected)


## 59 cards, plus the 8 item tiers (#77: BIG and GOLDEN Banana, Milk, Eggs and Coffee).
func test_all_sixty_seven_cards_exist() -> void:
	var ids: Array = []
	var tiers: int = 0
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
			ids.append(card.id)
			if card.tier != CardDefinition.Tier.PLAIN:
				tiers += 1
	assert_int(ids.size()).is_equal(67)
	assert_int(tiers).is_equal(8)


## Every card has a price-sticker template (#75); only a card with no rule has an empty one (its
## sticker shows only the price), and every template is digit-free, ordinals such as "2nd"
## aside, so a balance pass never leaves a stale number on a sticker.
func test_every_card_has_a_digit_free_sticker_template() -> void:
	var ordinal: RegEx = RegEx.create_from_string(ORDINAL)
	var digit: RegEx = RegEx.create_from_string("\\d")
	var cards: Array[CardDefinition] = _all_cards()
	assert_int(cards.size()).is_equal(67)
	for card: CardDefinition in cards:
		var template: String = CardText.sticker_template(card)
		var message: String = '%s: "%s"' % [card.id, template]
		assert_bool(template.is_empty()).override_failure_message(message).is_equal(
			card.rules.is_empty()
		)
		var without_ordinals: String = ordinal.sub(template, "", true)
		assert_object(digit.search(without_ordinals)).override_failure_message(message).is_null()


## Every key a template names is a sticker key and resolves, and the numbers on the sticker are
## exactly the data's values for those keys, read here straight from the card and its rule.
func test_sticker_numbers_come_from_the_data() -> void:
	var placeholder: RegEx = RegEx.create_from_string(PLACEHOLDER)
	var number: RegEx = RegEx.create_from_string(NUMBER)
	for card: CardDefinition in _all_cards():
		var summary: String = card.sticker_summary()
		var message: String = '%s: "%s"' % [card.id, summary]
		(
			assert_bool(summary.contains("{") or summary.contains("}"))
			. override_failure_message(message)
			. is_false()
		)
		var expected: Array[String] = []
		for found: RegExMatch in placeholder.search_all(CardText.sticker_template(card)):
			var key: String = found.get_string(1)
			assert_array(CardText.STICKER_KEYS).override_failure_message(message).contains([key])
			var value: Variant = _data_value(card, key)
			if value is int:
				expected.append(str(value))
		var shown: Array[String] = []
		for found: RegExMatch in number.search_all(summary):
			shown.append(found.get_string())
		assert_array(shown).override_failure_message(message).is_equal(expected)


## Every value that changes what a card's rule does shows on its sticker: its bonus (or base, when
## the bonus is the base), count bonus, factor, tag and matched tag. A rule that names a product
## by id (Cheese names Bread) spells it as that card's display name, and one that matches its own
## card names it.
func test_stickers_show_every_rule_value() -> void:
	var by_id: Dictionary[StringName, CardDefinition] = {}
	for card: CardDefinition in _all_cards():
		by_id[card.id] = card
	var named_products: int = 0
	for card: CardDefinition in by_id.values():
		var template: String = CardText.sticker_template(card)
		var message: String = '%s: "%s"' % [card.id, template]
		for rule: Rule in card.rules:
			for key: String in CardText.RULE_KEYS:
				var shows: bool = template.contains("{%s}" % key)
				var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
				if adjacent != null and key == "bonus" and adjacent.bonus_is_base:
					(
						assert_bool(template.contains("{base}") or shows)
						. override_failure_message(message)
						. is_true()
					)
				elif adjacent != null and key == "match_value":
					match adjacent.match_by:
						AdjacentMatchBonusRule.Match.TAG:
							assert_bool(shows).override_failure_message(message).is_true()
						AdjacentMatchBonusRule.Match.SAME_CARD:
							assert_str(template).override_failure_message(message).contains(
								"{name}"
							)
						AdjacentMatchBonusRule.Match.CARD_ID:
							var named: CardDefinition = by_id[StringName(adjacent.match_value)]
							assert_str(card.sticker_summary()).contains(named.display_name)
							assert_bool(shows).override_failure_message(message).is_false()
							named_products += 1
				elif _is_set(key, rule.get(key)):
					assert_bool(shows).override_failure_message(message + " " + key).is_true()
	# Cheese, Crisps, Breadsticks, Cereal, Chipped mug, Crackers, Egg timer, Soft tomatoes, Sugar
	# cubes and Yogurt.
	assert_int(named_products).is_equal(10)


## A charged multiplier's sticker says "next": with one charge that is the next product, so the
## sticker names no count; one with more charges (Golden Eggs, #77) names `{charges}`.
func test_charged_multipliers_with_more_charges_name_them() -> void:
	var several: int = 0
	for card: CardDefinition in _all_cards():
		for rule: Rule in card.rules:
			var charged: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
			if charged == null:
				continue
			var template: String = CardText.sticker_template(card)
			var message: String = '%s: "%s"' % [card.id, template]
			assert_int(charged.charges).override_failure_message(message).is_greater(0)
			if charged.charges > 1:
				assert_str(template).override_failure_message(message).contains("{charges}")
				several += 1
	assert_int(several).is_equal(1)


## Every art_ref names art drawn for an item (#75, decision 3A: 48x48 at 2x everywhere): a
## product's names its 48x48 sprite (ItemView.SPRITE_SIZE in art pixels), a coupon's the icon
## drawn on its slip (ItemView.COUPON_ICON_RECT in art pixels). An empty one is an undrawn item.
func test_every_art_ref_is_item_art() -> void:
	var sprite: Vector2i = Vector2i(ItemView.SPRITE_SIZE / float(ArtStyle.ART_SCALE))
	var icon: Vector2i = Vector2i(ItemView.COUPON_ICON_RECT.size / float(ArtStyle.ART_SCALE))
	assert_that(sprite).is_equal(Vector2i(48, 48))
	var drawn: int = 0
	for card: CardDefinition in _all_cards():
		if card.art_ref.is_empty():
			continue
		var message: String = "%s: %s" % [card.id, card.art_ref]
		assert_bool(ResourceLoader.exists(card.art_ref)).override_failure_message(message).is_true()
		var texture: Texture2D = load(card.art_ref) as Texture2D
		assert_object(texture).override_failure_message(message).is_not_null()
		if texture == null:
			continue
		var expected: Vector2i = icon if card.is_coupon() else sprite
		assert_that(texture.get_size()).override_failure_message(message).is_equal(
			Vector2(expected)
		)
		drawn += 1
	# The 10 products and 2 coupon icons drawn for style frame v2, the 8 item tiers (#77) and
	# #57's 13 products.
	assert_int(drawn).is_equal(33)


## The 20 products a new profile stocks (#57), read from data/: the starter deck's products and
## every base aisle's base_cards. Each has its own 48x48 sprite (art_ref), never the art-pending
## box, and no two share one.
func test_every_stocked_product_has_its_sprite() -> void:
	var products: Array[CardDefinition] = stocked_products()
	assert_int(products.size()).is_equal(20)
	var paths: Dictionary[String, StringName] = {}
	for card: CardDefinition in products:
		var message: String = "%s: %s" % [card.id, card.art_ref]
		assert_str(card.art_ref).override_failure_message(message).is_not_empty()
		var texture: Texture2D = ArtStyle.item_sprite(card)
		assert_object(texture).override_failure_message(message).is_not_same(ArtStyle.ITEM_PENDING)
		assert_that(texture.get_size()).override_failure_message(message).is_equal(Vector2(48, 48))
		assert_bool(paths.has(card.art_ref)).override_failure_message(message).is_false()
		paths[card.art_ref] = card.id


## The products a new profile stocks (full build plan 7.2): the starter deck's products, then
## every base aisle's base_cards (a machine-opened aisle has none), each once, in data order.
static func stocked_products() -> Array[CardDefinition]:
	var products: Array[CardDefinition] = []
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var cards: Array[CardDefinition] = deck.cards.duplicate()
	for aisle: AisleDefinition in balance.aisles:
		cards.append_array(aisle.base_cards)
	for card: CardDefinition in cards:
		if card.is_product() and not products.has(card):
			products.append(card)
	return products


static func _all_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			cards.append(load("%s/%s" % [CARDS_DIR, file]) as CardDefinition)
	return cards


## A sticker key's value read straight from the data (not through CardText): the card's base,
## its product's name, or the first rule's field; a match bonus is the one the rule pays for this
## base (the base or its flat bonus, times its factor), as CardText shows it.
static func _data_value(card: CardDefinition, key: String) -> Variant:
	if key == "base":
		return card.base
	if key == "name":
		return card.product_card().display_name
	for rule: Rule in card.rules:
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if key == "bonus" and adjacent != null:
			return adjacent.bonus_for(card.base)
		if key in rule:
			return rule.get(key)
	return null


## Whether a rule field holds a value that changes what the rule does (not its neutral default).
## One charge is the plain "next" the sticker already says, like a factor of 1.
static func _is_set(key: String, value: Variant) -> bool:
	if value is int:
		return value != (1 if key.ends_with("factor") or key == "charges" else 0)
	if value is String:
		return not (value as String).is_empty()
	return false


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
