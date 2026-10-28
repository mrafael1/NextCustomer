extends GdUnitTestSuite
## A ticket's families (CardFamilies, #105): the family a card works with, from its rules, a
## product it names, itself, or its override. The live table is the mock-up readability v3's
## (docs/art/mockups/readability_v3_src/cards.js), checked against every card in data/cards;
## the rest runs on cards made here.

const LiveCardCount := preload("res://tests/data/live_card_count.gd")
const CARDS_DIR := "res://data/cards"
const ORDER_LIST := [
	"Bakery", "Produce", "Dairy", "Frozen", "Snack", "Household", "Breakfast", "Clearance", "Food"
]
## Every plain card's ticket families (BIG and GOLDEN tiers take their plain card's), the
## approved v3 table: 58 stocked cards and Bundle (outside every pool: the plain coupon).
const LIVE: Dictionary[String, Array] = {
	"baguette": ["Bakery"],
	"birthday_candles": ["Bakery"],
	"bread": ["Bakery"],
	"broken_biscuit": ["Bakery"],
	"butter": ["Bakery"],
	"cheese": ["Bakery"],
	"crisps": ["Bakery"],
	"croissant": ["Bakery"],
	"iced_bun": ["Bakery"],
	"stale_doughnut": ["Bakery"],
	"banana": ["Produce"],
	"fruit_salad": ["Produce"],
	"grapefruit": ["Produce"],
	"lemon": ["Produce"],
	"potatoes": ["Produce"],
	"strawberries": ["Produce"],
	"wonky_carrot": ["Produce"],
	"yogurt": ["Produce"],
	"cereal": ["Dairy"],
	"cream": ["Dairy"],
	"ham_ends": ["Dairy"],
	"scone": ["Dairy"],
	"frozen_peas": ["Frozen"],
	"bent_lolly": ["Snack"],
	"cereal_bar": ["Snack"],
	"pick_n_mix": ["Snack"],
	"stale_popcorn": ["Snack"],
	"batteries": ["Household"],
	"odd_socks": ["Household"],
	"scissors": ["Household"],
	"breakfast_sticker": ["Breakfast"],
	"chipped_mug": ["Breakfast"],
	"coffee": ["Breakfast"],
	"egg_timer": ["Breakfast"],
	"milk": ["Breakfast"],
	"sugar_cubes": ["Breakfast"],
	"tea_bags": ["Breakfast"],
	"bruised_apples": ["Clearance"],
	"clearance_tag": ["Clearance"],
	"day_old_buns": ["Clearance"],
	"dented_can": ["Clearance"],
	"dusty_toffees": ["Clearance"],
	"final_markdown": ["Clearance"],
	"flickering_bulb": ["Clearance"],
	"reduced_yogurt": ["Clearance"],
	"squashed_cake": ["Clearance"],
	"breadsticks": ["Food"],
	"carrier_bag": ["Food"],
	"crackers": ["Food"],
	"eggs": ["Food"],
	"mixed_herbs": ["Food"],
	"soft_tomatoes": ["Food"],
	"soup": ["Food"],
	"multipack": [],
	"opening_deal": [],
	"repeat": [],
	"shelf_swap": [],
	"two_for_one": [],
	"bundle": [],
}
## The rules that name a family, and the ones that name none (a penalty, slot rules, coupon
## counting, links, copies, 2 for 1, the shared multiplier, the connector). A new rule in
## core/rules fails test_every_rule_is_classified until it is added to one of them.
const FAMILY_RULES := [
	"adjacent_match_bonus_rule.gd",
	"count_earlier_tag_bonus_rule.gd",
	"grant_charged_multiplier_rule.gd",
	"grant_next_tag_bonus_rule.gd",
	"grant_tag_to_next_slot_rule.gd",
]
const NO_FAMILY_RULES := [
	"connector_bridge_rule.gd",
	"copy_previous_payout_rule.gd",
	"count_earlier_coupon_bonus_rule.gd",
	"first_product_link_rule.gd",
	"first_slot_multiplier_rule.gd",
	"grant_shared_tag_multiplier_rule.gd",
	"last_slot_bonus_rule.gd",
	"two_for_one_rule.gd",
	"zero_payout_beside_tag_rule.gd",
]


func test_every_live_card_matches_the_v3_table() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var seen: int = 0
	var plain: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if not file.ends_with(".tres"):
			continue
		seen += 1
		var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
		var plain_id: String = String(card.product_card().id)
		if card.tier == CardDefinition.Tier.PLAIN:
			plain.append(plain_id)
		assert_bool(LIVE.has(plain_id)).override_failure_message(plain_id).is_true()
		var got: PackedStringArray = palette.ticket_families(card)
		assert_array(Array(got)).override_failure_message("%s: %s" % [card.id, got]).is_equal(
			LIVE.get(plain_id, ["?"])
		)
	assert_int(seen).is_equal(LiveCardCount.CARDS)
	assert_int(plain.size()).is_equal(LIVE.size())


func test_a_tier_is_coloured_as_its_plain_card() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	for tier: String in ["milk_big", "milk_golden", "cereal_golden", "soup_big"]:
		var card: CardDefinition = FamilyPalette.data_card(tier)
		assert_object(card).override_failure_message(tier).is_not_null()
		assert_array(Array(palette.ticket_families(card))).is_equal(
			Array(palette.ticket_families(card.product_card()))
		)


func test_a_tag_rule_gives_its_tag() -> void:
	var counting: CountEarlierTagBonusRule = CountEarlierTagBonusRule.new()
	counting.tag = "Breakfast"
	var milk: CardDefinition = _card("milk", ["Food", "Breakfast", "Dairy"], [counting])
	assert_array(Array(_families(milk))).is_equal(["Breakfast"])
	var charged: GrantChargedMultiplierRule = GrantChargedMultiplierRule.new()
	charged.tag = "Food"
	assert_array(Array(_families(_card("eggs", ["Food", "Breakfast"], [charged])))).is_equal(
		["Food"]
	)


func test_a_product_target_gives_that_products_main_family() -> void:
	var milk: CardDefinition = _card("milk", ["Food", "Breakfast", "Dairy"], [])
	var beside: AdjacentMatchBonusRule = _match(AdjacentMatchBonusRule.Match.CARD_ID, "milk")
	var cereal: CardDefinition = _card("cereal", ["Food", "Breakfast"], [beside])
	var lookup: Callable = func(id: String) -> CardDefinition: return milk if id == "milk" else null
	assert_array(Array(CardFamilies.ticket_families(cereal, _order(), lookup))).is_equal(["Dairy"])


func test_an_unknown_product_target_falls_back_to_the_own_family() -> void:
	var beside: AdjacentMatchBonusRule = _match(AdjacentMatchBonusRule.Match.CARD_ID, "nothing")
	var cheese: CardDefinition = _card("cheese", ["Food", "Dairy"], [beside])
	assert_array(Array(_families(cheese))).is_equal(["Dairy"])
	# The real lookup checks the file first, so nothing prints an error.
	var live: PackedStringArray = CardFamilies.ticket_families(
		cheese, _order(), FamilyPalette.data_card
	)
	assert_array(Array(live)).is_equal(["Dairy"])
	assert_object(FamilyPalette.data_card("../balance/balance")).is_null()
	assert_object(FamilyPalette.data_card("")).is_null()


func test_the_same_card_and_no_target_give_the_own_family() -> void:
	var same: AdjacentMatchBonusRule = _match(AdjacentMatchBonusRule.Match.SAME_CARD, "")
	assert_array(Array(_families(_card("banana", ["Food", "Produce"], [same])))).is_equal(
		["Produce"]
	)
	var penalty: ZeroPayoutBesideTagRule = ZeroPayoutBesideTagRule.new()
	penalty.tag = "Frozen"
	assert_array(Array(_families(_card("soup", ["Food"], [penalty])))).is_equal(["Food"])


func test_a_coupon_naming_no_family_is_plain() -> void:
	var coupon: CardDefinition = _card("repeat", [], [CopyPreviousPayoutRule.new()])
	coupon.kind = CardDefinition.Kind.COUPON
	assert_array(Array(_families(coupon))).is_empty()


func test_two_families_split_and_a_third_is_dropped() -> void:
	var rules: Array[Rule] = []
	for tag: String in ["Breakfast", "Breakfast", "Dairy", "Snack"]:
		var rule: GrantNextTagBonusRule = GrantNextTagBonusRule.new()
		rule.tag = tag
		rules.append(rule)
	var card: CardDefinition = _card("split", ["Food"], rules)
	assert_array(Array(_families(card))).is_equal(["Breakfast", "Dairy"])


func test_the_override_wins_and_a_tier_takes_its_plain_cards() -> void:
	var markdown: CardDefinition = _card("markdown", [], [LastSlotBonusRule.new()])
	markdown.kind = CardDefinition.Kind.COUPON
	markdown.ticket_families = PackedStringArray(["Clearance"])
	assert_array(Array(_families(markdown))).is_equal(["Clearance"])
	var counting: CountEarlierTagBonusRule = CountEarlierTagBonusRule.new()
	counting.tag = "Breakfast"
	var milk: CardDefinition = _card("milk", ["Food", "Breakfast", "Dairy"], [counting])
	milk.ticket_families = PackedStringArray(["Dairy", "Frozen", "Snack"])
	var golden: CardDefinition = _card("milk_golden", ["Food", "Breakfast", "Dairy"], [counting])
	golden.variant_of = milk
	golden.tier = CardDefinition.Tier.GOLDEN
	assert_array(Array(_families(golden))).is_equal(["Dairy", "Frozen"])
	golden.ticket_families = PackedStringArray(["Snack"])
	assert_array(Array(_families(golden))).is_equal(["Snack"])


func test_main_family_follows_the_order() -> void:
	var cases: Dictionary[String, Array] = {
		"Bakery": ["Food", "Breakfast", "Bakery"],
		"Dairy": ["Food", "Breakfast", "Dairy"],
		"Food": ["Food"],
		"": [],
	}
	for expected: String in cases:
		var card: CardDefinition = _card("card", cases[expected], [])
		assert_str(CardFamilies.main_family(card, _order())).is_equal(expected)
	var doughnut: CardDefinition = _card("doughnut", ["Food", "Bakery", "Clearance"], [])
	assert_str(CardFamilies.main_family(doughnut, _order())).is_equal("Bakery")


func test_live_main_families() -> void:
	var expected: Dictionary[String, String] = {
		"bread": "Bakery", "milk": "Dairy", "stale_doughnut": "Bakery", "soup": "Food"
	}
	var order: PackedStringArray = FamilyPalette.shared().main_family_order
	for id: String in expected:
		var card: CardDefinition = FamilyPalette.data_card(id)
		assert_str(CardFamilies.main_family(card, order)).is_equal(expected[id])


func test_shelf_families_leave_out_food() -> void:
	var quiet: PackedStringArray = PackedStringArray(["Food"])
	var milk: PackedStringArray = PackedStringArray(["Food", "Breakfast", "Dairy"])
	assert_array(Array(CardFamilies.shelf_families(milk, quiet))).is_equal(["Breakfast", "Dairy"])
	var soup: PackedStringArray = PackedStringArray(["Food"])
	assert_array(Array(CardFamilies.shelf_families(soup, quiet))).is_equal(["Food"])
	var none: PackedStringArray = PackedStringArray()
	assert_array(Array(CardFamilies.shelf_families(none, quiet))).is_empty()


func test_every_rule_is_classified() -> void:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at("res://core/rules"):
		if file.ends_with(".gd"):
			files.append(file)
	var classified: Array = FAMILY_RULES + NO_FAMILY_RULES
	classified.sort()
	files.sort()
	assert_array(files).is_equal(classified)
	var holder: CardDefinition = _card("holder", ["Food", "Snack"], [])
	for file: String in FAMILY_RULES:
		var rule: Rule = (load("res://core/rules/" + file) as GDScript).new()
		if rule is AdjacentMatchBonusRule:
			(rule as AdjacentMatchBonusRule).match_by = AdjacentMatchBonusRule.Match.TAG
			(rule as AdjacentMatchBonusRule).match_value = "Dairy"
		else:
			rule.set("tag", "Dairy")
		(
			assert_str(CardFamilies.rule_family(rule, holder, _order(), Callable()))
			. override_failure_message(file)
			. is_equal("Dairy")
		)
	for file: String in NO_FAMILY_RULES:
		var rule: Rule = (load("res://core/rules/" + file) as GDScript).new()
		if "tag" in rule:
			rule.set("tag", "Dairy")
		(
			assert_str(CardFamilies.rule_family(rule, holder, _order(), Callable()))
			. override_failure_message(file)
			. is_empty()
		)


## Why a ticket has its colour (colour_reason, mock-up v3's tgt column): a family its rule works
## with (T), a family it gives (G), a product it names (C), itself (S), its own family (-), the
## override, or nothing (a plain coupon); on every live card it agrees with ticket_families.
func test_the_colour_reason_names_what_the_card_works_with() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var expected: Dictionary[String, Array] = {
		"milk": [CardFamilies.Reason.FAMILY, "Breakfast"],
		"eggs": [CardFamilies.Reason.FAMILY, "Food"],
		"breakfast_sticker": [CardFamilies.Reason.GIVES, "Breakfast"],
		"cereal": [CardFamilies.Reason.CARD, "Milk"],
		"cheese": [CardFamilies.Reason.CARD, "Bread"],
		"banana": [CardFamilies.Reason.SAME, "Banana"],
		"banana_golden": [CardFamilies.Reason.SAME, "Banana"],
		"batteries": [CardFamilies.Reason.OWN, ""],
		"soup": [CardFamilies.Reason.OWN, ""],
		"final_markdown": [CardFamilies.Reason.OVERRIDE, ""],
		"multipack": [CardFamilies.Reason.NONE, ""],
	}
	for id: String in expected:
		var card: CardDefinition = FamilyPalette.data_card(id)
		var why: CardFamilies.Why = palette.colour_reason(card)
		var message: String = "%s: %d %s" % [id, why.reason, why.subject]
		assert_int(why.reason).override_failure_message(message).is_equal(expected[id][0])
		assert_str(why.subject).override_failure_message(message).is_equal(expected[id][1])
	var seen: int = 0
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if not file.ends_with(".tres"):
			continue
		seen += 1
		var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
		var families: PackedStringArray = palette.ticket_families(card)
		var why: CardFamilies.Why = palette.colour_reason(card)
		var message: String = "%s: %d %s %s" % [card.id, why.reason, why.subject, families]
		(
			assert_bool(why.reason == CardFamilies.Reason.NONE)
			. override_failure_message(message)
			. is_equal(families.is_empty())
		)
		if why.reason == CardFamilies.Reason.FAMILY or why.reason == CardFamilies.Reason.GIVES:
			assert_str(why.subject).override_failure_message(message).is_equal(families[0])
		(
			assert_bool(palette.colour_tip(card).is_empty())
			. override_failure_message(message)
			. is_false()
		)
	assert_int(seen).is_equal(LiveCardCount.CARDS)


## The colour's words (FamilyPalette): the tooltip and the scan popup's line, a split ticket's,
## and the plain coupon's tooltip (it has no popup line).
func test_the_colour_words_follow_the_reason() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var milk: CardDefinition = FamilyPalette.data_card("milk")
	assert_str(palette.colour_tip(milk)).is_equal("Breakfast colour · works with Breakfast")
	assert_str(palette.ticket_line(milk)).is_equal("Breakfast ticket: works with Breakfast")
	var cereal: CardDefinition = FamilyPalette.data_card("cereal")
	assert_str(palette.ticket_line(cereal)).is_equal("Dairy ticket: works with Milk")
	var multipack: CardDefinition = FamilyPalette.data_card("multipack")
	assert_str(palette.colour_tip(multipack)).is_equal(FamilyPalette.PLAIN_COUPON_TIP)
	assert_str(palette.ticket_line(multipack)).is_empty()
	var split: CardDefinition = _card(
		"split",
		["Food", "Breakfast"],
		[
			_match(AdjacentMatchBonusRule.Match.TAG, "Bakery"),
			_match(AdjacentMatchBonusRule.Match.TAG, "Dairy"),
		]
	)
	assert_str(palette.colour_tip(split)).is_equal("Bakery + Dairy: works with both")
	assert_str(palette.ticket_line(split)).is_equal("Bakery + Dairy ticket: works with both")


func _order() -> PackedStringArray:
	return PackedStringArray(ORDER_LIST)


func _families(card: CardDefinition) -> PackedStringArray:
	return CardFamilies.ticket_families(card, _order(), Callable())


func _match(by: AdjacentMatchBonusRule.Match, value: String) -> AdjacentMatchBonusRule:
	var rule: AdjacentMatchBonusRule = AdjacentMatchBonusRule.new()
	rule.match_by = by
	rule.match_value = value
	rule.position = AdjacentMatchBonusRule.Position.BESIDE
	return rule


func _card(id: String, tags: Array, rules: Array) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.display_name = id
	card.kind = CardDefinition.Kind.PRODUCT
	card.tags = PackedStringArray(tags)
	var typed: Array[Rule] = []
	typed.assign(rules)
	card.rules = typed
	return card
