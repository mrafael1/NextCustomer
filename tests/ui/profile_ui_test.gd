extends GdUnitTestSuite
## The profile on the real shift screen (full build plan section 4): loaded from the save
## folder at start, recorded and saved when a run ends, untouched by a run restarted before
## its end.

const SCREEN := "res://ui/shift_screen.tscn"
const TITLE := "res://ui/title_screen.tscn"
const REPEAT := "res://data/cards/repeat.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	Engine.time_scale = 8.0


func after_test() -> void:
	Engine.time_scale = 1.0
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_an_ended_run_is_saved_to_the_profile_and_a_restart_is_not() -> void:
	var saves: SaveService = SaveService.new(_folder)
	var saved: ProfileState = ProfileState.new()
	saved.run_count = 3
	saved.coupon_uses[&"repeat"] = 1
	saves.save_profile(saved)
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	assert_int(screen.profile.run_count).is_equal(3)
	# A new run before this one ends (the debug seed) records nothing.
	screen.start_new_run(5)
	screen._on_reward_skipped()
	assert_int(saves.load_profile().run_count).is_equal(3)
	# A Repeat alone pays 0: the run is lost, recorded and saved at the click.
	screen.run.place(screen.run.debug_add_to_hand(load(REPEAT)), 0)
	# Saved at the click, before the count-up: closing the game during it loses nothing.
	screen._on_checkout_pressed()
	assert_bool(screen._counting).is_true()
	assert_int(saves.load_profile().run_count).is_equal(4)
	while screen._counting:
		await get_tree().process_frame
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	var read: ProfileState = saves.load_profile()
	assert_int(read.run_count).is_equal(4)
	assert_dict(read.coupon_uses).is_equal({&"repeat": 2})
	assert_int(screen.profile.run_count).is_equal(4)


## Full build plan 7.1: the results print the run's coins at the bottom, with the profile's
## total, and the results fit the 1280 x 720 screen even with 8 history rows.
func test_the_results_print_the_coins_and_fit_the_screen() -> void:
	var saves: SaveService = SaveService.new(_folder)
	var saved: ProfileState = ProfileState.new()
	saved.coins = 6
	saves.save_profile(saved)
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	var count: int = screen.run.shift_count()
	screen._on_debug_shift(count)
	# The debug jump writes no history: the 7 earlier shifts are passed records, each €2 over.
	for shift: int in range(count - 1, 0, -1):
		screen.run.history.push_front(ShiftRecord.new(shift, 10, 12))
	# Bread, Multipack, then four Milks at x2: 67 against the last quota.
	for id: String in ["bread", "multipack", "milk", "milk", "milk", "milk"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		screen.run.place(screen.run.debug_add_to_hand(card), screen.run.row.size())
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.WON)
	# 8 shifts passed pay 2; overtime 7 x 2 + (67 - 48) = 33, under the €60 step.
	var texts: PackedStringArray = screen._results._coin_receipt.texts()
	assert_int(texts.size()).is_equal(3)
	assert_str(texts[0]).starts_with("Shifts passed 8").ends_with("+2")
	assert_str(texts[1]).starts_with("Overtime €33").ends_with("+0")
	assert_str(texts[2]).starts_with("COINS +2").ends_with("you have 8")
	assert_int(saves.load_profile().coins).is_equal(8)
	for frame: int in range(4):
		await get_tree().process_frame
	var banner: Rect2 = screen._results.get_global_rect()
	assert_float(banner.size.y).is_less_equal(720.0)
	assert_float(banner.size.x).is_less_equal(1280.0)
	assert_bool(banner.encloses(screen._results._coin_receipt.get_global_rect())).is_true()
	assert_float(screen._results._coin_receipt.size.y).is_greater(40.0)


## The receipt's lines all have the same width, so the amounts form a column, and an unknown
## total (the profile couldn't be saved) prints "?".
func test_coin_receipt_lines_align_and_show_an_unknown_total() -> void:
	var payout: CoinPayout = CoinPayout.new()
	payout.shifts_passed = 5
	payout.shift_coins = 1
	payout.overtime = 140
	payout.overtime_coins = 1
	var lines: PackedStringArray = CoinReceipt.lines(payout, 1234)
	(
		assert_array(Array(lines))
		. is_equal(
			[
				"Shifts passed 5                 +1",
				"Overtime €140                   +1",
				"COINS +2             you have 1234",
			]
		)
	)
	for line: String in lines:
		assert_int(line.length()).is_equal(CoinReceipt.WIDTH)
	assert_str(CoinReceipt.lines(payout, -1)[2]).ends_with("you have ?")


## The title screen shows the run's length from balance data and the profile's coins, read
## without reporting or backing up an unreadable save.
func test_the_title_shows_the_shift_count_and_the_coins() -> void:
	var saved: ProfileState = ProfileState.new()
	saved.coins = 9
	SaveService.new(_folder).save_profile(saved)
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	var shifts: int = (load("res://data/balance/balance.tres") as BalanceDefinition).quotas.size()
	assert_str(title._subtitle.text).contains("all %d shifts" % shifts)
	assert_str(title._coins.text).is_equal("Coins: 9")
	var file: FileAccess = FileAccess.open(
		_folder.path_join(SaveService.PROFILE_FILE), FileAccess.WRITE
	)
	file.store_string("{broken")
	file.close()
	assert_str(TitleScreen.coins_text(SaveService.new(_folder))).is_equal("Coins: ?")
	var backup: String = _folder.path_join(SaveService.PROFILE_FILE + SaveService.BACKUP_SUFFIX)
	assert_bool(FileAccess.file_exists(backup)).is_false()
	assert_str(TitleScreen.coins_text(SaveService.new(_folder.path_join("none")))).is_equal(
		"Coins: 0"
	)


func test_without_a_save_the_screen_starts_a_fresh_profile() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	assert_int(screen.profile.run_count).is_equal(0)
	assert_bool(FileAccess.file_exists(_folder.path_join(SaveService.PROFILE_FILE))).is_false()


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
