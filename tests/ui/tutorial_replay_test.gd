extends GdUnitTestSuite
## The tutorial on the menus (WP-6): the title's G1 (TitleGuide) rings the plate that starts the
## guided run; the handbook's PLAY THE GUIDED SHIFT, on the title and in a run, asks for the next
## new run to be guided and saves the profile, never the saved run; the options' RESET TIPS clears
## only the tips' and quick tutorials' flags. Every case runs on a temporary save folder and log.

const TITLE := "res://ui/title_screen.tscn"
const SCREEN := "res://ui/shift_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RUN_ID := "0011223344556677"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String = ""
var _window: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window = get_tree().root.size


func after_test() -> void:
	get_tree().paused = false
	get_tree().root.size = _window
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## G1 on a fresh profile: once the intro is over, a ring around START RUN and a callout beside it
## saying to click it, inside the window at 1280x720 and 1920x1080, clear of the plate and its
## CLICK tab; hidden during the intro, while a popup is open and once the run starts. It takes no
## clicks.
func test_g1_rings_start_run_on_a_fresh_profile() -> void:
	var intro: TitleScreen = await _title(false)
	assert_bool(intro.title_guide().is_active()).is_true()
	assert_bool(intro.title_guide().is_showing()).is_false()
	for size: Vector2i in SIZES:
		get_tree().root.size = size
		var title: TitleScreen = await _title()
		var guide: TitleGuide = title.title_guide()
		assert_bool(guide.is_showing()).override_failure_message(str(size)).is_true()
		assert_str(guide.line()).contains("Click START RUN.")
		assert_str(guide.card().tip_text()).contains("Click START RUN.")
		var plate: Rect2 = title.menu().plate(TitleMenu.Entry.PRIMARY).get_global_rect()
		assert_bool(title.anchor_rect(TutorialAnchors.TITLE_PRIMARY) == plate).is_true()
		_assert_ring_and_card(title, plate, str(size))
		for node: Node in guide.find_children("*", "Control", true, false):
			assert_int((node as Control).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_int(guide.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		# A popup over the title hides it; closing it brings it back.
		title.menu().plate(TitleMenu.Entry.OPTIONS).pressed.emit()
		await _frames(1)
		assert_bool(guide.is_showing()).is_false()
		title.options().close()
		await _frames(1)
		assert_bool(guide.is_showing()).is_true()
	var started: TitleScreen = await _title()
	started.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	assert_bool(started._starting).is_true()
	await _frames(1)
	assert_bool(started.title_guide().is_showing()).is_false()


## G1 with a run saved rings NEW RUN ("Click NEW RUN."); a profile done with the guided run, a
## played one, or a saved run that is itself guided (CONTINUE resumes it) shows none.
func test_g1_follows_the_plate_and_skips_a_done_profile() -> void:
	_save_run_at_shift(2)
	var title: TitleScreen = await _title()
	var guide: TitleGuide = title.title_guide()
	assert_bool(guide.is_showing()).is_true()
	assert_str(guide.line()).contains("Click NEW RUN.")
	var new_run: Rect2 = title.menu().plate(TitleMenu.Entry.NEW_RUN).get_global_rect()
	assert_bool(title.anchor_rect(TutorialAnchors.TITLE_PRIMARY) == new_run).is_true()
	_assert_ring_and_card(title, new_run, "saved")
	_write_profile(true)
	var done_title: TitleScreen = await _title()
	assert_bool(done_title.title_guide().is_active()).is_false()
	assert_bool(done_title.title_guide().is_showing()).is_false()
	var played: ProfileState = ProfileState.new()
	played.run_count = 2
	assert_bool(TitleGuide.due(played, null)).is_false()
	var fresh: ProfileState = ProfileState.new()
	var saved: RunSave = SaveService.new(_folder).peek_run(ContentLookup.new(load(BALANCE)))
	assert_bool(TitleGuide.due(fresh, saved)).is_true()
	saved.run.guided = true
	assert_bool(TitleGuide.due(fresh, saved)).is_false()
	assert_bool(TitleGuide.due(null, null)).is_false()


## The title's handbook: a profile done with the guided run gets PLAY THE GUIDED SHIFT at the
## foot of the first tab's index (clear of its rows and the hint card, its words on its face),
## on that tab only; a fresh profile gets the line instead (its next new run is guided anyway).
func test_the_handbook_offers_the_guided_shift_on_its_first_tab() -> void:
	_write_profile(true)
	var title: TitleScreen = await _title()
	var page: HandbookPage = title.guide()
	page.open_at()
	var first: StringName = HandbookBook.shared().group_ids[0]
	page.show_group(first)
	assert_bool(page.replay_plate.visible).is_true()
	assert_bool(page.replay_note.visible).is_false()
	assert_str(page.replay_plate.caption()).is_equal(HandbookPage.REPLAY_TEXT)
	var plate: Rect2 = page.replay_plate.get_global_rect()
	var binder: Rect2 = page.binder_rect()
	var index_page: Rect2 = Rect2(
		binder.position + HandbookPage.INDEX_PAGE.position, HandbookPage.INDEX_PAGE.size
	)
	assert_bool(index_page.encloses(plate)).is_true()
	for row: HandbookButton in page.index_rows():
		assert_float(row.get_global_rect().end.y).is_less_equal(plate.position.y)
	var hint: Control = page.find_child("HintCard", true, false) as Control
	assert_float(plate.end.y).is_less_equal(hint.get_global_rect().position.y)
	var words: Label = page.replay_plate.find_child("Text", false, false) as Label
	assert_float(HandbookButton.words_width(words)).is_less_equal(plate.size.x - 16.0)
	var tabs: Rect2 = title.anchor_rect(TutorialAnchors.HANDBOOK_TABS)
	assert_bool(tabs.encloses(page.tab(first).get_global_rect())).is_true()
	page.show_group(HandbookBook.shared().group_ids[1])
	assert_bool(page.replay_plate.visible).is_false()
	page.close()
	assert_bool(title.anchor_rect(TutorialAnchors.HANDBOOK_TABS).has_area()).is_false()
	# A fresh profile: the line, not the plate.
	DirAccess.remove_absolute(_folder.path_join(SaveService.PROFILE_FILE))
	var fresh: TitleScreen = await _title()
	fresh.guide().open_at()
	fresh.guide().show_group(first)
	assert_bool(fresh.guide().replay_plate.visible).is_false()
	assert_bool(fresh.guide().replay_note.visible).is_true()
	assert_str(fresh.guide().replay_note.text).is_equal(HandbookPage.REPLAY_SET_TEXT)
	var note: Label = fresh.guide().replay_note
	assert_float(note.get_minimum_size().y).is_less_equal(note.size.y + 0.5)


## PLAY THE GUIDED SHIFT on the title: the saved profile asks for the guided run (logged as
## tutorial_replay from the title, with no run id), the saved run is untouched, the plate turns
## into its line, and G1 comes up on NEW RUN once the handbook closes.
func test_replay_on_the_title_saves_the_profile_not_the_run() -> void:
	_write_profile(true)
	_save_run_at_shift(2)
	var run_before: String = FileAccess.get_file_as_string(_run_file())
	var title: TitleScreen = await _title()
	assert_bool(title.title_guide().is_active()).is_false()
	var page: HandbookPage = title.guide()
	page.open_at()
	page.show_group(HandbookBook.shared().group_ids[0])
	page.replay_plate.pressed.emit()
	var saved: ProfileState = _saved_profile()
	assert_bool(TutorialFlags.has_seen(saved, TutorialFlags.GUIDE_REPLAY)).is_true()
	assert_bool(TutorialFlags.has_seen(saved, TutorialFlags.GUIDE_DONE)).is_true()
	assert_bool(TutorialFlags.guided_due(saved)).is_true()
	assert_str(FileAccess.get_file_as_string(_run_file())).is_equal(run_before)
	assert_bool(page.replay_plate.visible).is_false()
	assert_bool(page.replay_note.visible).is_true()
	var event: Dictionary = _last_event("tutorial_replay")
	assert_str(event["from"]).is_equal("title")
	assert_str(str(event.get("run_id", ""))).is_empty()
	assert_bool(title.title_guide().is_active()).is_true()
	assert_bool(title.title_guide().is_showing()).is_false()  # Under the handbook.
	page.close()
	await _frames(1)
	assert_bool(title.title_guide().is_showing()).is_true()
	assert_str(title.title_guide().line()).contains("Click NEW RUN.")


## RESET TIPS on the title: a first press only asks; the second clears the tips' and quick
## tutorials' flags in the saved profile (the guided run's and the other flags stay), logged as
## tips_reset with how many; DONE keeps them cleared.
func test_reset_tips_on_the_title_clears_only_the_tips() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.seen = [
		TutorialFlags.GUIDE_DONE,
		TutorialFlags.tip(&"coupon"),
		&"capsule_machine",
		TutorialFlags.quick(TutorialFlags.QUICK_SWAP),
	]
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()
	var title: TitleScreen = await _title()
	title.menu().plate(TitleMenu.Entry.OPTIONS).pressed.emit()
	var options: OptionsCard = title.options()
	options.press_reset()
	assert_bool(options.reset_armed()).is_true()
	assert_str(options.reset_note().text).is_equal(OptionsCard.RESET_ASK)
	assert_int(_saved_profile().seen.size()).is_equal(4)
	options.press_reset()
	var kept: Array[StringName] = [TutorialFlags.GUIDE_DONE, &"capsule_machine"]
	assert_array(_saved_profile().seen).is_equal(kept)
	assert_str(options.reset_note().text).is_equal(OptionsCard.RESET_DONE)
	var event: Dictionary = _last_event("tips_reset")
	assert_int(int(event["cleared"])).is_equal(2)
	assert_str(str(event.get("run_id", ""))).is_empty()
	options.close()
	assert_array(_saved_profile().seen).is_equal(kept)


## RESET TIPS on the sheet: Enter on its row asks, marking another row takes the question back,
## and its note sits on the sheet, right of its chip, at every TEXT SIZE.
func test_reset_tips_asks_first_and_fits_the_sheet() -> void:
	for size_index: int in ProfileState.TEXT_SIZES.size():
		var profile: ProfileState = ProfileState.new()
		ProfileSettings.set_text_size(profile, size_index)
		GameSettings.apply_text_size(profile)
		profile.seen = [TutorialFlags.tip(&"redraw")]
		var host: Control = auto_free(Control.new())
		host.size = Vector2(1280, 720)
		add_child(host)
		var card: OptionsCard = OptionsCard.new()
		card.still = true
		host.add_child(card)
		card.open(profile, GameSettings.new(), null)
		var cleared: Array[int] = []
		card.tips_reset.connect(func(count: int) -> void: cleared.append(count))
		for step: int in OptionsCard.Row.RESET + 1:
			card.move_marker(1)
		assert_int(card.marked_row()).is_equal(OptionsCard.Row.RESET)
		assert_str(card.hint_label().text).is_equal(OptionsCard.HINTS[OptionsCard.Row.RESET])
		card.handle_key(_key(KEY_ENTER))
		assert_bool(card.reset_armed()).is_true()
		await get_tree().process_frame
		var sheet: Rect2 = card.sheet().get_global_rect().grow(-4.0)
		var note: Rect2 = Rect2(
			card.reset_note().global_position, UiKit.pixel_text_size(card.reset_note())
		)
		var chip: Rect2 = (card.chips(OptionsCard.Row.RESET)[0] as Control).get_global_rect()
		assert_bool(sheet.encloses(note)).override_failure_message(str(size_index)).is_true()
		assert_float(note.position.x).is_greater(chip.end.x)
		card.move_marker(-1)
		assert_bool(card.reset_armed()).is_false()
		assert_bool(card.reset_note().visible).is_false()
		assert_array(profile.seen).is_equal([TutorialFlags.tip(&"redraw")])
		card.move_marker(1)
		card.handle_key(_key(KEY_ENTER))
		card.handle_key(_key(KEY_ENTER))
		assert_array(profile.seen).is_empty()
		assert_array(cleared).is_equal([1])
		card.close()
	UiKit.reading_scale = 1.0


## In a run: the handbook (the top bar's or the pause's) offers PLAY THE GUIDED SHIFT; a click
## saves the profile with the replay asked for, logged under the run, and the run's save stays
## as it was. A guided run's handbook offers nothing.
func test_replay_in_a_run_saves_the_profile_not_the_run() -> void:
	_write_profile(true)
	var screen: ShiftScreen = await _screen()
	var page: HandbookPage = screen._pause._guide
	page.open_at()
	page.show_group(HandbookBook.shared().group_ids[0])
	assert_bool(page.replay_plate.visible).is_true()
	var run_before: String = FileAccess.get_file_as_string(_run_file())
	page.replay_plate.pressed.emit()
	assert_bool(TutorialFlags.has_seen(_saved_profile(), TutorialFlags.GUIDE_REPLAY)).is_true()
	assert_bool(TutorialFlags.has_seen(screen.profile, TutorialFlags.GUIDE_REPLAY)).is_true()
	assert_str(FileAccess.get_file_as_string(_run_file())).is_equal(run_before)
	assert_bool(page.replay_note.visible).is_true()
	var event: Dictionary = _last_event("tutorial_replay")
	assert_str(event["from"]).is_equal("run")
	assert_str(str(event["run_id"])).is_equal(_event_log().run_id)
	assert_str(_event_log().run_id).is_not_empty()
	page.close()
	screen.run.guided = true
	page.open_at()
	assert_bool(page.replay_plate.visible).is_false()
	assert_bool(page.replay_note.visible).is_false()
	page.close()


## RESET TIPS from the pause: logged under the run; the options' DONE saves the profile without
## the tips' flags.
func test_reset_tips_in_a_run_is_logged_under_the_run() -> void:
	var screen: ShiftScreen = await _screen()
	TutorialFlags.mark_tip(screen.profile, &"payday")
	screen._pause.open()
	screen._pause.pause.activate(PauseMenu.Entry.OPTIONS)
	var options: OptionsCard = screen._pause.options
	assert_bool(options.is_open()).is_true()
	options.press_reset()
	options.press_reset()
	var event: Dictionary = _last_event("tips_reset")
	assert_int(int(event["cleared"])).is_equal(1)
	assert_str(str(event["run_id"])).is_equal(_event_log().run_id)
	options.close()
	assert_bool(TutorialFlags.tip_seen(_saved_profile(), &"payday")).is_false()
	screen._pause.close()


## The ring encloses `target` with room to spare, and the ring, its CLICK tab and the callout lie
## inside the window; the callout covers neither the ring nor its tab.
func _assert_ring_and_card(title: TitleScreen, target: Rect2, case: String) -> void:
	var guide: TitleGuide = title.title_guide()
	var ring: Rect2 = guide.ring_rect()
	var card: Rect2 = guide.card().get_global_rect()
	var tab: Rect2 = Rect2(
		guide.click_tab().global_position, UiKit.pixel_text_size(guide.click_tab())
	)
	var screen: Rect2 = title.get_viewport_rect()
	var label: String = "%s ring %s card %s tab %s" % [case, ring, card, tab]
	var frame: float = TitleGuide.INK * 2.0 + TitleGuide.BORDER
	var inner: Rect2 = ring.grow(-frame)
	assert_bool(inner.encloses(target)).override_failure_message(label).is_true()
	for rect: Rect2 in [ring, card, tab]:
		assert_bool(screen.encloses(rect)).override_failure_message(label).is_true()
	assert_bool(card.intersects(ring)).override_failure_message(label).is_false()
	assert_bool(card.intersects(tab)).override_failure_message(label).is_false()
	assert_float(guide.card().size.y).is_greater(0.0)


## The title, its intro ended unless `skip` is false.
func _title(skip: bool = true) -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	if skip:
		title.skip_intro()
	await _frames(4)
	return title


## A new run on the shift screen (its time card skipped), on the save folder's profile.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	return screen


## Saves a profile done with the guided run (`done`) or a fresh one.
func _write_profile(done: bool) -> void:
	var profile: ProfileState = ProfileState.new()
	if done:
		TutorialFlags.finish_guide(profile)
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()


func _saved_profile() -> ProfileState:
	return SaveService.new(_folder).peek_profile()


## A run in planning on `shift` (1-based), saved under RUN_ID.
func _save_run_at_shift(shift: int) -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(31, deck, balance, RunStock.starting(balance))
	run.start_shift()
	run.debug_skip_to_shift(shift - 1)
	assert_bool(SaveService.new(_folder).save_run(run, RUN_ID, 1000)).is_true()


func _run_file() -> String:
	return _folder.path_join(SaveService.RUN_FILE)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


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
