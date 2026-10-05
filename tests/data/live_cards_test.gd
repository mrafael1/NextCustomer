extends GdUnitTestSuite
## Tests on the live data/ files. Unlike the golden rows, these expected values are updated
## when card values are tuned between playtest rounds (plan section 3.7).

const CARDS_DIR := "res://data/cards"


func test_live_cards_score_the_design_examples() -> void:
	assert_int(Scoring.score(_row("eggs,bread,cheese,banana,banana,repeat")).total).is_equal(31)
	assert_int(Scoring.score(_row("banana,repeat,bread,eggs,banana,cheese")).total).is_equal(18)


func test_starter_deck_matches_the_plan() -> void:
	var deck: DeckDefinition = load("res://data/decks/starter.tres")
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
				&"repeat": 1,
			}
		)
	)


func test_all_thirteen_cards_exist() -> void:
	var ids: Array = []
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if file.ends_with(".tres"):
			ids.append((load("%s/%s" % [CARDS_DIR, file]) as CardDefinition).id)
	assert_int(ids.size()).is_equal(13)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
