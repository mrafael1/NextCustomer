extends GdUnitTestSuite
## Checkout Rhythm v3 on the real shift screen: each payout rolls the shared register and
## top gauge through the plan's exact ticks. Bonus steps only change the item's explanation.
## Normal and reduced-motion playback retain identical scoring totals and a visible monitor,
## with no monitor-covering quota overlay. The tests record tick sounds alongside readings.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
## A frame's slack on the real clock (ms) when the tick spacing is read there.
const FRAME_SLACK_MS := 20.0

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


## A recording Sfx that also notes the frame of each tick sound.
class FrameSfx:
	extends "res://tests/presentation/recording_sfx.gd"

	var tick_frames: Array[int] = []

	func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
		if sound == "tick":
			tick_frames.append(Engine.get_process_frames())
		super(sound, pitch, volume_db)


func before_test() -> void:
	_folder = "user://test_count_sync_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## See the suite comment (untouched, normal motion).
func test_every_tick_keeps_the_register_and_top_gauge_in_sync() -> void:
	await _exercise(false)


func test_reduced_motion_keeps_the_same_paid_totals_without_flying_money() -> void:
	await _exercise(true)


func _exercise(reduced: bool) -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(reduced)
	await _full_row(screen)
	var sfx: FrameSfx = _frame_sfx(screen)
	var count: CountUp = screen._count_up
	var changes: Array[int] = []
	var frames: Array[int] = []
	var failures: Array[String] = []
	var last: Array[int] = [0]
	var observe: Callable = func(value: int, _quota: int, _met: bool) -> void:
		if not screen._led.is_counting() or value == last[0]:
			return
		last[0] = value
		changes.append(value)
		frames.append(Engine.get_process_frames())
		if screen._cabinet.total_display.amount() != value:
			failures.append("Register total differs from the shared reading")
		if screen._quota_meter.amount_label.text != "€%d" % value:
			failures.append("Top gauge differs from the shared reading")
		if screen._monitor.checkout().is_visible_in_tree() or screen._monitor.climax().is_running():
			failures.append("A total or celebration covered the monitor")
	screen._led.reading_changed.connect(observe)
	await screen._on_checkout_pressed()
	screen._led.reading_changed.disconnect(observe)
	var expected: Array[int] = []
	var all_tick_frames: int = 0
	for beat: CountUpBeat in count.plan.beats:
		if not CountUpPlan.is_payout_beat(beat):
			assert_array(beat.ticks).is_empty()
		if reduced and not beat.ticks.is_empty():
			expected.append(beat.shown_to)
		else:
			for value: int in beat.ticks:
				expected.append(value)
		all_tick_frames += beat.ticks.size()
	assert_array(changes).is_equal(expected)
	assert_int(sfx.tick_frames.size()).is_equal(all_tick_frames)
	if not reduced:
		assert_array(frames).is_equal(sfx.tick_frames)
	assert_array(failures).is_empty()
	assert_int(screen._cabinet.total_display.amount()).is_equal(count.plan.total)
	assert_array(screen._monitor.chips().chips()).is_empty()


func _frame_sfx(screen: ShiftScreen) -> FrameSfx:
	var sfx: FrameSfx = FrameSfx.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	return sfx


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	for id: String in FULL_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(FULL_ROW.size())
	await _frames(3)


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


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
