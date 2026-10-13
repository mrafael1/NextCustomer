extends GdUnitTestSuite
## The run's final receipt (#61, ResultsPanel and FinalReceipt) on the real shift screen: its
## lines and their order (the headline, one line per played shift with the upgrade and the
## inspection on a dim second line, the shortfall on a loss, the coins at the bottom), the print
## one line every final_line_ms, a tap printing the rest at once, New run armed mid-print, the
## coins clinking and the music ducking when the coin lines print, and the layout: 8 shifts, the
## stapled loyalty card with a starting-upgrade box and the coins fit 1280x720 unclipped. The
## real saves, logs and Music bus level are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const MUSIC_SCRIPT := preload("res://presentation/music.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The longest names of each kind, for the widest lines.
const LONG_CARD := "res://data/cards/breakfast_sticker.tres"
const LONG_UPGRADE := "res://data/upgrades/extra_coupon_slot.tres"
const LONG_INSPECTION := "res://data/inspections/coupon_slot_closed.tres"
const STARTING_UPGRADE := "res://data/upgrades/big_basket.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const UPGRADES: Array[String] = [
	"res://data/upgrades/coupon_engine.tres",
	"res://data/upgrades/category_engine.tres",
	"res://data/upgrades/extra_coupon_slot.tres",
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


## A run lost on shift 2: the headline, a rule, shift 1 (passed, reward skipped, its inspection
## on a dim second line), shift 2 (failed), the shortfall, a rule and the coins, "you have ?"
## when the profile wasn't saved. Shift and coin lines are FinalReceipt.WIDTH wide or less.
func test_a_lost_run_lists_its_shifts_then_the_shortfall_and_the_coins() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var first: ShiftRecord = ShiftRecord.new(1, 34, 109)
	first.reward_skipped = true
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
	var shortfall: String = "Shift 2 / %d: short by €%d" % [run.shift_count(), run.quota() - 20]
	var payout: CoinPayout = CoinPayout.for_run(run)
	var expected: Array = ["RUN OVER", rule]
	(
		expected
		. append_array(
			[
				"  1  €109 / €34     pass  skipped",
				"     inspection Spot check",
				"  2  €20 / €35      fail  —",
				shortfall,
				rule,
			]
		)
	)
	expected.append_array(Array(FinalReceipt.coin_lines(payout, -1)))
	assert_array(Array(texts)).is_equal(expected)
	assert_str(texts[-1]).ends_with("you have ?")
	assert_int(screen._results.coin_line_index()).is_equal(7)
	for index: int in [2, 4, 7, 8, 9]:
		assert_int(texts[index].length()).is_less_equal(FinalReceipt.WIDTH)


## The receipt prints one line every final_line_ms from the show (none early, none more than
## LATE_MS late), and New run arms 350 ms in, mid-print, once the mouse is up.
func test_the_receipt_prints_line_by_line_and_new_run_arms_mid_print() -> void:
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
		if armed_ms < 0 and not results._new_run_button.disabled:
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


## A won 8-shift run with the longest names, an upgrade and an inspection on every shift and a
## starting upgrade: the printed receipt fits 1280x720 below the top bar, unclipped; every line
## is inside the paper; no two lines overlap; the loyalty card (one box per upgrade shift plus
## the starting upgrade's) is in the paper's top-right corner and covers no line; the coins are
## at the bottom, above the buttons.
func test_a_full_receipt_fits_the_screen_with_the_card_and_the_coins() -> void:
	var screen: ShiftScreen = await _screen()
	_full_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	results.skip_printing()
	await _frames(15)
	assert_int(results.texts().size()).is_equal(2 + 8 * 2 + 1 + 3)
	var paper: Rect2 = results.get_global_rect()
	prints("#61 final receipt:", paper)
	assert_bool(SCREEN_RECT.encloses(paper)).is_true()
	# Below the top bar (64 px), which keeps Export log and Deck reachable.
	assert_float(paper.position.y).is_greater_equal(64.0)
	var card: Rect2 = results._loyalty_card.get_global_rect()
	assert_bool(paper.encloses(card)).is_true()
	assert_float(card.end.x).is_greater(paper.end.x - 40.0)
	assert_float(card.position.y).is_less(paper.position.y + 40.0)
	assert_int(results._loyalty_card.box_texts().size()).is_equal(
		screen.run.balance.upgrade_shifts.size() + 1
	)
	assert_str(results._loyalty_card.box_texts()[0]).is_equal("BiB")
	var previous: Rect2 = Rect2()
	for index: int in range(results._lines.size()):
		var line: Label = results._lines[index]
		var rect: Rect2 = line.get_global_rect()
		assert_bool(paper.encloses(rect)).override_failure_message(line.text).is_true()
		assert_float(rect.size.x).is_greater_equal(line.get_minimum_size().x - 0.5)
		assert_bool(rect.intersects(card)).override_failure_message(line.text).is_false()
		if index > 0:
			assert_float(rect.position.y).is_greater_equal(previous.end.y - 0.5)
		previous = rect
	var new_run: Rect2 = results._new_run_button.get_global_rect()
	assert_bool(paper.encloses(new_run)).is_true()
	assert_float(new_run.position.y).is_greater_equal(previous.end.y)
	assert_str(results.texts()[-1]).starts_with("COINS +")


## The won run of the layout test: 8 passed shifts with the longest card, upgrade and
## inspection names, totals of four digits, and a starting upgrade on the loyalty card.
func _full_run(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
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
		record.card_picked = load(LONG_CARD)
		record.upgrade_taken = load(LONG_UPGRADE)
		record.inspection = load(LONG_INSPECTION)
		history.append(record)
	run.history = history
	run.shift_index = run.shift_count() - 1
	run.phase = RunState.Phase.WON


func _last_result(screen: ShiftScreen) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = screen.run.history[-1].total
	return result


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
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
