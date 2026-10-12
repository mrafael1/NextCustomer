extends GdUnitTestSuite
## PressReader (full build plan 6.2): taps and holds of Space and the mouse, read from the input
## events sent through the scene runner. The reader's clock is the test's `_now`, so the
## threshold is tested to the millisecond; the checkout click, the checkout double-click, clicks
## on buttons that can be pressed and lost presses are neither taps nor holds.

var _now: int = 1000
var _taps: Array[int] = []
var _folder: String = ""
var _runner: GdUnitSceneRunner
var _root: Node
var _reader: PressReader


func before_test() -> void:
	# Nothing here saves or logs, but the event log and saves still point at a temporary folder.
	_folder = "user://test_press_reader_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_reading_starts_and_stops() -> void:
	_reader_in_tree()
	assert_bool(_reader.is_reading()).is_false()
	_reader.begin()
	assert_bool(_reader.is_reading()).is_true()
	assert_int(_reader.started_ms).is_equal(1000)
	_reader.end()
	assert_bool(_reader.is_reading()).is_false()


## A release 1 ms before the threshold is a tap; a press held to the threshold is a hold, and
## its release is no tap.
func test_a_tap_ends_before_the_threshold_and_a_hold_starts_at_it() -> void:
	_reader_in_tree()
	_reader.begin()
	_runner.simulate_key_press(KEY_SPACE)
	_now += PressReader.HOLD_THRESHOLD_MS - 1
	assert_bool(_reader.is_holding()).is_false()
	_runner.simulate_key_release(KEY_SPACE)
	assert_array(_taps).is_equal([1000 + PressReader.HOLD_THRESHOLD_MS - 1])

	_now = 2000
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_now += PressReader.HOLD_THRESHOLD_MS - 1
	assert_bool(_reader.is_holding()).is_false()
	_now += 1
	assert_bool(_reader.is_holding()).is_true()
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_bool(_reader.is_holding()).is_false()
	assert_int(_taps.size()).is_equal(1)


## Space and the mouse held together are one press: it ends with the last release.
func test_space_and_the_mouse_together_are_one_press() -> void:
	_reader_in_tree()
	_reader.begin()
	_runner.simulate_key_press(KEY_SPACE)
	_now += 50
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_now += 100
	_runner.simulate_key_release(KEY_SPACE)
	assert_array(_taps).is_empty()
	_now += 100
	assert_bool(_reader.is_holding()).is_true()
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_array(_taps).is_empty()


## A press already held when reading begins (the checkout click) is ignored up to its release:
## neither a tap when released quickly nor a hold when held long. The next press counts.
func test_a_press_held_at_the_start_is_ignored_up_to_its_release() -> void:
	_reader_in_tree()
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_runner.simulate_key_press(KEY_SPACE)
	_reader.begin()
	# begin() captures both held sources. Their presses came before it, so they are not tracked
	# either: the rule shows in the captured state as well as in no tap and no hold below.
	assert_int(_reader._ignored).is_equal(PressReader.PRESS_SPACE | PressReader.PRESS_MOUSE)
	_now += 1000
	assert_bool(_reader.is_holding()).is_false()
	_runner.simulate_key_release(KEY_SPACE)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_int(_reader._ignored).is_equal(0)
	assert_array(_taps).is_empty()
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_now += 20
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_array(_taps).is_equal([2020])


## The second click of a double-click within CHECKOUT_DOUBLE_CLICK_MS of the start finishes the
## checkout's double-click: neither its press nor its release counts. A later double-click press
## is a real tap.
func test_the_checkout_double_click_is_ignored_only_at_the_start() -> void:
	_reader_in_tree()
	_reader.begin()
	_now += PressReader.CHECKOUT_DOUBLE_CLICK_MS - 1
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT, true)
	_now += 20
	assert_bool(_reader.is_holding()).is_false()
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_array(_taps).is_empty()

	_now = 1000 + PressReader.CHECKOUT_DOUBLE_CLICK_MS
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT, true)
	_now += 20
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_array(_taps).is_equal([1000 + PressReader.CHECKOUT_DOUBLE_CLICK_MS + 20])


## A press and release that arrive in the same frame, on the real clock, are a tap.
func test_a_press_and_release_in_one_frame_is_a_tap() -> void:
	_reader_in_tree()
	_reader.clock = Time.get_ticks_msec
	_reader.begin()
	var frame: int = Engine.get_process_frames()
	_runner.simulate_key_press(KEY_SPACE)
	_runner.simulate_key_release(KEY_SPACE)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_int(Engine.get_process_frames()).is_equal(frame)
	assert_int(_taps.size()).is_equal(2)


## A press whose release never came (the window lost focus, so the input state shows it up
## without a release event) is dropped on the next frame: no hold, and a late release is no tap.
func test_a_lost_release_drops_the_press() -> void:
	_reader_in_tree()
	_reader.begin()
	_reader._input(_space(true))  # Pressed in its event only: the input state says it is up.
	_now += PressReader.HOLD_THRESHOLD_MS
	assert_bool(_reader.is_holding()).is_true()
	# process_frame comes before the nodes' _process: the second one follows a whole frame.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_reader.is_holding()).is_false()
	_reader._input(_space(false))
	assert_array(_taps).is_empty()


## A mouse press on a button that can be pressed is neither a tap nor a hold; on a disabled
## button (CHECKOUT during its own count) it counts. Headless runs keep the mouse at the
## window's corner, so the button sits there.
func test_a_press_on_an_enabled_button_is_neither_a_tap_nor_a_hold() -> void:
	_reader_in_tree()
	var button: Button = Button.new()
	button.size = Vector2(40, 40)
	_root.add_child(button)
	button.global_position = Vector2.ZERO
	await get_tree().process_frame
	_root.get_viewport().update_mouse_cursor_state()
	assert_object(_root.get_viewport().gui_get_hovered_control()).is_same(button)
	_reader.begin()
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_now += 20
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_now += 1000
	assert_bool(_reader.is_holding()).is_false()
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_array(_taps).is_empty()

	button.disabled = true
	_runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	_now += 20
	_runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	assert_array(_taps).is_equal([2040])


## Nothing is read before begin() or after end(): a press tracked when reading ends is
## forgotten, and its release is no tap.
func test_presses_outside_reading_do_nothing() -> void:
	_reader_in_tree()
	_runner.simulate_key_press(KEY_SPACE)
	_runner.simulate_key_release(KEY_SPACE)
	_reader.begin()
	_runner.simulate_key_press(KEY_SPACE)
	_reader.end()
	_now += 1000
	assert_bool(_reader.is_holding()).is_false()
	_runner.simulate_key_release(KEY_SPACE)
	assert_array(_taps).is_empty()


## The reader never marks an event handled, so the rest of the screen still gets it.
func test_events_are_not_marked_handled() -> void:
	_reader_in_tree()
	var probe: InputProbe = InputProbe.new()
	_root.add_child(probe)
	# Children get _input last to first: the reader first, then the probe.
	_root.move_child(probe, 0)
	_reader.begin()
	_root.get_viewport().push_input(_space(true))
	_root.get_viewport().push_input(_space(false))
	assert_int(probe.seen).is_equal(2)
	assert_array(_taps).is_equal([1000])


## A reader in the tree, under the scene runner, on the test's clock (at 1000 ms).
func _reader_in_tree() -> void:
	_now = 1000
	_taps.clear()
	_root = auto_free(Node.new())
	_reader = PressReader.new()
	_reader.clock = func() -> int: return _now
	_reader.tapped.connect(func(now_ms: int) -> void: _taps.append(now_ms))
	_root.add_child(_reader)
	_runner = scene_runner(_root)


static func _space(pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	return event


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## Counts the input events that reach it.
class InputProbe:
	extends Node
	var seen: int = 0

	func _input(_event: InputEvent) -> void:
		seen += 1
