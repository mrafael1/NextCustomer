extends GdUnitTestSuite
## Tests on the live data/ files. Unlike the golden rows, these expected values are updated
## when card values are tuned between playtest rounds (plan section 3.7).

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS_DIR := "res://data/cards"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const PLACEHOLDER := "\\{([a-z_]+)\\}"
const ORDINAL := "\\d+(st|nd|rd|th)"
## A number that isn't an ordinal ("2nd" stays): the data's numbers, which balance passes change.
const NUMBER := "\\d+(?!st|nd|rd|th)"


func test_live_cards_score_the_design_examples() -> void:
	# The design doc's 31 / 18 (kept on the frozen fixture) with Eggs' 1 charge and Bread 5 (#42).
	# v1.28: Cheese +5 beside Bread.
	assert_int(Scoring.score(_row("eggs,bread,cheese,banana,banana,repeat")).total).is_equal(29)
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
		# Bulb 2 (nothing WASTED before it); buns 2 + 4 after Clearance; can 2 (no redraw made).
		# #128 v3 (redraw tension, no redraw made or left here): was 15, 33, 33 and 22; v1.28: 10.
		["flickering_bulb,day_old_buns,dented_can", 10],
		# Repeat copies Bread's 5; Scissors 2 + 3 for Repeat; Batteries 2, its charges unused (no
		# Household product after it, #128).
		["bread,repeat,scissors,batteries", 17],
		# Butter 2 + 4, Bread 5, Crackers 5, Soup 5, Cereal 2 + 4, Milk 4 + 1 x 2 (Bread, Cereal).
		["butter,bread,crackers,soup,cereal,milk", 33],
		# Banana 2, Yogurt 2 + 4, Carrier bag 1 + 8 x 2 Food beside it (#128), Reduced yogurt
		# 2 + 4 (Dented can), Dented can 2.
		["banana,yogurt,carrier_bag,reduced_yogurt,dented_can", 33],
		# Tea bags isn't Food: Eggs skips it. Tea bags x4 on Bread: 1 + 20.
		["tea_bags,bread", 21],
		# 2 for 1 links the Bananas: the pair bonus applies, then ×2 (2 + 0 + 8).
		["banana,two_for_one,banana", 10],
		# Shelf swap (v1.28): Bread and Cheese differ, so they count as side by side and Cheese
		# pays ×2: 5 + 0 + (3 + 5 beside Bread) x2.
		["bread,shelf_swap,cheese", 21],
		# Clearance tag makes Bread Clearance: Day-old buns 2 + 4 after it (0 + 5 + 6).
		["clearance_tag,bread,day_old_buns", 11],
		# Opening deal in the first slot: Soup pays 5 x5 (0 + 25 + 5).
		["opening_deal,soup,bread", 30],
		# Fruit & veg since the Produce links (#128): Grapefruit 2; a lone Banana 2 + 3; the
		# Lemon, Strawberries and Wonky carrot out of place (1, 2, 2); Fruit salad 2 + 3 x 5
		# kinds. Then the helpers in place: Grapefruit 2; Strawberries 2 + 3 (Grapefruit); Banana
		# 2 + 1; the Lemon knot 1; Banana 2 + 3 x 2 + 1; Wonky carrot 2 + 2 x 2; Fruit salad
		# 2 + 3 x 5 kinds.
		["grapefruit,banana,lemon,strawberries,wonky_carrot,fruit_salad", 29],
		["grapefruit,strawberries,banana,lemon,banana,wonky_carrot,fruit_salad", 43],
		# Bakery, a batch of 4 after Birthday candles (#128 v3): candles 2 (v1.28); Croissant 2 + 3;
		# Baguette 2 + 4 + 2 + 3; Iced bun 1 + 2 + 3; Stale doughnut (1 + 3 x 4 + 2 + 3) x2.
		["birthday_candles,croissant,baguette,iced_bun,stale_doughnut", 60],
		# Snacks (no redraw made or left): Bread 5; Crisps 2; Stale popcorn 2; Cereal bar 2 + 4
		# beside a Snack; Bent lolly 2 (a Snack beside it); Pick 'n' mix 2 (no lone Snack).
		["bread,crisps,stale_popcorn,cereal_bar,bent_lolly,pick_n_mix", 19],
		# Clearance: Ham ends 2; Squashed cake 2; Reduced yogurt (2 + 4 x 2 Clearance beside it) x2
		# (Squashed cake's charge); Dented can 2.
		["ham_ends,squashed_cake,reduced_yogurt,dented_can", 26],
		# Key items: Egg timer 2 + 5 after Eggs; Bread 5 x2 takes Eggs' one charge; Milk 4 + 1 x 3
		# earlier Breakfast.
		["eggs,egg_timer,bread,milk", 25],
		# Cream (2 + 4 for the one PAIR: Reduced yogurt beside Ham ends) x2 = 12 (Eggs' one
		# charge); Milk 3 + 2; Ham ends 2 + 3; Reduced yogurt 2 + 4 (#128 Dairy, v1.28).
		["eggs,cream,milk,ham_ends,reduced_yogurt", 29],
		# Sugar cubes 2 + 4 after Coffee, not Breakfast: it ends the MORNING (Coffee 2 + 1) and
		# Milk's count passes over it. Milk 3 + 2 x 1 earlier Breakfast (#128 Breakfast).
		["coffee,sugar_cubes,milk", 14],
		# Coffee 2 + 1 (the MORNING is Coffee alone); Chipped mug 2 + 4 beside Coffee; Egg timer 2;
		# Odd socks 2: Egg timer beside it has Chipped mug beside it too, 3 in a row, no pair (#128).
		["coffee,chipped_mug,egg_timer,odd_socks", 13],
		# Household (#128, v1.28 numbers). Batteries 2; Odd socks (2 + 8 in an exact pair) x2, the
		# next Household.
		["batteries,odd_socks", 22],
		# Golden Batteries 4 (x2 on the next 3 Household); Odd socks (2 + 8) x2.
		["batteries_golden,odd_socks", 24],
		# Like Eggs, Batteries skip Bread (not Household) for the next Household: Odd socks has no
		# Household beside it, 2 x2: 2 + 5 + 4.
		["batteries,bread,odd_socks", 11],
		# A run of 3 is no pair: neither end nor the middle pays.
		["odd_socks,odd_socks,odd_socks", 6],
		# Carrier bag 1 + 8 x 2 (Eggs and Bread beside it); Eggs' x2 skips it (not Food): Bread 10.
		["eggs,carrier_bag,bread", 28],
	]
) -> void:
	assert_int(Scoring.score(_row(row)).total).is_equal(total)


## The base products' fizzles: Scissors with no earlier coupon, an unused Tea bags charge, a
## Flickering bulb with no Clearance product after it, Batteries with no Household product after
## it, Odd socks with no exact pair, Carrier bag with no Food beside it (#128).
func test_base_products_fizzle(
	row: String,
	expected: Array,
	_test_parameters := [
		["scissors", [[0, "Scissors: earlier coupons", "no coupon before it"]]],
		["bread,scissors", [[1, "Scissors: earlier coupons", "no coupon before it"]]],
		["repeat,scissors", [[0, "Repeat", "no item right before it to copy"]]],
		["tea_bags,soup", [[0, "Tea bags ×4", "no MORNING item after it"]]],
		[
			"flickering_bulb,bread",
			[[0, "Flickering bulb after WASTED", "the item right before it was not WASTED"]],
		],
		# Batteries hold 2 charges since v1.28: one Household after them leaves one unused.
		["batteries,bread", [[0, "Batteries charge", "2 charges unused"]]],
		["batteries", [[0, "Batteries charge", "2 charges unused"]]],
		["batteries,odd_socks", [[0, "Batteries charge", "1 charge unused"]]],
		["batteries,odd_socks,bread,carrier_bag", []],
		[
			"scissors,odd_socks,batteries",
			[
				[0, "Scissors: earlier coupons", "no coupon before it"],
				[1, "Odd socks pair", "two Household items beside it"],
				[2, "Batteries charge", "2 charges unused"]
			]
		],
		[
			"odd_socks,egg_timer,batteries",
			[
				[0, "Odd socks pair", "3 in a row is not a pair"],
				[1, "Egg timer after Eggs", "no Eggs right before it"],
				[2, "Batteries charge", "2 charges unused"]
			]
		],
		["bread,carrier_bag", []],
		[
			"carrier_bag,batteries",
			[
				[0, "Carrier bag: Food beside", "no Food item beside it"],
				[1, "Batteries charge", "2 charges unused"]
			]
		],
		# The capsule items reuse these rules' fizzles (#35).
		["lemon,bread", [[0, "Lemon knot", "not inside a CHAIN"]]],
		["cream,bread", [[0, "Cream: PAIRs", "no PAIR in the row"]]],
		[
			"stale_doughnut,bread",
			[[0, "Stale doughnut closes batch", "not last in its Bakery batch"]]
		],
		["eggs,carrier_bag,bread,bread", []],
		# Coffee is only Breakfast, which Multipack ignores (#42).
		[
			"coffee,multipack,milk",
			[[1, "Multipack ×3", "the item right before it has no family but Food or Breakfast"]]
		],
	]
) -> void:
	var fizzles: Array = []
	for step: ScoreStep in Scoring.score(_row(row)).steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			fizzles.append([step.source_slot, step.text, step.reason])
	assert_array(fizzles).is_equal(expected)


## 59 cards, plus the 100 item tiers: BIG and GOLDEN Banana, Milk, Eggs and Coffee (#77), Bread,
## Soup and the 14 base aisle items (v0.48), and the 30 capsule products (v0.52).
func test_all_cards_and_their_tiers_exist() -> void:
	var ids: Array = []
	var tiers: int = 0
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
			ids.append(card.id)
			if card.tier != CardDefinition.Tier.PLAIN:
				tiers += 1
	assert_int(ids.size()).is_equal(LiveCardCount.CARDS)
	assert_int(tiers).is_equal(100)


## Every card has a price-sticker template (#75); only a card with no rule has an empty one (its
## sticker shows only the price), and every template is digit-free, ordinals such as "2nd"
## aside, so a balance pass never leaves a stale number on a sticker.
func test_every_card_has_a_digit_free_sticker_template() -> void:
	var ordinal: RegEx = RegEx.create_from_string(ORDINAL)
	var digit: RegEx = RegEx.create_from_string("\\d")
	var cards: Array[CardDefinition] = _all_cards()
	assert_int(cards.size()).is_equal(LiveCardCount.CARDS)
	for card: CardDefinition in cards:
		var template: String = CardText.sticker_template(card)
		var message: String = '%s: "%s"' % [card.id, template]
		assert_bool(template.is_empty()).override_failure_message(message).is_equal(
			card.rules.is_empty()
		)
		var without_ordinals: String = ordinal.sub(template, "", true)
		assert_object(digit.search(without_ordinals)).override_failure_message(message).is_null()


## Every card with a rule has a monitor description (PR #138 monitor): a digit-free template
## (ordinals aside) naming only CardText.MONITOR_KEYS, its keyword (if the sticker names one) first,
## formatted with nothing left in braces; a card with no rule has none.
func test_every_card_has_a_digit_free_monitor_text() -> void:
	var ordinal: RegEx = RegEx.create_from_string(ORDINAL)
	var digit: RegEx = RegEx.create_from_string("\\d")
	var placeholder: RegEx = RegEx.create_from_string(PLACEHOLDER)
	for card: CardDefinition in _all_cards():
		var template: String = CardText.monitor_template(card)
		var message: String = '%s: "%s"' % [card.id, template]
		assert_bool(template.is_empty()).override_failure_message(message).is_equal(
			card.rules.is_empty()
		)
		(
			assert_object(digit.search(ordinal.sub(template, "", true)))
			. override_failure_message(message)
			. is_null()
		)
		for found: RegExMatch in placeholder.search_all(template):
			assert_array(CardText.MONITOR_KEYS).override_failure_message(message).contains(
				[found.get_string(1)]
			)
		var shown: String = CardText.monitor_text(card)
		(
			assert_bool(shown.contains("{") or shown.contains("}"))
			. override_failure_message(message)
			. is_false()
		)
		for key: String in ["{chain}", "{batch}", "{pair}"]:
			if CardText.sticker_template(card).begins_with(key):
				assert_str(template).override_failure_message(message).starts_with(key)


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
			elif value is String:
				# A chain bonus's factor ("2× prev", #106).
				for found_number: RegExMatch in number.search_all(value):
					expected.append(found_number.get_string())
		var shown: Array[String] = []
		for found: RegExMatch in number.search_all(summary):
			shown.append(found.get_string())
		assert_array(shown).override_failure_message(message).is_equal(expected)


## Every value that changes what a card's rule does shows on its sticker: its bonus (or base, when
## the bonus is the base), count bonus, factor, tag (a batch rule's as the BATCH keyword, #128),
## least batch size and matched tag. A rule that names a product by id (Cheese names Bread) spells
## it as that card's display name, and one that matches its own card names it.
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
				if adjacent != null and key == "bonus" and adjacent.bonus_is_previous_price:
					# The Banana chain (#106): "+prev", or "+2× prev" when counted twice.
					assert_bool(shows).override_failure_message(message).is_true()
				elif adjacent != null and key == "bonus" and adjacent.bonus_is_base:
					(
						assert_bool(template.contains("{base}") or shows)
						. override_failure_message(message)
						. is_true()
					)
				elif adjacent != null and key == "match_value":
					match adjacent.match_by:
						AdjacentMatchBonusRule.Match.TAG:
							assert_bool(shows).override_failure_message(message).is_true()
						AdjacentMatchBonusRule.Match.SAME_CARD when (
							adjacent.bonus_is_previous_price
						):
							# A chain names its product through the CHAIN keyword (#128).
							assert_str(template).override_failure_message(message).contains(
								"{%s}" % CardText.CHAIN_KEY
							)
						AdjacentMatchBonusRule.Match.SAME_CARD:
							assert_str(template).override_failure_message(message).contains(
								"{name}"
							)
						AdjacentMatchBonusRule.Match.CARD_ID:
							var named: CardDefinition = by_id[StringName(adjacent.match_value)]
							assert_str(card.sticker_summary()).contains(named.display_name)
							assert_bool(shows).override_failure_message(message).is_false()
							named_products += 1
				elif key == "tag" and _reads_morning(rule):
					# A MORNING rule's tag is the morning's: the MORNING keyword names it (#128).
					assert_str(template).override_failure_message(message).contains(
						"{%s}" % CardText.MORNING_KEY
					)
				elif key == "tag" and _reads_batches(rule):
					# A batch rule's tag is its batch's: the BATCH keyword names it (#128).
					assert_str(template).override_failure_message(message).contains(
						"{%s}" % CardText.BATCH_KEY
					)
				elif key == "percent" and rule == CardText.live_rule(card):
					# A live factor's percent shows through {factor} (#128 v3: Stale popcorn).
					assert_str(template).override_failure_message(message).contains("{factor}")
				elif _is_set(key, rule.get(key)):
					assert_bool(shows).override_failure_message(message + " " + key).is_true()
	# Cheese, Crisps, Breadsticks, Cereal, Chipped mug, Crackers, Egg timer, Soft tomatoes, Sugar
	# cubes and Yogurt, plus their BIG and GOLDEN tiers (Cheese, Cereal, Crackers and Yogurt in
	# v0.48, the six capsule products in v0.52). Crisps left in #128 v3 (IMPULSE, no Bread).
	assert_int(named_products).is_equal(27)


## A charged multiplier's sticker says "next": with one charge that is the next product, so the
## sticker names no count; one with more charges (Golden Eggs, #77; Golden Tea bags, v0.48; Golden
## Squashed cake, v0.52; Party pack and the 2-charge Batteries, v1.28) names `{charges}`. Iced bun
## glazes since #128, and Lemon is a CHAIN knot since #128's Produce links.
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
	assert_int(several).is_equal(7)


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
	# The 10 products and 2 coupon icons drawn for style frame v2, the 8 item tiers (#77),
	# #57's 13 products, the 32 tiers of Bread, Soup and the 14 base aisle items (#99, v0.48),
	# and #58's 27 capsule products, their 30 products' 60 tiers (#89), #59's 6 coupon icons
	# (v0.52) and v1.28's Write-off, Party pack and Family sticker icons.
	assert_int(drawn).is_equal(161)


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


## The 30 capsule products (#58, v0.52), read from every aisle's capsule_cards: each has its own
## 48x48 sprite and a complete chain in the machine's UPGRADES table (#89) whose BIG and GOLDEN
## tiers have their own 48x48 sprites too; no two of the 90 share one. Whether the chain follows
## the tier rule is item_tiers_test's.
func test_every_capsule_product_has_its_sprite_and_tiers() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var paths: Dictionary[String, StringName] = {}
	var products: int = 0
	for aisle: AisleDefinition in balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			products += 1
			var chain: ItemUpgradeDefinition = ItemUpgrades.chain_for(
				balance.machine.item_upgrades, card
			)
			assert_object(chain).override_failure_message(String(card.id)).is_not_null()
			if chain == null:
				continue
			assert_object(chain.product).is_same(card)
			for tier: CardDefinition in [card, chain.big, chain.golden]:
				var message: String = "%s: %s" % [tier.id, tier.art_ref]
				assert_str(tier.art_ref).override_failure_message(message).is_not_empty()
				var texture: Texture2D = ArtStyle.item_sprite(tier)
				assert_object(texture).override_failure_message(message).is_not_same(
					ArtStyle.ITEM_PENDING
				)
				assert_that(texture.get_size()).override_failure_message(message).is_equal(
					Vector2(48, 48)
				)
				assert_bool(paths.has(tier.art_ref)).override_failure_message(message).is_false()
				paths[tier.art_ref] = tier.id
	assert_int(products).is_equal(30)


## Every coupon a run can be offered (balance.coupon_pool) has its own icon on the slip (#59
## subset, v0.52: the 6 drawn after Multipack's and 2 for 1's; Write-off, Party pack and the Family
## sticker, v1.28, the sticker in place of the Breakfast sticker and the Clearance tag).
func test_every_pool_coupon_has_its_icon() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var icon: Vector2 = ItemView.COUPON_ICON_RECT.size / float(ArtStyle.ART_SCALE)
	var paths: Dictionary[String, StringName] = {}
	for card: CardDefinition in balance.coupon_pool:
		var message: String = "%s: %s" % [card.id, card.art_ref]
		assert_bool(card.is_coupon()).override_failure_message(message).is_true()
		assert_str(card.art_ref).override_failure_message(message).is_not_empty()
		var texture: Texture2D = (
			load(card.art_ref) as Texture2D if ResourceLoader.exists(card.art_ref) else null
		)
		assert_object(texture).override_failure_message(message).is_not_null()
		if texture != null:
			assert_that(texture.get_size()).override_failure_message(message).is_equal(icon)
		assert_bool(paths.has(card.art_ref)).override_failure_message(message).is_false()
		paths[card.art_ref] = card.id
	assert_int(paths.size()).is_equal(9)


## Sticker minis: every plain product with its own sprite has a 7x7 giver-badge mini and its
## GOLDEN copy (mini_art_ref, mini_golden_art_ref), each its own; a product with no sprite yet,
## a BIG or GOLDEN tier set none, and a tier shows its plain card's (gold-outlined
## for GOLDEN, the plain one for BIG).
func test_every_product_with_a_sprite_has_its_mini() -> void:
	var minis: Dictionary[String, StringName] = {}
	var with_mini: int = 0
	for card: CardDefinition in _all_cards():
		var message: String = "%s: %s / %s" % [card.id, card.mini_art_ref, card.mini_golden_art_ref]
		var drawn: bool = (
			card.is_product() and card.variant_of == null and not card.art_ref.is_empty()
		)
		if not drawn:
			if card.is_coupon():
				continue
			assert_str(card.mini_art_ref).override_failure_message(message).is_empty()
			assert_str(card.mini_golden_art_ref).override_failure_message(message).is_empty()
			continue
		with_mini += 1
		for path: String in [card.mini_art_ref, card.mini_golden_art_ref]:
			assert_bool(ResourceLoader.exists(path)).override_failure_message(message).is_true()
			var texture: Texture2D = (
				load(path) as Texture2D if ResourceLoader.exists(path) else null
			)
			assert_object(texture).override_failure_message(message).is_not_null()
			if texture != null:
				assert_that(texture.get_size()).override_failure_message(message).is_equal(
					GiverBadge.MINI_SIZE / float(ArtStyle.ART_SCALE)
				)
			assert_bool(minis.has(path)).override_failure_message(message).is_false()
			minis[path] = card.id
		assert_str(card.badge_mini_ref()).is_equal(card.mini_art_ref)
	# The 50 products with a sprite: style frame v2's 10, #57's 13 and #58's 27 (v0.52).
	assert_int(with_mini).is_equal(50)
	for card: CardDefinition in _all_cards():
		if card.tier == CardDefinition.Tier.PLAIN:
			continue
		var plain: CardDefinition = card.product_card()
		var expected: String = (
			plain.mini_golden_art_ref
			if card.tier == CardDefinition.Tier.GOLDEN
			else plain.mini_art_ref
		)
		assert_str(card.badge_mini_ref()).override_failure_message(card.id).is_equal(expected)
		assert_str(card.badge_mini_ref()).override_failure_message(card.id).is_not_empty()


## The products a new profile stocks (full build plan 7.2): the starter deck's products, then
## every base aisle's base_cards (a machine-opened aisle has none), each once, in data order.
static func stocked_products() -> Array[CardDefinition]:
	var products: Array[CardDefinition] = []
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
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
## base (the base or its flat bonus, times its factor), or a chain's "prev" (#106), as
## CardText shows it.
static func _data_value(card: CardDefinition, key: String) -> Variant:
	if key == "base":
		return card.base
	if key == "name":
		return card.product_card().display_name
	for rule: Rule in card.rules:
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if key == "bonus" and adjacent != null and adjacent.bonus_is_previous_price:
			return "prev" if adjacent.bonus_factor == 1 else "%d× prev" % adjacent.bonus_factor
		if key == "bonus" and adjacent != null:
			return adjacent.bonus_for(card.base)
		if key in rule:
			return rule.get(key)
	return null


## Whether a rule field holds a value that changes what the rule does (not its neutral default).
## One charge is the plain "next" the sticker already says, like a factor of 1.
## Whether `rule` reads Bakery batches (#128), whose tickets name them with the BATCH keyword.
static func _reads_morning(rule: Rule) -> bool:
	var charged: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
	return rule is MorningCountRule or (charged != null and charged.morning_end)


static func _reads_batches(rule: Rule) -> bool:
	return rule is BatchRoleRule or rule is BakedBatchBonusRule


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
