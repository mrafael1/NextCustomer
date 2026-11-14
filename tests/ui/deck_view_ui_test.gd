extends GdUnitTestSuite
## The extended deck view on the real shift screen (plan section 2, full build phase 1; the cart
## and run info polish, 2026-11-12; the cart as cards and the slim Run info, 2026-11-13): the Cart
## tab (one card per distinct card with its copies, the tag chips, the START marks, the rarity
## tabs, the full rules), the Run info tab (the run at a glance and the stock's icon grid, no
## upgrades or inspections), the hover popups, the choosing mode, and that it fits the window at
## 1280x720 and 1920x1080. Clicks go to the handlers (headless runs).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
## A centred pop-in on the 720 px screen that leaves the top bar (and the shade's top, 64)
## clear (#56's derived limit).
const MAX_PANEL_HEIGHT := 592.0
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const PACKS := "res://data/starter_packs"
const BALANCE := "res://data/balance/balance.tres"
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
## printed-tag counts as icon chips (each family's glyph and its count in the number font, most
## common first, no words).
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
	var chips: Array[FamilyCount] = _tag_chips(view)
	var shown: Array[String] = []
	var palette: FamilyPalette = FamilyPalette.shared()
	for chip: FamilyCount in chips:
		shown.append("%s %d" % [chip.family, chip.count])
		assert_int(chip.look).is_equal(FamilyCount.Look.CHIP)
		var style: FamilyStyle = palette.style(chip.family)
		assert_object(chip.icon().texture).is_same(style.glyph)
		assert_str(chip.count_label().text).is_equal(str(chip.count))
		assert_object(chip.count_label().get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_str(chip.tip_text).contains(chip.family)
	assert_array(shown).is_equal(["Food 10", "Breakfast 8", "Produce 3", "Bakery 2", "Dairy 2"])
	var texts: PackedStringArray = view.texts()
	(
		assert_bool(Array(texts).any(func(text: String) -> bool: return text.contains("Tags")))
		. is_false()
	)
	assert_array(Array(texts)).contains(["PRODUCTS 12", "COUPONS 1"])
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
		assert_int(cell.copies).is_equal(maxi(1, counts[id].trim_prefix("×").to_int()))
		# The plain starter deck isn't dealt: no START marks, and no legend.
		assert_array(cell.marks()).is_empty()
	assert_array(ids).is_equal(counts.keys())
	assert_object(view.find_child("Legend", true, false)).is_null()
	# The coupon stands after the products, behind the dashed separator, under its own label.
	var cells: Array[DeckCell] = view.cells()
	var separator: Control = view._deck_page.find_child(DeckView.SEPARATOR, true, false)
	assert_object(separator).is_not_null()
	var line: float = separator.get_global_rect().get_center().x
	for cell: DeckCell in cells:
		var rect: Rect2 = cell.get_global_rect()
		if cell.card.is_coupon():
			assert_float(rect.position.x).is_greater(line)
		else:
			assert_float(rect.end.x).is_less(line)
	# The shown tab is picked (sunk, the paper face, not dimmed), the other one plain.
	assert_bool(view._deck_tab.disabled).is_true()
	assert_bool(view._deck_tab.selected).is_true()
	assert_that(view._deck_tab.modulate).is_equal(Color.WHITE)
	assert_bool(view._info_tab.visible).is_true()
	assert_bool(view._info_tab.selected).is_false()
	assert_str(view.title_text()).starts_with("Your cart")


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
	var offer: StartOffer = run.start_offer
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
	assert_array(Array(view.texts())).contains(["PRODUCTS %d" % total])
	# One card per distinct card.
	assert_int(view.cells().size()).is_equal(_distinct(run.starter.cards))


## The cart and run info polish (2026-11-12): every product picked at the start (the starter
## pack's cards and the dealt ones) carries the green START chip for the run, over its card's
## barcode (the art's bottom left), its tooltip (opening below it) saying where it came from ("from
## the Bakery booster" since 2026-11-13); a regular and a product only the machine gave carry
## none. The chip sits inside the card, clear of the copies' count, the rule text and the top
## line's labels; the legend names it.
func test_the_cart_page_marks_the_starting_cart() -> void:
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
	var started: Array[StringName] = []
	for card: CardDefinition in StartingDeck.picks(run.starter):
		started.append(card.product_card().id)
	var plates: Array[Node] = view._deck_page.find_children(
		"Heading", "PanelContainer", true, false
	)
	assert_int(plates.size()).is_equal(2)
	var marked: int = 0
	for cell: DeckCell in view.cells():
		var id: String = String(cell.card.id)
		var mark: RevealChip = cell.face().get_node_or_null(DeckCell.START_MARK) as RevealChip
		var expected: bool = started.has(cell.card.product_card().id)
		assert_bool(mark != null).override_failure_message(id).is_equal(expected)
		if mark == null:
			continue
		marked += 1
		assert_str(mark.text_label().text).is_equal(DeckCell.START_TEXT)
		assert_that(mark.fill).is_equal(Palette.GREEN_DARK)
		# Its tooltip covers the chip and says where the item came from.
		var tip: StartTip = mark.get_node("StartTip") as StartTip
		assert_str(tip.tip_text).starts_with(StartTip.HEAD + " · ")
		assert_str(tip.tip_text).not_contains(StartTip.HEAD + " · " + StartTip.HEAD)
		assert_bool(tip.tip_below).is_true()
		assert_bool(tip.get_global_rect().is_equal_approx(mark.get_global_rect())).is_true()
		_assert_start_and_count(cell)
		for plate: Node in plates:
			var label: Rect2 = (plate as Control).get_global_rect()
			assert_bool(label.intersects(mark.get_global_rect())).is_false()
	assert_int(marked).is_greater(0)
	# Where each came from: the pack, a dealt aisle's booster; a regular and the prize carry none.
	var sources: Dictionary[StringName, String] = DeckView.start_sources(run)
	assert_array(sources.keys()).contains_exactly_in_any_order(started)
	var regulars: int = 0
	for card: CardDefinition in run.starter.core_cards:
		if not started.has(card.product_card().id):
			regulars += 1
			assert_bool(sources.has(card.product_card().id)).is_false()
	assert_int(regulars).is_greater(0)
	var pack: StarterPackDefinition = run.starter.starter_pack
	for card: CardDefinition in pack.cards:
		assert_str(sources[card.product_card().id]).is_equal(StartTip.PACK % pack.display_name)
	var dealt: int = 0
	for card: CardDefinition in StartingDeck.shared_of(run.starter):
		var source: String = sources[card.product_card().id]
		if source.begins_with("from the ") and source.ends_with(" booster"):
			dealt += 1
		assert_str(source).not_contains("dealt from")
	assert_int(dealt).is_greater(0)
	assert_bool(sources.has(&"lemon")).is_false()
	var texts: Array = Array(view.texts())
	assert_array(texts).contains([DeckView.START_LEGEND, DeckCell.START_TEXT])
	# The START card's tip says where it came from.
	for cell: DeckCell in view.cells():
		if not cell.marks().is_empty():
			view.hover(cell)
			assert_array(view.tip().lines()).contains(
				[CardTip.START_TEXT % sources[cell.card.product_card().id]]
			)
			break


## #56: any dealt cart, and a full cart of 15 distinct cards with BIG and GOLDEN copies, fits the
## Cart page unscrolled: every card sits inside the scroll area in the page's two rows
## (CartLayout), no two cards overlap, and the view sits inside the window below the top bar, at
## most MAX_PANEL_HEIGHT tall (a centred pop-in that leaves the top bar clickable). The top line
## says the room left (CART FULL on a full cart). The seed is the first in 0 to 199 that deals the
## most distinct cards on a new profile's stock.
func test_a_dealt_or_full_cart_fits_unscrolled() -> void:
	var balance: BalanceDefinition = load(BALANCE)
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
	# The most distinct: up to 12 (the 3 staples, the pack's 3, 6 products), more than one row.
	assert_int(widest_size).is_greater(CartLayout.COLUMNS)
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
		var cells: Array[DeckCell] = view.cells()
		assert_int(cells.size()).is_equal(_distinct_in_deck(run))
		_assert_cards_laid_out(cells, area, where)
		# The room left, on the top line: CART FULL in tomato, else ROOM FOR n MORE.
		var note: MixedLabel = view._deck_page.find_child(DeckView.ROOM_NOTE_NAME, true, false)
		var room: int = run.balance.deck_limit - run.deck.size()
		assert_str(note.text).is_equal(DeckView.FULL_NOTE if full else DeckView.ROOM_NOTE % room)
		assert_bool(area.encloses(note.get_global_rect())).is_true()
		for cell: DeckCell in cells:
			assert_bool(cell.get_global_rect().intersects(note.get_global_rect())).is_false()
		view._close()
		await get_tree().process_frame


## The fixed starter deck's page shows whole, unscrolled: every card sits inside the scroll area,
## and the view sits inside the window below the top bar.
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
	for cell: DeckCell in view.cells():
		assert_bool(area.encloses(cell.get_global_rect())).is_true()
	var rect: Rect2 = view.get_global_rect()
	assert_bool(screen.get_global_rect().encloses(rect)).is_true()
	assert_float(rect.position.y).is_greater_equal(screen._shade.offset_top)


## The slim Run info (2026-11-13): the run at a glance (the run family's card: the starter pack's
## family glyph big, its name, the pack and its hint; the run's two aisles in stock and the
## staples' line, its count from data; the cart's families as tiles, each a big glyph and its
## count in the number font, the run family's ringed), then MACHINE STOCK as an icon grid grouped
## STAPLES, each aisle, COUPONS. It shows no upgrades and no inspections, even with one of each.
func test_the_run_info_tab_shows_the_run_at_a_glance_and_the_stock() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("category_engine")
	screen._debug.set_inspection("spot_check")
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	await get_tree().create_timer(0.4).timeout
	var run: RunState = screen.run
	assert_str(view.title_text()).is_equal(DeckView.INFO_TITLE)
	assert_bool(view._info_tab.selected and view._info_tab.disabled).is_true()
	assert_bool(view._deck_tab.selected or view._deck_tab.disabled).is_false()
	var texts: Array = Array(view.texts())
	assert_array(texts).not_contains(
		["UPGRADES", "INSPECTIONS", "None yet.", "Category engine", "CATEGORY ENGINE"]
	)
	for text: String in texts:
		assert_bool(text.begins_with("This shift") or text.begins_with("Next shift")).is_false()
	assert_array(view.find_children("Warning", "", true, false)).is_empty()
	assert_array(view._info_page.find_children(LoyaltyCard.ICON_NAME, "", true, false)).is_empty()
	# The run family's card.
	var pack: StarterPackDefinition = run.starter.starter_pack
	var palette: FamilyPalette = FamilyPalette.shared()
	var card: Control = view._info_page.find_child(RunInfoHero.PACK_CARD, true, false)
	assert_object(card).is_not_null()
	var glyph: FamilyGlyph = card.find_child(RunInfoHero.FAMILY_GLYPH, true, false) as FamilyGlyph
	assert_str(glyph.family).is_equal(pack.family)
	assert_float(glyph.size.x).is_greater_equal(54.0)
	# The hint in the handbook's colours: its words unchanged, its terms marked (MORNING, Coffee).
	var hint: RichTextLabel = card.find_child(RunInfoHero.HINT, true, false) as RichTextLabel
	assert_object(hint).is_not_null()
	assert_str(hint.get_parsed_text()).is_not_empty()
	var markup: String = RunInfoHero.hint_markup(pack)
	assert_str(HandbookMarkup.plain(markup)).is_equal(pack.hint_text)
	assert_str(markup).contains("{kw:MORNING}").contains("{item:coffee}")
	var staples: int = RunStock.staples(run.balance).size()
	(
		assert_array(texts)
		. contains(
			[
				palette.style(pack.family).display_name,
				RunInfoHero.PACK_SUFFIX % pack.display_name,
				RunInfoHero.RUN_FAMILY,
				RunInfoHero.IN_CART,
				DeckView.STOCK_HEADING,
				RunInfoHero.STAPLES_NOTE % staples,
			]
		)
	)
	# The aisles in stock: since v1.32 the run's two boosters' aisles, one plate each, by name,
	# then the staples' line.
	var rows: Array[AisleDefinition] = RunInfoHero.aisle_rows(run)
	assert_int(rows.size()).is_equal(2)
	var plates: Node = view._info_page.find_child(RunInfoHero.PLATES, true, false)
	assert_int(plates.get_child_count()).is_equal(rows.size() + 1)
	assert_str(plates.get_child(-1).name).is_equal(RunInfoHero.STAPLES_NAME)
	var plate_names: Array = []
	for label: Node in plates.find_children("AisleName", "Label", true, false):
		plate_names.append((label as Label).text)
	for aisle: AisleDefinition in run.balance.aisles:
		(
			assert_bool(plate_names.has(aisle.display_name))
			. override_failure_message(aisle.display_name)
			. is_equal(run.stock.aisle_ids.has(aisle.id))
		)
	# The families: one tile per printed tag, most common first.
	var counts: Dictionary[String, int] = DeckSummary.tag_counts(run.deck.cards)
	var tiles: Array[FamilyCount] = []
	for child: Node in view._info_page.find_child(RunInfoHero.TILES, true, false).get_children():
		tiles.append(child as FamilyCount)
	assert_int(tiles.size()).is_equal(counts.size())
	for index: int in tiles.size():
		var tile: FamilyCount = tiles[index]
		assert_str(tile.family).is_equal(counts.keys()[index])
		assert_int(tile.count).is_equal(counts[tile.family])
		assert_int(tile.look).is_equal(FamilyCount.Look.TILE)
		assert_str(tile.count_label().text).is_equal(str(tile.count))
		var number: Label = tile.count_label()
		assert_object(number.get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_int(number.get_theme_font_size("font_size")).is_equal(FamilyCount.TILE_NUMBER_SIZE)
		assert_float(tile.icon().size.x).is_equal(36.0)
		assert_float(tile.size.y).is_equal(FamilyCount.TILE_SIZE.y)
		assert_bool(tile.ringed).override_failure_message(tile.family).is_equal(
			tile.family == pack.family
		)
	# The stock: the staples and two aisles' base products since the v1.32 feedback, and the
	# coupons of coupon_pool, as icons, each once, grouped STAPLES, the aisles, COUPONS.
	var grid: StockGrid = view.stock_grid()
	var expected: int = staples + run.balance.coupon_pool.size()
	for aisle: AisleDefinition in rows:
		expected += aisle.base_cards.size()
	assert_int(grid.icons().size()).is_equal(expected)
	var names: Array[String] = []
	for header: Control in grid.headers():
		names.append((header.find_child("GroupName", true, false) as Label).text)
	var wanted: Array[String] = [StockGrid.STAPLES]
	for aisle: AisleDefinition in run.balance.aisles:
		if run.stock.aisle_ids.has(aisle.id):
			wanted.append(aisle.display_name.to_upper())
	wanted.append(StockGrid.COUPONS)
	assert_array(names).is_equal(wanted)
	assert_object(grid.find_child(StockGrid.LEGEND, true, false)).is_not_null()


## The cart and run info polish: at 1280x720 and 1920x1080 a full cart's page fits unscrolled, its
## tag chips, START marks and rules inside the scroll area, the chips clear of the legend and of
## the cards; the Run info's hero (the run family's card, the aisle plates, the family tiles) sits
## whole inside the scroll area unscrolled, the tiles side by side, for every starter pack's card
## (as tall as its words).
func test_the_cart_and_run_info_fit_both_windows() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen_at(window)
		screen.start_new_run(20261014, false)
		screen._week.skip()
		_fill_distinct(screen.run)
		screen._on_deck_button_pressed()
		var view: DeckView = screen._deck_view
		# Past the pop-in tween, whose overshoot scales the panel for a moment.
		await get_tree().create_timer(0.4).timeout
		var where: String = str(window)
		assert_bool(Rect2(Vector2.ZERO, window).encloses(view.get_global_rect())).is_true()
		# The scroll area, half a pixel of slack for the centred panel's rounding.
		var area: Rect2 = view._scroll.get_global_rect().grow(0.5)
		var content: Control = view._scroll.get_child(0)
		assert_float(content.size.y).override_failure_message(where).is_less_equal(
			view._scroll.size.y
		)
		var chips: Array[FamilyCount] = _tag_chips(view)
		assert_int(chips.size()).is_greater(0)
		var legend: Control = view._deck_page.find_child("Legend", true, false)
		var cells: Array[DeckCell] = view.cells()
		for chip: FamilyCount in chips:
			var rect: Rect2 = chip.get_global_rect()
			assert_bool(area.encloses(rect)).override_failure_message(where).is_true()
			assert_float(rect.size.y).is_equal(FamilyCount.CHIP_HEIGHT)
			assert_bool(rect.intersects(legend.get_global_rect())).is_false()
			for cell: DeckCell in cells:
				assert_bool(rect.intersects(cell.get_global_rect())).is_false()
		for plate: Node in view._deck_page.find_children("Heading", "PanelContainer", true, false):
			var label: Rect2 = (plate as Control).get_global_rect()
			assert_bool(area.encloses(label)).override_failure_message(where).is_true()
			assert_bool(label.intersects(legend.get_global_rect())).is_false()
		for cell: DeckCell in cells:
			var message: String = "%s %s" % [where, cell.card.id]
			(
				assert_bool(area.encloses(cell.get_global_rect()))
				. override_failure_message(message)
				. is_true()
			)
			_assert_rule_fits(cell, message)
			for mark: RevealChip in cell.marks():
				assert_bool(area.encloses(mark.get_global_rect())).is_true()
			_assert_start_and_count(cell)
		view._close()
		await get_tree().process_frame
		# Every starter pack's card (the hints run 3 to 4 lines) leaves the hero whole, the card
		# no taller than its words.
		for path: String in DirAccess.get_files_at(PACKS):
			if not path.ends_with(".tres"):
				continue
			screen.run.starter.starter_pack = load(PACKS.path_join(path))
			screen._on_deck_button_pressed()
			view.show_page(true)
			await get_tree().create_timer(0.4).timeout
			_assert_hero_fits(view, area, "%s %s" % [where, path])
			view._close()
			await get_tree().process_frame


## At the deck limit only the deck shows, and a grouped card chooses one of its copies.
func test_the_chooser_shows_only_the_deck_and_picks_a_copy() -> void:
	var screen: ShiftScreen = await _screen()
	var chosen: Array[CardInstance] = []
	screen._deck_view.card_chosen.connect(func(card: CardInstance) -> void: chosen.append(card))
	screen._deck_view.open(screen.run, "choose", true)
	var view: DeckView = screen._deck_view
	assert_bool(view._deck_tab.visible).is_false()
	assert_bool(view._info_tab.visible).is_false()
	# No room note in the chooser: the room left is not the point there.
	assert_object(view._deck_page.find_child(DeckView.ROOM_NOTE_NAME, true, false)).is_null()
	var banana: DeckCell = view.cells()[0]
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
	screen._deck_view._on_card_clicked(screen._deck_view.cells()[0])
	assert_array(chosen).is_empty()
	assert_bool(screen._deck_view.visible).is_true()


## A full collection's stock (the base stock plus 15 more cards, about 40) and a deck past the limit
## still fit the window: the pages scroll inside a fixed area.
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
		if not page:
			var content: Control = view._scroll.get_child(0)
			assert_float(content.size.y).is_greater(view._scroll.size.y)
	assert_int(view.stock_grid().icons().size()).is_equal(base_stock + 15)


## #56: resting the pointer on a card opens its paper tip beside it, inside the window: its name,
## its rarity tag and colour, no price and its rule only when the face cut it short (2026-11-14),
## and a KEYWORD box for each keyword; it lifts the
## card; leaving it closes the tip. In the chooser the hovered card also gets the gold ring;
## browsing never rings it.
func test_hovering_a_card_shows_its_effect() -> void:
	var screen: ShiftScreen = await _screen()
	for choosing: bool in [false, true]:
		var view: DeckView = screen._deck_view
		view.open(screen.run, "Your cart", choosing)
		await get_tree().create_timer(0.4).timeout
		var cells: Array[DeckCell] = view.cells()
		var cell: DeckCell = cells[floori(cells.size() / 2.0)]
		cell.hovered.emit(cell)
		var tip: CardTip = view.tip()
		assert_bool(tip.visible).is_true()
		assert_bool(cell.lifted).is_true()
		assert_bool(cell.ringed).is_equal(choosing)
		var main: CardTip.CardTipBox = tip.main_card()
		assert_str(main.title_text()).is_equal(cell.card.display_name)
		assert_str(main.tag_text()).is_equal(CardTip.tag_of(cell.card, screen.run.balance.machine))
		var rule: String = DeckCell.rule_line(cell.card)
		var rule_shown: bool = not rule.is_empty() and tip.lines().has(rule)
		assert_bool(rule_shown).is_equal(cell.rule_clipped() and not rule.is_empty())
		for line: String in tip.lines():
			assert_str(line).not_contains("Price ")
		for rect: Rect2 in tip.card_rects():
			assert_bool(screen.get_global_rect().encloses(rect)).is_true()
			# Beside the card, never over it.
			var column: Rect2 = cell.get_global_transform() * cell.column_rect()
			assert_bool(rect.intersects(column)).is_false()
		cell.unhovered.emit(cell)
		assert_bool(tip.visible).is_false()
		assert_bool(cell.lifted).is_false()
		assert_bool(cell.ringed).is_false()
		view._close()
	# A keyword's card explains its keyword.
	var run: RunState = screen.run
	run.deck.add_card(load("res://data/cards/tea_bags_golden.tres"))
	var shown: DeckView = screen._deck_view
	shown.open(run, "Your cart", false)
	var tea: DeckCell = _cell_of(shown, &"tea_bags_golden")
	shown.hover(tea)
	var tea_tip: CardTip = shown.tip()
	assert_str(tea_tip.main_card().tag_text()).is_equal(
		CardTip.PRODUCT_TAGS[BoosterArt.Look.LEGENDARY]
	)
	# The header takes the rarity's colour: LEGENDARY gold.
	assert_that(tea_tip.main_card().band).is_equal(Palette.GOLD)
	var keyword: CardTip.CardTipBox = tea_tip.keyword_cards()[0]
	assert_str(keyword.title_text()).is_equal("MORNING")
	assert_str(keyword.tag_text()).is_equal(CardTip.KEYWORD_TAG)
	assert_array(keyword.texts()).is_equal([GlyphText.keyword_tip("MORNING")])
	shown._close()


## The mix highlight in the Cart (#105 piece 3, mock-up readability v3's Cart): hovering a card
## lights the cards it works with and greys every other card's face (a broad "next Food" match
## greyed under a dashed outline round its card, never a check); a family lights its cards;
## leaving puts every card back; in choosing mode nothing greys.
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
	milk.hovered.emit(milk)
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
		assert_float(cell.face().modulate.r).is_equal_approx(brightness, 0.001)
		lit += 1 if expected == MixModel.Look.LIT else 0
		greyed += 1 if grey else 0
		var outline: bool = cell.mix_mark() != null and cell.mix_mark().visible
		assert_bool(outline).is_equal(expected == MixModel.Look.FAINT)
		if outline:
			var drawn: Rect2 = cell.get_global_transform() * cell.mix_mark().mark_rect()
			assert_bool(screen.get_global_rect().encloses(drawn)).is_true()
	assert_int(lit).is_greater(0)
	assert_int(greyed).is_greater(0)
	milk.unhovered.emit(milk)
	for cell: DeckCell in cells:
		assert_int(cell.mix_look).is_equal(MixModel.Look.NONE)
		assert_float(cell.face().modulate.r).is_equal(1.0)
	# A family lights its cards.
	view.mix_family = "Breakfast"
	for cell: DeckCell in cells:
		var in_family: bool = cell.tags().has("Breakfast")
		var expected: MixModel.Look = MixModel.Look.LIT if in_family else MixModel.Look.GREY
		assert_int(cell.mix_look).override_failure_message(cell.card.id).is_equal(expected)
	view.mix_family = ""
	view._close()
	# Choosing mode: no highlight.
	view.open(screen.run, "choose", true)
	await get_tree().create_timer(0.4).timeout
	var chooser: DeckCell = view.cells()[0]
	chooser.hovered.emit(chooser)
	view.mix_family = "Breakfast"
	for cell: DeckCell in view.cells():
		assert_int(cell.mix_look).is_equal(MixModel.Look.NONE)
	view.mix_family = ""
	view._close()


## #56: the title's and headings' numbers print in the number font (Pixelify's digits read poorly),
## the words in the display font; the Run info page titles itself.
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
	for heading: MixedLabel in view._deck_page.find_children("*", "MixedLabel", true, false):
		var labels: Array[Label] = heading.labels()
		if heading.text.begins_with("PRODUCTS"):
			assert_object(labels[-1].get_theme_font("font")).is_same(ArtStyle.number_font())
	view.show_page(true)
	assert_str(view.title_text()).is_equal(DeckView.INFO_TITLE)
	view.show_page(false)
	assert_str(view.title_text()).starts_with("Your cart")


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for frame: int in range(2):
		await get_tree().process_frame
	return screen


## The real screen laid out at `window` (the run-start time card skipped).
func _screen_at(window: Vector2) -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	for frame: int in range(3):
		await get_tree().process_frame
	return screen


## The Cart page's tag chips, in order.
static func _tag_chips(view: DeckView) -> Array[FamilyCount]:
	var chips: Array[FamilyCount] = []
	var line: Node = view._deck_page.find_child("Tags", true, false)
	for child: Node in line.get_children():
		if child is FamilyCount:
			chips.append(child as FamilyCount)
	return chips


## The Cart's card of `id`, or null.
static func _cell_of(view: DeckView, id: StringName) -> DeckCell:
	for cell: DeckCell in view.cells():
		if cell.card.id == id:
			return cell
	return null


## Every card of `cells` inside `area`, no two overlapping (their tabs included).
func _assert_cards_laid_out(cells: Array[DeckCell], area: Rect2, where: String) -> void:
	for index: int in cells.size():
		var rect: Rect2 = cells[index].get_global_rect()
		var tabbed: Rect2 = rect.grow_side(SIDE_TOP, DeckCell.TOP_ROOM)
		(
			assert_bool(area.encloses(tabbed))
			. override_failure_message("%s %s" % [where, cells[index].card.id])
			. is_true()
		)
		for other: int in range(index + 1, cells.size()):
			var next: Rect2 = cells[other].get_global_rect().grow_side(SIDE_TOP, DeckCell.TOP_ROOM)
			assert_bool(tabbed.intersects(next)).override_failure_message(where).is_false()


## `cell`'s rule shows whole inside its rule box at one of RULE_SIZES (or cut short with "…" at the
## smallest), its lines centred.
func _assert_rule_fits(cell: DeckCell, message: String) -> void:
	var label: GlyphLabel = cell.rule_label()
	assert_bool(label.fits()).override_failure_message(message).is_true()
	assert_int(cell.rule_size()).override_failure_message(message).is_greater_equal(
		DeckCell.RULE_SIZES[-1]
	)
	var box: Rect2 = cell.rule_rect().grow(0.5)
	var shown: Rect2 = Rect2(label.position, label.size)
	assert_bool(box.encloses(shown)).override_failure_message(message).is_true()
	if cell.rule_clipped():
		assert_str(cell.shown_rule()).override_failure_message(message).ends_with(DeckCell.ELLIPSIS)
		assert_int(cell.rule_size()).is_equal(DeckCell.RULE_SIZES[-1])


## A START chip and a copies' count on `cell` sit apart: the chip inside the card clear of the
## rule text, the count over the card's top right corner.
func _assert_start_and_count(cell: DeckCell) -> void:
	var card: Rect2 = cell.get_global_rect()
	var id: String = String(cell.card.id)
	var rule: Rect2 = cell.rule_label().get_global_rect()
	for mark: RevealChip in cell.marks():
		var chip: Rect2 = mark.get_global_rect()
		assert_bool(card.encloses(chip)).override_failure_message(id).is_true()
		assert_bool(chip.intersects(rule)).override_failure_message(id).is_false()
		var count: Control = cell.count_label()
		if count != null:
			(
				assert_bool(chip.intersects(count.get_global_rect()))
				. override_failure_message(id)
				. is_false()
			)
	var count_label: Control = cell.count_label()
	if count_label != null:
		var count_rect: Rect2 = count_label.get_global_rect()
		assert_bool(count_rect.intersects(card)).override_failure_message(id).is_true()
		assert_float(count_rect.get_center().x).override_failure_message(id).is_greater(
			card.get_center().x
		)
		assert_bool(count_rect.intersects(rule)).override_failure_message(id).is_false()


## The Run info's hero (the run family's card, the aisle plates, the family tiles side by side)
## sits whole in `area` unscrolled; the card is as tall as its words.
func _assert_hero_fits(view: DeckView, area: Rect2, where: String) -> void:
	var hero: Control = view._info_page.find_child("RunInfoHero", false, false)
	assert_bool(area.encloses(hero.get_global_rect())).override_failure_message(where).is_true()
	for part: String in [RunInfoHero.PACK_CARD, RunInfoHero.PLATES, RunInfoHero.TILES]:
		var node: Control = hero.find_child(part, true, false)
		(
			assert_bool(area.encloses(node.get_global_rect()))
			. override_failure_message("%s %s" % [where, part])
			. is_true()
		)
	var card: Control = hero.find_child(RunInfoHero.PACK_CARD, true, false)
	assert_float(card.size.y).override_failure_message(where).is_equal(
		card.get_combined_minimum_size().y
	)
	var tiles: Array[Node] = hero.find_child(RunInfoHero.TILES, true, false).get_children()
	for index: int in range(1, tiles.size()):
		var left: Rect2 = (tiles[index - 1] as Control).get_global_rect()
		assert_bool(left.intersects((tiles[index] as Control).get_global_rect())).is_false()


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
