extends GdUnitTestSuite
## The opening board's page 1 "Counter" (full build plan 7.2, v1.07) on the real screen: the
## baskets dealt face up as it opens, what unlocks with completed aisles, RESTOCK by click and by
## keys 1–3, a regular's swap shelf and its undo, a starter basket's aisle change, saves, resume,
## motion, and page 1's layout at 1280x720 and 1920x1080.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103

var _folder: String


func before_test() -> void:
	_folder = "user://start_board_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## A new player sees six basket items dealt face up, four regulars and NEXT: no RESTOCK, no swap
## badges or SWAPS pips, no aisle tabs, no NEW tag; R and 1–4 do nothing. Enter opens page 2
## (BUILD), Enter clocks in.
func test_new_player_sees_six_items_four_regulars_and_next() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var run: RunState = screen.run
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.REVEALED)
	assert_int(run.start_offer.shared.size()).is_equal(6)
	assert_int(board.page).is_equal(1)
	assert_int(store.bays.size()).is_equal(3)
	for index: int in store.bays.size():
		assert_int(store.items[index].size()).is_equal(2)
		assert_object(store.signs[index].get_node_or_null("SwapTab")).is_null()
	assert_int(store.regulars.size()).is_equal(4)
	for holder: Control in store.regulars:
		assert_object(holder.get_node_or_null("Badge")).is_null()
		assert_object(holder.get_node_or_null("Undo")).is_null()
	assert_object(store.restock_key).is_null()
	assert_object(store.swap_chip).is_null()
	assert_object(store.extra).is_not_null()
	assert_array(store.fresh).is_empty()
	assert_int(store.find_children("New", "", true, false).size()).is_equal(0)
	assert_str(StartBoardKit.key_caption(board._next).text).is_equal("NEXT  ›")
	assert_bool((board._rail.get_node("Tab2") as Button).disabled).is_false()
	board._input(_key(KEY_R))
	assert_bool(store.restock_picking).is_false()
	board._input(_key(KEY_1))
	assert_object(board.popover).is_null()
	assert_str(board._save_hint.text).is_empty()
	board._input(_key(KEY_ENTER))
	assert_int(board.page).is_equal(2)
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	var expected: StarterPackDefinition = run.start_offer.first_pick
	board._input(_key(KEY_ENTER))
	for frame: int in 3:
		await get_tree().process_frame
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_object(run.starter.starter_pack).is_same(expected)
	assert_str(_save()["phase"]).is_equal("planning")


## The deal draws on the named streams only (the same seed deals the same baskets), each basket
## two distinct cards of its own source, shown on its sign and in its bay.
func test_each_basket_deals_two_from_its_source_on_named_streams() -> void:
	var screen: ShiftScreen = await _screen(3)
	var run: RunState = screen.run
	for index: int in run.start_setup.baskets.size():
		var basket: StartBasket = run.start_setup.baskets[index]
		assert_int(basket.cards.size()).is_equal(run.balance.start_basket_size)
		assert_bool(basket.cards[0] != basket.cards[1]).is_true()
		for card: CardDefinition in basket.cards:
			if basket.source == StartSetup.STAPLES:
				assert_bool(run.balance.staples.has(card)).is_true()
			else:
				assert_str(String(run.balance.aisle_of(card).id)).is_equal(String(basket.source))
		for at: int in basket.cards.size():
			var host: Control = screen._cart_reveal.board.store.items[index][at]
			assert_object(host.get_meta("card")).is_same(basket.cards[at])
	var state: int = run.rng_state
	var cards: Array[CardDefinition] = run.start_offer.shared.duplicate()
	screen.start_new_run(SEED, true, true)
	assert_array(screen.run.start_offer.shared).is_equal(cards)
	assert_int(screen.run.rng_state).is_equal(state)


## Quitting on page 1 resumes the same dealt baskets; quitting on page 2 (BUILD) resumes on
## page 2 with the same pick; going back to page 1 shows the same baskets.
func test_resume_follows_the_stage_and_page_one_keeps_the_setup() -> void:
	var screen: ShiftScreen = await _screen(3)
	var shared: Array[CardDefinition] = screen.run.start_offer.shared.duplicate()
	var waiting: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(waiting)
	await get_tree().process_frame
	assert_int(waiting.run.start_setup.stage).is_equal(StartSetup.Stage.REVEALED)
	assert_array(waiting.run.start_offer.shared).is_equal(shared)
	assert_int(waiting._cart_reveal.board.page).is_equal(1)
	waiting.queue_free()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	board.pick(0)
	board.back()
	assert_int(board.page).is_equal(1)
	assert_array(screen.run.start_offer.shared).is_equal(shared)
	board.show_page(2)
	assert_int(board.selected).is_equal(0)
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	assert_int(resumed._cart_reveal.board.page).is_equal(2)
	assert_int(resumed._cart_reveal.board.selected).is_equal(0)
	assert_array(resumed.run.start_offer.shared).is_equal(shared)


## A waiting run saved mid-setup in the first build's form (no stage) sets its setup up again
## from its seed on resume, dealt at once: the same aisles and baskets, saved in the new form, no
## error printed.
func test_an_old_format_setup_restarts_on_resume() -> void:
	var screen: ShiftScreen = await _screen(3)
	var stock: Array[StringName] = screen.run.start_setup.stock_aisles.duplicate()
	var shared: Array[CardDefinition] = screen.run.start_offer.shared.duplicate()
	var data: Dictionary = _save()
	(data["start_setup"] as Dictionary).erase("stage")
	var file: FileAccess = FileAccess.open(
		_folder.path_join(SaveService.RUN_FILE), FileAccess.WRITE
	)
	file.store_string(JSON.stringify(data))
	file.close()
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	assert_bool(resumed.run.restart_setup).is_false()
	assert_int(resumed.run.start_setup.stage).is_equal(StartSetup.Stage.REVEALED)
	assert_array(resumed.run.start_setup.stock_aisles).is_equal(stock)
	assert_array(resumed.run.start_offer.shared).is_equal(shared)
	assert_object(resumed._cart_reveal.board).is_not_null()
	assert_str(_save()["start_setup"]["stage"]).is_equal("revealed")


func test_hover_previews_without_changing_the_saved_pick_or_rng() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	var old_pick: StringName = screen.run.start_setup.picked
	var state: int = screen.run.rng_state
	var other: int = (board.selected + 1) % screen.run.start_offer.packs.size()
	board._preview(other)
	var shown: Array[CardDefinition] = board.staff.order.shown_cards
	assert_array(shown.slice(4, 7)).is_equal(screen.run.start_offer.packs[other].cards)
	assert_str(String(screen.run.start_setup.picked)).is_equal(String(old_pick))
	assert_int(screen.run.rng_state).is_equal(state)


## RESTOCK by keys (3 completed aisles): R makes the baskets wait as the shift's redraw mode does
## (each wears the redraw's teal RESTOCK tag; no frame, cue, bob or dimming), 2 redraws basket 2
## only, from the same source; the other baskets and the packs stay;
## the basket wears RESTOCKED, the key turns grey RESTOCK USED and R does nothing more; its NEW
## tag goes; saved and logged.
func test_restock_by_keys_redraws_one_basket_once() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var run: RunState = screen.run
	var dealt: Array[Array] = []
	for basket: StartBasket in run.start_setup.baskets:
		dealt.append(basket.cards.duplicate())
	var packs: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	var state: int = run.rng_state
	assert_bool(store.fresh.has(StorePage.NEW_RESTOCK)).is_true()
	assert_object(store.restock_key.get_node_or_null("New")).is_not_null()
	board._input(_key(KEY_R))
	assert_bool(store.restock_picking).is_true()
	for index: int in store.bays.size():
		var bob: Control = store.bays[index].get_node("Bob")
		var tag: RedrawTag = store.restock_tag(index)
		assert_object(tag).is_not_null()
		assert_str(tag.text()).is_equal("RESTOCK")
		assert_bool(tag.is_hot()).is_false()
		assert_object(bob.get_node_or_null("Hit/Frame")).is_null()
		assert_object(bob.get_node_or_null("Hit/Cue")).is_null()
		assert_float(bob.position.y).is_equal(0.0)
	assert_object(store.extra.modulate).is_equal(Color.WHITE)
	assert_object((store.get_node("Regulars") as Control).modulate).is_equal(Color.WHITE)
	assert_str(StartBoardKit.key_caption(store.restock_key).text).is_equal("PICK  A  BASKET")
	assert_object(store.restock_key.get_node_or_null("Cross")).is_not_null()
	var key_rect: Rect2 = store.restock_key.get_global_rect()
	var esc: Label = store.restock_key.get_node("Line")
	var esc_width: float = (
		(
			esc
			. get_theme_font("font")
			. get_string_size(
				esc.text, HORIZONTAL_ALIGNMENT_LEFT, -1, esc.get_theme_font_size("font_size")
			)
			. x
		)
		* esc.get_global_transform().get_scale().x
	)
	assert_float(esc.global_position.x + esc_width).is_less_equal(key_rect.end.x - 4)
	board._input(_key(KEY_2))
	assert_bool(store.restock_picking).is_false()
	assert_int(run.start_setup.restock_basket).is_equal(1)
	assert_array(run.start_setup.baskets[0].cards).is_equal(dealt[0])
	assert_array(run.start_setup.baskets[2].cards).is_equal(dealt[2])
	for card: CardDefinition in run.start_setup.baskets[1].cards:
		assert_bool(dealt[1].has(card)).is_false()
		assert_str(String(run.balance.aisle_of(card).id)).is_equal(
			String(run.start_setup.baskets[1].source)
		)
	assert_array(run.start_offer.packs).is_equal(packs)
	assert_int(run.rng_state).is_equal(state)
	assert_object(store.bays[1].get_node_or_null("Bob/Stamp")).is_not_null()
	assert_object(store.bays[0].get_node_or_null("Bob/Stamp")).is_null()
	assert_bool(store.restock_key.disabled).is_true()
	for index: int in store.bays.size():
		assert_object(store.restock_tag(index)).is_null()
	assert_str(StartBoardKit.key_caption(store.restock_key).text).is_equal("RESTOCK  USED")
	assert_object(store.restock_key.get_node_or_null("New")).is_null()
	assert_bool(screen.profile.seen.has(StorePage.NEW_RESTOCK)).is_true()
	board._input(_key(KEY_R))
	assert_bool(store.restock_picking).is_false()
	assert_bool(board.restock(0)).is_false()
	assert_int(int(_last_event("restock")["basket"])).is_equal(1)
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(run.balance))
	assert_int(saved.run.start_setup.restock_basket).is_equal(1)


## RESTOCK by mouse: the key, then a click on basket 3; pressing the key again while waiting
## cancels, as Esc does, with nothing spent.
func test_restock_by_click() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var dealt: Array[CardDefinition] = screen.run.start_setup.baskets[2].cards.duplicate()
	store.restock_key.pressed.emit()
	assert_bool(store.restock_picking).is_true()
	board.store.restock_key.pressed.emit()
	assert_bool(store.restock_picking).is_false()
	assert_int(screen.run.start_setup.restock_basket).is_equal(-1)
	store.restock_key.pressed.emit()
	var hit: Control = store.hits[2]
	assert_int(hit.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_int(hit.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	# Hovered, the tag goes hot and names the items going, as the redraw's does.
	hit.mouse_entered.emit()
	assert_bool(store.restock_tag(2).is_hot()).is_true()
	assert_str(store.restock_tag(2).text()).is_equal("RESTOCK 2")
	assert_bool(store.restock_tag(2).ring).is_false()
	hit.mouse_exited.emit()
	assert_str(store.restock_tag(2).text()).is_equal("RESTOCK")
	hit.gui_input.emit(_click(true))
	assert_int(screen.run.start_setup.restock_basket).is_equal(2)
	assert_array(screen.run.start_setup.baskets[2].cards).is_not_equal(dealt)
	assert_bool(store.restock_picking).is_false()


## Below 3 completed aisles there's no RESTOCK, below 6 no aisle tab; from 6 only the two
## starter signs carry one (never Staples, never today's extra aisle).
func test_controls_unlock_with_completed_aisles() -> void:
	for completed: int in [2, 3, 5, 6]:
		var screen: ShiftScreen = await _screen(completed)
		var store: StorePage = screen._cart_reveal.board.store
		assert_bool(store.restock_key != null).is_equal(completed >= 3)
		assert_object(store.swap_chip).is_not_null()
		assert_int(store.swap_chip.find_children("Pip*", "", false, false).size()).is_equal(
			mini(completed, 4)
		)
		for index: int in store.signs.size():
			var tab: bool = store.signs[index].get_node_or_null("SwapTab") != null
			assert_bool(tab).is_equal(completed >= 6 and index > 0)
		assert_object(store.extra.get_node("Sign").get_node_or_null("SwapTab")).is_null()
		assert_bool(screen._cart_reveal.board.open_aisles(1)).is_equal(completed >= 6)
		screen.queue_free()


## A regular's swap shelf by click (3 completed aisles): one tab per completed aisle, up to 4
## items; a click swaps at once (no confirm), the tile flips, a pip is spent, the put-back tag
## shows and the swap is saved and logged; the tag undoes it.
func test_a_regular_is_swapped_by_click_and_undone() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var run: RunState = screen.run
	var shared: Array[CardDefinition] = run.start_offer.shared.duplicate()
	var original: CardDefinition = run.starter.core_cards[0]
	store.regular_clicked.emit(0)
	var shelf: StorePopover = board.popover
	assert_object(shelf).is_not_null()
	assert_int(store.open_slot).is_equal(0)
	assert_int(shelf.tabs.size()).is_equal(3)
	assert_int(shelf.offers.size()).is_between(1, 4)
	var at: int = _open_offer(board)
	var card: CardDefinition = shelf.offer_cards[at]
	shelf.offers[at].pressed.emit()
	assert_object(board.popover).is_null()
	assert_object(run.starter.core_cards[0]).is_same(card)
	assert_array(run.start_offer.shared).is_equal(shared)
	_assert_undo_in_badge_place(store, 0)
	var pip: Panel = store.swap_chip.get_node("Pip0")
	var style: StyleBoxFlat = pip.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(style.bg_color).is_equal(Palette.TEAL_DARK)
	assert_bool(screen.profile.seen.has(StorePage.NEW_SWAP)).is_true()
	var event: Dictionary = _last_event("staple_swap")
	assert_str(event["via"]).is_equal("click")
	assert_str(event["card"]).is_equal(String(card.id))
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(run.balance))
	assert_object(saved.run.starter.core_cards[0]).is_same(card)
	# The swap is the run's own (v1.08): the profile never keeps it for the next run.
	assert_bool(screen._saves.load_profile().to_dictionary().has("staple_swaps")).is_false()
	# Reopening shows the same offer (kept per slot and aisle) and a BACK TO key.
	var aisle: StringName = run.balance.aisle_of(card).id
	var offer: Array[CardDefinition] = run.start_setup.regular_offer(0, aisle)
	assert_bool(board.open_swap(0)).is_true()
	assert_str(String(board.popover.aisle)).is_equal(String(aisle))
	assert_array(board.popover.offer_cards).is_equal(offer)
	assert_object(board.popover.restore_key).is_not_null()
	board.back()
	(store.regulars[0].get_node("Undo") as Button).pressed.emit()
	assert_object(run.starter.core_cards[0]).is_same(original)
	assert_object(store.regulars[0].get_node_or_null("Undo")).is_null()
	assert_bool(_last_event("staple_swap")["restored"]).is_true()
	assert_array(run.start_offer.shared).is_equal(shared)


## A swapped regular's put-back tag stands in its swap badge's place: its top-right corner on the
## badge's, right of the art's centre and above it, no badge beside it, inside the regular's lane,
## and it rises with the art on hover.
func _assert_undo_in_badge_place(store: StorePage, slot: int) -> void:
	var holder: Control = store.regulars[slot]
	var undo: Control = holder.get_node_or_null("Undo") as Control
	assert_object(undo).is_not_null()
	assert_object(holder.get_node_or_null("Badge")).is_null()
	var tile: StartItemTile = holder.get_node("Tile") as StartItemTile
	var badge: Vector2 = StorePage._badge_at(tile)
	assert_vector(undo.position + Vector2(undo.size.x, 0)).is_equal(
		badge + Vector2(StorePage.BADGE, 0)
	)
	var art: Rect2 = tile.art_bounds()
	assert_float(undo.position.x + undo.size.x / 2).is_greater(art.get_center().x)
	assert_float(undo.position.y + undo.size.y / 2).is_less(art.get_center().y)
	assert_float(undo.position.x + undo.size.x).is_less_equal(
		StartItemTile.SIZE.x + StorePage.BADGE_REACH
	)
	var rest: Vector2 = undo.position
	store._tile_hover(slot, true)
	assert_vector(undo.position).is_equal(rest - Vector2(0, 6))
	store._tile_hover(slot, false)
	assert_vector(undo.position).is_equal(rest)


## Keys: 2 opens regular 2's shelf, a number picks its item, Esc closes; while the shelf is open
## the page's own keys wait.
func test_keys_open_the_shelf_and_pick_an_item() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	board._input(_key(KEY_2))
	assert_object(board.popover).is_not_null()
	assert_int(board.store.open_slot).is_equal(1)
	board._input(_key(KEY_R))
	assert_bool(board.store.restock_picking).is_false()
	board._input(_key(KEY_ENTER))
	assert_int(board.page).is_equal(1)
	var at: int = _open_offer(board)
	var card: CardDefinition = board.popover.offer_cards[at]
	board._input(_key(StartBoard.NUMBER_KEYS[at]))
	assert_object(board.popover).is_null()
	assert_object(screen.run.starter.core_cards[1]).is_same(card)
	assert_str(_last_event("staple_swap")["via"]).is_equal("key")


## The aisle choice (6 completed aisles): a starter sign's tab lists the other completed aisles
## (never today's); a click deals the basket again from the chosen aisle, saved for the next run
## and logged; switching back deals the first pair again.
func test_a_starter_basket_changes_aisle_and_back() -> void:
	var screen: ShiftScreen = await _screen(6)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var run: RunState = screen.run
	var first: StringName = run.start_setup.baskets[2].source
	var first_pair: Array[CardDefinition] = run.start_setup.baskets[2].cards.duplicate()
	var packs: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	assert_object(store.signs[2].get_node_or_null("New")).is_not_null()
	store.sign_clicked.emit(2)
	var choice: StorePopover = board.popover
	assert_object(choice).is_not_null()
	assert_int(store.open_basket).is_equal(2)
	assert_int(choice.options.size()).is_equal(run.balance.aisles.size() - 3)
	for taken: StringName in run.start_setup.stock_aisles:
		assert_bool(choice.options.has(taken)).is_false()
	var other: StringName = choice.options.keys()[0]
	choice.options[other].pressed.emit()
	assert_object(board.popover).is_null()
	assert_str(String(run.start_setup.baskets[2].source)).is_equal(String(other))
	for card: CardDefinition in run.start_setup.baskets[2].cards:
		assert_str(String(run.balance.aisle_of(card).id)).is_equal(String(other))
	assert_array(run.start_offer.packs).is_equal(packs)
	assert_bool(screen.profile.stock_pair.has(other)).is_true()
	assert_bool(screen._saves.load_profile().stock_pair.has(other)).is_true()
	assert_bool(screen.profile.seen.has(StorePage.NEW_AISLE)).is_true()
	var event: Dictionary = _last_event("start_aisle")
	assert_str(event["from"]).is_equal(String(first))
	assert_str(event["to"]).is_equal(String(other))
	assert_bool(event["kept"]).is_false()
	assert_bool(board.open_aisles(2)).is_true()
	board.change_aisle(first)
	assert_array(run.start_setup.baskets[2].cards).is_equal(first_pair)
	assert_bool(_last_event("start_aisle")["kept"]).is_true()
	assert_bool(board.open_aisles(0)).is_false()


func test_a_failed_run_save_rolls_back_the_swap_and_profile() -> void:
	var screen: ShiftScreen = await _screen(3)
	var errors: Array[String] = []
	screen._saves = SaveService.new(_folder, func(message: String) -> void: errors.append(message))
	var original: CardDefinition = screen.run.starter.core_cards[0]
	var saved_before: Dictionary = _save()
	var blocked: String = screen._saves.run_path() + SaveService.TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocked)
	var card: CardDefinition = _swap_card(screen, 0)
	assert_bool(screen._start_choice.swap_staple(0, card)).is_false()
	DirAccess.remove_absolute(blocked)
	assert_object(screen.run.starter.core_cards[0]).is_same(original)
	assert_dict(_save()).is_equal(saved_before)
	assert_int(errors.size()).is_equal(1)


func test_pin_changes_update_the_waiting_run_without_redealing() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	board.open_pins()
	assert_float(board._pins.sheet().get_global_rect().end.x).is_less_equal(
		board.staff.order.get_global_rect().position.x
	)
	var shared: Array[CardDefinition] = screen.run.start_offer.shared.duplicate()
	var state: int = screen.run.rng_state
	var pin: PinDefinition = screen._catalogue.pins.back()
	assert_bool(board._pins.toggle(pin)).is_true()
	assert_array(screen.run.pins).is_equal([pin])
	assert_array(screen.run.start_offer.shared).is_equal(shared)
	assert_int(screen.run.rng_state).is_equal(state)
	board.back()
	assert_int(board.page).is_equal(2)


## Motion (reduced motion off): the page drops in; a RESTOCK hops the old pair out and drops the
## new one in; skipping settles every item, regular and bay at rest. Reduced motion never starts
## it.
func test_the_motion_settles_and_respects_reduced_motion() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	screen.profile.set_reduced_motion(false)
	board.refresh()
	store.play_intro()
	assert_bool(store.is_dealing()).is_true()
	store.skip_deal()
	assert_bool(store.is_dealing()).is_false()
	assert_bool(board.restock(1)).is_true()
	assert_bool(store.is_dealing()).is_true()
	assert_object(store.bays[1].get_node_or_null("Bob/Ghost0")).is_not_null()
	store.skip_deal()
	assert_bool(store.is_dealing()).is_false()
	for index: int in store.bays.size():
		assert_vector(store.bays[index].position).is_equal(
			Vector2(StorePage.BAY_LEFT + index * StorePage.BAY_STEP, 0)
		)
		for host: Control in store.items[index]:
			assert_float(host.position.y).is_equal(StorePage.ITEM_TOP)
			assert_float(host.modulate.a).is_equal(1.0)
	for slot: int in store.regulars.size():
		assert_vector(store.regulars[slot].position).is_equal(store.tile_rect(slot).position)
	screen.profile.set_reduced_motion(true)
	board.refresh()
	store.play_intro()
	store.play_flip(0)
	assert_bool(store.is_dealing()).is_false()


## Page 1 at 1280x720 and 1920x1080, at 0, 3 and 6 completed aisles, at rest, waiting for a
## RESTOCK pick, with a swap shelf open and (at 6) an aisle choice open: everything on the stage;
## the bays, signs and extra aisle apart under the rail; each basket's items inside its bay; the
## RESTOCK key clear of the signs; the regulars apart under their heading and SWAPS chip; the
## pop-ups clear of what they point at; the footer apart.
func test_store_page_layout_has_no_clipping_or_overlap() -> void:
	for completed: int in [0, 3, 6]:
		var screen: ShiftScreen = await _screen(completed)
		var board: StartBoard = screen._cart_reveal.board
		for state: String in ["rest", "pick", "swap", "aisle", "swapped"]:
			for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
				board.set_anchors_preset(Control.PRESET_TOP_LEFT)
				board.size = extent
				board._resize()
				board.back()
				var shown: bool = true
				match state:
					"pick":
						shown = board.start_restock()
					"swap":
						shown = board.open_swap(0)
					"aisle":
						shown = board.open_aisles(1)
					"swapped":
						shown = _swapped(screen, board, 2)
				assert_bool(shown).is_equal(state == "rest" or _expect_state(completed, state))
				_assert_store_layout(board)
				if board.store.restock_picking:
					board.cancel_restock()
		screen.queue_free()


static func _expect_state(completed: int, state: String) -> bool:
	match state:
		"pick":
			return completed >= 3
		"swap":
			return completed >= 1
		"aisle":
			return completed >= 6
		"swapped":
			return completed >= 1
	return true


## Regular `slot` swapped (once; later sizes keep it), its put-back tag showing.
func _swapped(screen: ShiftScreen, board: StartBoard, slot: int) -> bool:
	if screen.run.starter.core_cards[slot] != screen.run.start_setup.originals[slot]:
		return true
	var card: CardDefinition = _swap_card(screen, slot)
	if card == null or not board.open_swap(slot):
		return false
	return board.swap_to(card) and board.store.regulars[slot].has_node("Undo")


func _assert_store_layout(board: StartBoard) -> void:
	var stage: Rect2 = _stage_rect(board)
	var store: StorePage = board.store
	var factor: float = board._stage.scale.x
	var rail: Rect2 = (store.get_node("Rail") as Control).get_global_rect()
	assert_bool(stage.encloses(rail)).is_true()
	var columns: Array[Rect2] = []
	for index: int in store.bays.size():
		var bay: Rect2 = store.bays[index].get_global_rect()
		var sign_rect: Rect2 = store.signs[index].get_global_rect()
		assert_bool(stage.encloses(bay)).is_true()
		assert_bool(bay.encloses(sign_rect)).is_true()
		assert_float(sign_rect.position.y).is_greater_equal(rail.end.y)
		var area: Rect2 = _to_global(board, store.basket_rect(index))
		for host: Control in store.items[index]:
			assert_bool(area.grow(0.5).encloses(host.get_global_rect())).is_true()
		for other: Rect2 in columns:
			assert_bool(bay.intersects(other)).is_false()
		columns.append(bay)
	if store.extra != null:
		var extra_sign: Rect2 = (store.extra.get_node("Sign") as Control).get_global_rect()
		var extra_line: Rect2 = (store.extra.get_node("Line") as Control).get_global_rect()
		for rect: Rect2 in [extra_sign, extra_line]:
			assert_bool(stage.encloses(rect)).is_true()
			for bay: Rect2 in columns:
				assert_bool(rect.intersects(bay)).is_false()
	var regulars_top: float = _text_rect(store.get_node("Regulars/Heading")).position.y
	for index: int in store.bays.size():
		var tag: RedrawTag = store.restock_tag(index)
		if tag != null:
			# On its basket's front, clear of its price tags, above the regulars.
			var tag_rect: Rect2 = tag.get_global_rect()
			var front: Rect2 = (
				(store.bays[index].get_node("Bob/Front") as Control).get_global_rect()
			)
			assert_bool(stage.encloses(tag_rect)).is_true()
			assert_bool(front.grow(1).encloses(tag_rect)).is_true()
			assert_float(tag_rect.end.y).is_less_equal(regulars_top)
			for at: int in store.items[index].size():
				var price: Control = store.bays[index].get_node("Bob/Price%d" % at)
				assert_bool(tag_rect.intersects(price.get_global_rect())).is_false()
	if store.restock_key != null:
		var key: Rect2 = store.restock_key.get_global_rect()
		assert_bool(stage.encloses(key)).is_true()
		assert_bool(key.intersects(rail)).is_false()
		for sign_panel: Panel in store.signs:
			assert_bool(key.intersects(sign_panel.get_global_rect())).is_false()
		(
			assert_bool(
				key.intersects((store.get_node("BasketsHeading") as Control).get_global_rect())
			)
			. is_false()
		)
	var shelf: Control = store.get_node("Regulars")
	var heading: Rect2 = _text_rect(shelf.get_node("Heading"))
	var labels: Array[Rect2] = [heading, (shelf.get_node("Subtitle") as Control).get_global_rect()]
	if store.swap_chip != null:
		labels.append(store.swap_chip.get_global_rect())
	for index: int in labels.size():
		assert_bool(stage.encloses(labels[index])).is_true()
		for other: int in range(index + 1, labels.size()):
			assert_bool(labels[index].intersects(labels[other])).is_false()
	var tiles: Array[Rect2] = []
	for holder: Control in store.regulars:
		var rect: Rect2 = holder.get_global_rect()
		assert_bool(stage.encloses(rect)).is_true()
		for bay: Rect2 in columns:
			assert_float(rect.position.y).is_greater_equal(bay.end.y - 8 * factor)
		for label: Rect2 in labels:
			assert_bool(rect.intersects(label)).is_false()
		for other: Rect2 in tiles:
			assert_bool(rect.intersects(other)).is_false()
		tiles.append(rect)
	_assert_tile_tags(store)
	_assert_new_tags(board, stage)
	if board.popover != null:
		var pop: Rect2 = board.popover.get_global_rect()
		assert_bool(stage.encloses(pop)).is_true()
		if store.open_slot >= 0:
			assert_bool(pop.intersects(tiles[store.open_slot])).is_false()
		if store.open_basket >= 0:
			assert_bool(pop.intersects(store.signs[store.open_basket].get_global_rect())).is_false()
		for child: Node in board.popover.get_children():
			var control: Control = child as Control
			if control != null and control.visible and control.name != "Title":
				(
					assert_bool(pop.grow(0.5).encloses(control.get_global_rect()))
					. override_failure_message(control.name)
					. is_true()
				)
	_assert_chrome(board, stage)
	var footer: Rect2 = board._next.get_global_rect()
	for label: Label in [board._save_hint, board._note]:
		if label.visible and label.text != "":
			assert_bool(stage.encloses(label.get_global_rect())).is_true()
			assert_bool(label.get_global_rect().intersects(footer)).is_false()
	var line: Label = board._next_line
	var font: Font = line.get_theme_font("font")
	var needed: float = (
		font
		. get_string_size(
			line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line.get_theme_font_size("font_size")
		)
		. x
	)
	assert_float(needed).is_less_equal(line.size.x)


## The shelves (v1.08), at 1280x720 and 1920x1080: the baskets stand on one wooden plank whose top
## meets their feet, reaching past the outer baskets and ending before today's extra aisle; RUN-ONLY
## sits under the extra aisle's sign, "Available as machine prizes." under its capsules. Each
## regular's art stands on its shelf with no card backing, its one sticker (glyphs and price) on
## the shelf's edge under it and clear of its swap badge; a hover lifts the art but not the
## sticker, and the tile (art and sticker) carries the card for its popup.
func test_shelves_stickers_and_run_only_caption() -> void:
	var screen: ShiftScreen = await _screen(1)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board.size = extent
		board._resize()
		var factor: float = board._stage.scale.x
		var shelf: Rect2 = (store.get_node("BasketShelf") as Control).get_global_rect()
		for bay: Control in store.bays:
			var front: Rect2 = (bay.get_node("Bob/Front") as Control).get_global_rect()
			assert_float(absf(shelf.position.y - front.end.y)).is_less_equal(2 * factor)
			assert_float(shelf.position.x).is_less(front.position.x)
			assert_float(shelf.end.x).is_greater(front.end.x)
		var extra_sign: Rect2 = (store.extra.get_node("Sign") as Control).get_global_rect()
		assert_float(shelf.end.x).is_less(extra_sign.position.x)
		var caption: Rect2 = (store.extra.get_node("Caption") as Control).get_global_rect()
		var words: String = ""
		for part: Node in store.extra.get_node("Caption").get_children():
			words += (part as Label).text
		assert_str(words).is_equal("RUN-ONLY")
		assert_float(caption.position.y).is_greater_equal(extra_sign.end.y)
		assert_float(caption.position.y - extra_sign.end.y).is_less_equal(12 * factor)
		assert_float(absf(caption.get_center().x - extra_sign.get_center().x)).is_less(4 * factor)
		var line: Label = store.extra.get_node("Line") as Label
		assert_str(line.text).is_equal("Available as machine prizes.")
		assert_float(line.get_global_rect().position.y).is_greater(
			(store.extra.get_node("Capsule0") as Control).get_global_rect().end.y
		)
		var plank: Rect2 = (store.get_node("Regulars/Shelf") as Control).get_global_rect()
		for holder: Control in store.regulars:
			var tile: StartItemTile = holder.get_node("Tile") as StartItemTile
			assert_object(tile.get_meta("card")).is_same(
				screen.run.starter.core_cards[store.regulars.find(holder)]
			)
			for child: Node in tile.get_children():
				assert_bool(child == tile.art or child == tile.sticker).is_true()
			var art: Rect2 = tile.art.get_global_rect()
			assert_float(art.end.y).is_equal_approx(plank.position.y, 0.01)
			var sticker: Rect2 = tile.sticker.get_global_rect()
			assert_bool(sticker.intersects(plank)).is_true()
			assert_float(sticker.position.y).is_greater(plank.position.y)
			assert_bool(holder.get_global_rect().grow(0.5).encloses(sticker)).is_true()
			assert_bool(holder.get_global_rect().grow(0.5).encloses(art)).is_true()
			assert_str((tile.sticker.get_node("Price") as Label).text).contains("€")
			var badge: Control = holder.get_node("Badge") as Control
			assert_bool(badge.get_global_rect().intersects(sticker)).is_false()
			assert_float(badge.get_global_rect().get_center().x).is_greater(art.get_center().x)
			assert_float(badge.get_global_rect().get_center().y).is_less(art.get_center().y)
			# Clear of the art's opaque pixels (2 px), at its top-right, in its own lane.
			var spot: Rect2 = Rect2(badge.position, badge.size)
			var under: float = tile.art_top_over(spot.position.x - 2, spot.end.x + 2)
			assert_float(spot.end.y).is_less_equal(under - 2)
			assert_float(spot.position.x).is_greater(tile.art_bounds().get_center().x)
			assert_float(spot.end.y).is_less_equal(tile.art_bounds().position.y + StorePage.BADGE)
			var lane: float = holder.get_global_rect().end.x + StorePage.TILE_GAP * factor
			assert_float(badge.get_global_rect().end.x).is_less(lane)
	var first: StartItemTile = store.regulars[0].get_node("Tile") as StartItemTile
	var rest: float = first.sticker.position.y
	var art_rest: float = first.art.position.y
	var badge_rest: Vector2 = (store.regulars[0].get_node("Badge") as Control).position
	store._tile_hover(0, true)
	assert_float(first.art.position.y).is_equal(art_rest - 6)
	assert_vector((store.regulars[0].get_node("Badge") as Control).position).is_equal(
		badge_rest - Vector2(0, 6)
	)
	assert_float(first.sticker.position.y).is_equal(rest)
	assert_vector(store.regulars[0].position).is_equal(store.tile_rect(0).position)
	store._tile_hover(0, false)
	assert_float(first.art.position.y).is_equal(art_rest)


## The top bar's chips and the two tabs stay apart and on the stage on both pages; YOUR STORE
## shows its check only on page 2; page 2's keycap hints stay left of the order sheet and clock.
func test_top_bar_tabs_and_hints_stay_apart() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var stage: Rect2 = _stage_rect(board)
	assert_object(board._rail.get_node_or_null("Tab1/Done")).is_null()
	_assert_chrome(board, stage)
	board.show_page(2)
	_assert_chrome(board, stage)
	assert_object(board._rail.get_node_or_null("Tab1/Done")).is_not_null()
	var hints: Rect2 = (board.staff.get_node("Hints") as Control).get_global_rect()
	assert_bool(stage.encloses(hints)).is_true()
	assert_float(hints.end.x).is_less(board.staff.order.get_global_rect().position.x)
	assert_bool(hints.intersects(board._back.get_global_rect())).is_false()


func _assert_chrome(board: StartBoard, stage: Rect2) -> void:
	var chips: Array[Rect2] = []
	for chip: String in ["ShiftChip", "AisleChip", "CartChip"]:
		chips.append((board._bar.get_node(chip) as Control).get_global_rect())
		assert_bool(stage.encloses(chips.back())).is_true()
	for index: int in chips.size():
		for other: int in range(index + 1, chips.size()):
			assert_bool(chips[index].intersects(chips[other])).is_false()
	var first: Rect2 = (board._rail.get_node("Tab1") as Control).get_global_rect()
	var second: Rect2 = (board._rail.get_node("Tab2") as Control).get_global_rect()
	assert_bool(first.intersects(second)).is_false()
	assert_bool(stage.encloses(first) and stage.encloses(second)).is_true()
	if board._key_hint != null and board._key_hint.visible:
		var hints: Rect2 = board._key_hint.get_global_rect()
		assert_bool(stage.encloses(hints)).is_true()
		assert_bool(hints.intersects(board._next.get_global_rect())).is_false()


func _stage_rect(board: StartBoard) -> Rect2:
	return Rect2(board._stage.global_position, ShiftStage.SIZE * board._stage.scale)


func _to_global(board: StartBoard, rect: Rect2) -> Rect2:
	return Rect2(
		rect.position * board._stage.scale + board._stage.global_position,
		rect.size * board._stage.scale
	)


## A pixel label's visible words, in global px (its own width can be wider than its words).
func _text_rect(label: Label) -> Rect2:
	var factor: float = label.get_global_transform().get_scale().x
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var extent: Vector2 = Vector2(
		StartBoardKit.text_width(label.text, 1), ArtStyle.PIXEL_CAP_HEIGHT
	)
	return Rect2(label.global_position + Vector2(0, cap_top * factor), extent * factor)


static func _open_offer(board: StartBoard) -> int:
	for at: int in board.popover.offers.size():
		if not board.popover.offers[at].disabled:
			return at
	return 0


func _screen(completed: int = 0) -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
	for index: int in screen._balance.aisles.size():
		var aisle: AisleDefinition = screen._balance.aisles[index]
		var count: int = (
			aisle.capsule_cards.size()
			if index < completed
			else (
				mini(4, aisle.capsule_cards.size())
				if aisle.base_cards.is_empty() and completed > 0
				else 0
			)
		)
		for card: CardDefinition in aisle.capsule_cards.slice(0, count):
			screen.profile.unlocked_items[card.id] = 0
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	return screen


## A regular's put-back tag or swap badge never touches another regular's tile or tags.
func _assert_tile_tags(store: StorePage) -> void:
	for index: int in store.regulars.size():
		for tag_name: String in ["Undo", "Badge"]:
			var tag: Control = store.regulars[index].get_node_or_null(tag_name)
			if tag == null:
				continue
			var rect: Rect2 = tag.get_global_rect()
			for other: int in store.regulars.size():
				if other == index:
					continue
				var holder: Control = store.regulars[other]
				var parts: Array[Control] = [holder.get_node("Tile") as Control]
				for part_name: String in ["Undo", "Badge"]:
					if holder.has_node(part_name):
						parts.append(holder.get_node(part_name) as Control)
				for part: Control in parts:
					(
						assert_bool(rect.intersects(part.get_global_rect()))
						. override_failure_message(
							"%s %d hits regular %d" % [tag_name, index, other]
						)
						. is_false()
					)


## Every visible NEW tag stays on the stage and off the controls it isn't on: the restock pick's
## tags, the signs, the RESTOCK key, the SWAPS chip, the headings and the regulars.
func _assert_new_tags(board: StartBoard, stage: Rect2) -> void:
	var store: StorePage = board.store
	var others: Array[Control] = []
	for index: int in store.bays.size():
		if store.restock_tag(index) != null:
			others.append(store.restock_tag(index))
	for sign_panel: Panel in store.signs:
		others.append(sign_panel)
	for control: Control in [store.restock_key, store.swap_chip]:
		if control != null:
			others.append(control)
	others.append(store.get_node("BasketsHeading") as Control)
	others.append(store.get_node("Regulars/Heading") as Control)
	others.append(store.get_node("Regulars/Subtitle") as Control)
	others.append_array(store.regulars)
	var tags: Array[Node] = store.find_children("New", "Panel", true, false)
	for node: Node in tags:
		var tag: Control = node as Control
		if not tag.is_visible_in_tree():
			continue
		var rect: Rect2 = tag.get_global_rect()
		assert_bool(stage.encloses(rect)).override_failure_message(str(tag.get_path())).is_true()
		for other: Control in others:
			if other == tag.get_parent() or not other.is_visible_in_tree():
				continue
			(
				assert_bool(rect.intersects(other.get_global_rect()))
				. override_failure_message("%s hits %s" % [tag.get_path(), other.name])
				. is_false()
			)


func _swap_card(screen: ShiftScreen, slot: int) -> CardDefinition:
	for aisle: AisleDefinition in StartSetupRules.completed(screen.run.balance, screen.profile):
		for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			if StartSetupRules.can_swap(screen.run, screen.profile, slot, card):
				return card
	return null


func _save() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join(SaveService.RUN_FILE)))


## The last logged event of `type`.
func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


static func _click(pressed: bool) -> InputEventMouseButton:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	return button


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
