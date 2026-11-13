extends GdUnitTestSuite
## The shift's pause (mock-up options_pause.html, direction A) on the real shift screen: Esc, P
## and the ☰ button open and close it, Esc closes the topmost thing first, the tree pauses and
## the played time leaves the pause out, the plates sit clear of the register column, and
## SAVE & QUIT goes to the title with the run as it was saved. The real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().paused = false
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_esc_p_and_the_menu_button_open_and_close_the_pause() -> void:
	var screen: ShiftScreen = await _screen()
	var flow: PauseFlow = screen._pause
	await _press(KEY_ESCAPE)
	assert_bool(flow.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(flow.pause.marked_entry()).is_equal(PauseMenu.Entry.RESUME)
	await _press(KEY_ESCAPE)
	assert_bool(flow.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	await _press(KEY_P)
	assert_bool(flow.is_open()).is_true()
	await _press(KEY_P)
	assert_bool(flow.is_open()).is_false()
	var bar: TopBar = screen._top_bar as TopBar
	bar.menu_button.pressed.emit()
	assert_bool(flow.is_open()).is_true()
	assert_bool(bar.menu.visible).is_false()  # The ☰ popup is replaced by the pause.
	# The shade leaves the ☰ button lit, and a click there resumes.
	assert_bool(flow.pause.shade().hole().has_area()).is_true()
	bar.menu_button.pressed.emit()
	assert_bool(flow.is_open()).is_false()


func test_esc_closes_the_topmost_thing_first() -> void:
	var screen: ShiftScreen = await _screen()
	var guide: HandbookPage = screen._pause._guide
	guide.open_at()
	await _press(KEY_ESCAPE)
	assert_bool(guide.is_open()).is_false()
	assert_bool(screen._pause.is_open()).is_false()
	await _press(KEY_ESCAPE)
	assert_bool(screen._pause.is_open()).is_true()
	# HOW TO PLAY opens the handbook over the paused shift; its Esc closes it, back to the pause.
	screen._pause.pause.activate(PauseMenu.Entry.GUIDE)
	assert_bool(guide.is_open()).is_true()
	assert_bool(screen._pause.pause.visible).is_false()
	await _press(KEY_ESCAPE)
	assert_bool(guide.is_open()).is_false()
	assert_bool(screen._pause.pause.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	# OPTIONS opens over the pause; Esc closes the options first, then the pause.
	screen._pause.pause.activate(PauseMenu.Entry.OPTIONS)
	assert_bool(screen._pause.options.is_open()).is_true()
	await _press(KEY_ESCAPE)
	assert_bool(screen._pause.options.is_open()).is_false()
	assert_bool(screen._pause.is_open()).is_true()
	await _press(KEY_ESCAPE)
	assert_bool(screen._pause.is_open()).is_false()


func test_the_tree_pauses_and_played_time_leaves_the_pause_out() -> void:
	var screen: ShiftScreen = await _screen()
	var started: int = screen._run_started_ms
	var probe: Node = auto_free(Node.new())
	screen.add_child(probe)
	var ticks: Array[int] = [0]
	var tween: Tween = probe.create_tween()
	tween.tween_method(func(_v: float) -> void: ticks[0] += 1, 0.0, 1.0, 5.0)
	await get_tree().process_frame
	screen._pause.open()
	var at_pause: int = ticks[0]
	for i: int in 5:
		await get_tree().process_frame
	assert_int(ticks[0]).is_equal(at_pause)  # Frozen while paused.
	screen._pause.close()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(ticks[0]).is_greater(at_pause)  # And runs on from where it stopped.
	assert_int(screen._run_started_ms).is_greater(started)


func test_the_plates_stand_clear_of_the_register_column() -> void:
	var screen: ShiftScreen = await _screen()
	screen._pause.pause.still = true
	screen._pause.open()
	await get_tree().process_frame
	var key: Rect2 = screen._checkout_button.get_global_rect()
	var pause: PauseMenu = screen._pause.pause
	var window: Rect2 = Rect2(Vector2.ZERO, pause.size)
	# The LANE CLOSED sign hangs settled over the column, clear of the key and the plates.
	var hung: LaneClosedSign = pause.lane_sign()
	assert_bool(hung.is_settled()).is_true()
	var board: Rect2 = hung.get_global_rect()
	assert_bool(window.encloses(board)).is_true()
	assert_bool(board.intersects(key)).is_false()
	var first: Rect2 = pause.plate(PauseMenu.Entry.RESUME).get_global_rect()
	assert_float(board.end.y).is_less_equal(first.position.y)
	for entry: int in PauseMenu.Entry.size():
		var rect: Rect2 = pause.plate(entry as PauseMenu.Entry).get_global_rect()
		assert_bool(window.encloses(rect)).is_true()
		assert_bool(rect.intersects(key)).is_false()
	for entry: int in PauseMenu.Entry.size():
		pause.mark(entry)
		var note: Label = pause.note_label()
		var note_rect: Rect2 = Rect2(note.global_position, note.get_minimum_size())
		assert_bool(note_rect.intersects(key)).is_false()
		assert_float(note_rect.end.y).is_less_equal(
			pause.export_link().get_global_rect().position.y
		)


func test_save_and_quit_goes_to_the_title_with_the_run_as_saved() -> void:
	var screen: ShiftScreen = await _screen()
	screen.changes_scene = false
	TitleScreen.take_lit_request()
	var hand: Array = screen.run.hand().map(
		func(card: CardInstance) -> StringName: return card.definition.id
	)
	var shift: int = screen.run.shift_index
	screen._pause.open()
	screen._pause.pause.activate(PauseMenu.Entry.QUIT)
	assert_bool(get_tree().paused).is_false()
	assert_bool(TitleScreen.take_lit_request()).is_true()
	var balance: BalanceDefinition = load(ShiftScreen.BALANCE)
	var saves: SaveService = SaveService.new(SaveService.default_folder())
	var saved: RunSave = saves.peek_run(ContentLookup.new(balance))
	assert_object(saved).is_not_null()
	assert_int(saved.run.shift_index).is_equal(shift)
	var saved_hand: Array = saved.run.hand().map(
		func(card: CardInstance) -> StringName: return card.definition.id
	)
	assert_array(saved_hand).is_equal(hand)


func test_welcome_back_shows_on_a_resume_not_on_a_first_start() -> void:
	var first: ShiftScreen = await _screen()
	assert_bool(first._pause.welcome.visible).is_false()
	first.changes_scene = false
	first._pause.save_and_quit()
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)  # CONTINUE: the save is resumed.
	var resumed: ShiftScreen = runner.scene()
	await get_tree().process_frame
	assert_bool(resumed._pause.welcome.visible).is_true()
	assert_int(resumed.run.shift_index).is_equal(first.run.shift_index)


## v1.36 (polish batch 1): Esc closes the time card and the cart as a click on them does, and the
## pause stays shut under them; with them closed, Esc opens the pause as before.
func test_esc_closes_the_time_card_and_the_cart_before_the_pause() -> void:
	var screen: ShiftScreen = await _screen()
	var card: WeekCard = screen._week.card
	screen._week.reopen()
	assert_bool(card.is_open()).is_true()
	await _press(KEY_ESCAPE)
	assert_bool(screen._pause.is_open()).is_false()
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()
	screen._on_deck_button_pressed()
	var cart: DeckView = screen._deck_view
	assert_bool(cart.visible).is_true()
	await _press(KEY_ESCAPE)
	assert_bool(cart.visible).is_false()
	assert_bool(screen._pause.is_open()).is_false()
	await _press(KEY_ESCAPE)
	assert_bool(screen._pause.is_open()).is_true()


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	# A new run's first week plays its time card, which takes Esc first since v1.36: nothing open.
	screen._week.skip()
	for i: int in 2:
		await get_tree().process_frame
	return screen


func _press(keycode: Key) -> void:
	_runner.simulate_key_pressed(keycode)
	for i: int in 3:
		await get_tree().process_frame


func _event_log() -> EventLogService:
	return get_tree().root.get_node("EventLog") as EventLogService
