extends GdUnitTestSuite
## The run's final receipt (#61, ResultsPanel and FinalReceipt) on the real shift screen: its
## lines and their order (the headline, one line per played shift with a dim line per RECEIPT
## REWARDS visit (#77) and the inspection under it, the shortfall on a loss, the coins at the
## bottom), the print
## one line every final_line_ms, a tap printing the rest at once, Return to menu armed mid-print
## (the one primary button; it no longer starts a run or opens the toy machines), the
## coins clinking and the music ducking when the coin lines print, and the layout: 8 shifts with
## their visits, the
## stapled loyalty card with a starting-upgrade box and the coins fit 1280x720 unclipped. The
## real saves, logs and Music bus level are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const MUSIC_SCRIPT := preload("res://presentation/music.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The longest names of each kind, for the widest lines.
const LONG_CARD := "res://data/cards/breakfast_sticker.tres"
const LONG_UPGRADE := "res://data/upgrades/category_engine.tres"
const LONG_INSPECTION := "res://data/inspections/short_belt.tres"
const STARTING_UPGRADE := "res://data/upgrades/big_basket.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const BOON := "res://data/inspections/quiet_morning.tres"
## The run's perks; the first at LV 3, so its box carries a level mark (v0.61, #108).
const UPGRADES: Array[String] = [
	"res://data/upgrades/coupon_engine_lv3.tres",
	"res://data/upgrades/category_engine.tres",
	"res://data/upgrades/extra_redraw.tres",
]
## A line prints no earlier than planned (less a ms of rounding), and at most this much later
## (frame boundaries in the headless runner).
const LATE_MS := 150
## A bus this close to a level is at it, in dB.
const NEAR_DB := 0.5
const SLACK_S := 0.12
## A payout big enough for the most coin sounds.
const BIG_PAYOUT := 40

var _folder: String = ""
var _window_size: Vector2i
var _bus_db: float = 0.0
var _tuning: CountUpTuning


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)
	_bus_db = AudioServer.get_bus_volume_db(_music_bus())
	_tuning = load(CountUp.TUNING_PATH)


func after_test() -> void:
	AudioServer.set_bus_volume_db(_music_bus(), _bus_db)
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A run lost on shift 2: the headline, a rule, shift 1 (passed, its visit binned and its
## inspection on dim lines), shift 2 (failed), the shortfall, a rule and the coins, "you have ?"
## when the profile wasn't saved. Shift and coin lines are FinalReceipt.WIDTH wide or less.
func test_a_lost_run_lists_its_shifts_then_the_shortfall_and_the_coins() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var first: ShiftRecord = ShiftRecord.new(1, 34, 109)
	var binned: MachineVisit = MachineVisit.new()
	binned.chute = RewardMachine.Chute.NEW_ITEMS
	binned.binned = true
	first.visits.append(binned)
	first.inspection = load(SPOT_CHECK)
	var second: ShiftRecord = ShiftRecord.new(2, 35, 20)
	second.passed = false
	run.history.assign([first, second])
	run.shift_index = 1
	run.phase = RunState.Phase.LOST
	var result: ScoreResult = ScoreResult.new()
	result.total = 20
	screen._results.show_results(run, result, -1)
	screen._results.skip_printing()
	var texts: PackedStringArray = screen._results.texts()
	var rule: String = FinalReceipt.rule()
	var shortfall: String = (
		"Shift 2 / %d missed the quota by %d€" % [run.shift_count(), run.quota() - 20]
	)
	var payout: CoinPayout = CoinPayout.for_run(run)
	var expected: Array = ["RUN OVER", rule]
	(
		expected
		. append_array(
			[
				"  1  109€ / 34€     pass",
				"     thrown away NEW ITEMS",
				"     inspection Spot check",
				"  2  20€ / 35€      fail",
				shortfall,
				rule,
			]
		)
	)
	expected.append_array(Array(FinalReceipt.coin_lines(payout, -1)))
	assert_array(Array(texts)).is_equal(expected)
	assert_str(texts[-1]).ends_with("(you have ?)")
	assert_int(screen._results.coin_line_index()).is_equal(8)
	for index: int in [2, 3, 5, 8, 9]:
		assert_int(texts[index].length()).is_less_equal(FinalReceipt.WIDTH)


## The receipt prints one line every final_line_ms from the show (none early, none more than
## LATE_MS late), and Return to menu arms 350 ms in, mid-print, once the mouse is up.
func test_the_receipt_prints_line_by_line_and_menu_arms_mid_print() -> void:
	var screen: ShiftScreen = await _screen()
	_full_run(screen)
	var results: ResultsPanel = screen._results
	var shown: int = Time.get_ticks_msec()
	screen._show_results(_last_result(screen))
	var printed_at: Array[int] = [0]
	var armed_ms: int = -1
	var armed_mid_print: bool = false
	while results.is_printing() and Time.get_ticks_msec() - shown < 5000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec() - shown
		while printed_at.size() < results.printed_count():
			printed_at.append(now)
		if armed_ms < 0 and not results.menu_button().disabled:
			armed_ms = now
			armed_mid_print = results.is_printing()
	var count: int = results.texts().size()
	assert_int(printed_at.size()).is_equal(count)
	assert_int(count).is_greater(20)
	for index: int in range(count):
		var planned: int = index * _tuning.final_line_ms
		assert_int(printed_at[index]).is_between(planned - 1, planned + LATE_MS)
	assert_bool(results.print_skipped).is_false()
	assert_int(armed_ms).is_between(ResultsPanel.ARM_MS, ResultsPanel.ARM_MS + LATE_MS)
	assert_bool(armed_mid_print).is_true()


## A tap (Space, through the panel's own PressReader) prints the rest at once: the same lines,
## and the coins still clink, from the tap on.
func test_a_tap_prints_the_rest_at_once() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	_full_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	await _frames(2)
	assert_bool(results.is_printing()).is_true()
	assert_int(results.coins_started_ms).is_equal(-1)
	var tapped_ms: int = Time.get_ticks_msec()
	results._reader._input(_space(true))
	results._reader._input(_space(false))
	assert_bool(results.print_skipped).is_true()
	assert_bool(results.is_printing()).is_false()
	assert_int(results.printed_count()).is_equal(results.texts().size())
	assert_int(results.coins_started_ms).is_between(tapped_ms, tapped_ms + 5)
	var expected: int = FinalReceipt.coin_sounds(CoinPayout.for_run(screen.run).total())
	assert_int(expected).is_greater(0)
	assert_float(results.coins_seconds()).is_equal_approx(expected * FinalReceipt.COIN_GAP, 0.001)
	await _frames(3)
	var start: int = Time.get_ticks_msec()
	while sfx.call("count", "coin") < expected and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_int(sfx.call("count", "coin")).is_equal(expected)
	for label: Label in results._lines:
		assert_float(label.modulate.a).is_equal(1.0)


## The coins wait for their lines: the music stays 24 dB down (from the dessert) while the lines
## above them print, ducks to 18 dB down when the first coin line prints, and the first coin
## clinks as the COINS line prints; the coins (capped) follow one gap apart, and the music comes
## back after the last.
func test_the_coins_and_their_duck_start_when_the_coin_lines_print() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	var music: MusicService = screen._music
	var base: float = music.base_db()
	music.duck(CountUp.DESSERT_DUCK_DB, 0.0)
	_full_run(screen)
	# Without the day events' dim lines, so the coins print well inside the check's 6 s.
	for record: ShiftRecord in screen.run.history:
		record.inspections = []
	var balance: BalanceDefinition = screen.run.balance.duplicate() as BalanceDefinition
	var table: PackedInt32Array = PackedInt32Array()
	table.resize(screen.run.shift_count() + 1)
	table.fill(BIG_PAYOUT)
	balance.coins_by_shifts_passed = table
	screen.run.balance = balance
	var results: ResultsPanel = screen._results
	var shown_us: int = Time.get_ticks_usec()
	screen._show_results(_last_result(screen))
	assert_str(str(music.current_track())).is_equal(ShiftMusic.RESULTS_MUSIC)
	var coin_line_ms: int = -1
	while Time.get_ticks_usec() - shown_us < 6_000_000:
		await get_tree().process_frame
		var now: int = floori((Time.get_ticks_usec() - shown_us) / 1000.0)
		if results.coins_started_ms < 0:
			assert_float(_bus_now()).is_less_equal(base + CountUp.DESSERT_DUCK_DB + NEAR_DB)
			continue
		if coin_line_ms < 0:
			coin_line_ms = now
		var since: float = (now - coin_line_ms) / 1000.0
		if since > ShiftMusic.COINS_DUCK_S + SLACK_S and since < results.coins_seconds() - SLACK_S:
			assert_float(_bus_now()).is_equal_approx(base + ShiftMusic.COINS_DUCK_DB, NEAR_DB)
		if since > results.coins_seconds() + ShiftMusic.UNDUCK_S + SLACK_S:
			break
	var planned_ms: int = results.coin_line_index() * _tuning.final_line_ms
	assert_int(coin_line_ms).is_between(planned_ms - 1, planned_ms + LATE_MS)
	assert_float(_bus_now()).is_equal_approx(base, 0.01)
	# The coin sounds: the most there are, the first as the COINS line (the last line) prints.
	var coins: Array[int] = []
	for entry: Dictionary in sfx.get("sounds"):
		if entry["sound"] == "coin":
			coins.append(floori((int(entry["usec"]) - shown_us) / 1000.0))
	assert_int(coins.size()).is_equal(FinalReceipt.MAX_COIN_SOUNDS)
	var total_line_ms: int = (results.texts().size() - 1) * _tuning.final_line_ms
	assert_int(coins[0]).is_between(total_line_ms - 1, total_line_ms + LATE_MS)
	var gap_ms: int = roundi(FinalReceipt.COIN_GAP * 1000.0)
	for index: int in range(1, coins.size()):
		assert_int(coins[index] - coins[index - 1]).is_between(0, gap_ms + LATE_MS)
	assert_int(coins[-1] - coins[0]).is_greater_equal((coins.size() - 1) * gap_ms - 20)


## A won 16-shift run (v0.96) with the longest names: a ticket after every shift, a payday's
## PREMIUM perk after each review but the last, an inspection, a review's two and a boon on their
## days by the live schedule, and a starting upgrade. The printed receipt is full (not compact)
## in two week columns, weeks 1-2 on the left and 3-4 on the right, each under its header; it fits
## 1280x720 below the top bar, unclipped; every line is inside the paper and its column, the
## columns side by side between the two rules, no two lines of a column overlap; the loyalty card
## (one box per upgrade shift plus the starting upgrade's) is in the paper's top-right corner and
## covers no line, the LV 3 perk's level mark inside its box; the coins are at the bottom, above
## the buttons.
func test_a_full_receipt_fits_the_screen_with_the_card_and_the_coins() -> void:
	var screen: ShiftScreen = await _screen()
	_full_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	results.skip_printing()
	await _frames(15)
	var balance: BalanceDefinition = screen.run.balance
	var count: int = screen.run.shift_count()
	assert_int(count).is_equal(16)
	assert_bool(results.is_compact()).is_false()
	var paydays: int = balance.machine.bonus_extra_shifts.size()
	var days: int = balance.inspection_shifts.size() + balance.review_shifts.size()
	days += balance.boon_shifts.size()
	# The headline, a rule, 4 week headers, the shifts, their visits and day events, a rule and
	# 2 coin lines (no overtime coin since v1.03).
	var expected: int = 2 + 4 + count + (count - 1) + paydays + days + 1 + 2
	assert_int(results.texts().size()).is_equal(expected)
	var headers: Array = Array(results.texts()).filter(
		func(text: String) -> bool: return text.begins_with("WEEK ")
	)
	assert_array(headers).is_equal(
		["WEEK 1 · TRAINING", "WEEK 2 · BAKERY", "WEEK 3 · HOLIDAY", "WEEK 4 · CLEARANCE"]
	)
	var paper: Rect2 = results.get_global_rect()
	prints("v0.96 final receipt:", paper, "fit", results._fit)
	assert_bool(SCREEN_RECT.encloses(paper)).is_true()
	# Below the top bar's height (64 px), the closed store's shutter showing above it.
	assert_float(paper.position.y).is_greater_equal(64.0)
	var card: Rect2 = results._loyalty_card.get_global_rect()
	assert_bool(paper.encloses(card)).is_true()
	assert_float(card.end.x).is_greater(paper.end.x - 40.0)
	assert_float(card.position.y).is_less(paper.position.y + 40.0)
	assert_int(results._loyalty_card.box_texts().size()).is_equal(
		screen.run.balance.machine.register_cap + 1
	)
	# Big basket's "+1" icon (#108 follow-up), so no initials.
	assert_str(results._loyalty_card.box_texts()[0]).is_empty()
	assert_str(results._loyalty_card.box_icon(0).resource_path).is_equal(
		"res://art/icons/perk_big_basket.png"
	)
	assert_object(results._loyalty_card.level_mark(0)).is_null()
	var mark: Control = results._loyalty_card.level_mark(1)
	assert_object(mark).is_not_null()
	assert_str((mark as Label).text).is_equal("3")
	var in_box: Array[Rect2] = results._loyalty_card.level_mark_in_box(1)
	(
		assert_bool(in_box[1].grow(0.01).encloses(in_box[0]))
		. override_failure_message(str(in_box))
		. is_true()
	)
	assert_bool(card.encloses(mark.get_global_rect())).is_true()
	# The two columns: side by side, between the rules, the right one starting at the middle.
	var columns: Array[VBoxContainer] = results.week_columns()
	assert_int(columns.size()).is_equal(2)
	var left: Rect2 = columns[0].get_global_rect()
	var right: Rect2 = columns[1].get_global_rect()
	assert_bool(left.intersects(right)).is_false()
	assert_float(right.position.x).is_greater_equal(left.end.x)
	assert_float(right.position.x).is_equal_approx(paper.get_center().x, 40.0)
	var rules: Array[Label] = []
	var previous: Dictionary[Node, Rect2] = {}
	for line: Label in results._lines:
		var rect: Rect2 = line.get_global_rect()
		assert_bool(paper.encloses(rect)).override_failure_message(line.text).is_true()
		assert_float(rect.size.x).is_greater_equal(line.get_minimum_size().x - 0.5)
		assert_bool(rect.intersects(card)).override_failure_message(line.text).is_false()
		var parent: Node = line.get_parent()
		if parent is VBoxContainer and columns.has(parent as VBoxContainer):
			var column: Rect2 = (parent as Control).get_global_rect()
			(
				assert_bool(column.grow(0.5).encloses(rect))
				. override_failure_message(line.text)
				. is_true()
			)
		if previous.has(parent):
			assert_float(rect.position.y).is_greater_equal(previous[parent].end.y - 0.5)
		previous[parent] = rect
		if line.text == FinalReceipt.rule(FinalReceipt.WIDE_WIDTH):
			rules.append(line)
	assert_int(rules.size()).is_equal(2)
	for column: Rect2 in [left, right]:
		assert_float(column.position.y).is_greater_equal(rules[0].get_global_rect().end.y)
		assert_float(column.end.y).is_less_equal(rules[1].get_global_rect().position.y)
		# The rules span both columns.
		assert_float(rules[0].get_global_rect().end.x).is_greater_equal(column.end.x - 1.0)
	# The left column holds weeks 1-2, the right one weeks 3-4: shift 9 starts the right one.
	var shift_nine: Label = results._lines[Array(results.texts()).find("WEEK 3 · HOLIDAY")]
	assert_object(shift_nine.get_parent()).is_same(columns[1])
	assert_float(shift_nine.get_global_rect().position.y).is_equal_approx(left.position.y, 0.5)
	var coins: Label = results._lines[-1]
	var menu: Rect2 = results.menu_button().get_global_rect()
	assert_bool(paper.encloses(menu)).is_true()
	assert_float(menu.position.y).is_greater_equal(coins.get_global_rect().end.y)
	assert_float(coins.get_global_rect().position.y).is_greater(rules[1].get_global_rect().end.y)
	assert_str(results.texts()[-1]).starts_with("COINS +")


## A run lost in week 3 (shift 11) also prints in week columns, its shortfall closing the right
## one under the failed shift; one lost in week 2 (shift 8) too, week 1 on the left and week 2
## on the right; one lost in week 1 (shift 4) prints in one column, as before.
func test_a_run_lost_in_week_three_prints_in_columns() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	for last: int in [11, 8, 4]:
		_full_run(screen)
		run.history = run.history.slice(0, last)
		run.history[-1].total = run.history[-1].quota - 5
		run.history[-1].passed = false
		run.history[-1].visits.clear()
		run.shift_index = last - 1
		run.limits.quota = run.history[-1].quota
		run.phase = RunState.Phase.LOST
		assert_bool(FinalReceipt.uses_columns(run)).is_equal(last > 4)
		assert_int(FinalReceipt.left_weeks(run)).is_equal({11: 2, 8: 1, 4: 0}[last])
		var results: ResultsPanel = screen._results
		screen._show_results(_last_result(screen))
		results.skip_printing()
		await _frames(4)
		var texts: PackedStringArray = results.texts()
		var shortfall: int = Array(texts).find("Shift %d / 16 missed the quota by 5€" % last)
		assert_int(shortfall).is_greater(0)
		assert_bool(results.is_compact()).is_false()
		if last == 4:
			assert_array(results.week_columns()).is_empty()
			assert_bool(texts[2].begins_with("WEEK")).is_false()
			continue
		var columns: Array[VBoxContainer] = results.week_columns()
		assert_object(results._lines[shortfall].get_parent()).is_same(columns[1])
		var paper: Rect2 = results.get_global_rect()
		assert_bool(SCREEN_RECT.encloses(paper)).is_true()
		assert_float(paper.position.y).is_greater_equal(64.0)
		for line: Label in results._lines:
			assert_bool(paper.encloses(line.get_global_rect())).is_true()


## #56: the store closes behind the receipt: the closed store covers the whole window, the top
## bar too, and sits just behind the receipt; it takes no clicks (the shade under it takes them
## below the top bar, so Cart and ☰ stay clickable); the shutter rolls down in SHUTTER_S.
func test_the_store_closes_behind_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	_full_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	await _frames(2)
	var closed: StoreClosed = results.store_closed()
	assert_bool(closed.is_visible_in_tree()).is_true()
	assert_bool(closed.get_global_rect().encloses(SCREEN_RECT)).is_true()
	assert_int(closed.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(screen._shade.visible).is_true()
	assert_int(screen._shade.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_float(screen._shade.get_global_rect().position.y).is_equal(ShiftStage.PANEL_TOP)
	assert_object(closed.get_parent()).is_same(results.get_parent())
	assert_int(closed.get_index()).is_equal(results.get_index() - 1)
	assert_float(closed.shutter()).is_less(1.0)
	await get_tree().create_timer(StoreClosed.SHUTTER_S + SLACK_S).timeout
	assert_float(closed.shutter()).is_equal(1.0)
	assert_float(closed.shutter_foot()).is_equal_approx(closed.size.y, 0.5)
	assert_float(closed.global_position.y + closed.shutter_foot()).is_equal_approx(
		SCREEN_RECT.end.y, 0.5
	)
	assert_bool(closed.focus.is_equal_approx(results.get_global_rect())).is_true()


## #56: under the profile's reduced motion the store is closed at once: the shutter down, the
## lights out.
func test_reduced_motion_closes_the_store_at_once() -> void:
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	_full_run(screen)
	screen._show_results(_last_result(screen))
	var closed: StoreClosed = screen._results.store_closed()
	assert_float(closed.shutter()).is_equal(1.0)
	assert_float(closed.shutter_foot()).is_equal_approx(closed.size.y, 0.5)


## The closed store's shutter reaches the window's bottom edge, so it covers the whole visible
## window; the CLOSED sign stays near the top, fully on screen, and clear of the receipt.
func test_the_closed_shutter_covers_the_whole_window() -> void:
	await _assert_the_closed_store_covers(Vector2i(SCREEN_RECT.size))


## The same in a larger window (more of the store shows under the expand stretch): the shutter
## still reaches the bottom edge and the sign still hangs near the top.
func test_the_closed_shutter_covers_a_larger_window() -> void:
	var visible_rect: Rect2 = await _assert_the_closed_store_covers(Vector2i(1600, 1000))
	# The larger window shows more of the store: taller than the 720 design height.
	assert_float(visible_rect.size.y).is_greater(SCREEN_RECT.size.y)


## The results' actions: Return to menu, the one primary (red-framed) button, then Export log
## (teal) on its right, both inside the receipt and centred on one row; no New run and no Toy
## machines (they are on the title's REWARDS). Return to menu arms after ARM_MS.
func test_return_to_menu_is_the_one_primary_action_and_arms() -> void:
	var screen: ShiftScreen = await _screen()
	_full_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	results.skip_printing()
	await _frames(3)
	var menu: FramedButton = results.menu_button()
	assert_str(menu.caption).is_equal("Return to menu")
	assert_bool(menu.disabled).is_true()
	var row: HBoxContainer = menu.get_parent() as HBoxContainer
	var captions: Array[String] = []
	for child: Node in row.get_children():
		captions.append((child as FramedButton).caption)
	assert_array(captions).is_equal(["Return to menu", TopBar.EXPORT_TEXT])
	var export: FramedButton = row.get_child(1) as FramedButton
	assert_object(_frame_of(menu)).is_same(UiKit.BUTTON_FRAME)
	assert_object(_frame_of(export)).is_same(TopBar.BUTTON_FRAME)
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(3)
	assert_bool(menu.disabled).is_false()
	var paper: Rect2 = results.get_global_rect()
	assert_bool(paper.encloses(menu.get_global_rect())).is_true()
	assert_bool(paper.encloses(export.get_global_rect())).is_true()
	assert_float(export.get_global_rect().position.x).is_greater_equal(menu.get_global_rect().end.x)
	var row_center: float = (
		(menu.get_global_rect().position.x + export.get_global_rect().end.x) / 2.0
	)
	assert_float(absf(row_center - paper.get_center().x)).is_less(1.0)


## Return to menu clicked mid-print prints the rest first (a skip), so the receipt stops printing
## and its PressReader stops reading presses as the screen leaves; it asks for the menu.
func test_return_to_menu_mid_print_finishes_the_print() -> void:
	var screen: ShiftScreen = await _screen()
	screen.changes_scene = false
	_full_run(screen)
	var results: ResultsPanel = screen._results
	var asked: Array[bool] = []
	results.menu_requested.connect(func() -> void: asked.append(true))
	screen._show_results(_last_result(screen))
	var shown: int = Time.get_ticks_msec()
	while results.menu_button().disabled and Time.get_ticks_msec() - shown < 3000:
		await get_tree().process_frame
	(
		assert_bool(results.menu_button().disabled)
		. override_failure_message(
			"not armed; mouse held: %s" % Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		)
		. is_false()
	)
	assert_bool(results.is_printing()).is_true()
	results.menu_button().pressed.emit()
	assert_bool(results.is_printing()).is_false()
	assert_int(results.printed_count()).is_equal(results.texts().size())
	assert_bool(results._reader.is_reading()).is_false()
	assert_array(asked).is_equal([true])
	assert_bool(TitleScreen.take_lit_request()).is_true()


## The won run of the layout test: 8 passed shifts with totals of four digits, a ticket visit
## after each of the first 7 (NEW ITEMS with the longest card name), and on the inspected shifts
## (the balance's, with the longest inspection name) a bonus visit (REGISTER with the longest
## upgrade name); a starting upgrade on the loyalty card.
func _full_run(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	var balance: BalanceDefinition = run.balance
	var starter: DeckDefinition = run.starter.duplicate() as DeckDefinition
	starter.starting_upgrade = load(STARTING_UPGRADE)
	run.starter = starter
	var upgrades: Array[UpgradeDefinition] = [load(STARTING_UPGRADE)]
	for path: String in UPGRADES:
		upgrades.append(load(path))
	run.upgrades = upgrades
	var history: Array[ShiftRecord] = []
	for shift: int in range(1, run.shift_count() + 1):
		var record: ShiftRecord = ShiftRecord.new(shift, 923, 1234)
		record.passed = true
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
		if balance.machine.is_payday_shift(shift) and shift < run.shift_count():
			var bonus: MachineVisit = MachineVisit.new(MachineVisit.Kind.BONUS, "payday")
			bonus.premium = true
			bonus.chute = RewardMachine.Chute.UPGRADE
			var register: MachinePrize = MachinePrize.new(
				MachinePrize.Kind.REGISTER, MachinePrize.Rarity.RARE, null, load(LONG_UPGRADE)
			)
			var registers: Array[MachinePrize] = [register]
			bonus.set_drawn(registers)
			bonus.picked = 0
			record.visits.append(bonus)
		var events: Array[InspectionDefinition] = []
		if balance.inspection_shifts.has(shift):
			events.append(load(LONG_INSPECTION))
		if balance.review_shifts.has(shift):
			events.append_array([load(LONG_INSPECTION), load(SPOT_CHECK)])
		if balance.boon_shifts.has(shift):
			events.append(load(BOON))
		record.inspections = events
		history.append(record)
	run.history = history
	run.shift_index = run.shift_count() - 1
	run.phase = RunState.Phase.WON


## The store closed (at once) behind the final receipt in a `window` sized window: the shutter
## encloses the visible window and its foot is the window's bottom edge; the sign is on screen,
## below the top bar, in the window's top half, and off the receipt. Returns the visible window.
func _assert_the_closed_store_covers(window: Vector2i) -> Rect2:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	_full_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	results.skip_printing()
	await _frames(3)
	var visible_rect: Rect2 = get_tree().root.get_visible_rect()
	var closed: StoreClosed = results.store_closed()
	assert_float(closed.shutter()).is_equal(1.0)
	var shutter: Rect2 = Rect2(
		closed.global_position, Vector2(closed.size.x, closed.shutter_foot())
	)
	assert_bool(shutter.grow(0.5).encloses(visible_rect)).is_true()
	assert_float(shutter.end.y).is_equal_approx(visible_rect.end.y, 0.5)
	var sign_rect: Rect2 = closed.sign_rect()
	assert_bool(visible_rect.encloses(sign_rect)).is_true()
	assert_float(sign_rect.position.y).is_greater_equal(ShiftStage.PANEL_TOP)
	assert_float(sign_rect.end.y).is_less(visible_rect.get_center().y)
	assert_bool(sign_rect.intersects(results.get_global_rect())).is_false()
	return visible_rect


func _last_result(screen: ShiftScreen) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = screen.run.history[-1].total
	return result


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	# A fresh MusicService (streaming off) in place of the autoload, on the shift loop.
	var music: MusicService = MUSIC_SCRIPT.new()
	music.streaming = false
	add_child(music)
	auto_free(music)
	screen._music = music
	screen._count_up.music = music
	music.play(ShiftMusic.SHIFT_MUSIC)
	await _frames(2)
	return screen


## The 9-slice texture a framed button's face is drawn with.
static func _frame_of(button: FramedButton) -> Texture2D:
	return (button.face().get_theme_stylebox("panel") as StyleBoxTexture).texture


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _space(pressed: bool) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = pressed
	return key


static func _bus_now() -> float:
	return AudioServer.get_bus_volume_db(_music_bus())


static func _music_bus() -> int:
	return AudioServer.get_bus_index(MusicService.BUS)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
