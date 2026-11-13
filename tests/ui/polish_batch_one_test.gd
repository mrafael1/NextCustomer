extends GdUnitTestSuite
## Polish audit batch 1 (2026-11-13, v1.36), at 1280x720 and 1920x1080: release gating of the
## playtest UI (PlaytestUi: the title's export icon and build label, the LOYAL "SOON" poster, the
## shift's seed line, the pause's EXPORT LOG and the shift menu's entry hide in a release build and
## show in a playtest one); the pause column on its board (nothing of the shift between the plates,
## the note and the link on it, the sign's rods from the board's rail); QUIT GAME? and ABANDON
## THIS RUN? as twins (the same plates at the same places, open on the safe key, QUIT's empty line
## folded away); the OPTIONS sheet's fixes; the toy machines' NO COINS YET. The real saves and logs
## are never touched.

const TITLE := "res://ui/title_screen.tscn"
const SHIFT := "res://ui/shift_screen.tscn"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window = get_tree().root.size


func after_test() -> void:
	PlaytestUi.forced = -1
	get_tree().paused = false
	get_tree().root.size = _window
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Debug runs (these tests) count as playtest builds; the presets' `playtest` tag keeps the
## exports' log export.
func test_debug_runs_and_the_presets_tag_show_the_playtest_ui() -> void:
	assert_bool(PlaytestUi.shown()).is_true()
	PlaytestUi.forced = 0
	assert_bool(PlaytestUi.shown()).is_false()
	PlaytestUi.forced = 1
	assert_bool(PlaytestUi.shown()).is_true()
	var presets: ConfigFile = ConfigFile.new()
	assert_int(presets.load("res://export_presets.cfg")).is_equal(OK)
	for section: String in ["preset.0", "preset.1"]:
		var features: String = str(presets.get_value(section, "custom_features", ""))
		assert_str(features).contains(PlaytestUi.FEATURE)


## The title's corner (export icon, build label) and the bay's SOON poster: shown in a playtest
## build, gone in a release one.
func test_the_title_hides_the_playtest_corner_and_the_poster_in_release() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		for playtest: int in [1, 0]:
			PlaytestUi.forced = playtest
			var title: TitleScreen = await _title()
			assert_bool(title.export_button().visible).is_equal(playtest == 1)
			assert_bool(title.build_label().visible).is_equal(playtest == 1)
	PlaytestUi.forced = 1
	var with_poster: Image = StorefrontArt.layer("bay_lit").get_image()
	PlaytestUi.forced = 0
	var without: Image = StorefrontArt.layer("bay_lit").get_image()
	assert_bool(with_poster.get_data() == without.get_data()).is_false()
	# The poster's place (bay art px 6..30, 32..64) is bare glass in the release bay.
	var poster: Rect2i = Rect2i(7, 33, 22, 30)
	var colours: Dictionary = {}
	for y: int in range(poster.position.y, poster.end.y):
		for x: int in range(poster.position.x, poster.end.x):
			colours[without.get_pixel(x, y)] = true
	assert_bool(colours.has(Palette.TOMATO)).is_false()
	assert_bool(colours.has(Palette.CREAM)).is_false()


## The shift: the seed line carries the build label, the pause its EXPORT LOG link and the menu
## its export entry, in a playtest build only.
func test_the_shift_hides_the_exports_and_the_build_label_in_release() -> void:
	var label: String = str(ProjectSettings.get_setting("next_customer/build_label", ""))
	for playtest: int in [1, 0]:
		PlaytestUi.forced = playtest
		var screen: ShiftScreen = await _shift()
		assert_bool(screen._seed_label.text.contains(label)).is_equal(playtest == 1)
		assert_str(screen._seed_label.text).starts_with("Seed ")
		assert_bool(screen._pause.pause.export_link().visible).is_equal(playtest == 1)
		assert_bool((screen._top_bar as TopBar).export_button.visible).is_equal(playtest == 1)
		assert_str(TopBar.EXPORT_TEXT).is_equal(PauseMenu.EXPORT_TEXT)


## The pause column stands on its board at both sizes: the sign, every plate, the note (two
## lines) and the link on it; the board clear of the register column and the CHECKOUT key and
## under the top bar; the sign's rods start at the board's rail; every plate's face at one left
## edge at rest. A release build's board ends under the note.
func test_the_pause_column_stands_on_its_board() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		for playtest: int in [1, 0]:
			PlaytestUi.forced = playtest
			var screen: ShiftScreen = await _shift()
			var pause: PauseMenu = screen._pause.pause
			pause.still = true
			screen._pause.open()
			await _frames(2)
			var case: String = "%s playtest %d" % [window, playtest]
			var board: Rect2 = pause.board_rect()
			var visible_rect: Rect2 = Rect2(Vector2.ZERO, pause.size)
			assert_bool(visible_rect.encloses(board)).override_failure_message(case).is_true()
			assert_float(board.position.y).is_equal(PauseMenu.BOARD_TOP)
			var key: Rect2 = screen._checkout_button.get_global_rect()
			assert_bool(board.intersects(key)).override_failure_message(case).is_false()
			assert_float(board.position.x).is_greater_equal(PauseMenu.REGISTER_COLUMN)
			var sign_rect: Rect2 = pause.lane_sign().get_global_rect()
			assert_bool(board.encloses(sign_rect)).override_failure_message(case).is_true()
			assert_float(pause.lane_sign().rail_y).is_equal(
				PauseMenu.BOARD_TOP + PauseMenu.BOARD_RAIL
			)
			var lefts: Array[float] = []
			for entry: int in PauseMenu.Entry.size():
				var plate: MenuPlate = pause.plate(entry as PauseMenu.Entry)
				var rect: Rect2 = plate.get_global_rect()
				assert_bool(board.encloses(rect)).override_failure_message(case).is_true()
				lefts.append(plate.global_position.x)
				assert_float(rect.position.y).is_greater_equal(sign_rect.end.y)
			for left: float in lefts:
				assert_float(left).is_equal(lefts[0])
			var note: Label = pause.note_label()
			var note_rect: Rect2 = Rect2(
				note.global_position, Vector2(note.size.x, 2.0 * note.get_line_height())
			)
			assert_bool(board.encloses(note_rect)).override_failure_message(case).is_true()
			var link: Control = pause.export_link()
			if playtest == 1:
				assert_bool(board.encloses(link.get_global_rect())).is_true()
				assert_float(link.get_global_rect().position.y).is_greater_equal(note_rect.end.y)
			else:
				assert_float(board.end.y - note_rect.end.y).is_less(PauseMenu.LINK_HEIGHT)
			screen._pause.close()


## QUIT GAME? and ABANDON THIS RUN? are twins: the primary plate and the safe plate at the same
## places and sizes, opening with the marker on the safe one (STAY, KEEP) and its tick between
## the plates; QUIT / STAY; with no run saved QUIT's line folds away and its sheet is shorter,
## the plates moved up with it.
func test_the_quit_and_abandon_questions_are_twins() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var title: TitleScreen = await _title()
		var quit: QuitConfirm = title.quit_confirm()
		quit.still = true
		var abandon: AbandonConfirm = AbandonConfirm.new()
		abandon.still = true
		title.add_child(abandon)
		abandon.open("SHIFT 3/16 WILL BE LOST")
		quit.open(true)
		await _frames(2)
		assert_str(quit.yes_plate().caption).is_equal(QuitConfirm.QUIT_TEXT)
		assert_str(quit.no_plate().caption).is_equal(QuitConfirm.STAY_TEXT)
		assert_bool(quit.no_plate().marked).is_true()
		assert_bool(abandon.keep_plate().marked).is_true()
		var pairs: Array = [
			[quit.yes_plate(), abandon.abandon_plate()], [quit.no_plate(), abandon.keep_plate()]
		]
		for pair: Array in pairs:
			var a: MenuPlate = pair[0]
			var b: MenuPlate = pair[1]
			assert_vector(a.position).is_equal(b.position)
			assert_vector(a.face_size()).is_equal(b.face_size())
		for popup: TitlePopup in [quit, abandon] as Array[TitlePopup]:
			var left: MenuPlate = quit.yes_plate() if popup == quit else abandon.abandon_plate()
			var right: MenuPlate = quit.no_plate() if popup == quit else abandon.keep_plate()
			var tick: Rect2 = right.tick().get_global_rect()
			assert_bool(right.tick().visible).is_true()
			assert_float(tick.position.x).is_greater_equal(left.face().get_global_rect().end.x)
			assert_float(tick.end.x).is_less_equal(right.face().get_global_rect().position.x)
			assert_bool(popup.sheet().get_global_rect().encloses(left.get_global_rect())).is_true()
			assert_bool(popup.sheet().get_global_rect().encloses(right.get_global_rect())).is_true()
		var tall: float = quit.sheet().size.y
		var yes_top: float = quit.yes_plate().position.y
		quit.close()
		quit.open(false)
		await _frames(1)
		assert_bool(quit.line_label().visible).is_false()
		assert_float(quit.sheet().size.y).is_less(tall)
		var lift: float = tall - quit.sheet().size.y
		assert_float(quit.yes_plate().position.y).is_equal(yes_top - lift)
		(
			assert_bool(quit.sheet().get_global_rect().encloses(quit.no_plate().get_global_rect()))
			. is_true()
		)
		var question_bottom: float = AbandonConfirm.QUESTION_RECT.end.y
		assert_float(quit.yes_plate().position.y).is_greater(question_bottom)
		quit.close()
		abandon.close()


## The OPTIONS sheet at both sizes: the TEXT SIZE preview within the dashed rules, a hint shown
## before any row is marked, the chosen chips level with their neighbours, REDUCED MOTION as an
## OFF / ON chip pair (ON wears it), FAST's x1.5 in hard pixel digits on its chip, ESC centred on
## DONE's face, and the rows clear of the tagline.
func test_the_options_sheet_fixes() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var title: TitleScreen = await _title()
		var card: OptionsCard = OptionsCard.new()
		card.still = true
		title.add_child(card)
		var profile: ProfileState = ProfileState.new()
		card.open(profile, GameSettings.new(), null)
		await _frames(2)
		var sheet: Rect2 = card.sheet().get_global_rect()
		var rules_right: float = sheet.position.x + OptionsCard.SHEET_WIDTH - 24.0
		assert_float(OptionsCard.WIDGET_LEFT + OptionsCard.PREVIEW_WIDTH).is_less_equal(
			OptionsCard.SHEET_WIDTH - 24.0
		)
		(
			assert_float(sheet.position.x + OptionsCard.WIDGET_LEFT + OptionsCard.PREVIEW_WIDTH)
			. is_less_equal(rules_right)
		)
		assert_int(card.marked_row()).is_equal(-1)
		assert_str(card.hint_label().text).is_equal(OptionsCard.DEFAULT_HINT)
		for row: OptionsCard.Row in [
			OptionsCard.Row.DISPLAY,
			OptionsCard.Row.TEXT,
			OptionsCard.Row.MOTION,
			OptionsCard.Row.SPEED
		]:
			var chips: Array = card.chips(row)
			assert_int(chips.size()).is_greater_equal(2)
			var tops: Array[float] = []
			for chip: OptionChip in chips:
				tops.append(chip.global_position.y + chip.face_top())
			for top: float in tops:
				assert_float(top).is_equal(tops[0])
		var motion: Array = card.chips(OptionsCard.Row.MOTION)
		assert_bool((motion[0] as OptionChip).chosen).is_true()
		(motion[1] as OptionChip).pressed.emit()
		assert_bool(profile.reduced_motion()).is_true()
		assert_bool((motion[1] as OptionChip).chosen).is_true()
		var fast: OptionChip = card.chips(OptionsCard.Row.SPEED)[1]
		var digits: Label = fast.number_label()
		assert_str(digits.text).is_equal("×1.5")
		assert_object(digits.get_theme_font("font")).is_same(ArtStyle.pixel_number_font())
		# The digits' ink (their advance, their baseline) inside the chip's face.
		var font: Font = ArtStyle.pixel_number_font()
		var advance: float = (
			(
				font
				. get_string_size(
					digits.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.PIXEL_NUMBER_SIZE
				)
				. x
			)
			* digits.scale.x
		)
		var chip_rect: Rect2 = fast.get_global_rect()
		assert_float(digits.global_position.x + advance).is_less_equal(chip_rect.end.x)
		var baseline: float = (
			digits.global_position.y + font.get_ascent(ArtStyle.PIXEL_NUMBER_SIZE) * digits.scale.y
		)
		assert_float(baseline).is_less(chip_rect.end.y - 4.0)
		assert_float(baseline - ArtStyle.PIXEL_CAP_HEIGHT * 2.0).is_greater(chip_rect.position.y)
		var done: MenuPlate = card.done_plate()
		var face: Rect2 = done.face().get_global_rect()
		var face_middle: float = (
			face.position.y
			+ (MenuPlate.PLATE_FACE_TOP + face.size.y - MenuPlate.PLATE_FACE_BOTTOM) / 2.0
		)
		var esc: Label = card.esc_label()
		var esc_middle: float = (
			esc.global_position.y
			+ (
				(
					ArtStyle.pixel_display_font().get_ascent(ArtStyle.PIXEL_TEXT_SIZE)
					- ArtStyle.PIXEL_CAP_HEIGHT / 2.0
				)
				* esc.scale.y
			)
		)
		assert_float(absf(esc_middle - face_middle)).is_less_equal(2.0)
		var first: Rect2 = card.row_entry(OptionsCard.Row.DISPLAY).get_global_rect()
		assert_float(first.position.y - sheet.position.y).is_greater_equal(
			OptionsCard.ROWS_TOP - 6.0
		)
		card.close()


## A profile that never had a coin reads NO COINS YET; one that spent its coins NO COINS LEFT.
func test_a_fresh_profile_has_no_coins_yet() -> void:
	var fresh: ToyMachinesScreen = await _toys(Kit.profile(0, 0))
	assert_str(fresh.strip().text()).is_equal(
		" ".join(PixelLine.split(ToyMachinesScreen.BROKE_FRESH_NOTICE))
	)
	var spent: ToyMachinesScreen = await _toys(Kit.profile(0, 3, {&"snacks": 1}))
	assert_str(spent.strip().text()).is_equal(
		" ".join(PixelLine.split(ToyMachinesScreen.BROKE_NOTICE))
	)


func _title() -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(4)
	return title


func _shift() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SHIFT)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


func _toys(profile: ProfileState) -> ToyMachinesScreen:
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, true
	)
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, Kit.balance())
	for frame: int in range(3):
		await await_idle_frame()
	return screen


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _event_log() -> EventLogService:
	return get_tree().root.get_node("EventLog") as EventLogService
