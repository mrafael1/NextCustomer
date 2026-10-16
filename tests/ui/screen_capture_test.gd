extends GdUnitTestSuite
## The screen capture (debug/screen_capture, #55) sets up its fixed shift on the real shift
## screen: shift 5 under Short belt, a hand of 8 and four cards on the belt, with a product from
## each of the 6 aisles among them. The capture keeps its saves and log in a temporary folder;
## the test redirects them too, so the real ones are never touched. Its capture saves one PNG,
## reporting a failed save to its reporter (never to Godot's output); headless runs have no
## screen to grab, so the test passes its own image.

const CAPTURE := "res://debug/screen_capture/screen_capture.tscn"

var _folder: String = ""
var _capture_folder: String = ""
var _errors: PackedStringArray = PackedStringArray()


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_capture_folder = "user://screen_capture_%d" % Time.get_ticks_usec()
	_errors.clear()


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	for folder: String in [_folder, _capture_folder]:
		if DirAccess.dir_exists_absolute(folder):
			for file_name: String in DirAccess.get_files_at(folder):
				DirAccess.remove_absolute(folder.path_join(file_name))
			DirAccess.remove_absolute(folder)


func test_the_capture_sets_up_its_shift() -> void:
	var runner: GdUnitSceneRunner = scene_runner(CAPTURE)
	for _frame: int in range(3):
		await get_tree().process_frame
	var screen: ShiftScreen = runner.scene().call("screen")
	var run: RunState = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.shift_index).is_equal(4)
	assert_int(run.inspections.size()).is_equal(1)
	assert_int(run.hand().size()).is_equal(8)
	assert_int(run.row.size()).is_equal(4)
	assert_int(screen._hand_box.cards().size()).is_equal(8)
	assert_int(screen._row_views.size()).is_equal(4)
	var aisles: Dictionary = {}
	for card: CardInstance in run.hand() + run.row:
		var aisle: AisleDefinition = run.balance.aisle_of(card.definition)
		if aisle != null:
			aisles[aisle] = true
	assert_int(aisles.size()).is_equal(run.balance.aisles.size())


func test_the_capture_saves_one_png() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return Image.create(8, 8, false, Image.FORMAT_RGB8))
	await capture.call("capture", _capture_folder)
	assert_array(_errors).is_empty()
	var window: Vector2i = capture.get_window().size
	var file_name: String = "shift_screen_%dx%d.png" % [window.x, window.y]
	assert_bool(FileAccess.file_exists(_capture_folder.path_join(file_name))).is_true()
	assert_int(DirAccess.get_files_at(_capture_folder).size()).is_equal(1)


func test_a_failed_capture_goes_to_the_reporter() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return null)
	await capture.call("capture", _capture_folder)
	assert_int(_errors.size()).is_equal(1)
	assert_bool(_errors[0].begins_with("Can't save")).is_true()
	assert_int(DirAccess.get_files_at(_capture_folder).size()).is_equal(0)


func _record(message: String) -> void:
	_errors.append(message)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
