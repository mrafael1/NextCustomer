extends GdUnitTestSuite
## The extended deck view on the real shift screen (plan section 2, full build phase 1): the
## Deck tab (grouped copies, tag counts), the Run info tab (upgrades, inspections, stock), the
## choosing mode, and that it fits the window. Clicks go to the handlers (headless runs).

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	Engine.time_scale = 8.0


func after_test() -> void:
	Engine.time_scale = 1.0
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The starter deck: one card per distinct card with its copies, products then coupons, and the
## printed-tag counts.
func test_the_deck_tab_groups_copies_and_counts_tags() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	assert_bool(view.visible).is_true()
	var texts: PackedStringArray = view.texts()
	assert_str(texts[0]).is_equal(
		"Tags: Food 10  ·  Breakfast 8  ·  Produce 3  ·  Bakery 2  ·  Dairy 2"
	)
	assert_str(texts[1]).is_equal("PRODUCTS  (12)")
	assert_array(Array(texts)).contains(["COUPONS  (1)"])
	var counts: Dictionary[String, String] = {
		"banana": "×3",
		"bread": "×2",
		"coffee": "×2",
		"eggs": "×2",
		"milk": "×2",
		"soup": "",
		"repeat": "",
	}
	var ids: Array = []
	for card_view: CardView in view.card_views():
		var id: String = String(card_view.card.definition.id)
		ids.append(id)
		var note: Label = card_view.get_parent().get_child(1)
		assert_str(note.text).override_failure_message(id).is_equal(counts[id])
	assert_array(ids).is_equal(counts.keys())
	assert_bool(view._deck_tab.disabled).is_true()
	assert_bool(view._info_tab.visible).is_true()


## The starting deck's page shows whole, unscrolled: every card and its count line sit inside
## the scroll area, and the view sits inside the window below the top bar.
func test_the_starting_deck_fits_without_scrolling() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	await get_tree().create_timer(0.4).timeout
	var content: Control = view._scroll.get_child(0)
	assert_float(content.size.y).is_less_equal(view._scroll.size.y)
	var area: Rect2 = view._scroll.get_global_rect()
	for card_view: CardView in view.card_views():
		var cell: Control = card_view.get_parent()
		assert_bool(area.encloses(cell.get_global_rect())).is_true()
	var rect: Rect2 = view.get_global_rect()
	assert_bool(screen.get_global_rect().encloses(rect)).is_true()
	assert_float(rect.position.y).is_greater_equal(screen._shade.offset_top)


## Run info: upgrades (none, then one given through the debug panel), this shift's and the next
## shift's inspections, and the stock with its aisle.
func test_the_run_info_tab_shows_upgrades_inspections_and_stock() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	var texts: PackedStringArray = view.texts()
	(
		assert_array(Array(texts))
		. contains(
			[
				"UPGRADES",
				"None yet.",
				"This shift: no inspection.",
				"Next shift: no inspection.",
				"Aisles: Placeholder aisle",
			]
		)
	)
	assert_int(view.card_views().size()).is_equal(screen.run.stock.cards.size())
	assert_int(view.card_views().size()).is_equal(12)
	view._close()
	screen._on_debug_upgrade("category_engine")
	screen._on_debug_inspection("spot_check")
	screen._on_deck_button_pressed()
	view.show_page(true)
	texts = view.texts()
	assert_bool(texts.has("None yet.")).is_false()
	(
		assert_array(Array(texts))
		. contains(
			[
				(
					"Category engine (Category Engine): +3 for each different tag among your"
					+ " products  ·  Paid on the last product in the row"
				),
				"This shift: Spot check, The 3rd product pays €0",
			]
		)
	)
	view.show_page(false)
	assert_str(view.texts()[0]).starts_with("Tags: ")


## Before an inspected shift the next one is announced as coming (it is drawn at checkout);
## the last shift has no next shift.
func test_run_info_announces_a_scheduled_inspection() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_debug_shift(2)
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	assert_array(Array(view.texts())).contains(
		["This shift: no inspection.", "Next shift: inspected (announced at checkout)."]
	)
	view._close()
	screen._on_debug_shift(screen.run.shift_count())
	screen._on_deck_button_pressed()
	view.show_page(true)
	var texts: PackedStringArray = view.texts()
	(
		assert_bool(
			Array(texts).any(func(text: String) -> bool: return text.begins_with("Next shift"))
		)
		. is_false()
	)
	assert_array(Array(texts)).contains(["This shift: no inspection."])


## During the reward the drawn inspection shows for the next shift, and the shift just played
## is no longer called "This shift".
func test_run_info_during_the_reward_shows_the_drawn_inspection() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_debug_shift(2)
	for id: String in ["bread", "multipack", "bread", "bread", "bread", "bread"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		screen.run.place(screen.run.debug_add_to_hand(card), screen.run.row.size())
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)
	assert_object(screen.run.next_inspection).is_not_null()
	screen._on_reward_deck_requested()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	var texts: PackedStringArray = view.texts()
	assert_array(Array(texts)).contains(["Next shift: Spot check, The 3rd product pays €0"])
	(
		assert_bool(
			Array(texts).any(func(text: String) -> bool: return text.begins_with("This shift"))
		)
		. is_false()
	)


## New arrivals in the stock are marked NEW.
func test_run_info_marks_new_arrivals() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var arrival: CardDefinition = run.stock.cards[6]
	run.stock.new_arrivals = [arrival]
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	assert_array(Array(view.texts())).contains(["NEW"])
	for card_view: CardView in view.card_views():
		var note: Label = card_view.get_parent().get_child(1)
		var expected: String = "NEW" if card_view.card.definition == arrival else ""
		assert_str(note.text).is_equal(expected)


## At the deck limit only the deck shows, and a grouped card chooses one of its copies.
func test_the_chooser_shows_only_the_deck_and_picks_a_copy() -> void:
	var screen: ShiftScreen = await _screen()
	var chosen: Array[CardInstance] = []
	screen._deck_view.card_chosen.connect(func(card: CardInstance) -> void: chosen.append(card))
	screen._deck_view.open(screen.run, "choose", true)
	var view: DeckView = screen._deck_view
	assert_bool(view._deck_tab.visible).is_false()
	assert_bool(view._info_tab.visible).is_false()
	var banana: CardView = view.card_views()[0]
	view._on_card_clicked(banana)
	assert_int(chosen.size()).is_equal(1)
	assert_bool(screen.run.deck.cards.has(chosen[0])).is_true()
	assert_str(String(chosen[0].definition.id)).is_equal("banana")
	assert_bool(view.visible).is_false()


## The real flow: a reward picked at the deck limit opens the chooser, and clicking the grouped
## Banana removes one Banana copy.
func test_a_reward_at_the_deck_limit_removes_one_copy_of_a_grouped_card() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	while not run.deck_is_full():
		run.deck.add_card(load("res://data/cards/soup.tres"))
	for id: String in ["bread", "multipack", "bread", "bread", "bread", "bread"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		run.place(run.debug_add_to_hand(card), run.row.size())
	await screen._on_checkout_pressed()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	var bananas: int = _copies(run, &"banana")
	screen._on_reward_picked(run.offer[0])
	var view: DeckView = screen._deck_view
	assert_bool(view.visible).is_true()
	assert_bool(view._info_tab.visible).is_false()
	view._on_card_clicked(view.card_views()[0])
	assert_int(run.phase).is_not_equal(RunState.Phase.REWARD)
	assert_int(run.deck.size()).is_equal(run.balance.deck_limit)
	var picked_banana: int = 1 if run.history[0].card_picked.id == &"banana" else 0
	assert_int(_copies(run, &"banana")).is_equal(bananas - 1 + picked_banana)


## Outside the chooser a click chooses nothing.
func test_browsing_clicks_choose_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	var chosen: Array[CardInstance] = []
	screen._deck_view.card_chosen.connect(func(card: CardInstance) -> void: chosen.append(card))
	screen._on_deck_button_pressed()
	screen._deck_view._on_card_clicked(screen._deck_view.card_views()[0])
	assert_array(chosen).is_empty()
	assert_bool(screen._deck_view.visible).is_true()


## A full collection's stock (about 25 cards) and a deck of 15 distinct cards still fit the
## window: the pages scroll inside a fixed area.
func test_a_big_stock_and_deck_fit_the_screen() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	for index: int in range(15):
		run.stock.cards.append(_product("extra_%d" % index))
	for index: int in range(8):
		run.deck.add_card(_product("deck_%d" % index))
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	for page: bool in [false, true]:
		view.show_page(page)
		# Past the pop-in tween, whose overshoot scales the panel for a moment.
		await get_tree().create_timer(0.4).timeout
		var rect: Rect2 = view.get_global_rect()
		assert_bool(screen.get_global_rect().encloses(rect)).is_true()
		assert_float(rect.size.y).is_less_equal(view.get_combined_minimum_size().y + 1.0)
		var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
		assert_float(rect.size.x).is_less_equal(width)
		var content: Control = view._scroll.get_child(0)
		assert_float(content.size.y).is_greater(view._scroll.size.y)
	assert_int(view.card_views().size()).is_equal(27)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	for frame: int in range(2):
		await get_tree().process_frame
	return screen


static func _copies(run: RunState, id: StringName) -> int:
	var count: int = 0
	for card: CardInstance in run.deck.cards:
		if card.definition.id == id:
			count += 1
	return count


static func _product(id: String) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.display_name = id.capitalize()
	card.kind = CardDefinition.Kind.PRODUCT
	card.tags = PackedStringArray(["Food"])
	return card


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
