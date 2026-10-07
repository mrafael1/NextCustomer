extends GdUnitTestSuite
## ContentLookup (full build plan section 4): a save's ids resolve to the data files of the
## right kind whose own id equals the file name, and aisle ids to the balance's aisles. An id
## that doesn't resolve gives null and prints nothing.

const BALANCE := "res://data/balance/balance.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_lookup_%d" % Time.get_ticks_usec()


func after_test() -> void:
	var cards: String = _folder.path_join(ContentLookup.CARDS_FOLDER)
	if DirAccess.dir_exists_absolute(cards):
		for file_name: String in DirAccess.get_files_at(cards):
			DirAccess.remove_absolute(cards.path_join(file_name))
		DirAccess.remove_absolute(cards)
		DirAccess.remove_absolute(_folder)


func test_each_kind_resolves_from_the_data_folders() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	assert_object(lookup.card("banana")).is_same(load("res://data/cards/banana.tres"))
	assert_object(lookup.upgrade("extra_redraw")).is_same(
		load("res://data/upgrades/extra_redraw.tres")
	)
	assert_object(lookup.inspection("spot_check")).is_same(
		load("res://data/inspections/spot_check.tres")
	)
	assert_object(lookup.deck("starter")).is_same(load("res://data/decks/starter.tres"))
	assert_object(lookup.aisle("placeholder")).is_same(lookup.balance.aisles[0])


func test_unknown_ids_and_the_wrong_kind_give_null() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	assert_object(lookup.card("gone")).is_null()
	assert_object(lookup.card("")).is_null()
	assert_object(lookup.card("../decks/starter")).is_null()
	assert_object(lookup.card("starter")).is_null()
	assert_object(lookup.deck("banana")).is_null()
	assert_object(lookup.upgrade("banana")).is_null()
	assert_object(lookup.inspection("extra_redraw")).is_null()
	assert_object(lookup.aisle("gone")).is_null()


## A file whose resource has another id (a renamed file) doesn't resolve under either name.
func test_a_file_whose_id_differs_from_its_name_gives_null() -> void:
	var cards: String = _folder.path_join(ContentLookup.CARDS_FOLDER)
	DirAccess.make_dir_recursive_absolute(cards)
	var moved: CardDefinition = CardDefinition.new()
	moved.id = &"other"
	moved.kind = CardDefinition.Kind.PRODUCT
	assert_int(ResourceSaver.save(moved, cards.path_join("renamed.tres"))).is_equal(OK)
	var same: CardDefinition = CardDefinition.new()
	same.id = &"same"
	same.kind = CardDefinition.Kind.PRODUCT
	assert_int(ResourceSaver.save(same, cards.path_join("same.tres"))).is_equal(OK)
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE), _folder)
	assert_object(lookup.card("renamed")).is_null()
	assert_object(lookup.card("other")).is_null()
	assert_str(String(lookup.card("same").id)).is_equal("same")


func test_added_resources_resolve_by_their_id() -> void:
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var card: CardDefinition = CardDefinition.new()
	card.id = &"test_card"
	lookup.add(card)
	assert_object(lookup.card("test_card")).is_same(card)
	assert_object(lookup.upgrade("test_card")).is_null()
