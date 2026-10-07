extends GdUnitTestSuite
## The impulse rack on the real shift screen (full build plan section 3): shown on the reward
## panel before shift 1, picked or skipped, logged in run_start, and replayed from the debug
## panel. Clicks are sent to the screen's handlers, because headless runs don't deliver input.

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


## Before shift 1 the rack's 3 products show on the reward panel, on screen and shaded, with
## no hand drawn and nothing logged as run_start yet.
func test_the_rack_shows_before_shift_1_and_fits_the_screen() -> void:
	var screen: ShiftScreen = await _screen()
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_array(screen.run.hand()).is_empty()
	assert_bool(screen._checkout_button.disabled).is_true()
	assert_bool(screen._reward_panel.visible).is_true()
	assert_bool(screen._shade.visible).is_true()
	assert_str(screen._reward_panel._headline.text).contains("Impulse rack")
	var views: Array[Node] = screen._reward_panel._cards.get_children()
	assert_int(views.size()).is_equal(3)
	for index: int in range(views.size()):
		var view: CardView = views[index] as CardView
		assert_object(view.card.definition).is_same(screen.run.impulse_offer[index])
	assert_dict(_last_event("run_start")).is_empty()
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var panel: Rect2 = screen._reward_panel.get_global_rect()
	assert_float(panel.size.x).is_less_equal(width)
	assert_float(panel.size.y).is_less_equal(height)
	assert_bool(screen.get_global_rect().encloses(panel)).is_true()
	for view: Node in views:
		assert_bool(panel.encloses((view as CardView).get_global_rect())).is_true()
	assert_bool(panel.encloses(screen._reward_panel._skip_button.get_global_rect())).is_true()


func test_a_pick_joins_the_deck_and_run_start_logs_it() -> void:
	var screen: ShiftScreen = await _screen()
	var offered: Array = _ids(screen.run.impulse_offer)
	var card: CardDefinition = screen.run.impulse_offer[1]
	screen._on_reward_picked(card)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(screen.run.deck.size()).is_equal(14)
	assert_int(screen.run.hand().size()).is_equal(8)
	assert_bool(screen._reward_panel.visible).is_false()
	var types: Array = _events().map(func(event: Dictionary) -> String: return event["type"])
	assert_array(types.slice(-2)).is_equal(["run_start", "shift_start"])
	assert_bool(types.has("reward")).is_false()
	var start: Dictionary = _last_event("run_start")
	assert_array(start["impulse_offer"]).is_equal(offered)
	assert_str(start["impulse_pick"]).is_equal(String(card.id))
	assert_str(start["impulse_replaced"]).is_empty()
	assert_int((start["starting_deck"] as Array).size()).is_equal(13)


## run_start logs the rack's decision time and whether the deck view was opened, like the
## reward event.
func test_run_start_logs_the_rack_decision() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	screen._on_deck_closed()
	await get_tree().create_timer(0.4).timeout
	screen._on_reward_skipped()
	var start: Dictionary = _last_event("run_start")
	assert_bool(start["impulse_deck_view_opened"]).is_true()
	assert_int(int(start["impulse_decide_ms"])).is_greater(0)


## A new run's rack doesn't show over the last run's receipt and totals.
func test_the_rack_after_a_run_clears_the_last_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()
	screen.run.place(screen.run.debug_add_to_hand(load("res://data/cards/bread.tres")), 0)
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	screen._on_new_run_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_str(screen._subtotal_label.text).is_empty()
	assert_str(screen._projected_label.text).is_empty()
	assert_bool(screen._results.visible).is_false()
	assert_bool(screen._reward_panel.visible).is_true()


## The debug shift jump from an ended run replays its seed with its rack choice, then jumps.
func test_the_debug_shift_jump_after_a_run_replays_its_rack_choice() -> void:
	var screen: ShiftScreen = await _screen()
	var seed_value: int = screen.run.run_seed
	var card: CardDefinition = screen.run.impulse_offer[0]
	screen._on_reward_picked(card)
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	screen._on_debug_shift(3)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(screen.run.shift_index).is_equal(2)
	assert_int(screen.run.run_seed).is_equal(seed_value)
	assert_object(screen.run.impulse_pick).is_same(card)
	assert_bool(screen._reward_panel.visible).is_false()
	var types: Array = _events().map(func(event: Dictionary) -> String: return event["type"])
	var start: int = types.rfind("run_start")
	assert_int(start).is_greater(types.rfind("run_end"))
	assert_array(types.slice(start + 1)).is_equal(["shift_start", "shift_start"])


func test_a_skip_starts_shift_1_with_the_starting_deck() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(screen.run.deck.size()).is_equal(13)
	assert_int(screen.run.hand().size()).is_equal(8)
	assert_str(_last_event("run_start")["impulse_pick"]).is_empty()


## The deck view opens from the rack and comes back to it; the rack stays until a choice.
func test_the_deck_view_returns_to_the_rack() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	assert_bool(screen._reward_panel.visible).is_false()
	screen._on_deck_closed()
	assert_bool(screen._reward_panel.visible).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	# The debug shift jump waits for the rack too.
	screen._on_debug_shift(3)
	assert_int(screen.run.shift_index).is_equal(0)
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)


## At the deck limit a pick asks which deck card leaves, as a reward does.
func test_a_pick_at_the_deck_limit_asks_which_card_leaves() -> void:
	var screen: ShiftScreen = await _screen()
	while not screen.run.deck_is_full():
		screen.run.deck.add_card(load("res://data/cards/soup.tres"))
	var card: CardDefinition = screen.run.impulse_offer[0]
	screen._on_reward_picked(card)
	assert_bool(screen._deck_view.visible).is_true()
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	var replaced: CardInstance = screen.run.deck.cards[0]
	screen._on_deck_card_chosen(replaced)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(screen.run.deck.size()).is_equal(screen.run.balance.deck_limit)
	assert_bool(screen.run.deck.cards.has(replaced)).is_false()
	assert_str(_last_event("run_start")["impulse_replaced"]).is_equal(
		String(replaced.definition.id)
	)


func test_export_during_the_rack_names_the_screen() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_export_pressed()
	assert_str(_last_event("log_export")["screen"]).is_equal("impulse_rack")


## The debug replay: the same seed shows the same rack, and "New run with this seed" can apply
## the logged pick (or a skip) without showing it.
func test_the_debug_replay_applies_a_logged_pick() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(1234)
	var offered: Array[CardDefinition] = screen.run.impulse_offer.duplicate()
	screen.start_new_run(1234)
	assert_array(screen.run.impulse_offer).is_equal(offered)
	screen._on_debug_seed(1234, true, String(offered[2].id))
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_object(screen.run.impulse_pick).is_same(offered[2])
	assert_bool(screen._reward_panel.visible).is_false()
	var start: Dictionary = _last_event("run_start")
	assert_int(int(start["seed"])).is_equal(1234)
	assert_str(start["impulse_pick"]).is_equal(String(offered[2].id))
	var debug: Dictionary = _last_event("debug")
	assert_str(debug["action"]).is_equal("set_seed")
	assert_str(debug["impulse_pick"]).is_equal(String(offered[2].id))
	screen._on_debug_seed(1234, true, "")
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_object(screen.run.impulse_pick).is_null()
	assert_int(screen.run.deck.size()).is_equal(13)


func test_the_debug_replay_refuses_a_card_not_in_the_offer() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_debug_seed(99, true, "repeat")
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_bool(screen._reward_panel.visible).is_true()
	var refused: Dictionary = _last_event("debug")
	assert_str(refused["action"]).is_equal("impulse_pick_refused")
	assert_str(refused["card"]).is_equal("repeat")


## The debug panel's choice: show the rack (the default), skip it, or a card id to replay.
func test_the_debug_panel_sends_the_rack_choice() -> void:
	var screen: ShiftScreen = await _screen()
	var panel: Control = screen._debug_panel
	var sent: Array = []
	panel.connect(
		&"seed_requested",
		func(seed_value: int, replays: bool, pick: String) -> void:
			sent.append([seed_value, replays, pick])
	)
	var choice: OptionButton = panel.get("_impulse_choice")
	var seed_input: SpinBox = panel.get("_seed_input")
	seed_input.value = 55
	panel.call("_on_seed_pressed")
	choice.select(1)
	panel.call("_on_seed_pressed")
	for index: int in range(choice.item_count):
		if choice.get_item_text(index) == "bread":
			choice.select(index)
	panel.call("_on_seed_pressed")
	assert_array(sent).is_equal([[55, false, ""], [55, true, ""], [55, true, "bread"]])


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for frame: int in range(4):
		await get_tree().process_frame
	return screen


static func _ids(cards: Array[CardDefinition]) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))


func _last_event(type: String) -> Dictionary:
	var events: Array = _events()
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


func _events() -> Array:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	return events


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
