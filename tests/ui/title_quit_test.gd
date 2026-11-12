extends GdUnitTestSuite
## The title's way out (v1.27): the QUIT plate under GUIDE and OPTIONS and Esc on the title ask
## QUIT GAME? (YES / NO, opening on NO); the web build offers neither. And the popups' and half
## plates' centred captions stay centred however wide the scene leaves their labels. The title
## never changes the test runner's scene, and its saves and log go to a temporary folder.

const TITLE := "res://ui/title_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RUN_ID := "0011223344556677"

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


## Esc on the title (or the QUIT plate) asks QUIT GAME? on NO: Esc or NO keep the game open,
## YES closes it; with a run saved, the line says it stays saved.
func test_esc_and_quit_ask_before_closing_the_game() -> void:
	_save_run_at_shift(2)
	var title: TitleScreen = await _title()
	var quits: Array[bool] = []
	title.quit_game = func() -> void: quits.append(true)
	var quit: QuitConfirm = title.quit_confirm()
	assert_object(title.menu().plate(TitleMenu.Entry.QUIT)).is_not_null()
	title._unhandled_key_input(_key(KEY_ESCAPE))
	assert_bool(quit.is_open()).is_true()
	assert_bool(quit.no_plate().marked).is_true()
	assert_str(quit.line_label().text).is_equal(QuitConfirm.SAVED_LINE)
	title._unhandled_key_input(_key(KEY_ESCAPE))
	assert_bool(quit.is_open()).is_false()
	title._unhandled_key_input(_key(KEY_ESCAPE))
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(quit.is_open()).is_false()
	assert_array(quits).is_empty()
	title.menu().plate(TitleMenu.Entry.QUIT).pressed.emit()
	assert_bool(quit.is_open()).is_true()
	title._unhandled_key_input(_key(KEY_LEFT))
	assert_bool(quit.yes_plate().marked).is_true()
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(quit.is_open()).is_false()
	assert_array(quits).is_equal([true])


## The centred captions (GUIDE, OPTIONS, QUIT GAME?'s YES and NO) sit in the middle of their faces
## in the real title, where the scene leaves their labels wider than their words.
func test_centred_captions_sit_in_the_middle_of_their_faces() -> void:
	var title: TitleScreen = await _title()
	title.quit_confirm().still = true
	title.quit_confirm().open(false)
	await _frames(2)
	var plates: Array[MenuPlate] = [
		title.menu().plate(TitleMenu.Entry.GUIDE),
		title.menu().plate(TitleMenu.Entry.OPTIONS),
		title.quit_confirm().yes_plate(),
		title.quit_confirm().no_plate(),
	]
	for plate: MenuPlate in plates:
		var caption: Label = plate.caption_label()
		# The real title can leave the label wider than its words (GUIDE: 50 font px for 28).
		caption.size.x = plate.face_size().x / caption.scale.x
		await _frames(1)
		var face: Rect2 = plate.face().get_global_rect()
		var words: float = OptionChip.pixel_width(caption.text, roundi(caption.scale.x))
		var drawn_left: float = caption.global_position.x
		if caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			drawn_left += (caption.size.x * caption.scale.x - words) / 2.0
		var middle: float = drawn_left + words / 2.0
		(
			assert_float(absf(middle - face.get_center().x))
			. override_failure_message(
				"%s off by %s" % [caption.text, middle - face.get_center().x]
			)
			. is_less_equal(4.0)
		)
	title.quit_confirm().close()


## Without quit (the web build), the title has no QUIT plate and Esc asks nothing.
func test_the_web_title_offers_no_quit() -> void:
	var title: TitleScreen = auto_free(load(TITLE).instantiate())
	title.quit_offered = false
	title.changes_scene = false
	add_child(title)
	await _frames(2)
	assert_object(title.quit_confirm()).is_null()
	assert_object(title.menu().plate(TitleMenu.Entry.QUIT)).is_null()


func _title() -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(4)
	return title


func _save_run_at_shift(shift: int) -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(31, deck, balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(shift - 1)
	assert_bool(SaveService.new(_folder).save_run(run, RUN_ID, 1000)).is_true()


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
