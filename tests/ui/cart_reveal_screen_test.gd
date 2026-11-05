extends GdUnitTestSuite
## The cart reveal on the real shift screen (v0.51): who opens it (the title's request for the new
## run of the screen it opens, start_new_run with `reveal`, the debug panel's new run with a
## seed; never a resumed run, nor a screen opened another way), that it shows the run as dealt
## and saved on the two-page start board over the stage, that clock-in hands shift 1 over as
## dealt, that the board's cards use the reveal's scan popup, and that a run started without it
## closes it.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	# A request no screen took must not reach another suite's screen.
	CartReveal._request = false
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_screen_opened_without_a_request_starts_without_it() -> void:
	var screen: ShiftScreen = await _screen()
	assert_bool(screen._cart_reveal.is_open()).is_false()
	assert_bool(screen._cart_reveal.requested).is_false()


## The title's New run: the new run opens on the reveal, already dealt and saved, showing its
## staples and (since #107) the starter pack choice, today's products in the dispenser; the
## request is used up.
func test_the_titles_request_opens_it_on_the_new_run() -> void:
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	var reveal: CartReveal = screen._cart_reveal
	assert_bool(reveal.is_open()).is_true()
	# The machine's notice waits for the reveal to fold (it would pulse under the dim).
	assert_bool(screen._machine._notice_due).is_false()
	assert_bool(CartReveal._request).is_false()
	# A run with a start setup opens the two-page board, never the older panel (or its sounds).
	assert_object(reveal.panel()).is_null()
	assert_object(reveal.board).is_not_null()
	assert_bool(reveal.is_choosing()).is_true()
	assert_object(reveal.board.run).is_same(screen.run)
	assert_int(screen.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_bool(FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE))).is_true()
	# Over the deck view and the machine: the screen's last child but the debug panel.
	assert_int(reveal.get_index()).is_greater(screen._deck_view.get_index())


## A resumed run never shows it, and drops the title's request.
func test_a_resumed_run_drops_the_request() -> void:
	var first: ShiftScreen = await _screen()
	var seed_value: int = first.run.run_seed
	first.queue_free()
	await get_tree().process_frame
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	assert_int(screen.run.run_seed).is_equal(seed_value)
	assert_bool(screen._cart_reveal.is_open()).is_false()
	assert_bool(CartReveal._request).is_false()


## A new run with the reveal (start_new_run's `reveal`) and the debug panel's replay open it.
func test_a_new_run_and_the_debug_new_runs_open_it() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(screen._log.new_run_seed(), true, true)
	assert_bool(screen._cart_reveal.is_open()).is_true()
	screen._cart_reveal.close()
	screen._debug.replay_seed(42)
	assert_bool(screen._cart_reveal.is_open()).is_true()
	assert_int(screen.run.run_seed).is_equal(42)
	# A run started without it (a demo row, a test's seed) closes it.
	screen.start_new_run(43)
	assert_bool(screen._cart_reveal.is_open()).is_false()


## The title's request opens the full two-page board over the stage. Clock-in starts shift 1
## behind the shutter: the hand dealt then is the one planning opens with, its time to checkout
## starts and the machine's notice is due only once the shutter has cleared it.
func test_the_opening_board_covers_the_stage_and_clocks_in() -> void:
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	var reveal: CartReveal = screen._cart_reveal
	var board: StartBoard = reveal.board
	assert_int(board.page).is_equal(1)
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_bool(board.get_global_rect().encloses(stage)).is_true()
	screen.profile.set_reduced_motion(true)
	# Nothing is dealt until LOCK IN & DEAL, so page 2 waits for it.
	board.show_page(2, "enter")
	assert_int(board.page).is_equal(1)
	assert_bool(board.lock_in()).is_true()
	board.show_page(2, "enter")
	board.pick(0)
	var pack: StarterPackDefinition = screen.run.start_offer.packs[0]
	# Recorded after the screen's own handlers (connected first): shift 1 as the shutter covers
	# the board, and the machine as the shutter opens.
	var dealt: Array[CardInstance] = []
	var notice_due: Array[bool] = []
	reveal.pack_taken.connect(
		func(_taken: StarterPackDefinition) -> void: dealt.assign(screen.run.hand())
	)
	reveal.finished.connect(func() -> void: notice_due.append(screen._machine._notice_due))
	var clocked_ms: int = Time.get_ticks_msec()
	assert_bool(reveal.take_pack()).is_true()
	for frame: int in 3:
		await get_tree().process_frame
	assert_bool(reveal.is_open()).is_false()
	# Shift 1's time to checkout starts once the shutter is gone (plan section 8).
	assert_int(screen.tracker._start_ms).is_greater_equal(clocked_ms)
	assert_array(notice_due).is_equal([true])
	assert_int(dealt.size()).is_equal(screen.run.balance.hand_size)
	assert_array(screen.run.hand()).is_equal(dealt)
	# The hand comes from the cart the board showed: regulars, today's stock and the pack.
	var cart: Array[CardDefinition] = screen.run.starter.core_cards + screen.run.start_offer.shared
	cart.append_array(pack.cards)
	for card: CardInstance in dealt:
		assert_array(cart).contains([card.definition])
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(screen.run.row).is_empty()


## The board's card tiles show the reveal's own scan popup after its hold (hover_hold_ms), over
## the board and on the stage; leaving the tile hides it.
func test_the_boards_cards_show_the_reveals_popup() -> void:
	CartReveal.request()
	var screen: ShiftScreen = await _screen()
	var reveal: CartReveal = screen._cart_reveal
	reveal.set_process(false)
	var tile: Control = null
	for node: Node in reveal.board.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if tile == null and control.has_meta("card") and control.is_visible_in_tree():
			tile = control
	assert_object(tile).is_not_null()
	reveal.hover(tile)
	reveal.hover_for(maxf(reveal.hover_hold_ms - 50, 0) / 1000.0)
	assert_bool(reveal.popup().visible).is_equal(reveal.hover_hold_ms < 50)
	reveal.hover_for(0.1)
	assert_bool(reveal.popup().visible).is_true()
	assert_int(reveal.popup().get_index()).is_greater(reveal.board.get_index())
	assert_bool(reveal.board.stage_rect().encloses(reveal.popup().get_global_rect())).is_true()
	reveal.hover(null)
	assert_bool(reveal.popup().visible).is_false()


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	for _frame: int in range(2):
		await get_tree().process_frame
	return screen


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
