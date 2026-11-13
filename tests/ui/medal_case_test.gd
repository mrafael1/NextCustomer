extends GdUnitTestSuite
## The register's medal case on the real shift screen (v1.17, the user's pick of 2026-11-08:
## mock-up docs/art/mockups/main_scene_v2.html, "MEDAL CASE"), at 1280x720 and 1920x1080: on the
## cash drawer's front, inside the drawer, the stage and the window, clear of the quota gauge, the
## receipt and the key deck; each medal's ribbon, medal, name and line inside it and the two medals
## apart; the lines read the totals that win them ("at <2x quota>€", "at <3x quota>€"); a medal
## won leaves its socket and "WON ✓"; the medals take their tooltips, no clicks; the case's
## medals are drawn on whole art pixels.

const SCREEN := "res://ui/shift_screen.tscn"

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


## The case on the drawer, clear of its neighbours, its parts inside and apart, its thresholds the
## quota's laps; then the SILVER won: "WON ✓" in the same room.
func test_the_case_sits_on_the_drawer() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var medals: MedalCase = screen._stage.medal_case
		var run: RunState = screen.run
		var silver: int = WeekMedals.threshold_of(run, false)
		var gold: int = WeekMedals.threshold_of(run, true)
		var machine: MachineDefinition = WeekMedals.machine_data(run)
		assert_int(silver).is_equal(run.quota() * WeekMedals.laps_of(machine, false))
		assert_int(gold).is_equal(run.quota() * WeekMedals.laps_of(machine, true))
		assert_int(gold).is_greater(silver)
		assert_str(medals.line_text(false)).is_equal(MedalCase.THRESHOLD_TEXT % silver)
		assert_str(medals.line_text(true)).is_equal(MedalCase.THRESHOLD_TEXT % gold)
		var message: String = "at %s" % window
		await _frames(1)
		_assert_on_drawer(screen, message)
		medals.launch(false)
		await _frames(1)
		assert_str(medals.line_text(false)).is_equal("WON ✓")
		_assert_on_drawer(screen, "won " + message)


## The medals and their words show their tooltips; elsewhere the case takes no mouse.
func test_the_case_takes_the_mouse_on_its_medals_only() -> void:
	var screen: ShiftScreen = await _screen(Vector2(1280, 720))
	var medals: MedalCase = screen._stage.medal_case
	for gold: bool in [false, true]:
		var parts: Dictionary = medals.parts(gold)
		for key: String in ["medal", "name", "line"]:
			var point: Vector2 = (parts[key] as Rect2).get_center()
			assert_bool(medals._has_point(point)).override_failure_message(key).is_true()
			assert_str(medals.tip_at(point)).is_not_empty()
	assert_bool(medals._has_point(Vector2(2, 2))).is_false()
	assert_bool(medals._has_point(Vector2(medals.size.x - 4, medals.size.y / 2.0))).is_false()


## Every medal pixel lands on whole art pixels of the case (2 stage px, so whole screen pixels at
## 1920x1080's 1.5x): the medals' and ribbons' corners and sizes are whole cells.
func test_the_medals_lie_on_whole_art_pixels() -> void:
	for gold: bool in [false, true]:
		var index: int = 1 if gold else 0
		for rect: Rect2 in [
			MedalCase.RIBBON_RECTS[index],
			Rect2(MedalCase.MEDAL_AT[index], Vector2.ONE * MedalArt.SIZE * MedalCase.CELL)
		]:
			var cells: Rect2 = Rect2(rect.position / MedalCase.CELL, rect.size / MedalCase.CELL)
			assert_vector(cells.position).is_equal(cells.position.round())
			assert_vector(cells.size).is_equal(cells.size.round())
	assert_float(fmod(ShiftStage.DRAWER_RECT.position.x, 2.0)).is_equal(0.0)
	assert_float(fmod(ShiftStage.DRAWER_RECT.position.y, 2.0)).is_equal(0.0)


func _assert_on_drawer(screen: ShiftScreen, message: String) -> void:
	var medals: MedalCase = screen._stage.medal_case
	var to_stage: Transform2D = screen._stage.get_global_transform()
	var drawer: Rect2 = to_stage * ShiftStage.DRAWER_RECT
	var window: Rect2 = Rect2(Vector2.ZERO, screen.size)
	var to_global: Transform2D = medals.get_global_transform()
	var neighbours: Array[Rect2] = [
		screen._stage.quota_meter.get_global_rect(),
		screen._stage.receipt.get_global_rect(),
		to_stage * ShiftStage.DECK_RECT,
	]
	var shown: Array[Rect2] = []
	for gold: bool in [false, true]:
		var parts: Dictionary = medals.parts(gold)
		var medal: Array[Rect2] = []
		for key: String in ["ribbon", "medal", "name", "line"]:
			var rect: Rect2 = to_global * (parts[key] as Rect2)
			var what: String = "%s: %s %s" % [message, "gold" if gold else "silver", key]
			assert_bool(rect.has_area()).override_failure_message(what).is_true()
			assert_bool(drawer.encloses(rect)).override_failure_message(what).is_true()
			assert_bool(window.encloses(rect)).override_failure_message(what).is_true()
			for other: Rect2 in neighbours:
				assert_bool(rect.intersects(other)).override_failure_message(what).is_false()
			medal.append(rect)
		# The name and the line apart, both right of the medal.
		assert_bool(medal[2].intersects(medal[3])).override_failure_message(message).is_false()
		assert_float(medal[2].position.x).is_greater_equal(medal[1].end.x)
		assert_float(medal[3].position.x).is_greater_equal(medal[1].end.x)
		var whole: Rect2 = medal[0].merge(medal[1]).merge(medal[2]).merge(medal[3])
		for other: Rect2 in shown:
			assert_bool(whole.intersects(other)).override_failure_message(message).is_false()
		shown.append(whole)


func _screen(window: Vector2) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
