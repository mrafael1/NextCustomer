extends GdUnitTestSuite
## The title screen (#56, direction C+ "Storefront at night"): the sign is dark, then lights (a
## first click or key only ends the intro); without a run save START RUN and REWARDS, with one
## CONTINUE, NEW RUN and REWARDS (full build plan section 4), laid out on the brick, clear of the
## doors, the sign and the bay, inside the window; the doors start, the bay opens REWARDS; NEW
## RUN asks first, and only ABANDON gives the save up (logged as run_abandon under its run id);
## REWARDS opens the toy machines (#63) and the badge pins (#122); the keys walk the menu; the
## profile's reduced motion holds every loop and slide. The title never changes the test
## runner's scene.

const TITLE := "res://ui/title_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RUN_ID := "0011223344556677"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900)]

var _folder: String = ""
var _window: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _window
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The sign stays dark and the plates hidden until INTRO_DARK; a first click (anywhere, even on
## the doors) then only lights the sign and shows the plates at once.
func test_a_first_click_during_the_intro_only_ends_it() -> void:
	var title: TitleScreen = await _title(false)
	assert_bool(title.is_intro_playing()).is_true()
	assert_bool(title.storefront().is_lit()).is_false()
	assert_bool(title.menu().plate(TitleMenu.Entry.PRIMARY).visible).is_false()
	title._on_scene_input(_click_at(title, title.storefront().doors_rect().get_center()))
	assert_bool(title._starting).is_false()
	assert_bool(title.is_intro_playing()).is_false()
	assert_bool(title.storefront().is_lit()).is_true()
	for entry: TitleMenu.Entry in title.menu().entries():
		var plate: MenuPlate = title.menu().plate(entry)
		assert_bool(plate.visible).is_true()
		assert_float(plate.position.x).is_equal(0.0)
	assert_bool(title.skip_intro()).is_false()


## Left alone, the sign lights by itself after INTRO_DARK, then the plates step in.
func test_the_sign_lights_by_itself() -> void:
	var title: TitleScreen = await _title(false)
	title._process(TitleScreen.INTRO_DARK - 0.5)
	assert_int(title.storefront().neon_sign().lit_letters()).is_equal(0)
	title._process(0.6)
	await get_tree().create_timer(NeonSign.LETTER_STEP * 13 + TitleMenu.SLIDE_TIME * 2).timeout
	assert_bool(title.storefront().is_lit()).is_true()
	assert_bool(title.menu().is_shown()).is_true()
	await get_tree().create_timer(TitleMenu.STEP_DELAY * 3 + TitleMenu.SLIDE_TIME).timeout
	assert_bool(title.is_intro_playing()).is_false()


func test_without_a_run_save_the_doors_start() -> void:
	var title: TitleScreen = await _title()
	assert_array(title.menu().entries()).is_equal(
		[TitleMenu.Entry.PRIMARY, TitleMenu.Entry.REWARDS]
	)
	var primary: MenuPlate = title.menu().plate(TitleMenu.Entry.PRIMARY)
	assert_str(primary.caption).is_equal(TitleMenu.START_TEXT)
	assert_str(primary.sub_line).is_equal(TitleMenu.length_line(load(BALANCE)))
	assert_object(title.abandon_confirm()).is_null()
	# The brick starts nothing; the doors do.
	title._on_scene_input(_click_at(title, _on_stage(title, Vector2(20, 40))))
	assert_bool(title._starting).is_false()
	title._on_scene_input(_click_at(title, title.storefront().doors_rect().get_center()))
	assert_bool(title._starting).is_true()


## An unreadable run save is left for the shift screen to report and back up: the title works
## as without one and touches nothing.
func test_an_unreadable_run_save_shows_no_continue() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var file: FileAccess = FileAccess.open(_run_file(), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var title: TitleScreen = await _title()
	assert_object(title.menu().plate(TitleMenu.Entry.NEW_RUN)).is_null()
	assert_str(title.menu().plate(TitleMenu.Entry.PRIMARY).caption).is_equal(TitleMenu.START_TEXT)
	assert_bool(FileAccess.file_exists(_run_file() + SaveService.BACKUP_SUFFIX)).is_false()
	assert_str(FileAccess.get_file_as_string(_run_file())).is_equal("{broken")


## With a save: CONTINUE (naming the shift), NEW RUN and REWARDS. Enter continues and keeps the
## save.
func test_a_run_save_offers_continue_and_new_run() -> void:
	_save_run_at_shift(3)
	var title: TitleScreen = await _title()
	var menu: TitleMenu = title.menu()
	assert_array(menu.entries()).is_equal(
		[TitleMenu.Entry.PRIMARY, TitleMenu.Entry.NEW_RUN, TitleMenu.Entry.REWARDS]
	)
	var primary: MenuPlate = menu.plate(TitleMenu.Entry.PRIMARY)
	assert_str(primary.caption).is_equal(TitleMenu.CONTINUE_TEXT)
	assert_str(primary.sub_line).is_equal("SHIFT 3/%d" % _shift_count())
	assert_str(menu.plate(TitleMenu.Entry.NEW_RUN).caption).is_equal(TitleMenu.NEW_RUN_TEXT)
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_true()
	assert_bool(FileAccess.file_exists(_run_file())).is_true()
	assert_dict(_last_event("run_abandon")).is_empty()


func test_continue_keeps_the_save() -> void:
	_save_run_at_shift(1)
	var title: TitleScreen = await _title()
	var sfx: Sfx = _record(title)
	title.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	assert_bool(title._starting).is_true()
	assert_bool(FileAccess.file_exists(_run_file())).is_true()
	assert_array(sfx.call("sound_names")).is_equal(["ui_click", TitleScreen.START_SOUND])


## NEW RUN asks first, in a popup inside the window, with ui_open. KEEP closes it with ui_close
## (#62) and keeps the save; ABANDON deletes it, logs run_abandon under the saved run id and
## starts a new run.
func test_new_run_asks_before_abandoning_the_save() -> void:
	_save_run_at_shift(2)
	var title: TitleScreen = await _title()
	var sfx: Sfx = _record(title)
	title.menu().plate(TitleMenu.Entry.NEW_RUN).pressed.emit()
	var confirm: AbandonConfirm = title.abandon_confirm()
	assert_bool(title._starting).is_false()
	assert_bool(confirm.is_open()).is_true()
	assert_str(confirm.lost_label().text).is_equal("SHIFT 2/%d WILL BE LOST" % _shift_count())
	await get_tree().create_timer(TitlePopup.OPEN_TIME + 0.1).timeout
	var screen: Rect2 = title.get_viewport_rect()
	var sheet: Rect2 = confirm.sheet().get_global_rect()
	assert_bool(screen.encloses(sheet)).is_true()
	for plate: MenuPlate in [confirm.abandon_plate(), confirm.keep_plate()]:
		assert_bool(sheet.encloses(plate.get_global_rect())).is_true()
	# While it asks, Enter neither continues nor abandons, and the doors start nothing.
	title._unhandled_key_input(_key(KEY_ENTER))
	title._on_scene_input(_click_at(title, title.storefront().doors_rect().get_center()))
	assert_bool(title._starting).is_false()

	confirm.keep_plate().pressed.emit()
	assert_array(sfx.call("sound_names")).is_equal(["ui_click", "ui_open", "ui_close"])
	assert_bool(confirm.is_open()).is_false()
	assert_bool(FileAccess.file_exists(_run_file())).is_true()
	assert_bool(title._starting).is_false()
	assert_dict(_last_event("run_abandon")).is_empty()

	title.menu().plate(TitleMenu.Entry.NEW_RUN).pressed.emit()
	confirm.abandon_plate().pressed.emit()
	assert_bool(FileAccess.file_exists(_run_file())).is_false()
	assert_bool(title._starting).is_true()
	var abandon: Dictionary = _last_event("run_abandon")
	assert_str(abandon["run_id"]).is_equal(RUN_ID)
	assert_int(int(abandon["shift"])).is_equal(2)
	assert_str(abandon["phase"]).is_equal("planning")
	assert_int(int(abandon["run_ms"])).is_equal(1000)


## At 1280x720 and 1600x900, with and without a save: the plates, the Export log icon and the
## build label are inside the window; the plates clear each other, the doors, the sign and the
## bay; the hit rects are the drawn doors, bay and sign.
func test_the_title_is_laid_out_on_screen() -> void:
	for saved: bool in [false, true]:
		if saved:
			_save_run_at_shift(4)
		for size: Vector2i in SIZES:
			get_tree().root.size = size
			var title: TitleScreen = await _title()
			_assert_laid_out(title, "%s saved=%s" % [size, saved])


func _assert_laid_out(title: TitleScreen, case: String) -> void:
	var screen: Rect2 = title.get_viewport_rect()
	var front: Storefront = title.storefront()
	var origin: Vector2 = front.global_position
	var doors: Rect2 = Rect2(front.doors_rect().position + origin, front.doors_rect().size)
	var bay: Rect2 = Rect2(front.bay_rect().position + origin, front.bay_rect().size)
	var sign_rect: Rect2 = Rect2(front.sign_rect().position + origin, front.sign_rect().size)
	# The hit rects are what is drawn.
	assert_vector(doors.position).is_equal(front._doors.get_global_rect().position)
	assert_vector(doors.size).is_equal(front._doors.get_global_rect().size)
	assert_vector(bay.position).is_equal(front._bay.get_global_rect().position)
	assert_vector(sign_rect.position).is_equal(front.neon_sign().get_global_rect().position)
	assert_bool(bay.encloses(front.machine().get_global_rect())).is_true()
	assert_int(title.target_at(doors.get_center())).is_equal(TitleScreen.Target.DOORS)
	assert_int(title.target_at(bay.get_center())).is_equal(TitleScreen.Target.BAY)
	assert_int(title.target_at(sign_rect.get_center())).is_equal(TitleScreen.Target.SIGN)
	for scene_rect: Rect2 in [doors, bay, sign_rect]:
		assert_bool(screen.encloses(scene_rect)).override_failure_message(case).is_true()
	var plates: Array[Rect2] = []
	for entry: TitleMenu.Entry in title.menu().entries():
		var plate: MenuPlate = title.menu().plate(entry)
		var rect: Rect2 = plate.get_global_rect()
		var with_tick: Rect2 = rect.merge(plate.tick().get_global_rect())
		(
			assert_bool(screen.encloses(with_tick))
			. override_failure_message("%s %s %s" % [case, entry, rect])
			. is_true()
		)
		for scene_rect: Rect2 in [doors, bay, sign_rect]:
			(
				assert_bool(with_tick.intersects(scene_rect))
				. override_failure_message("%s %s over %s" % [case, rect, scene_rect])
				. is_false()
			)
		for other: Rect2 in plates:
			assert_bool(rect.intersects(other)).override_failure_message(case).is_false()
		plates.append(rect)
	var corner: Array[Rect2] = [
		title.export_button().get_global_rect(), title.build_label().get_global_rect()
	]
	assert_vector(corner[0].size).is_equal(TitleScreen.EXPORT_RECT.size)
	for rect: Rect2 in corner:
		assert_bool(screen.encloses(rect)).override_failure_message(case).is_true()
		for plate: Rect2 in plates:
			assert_bool(rect.intersects(plate)).is_false()
	assert_bool(corner[0].intersects(corner[1])).is_false()
	assert_str(title.build_label().text).is_equal(
		str(ProjectSettings.get_setting("next_customer/build_label", ""))
	)


## Real mouse input: the doors under the mouse mark the primary entry (the doors stand ajar), the
## bay REWARDS (it lights); a click on the bay opens REWARDS, on the doors starts.
func test_the_mouse_on_the_doors_and_the_bay() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(4)
	var front: Storefront = title.storefront()
	runner.set_mouse_position(front.doors_rect().get_center())
	await _frames(2)
	assert_int(title.menu().marked_entry()).is_equal(TitleMenu.Entry.PRIMARY)
	assert_int(front.door_gap()).is_equal(Storefront.DOORS_AJAR)
	assert_int(title.scene_hit().mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	runner.set_mouse_position(front.bay_rect().get_center())
	await _frames(2)
	assert_int(title.menu().marked_entry()).is_equal(TitleMenu.Entry.REWARDS)
	assert_bool(front.bay_hot).is_true()
	assert_bool(front.doors_hot).is_false()
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await get_tree().create_timer(Storefront.GLASS_TIME + 0.1).timeout
	assert_bool(title.rewards().is_open()).is_true()
	assert_bool(title._starting).is_false()
	title.rewards().back_plate().pressed.emit()
	assert_bool(title.rewards().is_open()).is_false()
	runner.set_mouse_position(front.doors_rect().get_center())
	await _frames(2)
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await _frames(1)
	assert_bool(title._starting).is_true()


## REWARDS: the bay's glass slides, then the menu opens with the profile's coins on its LED;
## TOY MACHINES opens the machines over it, where nothing starts a run;
## Done closes them and the coins follow the draw on the plate and the LED; BACK and Esc close
## REWARDS.
func test_rewards_opens_the_toy_machines() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coins = 2
	profile.run_count = 3
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var title: TitleScreen = await _title()
	var sfx: Sfx = _record(title)
	var plate: MenuPlate = title.menu().plate(TitleMenu.Entry.REWARDS)
	assert_str(plate.count_label().text).is_equal("2")
	var rewards: RewardsMenu = await _open_rewards(title)
	assert_str(rewards.coin_label().text).is_equal("2")
	assert_bool(title.get_viewport_rect().encloses(rewards.sheet().get_global_rect())).is_true()
	assert_array(sfx.call("sound_names")).is_equal(["ui_click", "ui_open"])
	rewards.toy_machines_card().pressed.emit()
	await _frames(2)
	assert_bool(title.toy_machines_open()).is_true()
	var toys: ToyMachinesScreen = title._toys
	assert_int(toys.get_index()).is_greater(rewards.get_index())
	assert_str(toys.coins_text()).is_equal("2")
	title._on_scene_input(_click_at(title, title.storefront().doors_rect().get_center()))
	title._unhandled_key_input(_key(KEY_ENTER))
	title._unhandled_key_input(_key(KEY_SPACE))
	assert_bool(title._starting).is_false()
	toys.machines()[0]._gui_input(_left_click())
	assert_int(SaveService.new(_folder).load_profile().coins).is_equal(1)
	# No run is saved: the item rides the next runs, from the ended runs' index.
	assert_int(SaveService.new(_folder).load_profile().unlocked_items[&"cream"]).is_equal(2)
	assert_str(toys.reveal().stock_label().text).is_equal(CapsuleCounter.NEXT_RUN_LINE)
	assert_str(_last_event("capsule")["run_id"]).is_empty()
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	toys.reveal().dismiss()
	toys.done_button().pressed.emit()
	assert_bool(title.toy_machines_open()).is_false()
	assert_bool(rewards.is_open()).is_true()
	assert_str(rewards.coin_label().text).is_equal("1")
	assert_str(plate.count_label().text).is_equal("1")
	title._unhandled_key_input(_key(KEY_ESCAPE))
	assert_bool(rewards.is_open()).is_false()
	# Closed: the doors start again.
	title._on_scene_input(_click_at(title, title.storefront().doors_rect().get_center()))
	assert_bool(title._starting).is_true()


## With a run saved, a title draw gets that run's index and the saved-run stock line.
func test_a_title_draw_with_a_saved_run_rides_after_it() -> void:
	_save_run_at_shift(2)
	var profile: ProfileState = ProfileState.new()
	profile.coins = 1
	profile.run_count = 4
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var title: TitleScreen = await _title()
	var rewards: RewardsMenu = await _open_rewards(title)
	rewards.toy_machines_card().pressed.emit()
	await _frames(2)
	title._toys.machines()[1]._gui_input(_left_click())
	assert_int(SaveService.new(_folder).load_profile().unlocked_items[&"sugar_cubes"]).is_equal(4)
	assert_str(title._toys.reveal().stock_label().text).is_equal(
		CapsuleCounter.AFTER_SAVED_RUN_LINE
	)
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_false()


## An unreadable profile hides the coins on REWARDS ("?" on its LED), opens the machines switched
## off and leaves the file as it is.
func test_an_unreadable_profile_opens_the_machines_switched_off() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var path: String = SaveService.new(_folder).profile_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var title: TitleScreen = await _title()
	assert_bool(title.menu().plate(TitleMenu.Entry.REWARDS).count_label().visible).is_false()
	var rewards: RewardsMenu = await _open_rewards(title)
	assert_str(rewards.coin_label().text).is_equal("?")
	rewards.toy_machines_card().pressed.emit()
	await _frames(2)
	for machine: ToyMachineView in title._toys.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
	assert_str(title._toys.coins_text()).is_equal("?")
	assert_str(FileAccess.get_file_as_string(path)).is_equal("{broken")


## The keys: Down and Up walk the plates (the storefront follows), Enter presses the marked one;
## in REWARDS the arrows walk its cards and Esc closes it.
func test_the_keys_walk_the_menu() -> void:
	_save_run_at_shift(2)
	var title: TitleScreen = await _title()
	var menu: TitleMenu = title.menu()
	title._unhandled_key_input(_key(KEY_DOWN))
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.PRIMARY)
	assert_bool(title.storefront().doors_hot).is_true()
	title._unhandled_key_input(_key(KEY_UP))
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.REWARDS)
	assert_bool(title.storefront().bay_hot).is_true()
	assert_bool(title.storefront().doors_hot).is_false()
	title._unhandled_key_input(_key(KEY_UP))
	assert_int(menu.marked_entry()).is_equal(TitleMenu.Entry.NEW_RUN)
	title._unhandled_key_input(_key(KEY_DOWN))
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_false()
	await get_tree().create_timer(Storefront.GLASS_TIME + 0.1).timeout
	var rewards: RewardsMenu = title.rewards()
	assert_bool(rewards.is_open()).is_true()
	title._unhandled_key_input(_key(KEY_RIGHT))
	assert_bool(rewards.toy_machines_card().marked).is_true()
	title._unhandled_key_input(_key(KEY_RIGHT))
	assert_bool(rewards.badge_card().marked).is_true()
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(rewards.is_open()).is_true()
	assert_bool(title.badge_screen().is_open()).is_true()
	assert_bool(title.toy_machines_open()).is_false()
	title._unhandled_key_input(_key(KEY_ESCAPE))
	assert_bool(title.badge_screen().is_open()).is_false()
	assert_bool(rewards.is_open()).is_true()
	title._unhandled_key_input(_key(KEY_ESCAPE))
	assert_bool(rewards.is_open()).is_false()
	assert_bool(title._starting).is_false()


## A start opens the doors in DOOR_STEP steps, then the light floods the window.
func test_a_start_opens_the_doors() -> void:
	var title: TitleScreen = await _title()
	var front: Storefront = title.storefront()
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_true()
	await get_tree().create_timer(Storefront.DOOR_TIME / 2.0).timeout
	assert_int(front.door_gap() % Storefront.DOOR_STEP).is_equal(0)
	assert_int(front.door_gap()).is_greater(Storefront.DOORS_AJAR)
	await get_tree().create_timer(Storefront.DOOR_TIME / 2.0 + Storefront.FLOOD_TIME).timeout
	await _frames(2)
	assert_int(front.door_gap()).is_equal(Storefront.DOORS_OPEN)
	assert_float(front.flood()).is_equal(1.0)
	# Input after the start does nothing.
	title._unhandled_key_input(_key(KEY_DOWN))
	title.menu().plate(TitleMenu.Entry.REWARDS).pressed.emit()
	assert_bool(title.rewards().is_open()).is_false()
	# Nor does the mouse crossing the plates: the marker and the storefront stay as they are.
	var marked: TitleMenu.Entry = title.menu().marked_entry()
	title.menu().plate(TitleMenu.Entry.REWARDS).mouse_entered.emit()
	title.menu().plate(TitleMenu.Entry.PRIMARY).mouse_exited.emit()
	assert_int(title.menu().marked_entry()).is_equal(marked)
	assert_bool(front.bay_hot).is_false()


## Reduced motion: the sign is lit and the plates are in place at once, nothing loops (no
## stutter, swing, breath, flicker or scrap), REWARDS opens with no slide, and a start only
## floods the window, the doors staying shut.
func test_reduced_motion_holds_every_loop_and_slide() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.set_reduced_motion(true)
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	await _frames(2)
	var front: Storefront = title.storefront()
	assert_bool(front.still).is_true()
	assert_bool(front.is_lit()).is_true()
	assert_bool(title.is_intro_playing()).is_false()
	for entry: TitleMenu.Entry in title.menu().entries():
		assert_bool(title.menu().plate(entry).visible).is_true()
	var neon: NeonSign = front.neon_sign()
	for step: int in 40:
		front._process(0.25)
		neon._process(0.25)
		assert_bool(neon.is_stuttering()).is_false()
		assert_int(neon.swing()).is_equal(0)
		assert_bool(neon.halo_is_soft()).is_false()
		assert_bool(front.layer("tube_on").visible).is_true()
	title.menu().plate(TitleMenu.Entry.REWARDS).pressed.emit()
	await _frames(2)
	assert_bool(title.rewards().is_open()).is_true()
	assert_float(title.rewards().sheet().modulate.a).is_equal(1.0)
	assert_bool(front.layer("glass").visible).is_false()
	title._unhandled_key_input(_key(KEY_ESCAPE))
	title._unhandled_key_input(_key(KEY_ENTER))
	assert_bool(title._starting).is_true()
	await get_tree().create_timer(Storefront.FLOOD_TIME + 0.1).timeout
	assert_int(front.door_gap()).is_equal(0)
	assert_float(front.flood()).is_equal(1.0)


## The sign's hidden toy: a click on it scans it (the scanner's beep) and starts nothing.
func test_a_click_on_the_sign_scans_it() -> void:
	var title: TitleScreen = await _title()
	var sfx: Sfx = _record(title)
	title._on_scene_input(_click_at(title, title.storefront().sign_rect().get_center()))
	assert_bool(title._starting).is_false()
	assert_array(sfx.call("sound_names")).is_equal(["scan"])


## The title, its intro ended unless `skip` is false.
func _title(skip: bool = true) -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	if skip:
		title.skip_intro()
	await _frames(4)
	return title


## Presses REWARDS and waits for the bay's glass and the menu's step in.
## #122: BADGE PINS opens the badge screen over REWARDS on the saved profile. Pressing an owned
## pin wears it and saves; a locked one says no; UNLOCK A RANDOM PIN spends the price and
## unlocks the last locked pin (saved, with a capsule seed made for it); the REWARDS card and
## the coins follow.
func test_badge_pins_wear_and_buy_from_rewards() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coins = 14
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var title: TitleScreen = await _title()
	var rewards: RewardsMenu = await _open_rewards(title)
	assert_str(rewards.pins_line().text).is_equal("1 OF 2 PINS")
	rewards.badge_card().pressed.emit()
	var badge: BadgeScreen = title.badge_screen()
	assert_bool(badge.is_open()).is_true()
	assert_int(badge.get_index()).is_greater(rewards.get_index())
	var rows: Array[PinRow] = badge.rows()
	assert_int(rows[0].state()).is_equal(PinRow.State.OWNED)
	assert_int(rows[1].state()).is_equal(PinRow.State.LOCKED)
	assert_bool(title.get_viewport_rect().encloses(badge.sheet().get_global_rect())).is_true()
	var sheet: Rect2 = badge.sheet().get_global_rect()
	for control: Control in [badge.badge(), rows[0], rows[1], badge.buy_plate()] as Array[Control]:
		assert_bool(sheet.encloses(control.get_global_rect())).is_true()
	assert_bool(rows[0].get_global_rect().intersects(rows[1].get_global_rect())).is_false()
	rows[1].pressed.emit()
	assert_array(SaveService.new(_folder).load_profile().worn_pins).is_empty()
	rows[0].pressed.emit()
	assert_int(rows[0].state()).is_equal(PinRow.State.WORN)
	assert_array(SaveService.new(_folder).load_profile().worn_pins).is_equal([rows[0].pin.id])
	assert_str(rewards.badge().slot_faces()[0].letters()).is_equal(rows[0].pin.face_text)
	badge.buy_plate().pressed.emit()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_int(saved.coins).is_equal(2)
	assert_array(saved.unlocked_pins).is_equal([rows[1].pin.id])
	assert_bool(saved.has_capsule_seed).is_true()
	assert_int(rows[1].state()).is_equal(PinRow.State.OWNED)
	assert_bool(badge.buy_plate().disabled).is_true()
	assert_str(rewards.coin_label().text).is_equal("2")
	assert_str(rewards.pins_line().text).is_equal("2 OF 2 PINS")
	badge.back_plate().pressed.emit()
	assert_bool(badge.is_open()).is_false()
	assert_bool(rewards.is_open()).is_true()


func _open_rewards(title: TitleScreen) -> RewardsMenu:
	title.menu().plate(TitleMenu.Entry.REWARDS).pressed.emit()
	assert_bool(title._rewards_pending).is_true()
	await get_tree().create_timer(Storefront.GLASS_TIME + TitlePopup.OPEN_TIME + 0.15).timeout
	assert_bool(title.rewards().is_open()).is_true()
	return title.rewards()


## A recording Sfx in place of the title's (the popups find it too).
func _record(title: TitleScreen) -> Sfx:
	var sfx: Sfx = RECORDING_SFX.new()
	title.add_child(sfx)
	title._sfx = sfx
	return sfx


## A left click at `point` (global canvas px), in the scene hit layer's coordinates.
static func _click_at(title: TitleScreen, point: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = _left_click()
	click.position = title.scene_hit().get_global_transform().affine_inverse() * point
	return click


## `stage_point` on the storefront's stage, in global canvas px.
static func _on_stage(title: TitleScreen, stage_point: Vector2) -> Vector2:
	return title.storefront().stage().get_global_rect().position + stage_point


## A run in planning on `shift` (1-based), saved under RUN_ID.
func _save_run_at_shift(shift: int) -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(31, deck, balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(shift - 1)
	assert_bool(SaveService.new(_folder).save_run(run, RUN_ID, 1000)).is_true()


static func _shift_count() -> int:
	return (load(BALANCE) as BalanceDefinition).quotas.size()


func _run_file() -> String:
	return _folder.path_join(SaveService.RUN_FILE)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


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
