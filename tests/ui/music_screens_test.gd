extends GdUnitTestSuite
## The music on the real screens (#62, Q2, Q6): the title starts the front loop on its first
## click or key press, never before; on the shift screen the count-up ducks the Music bus 24 dB
## down as the pause before the total starts, so the dessert's slam lands in near-silence (#61),
## and it comes back when the reward panel appears (a pass), stays ducked through the fail
## sound then crossfades to the front loop and, once the final receipt prints its coin lines,
## ducks 18 dB down until the last coin (a fail), or comes back fast when a tap skips the
## dessert. The bus volume is read frame by frame (headless runs on the dummy audio driver).
## Each test plays on its own MusicService with streaming off; the real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"
const TITLE := "res://ui/title_screen.tscn"
const MUSIC_SCRIPT := preload("res://presentation/music.gd")
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## Milk, Multipack, Milk x5 = 109: passes shift 1's quota.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## Short of shift 1's quota: the run ends.
const FAILING_ROW: Array[String] = ["bread"]
## Slack for frame timing in the headless runner, in seconds.
const SLACK_S := 0.12
## A bus this close to a level is at it, in dB.
const NEAR_DB := 0.5
## About one frame of the headless runner, in ms.
const FRAME_MS := 20
## A payout big enough for the most coin sounds (FinalReceipt.MAX_COIN_SOUNDS).
const BIG_PAYOUT := 40

var _folder: String = ""
var _window_size: Vector2i
var _bus_db: float = 0.0


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)
	_autoload().unduck(0.0)
	_bus_db = _bus_now()


func after_test() -> void:
	_autoload().unduck(0.0)
	AudioServer.set_bus_volume_db(_music_bus(), _bus_db)
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Nothing plays until the title's first click or key press (browsers block audio before
## one); that press starts the front loop once it has been handled, and later presses don't
## restart it.
func test_the_title_starts_the_front_loop_on_its_first_press() -> void:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	var music: MusicService = _music()
	title._music = music
	await _frames(3)
	title._input(InputEventMouseMotion.new())
	var release: InputEventKey = InputEventKey.new()
	release.keycode = KEY_A
	title._input(release)
	assert_str(str(music.current_track())).is_equal("")
	title._input(_left_click())
	await _frames(1)
	assert_str(str(music.current_track())).is_equal(TitleScreen.MUSIC)
	assert_int(music.track_starts).is_equal(1)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	title._input(key)
	await _frames(1)
	assert_int(music.track_starts).is_equal(1)
	assert_bool(TitleScreen.is_audio_gesture(key)).is_true()
	assert_bool(TitleScreen.is_audio_gesture(release)).is_false()
	assert_bool(TitleScreen.is_audio_gesture(InputEventMouseMotion.new())).is_false()


## A first press that starts the run (a background click without a save) starts no front loop:
## the shift screen starts its own loop next.
func test_a_first_press_that_starts_the_run_leaves_the_title_silent() -> void:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	var music: MusicService = _music()
	title._music = music
	await _frames(3)
	assert_object(title._saved_run).is_null()
	title._input(_left_click())
	title._on_background_input(_left_click())
	assert_bool(title._starting).is_true()
	await _frames(2)
	assert_str(str(music.current_track())).is_equal("")
	assert_int(music.track_starts).is_equal(0)


## With a run save, a first mouse press on Continue starts no front loop (the button starts the
## run on release); a first press elsewhere still starts it.
func test_a_first_press_on_continue_leaves_the_title_silent() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var deck: DeckDefinition = load("res://data/decks/starter.tres")
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var run: RunState = RunState.new(31, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	assert_bool(SaveService.new(_folder).save_run(run, "0011223344556677", 1000)).is_true()
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	var music: MusicService = _music()
	title._music = music
	await _frames(3)
	assert_object(title._saved_run).is_not_null()
	var on_continue: InputEventMouseButton = _left_click()
	on_continue.position = title._continue_button.get_global_rect().get_center()
	title._input(on_continue)
	await _frames(1)
	assert_int(music.track_starts).is_equal(0)
	title._input(_left_click())
	await _frames(1)
	assert_str(str(music.current_track())).is_equal(TitleScreen.MUSIC)


## The shift screen asks the autoload for the shift loop when it opens. The autoload is stopped
## first: earlier suites' shift screens leave it on the shift loop.
func test_the_shift_screen_plays_the_shift_loop() -> void:
	_autoload().stop()
	var starts: int = _autoload().track_starts
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	assert_object(screen._music).is_same(_autoload())
	assert_object(screen._count_up.music).is_same(_autoload())
	assert_str(str(_autoload().current_track())).is_equal(ShiftMusic.SHIFT_MUSIC)
	assert_int(_autoload().track_starts).is_equal(starts + 1)


## A pass, the count tapped once (the dessert plays at normal speed): the bus stays at its level
## through the count, ducks 24 dB over about 120 ms as the pause before the total starts (before
## the verdict, #61), is there when the slam lands at least 250 ms later and through the pass
## sound, and comes back over 600 ms once the reward panel appears.
func test_a_pass_ducks_the_dessert_and_comes_back_with_the_reward() -> void:
	var screen: ShiftScreen = await _screen()
	var music: MusicService = _inject_music(screen)
	var sfx: Sfx = _recording_sfx(screen)
	var base: float = music.base_db()
	await _place(screen, PASSING_ROW)
	screen._on_checkout_pressed()
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	var frames: Array[Dictionary] = await _record(screen, sfx, "_reward_panel", 0.6 + SLACK_S)
	assert_bool(screen._reward_panel.visible).is_true()
	assert_bool(screen._count_up.dessert_skipped).is_false()
	for frame: Dictionary in frames:
		if not frame["ducked"]:
			assert_float(frame["bus"]).is_equal_approx(base, 0.01)
	var ducked_ms: int = _first_ms(frames, func(f: Dictionary) -> bool: return f["ducked"])
	var verdict_ms: int = _first_ms(frames, func(f: Dictionary) -> bool: return f["verdict"])
	assert_int(ducked_ms).is_greater_equal(0)
	assert_int(ducked_ms).is_less(verdict_ms)
	var duck_ms: int = _first_ms(
		frames, func(f: Dictionary) -> bool: return f["bus"] < base - NEAR_DB
	)
	var deep_ms: int = _first_ms(
		frames, func(f: Dictionary) -> bool: return f["bus"] <= base - 24.0 + NEAR_DB
	)
	var slam_ms: int = _first_ms(
		frames, func(f: Dictionary) -> bool: return f["sounds"].has("total")
	)
	var pass_ms: int = _first_ms(
		frames, func(f: Dictionary) -> bool: return f["sounds"].has("pass")
	)
	var panel_ms: int = _first_ms(frames, func(f: Dictionary) -> bool: return f["panel"])
	prints("#62 pass: duck", duck_ms, "deep", deep_ms, "slam", slam_ms, "panel", panel_ms)
	assert_int(duck_ms).is_greater_equal(ducked_ms)
	assert_int(deep_ms - duck_ms).is_between(60, roundi((0.12 + SLACK_S) * 1000.0))
	assert_int(slam_ms - duck_ms).is_greater_equal(250)
	assert_int(pass_ms).is_greater(slam_ms)
	for frame: Dictionary in frames:
		if int(frame["ms"]) >= deep_ms and int(frame["ms"]) < panel_ms:
			assert_float(frame["bus"]).is_less_equal(base - 24.0 + NEAR_DB)
	_assert_rises_back(frames, panel_ms, base, 0.6)


## A fail: ducked through the whole fail sound (the front loop not started yet), then the
## results crossfade to the front loop, still 24 dB down while the final receipt prints (#61);
## its coin lines duck it 18 dB down until the last coin of a big payout (past COINS_PRINT_S),
## and it comes back over 600 ms after them. A new run from the debug panel goes back to the
## shift loop.
func test_a_fail_stays_ducked_then_the_results_duck_for_the_coins() -> void:
	var screen: ShiftScreen = await _screen()
	var music: MusicService = _inject_music(screen)
	var sfx: Sfx = _recording_sfx(screen)
	var base: float = music.base_db()
	await _place(screen, FAILING_ROW)
	assert_int(screen.run.preview().total).is_less(screen.run.quota())
	# A payout of BIG_PAYOUT coins: the most coin sounds, the last one after COINS_PRINT_S.
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	balance.coins_by_shifts_passed = PackedInt32Array([BIG_PAYOUT])
	screen.run.balance = balance
	screen._on_checkout_pressed()
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	var frames: Array[Dictionary] = await _record(screen, sfx, "_results", 3.0)
	assert_bool(screen._results.visible).is_true()
	var results: ResultsPanel = screen._results
	# The coins clink from the COINS line, the last one, on: the lines after the first coin line.
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var coins_delay_s: float = (
		(results.texts().size() - 1 - results.coin_line_index()) * tuning.final_line_ms / 1000.0
	)
	var coins_s: float = coins_delay_s + FinalReceipt.MAX_COIN_SOUNDS * FinalReceipt.COIN_GAP
	assert_float(results.coins_seconds()).is_equal_approx(coins_s, 0.001)
	assert_float(coins_s).is_greater(ShiftMusic.COINS_PRINT_S + 0.15)
	var deep_ms: int = _first_ms(
		frames, func(f: Dictionary) -> bool: return f["bus"] <= base - 24.0 + NEAR_DB
	)
	var fail_ms: int = _first_ms(
		frames, func(f: Dictionary) -> bool: return f["sounds"].has("fail")
	)
	var results_ms: int = _first_ms(frames, func(f: Dictionary) -> bool: return f["panel"])
	var front_ms: int = _first_ms(frames, func(f: Dictionary) -> bool: return f["front"] > 0.0)
	var coins_ms: int = _first_ms(frames, func(f: Dictionary) -> bool: return f["coins"])
	prints("#62 fail: deep", deep_ms, "fail", fail_ms, "results", results_ms, "coins", coins_ms)
	assert_int(deep_ms).is_greater_equal(0)
	assert_int(fail_ms).is_greater(deep_ms)
	# The fail sound rings out in full (give or take a frame) before the results and their loop.
	var fail_end: int = fail_ms + roundi(sfx.sound_length("fail") * 1000.0) - FRAME_MS
	assert_int(results_ms).is_greater_equal(fail_end)
	assert_int(front_ms).is_greater_equal(results_ms)
	# The coin lines print after the headline, the shift and the shortfall (one line apart).
	var print_ms: int = results.coin_line_index() * tuning.final_line_ms
	assert_int(coins_ms - results_ms).is_between(print_ms - FRAME_MS, print_ms + 150)
	for frame: Dictionary in frames:
		if int(frame["ms"]) >= deep_ms and int(frame["ms"]) < coins_ms:
			var bus: float = frame["bus"]
			assert_float(bus).override_failure_message(_dump(frames)).is_less_equal(
				base - 24.0 + NEAR_DB
			)
		if int(frame["ms"]) >= deep_ms and int(frame["ms"]) < results_ms:
			assert_float(frame["front"]).is_equal(0.0)
	assert_str(str(music.current_track())).is_equal(ShiftMusic.RESULTS_MUSIC)
	assert_float(music.track_gain(ShiftMusic.RESULTS_MUSIC)).is_equal(1.0)
	assert_float(music.track_gain(ShiftMusic.SHIFT_MUSIC)).is_equal(0.0)
	# While the coins print: up from the dessert's 24 dB down to 18 dB down, and held there.
	var coins_from: int = coins_ms + roundi((ShiftMusic.COINS_DUCK_S + SLACK_S) * 1000.0)
	var coins_to: int = coins_ms + roundi(coins_s * 1000.0)
	var coin_frames: int = 0
	for frame: Dictionary in frames:
		if int(frame["ms"]) >= coins_from and int(frame["ms"]) < coins_to:
			coin_frames += 1
			assert_float(frame["bus"]).is_equal_approx(base + ShiftMusic.COINS_DUCK_DB, NEAR_DB)
	assert_int(coin_frames).is_greater(0)
	_assert_rises_back(frames, coins_to, base, ShiftMusic.UNDUCK_S)
	# A new run started from the debug panel (a replay): back on the shift loop.
	screen.start_new_run(screen.run.run_seed)
	assert_str(str(music.current_track())).is_equal(ShiftMusic.SHIFT_MUSIC)


## ShiftMusic's results and coin cues on their own: the coin duck holds until `coins_s` when
## that is past COINS_PRINT_S, then the music rises back over UNDUCK_S.
func test_the_coin_duck_holds_until_the_last_coin() -> void:
	var music: MusicService = _music()
	var base: float = music.base_db()
	music.play(ShiftMusic.SHIFT_MUSIC)
	music.duck(CountUp.DESSERT_DUCK_DB, 0.0)
	var coins_s: float = 1.5
	ShiftMusic.results_shown(music)
	ShiftMusic.coins_printing(music, coins_s)
	assert_str(str(music.current_track())).is_equal(ShiftMusic.RESULTS_MUSIC)
	var elapsed: float = 0.0
	var back_s: float = -1.0
	var held: int = 0
	while elapsed < coins_s + ShiftMusic.UNDUCK_S + 2.0 * SLACK_S:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > ShiftMusic.COINS_DUCK_S + SLACK_S and elapsed < coins_s - SLACK_S:
			held += 1
			assert_float(_bus_now()).is_equal_approx(base + ShiftMusic.COINS_DUCK_DB, NEAR_DB)
		if back_s < 0.0 and _bus_now() >= base - 0.01:
			back_s = elapsed
	prints("#62 coin duck: back at", back_s, "s")
	assert_int(held).is_greater(0)
	assert_float(back_s).is_between(
		coins_s + ShiftMusic.UNDUCK_S * 0.5, coins_s + ShiftMusic.UNDUCK_S + SLACK_S
	)


## A second tap during the dessert brings the music back within about 150 ms, before the reward
## panel; two taps before the verdict skip the dessert and never duck at all.
func test_a_skipped_dessert_brings_the_music_back_fast() -> void:
	var screen: ShiftScreen = await _screen()
	var music: MusicService = _inject_music(screen)
	var base: float = music.base_db()
	await _place(screen, PASSING_ROW)
	screen._on_checkout_pressed()
	await _frames(2)
	var count_up: CountUp = screen._count_up
	count_up._tap(Time.get_ticks_msec())
	while not music.is_ducked() and screen._counting:
		await get_tree().process_frame
	assert_bool(music.is_ducked()).is_true()
	await _frames(2)
	assert_float(_bus_now()).is_less(base - NEAR_DB)
	count_up._tap(Time.get_ticks_msec())
	assert_bool(count_up.dessert_skipped).is_true()
	assert_bool(music.is_ducked()).is_false()
	var back_s: float = 0.0
	while _bus_now() < base - 0.01 and back_s < 1.0:
		await get_tree().process_frame
		back_s += get_process_delta_time()
	var back_ms: int = roundi(back_s * 1000.0)
	prints("#62 skipped dessert: back in", back_ms, "ms")
	assert_int(back_ms).is_less_equal(roundi((CountUp.SKIP_UNDUCK_S + SLACK_S) * 1000.0))
	await _count_up_end(screen)
	assert_float(_bus_now()).is_equal_approx(base, 0.01)

	# The next shift, both taps before the verdict: no duck at all.
	screen._on_reward_skipped()
	await _place(screen, ["milk", "milk", "milk", "milk"])
	screen._on_checkout_pressed()
	await _frames(2)
	count_up._tap(Time.get_ticks_msec())
	count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		assert_float(_bus_now()).is_equal_approx(base, 0.01)
		assert_bool(music.is_ducked()).is_false()
		await get_tree().process_frame


## The Music bus on every frame from now until `seconds` after the screen's `panel` shows (or
## 15 s): {"ms": process time since the start (the tweens' time), "bus": dB, "ducked": the
## count-up has ducked the music, "verdict": the total shown, "sounds": the sounds played so
## far, "panel": the panel visible, "front": the front loop's fade gain, "coins": the final
## receipt's coin lines have printed}.
func _record(screen: ShiftScreen, sfx: Sfx, panel: String, seconds: float) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	var elapsed: float = 0.0
	var shown_ms: int = -1
	while elapsed < 15.0:
		var now: int = roundi(elapsed * 1000.0)
		var visible: bool = (screen.get(panel) as Control).visible
		if visible and shown_ms < 0:
			shown_ms = now
		if shown_ms >= 0 and now - shown_ms > seconds * 1000.0:
			break
		var sounds: Array[String] = []
		for entry: Dictionary in sfx.get("sounds"):
			sounds.append(str(entry["sound"]))
		var frame: Dictionary = {
			"ms": now,
			"bus": _bus_now(),
			"ducked": screen._count_up._ducked,
			"verdict": screen._count_up._verdict_shown,
			"sounds": sounds,
			"panel": visible,
			"front": screen._music.track_gain(ShiftMusic.RESULTS_MUSIC),
			"coins": screen._results.coins_started_ms >= 0,
		}
		frames.append(frame)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return frames


## The frames as text, for a failure message.
static func _dump(frames: Array[Dictionary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for frame: Dictionary in frames:
		var sounds: Array[String] = frame["sounds"]
		lines.append("%d %.2f %s %d" % [frame["ms"], frame["bus"], frame["panel"], sounds.size()])
	return "\n".join(lines)


## From `from_ms` on, the bus only rises, and is back at `base` within `seconds` (plus slack).
func _assert_rises_back(
	frames: Array[Dictionary], from_ms: int, base: float, seconds: float
) -> void:
	assert_int(from_ms).is_greater_equal(0)
	var last: float = -INF
	var back_ms: int = -1
	for frame: Dictionary in frames:
		if int(frame["ms"]) < from_ms:
			continue
		var bus: float = frame["bus"]
		assert_float(bus).is_greater_equal(last - 0.001)
		last = bus
		if back_ms < 0 and bus >= base - 0.01:
			back_ms = int(frame["ms"]) - from_ms
	prints("#62 back at the normal level in", back_ms, "ms")
	assert_int(back_ms).is_between(roundi(seconds * 500.0), roundi((seconds + SLACK_S) * 1000.0))


## The first frame's ms that matches `test`, or -1.
static func _first_ms(frames: Array[Dictionary], test: Callable) -> int:
	for frame: Dictionary in frames:
		if test.call(frame):
			return int(frame["ms"])
	return -1


## A fresh MusicService (streaming off) in place of the autoload, already on the shift loop.
func _inject_music(screen: ShiftScreen) -> MusicService:
	var music: MusicService = _music()
	screen._music = music
	screen._count_up.music = music
	music.play(ShiftMusic.SHIFT_MUSIC)
	return music


func _music() -> MusicService:
	var music: MusicService = MUSIC_SCRIPT.new()
	music.streaming = false
	add_child(music)
	auto_free(music)
	return music


func _recording_sfx(screen: ShiftScreen) -> Sfx:
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	return sfx


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


func _count_up_end(screen: ShiftScreen) -> void:
	while screen._counting:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for frame: int in range(count):
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


static func _bus_now() -> float:
	return AudioServer.get_bus_volume_db(_music_bus())


static func _music_bus() -> int:
	return AudioServer.get_bus_index(MusicService.BUS)


static func _autoload() -> MusicService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/Music")


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
