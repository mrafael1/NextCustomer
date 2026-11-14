extends GdUnitTestSuite
## The final receipt's BEST line on the real shift screen (v1.37, ReceiptHighlight, the approved
## direction A of docs/art/mockups/receipt_highlight.html): it prints between the second rule and
## the coins, across the receipt, on a gold band inside the paper, its sticker and mini in its
## indent; the won 16-shift receipt (week columns) and a run lost in week 1 (one column) fit
## 1280x720 and 1920x1080 with it. The coins wait for its wipe, slam and hold; a tap prints it in
## its final state. A run with nothing to show prints no line. The real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"
const LONG_CARD := "res://data/cards/breakfast_sticker.tres"
const LONG_INSPECTION := "res://data/inspections/short_belt.tres"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A won 16-shift run (week columns, a ticket after every shift, the longest names): the BEST
## line is the Biggest payout's, after the second rule and before the coins, out of the columns,
## its band inside the paper between the rule and the coins, as wide as the rules; its sticker
## and Golden milk mini sit in its indent, on the band. It fits both window sizes.
func test_the_won_receipt_prints_the_line_between_the_history_and_the_coins() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		_won_run(screen)
		var results: ResultsPanel = screen._results
		screen._show_results(_last_result(screen))
		results.skip_printing()
		await _frames(6)
		var highlight: ReceiptHighlight = results.highlight()
		assert_object(highlight).is_not_null()
		var texts: PackedStringArray = results.texts()
		var at: int = results.coin_line_index() - 1
		assert_str(texts[at]).contains("Biggest payout · Golden milk · 1800€")
		assert_str(texts[at]).ends_with("shift 14")
		assert_str(texts[at - 1]).is_equal(FinalReceipt.rule(FinalReceipt.WIDE_WIDTH))
		assert_object(results._lines[at]).is_same(highlight)
		assert_bool(results.week_columns().has(highlight.get_parent())).is_false()
		_assert_inside_the_receipt(results, at, window)
		assert_object(highlight.mini_texture()).is_same(
			load((load(MILK_GOLDEN) as CardDefinition).badge_mini_ref())
		)
		# As wide as the rules (both columns), the band a little wider.
		var rule: Rect2 = results._lines[at - 1].get_global_rect()
		assert_float(highlight.band_rect().size.x).is_greater_equal(rule.size.x - 1.0)


## A run lost in week 1 (one column): Closest call, the same place, inside the paper at both
## sizes; its mini is the quota target.
func test_a_lost_receipt_in_one_column_prints_the_line_too() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		var run: RunState = screen.run
		var history: Array[ShiftRecord] = [
			_record(1, 30, 31, "milk", 6), _record(2, 35, 40, "eggs", 8), _record(3, 36, 20, "", 0)
		]
		run.history = history
		run.shift_index = 2
		run.limits.quota = 36
		run.phase = RunState.Phase.LOST
		var results: ResultsPanel = screen._results
		screen._show_results(_last_result(screen))
		results.skip_printing()
		await _frames(6)
		assert_array(results.week_columns()).is_empty()
		var at: int = results.coin_line_index() - 1
		assert_str(results.texts()[at]).contains("Closest call · Shift 1 · 31€ / 30€")
		# The text names its shift: no "shift 1" on the right, and the line fits the receipt.
		assert_str(results.texts()[at]).not_contains(FinalReceipt.HIGHLIGHT_SHIFT % 1)
		assert_int(results.texts()[at].length()).is_less_equal(FinalReceipt.WIDTH)
		assert_object(results.highlight().mini_texture()).is_same(ReceiptHighlight.QUOTA_ICON)
		_assert_inside_the_receipt(results, at, window)


## The print: the BEST line prints in its turn and plays (the band wipes in), and the coins wait
## for its wipe, slam and hold; a tap shows it in its final state (the whole band, not playing).
func test_the_coins_wait_for_the_line_and_a_tap_finishes_it() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	_won_run(screen)
	var results: ResultsPanel = screen._results
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	screen._show_results(_last_result(screen))
	var times: PackedInt32Array = results.print_times()
	var coins: int = results.coin_line_index()
	var extra: int = (
		tuning.final_highlight_wipe_ms
		+ tuning.final_highlight_slam_ms
		+ tuning.final_highlight_hold_ms
	)
	assert_int(extra).is_between(550, 750)
	assert_int(times[coins - 1]).is_equal((coins - 1) * tuning.final_line_ms)
	assert_int(times[coins]).is_equal(coins * tuning.final_line_ms + extra)
	var start: int = Time.get_ticks_msec()
	while results.printed_count() < coins and Time.get_ticks_msec() - start < 8000:
		await get_tree().process_frame
	assert_int(results.printed_count()).is_equal(coins)
	assert_bool(results.highlight().is_playing()).is_true()
	results.skip_printing()
	assert_bool(results.highlight().is_playing()).is_false()
	assert_float(results.highlight().band_rect().size.x).is_greater(results.highlight().size.x)


## Reduced motion: no wipe or slam, the hold stays.
func test_reduced_motion_keeps_only_the_hold() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	_won_run(screen)
	var results: ResultsPanel = screen._results
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	screen._show_results(_last_result(screen))
	var coins: int = results.coin_line_index()
	assert_int(results.print_times()[coins]).is_equal(
		coins * tuning.final_line_ms + tuning.final_highlight_hold_ms
	)


## No payout recorded and nothing at its bar (a run saved before v1.37): no BEST line.
func test_a_run_with_nothing_to_show_prints_no_line() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = [ShiftRecord.new(1, 30, 40), ShiftRecord.new(2, 35, 10)]
	run.history = history
	run.shift_index = 1
	run.limits.quota = 35
	run.phase = RunState.Phase.LOST
	screen._show_results(_last_result(screen))
	screen._results.skip_printing()
	assert_object(screen._results.highlight()).is_null()
	var tones: Array = Array(screen._results.texts()).filter(
		func(text: String) -> bool: return text.contains("·")
	)
	assert_array(tones).is_empty()


## The BEST line (line `at`) and its parts inside the paper, the paper on screen below the top
## bar; the band below the rule above it and above the first coin line; the sticker and mini on
## the band, in the indent before the text.
func _assert_inside_the_receipt(results: ResultsPanel, at: int, window: Vector2i) -> void:
	var paper: Rect2 = results.get_global_rect()
	var visible_rect: Rect2 = get_tree().root.get_visible_rect()
	prints("v1.37 BEST line:", window, paper, "fit", results._fit)
	assert_bool(visible_rect.encloses(paper)).override_failure_message(str(window)).is_true()
	assert_float(paper.position.y).is_greater_equal(ShiftStage.PANEL_TOP)
	var highlight: ReceiptHighlight = results.highlight()
	var band: Rect2 = highlight.band_rect()
	assert_bool(paper.encloses(band)).override_failure_message(str(band)).is_true()
	var rule: Rect2 = results._lines[at - 1].get_global_rect()
	var coin: Rect2 = results._lines[at + 1].get_global_rect()
	assert_float(band.position.y).is_greater_equal(rule.end.y - 0.5)
	assert_float(band.end.y).is_less_equal(coin.position.y + 0.5)
	var line: Rect2 = highlight.get_global_rect()
	var font: Font = highlight.get_theme_font("font")
	var font_size: int = highlight.get_theme_font_size("font_size")
	var indent: float = (
		font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		* highlight.indent_chars()
	)
	# The sticker may overhang the band (STICKER_OVERHANG of its height), the mini may not; both
	# stay in the paper and the indent. The sticker is its art at a whole-number scale.
	var overhang: float = band.size.y * ReceiptHighlight.STICKER_OVERHANG + 1.0
	var hangs: Array[float] = [overhang, 0.0]
	var parts: Array[Rect2] = [highlight.sticker_rect(), highlight.mini_rect()]
	for index: int in range(parts.size()):
		var part: Rect2 = parts[index]
		var room: Rect2 = band.grow_individual(0.5, hangs[index] + 0.5, 0.5, hangs[index] + 0.5)
		assert_bool(room.encloses(part)).override_failure_message(str(part)).is_true()
		assert_bool(paper.encloses(part)).override_failure_message(str(part)).is_true()
		assert_float(part.end.x).is_less_equal(line.position.x + indent + 0.5)
		assert_float(part.size.x).is_greater(0.0)
	# Its scale (in the line's own coordinates; the receipt itself may be scaled to fit) is in
	# half steps, whole from 2; week columns indent more, so the sticker is at least as big.
	var scale: float = highlight.sticker_scale()
	assert_float(scale).is_greater_equal(1.0)
	assert_float(scale * 2.0).is_equal(roundf(scale * 2.0))
	if scale > 2.0:
		assert_float(scale).is_equal(roundf(scale))
	var wide: bool = not results.week_columns().is_empty()
	assert_int(highlight.indent_chars()).is_equal(
		FinalReceipt.HIGHLIGHT_INDENT_WIDE if wide else FinalReceipt.HIGHLIGHT_INDENT
	)
	assert_float(scale).is_greater_equal(1.5)
	assert_bool(highlight.sticker_rect().intersects(highlight.mini_rect())).is_false()


## results_panel_test's won 16-shift run (a ticket after every shift with the longest card name,
## the inspected shifts' longest inspection), each shift's best item Milk paying a fifth of its
## quota, and Golden milk paying 1800€ on shift 14.
func _won_run(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = []
	for shift: int in range(1, run.shift_count() + 1):
		var record: ShiftRecord = _record(shift, 923, 1234, "milk", 184)
		if shift == 14:
			record.best_card = load(MILK_GOLDEN)
			record.best_payout = 1800
		if shift < run.shift_count():
			var ticket: MachineVisit = MachineVisit.new()
			ticket.chute = RewardMachine.Chute.NEW_ITEMS
			var card: MachinePrize = MachinePrize.new(
				MachinePrize.Kind.PRODUCT, MachinePrize.Rarity.COMMON, load(LONG_CARD)
			)
			var cards: Array[MachinePrize] = [card]
			ticket.set_drawn(cards)
			ticket.picked = 0
			record.visits.append(ticket)
		if run.balance.inspection_shifts.has(shift):
			record.inspection = load(LONG_INSPECTION)
		history.append(record)
	run.history = history
	run.shift_index = run.shift_count() - 1
	run.phase = RunState.Phase.WON


## A record whose best item is data/cards/<card_id>.tres paying `payout` ("": none).
static func _record(
	shift: int, quota: int, total: int, card_id: String, payout: int
) -> ShiftRecord:
	var record: ShiftRecord = ShiftRecord.new(shift, quota, total)
	if not card_id.is_empty():
		record.best_card = load("res://data/cards/%s.tres" % card_id)
		record.best_payout = payout
		record.played.assign([record.best_card])
	return record


func _last_result(screen: ShiftScreen) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = screen.run.history[-1].total
	return result


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
