extends GdUnitTestSuite
## Start v4 B (full build plan 7.2, reworked 2026-11-05) on the real screen: LOCK IN & DEAL, the
## aisle board's statuses and choosing, the baskets and their RESTOCK, replacing a regular by
## drag, click and keys (strip, preview, PUT BACK), saves and resume, and page 1's layout.

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


## A new profile opens in SELECT: today's three aisles shown in their statuses, rows not
## clickable, the baskets covered, LOCK IN & DEAL in NEXT's place and page 2 locked. Enter locks
## in (2 per basket, uncovered), Enter opens page 2 (BUILD), Enter clocks in.
func test_new_profile_locks_in_then_enter_enter_clocks_in() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	var run: RunState = screen.run
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_array(run.start_offer.shared).is_empty()
	assert_int(board.page).is_equal(1)
	for view: StartBasketView in board.store.baskets:
		assert_bool(view.covered and view.cover.visible).is_true()
		assert_object(view.tag).is_null()
	var green: Array[StringName] = run.start_setup.green_ids(run.balance)
	assert_int(board.store.board.rows[green[0]].get_meta("status")).is_equal(
		AisleBoard.Status.GREEN
	)
	(
		assert_int(
			board.store.board.rows[run.start_setup.run_only_ids(run.balance)[0]].get_meta("status")
		)
		. is_equal(AisleBoard.Status.ORANGE)
	)
	assert_bool(board.store.cycle(green[0])).is_false()
	assert_str(board.store.board.note_body.text).contains("6 completed aisles (0/6)")
	assert_str(StartBoardKit.key_caption(board._next).text).is_equal("LOCK IN & DEAL ›")
	assert_bool((board._rail.get_node("Tab2") as Button).disabled).is_true()
	board.show_page(2)
	assert_int(board.page).is_equal(1)
	assert_bool(board.clock_in()).is_false()
	board._input(_key(KEY_ENTER))
	assert_int(run.start_setup.stage).is_equal(StartSetup.Stage.REVEALED)
	assert_int(run.start_offer.shared.size()).is_equal(6)
	for index: int in board.store.baskets.size():
		var view: StartBasketView = board.store.baskets[index]
		assert_bool(view.cover.visible).is_false()
		assert_int(view.tiles.size()).is_equal(2)
		assert_str(String(view.source)).is_equal(String(run.start_setup.baskets[index].source))
	assert_str(StartBoardKit.key_caption(board._next).text).is_equal("NEXT ›")
	assert_str(_last_event("start_lock_in")["green"][0]).is_equal(String(green[0]))
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


## LOCK IN draws on the named streams only: the run's RNG is untouched, and the same seed deals
## the same baskets. Each basket holds two distinct cards of its own source.
func test_each_basket_deals_two_from_its_source_on_named_streams() -> void:
	var screen: ShiftScreen = await _screen(3)
	var run: RunState = screen.run
	var state: int = run.rng_state
	assert_bool(screen._cart_reveal.board.lock_in()).is_true()
	assert_int(run.rng_state).is_equal(state)
	for basket: StartBasket in run.start_setup.baskets:
		assert_int(basket.cards.size()).is_equal(run.balance.start_basket_size)
		assert_bool(basket.cards[0] != basket.cards[1]).is_true()
		for card: CardDefinition in basket.cards:
			if basket.source == StartSetup.STAPLES:
				assert_bool(run.balance.staples.has(card)).is_true()
			else:
				assert_str(String(run.balance.aisle_of(card).id)).is_equal(String(basket.source))
	var cards: Array[CardDefinition] = run.start_offer.shared.duplicate()
	screen.start_new_run(SEED, true, true)
	assert_bool(screen._cart_reveal.board.lock_in()).is_true()
	assert_array(screen.run.start_offer.shared).is_equal(cards)


## Quitting in SELECT keeps the suggestion and nothing dealt; quitting on page 2 (BUILD) resumes
## on page 2 with the same pick; going back to page 1 shows the same baskets.
func test_resume_follows_the_stage_and_page_one_keeps_the_setup() -> void:
	var screen: ShiftScreen = await _screen(3)
	var stock: Array[StringName] = screen.run.start_setup.stock_aisles.duplicate()
	var waiting: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(waiting)
	await get_tree().process_frame
	assert_int(waiting.run.start_setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_array(waiting.run.start_setup.stock_aisles).is_equal(stock)
	assert_int(waiting._cart_reveal.board.page).is_equal(1)
	waiting.queue_free()
	var board: StartBoard = screen._cart_reveal.board
	board.lock_in()
	var shared: Array[CardDefinition] = screen.run.start_offer.shared.duplicate()
	board.show_page(2)
	board.pick(0)
	board.back()
	assert_int(board.page).is_equal(1)
	assert_array(screen.run.start_offer.shared).is_equal(shared)
	for index: int in board.store.baskets.size():
		var view: StartBasketView = board.store.baskets[index]
		assert_bool(view.cover.visible).is_false()
		assert_int(view.tiles.size()).is_equal(2)
	board.show_page(2)
	assert_int(board.selected).is_equal(0)
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	assert_int(resumed._cart_reveal.board.page).is_equal(2)
	assert_int(resumed._cart_reveal.board.selected).is_equal(0)
	assert_array(resumed.run.start_offer.shared).is_equal(shared)


## A waiting run saved mid-setup in the first build's form (no stage) sets its setup up again
## from its seed on resume: SELECT, the same suggestion, saved in the new form, no error printed.
func test_an_old_format_setup_restarts_on_resume() -> void:
	var screen: ShiftScreen = await _screen(3)
	var stock: Array[StringName] = screen.run.start_setup.stock_aisles.duplicate()
	# The first build dealt before the board opened: a dealt offer, a setup without its stage.
	screen._cart_reveal.board.lock_in()
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
	assert_int(resumed.run.start_setup.stage).is_equal(StartSetup.Stage.SELECT)
	assert_array(resumed.run.start_setup.stock_aisles).is_equal(stock)
	assert_object(resumed._cart_reveal.board).is_not_null()
	assert_str(_save()["start_setup"]["stage"]).is_equal("select")


func test_hover_previews_without_changing_the_saved_pick_or_rng() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.lock_in()
	board.show_page(2)
	var old_pick: StringName = screen.run.start_setup.picked
	var state: int = screen.run.rng_state
	var other: int = (board.selected + 1) % screen.run.start_offer.packs.size()
	board._preview(other)
	var shown: Array[CardDefinition] = board.staff.order.shown_cards
	assert_array(shown.slice(4, 7)).is_equal(screen.run.start_offer.packs[other].cards)
	assert_str(String(screen.run.start_setup.picked)).is_equal(String(old_pick))
	assert_int(screen.run.rng_state).is_equal(state)


## From 6 completed aisles a row click cycles its draft status (not today › STARTER CART › RUN
## ONLY), skipping a full one; LOCK IN waits for 2 + 1 and saves the choice for the next run.
func test_choosing_cycles_statuses_and_saves_the_choice() -> void:
	var screen: ShiftScreen = await _screen(6)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var balance: BalanceDefinition = screen.run.balance
	assert_bool(store.choosing()).is_true()
	var green: Array[StringName] = store.draft_green()
	var orange: Array[StringName] = store.draft_run_only()
	var spare: StringName = &""
	for aisle: AisleDefinition in balance.aisles:
		if not green.has(aisle.id) and not orange.has(aisle.id):
			spare = aisle.id
			break
	# Both statuses full: a spare aisle can't change, its tip says why.
	assert_bool(store.cycle(spare)).is_false()
	assert_str(store.board.rows[spare].tooltip_text).contains("is full")
	# A green aisle skips the full RUN ONLY and goes to not today.
	store.board.row_clicked.emit(green[0])
	assert_array(store.draft_green()).is_equal([green[1]])
	assert_bool(board._next.disabled).is_true()
	assert_str(board._next_line.text).is_equal("Pick 2 STARTER CART aisles and 1 RUN ONLY")
	assert_bool(board.lock_in()).is_false()
	store.board.set_focus(store.board.ids.find(spare))
	board._input(_key(KEY_SPACE))
	assert_bool(store.draft_green().has(spare)).is_true()
	assert_bool(board._next.disabled).is_false()
	board._input(_key(KEY_ENTER))
	var chosen: Array[StringName] = StartSetupRules.ordered_pair(balance, [green[1], spare])
	assert_array(screen.run.start_setup.green_ids(balance)).is_equal(chosen)
	assert_array(screen.profile.stock_pair).is_equal(chosen)
	var event: Dictionary = _last_event("start_lock_in")
	assert_bool(event["changed"]).is_true()
	assert_int(int(event["status_clicks"])).is_equal(2)
	# After LOCK IN the rows are locked.
	assert_bool(store.cycle(green[0])).is_false()
	screen.start_new_run(SEED + 1, true, true)
	assert_array(screen.run.start_setup.green_ids(balance)).is_equal(chosen)


## A drag onto an aisle row: eligible rows show DROP HERE (gold), the others are muted with their
## reason; the drop opens the strip, an item its preview, CONFIRM saves the swap (logged as a
## drag) without re-dealing. Click then click reaches the same strip; WAS puts it back.
func test_a_regular_is_replaced_by_drag_and_by_click() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	var run: RunState = screen.run
	board.lock_in()
	var shared: Array[CardDefinition] = run.start_offer.shared.duplicate()
	var original: CardDefinition = run.starter.core_cards[0]
	assert_bool(store.carry(0, "drag")).is_true()
	var target: StringName = &""
	for aisle: AisleDefinition in run.balance.aisles:
		var row: Panel = store.board.rows[aisle.id]
		var reason: StringName = StartSetupRules.target_block(run, screen.profile, 0, aisle.id)
		var pill: Label = row.get_node_or_null("Pill/Words")
		if reason == &"":
			target = aisle.id if target == &"" else target
			assert_str(pill.text).is_equal("DROP HERE")
			assert_object(row.modulate).is_equal(Color.WHITE)
		else:
			assert_object(row.modulate).is_equal(AisleBoard.MUTED)
			assert_str(row.tooltip_text).is_equal(StartReasons.target(run, reason))
	assert_str(String(target)).is_not_empty()
	assert_object(board.hovered_card()).is_null()
	store.drop_on(target, "drag")
	assert_bool(store.carrying()).is_false()
	assert_object(board.strip).is_not_null()
	var at: int = -1
	for index: int in board.strip.items.size():
		if at < 0 and not board.strip.items[index].disabled:
			at = index
	var card: CardDefinition = board.strip.offer[at]
	board._input(_key(StartBoard.NUMBER_KEYS[at]))
	assert_bool(board.strip.previewing).is_true()
	board._input(_key(KEY_ENTER))
	assert_object(board.strip).is_null()
	assert_object(run.starter.core_cards[0]).is_same(card)
	assert_array(run.start_offer.shared).is_equal(shared)
	var event: Dictionary = _last_event("staple_swap")
	assert_str(event["via"]).is_equal("drag")
	assert_str(event["aisle"]).is_equal(String(target))
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(run.balance))
	assert_object(saved.run.starter.core_cards[0]).is_same(card)
	# The offer is kept per slot and aisle: reopening shows the same items.
	var offer: Array[CardDefinition] = run.start_setup.regular_offer(0, target)
	assert_bool(store.carry(1, "click")).is_true()
	store.board.row_clicked.emit(target)
	assert_object(board._modal).is_not_null()
	board.back()
	assert_object(board._modal).is_null()
	board._dropped(0, target, "click")
	if not board.strip.previewing:
		assert_array(board.strip.offer).is_equal(offer)
	board.back()
	assert_int(board.page).is_equal(1)
	# WAS: the PUT BACK preview, then the original is back.
	var was: Button = store.regulars[0].get_node("Was")
	was.pressed.emit()
	assert_bool(board.strip.previewing).is_true()
	assert_bool(board.confirm_swap()).is_true()
	assert_object(run.starter.core_cards[0]).is_same(original)
	assert_array(run.start_offer.shared).is_equal(shared)


## The mouse: press a regular, move past the drag distance and release over an eligible row
## drops it there (the strip or preview opens, the row highlighted while dragging); press and
## release in place picks it up, a row click then drops it; released off the rows it goes back.
func test_mouse_drag_and_click_carry_a_regular() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	board.lock_in()
	var target: StringName = &""
	for aisle: AisleDefinition in screen.run.balance.aisles:
		if (
			target == &""
			and StartSetupRules.target_block(screen.run, screen.profile, 0, aisle.id) == &""
		):
			target = aisle.id
	var holder: Control = store.regulars[0]
	var start: Vector2 = holder.size / 2.0
	var row_point: Vector2 = store.board.rows[target].get_global_rect().get_center()
	var at_row: Vector2 = holder.get_global_transform().affine_inverse() * row_point
	store._regular_input(_mouse_button(start, true), 0)
	assert_bool(store.carrying()).is_false()
	store._regular_input(_mouse_motion(at_row), 0)
	assert_int(store.carry_slot).is_equal(0)
	assert_bool(store.ghost.visible).is_true()
	assert_object(store.regulars[0]).is_same(holder)
	assert_str((store.board.rows[target].get_node("Pill/Words") as Label).text).is_equal(
		"DROP HERE"
	)
	store._regular_input(_mouse_button(at_row, false), 0)
	assert_bool(store.carrying()).is_false()
	assert_object(board._modal).is_not_null()
	assert_str(String(_last_slot_aisle(board))).is_equal(String(target))
	board.back()
	# Released off the rows: put down, nothing opens.
	store._regular_input(_mouse_button(start, true), 0)
	store._regular_input(_mouse_motion(start + Vector2(0, -40)), 0)
	store._regular_input(_mouse_button(start + Vector2(0, -40), false), 0)
	assert_bool(store.carrying()).is_false()
	assert_object(board._modal).is_null()
	# Click, then click a row.
	store._regular_input(_mouse_button(start, true), 0)
	store._regular_input(_mouse_button(start, false), 0)
	assert_int(store.carry_slot).is_equal(0)
	assert_str(store.carry_via).is_equal("click")
	store.board.row_clicked.emit(target)
	assert_object(board._modal).is_not_null()


func _last_slot_aisle(board: StartBoard) -> StringName:
	for key: String in board.run.start_setup.regular_offers:
		return StringName(key.get_slice(":", 1))
	return &""


static func _mouse_button(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = point
	return button


static func _mouse_motion(point: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	return motion


## The reveal at LOCK IN (reduced motion off): the cloths lift and the tiles pop in; skipping it
## (or a refresh) leaves every basket uncovered at full size. A RESTOCK plays only its basket.
## Reduced motion never starts it.
func test_the_lock_in_reveal_settles_and_respects_reduced_motion() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var store: StorePage = board.store
	screen.profile.set_reduced_motion(false)
	assert_bool(board.lock_in()).is_true()
	assert_bool(store.is_dealing()).is_true()
	assert_bool(store.baskets[2].cover.visible).is_true()
	assert_float(store.baskets[2].tiles[0].scale.x).is_less(0.01)
	store.skip_deal()
	assert_bool(store.is_dealing()).is_false()
	for view: StartBasketView in store.baskets:
		assert_bool(view.cover.visible).is_false()
		for tile: Control in view.tiles:
			assert_vector(tile.scale).is_equal(Vector2.ONE)
	assert_bool(board.restock(1)).is_true()
	assert_bool(store.baskets[1].cover.visible).is_true()
	assert_bool(store.baskets[0].cover.visible).is_false()
	board.refresh()
	assert_bool(store.is_dealing()).is_false()
	store.play_deal(true)
	assert_bool(store.is_dealing()).is_false()


## Keys: 1–4 pick up a regular, Up/Down move over the rows, Enter drops on the focused row.
func test_keys_carry_and_drop_a_regular() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	board.lock_in()
	board._input(_key(KEY_2))
	assert_int(board.store.carry_slot).is_equal(1)
	var focus: int = board.store.board.focus
	assert_int(focus).is_greater(0)
	var id: StringName = board.store.board.ids[focus]
	assert_str(String(StartSetupRules.target_block(screen.run, screen.profile, 1, id))).is_empty()
	board._input(_key(KEY_ENTER))
	assert_object(board._modal).is_not_null()
	board.back()
	board._input(_key(KEY_2))
	board._input(_key(KEY_2))
	assert_bool(board.store.carrying()).is_false()


## RESTOCK (3 completed aisles): R, then 2 redraws basket 2 only, from the same source; the other
## baskets and the packs stay; the basket wears RESTOCKED and the tags go; saved and logged.
func test_restock_redraws_one_basket_once() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	var run: RunState = screen.run
	board.lock_in()
	var dealt: Array[Array] = []
	for basket: StartBasket in run.start_setup.baskets:
		dealt.append(basket.cards.duplicate())
	var packs: Array[StarterPackDefinition] = run.start_offer.packs.duplicate()
	var state: int = run.rng_state
	board._input(_key(KEY_R))
	assert_bool(board.store.restock_picking).is_true()
	assert_str(StartBoardKit.key_caption(board.store.baskets[1].tag).text).contains("2")
	board._input(_key(KEY_2))
	assert_int(run.start_setup.restock_basket).is_equal(1)
	assert_array(run.start_setup.baskets[0].cards).is_equal(dealt[0])
	assert_array(run.start_setup.baskets[2].cards).is_equal(dealt[2])
	assert_array(run.start_setup.baskets[1].cards).is_not_equal(dealt[1])
	for card: CardDefinition in run.start_setup.baskets[1].cards:
		assert_str(String(run.balance.aisle_of(card).id)).is_equal(
			String(run.start_setup.baskets[1].source)
		)
	assert_array(run.start_offer.packs).is_equal(packs)
	assert_int(run.rng_state).is_equal(state)
	assert_object(board.store.baskets[1].stamp).is_not_null()
	for view: StartBasketView in board.store.baskets:
		assert_object(view.tag).is_null()
	assert_bool(board.restock(0)).is_false()
	assert_int(int(_last_event("restock")["basket"])).is_equal(1)
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(run.balance))
	assert_int(saved.run.start_setup.restock_basket).is_equal(1)


## Below 3 completed aisles the tags show greyed with the reason; R does nothing. Before an aisle
## is completed a regular can't be picked up.
func test_restock_and_replacements_are_locked_on_a_fresh_profile() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.lock_in()
	for view: StartBasketView in board.store.baskets:
		assert_bool(view.tag.disabled).is_true()
		assert_str(view.tag.tooltip_text).is_equal("RESTOCK opens at 3 completed aisles (0/3)")
	board._input(_key(KEY_R))
	assert_bool(board.store.restock_picking).is_false()
	assert_bool(board.restock(0)).is_false()
	assert_bool(board.store.carry(0, "click")).is_false()
	assert_str(board.store.tray_tip.text).contains("Complete an aisle")


func test_a_failed_run_save_rolls_back_the_swap_and_profile() -> void:
	var screen: ShiftScreen = await _screen(3)
	screen._cart_reveal.board.lock_in()
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
	assert_array(screen._saves.load_profile().staple_swaps).is_empty()
	assert_int(errors.size()).is_equal(1)


func test_pin_changes_update_the_waiting_run_without_redealing() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.lock_in()
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


## Page 1 at 1280x720 and 1920x1080, at 0, 3 and 6 completed aisles, in SELECT and after LOCK IN:
## the 7 rows inside the board and apart, each row's name, count and pill inside it and apart, the
## note under the rows; the baskets inside the counter and apart with their tiles and tags; the
## regulars inside the tray and apart, clear of its tip; the chrome and footer apart.
func test_store_page_layout_has_no_clipping_or_overlap() -> void:
	for completed: int in [0, 3, 6]:
		var screen: ShiftScreen = await _screen(completed)
		var board: StartBoard = screen._cart_reveal.board
		for locked: bool in [false, true]:
			if locked:
				board.lock_in()
			for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
				board.set_anchors_preset(Control.PRESET_TOP_LEFT)
				board.size = extent
				board._resize()
				_assert_store_layout(board, screen.run)


func _assert_store_layout(board: StartBoard, run: RunState) -> void:
	var stage: Rect2 = _stage_rect(board)
	var store: StorePage = board.store
	var panel: Rect2 = (store.board.get_node("Board") as Control).get_global_rect()
	var rows: Array[Rect2] = []
	assert_int(store.board.ids.size()).is_equal(1 + run.balance.aisles.size())
	for id: StringName in store.board.ids:
		var row: Panel = store.board.rows[id]
		var rect: Rect2 = row.get_global_rect()
		assert_bool(panel.encloses(rect)).is_true()
		var words: Rect2 = _text_rect(row.get_node("Name"))
		assert_bool(rect.grow(0.5).encloses(words)).is_true()
		var drawn: Rect2 = _number_rect(row.get_node("Items"))
		var items: Rect2 = Rect2(drawn.position.x, rect.position.y + 1, drawn.size.x, 2)
		assert_bool(rect.grow(0.5).encloses(items)).is_true()
		assert_bool(words.intersects(items)).is_false()
		var pill: Control = row.get_node_or_null("Pill")
		if pill != null:
			assert_bool(rect.encloses(pill.get_global_rect())).is_true()
			assert_bool(pill.get_global_rect().intersects(items)).is_false()
			var pill_words: Rect2 = _text_rect(pill.get_node("Words"))
			assert_bool(pill.get_global_rect().grow(0.5).encloses(pill_words)).is_true()
		for other: Rect2 in rows:
			assert_bool(rect.intersects(other)).is_false()
		rows.append(rect)
	var note: Rect2 = (store.board.get_node("Note") as Control).get_global_rect()
	assert_bool(panel.encloses(note)).is_true()
	for rect: Rect2 in rows:
		assert_bool(rect.intersects(note)).is_false()
	var counter: Rect2 = Rect2(
		StorePage.COUNTER.position * board._stage.scale + board._stage.global_position,
		StorePage.COUNTER.size * board._stage.scale
	)
	assert_bool(stage.encloses(counter)).is_true()
	assert_bool(counter.intersects(panel)).is_false()
	var baskets: Array[Rect2] = []
	for view: StartBasketView in store.baskets:
		var rect: Rect2 = view.get_global_rect()
		assert_bool(counter.encloses(rect)).is_true()
		for tile: Control in view.tiles:
			assert_bool(rect.encloses(tile.get_global_rect())).is_true()
		if view.tag != null:
			assert_bool(rect.encloses(view.tag.get_global_rect())).is_true()
		assert_bool(rect.grow(0.5).encloses(_text_rect(view.label))).is_true()
		for other: Rect2 in baskets:
			assert_bool(rect.intersects(other)).is_false()
		baskets.append(rect)
	assert_bool(counter.encloses(store.counter_line.get_global_rect())).is_true()
	var tray: Rect2 = (store.get_node("Tray").get_child(0) as Control).get_global_rect()
	var tip: Rect2 = (store.get_node("Tray/Tip") as Control).get_global_rect()
	assert_bool(tray.encloses(tip)).is_true()
	assert_bool(tray.intersects(counter)).is_false()
	var tiles: Array[Rect2] = []
	for regular: Control in store.regulars:
		var rect: Rect2 = regular.get_global_rect()
		assert_bool(tray.encloses(rect)).is_true()
		assert_bool(rect.intersects(tip)).is_false()
		for other: Rect2 in tiles:
			assert_bool(rect.intersects(other)).is_false()
		tiles.append(rect)
	_assert_chrome(board, stage)
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


## The top bar's chips and the two tabs stay apart and on the stage on both pages; YOUR STORE
## shows its check only on page 2; page 2's keycap hints stay left of the order sheet and clock.
func test_top_bar_tabs_and_hints_stay_apart() -> void:
	var screen: ShiftScreen = await _screen(3)
	var board: StartBoard = screen._cart_reveal.board
	board.lock_in()
	var stage: Rect2 = _stage_rect(board)
	assert_object(board._rail.get_node_or_null("Tab1/Done")).is_null()
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


## A pixel label's visible words, in global px (its own width can be wider than its words).
func _text_rect(label: Label) -> Rect2:
	var factor: float = label.get_global_transform().get_scale().x
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var extent: Vector2 = Vector2(
		StartBoardKit.text_width(label.text, 1), ArtStyle.PIXEL_CAP_HEIGHT
	)
	return Rect2(label.global_position + Vector2(0, cap_top * factor), extent * factor)


## A number label's drawn text, in global px.
func _number_rect(label: Label) -> Rect2:
	var factor: float = label.get_global_transform().get_scale().x
	var font_size: int = label.get_theme_font_size("font_size")
	var font: Font = label.get_theme_font("font")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left: float = 0.0
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		left = label.size.x - width
	return Rect2(
		label.global_position + Vector2(left * factor, 0), Vector2(width, label.size.y) * factor
	)


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


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
