extends GdUnitTestSuite
## What the deck view shows about the deck (DeckSummary): groups of copies in view order and
## the printed-tag counts.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"


func test_the_starter_groups_products_by_name_then_coupons() -> void:
	var deck: Deck = Deck.from_definition(load(STARTER), RandomNumberGenerator.new())
	var groups: Array[DeckSummary.Group] = DeckSummary.groups(deck.cards)
	var found: Array = []
	for group: DeckSummary.Group in groups:
		found.append("%s %d" % [group.card.id, group.copies.size()])
	assert_array(found).is_equal(
		["banana 3", "bread 2", "coffee 2", "eggs 2", "milk 2", "soup 1", "repeat 1"]
	)


## Each group holds the deck's own instances, in deck order, so choosing one removes a real copy.
func test_groups_hold_the_deck_copies_in_deck_order() -> void:
	var deck: Deck = Deck.from_definition(load(STARTER), RandomNumberGenerator.new())
	var copies: Array[CardInstance] = []
	for card: CardInstance in deck.cards:
		if card.definition.id == &"banana":
			copies.append(card)
	assert_array(DeckSummary.groups(deck.cards)[0].copies).is_equal(copies)
	assert_array(DeckSummary.groups([])).is_empty()


func test_tag_counts_count_copies_most_common_first() -> void:
	var deck: Deck = Deck.from_definition(load(STARTER), RandomNumberGenerator.new())
	var counts: Dictionary[String, int] = DeckSummary.tag_counts(deck.cards)
	assert_array(counts.keys()).is_equal(["Food", "Breakfast", "Produce", "Bakery", "Dairy"])
	assert_array(counts.values()).is_equal([10, 8, 3, 2, 2])
	assert_dict(DeckSummary.tag_counts([])).is_empty()


func test_view_order_puts_products_first_then_names() -> void:
	var stock: RunStock = RunStock.starting(load(STARTER), load(BALANCE))
	var ids: Array = DeckSummary.in_view_order(stock.cards).map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	(
		assert_array(ids)
		. is_equal(
			[
				"banana",
				"batteries",
				"bread",
				"butter",
				"carrier_bag",
				"cereal",
				"cheese",
				"coffee",
				"crackers",
				"day_old_buns",
				"dented_can",
				"eggs",
				"flickering_bulb",
				"frozen_peas",
				"milk",
				"reduced_yogurt",
				"scissors",
				"soup",
				"tea_bags",
				"yogurt",
				"two_for_one",
				"breakfast_sticker",
				"clearance_tag",
				"final_markdown",
				"multipack",
				"opening_deal",
				"repeat",
				"shelf_swap",
			]
		)
	)


## Same names fall back to the id, so the order never depends on the list's order.
func test_view_order_breaks_name_ties_by_id() -> void:
	var b: CardDefinition = _product(&"b", "Same")
	var a: CardDefinition = _product(&"a", "Same")
	var ids: Array = DeckSummary.in_view_order([b, a]).map(
		func(card: CardDefinition) -> StringName: return card.id
	)
	assert_array(ids).is_equal([&"a", &"b"])


static func _product(id: StringName, display_name: String) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = id
	card.display_name = display_name
	card.kind = CardDefinition.Kind.PRODUCT
	return card
