extends GdUnitTestSuite
## End-to-end: the real shift screen through placing, redraw, checkout, the count-up, the
## event log and the next shift. Clicks are sent to the screen's handlers, because headless
## runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
## Checkouts rush their count (one tap): the suite tests what follows it.
const Rush := preload("res://tests/ui/count_up_rush.gd")
const BREAD := "res://data/cards/bread.tres"

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


func test_a_shift_from_draw_to_next_shift() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	assert_int(run.hand().size()).is_equal(8)

	# Redraw the last basket (plan section 3.8): its two items, in their places.
	var hand: Array[CardInstance] = run.hand()
	screen._on_redraw_pressed()
	screen._on_basket_clicked(3)
	screen._basket_redraw.stop()
	assert_int(run.redraws_used).is_equal(1)
	assert_bool(run.hand().has(hand[6]) or run.hand().has(hand[7])).is_false()
	assert_bool(screen._redraw_mode).is_false()

	# Place three cards with clicks: pick up a hand card, then click a slot.
	hand = run.hand()
	for index: int in range(3):
		screen._on_hand_card_clicked(_view_for(screen, hand[index]))
		screen._on_slot_input(_left_click(), index)
	assert_int(run.row.size()).is_equal(3)
	# Pick one back up and put it in front.
	screen._on_row_card_clicked(_row_view(screen, 2))
	screen._on_slot_input(_left_click(), 0)
	assert_object(run.row[0]).is_same(hand[2])
	var expected_total: int = run.preview().total

	await Rush.checkout(screen)
	# The register reads the counted total, and the monitor's checkout column shows it under TOTAL.
	assert_int(screen._led.amount()).is_equal(expected_total)
	assert_int(screen._led.mode()).is_equal(LedDisplay.Mode.TOTAL)
	var column: CheckoutColumn = screen._monitor.checkout()
	assert_int(column.total_number().value()).is_equal(expected_total)
	assert_str(column.caption().text).is_equal(MonitorText.TOTAL_CAPTION)
	var passed: bool = expected_total >= run.quota()
	# A pass opens the RECEIPT REWARDS machine (#77); a fail shows the results screen.
	assert_bool(screen._machine.is_open()).is_equal(passed)
	assert_bool(screen._results.visible).is_equal(not passed)

	var events: Array = _events()
	var types: Array = events.map(func(event: Dictionary) -> String: return event["type"])
	var expected_types: Array = ["run_start", "shift_start", "redraw", "checkout"]
	if not passed:
		expected_types.append("run_end")
	expected_types.append("count_up")
	assert_array(types).contains_exactly(expected_types)
	var checkout: Dictionary = events[3]
	assert_int(int(checkout["score"])).is_equal(expected_total)
	assert_int(int(checkout["placements"])).is_equal(4)
	# A move within the row is 1 placement and 0 removals (plan section 8).
	assert_int(int(checkout["removals"])).is_equal(0)
	var count_up: Dictionary = events[-1]
	assert_int(int(count_up["count_up_ms"])).is_greater(0)
	assert_int(int(checkout["rearrangements"])).is_equal(1)
	assert_int((checkout["final_order"] as Array).size()).is_equal(3)
	assert_bool(checkout["passed"]).is_equal(passed)

	if passed:
		screen._machine.debug_skip()
		types = _events().map(func(event: Dictionary) -> String: return event["type"])
		assert_int(screen.run.shift_index).is_equal(1)
		assert_array(types.slice(-2)).is_equal(["machine_visit", "shift_start"])
		assert_bool(_events()[-2]["binned"]).is_true()
	else:
		screen._on_new_run_pressed()
		types = _events().map(func(event: Dictionary) -> String: return event["type"])
		assert_int(screen.run.shift_index).is_equal(0)
		assert_array(types.slice(-3)).is_equal(["restart", "run_start", "shift_start"])


## A row card picked up and dropped back in the hand is a removal; one placed again is not.
func test_dropping_a_picked_row_card_counts_as_a_removal() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var hand: Array[CardInstance] = screen.run.hand()
	for index: int in range(2):
		screen._on_hand_card_clicked(_view_for(screen, hand[index]))
		screen._on_slot_input(_left_click(), index)
	screen._on_row_card_clicked(_row_view(screen, 0))
	screen._on_background_input(_left_click())
	assert_int(screen.tracker.removals).is_equal(1)
	assert_int(screen.run.row.size()).is_equal(1)
	# A wheel tick over the background doesn't drop a picked card.
	screen._on_row_card_clicked(_row_view(screen, 0))
	var wheel: InputEventMouseButton = _left_click()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	screen._on_background_input(wheel)
	assert_object(screen._picked).is_not_null()


func test_full_row_highlights_no_slot() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_place_ids(screen, ["bread", "bread", "repeat", "bread", "bread", "bread", "bread"])
	assert_int(screen.run.row.size()).is_equal(7)
	for id: String in ["bread", "repeat"]:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		for slot: int in range(screen._slots.size()):
			assert_bool(screen._row_strip.is_outlined(slot)).is_false()


## Plan section 3.1 (v0.46, #106): 7 general slots, and the window fits all 7. Any card goes in
## any slot: no panel is marked for coupons.
func test_the_row_shows_seven_general_slots() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	assert_int(screen._slots.size()).is_equal(7)
	for slot: int in range(7):
		assert_str(_slot_hint(screen, slot)).is_equal(str(slot + 1))
	var run: RunState = screen.run
	assert_int(run.limits.slot_count).is_equal(7)
	_place_ids(screen, ["bread", "repeat", "repeat"])
	assert_int(run.row.size()).is_equal(3)
	await _frames(2)
	var stage: Rect2 = _stage_rect(screen)
	var receipt: Rect2 = screen._receipt.get_global_rect()
	for panel: PanelContainer in screen._slots:
		assert_bool(stage.encloses(panel.get_global_rect())).is_true()
		assert_bool(panel.get_global_rect().intersects(receipt)).is_false()


## A card that doesn't fit says why instead of doing nothing: a 7th product fits (any card in
## any slot, v0.46), and an 8th card of either kind is refused with a notice.
func test_an_eighth_card_is_refused_with_a_notice() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_place_ids(screen, ["bread", "bread", "bread", "bread", "bread", "bread", "bread"])
	assert_int(screen.run.row.size()).is_equal(7)
	assert_str(screen._notice_label.text).is_empty()
	for id: String in ["bread", "repeat"]:
		screen._debug.add_card(id)
		var card: CardInstance = screen.run.hand()[-1]
		screen._on_hand_card_clicked(_view_for(screen, card))
		assert_str(screen._notice_label.text).contains("Row full (7/7 items)")
		screen._notice_label.text = ""
		screen._on_slot_input(_left_click(), 2)
		assert_int(screen.run.row.size()).is_equal(7)
		assert_bool(screen.run.row.has(card)).is_false()
		assert_str(screen._notice_label.text).contains("Row full (7/7 items)")
		screen._notice_label.text = ""


## The notice says to take an item out: clicking a row product does that, it doesn't repeat the
## refusal.
func test_a_refused_pick_lets_a_row_card_be_taken_out() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_place_ids(screen, ["bread", "bread", "bread", "bread", "bread", "bread", "repeat"])
	screen._debug.add_card("bread")
	var product: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, product))
	assert_str(screen._notice_label.text).contains("take an item out")
	var row_card: CardInstance = screen.run.row[1]
	screen._on_row_card_clicked(_row_view(screen, 1))
	assert_int(screen.run.row.size()).is_equal(6)
	assert_bool(screen.run.row.has(row_card)).is_false()
	assert_object(screen._picked).is_same(row_card)
	assert_bool(screen.run.hand().has(product)).is_true()


## While product room is left, any panel takes a product: the 7th panel isn't reserved.
func test_the_seventh_panel_takes_a_product_while_room_is_left() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.add_card("bread")
	var product: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, product))
	screen._on_slot_input(_left_click(), 6)
	assert_object(screen.run.row[0]).is_same(product)
	assert_str(screen._notice_label.text).is_empty()


## The machine's real flow (#77): the Cart opens the deck view once the machine has armed and
## gives the machine back on close; a confirmed chute draws its prizes; a picked NEW ITEMS
## prize joins the deck, the visit is logged as machine_visit and the next shift starts.
func test_picking_a_prize_adds_it_to_the_deck_and_logs_it() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _pass_first_shift(screen)
	await _until_armed(screen)
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	assert_bool(screen._machine.view.visible).is_false()
	screen._deck_view._close()
	assert_bool(screen._machine.is_open()).is_true()
	screen._machine.view.press_key(RewardMachine.Chute.NEW_ITEMS)
	screen._machine.view._on_confirmed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	var offered: CardDefinition = screen.run.machine.prizes()[0].card
	await _until_armed(screen)
	screen._machine.view.pick(0)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	assert_int(screen.run.deck.size()).is_equal(14)
	assert_int(screen.run.shift_index).is_equal(1)
	# The top bar's Cart counts the deck against its limit.
	assert_str(screen._deck_button.caption).is_equal("Cart 14/%d" % screen.run.balance.deck_limit)
	var visit: Dictionary = _last_event("machine_visit")
	assert_str(visit["chute"]).is_equal("new_items")
	assert_int(int(visit["picked"])).is_equal(0)
	assert_str(visit["offered"][0]["id"]).is_equal(String(offered.id))
	assert_int((visit["offered"] as Array).size()).is_equal(3)
	assert_int(int(visit["shift"])).is_equal(1)
	assert_bool(visit["resumed"]).is_false()


## At the deck limit a picked prize opens the chooser; its cancel goes back to the prizes with
## nothing taken; a chosen card is swapped out and logged as replaced.
func test_a_full_deck_asks_which_card_to_remove() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var bread: CardDefinition = load(BREAD)
	while not screen.run.deck_is_full():
		screen.run.deck.add_card(bread)
	await _pass_first_shift(screen)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _until_armed(screen)
	screen._machine.view.pick(1)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	assert_bool(screen._deck_view.visible).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	# Closing the deck view goes back to the prizes without taking anything.
	screen._deck_view._close()
	assert_bool(screen._machine.is_open()).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	screen._machine.view.pick(1)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	var removed: CardInstance = screen.run.deck.cards[0]
	screen._on_deck_card_chosen(removed)
	assert_int(screen.run.deck.size()).is_equal(screen.run.balance.deck_limit)
	assert_bool(screen.run.deck.cards.has(removed)).is_false()
	var limit: int = screen.run.balance.deck_limit
	assert_str(screen._deck_button.caption).is_equal("Cart %d/%d" % [limit, limit])
	assert_str(_last_event("machine_visit")["replaced"]).is_equal(String(removed.definition.id))
	assert_bool(_last_event("machine_visit")["cart_full_at_pick"]).is_true()


func test_export_from_the_shift_screen_logs_the_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	_event_log().use_folder(_folder.path_join("logs"))
	var joined: String = _event_log().export_logs("shift", false)
	assert_str(joined).contains("log_export")
	for file_name: String in DirAccess.get_files_at(_folder.path_join("logs")):
		DirAccess.remove_absolute(_folder.path_join("logs").path_join(file_name))
	DirAccess.remove_absolute(_folder.path_join("logs"))
	DirAccess.remove_absolute(_folder.path_join("playtest_export.jsonl"))
	assert_object(screen).is_not_null()


func test_title_screen_starts_the_game() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://ui/title_screen.tscn")
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title._on_background_input(_left_click())
	assert_bool(title._starting).is_true()


func test_buttons_never_take_keyboard_focus() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for button: Button in [
		screen._checkout_button, screen._redraw_button, screen._cancel_button, screen._deck_button
	]:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)


## The review's repro: after the machine, Space (the fast-forward key) must not check out.
func test_space_after_the_machine_does_not_check_out() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _pass_first_shift(screen)
	screen._machine.debug_skip()
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	runner.simulate_key_pressed(KEY_SPACE)
	await _frames(5)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._counting).is_false()


func test_checkout_closes_the_deck_view_and_no_shade_covers_the_visit() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_deck_button_pressed()
	await _frames(2)
	assert_bool(screen._shade.visible).is_true()
	await _pass_first_shift(screen)
	assert_bool(screen._deck_view.visible).is_false()
	await _frames(2)
	assert_bool(screen._machine.is_open()).is_true()
	# No shade over the store during a visit (#77 machine v2): the camera glides to the machine.
	assert_bool(screen._shade.visible).is_false()


## Clicks meant to speed up the count-up must not choose a chute or pick a prize the player
## hasn't seen: the machine arms on the first frame the mouse is up after it shows.
func test_the_machine_ignores_clicks_until_armed() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _pass_first_shift(screen)
	var view: RewardMachineView = screen._machine.view
	view._armed = false
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	assert_int(view.pressed_chute()).is_equal(-1)
	await _until_armed(screen)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(view.is_armed()).is_false()
	view.pick(0)
	view.fast_forward()  # The landing plays to its end.
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	await _until_armed(screen)
	view.pick(0)
	view.fast_forward()  # The landing plays to its end.
	assert_int(screen.run.shift_index).is_equal(1)


## Fast-forwards the machine to its wait point (as a tap would, unlogged), then waits (at most
## 3 s) for it to arm: the mouse is up, so it arms on its next frame.
func _until_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()


## Places a row that passes the first five quotas: Milk, Multipack, Milk x5 = 109.
func _pass_first_shift(screen: ShiftScreen) -> void:
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		screen._debug.add_card(id)
	var added: Array[CardInstance] = screen.run.hand().slice(-7)
	for card: CardInstance in added:
		screen._on_hand_card_clicked(_view_for(screen, card))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


## Adds the cards to the hand through the debug panel and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## The 1280x720 stage's global rect (headless runs use a 1280x1280 window: the stage is centred).
static func _stage_rect(screen: ShiftScreen) -> Rect2:
	return screen._stage.get_global_rect()


static func _slot_hint(screen: ShiftScreen, slot: int) -> String:
	var hint: Label = RowStrip.slot_number(screen._slots[slot])
	return hint.text if hint != null and hint.visible else ""


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _last_event(type: String) -> Dictionary:
	var events: Array = _events()
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


## run_start logs the run's stock (full build plan section 4), so a run can be rebuilt without
## the profile: the aisles stocked whole and the card ids in stock order.
func test_run_start_logs_the_stock() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var start: Dictionary = _last_event("run_start")
	assert_array(start["listed_aisles"]).is_equal(["cold_cases", "pantry", "household"])
	assert_array(start["stock"]).is_equal(screen.run.stock.card_ids())
	assert_int((start["stock"] as Array).size()).is_equal(28)


## The run length comes from balance data: the header, the debug shift jump, the win screen and
## the log all follow it. Jumps straight to the last shift instead of playing every shift.
func test_winning_the_last_shift_shows_the_results() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var count: int = screen.run.shift_count()
	assert_int(int(_last_event("run_start")["shift_count"])).is_equal(count)
	assert_str(screen._shift_label.text).is_equal("1/%d" % count)
	var shift_input: SpinBox = screen._debug.panel.get("_shift_input")
	assert_int(int(shift_input.max_value)).is_equal(count)

	screen._debug.skip_to_shift(count)
	assert_bool(screen.run.is_last_shift()).is_true()
	assert_str(screen._shift_label.text).is_equal("%d/%d" % [count, count])
	assert_int(int(_last_event("shift_start")["shift"])).is_equal(count)
	# The last quota (plan v0.28) expects upgrades: this test plays it against 48 instead.
	screen.run.limits.quota = 48
	# Milk, Multipack, then four Milks at x3 (they share Dairy): 82, above that quota.
	_place_ids(screen, ["milk", "multipack", "milk", "milk", "milk", "milk"])
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.WON)
	assert_bool(screen._results.visible).is_true()
	assert_bool(screen._machine.is_open()).is_false()
	assert_str(screen._results.texts()[0]).is_equal("RUN WON!")
	var run_end: Dictionary = _last_event("run_end")
	assert_str(run_end["result"]).is_equal("win")
	assert_int(int(run_end["shift_reached"])).is_equal(count)


func test_empty_checkout_loses_and_logs_run_end() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await Rush.checkout(screen)
	var events: Array = _events()
	assert_str(events[-1]["type"]).is_equal("count_up")
	assert_str(events[-2]["type"]).is_equal("run_end")
	assert_str(events[-2]["result"]).is_equal("loss")
	assert_int(int(events[-3]["score"])).is_equal(0)


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	var hand_box: Control = screen._hand_box
	for child: Node in hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _row_view(screen: ShiftScreen, slot: int) -> CardView:
	return screen._row_views[slot]


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _events() -> Array:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	return events


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
