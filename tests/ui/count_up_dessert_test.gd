extends GdUnitTestSuite
## The shift's dessert on the real shift screen (#61, CountUpDessert): after the verdict,
## "€total / €quota" slams onto the TOTAL line with `total` or `miss`, the margin line counts
## (+€N OVER QUOTA, SHORT €N, ON QUOTA) with `pass` or `fail`, a pass is stamped PAID, the
## receipt tears with `rip` (after `fail` has rung out on a miss), the next shift's notice prints
## under the tear, and a pass ends at the printer feed. Checked: the order and timing of the
## sounds for a pass, a miss (at Normal and Fast), a pass before an inspected shift, an upgrade
## shift and the last shift; the right N; the speed setting without the auto speed-up; reduced
## motion; the slam and the new lines on screen; and a skipped dessert leaving the same receipt
## and sounds. The real saves, logs and
## Music bus level are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const MUSIC_SCRIPT := preload("res://presentation/music.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## Milk, Multipack, Milk x5 = 109.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const ROW_TOTAL := 109
## A step starts no earlier than planned (less the verdict frame's delta and 5 ms of rounding),
## and at most this much later (frame boundaries in the headless runner) plus the longest frame
## that ran since the verdict, so a stalled frame under load doesn't fail it (_assert_ms).
const LATE_MS := 150
## A wait between two dessert steps can end up to a frame early in wall-clock time.
const EARLY_MS := 20
const NOTICE := "Next shift: test notice"

var _folder: String = ""
var _window_size: Vector2i
var _bus_db: float = 0.0
var _tuning: CountUpTuning
## Each frame's start (Time.get_ticks_usec() at process_frame) and its process delta in ms, from
## _play until the count-up ends: the timing bounds allow for the frames that actually ran.
var _frame_usec: PackedInt64Array = PackedInt64Array()
var _frame_delta_ms: PackedFloat64Array = PackedFloat64Array()
var _timed: CountUp


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)
	_bus_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(MusicService.BUS))
	_tuning = load(CountUp.TUNING_PATH)


func after_test() -> void:
	if get_tree().process_frame.is_connected(_record_frame):
		get_tree().process_frame.disconnect(_record_frame)
	_timed = null
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MusicService.BUS), _bus_db)
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A pass with no notice and no taps: total and the slam at 300 ms, pass at 450, PAID at 520,
## the tear at 560 and the printer feed at 700 (each within _assert_ms's bounds); the
## verdict and "+€75 OVER QUOTA | PAID" in green under it, then the tear; one printer_feed.
func test_a_pass_slams_counts_stamps_tears_and_feeds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	var feeds: Array[int] = []
	count_up.printer_feed.connect(func() -> void: feeds.append(Time.get_ticks_msec()))
	_play(screen, 34)
	var failures: Array[String] = await _watch_dessert(screen)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	var heard: Array[Dictionary] = _dessert_sounds(sfx, count_up)
	assert_array(_names_of(heard)).is_equal(["total", "pass", "stamp_paid", "rip"])
	var slam: int = _tuning.dessert_slam_delay_ms + _tuning.dessert_slam_ms
	var tear: int = (
		slam + _tuning.dessert_margin_ms + _tuning.dessert_paid_ms + _tuning.dessert_tear_ms
	)
	_assert_at(heard[0], count_up, slam)
	_assert_at(heard[1], count_up, slam + _tuning.dessert_verdict_sound_ms)
	_assert_at(heard[2], count_up, slam + _tuning.dessert_margin_ms + _tuning.dessert_paid_ms)
	_assert_at(heard[3], count_up, tear)
	var feed_ms: int = count_up.printer_feed_ms - count_up.total_shown_ms
	prints("#61 pass: total", _ms_of(heard[0], count_up), "feed", feed_ms)
	_assert_ms(feed_ms, count_up, tear + _tuning.dessert_feed_ms, "printer feed")
	assert_array(feeds).is_equal([count_up.printer_feed_ms])
	assert_int(count_up.margin.kind()).is_equal(ShiftMargin.Kind.OVER)
	var lines: Array[String] = _lines(screen._receipt)
	assert_array(lines.slice(-3)).is_equal(
		[
			"TOTAL | €109 / €34",
			"+€75 OVER QUOTA | PAID",
			ReceiptView.TEAR_PATTERN.repeat(60) + " | "
		]
	)
	assert_that(_color(screen._receipt.total_label())).is_equal(Palette.GOOD)
	assert_that(_color(_line_label(screen._receipt, -2, 0))).is_equal(Palette.GOOD)
	await _assert_lines_on_screen(screen, 3)


## A miss: miss, fail, then the tear once fail has rung out, and no PAID, notice or feed;
## "SHORT €91" and the verdict in red.
func test_a_miss_counts_short_and_tears_after_the_fail() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	var feeds: Array[int] = []
	count_up.printer_feed.connect(func() -> void: feeds.append(Time.get_ticks_msec()))
	_play(screen, 200, NOTICE)
	var failures: Array[String] = await _watch_dessert(screen)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	var heard: Array[Dictionary] = _dessert_sounds(sfx, count_up)
	assert_array(_names_of(heard)).is_equal(["miss", "fail", "rip"])
	var fail_ms: int = _ms_of(heard[1], count_up)
	var fail_end: int = fail_ms + roundi(sfx.sound_length("fail") * 1000.0)
	assert_int(_ms_of(heard[2], count_up)).is_greater_equal(fail_end + _tuning.dessert_tear_ms - 20)
	assert_int(count_up.printer_feed_ms).is_equal(-1)
	assert_array(feeds).is_empty()
	assert_int(count_up.margin.kind()).is_equal(ShiftMargin.Kind.SHORT)
	var lines: Array[String] = _lines(screen._receipt)
	assert_str(lines[-3]).is_equal("TOTAL | €109 / €200")
	assert_str(lines[-2]).is_equal("SHORT €91 | ")
	assert_that(_color(screen._receipt.total_label())).is_equal(Palette.TOMATO)
	assert_that(_color(_line_label(screen._receipt, -2, 0))).is_equal(Palette.TOMATO)
	await _assert_lines_on_screen(screen, 3)


## Before an inspected shift: the notice prints under the tear with the printer, its stamp just
## after, and the printer still feeds within the same time.
func test_before_an_inspected_shift_the_notice_prints_under_the_tear() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	_play(screen, 34, NOTICE)
	await _played(screen)
	var heard: Array[Dictionary] = _dessert_sounds(sfx, count_up)
	assert_array(_names_of(heard)).is_equal(
		["total", "pass", "stamp_paid", "rip", "print", "stamp_notice"]
	)
	var tear: int = _ms_of(heard[3], count_up)
	# Less a frame: the wait's tween counts game time from the frame before it started.
	var notice_ms: int = tear + _tuning.dessert_notice_ms - EARLY_MS
	assert_int(_ms_of(heard[4], count_up)).is_greater_equal(notice_ms)
	var feed_ms: int = count_up.printer_feed_ms - count_up.total_shown_ms
	assert_int(feed_ms).is_greater_equal(_ms_of(heard[5], count_up))
	_assert_ms(feed_ms, count_up, _feed_ms(), "printer feed")
	var lines: Array[String] = _lines(screen._receipt)
	assert_str(lines[-2]).is_equal(ReceiptView.TEAR_PATTERN.repeat(60) + " | ")
	assert_str(lines[-1]).is_equal(NOTICE + " | ")
	await _assert_lines_on_screen(screen, 4)


## Exactly on the quota: a pass of €0, "ON QUOTA" in green with PAID.
func test_exactly_on_the_quota_is_a_green_on_quota() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	_play_skipped(screen, ROW_TOTAL)
	await _played(screen)
	var lines: Array[String] = _lines(screen._receipt)
	assert_str(lines[-3]).is_equal("TOTAL | €109 / €109")
	assert_str(lines[-2]).is_equal("ON QUOTA | PAID")
	assert_that(_color(_line_label(screen._receipt, -2, 0))).is_equal(Palette.GOOD)
	assert_int(screen._count_up.margin.kind()).is_equal(ShiftMargin.Kind.ON)
	assert_array(_names_of(_dessert_sounds(sfx, screen._count_up))).is_equal(
		["total", "pass", "stamp_paid", "rip"]
	)


## The last shift, won through the real checkout: PAID and the tear, no notice, then the
## results (no reward). The count_up event is logged once the dessert has finished.
func test_the_last_shift_is_stamped_and_torn_then_shows_the_results() -> void:
	var screen: ShiftScreen = await _screen()
	var music: MusicService = MUSIC_SCRIPT.new()
	music.streaming = false
	add_child(music)
	auto_free(music)
	screen._music = music
	screen._count_up.music = music
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	balance.quotas = PackedInt32Array([screen.run.quota()])
	screen.run.balance = balance
	assert_bool(screen.run.is_last_shift()).is_true()
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.WON)
	assert_bool(screen._results.visible).is_true()
	assert_bool(screen._reward_panel.visible).is_false()
	var count_up: CountUp = screen._count_up
	assert_array(_names_of(_dessert_sounds(sfx, count_up))).is_equal(
		["total", "pass", "stamp_paid", "rip"]
	)
	assert_str(_lines(screen._receipt)[-2]).is_equal("+€75 OVER QUOTA | PAID")
	assert_bool(_last_event("count_up").is_empty()).is_false()


## An upgrade shift (shift 2), through the real checkout: the same dessert (total, pass, PAID,
## the tear) and the print-out at the printer feed, which lifts and arms; the tickets follow it.
func test_an_upgrade_shift_plays_the_dessert_then_the_printout() -> void:
	var screen: ShiftScreen = await _screen()
	screen._count_up.music = null
	var sfx: Sfx = _recording_sfx(screen)
	var run: RunState = screen.run
	assert_bool(run.balance.upgrade_shifts.has(2)).is_true()
	await _place(screen, PASSING_ROW)
	await screen._on_checkout_pressed()
	screen._on_reward_skipped()
	assert_int(run.shift_index).is_equal(1)
	sfx.clear()
	await _place(screen, PASSING_ROW)
	await screen._on_checkout_pressed()
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
	var count_up: CountUp = screen._count_up
	var heard: Array[String] = _names_of(_dessert_sounds(sfx, count_up))
	prints("#61 upgrade shift:", heard)
	assert_array(heard.slice(0, 4)).is_equal(["total", "pass", "stamp_paid", "rip"])
	var paid: int = 0
	for line: String in _lines(screen._receipt):
		paid += int(line.ends_with("OVER QUOTA | PAID"))
	assert_int(paid).is_equal(1)
	var panel: RewardPanel = screen._reward_panel
	assert_bool(panel.is_printout()).is_true()
	assert_int(panel.timeline._shown_at).is_equal(count_up.printer_feed_ms)
	var start: int = Time.get_ticks_msec()
	while panel.is_arming() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(panel.is_arming()).is_false()
	assert_bool(panel.is_lifting()).is_false()
	screen._on_reward_skipped()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	assert_bool(screen._upgrade_panel.visible).is_true()


## A skipped dessert (two taps) leaves the same receipt and plays the same sounds, in order.
func test_a_skipped_dessert_leaves_the_same_receipt_and_sounds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	for quota: int in [34, 200]:
		sfx.clear()
		_play(screen, quota, NOTICE)
		await _played(screen)
		var untouched: Array[String] = _lines(screen._receipt)
		var sounds: Array[String] = _names_of(_dessert_sounds(sfx, count_up))
		var took: int = count_up.printer_feed_ms - count_up.total_shown_ms
		sfx.clear()
		_play_skipped(screen, quota, NOTICE)
		await _played(screen)
		assert_bool(count_up.dessert_skipped).is_true()
		assert_array(_lines(screen._receipt)).is_equal(untouched)
		assert_array(_names_of(_dessert_sounds(sfx, count_up))).is_equal(sounds)
		if quota == 34:
			assert_int(count_up.printer_feed_ms - count_up.total_shown_ms).is_less(
				floori(took / 3.0)
			)
		for line: Node in screen._receipt._lines.get_children():
			assert_float((line as CanvasItem).modulate.a).is_equal(1.0)


## After the verdict the speed setting applies but not the auto speed-up: on shift 3 (auto
## x1.25) the feed comes at 700 ms; with Fast (x1.5) at about 467.
func test_the_dessert_runs_at_the_speed_setting_without_the_auto_speed_up() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	_play(screen, 34, "", CountUpContext.new(3, 0))
	await _played(screen)
	assert_float(count_up.plan.base_speed).is_equal_approx(1.25, 0.001)
	_assert_ms(count_up.printer_feed_ms - count_up.total_shown_ms, count_up, _feed_ms(), "feed")
	sfx.clear()
	_play(screen, 34, "", CountUpContext.new(3, 0, 1.5))
	await _played(screen)
	assert_float(count_up.plan.speed_setting).is_equal(1.5)
	_assert_ms(
		count_up.printer_feed_ms - count_up.total_shown_ms,
		count_up,
		roundi(_feed_ms() / 1.5),
		"feed at Fast"
	)


## A miss at Fast (x1.5): the waits run faster but `fail` plays in real time, so the receipt
## still tears only once it has rung out.
func test_a_miss_at_fast_tears_after_the_fail_has_rung_out() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	_play(screen, 200, "", CountUpContext.new(1, 0, 1.5))
	await _played(screen)
	var heard: Array[Dictionary] = _dessert_sounds(sfx, count_up)
	assert_array(_names_of(heard)).is_equal(["miss", "fail", "rip"])
	var fail_end: int = _ms_of(heard[1], count_up) + roundi(sfx.sound_length("fail") * 1000.0)
	var rip_ms: int = _ms_of(heard[2], count_up)
	prints("#61 miss at Fast: fail ends", fail_end, "rip", rip_ms)
	assert_int(rip_ms).is_greater_equal(fail_end + roundi(_tuning.dessert_tear_ms / 1.5) - EARLY_MS)
	assert_int(Time.get_ticks_msec() - count_up.total_shown_ms).is_greater_equal(fail_end)


## Reduced motion: the slam fades in at full size and nothing shakes; the sounds stay.
func test_reduced_motion_slams_at_full_size_without_a_shake() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = _recording_sfx(screen)
	await _place(screen, PASSING_ROW)
	var count_up: CountUp = screen._count_up
	var rest: float = screen._register.position.x
	_play(screen, 34, "", CountUpContext.new(1, 0, 1.0, true))
	var slam_frames: int = 0
	var moved: Array[String] = []
	while count_up._playing:
		await get_tree().process_frame
		if not count_up._verdict_shown:
			continue
		var slam: Label = _slam_label(screen)
		if slam != null:
			slam_frames += 1
			if slam.scale != Vector2.ONE:
				moved.append("slam at scale %s" % slam.scale)
		if screen._register.position.x != rest:
			moved.append("register at %s" % screen._register.position.x)
	assert_int(slam_frames).is_greater(2)
	assert_array(moved).override_failure_message("\n".join(moved)).is_empty()
	assert_array(_names_of(_dessert_sounds(sfx, count_up))).is_equal(
		["total", "pass", "stamp_paid", "rip"]
	)


## The slam's shake: 10 px on a pass and 4 on a miss, a quarter more for a large total and half
## more for a huge one.
func test_the_shake_steps_up_with_the_intensity() -> void:
	var intensity: CountUpIntensity = CountUpIntensity.new()
	assert_float(CountUpDessert.shake_px(true, null, _tuning)).is_equal(10.0)
	assert_float(CountUpDessert.shake_px(false, intensity, _tuning)).is_equal(4.0)
	intensity.is_large = true
	assert_float(CountUpDessert.shake_px(true, intensity, _tuning)).is_equal(12.5)
	assert_float(CountUpDessert.shake_px(false, intensity, _tuning)).is_equal(5.0)
	intensity.is_huge = true
	assert_float(CountUpDessert.shake_px(true, intensity, _tuning)).is_equal(15.0)
	assert_float(CountUpDessert.shake_px(false, intensity, _tuning)).is_equal(6.0)


# --- Helpers ---------------------------------------------------------------------------------


## Follows the dessert frame by frame until play() returns: the slam (as drawn, scaled) stays
## inside the screen on every frame and lands on the TOTAL line (as it is on the slam's last
## frame: the receipt then scrolls to its new lines). Returns the failures.
func _watch_dessert(screen: ShiftScreen) -> Array[String]:
	var count_up: CountUp = screen._count_up
	var failures: Array[String] = []
	var slam_seen: bool = false
	var last_slam: Rect2 = Rect2()
	var total: Rect2 = Rect2()
	while count_up._playing:
		await get_tree().process_frame
		var slam: Label = _slam_label(screen)
		if slam == null:
			continue
		slam_seen = true
		last_slam = _drawn_rect(slam)
		total = screen._receipt.total_label().get_global_rect()
		if not SCREEN_RECT.grow(1.0).encloses(last_slam):
			failures.append("slam outside the screen at %s" % last_slam)
	if not slam_seen:
		failures.append("no slam")
	if last_slam.get_center().distance_to(total.get_center()) > 4.0:
		failures.append("slam landed at %s, TOTAL at %s" % [last_slam, total])
	return failures


## A control's rect as drawn: its size through its global transform (scale and pivot included).
static func _drawn_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform()
	return Rect2(xform * Vector2.ZERO, Vector2.ZERO).expand(xform * control.size)


## The receipt's last `count` lines, after a few frames: inside the receipt's scroll area and
## the screen, one under the other without overlapping.
func _assert_lines_on_screen(screen: ShiftScreen, count: int) -> void:
	for frame: int in range(3):
		await get_tree().process_frame
	var lines: Array[Node] = screen._receipt._lines.get_children()
	var scroll: Rect2 = screen._receipt._scroll.get_global_rect().grow(1.0)
	var above: Rect2 = Rect2()
	for line: Node in lines.slice(-count):
		var rect: Rect2 = (line as Control).get_global_rect()
		assert_bool(rect.size.y > 0.0).is_true()
		assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
		(
			assert_bool(scroll.encloses(rect))
			. override_failure_message("%s outside %s" % [rect, scroll])
			. is_true()
		)
		if above.size != Vector2.ZERO:
			assert_float(rect.position.y).is_greater_equal(above.end.y)
		above = rect


## The slam label flying over the overlay, or null.
static func _slam_label(screen: ShiftScreen) -> Label:
	for child: Node in screen._overlay.get_children():
		var label: Label = child as Label
		if label != null and not label.is_queued_for_deletion() and label.text.contains(" / €"):
			return label
	return null


## The sounds played after the verdict, in order, but the UI's and the coins' (the results).
static func _dessert_sounds(sfx: Sfx, count_up: CountUp) -> Array[Dictionary]:
	var heard: Array[Dictionary] = []
	for entry: Dictionary in sfx.get("sounds"):
		var sound: String = String(entry["sound"])
		if sound.begins_with("ui_") or sound.begins_with("coin"):
			continue
		if floori(int(entry["usec"]) / 1000.0) > count_up.total_shown_ms:
			heard.append(entry)
	return heard


static func _names_of(heard: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in heard:
		names.append(String(entry["sound"]))
	return names


## A sound's time after the verdict, in ms.
static func _ms_of(entry: Dictionary, count_up: CountUp) -> int:
	return floori(int(entry["usec"]) / 1000.0) - count_up.total_shown_ms


func _assert_at(entry: Dictionary, count_up: CountUp, planned_ms: int) -> void:
	_assert_ms(_ms_of(entry, count_up), count_up, planned_ms, str(entry))


## A step `at_ms` after the verdict, planned `planned_ms` after it, within the frames that ran
## (recorded since _play). The dessert's first wait is a tween stepped in the verdict's own frame
## with that frame's delta (time that passed before the verdict), so a step can come up to that
## delta early; each wait ends on a frame, so it can come LATE_MS late, plus the longest frame
## between the verdict and the step (a stall under load). Normal headless frames are 7 to 16 ms.
func _assert_ms(at_ms: int, count_up: CountUp, planned_ms: int, what: String) -> void:
	var verdict_end: int = (count_up.total_shown_ms + 1) * 1000
	var step_end: int = (count_up.total_shown_ms + at_ms + 1) * 1000
	var verdict_delta: float = 0.0
	var longest: float = 0.0
	for index: int in range(_frame_usec.size()):
		if _frame_usec[index] < verdict_end:
			verdict_delta = _frame_delta_ms[index]
		elif _frame_usec[index] < step_end:
			longest = maxf(longest, _frame_delta_ms[index])
	var earliest: int = planned_ms - ceili(verdict_delta) - 5
	var latest: int = planned_ms + LATE_MS + ceili(longest)
	(
		assert_int(at_ms)
		. override_failure_message(
			(
				"%s at %d ms, planned %d: allowed %d to %d (verdict frame %.1f ms, longest %.1f ms)"
				% [what, at_ms, planned_ms, earliest, latest, verdict_delta, longest]
			)
		)
		. is_between(earliest, latest)
	)


## A pass's printer feed after the verdict at speed 1: the slam, the margin, PAID, the tear and
## the feed's wait (700 ms).
func _feed_ms() -> int:
	return (
		_tuning.dessert_slam_delay_ms
		+ _tuning.dessert_slam_ms
		+ _tuning.dessert_margin_ms
		+ _tuning.dessert_paid_ms
		+ _tuning.dessert_tear_ms
		+ _tuning.dessert_feed_ms
	)


## Records a frame's start and delta for _assert_ms. Connected before the count-up plays, so it
## runs before the count-up's own process_frame awaits in each frame (the verdict's included).
func _record_frame() -> void:
	_frame_usec.append(Time.get_ticks_usec())
	_frame_delta_ms.append(get_process_delta_time() * 1000.0)
	if _timed != null and not _timed._playing:
		get_tree().process_frame.disconnect(_record_frame)


static func _color(label: Label) -> Color:
	return label.get_theme_color("font_color")


## The label at `index` of the receipt line at `line_index` (negative from the end).
static func _line_label(receipt: ReceiptView, line_index: int, index: int) -> Label:
	var lines: Array[Node] = receipt._lines.get_children()
	return lines[line_index].get_child(index) as Label


## A receipt's lines as text ("left | right"; "---" for the rule above the total).
static func _lines(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HSeparator:
			lines.append("---")
			continue
		var texts: PackedStringArray = PackedStringArray()
		for label: Node in line.get_children():
			texts.append((label as Label).text)
		lines.append(" | ".join(texts))
	return lines


## Plays the screen's row against `quota` with `notice`, untouched and without music.
func _play(
	screen: ShiftScreen, quota: int, notice: String = "", context: CountUpContext = null
) -> void:
	var count_up: CountUp = screen._count_up
	count_up.music = null
	_timed = count_up
	_frame_usec.clear()
	_frame_delta_ms.clear()
	if not get_tree().process_frame.is_connected(_record_frame):
		get_tree().process_frame.connect(_record_frame)
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		quota,
		context if context != null else CountUpContext.new(1, 0),
		screen._loyalty_card.stamped_boxes(),
		LoyaltyCard.names(screen.run.upgrades),
		screen._inspection_tag.sources(screen.run.inspections),
		InspectionTag.names(screen.run.inspections),
		notice
	)


## As _play, tapped twice at once: the count and the dessert at skip speed.
func _play_skipped(screen: ShiftScreen, quota: int, notice: String = "") -> void:
	_play(screen, quota, notice)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())


func _played(screen: ShiftScreen) -> void:
	while screen._count_up._playing:
		await get_tree().process_frame


func _recording_sfx(screen: ShiftScreen) -> Sfx:
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	return sfx


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	for frame: int in range(2):
		await get_tree().process_frame
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	assert_int(screen.run.preview().total).is_equal(ROW_TOTAL)
	for frame: int in range(3):
		await get_tree().process_frame


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


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
