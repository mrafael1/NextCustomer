extends GdUnitTestSuite
## The puzzle shifts on screen (#183, full build plan section 7.6), at 1280x720: the title offers
## PUZZLES once a run has ended, as the puzzle planner in the storefront's right window (no plate:
## QUIT stays on the brick), hot under the mouse or the keys, a click on it opening the board;
## the board's sheet, tabs, cards, clipboard and PLAY inside the window, the cards clear of the
## clipboard; a locked pack's tab opens nothing; PLAY asks for the puzzle; a completed pack is
## golden and shines once after the solve that completed it. On the shift screen a puzzle
## replaces the run save's run (left as it is): the puzzle's tip stands where the Redraw key was,
## inside the register and clear of CHECKOUT; the overlay (PUZZLE n, its pack and title, BOARD
## and RETRY) right of the belt's end, clear of the monitor and the receipt, for every belt
## length; the Redraw key and the week glass hidden, the
## desk calendar and the bell on the register's top as in a run (a puzzle's day events show on
## the calendar's page and its slip, as a run's: play test 2026-11-23); the gauge is the exact
## tube, in a run's gauge's place and size (no SHIFT chip, its lamp lit: no leftover socket);
## planning shows the projected total on the receipt
## and the gauge as a run's does (play test 2026-11-23), past the target in tomato. An exact
## checkout stamps EXACT on the receipt, records the solve in the saved profile and brings NEXT in
## big over the belt (RETRY small beside it), clear of CHECKOUT, the monitor, the receipt and the
## overlay; RETRY puts the belt back; a miss stamps SHORT n€ and brings RETRY in big. The real
## saves and logs are never touched.

const TITLE := "res://ui/title_screen.tscn"
const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
const PUZZLE := &"op_first_customer"

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)
	PuzzlePlay.take()
	PuzzlePlay.take_board()
	PuzzlePlay.take_completed()


func after_test() -> void:
	PuzzlePlay.take()
	PuzzlePlay.take_board()
	PuzzlePlay.take_completed()
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A new profile sees no PUZZLES; once a run has ended the planner stands inside the right window
## (no plate: every plate on the brick, above the sidewalk), clear of the plates and of register
## 3's monitor; the mouse or the keys make it hot (lifted, lit) and a click on it opens the board.
func test_the_title_offers_puzzles_after_a_run() -> void:
	var title: TitleScreen = await _title()
	assert_bool(title.storefront().planner.visible).is_false()
	assert_bool(title.menu().entries().has(TitleMenu.Entry.PUZZLES)).is_false()
	_save_profile(1, [])
	title = await _title()
	var front: Storefront = title.storefront()
	assert_bool(front.planner.visible).is_true()
	assert_object(title.menu().plate(TitleMenu.Entry.PUZZLES)).is_null()
	var rect: Rect2 = front.get_global_transform() * front.planner_rect()
	assert_that(front.planner.get_global_rect()).is_equal(rect)
	var stage_at: Vector2 = front.stage().get_global_rect().position
	var art: Rect2 = Rect2(StorefrontArt.TUBE_WINDOW_RECT)
	var window: Rect2 = Rect2(stage_at + art.position * 2.0, art.size * 2.0)
	assert_bool(window.encloses(rect)).override_failure_message(str(rect)).is_true()
	var sidewalk: float = stage_at.y + StorefrontArt.SIDEWALK.x * 2.0
	for entry: TitleMenu.Entry in title.menu().entries():
		if entry == TitleMenu.Entry.PUZZLES:
			continue
		var other: Rect2 = title.menu().plate(entry).get_global_rect()
		assert_bool(rect.intersects(other)).override_failure_message(str(entry)).is_false()
		assert_float(other.end.y).override_failure_message(str(entry)).is_less_equal(sidewalk)
	var centre: Vector2 = rect.get_center()
	assert_int(title.target_at(centre)).is_equal(TitleScreen.Target.PLANNER)
	title.menu().mark(TitleMenu.Entry.PUZZLES)
	assert_bool(front.planner.hot).is_true()
	assert_float(front.planner.position.y).is_less(front.planner.home.y)
	title.menu().mark(TitleMenu.Entry.NONE)
	assert_bool(front.planner.hot).is_false()
	var entries: Array[TitleMenu.Entry] = title.menu().entries()
	for step: int in entries.find(TitleMenu.Entry.PUZZLES) + 1:
		title.menu().move_marker(1)
	assert_int(title.menu().marked_entry()).is_equal(TitleMenu.Entry.PUZZLES)
	assert_bool(front.planner.hot).is_true()
	title.menu().activate(title.menu().marked_entry())
	await _frames(2)
	assert_bool(title._puzzles.is_open()).is_true()


## The board's parts lie inside the window; the cards are clear of the clipboard and of each
## other; a locked pack's tab opens nothing; PLAY asks for the picked puzzle.
func test_the_board_fits_the_window_and_plays() -> void:
	_save_profile(1, [&"op_first_customer"])
	var title: TitleScreen = await _title()
	title.menu().activate(TitleMenu.Entry.PUZZLES)
	var board: PuzzleBoard = title._puzzles
	await _frames(20)
	assert_bool(board.is_open()).is_true()
	assert_bool(SCREEN_RECT.encloses(board.sheet().get_global_rect())).is_true()
	var clip: Rect2 = board.clipboard_rect()
	assert_bool(board.sheet().get_global_rect().encloses(clip)).is_true()
	var hits: Array[Control] = board.card_hits()
	for index: int in hits.size():
		var card: Rect2 = hits[index].get_global_rect()
		(
			assert_bool(board.sheet().get_global_rect().encloses(card))
			. override_failure_message("%s in %s" % [card, board.sheet().get_global_rect()])
			. is_true()
		)
		assert_bool(card.intersects(clip)).is_false()
		for other: Control in hits.slice(index + 1):
			assert_bool(card.intersects(other.get_global_rect())).is_false()
	for hit: Control in board.tab_hits() + [board.play_hit(), board.back_hit()]:
		assert_bool(board.sheet().get_global_rect().encloses(hit.get_global_rect())).is_true()
	assert_bool(clip.encloses(board.play_hit().get_global_rect())).is_true()
	assert_int(board.pack).is_equal(1)
	assert_str(String(board.picked.id)).is_equal("op_banana_split")
	board._press(board.tab_hits()[1])
	assert_int(board.pack).is_equal(1)
	var asked: Array[StringName] = []
	board.play_requested.connect(func(id: StringName) -> void: asked.append(id))
	board._press(board.play_hit())
	assert_array(asked).is_equal([&"op_banana_split"])
	assert_str(String(PuzzlePlay.take())).is_equal("op_banana_split")


## A completed pack is golden; the first time the board opens after the solve that completed it
## (PuzzlePlay.note_completed), it opens on that pack and the light sweeps once, then stops.
func test_a_completed_pack_is_golden_and_shines_once() -> void:
	var solved: Array[StringName] = []
	for puzzle: PuzzleDefinition in PuzzlePlay.list().pack(1):
		solved.append(puzzle.id)
	_save_profile(1, solved)
	var title: TitleScreen = await _title()
	PuzzlePlay.note_completed(1)
	title.open_puzzles()
	var board: PuzzleBoard = title._puzzles
	assert_bool(board.is_golden(1)).is_true()
	assert_bool(board.is_golden(2)).is_false()
	assert_int(board.pack).is_equal(1)
	var shone: bool = false
	for frame: int in 180:
		await get_tree().process_frame
		shone = shone or board.is_shining()
	assert_bool(shone).is_true()
	assert_bool(board.is_shining()).is_false()
	board.close()
	title.open_puzzles()
	await _frames(40)
	assert_bool(board.is_shining()).is_false()


## The puzzle's screen: the tip in the register, clear of CHECKOUT; the overlay right of the
## belt's end, clear of the monitor and the receipt, its keys inside it; the run's keys hidden;
## the exact gauge where a run's stands (ShiftStage.GAUGE_PANEL_RECT, as RegisterTowerTest checks
## a run's), its glass and lamp inside it; the run save untouched.
func test_a_puzzle_shift_hides_the_run_parts() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	assert_object(screen.puzzle_flow).is_not_null()
	var hint: Rect2 = screen.puzzle_flow.hint.get_global_rect()
	assert_bool(screen._stage.register.get_global_rect().encloses(hint)).is_true()
	assert_bool(hint.intersects(screen._checkout_button.get_global_rect())).is_false()
	assert_int(screen.puzzle_flow.hint.lines().size()).is_greater(0)
	var overlay: PuzzleOverlay = screen.puzzle_flow.overlay
	_assert_overlay_clear(screen, overlay)
	assert_str(overlay.number_text()).is_equal("PUZZLE 1")
	assert_str(overlay.pack_text()).is_equal("OPENING")
	assert_str(overlay.title_text()).is_equal(screen.puzzle_flow.puzzle.title)
	assert_bool(overlay.retry_key().visible).is_true()
	assert_bool(screen.puzzle_flow.verdict_keys.big_key().visible).is_false()
	await _frames(2)  # The week 1 strip's refresh (TutorialDirector) runs on a frame.
	assert_bool(screen._redraw_button.visible).is_false()
	assert_bool(screen._stage.week_glass.visible).is_false()
	assert_bool(screen._stage.bell.visible).is_true()
	_assert_desk_calendar(screen)
	assert_int(screen._calendar.look()).is_equal(DayCalendarArt.Look.NORMAL)
	assert_bool(screen._receipt.target.puzzle).is_true()
	assert_bool(screen._quota_meter.exact).is_true()
	var top_bar: TopBar = screen._top_bar as TopBar
	assert_bool(top_bar.shift_chip.visible).is_false()
	var chip: Rect2 = screen._stage.gauge_panel.get_global_rect()
	var stage_at: Vector2 = screen._stage.get_global_rect().position
	var rest: Rect2 = Rect2(
		stage_at + ShiftStage.GAUGE_PANEL_RECT.position, ShiftStage.GAUGE_PANEL_RECT.size
	)
	assert_that(chip).is_equal(rest)
	var glass: Rect2 = screen._quota_meter.get_global_rect()
	assert_bool(chip.encloses(glass)).override_failure_message(str(glass)).is_true()
	var lamp: Rect2 = screen._quota_meter.get_global_transform() * screen._quota_meter.badge_rect()
	assert_bool(chip.encloses(lamp)).is_true()
	assert_float(lamp.end.x).is_less_equal(glass.position.x)
	assert_int(screen.run.quota()).is_equal(10)
	assert_bool(FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE))).is_false()


## Every belt length the puzzles use (3 to 6 cells) leaves the overlay room right of the belt's
## end: a 6-cell belt's narrow room stacks its keys.
func test_the_overlay_fits_every_belt() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	var overlay: PuzzleOverlay = screen.puzzle_flow.overlay
	for cells: int in [3, 4, 5, 6]:
		screen.puzzle_flow._fit_to_belt(cells)
		_assert_overlay_clear(screen, overlay, BeltPanel.cut_of(cells))
		assert_bool(overlay.is_stacked()).override_failure_message(str(cells)).is_equal(cells == 6)


## An exact checkout: EXACT on the receipt, the solve saved in the profile, NEXT in big over the
## belt with a small RETRY beside it, clear of CHECKOUT, the monitor, the receipt and the overlay;
## the small RETRY then puts the belt back as it was checked out and the keys go.
func test_an_exact_checkout_is_solved_and_retried() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	await _check_out(screen, PackedStringArray(["bread", "soup"]))
	assert_int(screen.puzzle_flow.last_verdict).is_equal(PuzzleRun.Verdict.EXACT)
	var stamp: Label = screen._receipt.target.stamp
	assert_bool(stamp.visible).is_true()
	assert_str(stamp.text).is_equal("EXACT")
	assert_bool(SCREEN_RECT.encloses(stamp.get_global_rect())).is_true()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_array(saved.solved_puzzles).is_equal([PUZZLE])
	var keys: PuzzleVerdictKeys = await _landed(screen)
	assert_int(keys.big_kind()).is_equal(PuzzleVerdictKeys.Big.NEXT)
	assert_bool(keys.small_key().visible).is_true()
	assert_bool(screen.puzzle_flow.overlay.retry_key().visible).is_false()
	_assert_keys_clear(screen, [keys.big_key(), keys.small_key()])
	var big: Rect2 = keys.big_key().get_global_rect()
	assert_float(big.size.x).is_greater(screen.puzzle_flow.overlay.retry_key().size.x * 2.0)
	keys.small_key().pressed.emit()
	await _frames(2)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_array(CardInstance.names(screen.run.row)).is_equal(["Bread", "Soup"])
	assert_bool(stamp.visible).is_false()
	assert_bool(keys.big_key().visible).is_false()
	assert_bool(screen.puzzle_flow.overlay.retry_key().visible).is_true()


## Planning shows the projected total (play test 2026-11-23): the receipt's hero and the gauge
## follow the belt; over the target the gauge pours its second lap in tomato, the lamp lit tomato
## with no check.
func test_planning_previews_the_total() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	for card: CardInstance in PuzzleRun.row_of(screen.run, PackedStringArray(["bread", "soup"])):
		screen.run.place(card, screen.run.row.size())
	screen._refresh()
	await _eased(screen._quota_meter, 10.0)
	var target: ReceiptTarget = screen._receipt.target
	assert_bool(target.hero.visible).is_true()
	assert_int(screen._quota_meter.amount()).is_equal(10)
	assert_str(screen._quota_meter.badge_text()).is_equal(LapLamp.CHECK_TEXT)
	screen.run.place(PuzzleRun.row_of(screen.run, PackedStringArray(["potatoes"]))[0], 0)
	screen._refresh()
	await _eased(screen._quota_meter, float(screen._quota_meter.amount()))
	assert_int(screen._quota_meter.amount()).is_greater(10)
	assert_array(screen._quota_meter.liquid_ramp()).is_equal(QuotaMeter.SPILL_RAMP)


## A miss stamps SHORT and the gap; nothing is saved as solved; RETRY comes in big (alone),
## centred on the belt's shown part, clear of the screen's parts.
func test_a_miss_reads_short() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	await _check_out(screen, PackedStringArray(["bread"]))
	assert_int(screen.puzzle_flow.last_verdict).is_equal(PuzzleRun.Verdict.SHORT)
	assert_str(screen._receipt.target.stamp.text).is_equal("SHORT 5€")
	assert_array(SaveService.new(_folder).load_profile().solved_puzzles).is_empty()
	var keys: PuzzleVerdictKeys = await _landed(screen)
	assert_int(keys.big_kind()).is_equal(PuzzleVerdictKeys.Big.RETRY)
	assert_bool(keys.small_key().visible).is_false()
	_assert_keys_clear(screen, [keys.big_key()])
	var belt_middle: float = (PuzzleVerdictKeys.BELT_LEFT + 1266.0 - screen._stage.belt.cut()) / 2.0
	assert_float(absf(keys.big_key().get_global_rect().get_center().x - belt_middle)).is_less(2.0)


## A puzzle's day event shows where a run's does (play test 2026-11-23: "Slot 3 pays 0€" was on
## the puzzle bar): the desk calendar in its run place, its page the inspection's band and sign;
## a tap pops today's slip with its effect (Slot 3 pays 0€), above the calendar,
## inside the window; the tip's plate stays below the calendar, clear of it.
func test_a_puzzle_day_event_shows_on_the_calendar() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen(&"op_spot_check")
	await _frames(2)
	_assert_desk_calendar(screen)
	var calendar: DayCalendar = screen._calendar
	assert_int(calendar.look()).is_equal(DayCalendarArt.Look.INSPECTION)
	assert_int(calendar.day()).is_equal(1)
	assert_int((calendar.part_rects()["signs"] as Array).size()).is_equal(1)
	var tip: Rect2 = screen.puzzle_flow.hint.get_global_rect()
	assert_bool(tip.intersects(calendar.get_global_rect())).is_false()
	calendar.pressed.emit()
	var slip: DaySlip = screen._week.slip
	slip.settle()
	await _frames(2)
	assert_bool(slip.is_open()).is_true()
	assert_str(slip.slip_text()).contains("Slot 3 pays 0€")
	var paper: Rect2 = slip.paper().get_global_rect()
	assert_bool(SCREEN_RECT.encloses(paper)).override_failure_message(str(paper)).is_true()
	assert_float(paper.end.y).is_less_equal(calendar.get_global_rect().position.y)


## The puzzles' unlock tip (polish 5): the first title that offers puzzles rings the planner
## with the one-time tips' card (T17), inside the window; it is saved as seen at once, GOT IT
## closes it, and the next title shows none.
func test_the_unlock_tip_points_at_the_planner() -> void:
	_save_profile(1, [])
	var title: TitleScreen = await _title()
	var tip: TitlePuzzleTip = title._puzzle_tip
	assert_object(tip).is_not_null()
	for frame: int in 30:
		if tip.is_showing():
			break
		await get_tree().process_frame
	assert_bool(tip.is_showing()).is_true()
	await _frames(4)
	var planner: Rect2 = title.anchor_rect(TutorialAnchors.TITLE_PUZZLES)
	var rings: Array[Rect2] = tip.overlay().ring_rects()
	assert_int(rings.size()).is_equal(1)
	assert_bool(rings[0].grow(1.0).encloses(planner)).override_failure_message(str(rings)).is_true()
	var card: Rect2 = tip.overlay().callout().get_global_rect()
	assert_bool(SCREEN_RECT.encloses(card)).override_failure_message(str(card)).is_true()
	assert_bool(card.intersects(planner)).is_false()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_bool(TutorialFlags.tip_seen(saved, TitlePuzzleTip.TIP_ID)).is_true()
	tip.overlay().button_pressed.emit()
	assert_bool(tip.is_showing()).is_false()
	title = await _title()
	assert_object(title._puzzle_tip).is_null()


## Each pack's reward on the board (polish 5): pack 1's pin as a mystery badge under the cards
## until earned, then the real pin; the strip inside the sheet, clear of the cards and the
## clipboard.
func test_the_board_shows_each_packs_mystery_badge() -> void:
	_save_profile(1, [])
	var title: TitleScreen = await _title()
	title.open_puzzles()
	var board: PuzzleBoard = title._puzzles
	await _frames(20)
	assert_str(String(board.reward_pin(1).id)).is_equal("price_gun")
	assert_str(String(board.reward_pin(2).id)).is_equal("long_belt")
	assert_str(String(board.reward_pin(3).id)).is_equal("spotlight")
	assert_bool(board.reward_earned(1)).is_false()
	var strip: Rect2 = board.reward_rect()
	assert_bool(board.sheet().get_global_rect().encloses(strip)).is_true()
	assert_bool(strip.intersects(board.clipboard_rect())).is_false()
	for hit: Control in board.card_hits():
		assert_bool(strip.intersects(hit.get_global_rect())).is_false()
	board.profile.unlocked_pins.append(&"price_gun")
	assert_bool(board.reward_earned(1)).is_true()


## The overlay's words stand centred in the plate's height above its keys (polish 5: the gap
## under them was much bigger than over them), for every belt length; the BOARD key's icon sits
## on the 2 px art grid at a whole scale (crisp at any window scale); RETRY wears mustard.
func test_the_overlay_words_are_centred_and_the_icon_is_crisp() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	var overlay: PuzzleOverlay = screen.puzzle_flow.overlay
	for cells: int in [3, 4, 5, 6]:
		screen.puzzle_flow._fit_to_belt(cells)
		var top: float = overlay.text_top() - PuzzleOverlay.BLOCK_TOP_ROW
		var keys_top: float = (
			minf(overlay.board_key().position.y, overlay.retry_key().position.y)
			/ ArtStyle.ART_SCALE
		)
		var bottom: float = (
			keys_top - PuzzleOverlay.KEYS_GAP - overlay.text_top() - overlay.block_height()
		)
		var gaps: String = "%d: %s %s" % [cells, top, bottom]
		assert_float(absf(top - bottom)).override_failure_message(gaps).is_less_equal(1.0)
		var icon: TextureRect = overlay.board_key().icon_rect()
		var at: Vector2 = icon.get_global_rect().position
		assert_float(fmod(at.x, 2.0)).override_failure_message(str(at)).is_equal(0.0)
		assert_float(fmod(at.y, 2.0)).override_failure_message(str(at)).is_equal(0.0)
		assert_that(icon.size).is_equal(icon.texture.get_size() * ArtStyle.ART_SCALE)
	assert_object(overlay.retry_key()._frame).is_same(PuzzleOverlay.RETRY_FRAME)
	assert_object(overlay.board_key()._frame).is_same(PuzzleOverlay.KEY_FRAME)


## The tip starts hidden behind SHOW TIP (inside the plate); its press shows the hint; RETRY
## keeps it shown; the next puzzle hides it again.
func test_the_tip_is_hidden_until_asked() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	var hint: PuzzleHint = screen.puzzle_flow.hint
	assert_bool(hint.is_revealed()).is_false()
	var key: FramedButton = hint.show_key()
	assert_bool(key.visible).is_true()
	assert_bool(hint.get_global_rect().encloses(key.get_global_rect())).is_true()
	key.pressed.emit()
	assert_bool(hint.is_revealed()).is_true()
	assert_bool(key.visible).is_false()
	await _check_out(screen, PackedStringArray(["bread", "soup"]))
	screen.puzzle_flow.retry()
	assert_bool(hint.is_revealed()).is_true()
	await _check_out(screen, PackedStringArray())
	screen.puzzle_flow.next()
	assert_bool(hint.is_revealed()).is_false()
	assert_bool(key.visible).is_true()


## EXACT celebrates (polish 5): the stamp slams, confetti flies, the notch flashes; the keys land
## with an overshoot and the big one then pulses; a solve's NEXT is tomato with a mustard small
## RETRY, a miss's big RETRY mustard.
func test_an_exact_solve_celebrates() -> void:
	_save_profile(1, [])
	var screen: ShiftScreen = await _puzzle_screen()
	await _check_out(screen, PackedStringArray(["bread", "soup"]))
	var cheer: PuzzleCheer = screen.puzzle_flow.cheer
	var flew: bool = false
	var flashed: bool = false
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1000:
		flew = flew or cheer.pieces() > 0
		flashed = flashed or screen._quota_meter._notch_flash > 0.0
		await get_tree().process_frame
	assert_bool(flew).is_true()
	assert_bool(flashed).is_true()
	assert_bool(cheer.is_slamming()).is_false()
	assert_that(screen._receipt.target.stamp.scale).is_equal(Vector2.ONE)
	var keys: PuzzleVerdictKeys = await _landed(screen)
	assert_that(keys.big_key().scale).is_equal(Vector2.ONE)
	assert_object(keys.big_key()._frame).is_same(PuzzleVerdictKeys.GO_FRAME)
	assert_object(keys.small_key()._frame).is_same(PuzzleVerdictKeys.RETRY_FRAME)
	var pulsed: bool = false
	start = Time.get_ticks_msec()
	while not pulsed and Time.get_ticks_msec() - start < 2500:
		pulsed = keys.is_pulsing()
		await get_tree().process_frame
	assert_bool(pulsed).is_true()
	keys.small_key().pressed.emit()
	await _frames(2)
	screen.run.remove(screen.run.row[1])
	await _check_out(screen, PackedStringArray())
	keys = await _landed(screen)
	assert_int(keys.big_kind()).is_equal(PuzzleVerdictKeys.Big.RETRY)
	assert_object(keys.big_key()._frame).is_same(PuzzleVerdictKeys.RETRY_FRAME)
	var caption: Label = keys.big_key().caption_label()
	assert_int(caption.get_theme_constant("outline_size")).is_equal(UiKit.LIGHT_OUTLINE)


## The solve that completes a pack (polish 5): BOARD alone, on the gold button; the overlay turns
## gold; the pack's pin unlocks.
func test_completing_a_pack_turns_the_overlay_gold() -> void:
	var solved: Array[StringName] = []
	for puzzle: PuzzleDefinition in PuzzlePlay.list().pack(1).slice(0, 7):
		solved.append(puzzle.id)
	_save_profile(1, solved)
	var screen: ShiftScreen = await _puzzle_screen(&"op_spot_check")
	var overlay: PuzzleOverlay = screen.puzzle_flow.overlay
	assert_bool(overlay.is_golden()).is_false()
	await _check_out(screen, screen.puzzle_flow.puzzle.solution)
	assert_int(screen.puzzle_flow.last_verdict).is_equal(PuzzleRun.Verdict.EXACT)
	var keys: PuzzleVerdictKeys = await _landed(screen)
	assert_int(keys.big_kind()).is_equal(PuzzleVerdictKeys.Big.BOARD)
	assert_bool(keys.small_key().visible).is_false()
	assert_object(keys.big_key()._frame).is_same(PuzzleVerdictKeys.GOLD_FRAME)
	# The frame swap keeps the caption's ink: brass darkest on gold, no outline.
	var ink: Label = keys.big_key().caption_label()
	assert_that(ink.get_theme_color("font_color")).is_equal(Palette.BRASS_DARKEST)
	assert_int(ink.get_theme_constant("outline_size")).is_equal(0)
	var turned: bool = false
	for frame: int in 120:
		turned = turned or overlay.is_turning_gold()
		if overlay.is_golden():
			break
		await get_tree().process_frame
	assert_bool(turned).is_true()
	assert_bool(overlay.is_golden()).is_true()
	assert_object(overlay.board_key()._frame).is_same(PuzzleOverlay.GOLD_FRAME)
	assert_bool(screen.profile.unlocked_pins.has(&"price_gun")).is_true()


## Every PLAY on the board cuts to the puzzle: no doors, a short fade (a first PLAY here).
func test_board_play_skips_the_doors() -> void:
	_save_profile(1, [])
	var title: TitleScreen = await _title()
	title.open_puzzles()
	await _assert_play_cuts(title)


## Back from a puzzle's BOARD, PLAY cuts to the puzzle as well.
func test_board_play_after_a_puzzle_skips_the_doors() -> void:
	_save_profile(1, [])
	PuzzlePlay.request_board()
	await _assert_play_cuts(await _title())


func _assert_play_cuts(title: TitleScreen) -> void:
	assert_bool(title._puzzles.is_open()).is_true()
	title._puzzles._press(title._puzzles.play_hit())
	await _frames(20)
	assert_object(title._cut).is_not_null()
	assert_int(title.storefront().door_gap()).is_equal(0)
	assert_str(String(PuzzlePlay.take())).is_not_empty()


## The overlay inside the window, right of a belt cut `cut` px short, clear of the monitor, the
## receipt and the baskets' row; its keys inside it.
func _assert_overlay_clear(screen: ShiftScreen, overlay: PuzzleOverlay, cut: float = -1.0) -> void:
	var rect: Rect2 = overlay.get_global_rect()
	var stage_at: Vector2 = screen._stage.get_global_rect().position
	var belt_cut: float = screen._stage.belt.cut() if cut < 0.0 else cut
	var belt_end: float = stage_at.x + ShiftStage.BELT_RECT.end.x - belt_cut
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_float(rect.position.x).is_greater(belt_end)
	var monitor: Rect2 = Rect2(
		stage_at + ShiftStage.MONITOR_RECT.position, ShiftStage.MONITOR_RECT.size
	)
	assert_bool(rect.intersects(monitor)).is_false()
	assert_bool(rect.intersects(screen._receipt.get_global_rect())).is_false()
	assert_float(rect.end.y).is_less_equal(stage_at.y + ShiftStage.HAND_RECT.position.y)
	for key: FramedButton in [overlay.retry_key(), overlay.board_key()]:
		var key_rect: Rect2 = key.get_global_rect()
		assert_bool(rect.encloses(key_rect)).override_failure_message(str(key_rect)).is_true()


## The verdict keys inside the window, clear of CHECKOUT, the monitor, the receipt, the overlay
## and each other.
func _assert_keys_clear(screen: ShiftScreen, keys: Array[FramedButton]) -> void:
	var stage_at: Vector2 = screen._stage.get_global_rect().position
	var monitor: Rect2 = Rect2(
		stage_at + ShiftStage.MONITOR_RECT.position, ShiftStage.MONITOR_RECT.size
	)
	var parts: Array[Rect2] = [
		screen._checkout_button.get_global_rect(),
		monitor,
		screen._receipt.get_global_rect(),
		screen.puzzle_flow.overlay.get_global_rect(),
	]
	for index: int in keys.size():
		var rect: Rect2 = keys[index].get_global_rect()
		assert_bool(keys[index].visible).is_true()
		assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
		for part: Rect2 in parts:
			assert_bool(rect.intersects(part)).override_failure_message(str(part)).is_false()
		for other: FramedButton in keys.slice(index + 1):
			assert_bool(rect.intersects(other.get_global_rect())).is_false()


## Waits (up to 3 s) for the verdict keys' entrance to end; returns them.
func _landed(screen: ShiftScreen) -> PuzzleVerdictKeys:
	var keys: PuzzleVerdictKeys = screen.puzzle_flow.verdict_keys
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3000:
		if keys.is_landed() and keys.big_key().visible:
			break
		await get_tree().process_frame
	return keys


func _assert_desk_calendar(screen: ShiftScreen) -> void:
	var calendar: DayCalendar = screen._calendar
	assert_bool(calendar.is_visible_in_tree()).is_true()
	var stage_at: Vector2 = screen._stage.get_global_rect().position
	var rest: Rect2 = Rect2(
		stage_at + ShiftStage.DESK_CALENDAR_RECT.position, ShiftStage.DESK_CALENDAR_RECT.size
	)
	assert_that(calendar.get_global_rect()).is_equal(rest)


func _check_out(screen: ShiftScreen, ids: PackedStringArray) -> void:
	for card: CardInstance in PuzzleRun.row_of(screen.run, ids):
		screen.run.place(card, screen.run.row.size())
	screen._refresh()
	await _frames(2)
	screen._on_checkout_pressed()
	var waited: int = 0
	while screen.puzzle_flow.last_verdict < 0 and waited < 3000:
		await get_tree().process_frame
		waited += 1


func _puzzle_screen(puzzle_id: StringName = PUZZLE) -> ShiftScreen:
	PuzzlePlay.request(puzzle_id)
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.changes_scene = false
	await _frames(4)
	return screen


func _title() -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(4)
	return title


func _save_profile(runs: int, solved: Array[StringName]) -> void:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = runs
	profile.solved_puzzles = solved
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()


## Waits (up to 600 frames) for `meter`'s drawn level to ease to `level`.
func _eased(meter: QuotaMeter, level: float) -> void:
	for frame: int in 600:
		if is_equal_approx(meter._shown, level):
			return
		await get_tree().process_frame


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _event_log() -> EventLogService:
	return get_tree().root.get_node("EventLog")
