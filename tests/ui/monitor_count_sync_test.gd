extends GdUnitTestSuite
## The total's count-up on the real shift screen (#105 piece 2, mock-up readability_v3.html,
## monitor b): the full reference row (Eggs, Bread, Milk, Multipack, Milk x3 with Coupon engine,
## Slot engine and a Spot check) played untouched, read on every reading change and every frame.
## - One number: on every change and every frame the checkout column's number, the top bar's
##   amount, the status line ("N€ to go" / "+N€ over") and the climax's number (while it runs)
##   read the register's same whole number.
## - The ticks: the reading moves through exactly the plan's ticks (at most 3 per landing, whole
##   euros) and ends on the score's total; each change plays one tick sound in the same frame, the
##   ticks of one landing tick_gap_ms apart on the count's clock (at least that on the real one,
##   less a frame); only the digits that change roll.
## - The landings: sparks by kind (base 0, +N 3, × 6), the gold corners and the flash on × only,
##   a lamp per gain landing.
## - The chips: a flying amount never covers the digits (it dissolves short of their left edge);
##   WASTED's grey €0 drops from under its WASTED word and never crosses the item's struck price.
## Under reduced motion the reading jumps once per landing, the tick sounds all play, nothing flies
## and the number never punches. The saves and logs go to a temporary folder only.

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
func test_every_tick_moves_the_one_number_the_bar_and_the_monitor_show() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: FrameSfx = _frame_sfx(screen)
	await _full_row(screen)
	var probe: Dictionary = await _play(screen)
	var failures: Array[String] = probe["failures"]
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 16))).is_empty()
	var count_up: CountUp = screen._count_up
	var plan: CountUpPlan = count_up.plan
	var tuning: CountTotalTuning = count_up.total_tuning()
	# The reading moved through exactly the plan's ticks, and ends on the total.
	var expected: Array[int] = []
	var owners: Array[int] = []
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		assert_int(beat.ticks.size()).is_less_equal(tuning.ticks_per_landing)
		for value: int in beat.ticks:
			expected.append(value)
			owners.append(index)
	var changes: Array[Dictionary] = probe["changes"]
	var values: Array[int] = []
	for change: Dictionary in changes:
		values.append(int(change["value"]))
	assert_array(values).is_equal(expected)
	assert_int(values[-1]).is_equal(screen.run.last_result.total)
	assert_int(screen._monitor.checkout().total_number().value()).is_equal(plan.total)
	# One tick sound per change, in its frame.
	assert_int(sfx.tick_frames.size()).is_equal(changes.size())
	for index: int in range(changes.size()):
		assert_int(sfx.tick_frames[index]).override_failure_message("tick %d" % index).is_equal(
			int(changes[index]["frame"])
		)
	# A landing's ticks tick_gap_ms apart on the count's clock (count_speed on shift 1).
	var gap_ms: float = tuning.tick_gap_ms / plan.count_speed
	var spaced: int = 0
	for index: int in range(1, changes.size()):
		if owners[index] != owners[index - 1]:
			continue
		var real_ms: float = (
			(int(changes[index]["usec"]) - int(changes[index - 1]["usec"])) / 1000.0
		)
		(
			assert_float(real_ms)
			. override_failure_message("ticks %d-%d %.1f ms" % [index - 1, index, real_ms])
			. is_greater_equal(gap_ms - FRAME_SLACK_MS)
		)
		spaced += 1
	assert_int(spaced).is_greater(5)
	# The landings: one per landing beat that moves the total, sparks, corners and the flash by
	# kind; every kind seen.
	var landings: Array[Dictionary] = probe["landings"]
	var moving: int = 0
	for beat: CountUpBeat in plan.beats:
		if not beat.ticks.is_empty():
			moving += 1
	assert_int(landings.size()).is_equal(moving)
	var kinds: Dictionary[int, bool] = {}
	for landing: Dictionary in landings:
		var land: CountUpBeat.Land = landing["land"]
		kinds[land] = true
		var sparks: int = 0
		match land:
			CountUpBeat.Land.ADD:
				sparks = tuning.sparks_add
			CountUpBeat.Land.MUL:
				sparks = tuning.sparks_mul
		var message: String = "landing %s" % CountUpBeat.Land.keys()[land]
		assert_int(landing["sparks"]).override_failure_message(message).is_equal(sparks)
		var times: bool = land == CountUpBeat.Land.MUL
		assert_bool(landing["corners"]).override_failure_message(message).is_equal(times)
		assert_bool(landing["flash"]).override_failure_message(message).is_equal(times)
	for land: CountUpBeat.Land in [
		CountUpBeat.Land.BASE, CountUpBeat.Land.ADD, CountUpBeat.Land.MUL, CountUpBeat.Land.DOWN
	]:
		assert_bool(kinds.has(land)).override_failure_message(str(land)).is_true()
	assert_int(screen._monitor.checkout().lit_lamps()).is_equal(plan.lamp_count)
	# The chips flew, and WASTED dropped its €0 (Coupon engine on Multipack).
	assert_int(probe["chips_seen"]).is_greater(plan.lamp_count)
	assert_bool(probe["waste_seen"]).is_true()


## Reduced motion: one change per landing (its shown_to), every tick sound still played, no chip,
## no punch; the bar and the monitor read the same number on every frame.
func test_reduced_motion_jumps_once_per_landing_with_every_tick_sound() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_reduced_motion(true)
	var sfx: FrameSfx = _frame_sfx(screen)
	await _full_row(screen)
	var probe: Dictionary = await _play(screen)
	var failures: Array[String] = probe["failures"]
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 16))).is_empty()
	var plan: CountUpPlan = screen._count_up.plan
	assert_bool(plan.reduced_motion).is_true()
	var expected: Array[int] = []
	var ticks: int = 0
	for beat: CountUpBeat in plan.beats:
		if not beat.ticks.is_empty():
			expected.append(beat.shown_to)
			ticks += beat.ticks.size()
	var values: Array[int] = []
	for change: Dictionary in probe["changes"]:
		values.append(int(change["value"]))
	assert_array(values).is_equal(expected)
	assert_int(sfx.tick_frames.size()).is_equal(ticks)
	assert_int(probe["chips_seen"]).is_equal(0)
	assert_float(float(probe["peak_punch"])).is_equal(1.0)


# --- Helpers ---------------------------------------------------------------------------------


## Presses CHECKOUT and plays the count untouched to the verdict, recording every reading change
## ({"value", "frame", "usec"}), every landing ({"land", "sparks", "corners", "flash"}) and every
## frame's checks. Returns {"failures", "changes", "landings", "chips_seen", "waste_seen",
## "peak_punch"}.
func _play(screen: ShiftScreen) -> Dictionary:
	var count_up: CountUp = screen._count_up
	var led: LedDisplay = screen._led
	var monitor: MonitorView = screen._monitor
	var number: TotalNumber = monitor.checkout().total_number()
	var chips: CountChips = monitor.chips()
	var failures: Array[String] = []
	var changes: Array[Dictionary] = []
	var landings: Array[Dictionary] = []
	var state: Dictionary = {"last": 0, "text": "0", "chips": 0, "waste": false, "peak": 1.0}
	var on_reading: Callable = func(amount: int, _quota: int, _met: bool) -> void:
		if not led.is_counting() or count_up._verdict_shown or amount == int(state["last"]):
			return
		var frame: int = Engine.get_process_frames()
		changes.append({"value": amount, "frame": frame, "usec": Time.get_ticks_usec()})
		failures.append_array(_sync_failures(screen, "change to %d" % amount))
		# Only the digits that change roll (none under reduced motion).
		var old: String = String(state["text"])
		var new: String = "%d" % amount
		var rolling: Array[int] = number.rolling()
		rolling.sort()
		var expected: Array[int] = []
		# A shorter number is laid out again at once.
		if not count_up.plan.reduced_motion and old.length() <= new.length():
			var padded: String = old.lpad(new.length())
			for index: int in range(new.length()):
				if padded[index] != new[index]:
					expected.append(index)
		if rolling != expected:
			failures.append("%s to %s: rolling %s, changed %s" % [old, new, rolling, expected])
		state["last"] = amount
		state["text"] = new
	var on_landing: Callable = func(beat: CountUpBeat) -> void:
		var sparks: int = 0
		var corners: bool = false
		for effect: Dictionary in chips._effects:
			if float(effect["q"]) != 0.0:
				continue
			if effect["kind"] == "sparks":
				sparks += int(effect["count"])
			corners = corners or effect["kind"] == "corners"
		var flash: bool = number.modulate != Color.WHITE
		landings.append({"land": beat.land, "sparks": sparks, "corners": corners, "flash": flash})
	var on_frame: Callable = func() -> void:
		if not led.is_counting() or count_up._verdict_shown:
			return
		failures.append_array(_sync_failures(screen, "frame %d" % Engine.get_process_frames()))
		failures.append_array(_chip_failures(monitor))
		state["peak"] = maxf(float(state["peak"]), number.punch_scale())
		for chip: Control in chips.chips():
			state["chips"] = int(state["chips"]) + 1
			if (chip as CountChips.Chip).text == "€0" and not bool(state["waste"]):
				state["waste"] = true
				failures.append_array(_waste_start_failures(monitor, chip))
	led.reading_changed.connect(on_reading)
	count_up.landing.connect(on_landing)
	get_tree().process_frame.connect(on_frame)
	screen._on_checkout_pressed()
	while screen._counting and not count_up._verdict_shown:
		await get_tree().process_frame
	get_tree().process_frame.disconnect(on_frame)
	count_up.landing.disconnect(on_landing)
	led.reading_changed.disconnect(on_reading)
	return {
		"failures": failures,
		"changes": changes,
		"landings": landings,
		"chips_seen": state["chips"],
		"waste_seen": state["waste"],
		"peak_punch": state["peak"],
	}


## The register's reading against the top bar's amount, the checkout column's number, its status
## line (while it shows) and the climax's number (while it runs), as failures.
static func _sync_failures(screen: ShiftScreen, where: String) -> Array[String]:
	var failures: Array[String] = []
	var reading: int = screen._led.amount()
	var quota: int = screen._led.quota()
	var top: String = screen._quota_meter.amount_label.text
	if top != "€%d" % reading:
		failures.append("%s: the top bar %s, the reading %d" % [where, top, reading])
	var column: CheckoutColumn = screen._monitor.checkout()
	var number: TotalNumber = column.total_number()
	if number.value() != reading or number.text() != "%d" % reading:
		failures.append("%s: the column %s, the reading %d" % [where, number.text(), reading])
	var status: Label = column.status_label()
	if status.visible and status.text != MonitorText.status(reading, quota):
		failures.append("%s: the status '%s', the reading %d" % [where, status.text, reading])
	var climax: MonitorClimax = screen._monitor.climax()
	if climax.is_running() and climax.number().value() != reading:
		failures.append(
			"%s: the climax %d, the reading %d" % [where, climax.number().value(), reading]
		)
	return failures


## The chips now, as failures: a flying amount clear of the digits (left of their left edge while
## level with them), a WASTED €0 clear of the item's struck price.
static func _chip_failures(monitor: MonitorView) -> Array[String]:
	var failures: Array[String] = []
	var digits: Rect2 = monitor.checkout().total_number().ink_rect()
	var struck: PriceSticker.StruckPrice = monitor.item_column().struck()
	for chip: Control in monitor.chips().chips():
		if chip.modulate.a <= 0.0:
			continue
		var rect: Rect2 = MonitorKit.drawn_rect(chip)
		if (chip as CountChips.Chip).text == "€0":
			if struck != null and struck.is_visible_in_tree():
				if rect.intersects(struck.get_global_rect()):
					failures.append("€0 %s over the struck price" % rect)
			continue
		# Level with the digits it stays left of their left edge; it never covers them.
		var level: bool = rect.end.y > digits.position.y and rect.position.y < digits.end.y
		if rect.intersects(digits) or (level and rect.end.x > digits.position.x):
			failures.append("chip '%s' %s over the digits %s" % [chip.get("text"), rect, digits])
	return failures


## WASTED's €0 as it first shows, as failures: under its step line's WASTED (its top at or below
## the word's foot, across the word's span), not over it.
static func _waste_start_failures(monitor: MonitorView, chip: Control) -> Array[String]:
	var rows: Array[Control] = monitor.item_column().step_rows()
	var amount: Control = (
		rows[-1].get_node_or_null("Amount") as Control if not rows.is_empty() else null
	)
	if amount == null:
		return ["€0 with no WASTED line"]
	var word: Rect2 = amount.get_global_rect()
	var rect: Rect2 = MonitorKit.drawn_rect(chip)
	var under: bool = rect.position.y >= word.end.y - 2.0
	var across: bool = rect.get_center().x > word.position.x and rect.get_center().x < word.end.x
	if not under or not across:
		return ["€0 %s not under WASTED %s" % [rect, word]]
	return []


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
