extends GdUnitTestSuite
## The extended deck view on the real shift screen (plan section 2, full build phase 1): the
## Deck tab (grouped copies, tag counts), the Run info tab (upgrades, inspections, stock), the
## choosing mode, and that it fits the window. Clicks go to the handlers (headless runs).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
## A centred pop-in on the 720 px screen that leaves the top bar (and the shade's top, 64)
## clear (#56's derived limit).
const MAX_PANEL_HEIGHT := 592.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The starter deck: one card per distinct card with its copies, products then coupons, and the
## printed-tag counts.
func test_the_deck_tab_groups_copies_and_counts_tags() -> void:
	var screen: ShiftScreen = await _screen()
	# The fixed starter deck (the game deals a recipe since v0.49, see
	# test_the_game_deals_the_recipe_deck).
	var balance: BalanceDefinition = screen.run.balance
	screen.run = RunState.new(61, load(STARTER), balance, RunStock.starting(balance))
	screen.run.start_shift()
	screen._on_shift_started()
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
		"final_markdown": "",
	}
	var ids: Array = []
	for cell: DeckCell in view.cells():
		var id: String = String(cell.card.id)
		ids.append(id)
		assert_str(cell.count_text()).override_failure_message(id).is_equal(counts[id])
		# The plain starter deck isn't dealt: no staple or pick marks, and no legend.
		assert_array(cell.marks()).is_empty()
	assert_array(ids).is_equal(counts.keys())
	assert_object(view.find_child("Legend", true, false)).is_null()
	assert_bool(view._deck_tab.disabled).is_true()
	assert_bool(view._info_tab.visible).is_true()


## v0.49: a new run starts from the recipe deck, dealt from its stock on the run seed's own
## stream; since v0.63 (#107) the recipe with starter packs: the 4 core cards, the pack taken (a
## run started without the reveal takes the offer's default, a new profile's good first pick),
## then 6 stocked products with a tier chain, and the Deck tab shows it.
func test_the_game_deals_the_recipe_deck() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	assert_str(String(run.starter.id)).is_equal("pack_starter")
	assert_int(run.starter.cards.size()).is_equal(13)
	assert_int(run.deck.size()).is_equal(13)
	var recipe: DeckDefinition = load(ShiftScreen.STARTER_DECK)
	assert_array(run.starter.cards.slice(0, 4)).is_equal(recipe.core_cards)
	var offer: StartOffer = StartingDeck.deal_offer(
		recipe,
		run.stock,
		run.balance,
		EventLogService.derived_stream(run.run_seed, EventLogService.STARTING_DECK_STREAM),
		not screen.profile.has_won()
	)
	var expected: DeckDefinition = StartingDeck.with_pack(
		recipe, offer.default_pack(), offer.shared
	)
	assert_array(run.starter.cards).is_equal(expected.cards)
	assert_object(run.starter.starter_pack).is_same(offer.default_pack())
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	var total: int = 0
	for card: CardDefinition in run.starter.cards:
		total += 1 if card.is_product() else 0
	assert_array(Array(view.texts())).contains(["PRODUCTS  (%d)" % total])
	# One card per distinct card.
	assert_int(view.card_views().size()).is_equal(_distinct(run.starter.cards))


## v0.51: the Cart page keeps the cart reveal's pick marks for the run (#56: on the item's art):
## a starting pick's "+" (the coupon's token); a staple and a card only the machine gave have
## none (#105: the staple's padlock shows only on the cart reveal). The marks sit on the art's top
## left, inside the cell, apart from each other and clear of the copies' count label; the legend
## names them and has no staple entry.
func test_the_cart_page_marks_staples_and_picks() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(20261014, false)
	var run: RunState = screen.run
	# A machine prize the deal didn't give (a capsule product: never dealt).
	var prize: CardDefinition = load("res://data/cards/lemon.tres")
	assert_bool(run.starter.cards.has(prize)).is_false()
	run.deck.add_card(prize)
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	await get_tree().create_timer(0.4).timeout
	var picks: Array[CardDefinition] = StartingDeck.picks(run.starter)
	var seen: Dictionary[String, Array] = {}
	for cell: DeckCell in view.cells():
		var card: CardDefinition = cell.card
		var staple: Node = cell.find_child("*Staple*", true, false)
		var pick: Node = cell.get_node_or_null(DeckCell.PICK_MARK)
		var id: String = String(card.id)
		seen[id] = [staple != null, pick != null]
		assert_bool(staple != null).override_failure_message(id).is_false()
		assert_bool(pick != null).override_failure_message(id).is_equal(picks.has(card))
		var column: Rect2 = cell.get_global_rect()
		var count: Control = cell.get_node_or_null(DeckCell.COUNT_LABEL)
		var placed: Array[Rect2] = []
		for mark: RevealChip in cell.marks():
			var rect: Rect2 = mark.get_global_rect().grow(RevealChip.OUTLINE)
			assert_float(rect.position.x).override_failure_message(id).is_greater_equal(
				column.position.x
			)
			assert_float(rect.end.x).override_failure_message(id).is_less_equal(column.end.x)
			if count != null:
				(
					assert_bool(rect.intersects(count.get_global_rect()))
					. override_failure_message(id)
					. is_false()
				)
			for other: Rect2 in placed:
				assert_bool(rect.intersects(other)).override_failure_message(id).is_false()
			placed.append(rect)
	# Banana: a staple only (no mark); the machine's prize: none; the pack's coupon: a pick.
	assert_array(seen["banana"]).is_equal([false, false])
	assert_array(seen["lemon"]).is_equal([false, false])
	var coupon: CardDefinition = picks[0]
	assert_bool(coupon.is_coupon()).is_true()
	assert_array(seen[String(coupon.id)]).is_equal([false, true])
	assert_array(Array(view.texts())).contains([DeckView.PICK_LEGEND, DeckView.COUPON_LEGEND])
	assert_array(Array(view.texts())).not_contains(["staple"])


## #56: any dealt cart, and a full cart of 15 distinct cards with BIG and GOLDEN copies, fits the
## Cart page unscrolled: every cell sits inside the scroll area on the page's two shelves, no two
## cells overlap, and the view sits inside the window below the top bar, at most
## MAX_PANEL_HEIGHT tall (a centred pop-in that leaves the top bar clickable). The seed is the
## first in 0 to 199 that deals the most distinct cards on a new profile's stock.
func test_a_dealt_or_full_cart_fits_unscrolled() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var recipe: DeckDefinition = load(ShiftScreen.STARTER_DECK)
	var stock: RunStock = RunStock.starting(balance)
	var widest: int = -1
	var widest_size: int = 0
	for seed_value: int in 200:
		var stream: RandomNumberGenerator = EventLogService.derived_stream(
			seed_value, EventLogService.STARTING_DECK_STREAM
		)
		var offer: StartOffer = StartingDeck.deal_offer(recipe, stock, balance, stream, true)
		var cart: DeckDefinition = StartingDeck.with_pack(
			recipe, offer.default_pack(), offer.shared
		)
		var size: int = _distinct(cart.cards)
		if size > widest_size:
			widest = seed_value
			widest_size = size
	# The most distinct: up to 12 (the 3 staples, the pack's 3, 6 products), more than one shelf.
	assert_int(widest_size).is_greater(DeckView.COLUMNS)
	var screen: ShiftScreen = await _screen()
	for full: bool in [false, true]:
		screen.start_new_run(widest, false)
		var run: RunState = screen.run
		if full:
			_fill_distinct(run)
			assert_int(_distinct_in_deck(run)).is_equal(run.balance.deck_limit)
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		# Past the pop-in tween, whose overshoot scales the panel for a moment.
		await get_tree().create_timer(0.4).timeout
		var where: String = "full" if full else "seed %d" % widest
		var rect: Rect2 = view.get_global_rect()
		(
			assert_bool(screen.get_global_rect().encloses(rect))
			. override_failure_message(where)
			. is_true()
		)
		assert_float(rect.position.y).is_greater_equal(screen._shade.offset_top)
		assert_float(rect.size.y).is_less_equal(MAX_PANEL_HEIGHT)
		assert_float(view._scroll.size.y).is_equal(DeckView.PAGE_SIZE.y)
		var content: Control = view._scroll.get_child(0)
		assert_float(content.size.y).override_failure_message(where).is_less_equal(
			view._scroll.size.y
		)
		var area: Rect2 = view._scroll.get_global_rect()
		assert_array(_cells_inside(view, area)).override_failure_message(where).not_contains(
			[false]
		)
		assert_int(view._deck_page.find_children("*", "DeckShelf", true, false).size()).is_equal(
			DeckView.MIN_SHELVES
		)
		var cells: Array[DeckCell] = view.cells()
		assert_int(cells.size()).is_equal(_distinct_in_deck(run))
		for index: int in cells.size():
			for other: int in range(index + 1, cells.size()):
				var overlap: bool = cells[index].get_global_rect().intersects(
					cells[other].get_global_rect()
				)
				assert_bool(overlap).override_failure_message(where).is_false()
		view._close()
		await get_tree().process_frame


## The shelves' slots: products from the first slot, the coupons at the end of the last shelf
## after at least one empty slot; a 15-distinct cart takes two shelves of 10.
func test_shelf_slots_put_the_coupons_at_the_end() -> void:
	assert_array(DeckView.shelf_slots(8, 1, 10)).is_equal([0, 1, 2, 3, 4, 5, 6, 7, 9])
	assert_array(DeckView.shelf_slots(9, 1, 10)).is_equal([0, 1, 2, 3, 4, 5, 6, 7, 8, 19])
	assert_array(DeckView.shelf_slots(12, 1, 10)).is_equal(
		[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 19]
	)
	assert_array(DeckView.shelf_slots(13, 2, 10)).is_equal(
		[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 18, 19]
	)
	assert_array(DeckView.shelf_slots(0, 2, 10)).is_equal([8, 9])
	assert_array(DeckView.shelf_slots(3, 0, 10)).is_equal([0, 1, 2])


## The fixed starter deck's page shows whole, unscrolled: every card and its count line sit
## inside the scroll area, and the view sits inside the window below the top bar. (A dealt deck,
## v0.49, can hold more than one row of distinct products: its page scrolls, see
## test_a_dealt_deck_with_two_product_rows_scrolls_inside_its_area.)
func test_the_starting_deck_fits_without_scrolling() -> void:
	var screen: ShiftScreen = await _screen()
	var balance: BalanceDefinition = screen.run.balance
	screen.run = RunState.new(61, load(STARTER), balance, RunStock.starting(balance))
	screen.run.start_shift()
	screen._on_shift_started()
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
				# Shift 2 is a boon day (v0.69).
				"Next shift: a good day (announced at checkout).",
				"Aisles:",
				"Cold cases,",
				"Pantry,",
				"Household",
			]
		)
	)
	# No inspection: no warning sign shows.
	for warning: Node in view.find_children("Warning", "TextureRect", true, false):
		assert_float((warning as TextureRect).self_modulate.a).is_equal(0.0)
	assert_int(view.card_views().size()).is_equal(screen.run.stock.cards.size())
	assert_int(view.card_views().size()).is_equal(28)
	view._close()
	screen._debug.give_upgrade("category_engine")
	screen._debug.set_inspection("spot_check")
	screen._on_deck_button_pressed()
	view.show_page(true)
	texts = view.texts()
	assert_bool(texts.has("None yet.")).is_false()
	(
		assert_array(Array(texts))
		. contains(
			[
				"Category engine",
				"CATEGORY ENGINE",
				(
					"+3 for each different tag among your products  ·  Paid on the last product"
					+ " in the row"
				),
				"This shift: Spot check, Slot 3 pays €0",
			]
		)
	)
	# The upgrade's LOYALTY stamp ring with its perk icon (#108 follow-up), and the inspected
	# shift's warning sign.
	var icons: Array[String] = []
	for holder: Node in view._info_page.find_children(
		LoyaltyCard.ICON_NAME, "Control", true, false
	):
		icons.append((holder.get_child(0) as TextureRect).texture.resource_path)
	assert_array(icons).contains(["res://art/icons/combo_diamond.png"])
	var warned: int = 0
	for warning: Node in view.find_children("Warning", "TextureRect", true, false):
		warned += 1 if (warning as TextureRect).self_modulate.a > 0.0 else 0
	assert_int(warned).is_equal(1)
	view.show_page(false)
	assert_str(view.texts()[0]).starts_with("Tags: ")


## Before an inspected shift the next one is announced as coming (it is drawn at checkout), a
## Manager's review by its name; the last shift has no next shift.
func test_run_info_announces_a_scheduled_inspection() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(2)
	# Shift 2 is a boon day (v0.69): its boon is this shift's event, never an inspection.
	var boons: Array[InspectionDefinition] = InspectionDefinition.boons(screen.run.inspections)
	assert_int(boons.size()).is_equal(1)
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	var this_shift: String = "This shift: %s, %s" % [boons[0].display_name, boons[0].notice_text]
	assert_array(Array(view.texts())).contains(
		[this_shift, "Next shift: inspected (announced at checkout)."]
	)
	view._close()
	# Shift 3: the next one is the first Manager's review (v0.65).
	screen._debug.skip_to_shift(3)
	screen._on_deck_button_pressed()
	view.show_page(true)
	assert_array(Array(view.texts())).contains(
		["Next shift: Manager's review (announced at checkout)."]
	)
	view._close()
	screen._debug.skip_to_shift(screen.run.shift_count())
	screen._on_deck_button_pressed()
	view.show_page(true)
	var texts: PackedStringArray = view.texts()
	(
		assert_bool(
			Array(texts).any(func(text: String) -> bool: return text.begins_with("Next shift"))
		)
		. is_false()
	)
	# The last shift is the final Manager's review (v0.65): its inspections, all of them.
	assert_int(screen.run.inspections.size()).is_equal(2)
	var line: String = DeckView._inspection_line("This shift", screen.run.inspections)
	assert_array(Array(texts)).contains([line])
	assert_str(line).starts_with("This shift: Manager's review: ")
	for inspection: InspectionDefinition in screen.run.inspections:
		assert_str(line).contains(inspection.display_name)


## During the machine's visit (#77) the drawn inspection shows for the next shift, and the shift
## just played is no longer called "This shift".
func test_run_info_during_the_machine_shows_the_drawn_inspection() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.skip_to_shift(2)
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		screen.run.place(screen.run.debug_add_to_hand(card), screen.run.row.size())
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_object(screen.run.next_inspection).is_not_null()
	await _until_machine_armed(screen)
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	assert_bool(view.visible).is_true()
	assert_bool(screen._machine.view.visible).is_false()
	view.show_page(true)
	var texts: PackedStringArray = view.texts()
	var drawn: InspectionDefinition = screen.run.next_inspection
	assert_array(Array(texts)).contains(
		["Next shift: %s, %s" % [drawn.display_name, drawn.notice_text]]
	)
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
	for cell: DeckCell in view.cells():
		var mark: RevealChip = cell.get_node_or_null(DeckCell.NEW_MARK)
		assert_bool(mark != null).is_equal(cell.card == arrival)
		if mark != null:
			assert_str(mark.text_label().text).is_equal(DeckCell.NEW_TEXT)


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


## The real flow: a NEW ITEMS prize picked at the deck limit opens the cart with no free spot, and
## dropping it on the grouped Banana removes one Banana copy.
func test_a_prize_at_the_deck_limit_removes_one_copy_of_a_grouped_card() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	while not run.deck_is_full():
		run.deck.add_card(load("res://data/cards/soup.tres"))
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		run.place(run.debug_add_to_hand(card), run.row.size())
	await Rush.checkout(screen)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var bananas: int = _copies(run, &"banana")
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _until_machine_armed(screen)
	screen._machine.view.pick(0)
	var view: DeckView = screen._deck_view
	assert_bool(view.visible).is_true()
	assert_bool(view._info_tab.visible).is_false()
	assert_array(view.placing().spots()).is_empty()
	screen._machine.on_deck_added()  # No free spot: nothing is added.
	assert_int(run.deck.size()).is_equal(run.balance.deck_limit)
	await get_tree().process_frame
	view.placing().drop_at(view.cells()[0].get_global_rect().get_center())
	screen._machine.view.fast_forward()  # The landing plays to its end.
	assert_int(run.phase).is_not_equal(RunState.Phase.MACHINE_PICK)
	assert_int(run.deck.size()).is_equal(run.balance.deck_limit)
	var picked_banana: int = 1 if run.history[0].cards_added()[0].id == &"banana" else 0
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


## A full collection's stock (the base stock plus 15 more cards, about 40) and a deck past the limit
## still fit the window: the pages scroll inside a fixed area (the stock's shelves scroll).
func test_a_big_stock_and_deck_fit_the_screen() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var base_stock: int = run.stock.cards.size()
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
		if page:
			assert_float(content.size.y).is_greater(view._scroll.size.y)
	assert_int(view.card_views().size()).is_equal(base_stock + 15)


## #56: resting the pointer on an item opens the scan popup beside it, inside the window, with the
## card's rule text, and lifts the item; leaving it closes the popup. In the chooser the hovered
## item also gets the gold ring; browsing never rings it.
func test_hovering_an_item_shows_its_effect() -> void:
	var screen: ShiftScreen = await _screen()
	for choosing: bool in [false, true]:
		var view: DeckView = screen._deck_view
		view.open(screen.run, "Your cart", choosing)
		await get_tree().create_timer(0.4).timeout
		var cells: Array[DeckCell] = view.cells()
		var cell: DeckCell = cells[floori(cells.size() / 2.0)]
		cell.item().hovered.emit(cell.item())
		var popup: ScanPopup = view.popup()
		assert_bool(popup.visible).is_true()
		assert_bool(cell.item().lifted).is_true()
		assert_bool(cell.ringed).is_equal(choosing)
		assert_str(popup.rule_label().text).is_equal(cell.card.rule_text)
		var rect: Rect2 = popup.get_global_rect()
		assert_bool(screen.get_global_rect().encloses(rect)).is_true()
		# Beside the item's column, never over it.
		var column: Rect2 = cell.get_global_transform() * cell.column_rect()
		assert_bool(rect.intersects(column)).is_false()
		cell.item().unhovered.emit(cell.item())
		assert_bool(popup.visible).is_false()
		assert_bool(cell.item().lifted).is_false()
		assert_bool(cell.ringed).is_false()
		view._close()


## The mix highlight in the Cart (#105 piece 3, mock-up readability v3's Cart): hovering an item
## lights the cells it works with and greys the whole of every other cell (a broad "next Food"
## match greyed under a dashed outline round its cell, never a check); a family lights its cells;
## leaving puts every cell back; in choosing mode nothing greys.
func test_the_cart_lights_what_an_item_works_with() -> void:
	var screen: ShiftScreen = await _screen()
	var view: DeckView = screen._deck_view
	view.open(screen.run, "Your cart", false)
	await get_tree().create_timer(0.4).timeout
	var cells: Array[DeckCell] = view.cells()
	var milk: DeckCell = null
	for cell: DeckCell in cells:
		if cell.card.product_card().id == &"milk":
			milk = cell
	assert_object(milk).is_not_null()
	milk.item().hovered.emit(milk.item())
	var lit: int = 0
	var greyed: int = 0
	for cell: DeckCell in cells:
		var hit: CardAffinity.Match = CardAffinity.between(
			milk.card,
			milk.card.tags,
			cell.card,
			cell.card.tags,
			FamilyPalette.shared().quiet_families
		)
		var expected: MixModel.Look = MixModel.Look.GREY
		if cell == milk:
			expected = MixModel.Look.SELF
		elif hit == CardAffinity.Match.YES:
			expected = MixModel.Look.LIT
		elif hit == CardAffinity.Match.WEAK:
			expected = MixModel.Look.FAINT
		assert_int(cell.mix_look).override_failure_message(cell.card.id).is_equal(expected)
		var grey: bool = MixModel.greys(expected)
		var brightness: float = view.tuning.mix_brightness if grey else 1.0
		assert_float(cell.item().modulate.r).is_equal_approx(brightness, 0.001)
		assert_float(cell.name_label().modulate.r).is_equal_approx(brightness, 0.001)
		lit += 1 if expected == MixModel.Look.LIT else 0
		greyed += 1 if grey else 0
		var outline: bool = cell.mix_mark() != null and cell.mix_mark().visible
		assert_bool(outline).is_equal(expected == MixModel.Look.FAINT)
		if outline:
			var drawn: Rect2 = cell.get_global_transform() * cell.mix_mark().mark_rect()
			assert_bool(screen.get_global_rect().encloses(drawn)).is_true()
	assert_int(lit).is_greater(0)
	assert_int(greyed).is_greater(0)
	milk.item().unhovered.emit(milk.item())
	var stacked: int = 0
	for cell: DeckCell in cells:
		assert_int(cell.mix_look).is_equal(MixModel.Look.NONE)
		assert_float(cell.item().modulate.r).is_equal(1.0)
		# The copies stacked behind keep their dimmed tint through the hover and after it.
		for copy: TextureRect in _stack_copies(cell):
			assert_that(copy.self_modulate).is_equal(DeckCell.STACK_TINT)
			assert_float(copy.modulate.r).is_equal(1.0)
			stacked += 1
	assert_int(stacked).is_greater(0)
	# A family lights its cells.
	view.mix_family = "Breakfast"
	for cell: DeckCell in cells:
		var in_family: bool = cell.item().tags().has("Breakfast")
		var expected: MixModel.Look = MixModel.Look.LIT if in_family else MixModel.Look.GREY
		assert_int(cell.mix_look).override_failure_message(cell.card.id).is_equal(expected)
	view.mix_family = ""
	view._close()
	# Choosing mode: no highlight.
	view.open(screen.run, "choose", true)
	await get_tree().create_timer(0.4).timeout
	var chooser: DeckCell = view.cells()[0]
	chooser.item().hovered.emit(chooser.item())
	view.mix_family = "Breakfast"
	for cell: DeckCell in view.cells():
		assert_int(cell.mix_look).is_equal(MixModel.Look.NONE)
	view.mix_family = ""
	view._close()


## The copies stacked behind `cell`'s item (DeckCell._add_stack): its plain sprites tinted
## STACK_TINT.
func _stack_copies(cell: DeckCell) -> Array[TextureRect]:
	var copies: Array[TextureRect] = []
	for child: Node in cell.get_children():
		var copy: TextureRect = child as TextureRect
		if copy != null and copy.self_modulate == DeckCell.STACK_TINT:
			copies.append(copy)
	return copies


## #56: the title's and headings' numbers print in the number font (Pixelify's digits read poorly),
## the words in the display font.
func test_numbers_print_in_the_number_font() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	assert_str(view.title_text()).is_equal(
		"Your cart (%d/%d)" % [screen.run.deck.size(), screen.run.balance.deck_limit]
	)
	var fonts: Dictionary[String, Font] = {}
	for label: Label in view._title.labels():
		fonts[label.text] = label.get_theme_font("font")
	assert_object(fonts["Your cart"]).is_same(ArtStyle.DISPLAY_FONT)
	var count: String = "(%d/%d)" % [screen.run.deck.size(), screen.run.balance.deck_limit]
	assert_object(fonts[count]).is_same(ArtStyle.number_font())


## #56: every card's name fits its line under its item at one of the name's sizes (the plain
## product's name for a BIG or GOLDEN card).
func test_every_name_fits_under_its_item() -> void:
	var font: Font = ArtStyle.bold_font(DeckCell.NAME_WEIGHT)
	for file_name: String in DirAccess.get_files_at("res://data/cards"):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards/" + file_name)
		var shown: String = (card.product_card() if card.is_product() else card).display_name
		var size: int = DeckCell.name_size(shown)
		var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		assert_float(width).override_failure_message(shown).is_less_equal(
			DeckCell.SIZE.x + DeckCell.NAME_SPILL
		)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for frame: int in range(2):
		await get_tree().process_frame
	return screen


## Fills `run`'s cart to the deck limit with distinct cards: one copy of each dealt card, the
## first Banana GOLDEN and the first Milk BIG, then stocked products the cart lacks.
static func _fill_distinct(run: RunState) -> void:
	var kept: Array[CardDefinition] = []
	for card: CardInstance in run.deck.cards.duplicate():
		if kept.has(card.definition):
			run.deck.remove_card(card)
		else:
			kept.append(card.definition)
	for tier: Array in [["banana", "banana_golden"], ["milk", "milk_big"]]:
		for card: CardInstance in run.deck.cards:
			if card.definition.id == StringName(tier[0]):
				run.deck.upgrade(card, load("res://data/cards/%s.tres" % tier[1]))
				break
	for card: CardDefinition in DeckSummary.in_view_order(run.stock.cards):
		var owned: bool = run.deck.cards.any(
			func(owned_card: CardInstance) -> bool:
				return owned_card.definition.is_same_product(card)
		)
		if not owned and not run.deck_is_full():
			run.deck.add_card(card)


static func _distinct_in_deck(run: RunState) -> int:
	var cards: Array[CardDefinition] = []
	for card: CardInstance in run.deck.cards:
		cards.append(card.definition)
	return _distinct(cards)


## Whether each card view's cell sits inside `area` (for each card, in order).
static func _cells_inside(view: DeckView, area: Rect2) -> Array[bool]:
	var inside: Array[bool] = []
	for card_view: CardView in view.card_views():
		var cell: Control = card_view.get_parent()
		inside.append(area.encloses(cell.get_global_rect()))
	return inside


static func _distinct(cards: Array[CardDefinition]) -> int:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in cards:
		if not found.has(card):
			found.append(card)
	return found.size()


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


## Fast-forwards the machine to its wait point (as a tap would, unlogged), then waits (at most
## 3 s) for it to arm: the mouse is up, so it arms on its next frame.
func _until_machine_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()
