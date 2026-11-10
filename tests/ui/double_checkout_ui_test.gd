extends GdUnitTestSuite
## The Double checkout on the real screen (#122 part 2: DoubleCheckoutFlow). With the pin worn the
## belt has the pin's 4 slots and the receipt's header says ROW 1 OF 2. Row 1's CHECKOUT counts
## row 1 (logged as row_checkout and saved) but stops before the total: no verdict, the run still
## planning, the belt empty for row 2, the hand refilled, and the header says row 1's amount. Row
## 2's preview and gauge count on from row 1's total, and row 2's CHECKOUT ends the shift on both
## rows (one record and one checkout event naming all their cards). The real saves and logs are
## never touched. What shows the two rows: the belt fitted to the 4 cells, "CHECKOUT 1/2" then
## "2/2" on the key, the gauge's pips (the first gold after row 1) and the ROW 2 banner over the
## belt after row 1's count.

const SCREEN := "res://ui/shift_screen.tscn"
const DOUBLE := "res://data/pins/double_checkout.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_two_rows_make_one_shift() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	assert_int(screen._slots.size()).is_equal(4)
	assert_bool(_receipt_text(screen).contains(DoubleCheckoutFlow.ROW_ONE_TEXT)).is_true()
	var stage: ShiftStage = screen._stage
	assert_int(stage.belt.cell_count()).is_equal(4)
	assert_float(stage.bonus_lights.belt_cut).is_equal(BeltPanel.cut_of(4))
	assert_float(stage.quota_light.belt_cut).is_equal(BeltPanel.cut_of(4))
	assert_str(_checkout_caption(screen)).is_equal("CHECKOUT 1/2")
	var pips: RowPips = screen._stage.row_pips
	assert_bool(pips.is_visible_in_tree()).is_true()
	assert_int(pips.done_count()).is_equal(0)
	var row_one: Array[CardInstance] = await _place(screen, 4)
	await Rush.checkout(screen)
	await _frames(2)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._counting).is_false()
	assert_array(run.first_row).is_equal(row_one)
	assert_array(run.row).is_empty()
	assert_array(screen._row_views).is_empty()
	assert_int(screen._hand_box.cards().size()).is_equal(run.hand().size())
	assert_array(run.history).is_empty()
	assert_str(_checkout_caption(screen)).is_equal("CHECKOUT 2/2")
	assert_int(pips.done_count()).is_equal(1)
	var banner: Label = stage.get_node_or_null(NodePath(DoubleCheckoutFlow.BANNER_NAME))
	assert_object(banner).is_not_null()
	var belt_rect: Rect2 = Rect2(stage.belt.global_position, stage.belt.size)
	belt_rect.size.x -= stage.belt.cut()
	assert_float(banner.get_global_rect().get_center().x).is_equal_approx(
		belt_rect.get_center().x, 2.0
	)
	assert_bool(belt_rect.encloses(banner.get_global_rect())).is_true()
	var event: Dictionary = _last_event("row_checkout")
	assert_int(int(event["score"])).is_equal(run.first_result.total)
	assert_object(_last_event("checkout").get("score")).is_null()
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(run.balance))
	assert_int(saved.run.first_row.size()).is_equal(4)
	var amount: String = ReceiptView.money(run.first_result.total)
	var header: String = DoubleCheckoutFlow.ROW_TWO_TEXT % amount
	assert_bool(_receipt_text(screen).contains(header)).is_true()
	# Row 2's preview counts on from row 1's total.
	var row_two: Array[CardInstance] = await _place(screen, 2)
	var preview: ScoreResult = DoubleCheckoutFlow.on_from_row_one(run, run.preview())
	assert_int(preview.total).is_equal(run.first_result.total + run.preview().total)
	var first_total: int = run.first_result.total
	var second_total: int = run.preview().total
	await Rush.checkout(screen)
	# A miss in the training week is a slip: the next shift may have started already.
	assert_int(run.history.size()).is_equal(1)
	assert_int(run.history[0].total).is_equal(first_total + second_total)
	var checkout: Dictionary = _last_event("checkout")
	assert_int(int(checkout["score"])).is_equal(first_total + second_total)
	assert_int((checkout["final_order"] as Array).size()).is_equal(row_one.size() + row_two.size())
	assert_int(screen._count_up.plan.start_total).is_equal(first_total)


## Row 1's CHECKOUT plays no medal prelude (MedalPrelude, 2026-11-09), even making three times
## the target alone: the gauge runs no laps, no medal leaves its socket and the paper stays plain;
## the medals wait for row 2, the shift's own checkout.
func test_row_one_has_no_medal_prelude() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	run.limits.quota = 1
	screen._refresh()
	await _place(screen, 4)
	assert_int(run.preview().total).is_greater_equal(3)
	var steps: Array[int] = []
	screen._stage.gauge_panel.lap_run_step.connect(func(laps: int) -> void: steps.append(laps))
	var medals: Array[int] = screen._stage.medal_case.states()
	await Rush.checkout(screen)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(steps).is_empty()
	assert_bool(screen._stage.medal_prelude.is_playing()).is_false()
	assert_array(screen._stage.medal_case.states()).is_equal(medals)
	assert_bool(screen._receipt.gold.is_gold() or screen._receipt.gold.is_silver()).is_false()


static func _checkout_caption(screen: ShiftScreen) -> String:
	return screen._cabinet.checkout_key.caption_label().text


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	RunPins.wear(screen.run, [load(DOUBLE)])
	screen.run.start_shift()
	screen._refresh()
	await _frames(2)
	return screen


## Places the first `count` hand items on the belt, as the player would.
func _place(screen: ShiftScreen, count: int) -> Array[CardInstance]:
	var placed: Array[CardInstance] = []
	for card: CardInstance in screen.run.hand():
		if placed.size() == count:
			break
		if screen.run.place(card, screen.run.row.size()):
			placed.append(card)
	screen._refresh()
	await _frames(2)
	return placed


static func _receipt_text(screen: ShiftScreen) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return "\n".join(texts)


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
