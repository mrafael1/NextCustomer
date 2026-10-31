extends GdUnitTestSuite
## The quota crossing (QuotaCrossing and BonusLights, mock-up docs/art/mockups/quota_crossing.html)
## on the real shift screen: the ding's crossing plants the SPEND MET flag on the item that met
## the quota, dips the stage and puts it back, lights the belt's rail and sounds the ka-ching;
## twice the quota slams the ×2 stamp under the gauge with another ka-ching; the rail's lights go
## out after the count; reduced motion keeps the flag, the lights and the sounds with no dip or
## flash; a resumed checkout pops nothing. Alone: a lap stamps only while counting. The real saves
## and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
## Milk, Multipack, Milk x5 = 109: past 40 and 80 (×2), short of 120.
const ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const QUOTA := 40
const MAX_WAIT_MS := 60000

var _folder: String = ""
var _runner: GdUnitSceneRunner
## At the crossing: [flag shown, lights lit, the flag's foot, the paying item's rect (local)].
var _at_cross: Array = []
## At each lap: [lap, stamp shown, the gauge's rect, the meter's bar rect (local)].
var _at_laps: Array[Array] = []
## The picture's offsets from its rest (the viewport's canvas transform) seen on any frame.
var _dips: Array[Vector2] = []
var _rest: Vector2 = Vector2.ZERO
var _flash_seen: bool = false


func before_test() -> void:
	_folder = "user://test_quota_crossing_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_at_cross = []
	_at_laps.clear()
	_dips.clear()
	_flash_seen = false


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_crossing_flags_the_item_dips_lights_and_rings() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording(screen)
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	_play(screen, false)
	await _until_played(screen)
	assert_int(_at_cross.size()).is_equal(4)
	assert_bool(_at_cross[0]).is_true()
	assert_bool(_at_cross[1]).is_true()
	# The flag stands on the item that met the quota.
	var item: Rect2 = _at_cross[3]
	(
		assert_bool(item.grow(8.0).has_point(_at_cross[2]))
		. override_failure_message("Flag foot %s off the item %s" % [_at_cross[2], item])
		. is_true()
	)
	# Twice the quota: one ×2 stamp, under the gauge.
	assert_int(_at_laps.size()).is_equal(1)
	assert_int(_at_laps[0][0]).is_equal(2)
	assert_bool(_at_laps[0][1]).is_true()
	assert_that(_at_laps[0][2]).is_equal(_at_laps[0][3])
	assert_int(_sounds(sfx, "kaching")).is_equal(2)
	# The stage dipped and came back to rest; the flash showed.
	assert_bool(_dips.any(func(offset: Vector2) -> bool: return offset.y > 0.0)).is_true()
	assert_that(screen.get_viewport().canvas_transform.origin).is_equal(_rest)
	assert_bool(_flash_seen).is_true()
	assert_bool(crossing.flag_shown()).is_false()
	await _seconds(BonusLights.FADE_SECONDS + 0.2)
	assert_bool(screen._stage.bonus_lights.is_lit()).is_false()


func test_reduced_motion_keeps_the_flag_lights_and_sound_without_dip_or_flash() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording(screen)
	_play(screen, true)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	await _until_played(screen)
	assert_bool(_at_cross[0]).is_true()
	assert_bool(_at_cross[1]).is_true()
	assert_int(_sounds(sfx, "kaching")).is_equal(2)
	assert_bool(_dips.all(func(offset: Vector2) -> bool: return offset == Vector2.ZERO)).is_true()
	assert_bool(_flash_seen).is_false()


func test_a_resumed_checkout_pops_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording(screen)
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	var context: CountUpContext = CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	screen._count_up.show_end_state(screen.run.preview(), QUOTA, context)
	await _frames(3)
	assert_bool(crossing.flag_shown()).is_false()
	assert_bool(crossing.stamp_shown()).is_false()
	assert_bool(screen._stage.bonus_lights.is_lit()).is_false()
	assert_int(_sounds(sfx, "kaching")).is_equal(0)


## An idle screen (a resume shows one for a while before its count) never lights the rail or
## shows the flag on its own.
func test_an_idle_screen_stays_dark() -> void:
	var screen: ShiftScreen = await _screen()
	await _seconds(1.5)
	assert_bool(screen._stage.bonus_lights.is_lit()).is_false()
	assert_bool(screen._stage.quota_crossing.flag_shown()).is_false()
	assert_bool(screen._stage.quota_crossing.stamp_shown()).is_false()


## Alone: a gauge's lap stamps only between a count's start and its end.
func test_a_lap_stamps_only_while_counting() -> void:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	meter.size = Vector2(560, TopBar.ROW_SIZE.y)
	add_child(meter)
	var lights: BonusLights = auto_free(BonusLights.new())
	add_child(lights)
	var crossing: QuotaCrossing = auto_free(QuotaCrossing.new())
	add_child(crossing)
	var count_up: CountUp = auto_free(CountUp.new())
	add_child(count_up)
	crossing.follow(count_up, meter, lights)
	meter.lap_reached.emit(2)
	assert_bool(crossing.stamp_shown()).is_false()
	crossing.begin()
	meter.lap_reached.emit(2)
	assert_bool(crossing.stamp_shown()).is_true()
	crossing.end()
	await _seconds(QuotaCrossing.STAMP_SECONDS + 0.1)
	meter.lap_reached.emit(3)
	assert_bool(crossing.stamp_shown()).is_false()


func _play(screen: ShiftScreen, reduced: bool) -> void:
	var count_up: CountUp = screen._count_up
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	_rest = screen.get_viewport().canvas_transform.origin
	count_up.quota_met.connect(_on_quota_met.bind(screen))
	screen._stage.top_bar.quota_meter.lap_reached.connect(
		func(lap: int) -> void:
			var bar: Rect2 = crossing._local_rect(
				screen._stage.top_bar.quota_meter.bar().get_global_rect()
			)
			_at_laps.append([lap, crossing.stamp_shown(), crossing._gauge, bar])
	)
	get_tree().process_frame.connect(_sample.bind(screen))
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		CardInstance.names(screen.run.row),
		QUOTA,
		CountUpContext.new(1, 0, 1.0, reduced, screen.receipt_header())
	)


## After the crossing's own handler (connected first).
func _on_quota_met(with_pop: bool, screen: ShiftScreen) -> void:
	if not with_pop:
		return
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	var item: Rect2 = crossing._local_rect(crossing._item())
	var foot: Vector2 = crossing._foot
	_at_cross = [crossing.flag_shown(), screen._stage.bonus_lights.is_lit(), foot, item]


func _sample(screen: ShiftScreen) -> void:
	_dips.append(screen.get_viewport().canvas_transform.origin - _rest)
	var flash: TextureRect = screen._stage.quota_crossing.get_node("Flash") as TextureRect
	if flash.modulate.a > 0.0:
		_flash_seen = true


## A recording Sfx on the screen: Sfx.find finds it from the stage.
func _recording(screen: ShiftScreen) -> Sfx:
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	return sfx


func _until_played(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	var started: int = Time.get_ticks_msec()
	while count_up._playing and Time.get_ticks_msec() - started < MAX_WAIT_MS:
		await get_tree().process_frame
	get_tree().process_frame.disconnect(_sample)
	assert_bool(count_up._playing).override_failure_message("Still counting.").is_false()


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	for id: String in ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ROW.size())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func _sounds(sfx: Sfx, sound: String) -> int:
	var count: int = 0
	for entry: Dictionary in sfx.get("sounds"):
		if entry["sound"] == sound:
			count += 1
	return count


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
