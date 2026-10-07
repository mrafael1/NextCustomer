extends GdUnitTestSuite
## Save and resume on the real shift screen (full build plan section 4): run.json is written at
## every save point and deleted when the run ends; a new screen over the same save folder
## resumes the same state (with its panel laid out on screen) and logs run_resume under the
## saved run id; an unreadable save is reported, backed up and replaced by a new run. Clicks are
## sent to the screen's handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
## Bread, Multipack, Bread x4 = 27: passes the first two quotas.
const PASSING_ROW: Array[String] = ["bread", "multipack", "bread", "bread", "bread", "bread"]

var _folder: String = ""
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_errors = []
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Every save point writes run.json: the rack shown, the shift's start, each place, remove and
## redraw, the checkout click (so the reward waits even during the count-up), the reward pick,
## the upgrade tickets and the upgrade pick. The checkout click that ends the run deletes it.
func test_the_screen_saves_at_every_save_point_and_deletes_the_save_at_the_end() -> void:
	var screen: ShiftScreen = await _screen()
	assert_str(_saved()["phase"]).is_equal("impulse_rack")
	assert_str(_saved()["run_id"]).is_equal(_event_log().run_id)
	screen._on_reward_skipped()
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_array(_ints(_saved()["draw_pile"])).is_equal(_instance_ids(screen.run.deck.draw_pile()))
	var hand: Array[CardInstance] = screen.run.hand()
	screen._on_hand_card_clicked(_view_for(screen, hand[0]))
	screen._on_slot_input(_left_click(), 0)
	assert_array(_ints(_saved()["row"])).is_equal([hand[0].instance_id])
	screen._on_row_card_clicked(screen._row_views[0])
	assert_array(_saved()["row"]).is_empty()
	screen._on_background_input(_left_click())
	screen._on_redraw_pressed()
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[7]))
	screen._on_redraw_pressed()
	assert_int(int(_saved()["redraws_used"])).is_equal(1)
	assert_array(_hand_ids(_saved())).is_equal(_instance_ids(screen.run.deck.hand()))
	_place_ids(screen, PASSING_ROW)
	assert_int((_saved()["row"] as Array).size()).is_equal(6)

	screen._on_checkout_pressed()
	assert_bool(screen._counting).is_true()
	assert_str(_saved()["phase"]).is_equal("reward")
	await _count_up_end(screen)
	screen._on_reward_skipped()
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_int(int(_saved()["shift_index"])).is_equal(1)
	_place_ids(screen, PASSING_ROW)
	await screen._on_checkout_pressed()
	screen._on_reward_skipped()
	assert_int(screen.run.phase).is_equal(RunState.Phase.UPGRADE)
	assert_str(_saved()["phase"]).is_equal("upgrade")
	var upgrade: UpgradeDefinition = screen.run.upgrade_offer[0]
	screen._on_upgrade_picked(upgrade)
	assert_str(_saved()["phase"]).is_equal("planning")
	assert_array(_saved()["upgrades"]).is_equal([String(upgrade.id)])

	# An empty row loses shift 3: the run ends at the click and its save is gone.
	screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	await _count_up_end(screen)
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	assert_array(_errors).is_empty()


## A resumed planning shift has the same hand, the same row in order and the same redraw used,
## logs run_resume (and no shift_start) under the saved run id, and continues exactly as the
## run would have.
func test_a_new_screen_resumes_the_hand_the_row_and_the_redraws() -> void:
	var first: ShiftScreen = await _screen()
	first._on_reward_skipped()
	var replaced: Array[CardInstance] = first.run.hand().slice(6)
	first._on_redraw_pressed()
	for card: CardInstance in replaced:
		first._on_hand_card_clicked(_view_for(first, card))
	first._on_redraw_pressed()
	var hand: Array[CardInstance] = first.run.hand()
	first._on_hand_card_clicked(_view_for(first, hand[0]))
	first._on_slot_input(_left_click(), 0)
	first._on_hand_card_clicked(_view_for(first, hand[1]))
	first._on_slot_input(_left_click(), 0)
	var run_id: String = _event_log().run_id

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(_cards(resumed.run.deck.hand())).is_equal(_cards(first.run.deck.hand()))
	assert_array(_cards(resumed.run.row)).is_equal(_cards([hand[1], hand[0]]))
	assert_array(_cards(resumed.run.deck.draw_pile())).is_equal(_cards(first.run.deck.draw_pile()))
	assert_int(resumed.run.redraws_used).is_equal(1)
	assert_bool(resumed._redraw_button.disabled).is_true()
	assert_int(resumed._row_views.size()).is_equal(2)
	assert_int(_hand_views(resumed).size()).is_equal(resumed.run.hand().size())
	assert_bool(resumed._reward_panel.visible).is_false()
	assert_str(resumed._projected_label.text).is_equal("Projected €%d" % first.run.preview().total)
	assert_str(_event_log().run_id).is_equal(run_id)
	var resume: Dictionary = _last_event("run_resume")
	assert_str(resume["run_id"]).is_equal(run_id)
	assert_int(int(resume["shift"])).is_equal(1)
	assert_str(resume["phase"]).is_equal("planning")
	assert_int(int(resume["run_ms"])).is_greater_equal(0)
	var types: Array = _events().map(func(event: Dictionary) -> String: return event["type"])
	assert_array(types.slice(types.rfind("run_resume") + 1)).is_empty()

	# The same checkout, the same offer and the same next hand.
	assert_int(resumed.run.checkout().total).is_equal(first.run.checkout().total)
	assert_array(_ids(resumed.run.offer)).is_equal(_ids(first.run.offer))
	assert_array(_errors).is_empty()


## Quitting during the count-up loses nothing: the save was written at the click, so a new
## screen opens on the reward panel, laid out inside the screen, and continues like the first.
func test_quitting_during_the_count_up_resumes_on_the_reward_panel() -> void:
	var first: ShiftScreen = await _screen()
	first._on_reward_skipped()
	_place_ids(first, PASSING_ROW)
	first._on_checkout_pressed()
	assert_bool(first._counting).is_true()

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.REWARD)
	assert_int(resumed.run.last_result.total).is_equal(first.run.last_result.total)
	assert_str(resumed._subtotal_label.text).is_equal("€%d" % first.run.last_result.total)
	assert_str(_last_event("run_resume")["phase"]).is_equal("reward")
	assert_bool(resumed._reward_panel.visible).is_true()
	assert_bool(resumed._shade.visible).is_true()
	assert_str(resumed._reward_panel._headline.text).contains("Shift passed")
	var views: Array[Node] = resumed._reward_panel._cards.get_children()
	assert_array(_offer_ids(resumed)).is_equal(_ids(first.run.offer))
	await _assert_on_screen(resumed, resumed._reward_panel)
	var panel: Rect2 = resumed._reward_panel.get_global_rect()
	for view: Node in views:
		assert_bool(panel.encloses((view as CardView).get_global_rect())).is_true()
	assert_bool(panel.encloses(resumed._reward_panel._skip_button.get_global_rect())).is_true()

	await _count_up_end(first)
	# The receipt and totals behind the panel, as the count-up left them.
	assert_array(_receipt_lines(resumed)).is_equal(_receipt_lines(first))
	assert_str(resumed._projected_label.text).is_equal(first._projected_label.text)
	first._on_reward_skipped()
	resumed._on_reward_skipped()
	assert_int(resumed.run.shift_index).is_equal(1)
	assert_array(_cards(resumed.run.hand())).is_equal(_cards(first.run.hand()))
	assert_array(_errors).is_empty()


## The exit kiosk resumes with its tickets on screen and the next shift's inspection kept.
func test_a_new_screen_resumes_the_upgrade_tickets() -> void:
	var first: ShiftScreen = await _screen()
	first._on_reward_skipped()
	for shift: int in range(2):
		_place_ids(first, PASSING_ROW)
		await first._on_checkout_pressed()
		first._on_reward_skipped()
	assert_int(first.run.phase).is_equal(RunState.Phase.UPGRADE)

	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.UPGRADE)
	assert_str(_last_event("run_resume")["phase"]).is_equal("upgrade")
	assert_int(int(_last_event("run_resume")["shift"])).is_equal(2)
	assert_bool(resumed._upgrade_panel.visible).is_true()
	assert_bool(resumed._reward_panel.visible).is_false()
	var tickets: Array[UpgradeTicket] = resumed._upgrade_panel.tickets()
	var shown: Array = tickets.map(
		func(ticket: UpgradeTicket) -> String: return String(ticket.upgrade.id)
	)
	assert_array(shown).is_equal(_upgrade_ids(first.run.upgrade_offer))
	await _frames(3)
	await _assert_on_screen(resumed, resumed._upgrade_panel)
	var panel: Rect2 = resumed._upgrade_panel.get_global_rect()
	assert_float(panel.size.y).is_less_equal(resumed._upgrade_panel.get_combined_minimum_size().y)
	for ticket: UpgradeTicket in tickets:
		assert_bool(panel.encloses(ticket.get_global_rect())).is_true()
	assert_object(resumed.run.next_inspection).is_same(first.run.next_inspection)
	# The receipt behind the tickets still announces the next shift's inspection, and the totals
	# are the ones the count-up left.
	var notice: String = InspectionTag.next_notice(resumed.run.next_inspection)
	assert_str(notice).is_not_empty()
	assert_bool(_receipt_lines(resumed).has(notice)).is_true()
	assert_array(_receipt_lines(resumed)).is_equal(_receipt_lines(first))
	assert_str(resumed._projected_label.text).is_equal(first._projected_label.text)
	assert_str(resumed._projected_label.text).is_not_empty()

	var upgrade: UpgradeDefinition = first.run.upgrade_offer[0]
	first._on_upgrade_picked(upgrade)
	resumed._on_upgrade_picked(upgrade)
	assert_int(resumed.run.shift_index).is_equal(2)
	assert_array(_cards(resumed.run.hand())).is_equal(_cards(first.run.hand()))
	assert_array(_upgrade_ids(resumed.run.upgrades)).is_equal([String(upgrade.id)])
	assert_object(resumed.run.inspections[0]).is_same(first.run.inspections[0])
	assert_array(_errors).is_empty()


## A run saved before its impulse-rack choice resumes on the rack; run_start then logs under
## the saved run id.
func test_a_new_screen_resumes_the_impulse_rack() -> void:
	var first: ShiftScreen = await _screen()
	var run_id: String = _event_log().run_id
	var resumed: ShiftScreen = await _screen()
	assert_int(resumed.run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_str(_last_event("run_resume")["phase"]).is_equal("impulse_rack")
	assert_bool(resumed._reward_panel.visible).is_true()
	assert_str(resumed._reward_panel._headline.text).contains("Impulse rack")
	assert_array(_offer_ids(resumed)).is_equal(_ids(first.run.impulse_offer))
	await _assert_on_screen(resumed, resumed._reward_panel)
	resumed._on_reward_picked(resumed.run.impulse_offer[1])
	var start: Dictionary = _last_event("run_start")
	assert_str(start["run_id"]).is_equal(run_id)
	assert_str(start["impulse_pick"]).is_equal(String(first.run.impulse_offer[1].id))
	assert_array(_errors).is_empty()


## A resumed run counts only played time: run_resume carries the saved run_ms, and run_end's
## run_ms continues from it under the saved run id.
func test_a_resumed_run_keeps_its_run_id_and_played_time() -> void:
	var first: ShiftScreen = await _screen()
	first._on_reward_skipped()
	assert_bool(SaveService.new(_folder).save_run(first.run, "feedc0de12345678", 600000)).is_true()
	var resumed: ShiftScreen = await _screen()
	var resume: Dictionary = _last_event("run_resume")
	assert_str(resume["run_id"]).is_equal("feedc0de12345678")
	assert_int(int(resume["run_ms"])).is_equal(600000)
	await resumed._on_checkout_pressed()
	var run_end: Dictionary = _last_event("run_end")
	assert_str(run_end["run_id"]).is_equal("feedc0de12345678")
	assert_int(int(run_end["run_ms"])).is_between(600000, 660000)
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	assert_array(_errors).is_empty()


## An unreadable run save is reported (to the screen's reporter: nothing prints), kept as
## run.json.bad, and a new run starts; its first save point writes over it.
func test_an_unreadable_run_save_is_backed_up_and_a_new_run_starts() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var file: FileAccess = FileAccess.open(_run_file(), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var screen: ShiftScreen = await _screen()
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).contains("can't read")
	var backup: String = _run_file() + SaveService.BACKUP_SUFFIX
	assert_str(FileAccess.get_file_as_string(backup)).is_equal("{broken")
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	assert_bool(screen._reward_panel.visible).is_true()
	assert_dict(_last_event("run_resume")).is_empty()
	var lookup: ContentLookup = ContentLookup.new(load(BALANCE))
	var saved: RunSave = SaveService.new(_folder).peek_run(lookup)
	assert_object(saved).is_not_null()
	assert_str(saved.run_id).is_equal(_event_log().run_id)


## A run started without saving (the --demo-row run) never writes or deletes the run save, so
## the run in progress survives a demo session. A new run started as usual saves again.
func test_a_run_that_doesnt_save_leaves_the_run_save_untouched() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()
	var kept: String = FileAccess.get_file_as_string(_run_file())
	screen.start_new_run(77, false, "", false)
	screen._on_reward_skipped()
	_place_ids(screen, PASSING_ROW)
	await screen._on_checkout_pressed()
	screen._on_reward_skipped()
	# An empty row loses shift 2: the run ends without deleting the save.
	screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	await _count_up_end(screen)
	assert_str(FileAccess.get_file_as_string(_run_file())).is_equal(kept)
	screen._on_new_run_pressed()
	assert_str(_saved()["run_id"]).is_equal(_event_log().run_id)
	assert_str(FileAccess.get_file_as_string(_run_file())).is_not_equal(kept)
	assert_array(_errors).is_empty()


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	screen.report_error = _record_error
	scene_runner(screen)
	await _frames(4)
	return screen


func _record_error(message: String) -> void:
	_errors.append(message)


## The panel is visible, fits the window and sits inside the screen once laid out.
func _assert_on_screen(screen: ShiftScreen, panel: Control) -> void:
	await _frames(4)
	await get_tree().create_timer(0.3).timeout
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var rect: Rect2 = panel.get_global_rect()
	assert_bool(panel.is_visible_in_tree()).is_true()
	assert_float(rect.size.x).is_greater(100.0)
	assert_float(rect.size.x).is_less_equal(width)
	assert_float(rect.size.y).is_less_equal(height)
	assert_bool(screen.get_global_rect().encloses(rect)).is_true()


func _count_up_end(screen: ShiftScreen) -> void:
	while screen._counting:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


## Adds the cards to the hand through the debug tools and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


func _run_file() -> String:
	return _folder.path_join(SaveService.RUN_FILE)


## The run save as written.
func _saved() -> Dictionary:
	if not FileAccess.file_exists(_run_file()):
		return {}
	var json: JSON = JSON.new()
	json.parse(FileAccess.get_file_as_string(_run_file()))
	return json.data


## The receipt's labels in order (a line's left text, then its right text).
static func _receipt_lines(screen: ShiftScreen) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append((label as Label).text)
	return texts


static func _offer_ids(screen: ShiftScreen) -> Array:
	var ids: Array = []
	for view: Node in screen._reward_panel._cards.get_children():
		if not view.is_queued_for_deletion():
			ids.append(String((view as CardView).card.definition.id))
	return ids


static func _hand_views(screen: ShiftScreen) -> Array[CardView]:
	var views: Array[CardView] = []
	for child: Node in screen._hand_box.get_children():
		if child is CardView and not child.is_queued_for_deletion():
			views.append(child)
	return views


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: CardView in _hand_views(screen):
		if view.card == card:
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


## "instance id:card id" for each card, in order.
static func _cards(cards: Array[CardInstance]) -> Array:
	return cards.map(
		func(card: CardInstance) -> String: return "%d:%s" % [card.instance_id, card.definition.id]
	)


static func _instance_ids(cards: Array[CardInstance]) -> Array:
	return cards.map(func(card: CardInstance) -> int: return card.instance_id)


static func _hand_ids(saved: Dictionary) -> Array:
	return (saved["hand"] as Array).map(func(pair: Array) -> int: return int(pair[0]))


static func _ints(values: Array) -> Array:
	return values.map(func(value: Variant) -> int: return int(value))


static func _ids(cards: Array[CardDefinition]) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))


static func _upgrade_ids(upgrades: Array[UpgradeDefinition]) -> Array:
	return upgrades.map(func(upgrade: UpgradeDefinition) -> String: return String(upgrade.id))


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
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
