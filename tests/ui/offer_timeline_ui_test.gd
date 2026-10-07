extends GdUnitTestSuite
## The offers' presentation timelines on the real shift screen (plan section 8, since v0.20): the
## reward, upgrade and run_start events log presented_ms (the pop-in finished), armed_ms (the
## panel accepts clicks) and presentation_skipped beside decide_ms, all from the offer's show. The
## panels arm themselves; the choices are sent to the screen's handlers, because headless runs
## don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
## Bread, Multipack, Bread x4 = 27: passes the first two quotas.
const PASSING_ROW: Array[String] = ["bread", "multipack", "bread", "bread", "bread", "bread"]
## The panels' arming delay (RewardPanel, UpgradePanel), in wall-clock ms.
const ARMING_MS := 350
## A tween counts game time from the frame before it started, so in wall-clock time the pop-in
## can finish up to a frame early.
const FRAME_SLACK_MS := 50

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A passed shift's reward: fully shown after the pop-in, armed after 350 ms, both before the
## choice; phase 1 has no skippable presentation.
func test_the_reward_event_logs_the_presentation_timeline() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _pass_shift(screen)
	await _until_armed(screen._reward_panel)
	await _wall_ms(100)
	screen._on_reward_skipped()
	_assert_timeline(_last_event("reward"), "")


## The impulse rack's times are run_start's impulse_ fields. (A new run's rack: the first one shows
## while the scene loads, whose first frame is long.)
func test_run_start_logs_the_rack_timeline() -> void:
	var screen: ShiftScreen = await _screen()
	# Settle, so the frame the rack shows in follows a short one.
	await _wall_ms(300)
	await _frames(3)
	screen.start_new_run(screen.run.run_seed)
	await _until_armed(screen._reward_panel)
	await _wall_ms(100)
	screen._on_reward_skipped()
	_assert_timeline(_last_event("run_start"), "impulse_")


## The debug replay never shows the rack to the player: 0 / 0 / 0 / false, like a run without one.
func test_a_replayed_rack_logs_zero_times() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(screen.run.run_seed, true, "")
	var start: Dictionary = _last_event("run_start")
	assert_int(int(start["impulse_decide_ms"])).is_equal(0)
	assert_int(int(start["impulse_presented_ms"])).is_equal(0)
	assert_int(int(start["impulse_armed_ms"])).is_equal(0)
	assert_bool(start["impulse_presentation_skipped"]).is_false()


## The --demo-row run skips the rack in code like the replay's skip: 0 / 0 / 0 / false too.
func test_a_demo_row_logs_zero_rack_times() -> void:
	var screen: ShiftScreen = await _screen()
	await screen._debug.play_row(PackedStringArray(["bread", "bread"]))
	var start: Dictionary = _last_event("run_start")
	assert_int(int(start["impulse_decide_ms"])).is_equal(0)
	assert_int(int(start["impulse_presented_ms"])).is_equal(0)
	assert_int(int(start["impulse_armed_ms"])).is_equal(0)
	assert_bool(start["impulse_presentation_skipped"]).is_false()
	while screen._counting:
		await get_tree().process_frame


## A replayed pick that is refused leaves the rack to the player: their choice logs the rack's real
## times, not the replay's zeros.
func test_a_refused_replay_logs_the_rack_times() -> void:
	var screen: ShiftScreen = await _screen()
	await _wall_ms(300)
	await _frames(3)
	screen.start_new_run(screen.run.run_seed, true, "no_such_card")
	assert_str(_last_event("debug")["action"]).is_equal("impulse_pick_refused")
	assert_int(screen.run.phase).is_equal(RunState.Phase.IMPULSE)
	await _until_armed(screen._reward_panel)
	await _wall_ms(100)
	screen._on_reward_skipped()
	_assert_timeline(_last_event("run_start"), "impulse_")


## The top bar's Deck waits for the offer to arm, like the panel's own View deck, so the deck view
## never hides an offer before it accepts clicks (armed_ms stays the forced wait).
func test_the_top_bar_deck_waits_for_the_offer_to_arm() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	assert_bool(panel.is_arming()).is_true()
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_false()
	assert_bool(panel.visible).is_true()
	await _until_armed(panel)
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	assert_bool(panel.visible).is_false()
	screen._on_deck_closed()
	await _wall_ms(100)
	screen._on_reward_skipped()
	var reward: Dictionary = _last_event("reward")
	assert_int(int(reward["armed_ms"])).is_less(ARMING_MS + 1000)


## The upgrade tickets log the same timeline.
func test_the_upgrade_event_logs_the_presentation_timeline() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _pass_shift(screen)
	screen._on_reward_skipped()
	await _pass_shift(screen)
	screen._on_reward_skipped()
	assert_int(screen.run.phase).is_equal(RunState.Phase.UPGRADE)
	await _until_armed(screen._upgrade_panel)
	await _wall_ms(100)
	screen._upgrade_panel._on_ticket_clicked(screen._upgrade_panel.tickets()[0])
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	_assert_timeline(_last_event("upgrade"), "")


## An offer shown again after the deck view keeps its first presentation's times; decide_ms
## still runs from the first show.
func test_reopening_the_offer_after_the_deck_view_keeps_the_first_times() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	var timeline: OfferTimeline = panel.timeline
	var first: Dictionary = timeline.fields(Time.get_ticks_msec())
	screen._on_reward_deck_requested()
	assert_bool(panel.visible).is_false()
	await _wall_ms(150)
	screen._on_deck_closed()
	assert_bool(panel.visible).is_true()
	await _wall_ms(450)
	screen._on_reward_skipped()
	assert_object(panel.timeline).is_same(timeline)
	var reward: Dictionary = _last_event("reward")
	assert_bool(reward["deck_view_opened"]).is_true()
	assert_int(int(reward["presented_ms"])).is_equal(int(first["presented_ms"]))
	assert_int(int(reward["armed_ms"])).is_equal(int(first["armed_ms"]))
	assert_int(int(reward["decide_ms"])).is_greater_equal(int(first["armed_ms"]) + 600)


## presented_ms covers the pop-in, armed_ms the arming delay, both before decide_ms; nothing was
## skipped.
func _assert_timeline(event: Dictionary, prefix: String) -> void:
	assert_dict(event).is_not_empty()
	var pop_in_ms: int = roundi(UiKit.POP_IN_SECONDS * 1000.0 / Engine.time_scale) - FRAME_SLACK_MS
	var presented: int = int(event[prefix + "presented_ms"])
	var armed: int = int(event[prefix + "armed_ms"])
	var decided: int = int(event[prefix + "decide_ms"])
	assert_int(presented).is_greater_equal(pop_in_ms)
	assert_int(armed).is_greater_equal(ARMING_MS)
	assert_int(presented).is_less_equal(decided)
	assert_int(armed).is_less_equal(decided)
	assert_bool(event[prefix + "presentation_skipped"]).is_false()
	# JSON keeps them as numbers and a bool.
	assert_int(typeof(event[prefix + "presented_ms"])).is_equal(TYPE_FLOAT)
	assert_int(typeof(event[prefix + "presentation_skipped"])).is_equal(TYPE_BOOL)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


func _pass_shift(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)


## Waits until the panel accepts clicks (a generous wall-clock limit).
func _until_armed(panel: Control) -> void:
	var start: int = Time.get_ticks_msec()
	while not panel.get("_armed") and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(panel.get("_armed")).is_true()


func _wall_ms(ms: int) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
