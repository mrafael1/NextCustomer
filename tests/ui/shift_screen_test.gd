extends GdUnitTestSuite
## End-to-end: the real shift screen through placing, redraw, checkout, the count-up, the
## event log and the next shift. Clicks are sent to the screen's handlers, because headless
## runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
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
	screen._on_reward_skipped()  # Past the impulse rack.
	var run: RunState = screen.run
	assert_int(run.hand().size()).is_equal(8)

	# Redraw two cards through the redraw mode.
	var hand: Array[CardInstance] = run.hand()
	screen._on_redraw_pressed()
	screen._on_hand_card_clicked(_view_for(screen, hand[6]))
	screen._on_hand_card_clicked(_view_for(screen, hand[7]))
	screen._on_redraw_pressed()
	assert_int(run.redraws_used).is_equal(1)
	assert_bool(run.hand().has(hand[6])).is_false()

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

	await screen._on_checkout_pressed()
	var subtotal: Label = screen._subtotal_label
	assert_str(subtotal.text).is_equal("€%d" % expected_total)
	var passed: bool = expected_total >= run.quota()
	# A pass shows the reward choice; a fail shows the results screen.
	assert_bool(screen._reward_panel.visible).is_equal(passed)
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
		screen._on_reward_skipped()
		types = _events().map(func(event: Dictionary) -> String: return event["type"])
		assert_int(screen.run.shift_index).is_equal(1)
		assert_array(types.slice(-2)).is_equal(["reward", "shift_start"])
		assert_bool(_events()[-2]["skipped"]).is_true()
	else:
		screen._on_new_run_pressed()
		screen._on_reward_skipped()
		types = _events().map(func(event: Dictionary) -> String: return event["type"])
		assert_int(screen.run.shift_index).is_equal(0)
		assert_array(types.slice(-3)).is_equal(["restart", "run_start", "shift_start"])


## A row card picked up and dropped back in the hand is a removal; one placed again is not.
func test_dropping_a_picked_row_card_counts_as_a_removal() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
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
	screen._on_reward_skipped()  # Past the impulse rack.
	_place_ids(screen, ["bread", "bread", "repeat", "bread", "bread", "bread", "bread"])
	assert_int(screen.run.row.size()).is_equal(7)
	for id: String in ["bread", "repeat"]:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		for panel: PanelContainer in screen._slots:
			var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
			assert_bool(style.border_color == Palette.MUSTARD).is_false()


## Plan section 3.1: 6 shared slots + 1 coupon-only slot, and the window fits all 7. The coupon
## slot is a count, not a position: no panel is marked for coupons, because a new player
## would read that as "coupons only go here" (playtest feedback).
func test_the_row_shows_the_coupon_slot() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	assert_int(screen._slots.size()).is_equal(7)
	for slot: int in range(7):
		assert_str(_slot_hint(screen, slot)).is_equal(str(slot + 1))
	assert_str(screen._capacity_label.text).contains("Products 0/6").contains("Coupon slot 0/1")
	_place_ids(screen, ["bread", "repeat"])
	assert_str(screen._capacity_label.text).contains("Products 1/6").contains("Coupon slot 1/1")
	_place_ids(screen, ["repeat"])
	assert_str(screen._capacity_label.text).contains("Products 1/6").contains("Coupon slot 1/1")
	await _frames(2)
	var margin: MarginContainer = null
	for child: Node in screen.get_children():
		if child is MarginContainer:
			margin = child
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_float(margin.get_combined_minimum_size().x).is_less_equal(width)


## A product that doesn't fit says why instead of doing nothing; a coupon still fits.
func test_a_seventh_product_is_refused_with_a_notice() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	_place_ids(screen, ["bread", "bread", "bread", "bread", "bread", "bread"])
	assert_str(screen._notice_label.text).is_empty()
	screen._debug.add_card("bread")
	var product: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, product))
	assert_str(screen._notice_label.text).contains("6/6 products").contains("coupon")
	screen._notice_label.text = ""
	screen._on_slot_input(_left_click(), 6)
	assert_int(screen.run.row.size()).is_equal(6)
	assert_bool(screen.run.row.has(product)).is_false()
	assert_str(screen._notice_label.text).contains("6/6 products")
	screen._debug.add_card("repeat")
	var coupon: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, coupon))
	screen._on_slot_input(_left_click(), 2)
	assert_object(screen.run.row[2]).is_same(coupon)
	assert_int(screen.run.row.size()).is_equal(7)


## The notice says to take a product out: clicking a row product does that, it doesn't
## repeat the refusal.
func test_a_refused_pick_lets_a_row_card_be_taken_out() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	_place_ids(screen, ["bread", "bread", "bread", "bread", "bread", "bread", "repeat"])
	screen._debug.add_card("bread")
	var product: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, product))
	assert_str(screen._notice_label.text).contains("take a product out")
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
	screen._on_reward_skipped()  # Past the impulse rack.
	screen._debug.add_card("bread")
	var product: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, product))
	screen._on_slot_input(_left_click(), 6)
	assert_object(screen.run.row[0]).is_same(product)
	assert_str(screen._notice_label.text).is_empty()


func test_picking_a_reward_adds_it_to_the_deck_and_logs_it() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _pass_first_shift(screen)
	var offered: CardDefinition = screen.run.offer[0]
	screen._on_reward_deck_requested()
	assert_bool(screen._deck_view.visible).is_true()
	screen._deck_view._close()
	assert_bool(screen._reward_panel.visible).is_true()
	screen._on_reward_picked(offered)
	assert_int(screen.run.deck.size()).is_equal(14)
	assert_int(screen.run.shift_index).is_equal(1)
	var reward: Dictionary = _last_event("reward")
	assert_str(reward["picked"]).is_equal(String(offered.id))
	assert_bool(reward["deck_view_opened"]).is_true()
	assert_int((reward["offered"] as Array).size()).is_equal(3)
	assert_int(int(reward["shift"])).is_equal(1)


func test_a_full_deck_asks_which_card_to_remove() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	var bread: CardDefinition = load(BREAD)
	while not screen.run.deck_is_full():
		screen.run.deck.add_card(bread)
	await _pass_first_shift(screen)
	var offered: CardDefinition = screen.run.offer[1]
	screen._on_reward_picked(offered)
	assert_bool(screen._deck_view.visible).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)
	# Closing the deck view goes back to the offer without taking anything.
	screen._deck_view._close()
	assert_bool(screen._reward_panel.visible).is_true()
	screen._on_reward_picked(offered)
	var removed: CardInstance = screen.run.deck.cards[0]
	screen._on_deck_card_chosen(removed)
	assert_int(screen.run.deck.size()).is_equal(screen.run.balance.deck_limit)
	assert_bool(screen.run.deck.cards.has(removed)).is_false()
	assert_str(_last_event("reward")["replaced"]).is_equal(String(removed.definition.id))


func test_export_from_the_shift_screen_logs_the_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
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
	screen._on_reward_skipped()  # Past the impulse rack.
	for button: Button in [
		screen._checkout_button, screen._redraw_button, screen._cancel_button, screen._deck_button
	]:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_NONE)


## The review's repro: after a reward, Space (the fast-forward key) must not check out.
func test_space_after_a_reward_does_not_check_out() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _pass_first_shift(screen)
	screen._on_reward_skipped()
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	runner.simulate_key_pressed(KEY_SPACE)
	await _frames(5)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._counting).is_false()


func test_checkout_closes_the_deck_view_and_overlays_are_shaded() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	screen._on_deck_button_pressed()
	await _frames(2)
	assert_bool(screen._shade.visible).is_true()
	await _pass_first_shift(screen)
	assert_bool(screen._deck_view.visible).is_false()
	await _frames(2)
	assert_bool(screen._reward_panel.visible).is_true()
	assert_bool(screen._shade.visible).is_true()


## Clicks meant to speed up the count-up must not pick a reward the player hasn't seen.
func test_reward_cards_ignore_clicks_until_armed() -> void:
	var panel: RewardPanel = auto_free(RewardPanel.new())
	add_child(panel)
	var offer: Array[CardDefinition] = [load(BREAD)]
	panel.show_offer(offer, "test", 13, 15)
	var picks: Array = []
	panel.picked.connect(func(card: CardDefinition) -> void: picks.append(card))
	var view: CardView = panel._cards.get_child(0)
	panel._on_card_clicked(view)
	assert_array(picks).is_empty()
	assert_bool(panel._skip_button.disabled).is_true()
	# Wait on wall-clock time: the suite speeds up game time.
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 450:
		await get_tree().process_frame
	await get_tree().process_frame
	panel._on_card_clicked(view)
	assert_int(picks.size()).is_equal(1)
	assert_bool(panel._skip_button.disabled).is_false()


## Places a row that always passes the first quota: Bread, Multipack, Bread x4 = 27.
func _pass_first_shift(screen: ShiftScreen) -> void:
	for id: String in ["bread", "multipack", "bread", "bread", "bread", "bread"]:
		screen._debug.add_card(id)
	var added: Array[CardInstance] = screen.run.hand().slice(-6)
	for card: CardInstance in added:
		screen._on_hand_card_clicked(_view_for(screen, card))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)


## Adds the cards to the hand through the debug panel and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


static func _slot_hint(screen: ShiftScreen, slot: int) -> String:
	var hint: Label = screen._slots[slot].get_child(0) as Label
	return hint.text if hint != null else ""


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
	screen._on_reward_skipped()  # Past the impulse rack.
	var start: Dictionary = _last_event("run_start")
	assert_array(start["listed_aisles"]).is_equal(["cold_cases", "pantry", "household"])
	assert_array(start["stock"]).is_equal(screen.run.stock.card_ids())
	assert_int((start["stock"] as Array).size()).is_equal(26)


## The run length comes from balance data: the header, the debug shift jump, the win screen and
## the log all follow it. Jumps straight to the last shift instead of playing every shift.
func test_winning_the_last_shift_shows_the_results() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	var count: int = screen.run.shift_count()
	assert_int(int(_last_event("run_start")["shift_count"])).is_equal(count)
	assert_str(screen._shift_label.text).is_equal("Shift 1 / %d" % count)
	var shift_input: SpinBox = screen._debug.panel.get("_shift_input")
	assert_int(int(shift_input.max_value)).is_equal(count)

	screen._debug.skip_to_shift(count)
	assert_bool(screen.run.is_last_shift()).is_true()
	assert_str(screen._shift_label.text).is_equal("Shift %d / %d" % [count, count])
	assert_int(int(_last_event("shift_start")["shift"])).is_equal(count)
	# Bread, Multipack, then four Milks at x2: 67, above the last quota.
	_place_ids(screen, ["bread", "multipack", "milk", "milk", "milk", "milk"])
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.WON)
	assert_bool(screen._results.visible).is_true()
	assert_bool(screen._reward_panel.visible).is_false()
	assert_str(screen._results.detail_text()).starts_with("All %d shifts cleared." % count)
	var run_end: Dictionary = _last_event("run_end")
	assert_str(run_end["result"]).is_equal("win")
	assert_int(int(run_end["shift_reached"])).is_equal(count)


func test_empty_checkout_loses_and_logs_run_end() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await screen._on_checkout_pressed()
	var events: Array = _events()
	assert_str(events[-1]["type"]).is_equal("count_up")
	assert_str(events[-2]["type"]).is_equal("run_end")
	assert_str(events[-2]["result"]).is_equal("loss")
	assert_int(int(events[-3]["score"])).is_equal(0)


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	var hand_box: HBoxContainer = screen._hand_box
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
