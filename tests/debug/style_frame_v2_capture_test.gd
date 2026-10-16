extends GdUnitTestSuite
## Style frame v2's scene (debug/style_frame_v2, #75): every state builds, and the capture saves
## one PNG per state into its folder, reporting a failed save to its reporter (never to Godot's
## output). Headless runs have no screen to grab, so the test passes its own image.

const SCENE := "res://debug/style_frame_v2/style_frame_v2.tscn"
const CAPTURED: Array[StyleFrameV2.State] = [
	StyleFrameV2.State.PLANNING, StyleFrameV2.State.COUNT_UP, StyleFrameV2.State.SCAN
]

var _folder: String = ""
var _errors: PackedStringArray = PackedStringArray()


func before_test() -> void:
	_folder = "user://style_frame_v2_capture_%d" % Time.get_ticks_usec()
	_errors.clear()


func after_test() -> void:
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_every_state_builds() -> void:
	var frame: StyleFrameV2 = scene_runner(SCENE).scene() as StyleFrameV2
	for state: int in StyleFrameV2.State.values():
		frame.show_state(state as StyleFrameV2.State)
		await get_tree().process_frame
		assert_int(frame.stage().get_parent().get_children().filter(_is_stage).size()).is_equal(1)
		assert_int(frame.item_views(true).size()).is_greater_equal(4)
		assert_int(frame.item_views(false).size()).is_greater_equal(6)
		var hover: bool = state == StyleFrameV2.State.SCAN or state == StyleFrameV2.State.SCAN_BELT
		assert_bool(frame.popup() != null).is_equal(hover)
		var docked: bool = state == StyleFrameV2.State.PLANNING
		assert_bool(frame.scanner().get_parent() == frame.stage()).is_equal(docked)
		assert_bool(frame.overlay().brackets().has_area()).is_equal(not docked)


func test_the_capture_saves_one_png_per_state() -> void:
	var frame: StyleFrameV2 = scene_runner(SCENE).scene() as StyleFrameV2
	frame.report_error = _record
	frame.grab_image = func() -> Image: return Image.create(8, 8, false, Image.FORMAT_RGB8)
	await frame.capture(_folder, CAPTURED)
	assert_array(_errors).is_empty()
	var window: Vector2i = frame.get_window().size
	for state: StyleFrameV2.State in CAPTURED:
		var file_name: String = (
			"style_frame_v2_%s_%dx%d.png" % [StyleFrameV2.STATE_NAMES[state], window.x, window.y]
		)
		assert_bool(FileAccess.file_exists(_folder.path_join(file_name))).is_true()
	assert_int(DirAccess.get_files_at(_folder).size()).is_equal(CAPTURED.size())
	assert_int(frame.stage().get_parent().get_children().filter(_is_stage).size()).is_equal(1)


func test_a_failed_capture_goes_to_the_reporter() -> void:
	var frame: StyleFrameV2 = scene_runner(SCENE).scene() as StyleFrameV2
	frame.report_error = _record
	frame.grab_image = func() -> Image: return null
	await frame.capture(_folder, CAPTURED)
	assert_int(_errors.size()).is_equal(CAPTURED.size())
	assert_bool(_errors[0].begins_with("Can't save")).is_true()
	assert_int(DirAccess.get_files_at(_folder).size()).is_equal(0)


func _record(message: String) -> void:
	_errors.append(message)


static func _is_stage(node: Node) -> bool:
	return node.name == "Stage" and not node.is_queued_for_deletion()
