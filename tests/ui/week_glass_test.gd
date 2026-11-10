extends GdUnitTestSuite
## The register's week glass on the real shift screen (v1.17, the user's pick of 2026-11-08: mock-up
## docs/art/mockups/main_scene_v2.html, option "7a"), at 1280x720 and 1920x1080: in the keypad's
## place on the key deck, inside the deck, the stage and the window, clear of CHECKOUT, Redraw and
## the seed line; its words (WEEK and N/4 only: the days-left line went on 2026-11-08) inside its
## glass, apart and centred on it; covering the keypad whole; hidden while Cancel stands in its
## place (redraw mode), the keypad hidden with it, and back after; the keypad shows for a run
## without weeks. Its tooltip names the week and tells the tap; a tap opens the time card
## (week_card_ui_test).

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


## On each day of week 1 the glass sits on the deck clear of the keys, its words inside and apart,
## WEEK over the number centred top to bottom on the inside (no days-left line).
func test_the_glass_sits_on_the_deck_and_centres_its_words() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var glass: WeekGlass = screen._stage.week_glass
		for shift_index: int in range(4):
			screen.run.debug_skip_to_shift(shift_index)
			screen.debug_show_shift()
			screen._week.skip()
			await _frames(2)
			var message: String = "shift %d at %s" % [shift_index + 1, window]
			assert_bool(glass.is_visible_in_tree()).override_failure_message(message).is_true()
			# The glass covers the keypad whole (the keypad stays under it for a run without weeks).
			var keypad: Rect2 = screen._stage.cabinet.keypad.get_global_rect()
			assert_bool(glass.get_global_rect().encloses(keypad)).is_true()
			_assert_on_deck(screen, message)
			# Only WEEK and N/4 (2026-11-08): the pair centred top to bottom on the inside.
			var words: Array[PixelWords] = []
			for child: Node in glass.get_children():
				if child is PixelWords:
					words.append(child as PixelWords)
			assert_int(words.size()).override_failure_message(message).is_equal(3)
			var top: float = glass.week_label.position.y
			var foot: float = glass.number_label.position.y + glass.number_label.size.y
			assert_float((top + foot) / 2.0).override_failure_message(message).is_equal_approx(
				WeekGlass.INSIDE_RECT.get_center().y, 2.0
			)
			assert_float(glass.week_label.position.y + glass.week_label.size.y).is_less(
				glass.number_label.position.y
			)
			assert_str(glass.tooltip_text).contains("Tap to open the time card")


## Redraw mode: Cancel stands in the glass's place, the glass and the keypad hide; leaving it
## brings the glass back.
func test_cancel_covers_the_glass() -> void:
	var screen: ShiftScreen = await _screen(Vector2(1280, 720))
	var glass: WeekGlass = screen._stage.week_glass
	var cabinet: RegisterCabinet = screen._stage.cabinet
	assert_bool(glass.visible).is_true()
	cabinet.cancel_key.visible = true
	assert_bool(glass.visible or cabinet.keypad.visible).is_false()
	assert_bool(glass.covered).is_true()
	cabinet.cancel_key.visible = false
	assert_bool(glass.visible).is_true()


## A run without weeks (WeekFlow.has_weeks false): no glass, the keypad shows. A run with weeks
## shows it even when it has one week and no week event (the time card still opens from it).
func test_a_run_without_weeks_shows_the_keypad() -> void:
	var glass: WeekGlass = auto_free(WeekGlass.new())
	add_child(glass)
	var model: WeekCardModel = WeekCardModel.new()
	model.week_count = 1
	glass.show_week(model, false)
	assert_bool(glass.visible).is_false()
	glass.show_week(model, true)
	assert_bool(glass.visible).is_true()
	assert_str(glass.count_label.text).is_empty()
	model.week_count = 4
	model.week_number = 2
	glass.show_week(model, true)
	assert_bool(glass.visible).is_true()
	assert_str(glass.count_label.text).is_equal("/4")
	assert_str(glass.number_label.text).is_equal("2")


func _assert_on_deck(screen: ShiftScreen, message: String) -> void:
	var glass: WeekGlass = screen._stage.week_glass
	var to_stage: Transform2D = screen._stage.get_global_transform()
	var box: Rect2 = glass.get_global_rect()
	var window: Rect2 = Rect2(Vector2.ZERO, screen.size)
	var deck: Rect2 = to_stage * ShiftStage.DECK_RECT
	assert_bool(deck.encloses(box)).override_failure_message(message).is_true()
	assert_bool(window.encloses(box)).override_failure_message(message).is_true()
	assert_bool(screen._stage.get_global_rect().encloses(box)).is_true()
	var cabinet: RegisterCabinet = screen._stage.cabinet
	var keys: Array[Control] = [cabinet.checkout_key, cabinet.redraw_key, cabinet.seed_label]
	for key: Control in keys:
		var apart: bool = not box.intersects(key.get_global_rect())
		assert_bool(apart).override_failure_message("%s: %s" % [message, key.name]).is_true()
	var inner: Rect2 = glass.get_global_transform() * WeekGlass.INSIDE_RECT
	var words: Array[PixelWords] = [glass.week_label, glass.number_label, glass.count_label]
	for index: int in range(words.size()):
		var rect: Rect2 = words[index].get_global_rect()
		var what: String = "%s: %s" % [message, words[index].text]
		assert_bool(inner.encloses(rect)).override_failure_message(what).is_true()
		for other: int in range(index + 1, words.size()):
			var apart: bool = not rect.intersects(words[other].get_global_rect())
			assert_bool(apart).override_failure_message(what).is_true()


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
