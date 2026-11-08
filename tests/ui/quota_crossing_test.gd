extends GdUnitTestSuite
## The quota crossing (QuotaCrossing and BonusLights, mock-up docs/art/mockups/quota_crossing.html)
## on the real shift screen: the ding's crossing flies its streak from the item that met the
## quota (no flag since the user's feedback of 2026-11-03), dips the stage and puts it back,
## lights the belt's rail and sounds the ka-ching; twice the quota rings another ka-ching with no
## pop beside the receipt (v1.13: no "×N" stamp, and the row's Multipack ×3 stickers neither punch
## nor flash); the rail's lights go out after the count; reduced motion keeps the crossing, the
## lights and the sounds with no dip or flash; a resumed checkout pops nothing. Alone: a lap rings
## only while counting and draws nothing. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
## Milk, Multipack, Milk x5 = 109: past 40 and 80 (×2), short of 120.
const ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const QUOTA := 40
const MAX_WAIT_MS := 60000

var _folder: String = ""
var _runner: GdUnitSceneRunner
## At the crossing: [crossing shown, lights lit, the streak's start, the paying item's rect
## (local)].
var _at_cross: Array = []
## At each lap: [lap, the crossing drawing, the gauge's rect, the meter's bar rect (local)].
var _at_laps: Array[Array] = []
## Frames, from the first lap on, where the crossing still drew or processed past its own show
## (a lap's pop), and where a MULTIPLY sticker ("×3") was scaled up or flashed (a checkout ×N
## pop, v1.00 and v1.13).
var _lap_pops: int = 0
## The visible Controls between the register tower and the monitor, above the belt (where the
## ×N stamp popped), before the count; and those that showed there only from the first lap on,
## other than the belt's stickers.
var _beside_before: Dictionary = {}
var _beside_pops: Array[String] = []
var _multiply_pops: Array[String] = []
var _multiply_stickers: int = 0
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
	_lap_pops = 0
	_beside_before.clear()
	_beside_pops.clear()
	_multiply_pops.clear()
	_multiply_stickers = 0


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_crossing_streaks_from_the_item_dips_lights_and_rings() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording(screen)
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	_play(screen, false)
	await _until_played(screen)
	assert_int(_at_cross.size()).is_equal(4)
	assert_bool(_at_cross[0]).is_true()
	assert_bool(_at_cross[1]).is_true()
	# The streak starts on the item that met the quota.
	var item: Rect2 = _at_cross[3]
	(
		assert_bool(item.grow(8.0).has_point(_at_cross[2]))
		. override_failure_message("Streak start %s off the item %s" % [_at_cross[2], item])
		. is_true()
	)
	# Twice the quota: one lap, rung with the ka-ching, and no "×N" pop beside the receipt
	# (v1.13), nor a punched or flashed "×3" sticker (v1.00).
	assert_int(_at_laps.size()).is_equal(1)
	assert_int(_at_laps[0][0]).is_equal(2)
	assert_that(_at_laps[0][2]).is_equal(_at_laps[0][3])
	assert_int(_sounds(sfx, "kaching")).is_equal(2)
	assert_int(_lap_pops).is_equal(0)
	assert_array(_beside_pops).is_empty()
	assert_int(_multiply_stickers).is_greater(0)
	assert_array(_multiply_pops).is_empty()
	# The stage dipped and came back to rest; the flash showed.
	assert_bool(_dips.any(func(offset: Vector2) -> bool: return offset.y > 0.0)).is_true()
	assert_that(screen.get_viewport().canvas_transform.origin).is_equal(_rest)
	assert_bool(_flash_seen).is_true()
	assert_bool(crossing.crossing_shown()).is_false()
	await _seconds(BonusLights.FADE_SECONDS + 0.2)
	assert_bool(screen._stage.bonus_lights.is_lit()).is_false()


func test_reduced_motion_keeps_the_lights_and_sound_without_dip_or_flash() -> void:
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
	assert_bool(crossing.crossing_shown()).is_false()
	assert_bool(crossing.drawing()).is_false()
	assert_bool(screen._stage.bonus_lights.is_lit()).is_false()
	assert_int(_sounds(sfx, "kaching")).is_equal(0)


## An idle screen (a resume shows one for a while before its count) never lights the rail or
## shows the crossing on its own.
func test_an_idle_screen_stays_dark() -> void:
	var screen: ShiftScreen = await _screen()
	await _seconds(1.5)
	assert_bool(screen._stage.bonus_lights.is_lit()).is_false()
	assert_bool(screen._stage.quota_crossing.crossing_shown()).is_false()
	assert_bool(screen._stage.quota_crossing.drawing()).is_false()


## Alone: its hard pixel shapes (the streak, the ring and the sparkles) go through the
## sharp-pixel material with linear filtering, so they stay even at 1920x1080 (the 1.5x stretch).
func test_its_pixel_shapes_take_the_pixel_material() -> void:
	var crossing: QuotaCrossing = auto_free(QuotaCrossing.new())
	assert_object(crossing.material).is_same(ArtStyle.pixel_material())
	assert_int(crossing.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR)


## Alone: a gauge's lap rings only between a count's start and its end, and never draws: no
## "×N" stamp pops beside the receipt at checkout (v1.13), nor its sparkles.
func test_a_lap_rings_only_while_counting_and_pops_nothing() -> void:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	meter.size = ShiftStage.TUBE_RECT.size
	add_child(meter)
	var lights: BonusLights = auto_free(BonusLights.new())
	add_child(lights)
	var crossing: QuotaCrossing = auto_free(QuotaCrossing.new())
	add_child(crossing)
	var count_up: CountUp = auto_free(CountUp.new())
	add_child(count_up)
	crossing.follow(count_up, meter, lights)
	var sfx: Sfx = RECORDING_SFX.new()
	add_child(sfx)
	auto_free(sfx)
	meter.lap_reached.emit(2)
	assert_int(_sounds(sfx, "kaching")).is_equal(0)
	crossing.begin()
	for lap: int in [2, 3]:
		meter.lap_reached.emit(lap)
		await _frames(2)
		assert_bool(crossing.drawing()).is_false()
		assert_bool(crossing.is_processing()).is_false()
		assert_int(crossing.get_child_count()).is_equal(1)  # The flash only (no pill, 2026-11-06).
	assert_int(_sounds(sfx, "kaching")).is_equal(2)
	crossing.end()
	meter.lap_reached.emit(4)
	assert_int(_sounds(sfx, "kaching")).is_equal(2)


func _play(screen: ShiftScreen, reduced: bool) -> void:
	var count_up: CountUp = screen._count_up
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	_rest = screen.get_viewport().canvas_transform.origin
	count_up.quota_met.connect(_on_quota_met.bind(screen))
	screen._stage.quota_meter.lap_reached.connect(
		func(lap: int) -> void:
			var bar: Rect2 = crossing._local_rect(screen._stage.quota_meter.bar().get_global_rect())
			_at_laps.append([lap, crossing.drawing(), crossing._gauge, bar])
	)
	for control: Control in _beside(screen):
		_beside_before[control] = true
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
	var launch: Vector2 = crossing.launch_point()
	_at_cross = [crossing.crossing_shown(), screen._stage.bonus_lights.is_lit(), launch, item]


func _sample(screen: ShiftScreen) -> void:
	_dips.append(screen.get_viewport().canvas_transform.origin - _rest)
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	var flash: TextureRect = crossing.get_node("Flash") as TextureRect
	if flash.modulate.a > 0.0:
		_flash_seen = true
	if not _at_laps.is_empty() and not crossing.crossing_shown():
		if crossing.drawing() or crossing.is_processing():
			_lap_pops += 1
		for control: Control in _beside(screen):
			var seen: String = "%s %s" % [screen.get_path_to(control), control.get_global_rect()]
			if not _beside_before.has(control) and not _beside_pops.has(seen):
				_beside_pops.append(seen)
	for node: Node in screen._stage.planning_layer.find_children("*", "EffectSticker", true, false):
		var sticker: EffectSticker = node as EffectSticker
		if sticker.spec().kind != StickerSpec.Kind.MULTIPLY or not sticker.is_visible_in_tree():
			continue
		_multiply_stickers += 1
		var inner: Control = sticker._inner
		if inner.scale.x > 1.0 or inner.modulate != Color.WHITE:
			_multiply_pops.append("%s %s" % [inner.scale, inner.modulate])


## The visible Controls drawn whole between the register tower and the monitor, above the belt
## (in the crossing's layer; a pop such as the old 70x40 stamp, not a layer spanning the screen),
## other than the belt's items (their stickers, and the price a counted item lifts over the belt).
func _beside(screen: ShiftScreen) -> Array[Control]:
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	var area: Rect2 = Rect2(
		ShiftStage.TOWER_RECT.end.x,
		0.0,
		ShiftStage.MONITOR_RECT.position.x - ShiftStage.TOWER_RECT.end.x,
		ShiftStage.BELT_RECT.position.y
	)
	var found: Array[Control] = []
	for node: Node in screen.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.size == Vector2.ZERO:
			continue
		if control.modulate.a == 0.0 or control.self_modulate.a == 0.0:
			continue
		if control is EffectSticker or control is ItemView or _on_an_item(control):
			continue
		if area.encloses(crossing._local_rect(control.get_global_rect())):
			found.append(control)
	return found


func _on_an_item(node: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is EffectSticker or parent is ItemView or parent is CardView:
			return true
		parent = parent.get_parent()
	return false


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
