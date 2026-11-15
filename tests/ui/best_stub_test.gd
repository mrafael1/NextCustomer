extends GdUnitTestSuite
## The results' BEST stub (BestStub, direction B of docs/art/mockups/receipt_highlight.html, built
## beside the BEST line on 2026-11-15) on the real shift screen: once the coins have printed, the
## BEST line's moment shows on a gold stub left of the receipt, below the CLOSED sign, inside the
## window at 1280x720 and 1920x1080, clear of the pins' unlock cards, its value in big digits. It
## waits for the shutter, slides in after the coins (the pins' cards wait for it), and a tap,
## Return to menu or reduced motion shows it in place at once. Its words are RunHighlight's for
## every kind. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const HIGHLIGHT := "res://data/balance/highlight.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const PINS: Array[StringName] = [&"recycle", &"repack"]
## The value's digits are at least this tall (a 4 px chunky cell), in canvas px.
const MIN_DIGITS := 32.0

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_best_stub_%d" % Time.get_ticks_usec()
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


## A won 16-shift run (the widest receipt): Biggest payout's stub, Golden milk at full size, its
## 1800€, shift 14 of week 4, at its full size left of the receipt at both window sizes.
func test_the_won_stub_shows_the_biggest_payout_left_of_the_receipt() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		_won_run(screen)
		var results: ResultsPanel = await _settled(screen)
		var stub: BestStub = results.best_stub()
		assert_bool(stub.is_showing()).override_failure_message(str(window)).is_true()
		assert_array(Array(stub.texts())).is_equal(
			["BEST MOMENT", "BIGGEST PAYOUT", "Golden milk", "1800€", "shift 14 · week 4"]
		)
		var golden: CardDefinition = load(MILK_GOLDEN)
		assert_object(stub.art_texture()).is_same(ArtStyle.item_sprite(golden))
		assert_bool(stub.has_tag()).is_false()
		assert_float(stub.fit_scale()).is_equal(1.0)
		_assert_placed(results, window)


## A run lost in week 1 (one column, a narrow receipt): Closest call's stub, the quota target drawn
## big, the shift's total and quota as its name and the margin as its value.
func test_a_lost_stub_shows_the_closest_call() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		_lost_run(screen)
		var results: ResultsPanel = await _settled(screen)
		var stub: BestStub = results.best_stub()
		assert_bool(stub.is_showing()).is_true()
		assert_array(Array(stub.texts())).is_equal(
			["BEST MOMENT", "CLOSEST CALL", "31€ / 30€", "+1€", "shift 1 · week 1"]
		)
		assert_object(stub.art_texture()).is_same(ReceiptHighlight.QUOTA_ICON)
		assert_float(stub.art_rect().size.y).is_greater_equal(
			ReceiptHighlight.QUOTA_ICON.get_height() * BestStub.TARGET_SCALE - 1.0
		)
		_assert_placed(results, window)


## A won run that unlocked two pins: the receipt leaves the cards' room on the right; the stub on
## the left stays clear of every card, the stack's slot, its pager and its next line.
func test_the_stub_keeps_clear_of_the_pin_cards() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		_won_run(screen)
		var results: ResultsPanel = await _settled(screen, PINS)
		var reveal: PinReveal = results.pin_reveal()
		reveal.finish()
		await _frames(2)
		var stub: BestStub = results.best_stub()
		assert_bool(stub.is_showing()).is_true()
		_assert_placed(results, window)
		var rects: Array[Rect2] = [reveal.slot_rect()]
		for card: PinUnlockCard in reveal.cards():
			rects.append(card.get_global_rect())
		rects.append(reveal.pager().get_global_rect())
		rects.append(reveal.next_line().get_global_rect())
		for rect: Rect2 in rects:
			(
				assert_bool(stub.stub_rect().intersects(rect))
				. override_failure_message("%s %s" % [window, rect])
				. is_false()
			)


## Its words for the kinds the runs above don't show: Over quota (total and quota, the ratio), a
## combo (the combo diamond with its "×N" tag, the combo's euros) and First GOLDEN (GOLD!).
func test_every_kind_has_its_words() -> void:
	var definition: HighlightDefinition = load(HIGHLIGHT)
	var stub: BestStub = BestStub.new()
	add_child(stub)
	auto_free(stub)
	var over: RunHighlight.Moment = _moment(RunHighlight.Kind.OVER_QUOTA, 5, 160, 70)
	stub.set_moment(over, definition, 2)
	assert_array(Array(stub.texts())).is_equal(
		["BEST MOMENT", "OVER QUOTA", "160€ / 70€", "×2.3", "shift 5 · week 2"]
	)
	assert_object(stub.art_texture()).is_same(ReceiptHighlight.QUOTA_ICON)
	var combo: RunHighlight.Moment = _moment(RunHighlight.Kind.LONGEST_COMBO, 7, 90, 80)
	combo.keyword = CardText.CHAIN_WORD
	combo.length = 5
	combo.amount = 118
	stub.set_moment(combo, definition, 2)
	assert_array(Array(stub.texts())).is_equal(
		["BEST MOMENT", "LONGEST CHAIN", "5 items", "118€", "shift 7 · week 2"]
	)
	assert_object(stub.art_texture()).is_same(ReceiptHighlight.COMBO_ICON)
	assert_bool(stub.has_tag()).is_true()
	assert_float(stub.value_cell()).is_equal(BestStub.VALUE_CELLS[0])
	var golden: RunHighlight.Moment = _moment(RunHighlight.Kind.FIRST_GOLDEN, 9, 120, 100)
	golden.card = load(MILK_GOLDEN)
	stub.set_moment(golden, definition, 3)
	assert_array(Array(stub.texts())).is_equal(
		["BEST MOMENT", "FIRST GOLDEN", "Golden milk", "GOLD!", "shift 9 · week 3"]
	)
	assert_bool(stub.has_tag()).is_false()


## The natural print: the stub waits for the coins, then slides in from under the receipt while
## the pins' first card waits; once landed, the cards come.
func test_it_slides_in_after_the_coins_and_the_cards_wait() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	_lost_run(screen)
	var results: ResultsPanel = screen._results
	results.pin_news = _news(PINS)
	screen._show_results(_last_result(screen))
	results.store_closed().close_store(true)
	var stub: BestStub = results.best_stub()
	assert_bool(stub.is_playing()).is_false()
	var start: int = Time.get_ticks_msec()
	while results.is_printing() and Time.get_ticks_msec() - start < 10000:
		await get_tree().process_frame
	assert_bool(results.is_printing()).is_false()
	assert_bool(stub.is_playing()).is_true()
	var reveal: PinReveal = results.pin_reveal()
	while stub.is_playing() and Time.get_ticks_msec() - start < 12000:
		assert_bool(reveal.cards()[0].visible).is_false()
		await get_tree().process_frame
	assert_bool(stub.is_playing()).is_false()
	assert_bool(stub.is_showing()).is_true()
	_assert_placed(results, SIZES[0])
	while not reveal.cards()[0].visible and Time.get_ticks_msec() - start < 14000:
		await get_tree().process_frame
	assert_bool(reveal.cards()[0].visible).is_true()


## A tap while it slides (skip_printing once printed) or Return to menu shows it in place at once.
func test_a_tap_or_the_menu_shows_it_in_place() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	_lost_run(screen)
	var results: ResultsPanel = await _settled(screen)
	var stub: BestStub = results.best_stub()
	var landed: Rect2 = stub.stub_rect()
	stub.play(false)
	assert_bool(stub.is_playing()).is_true()
	await _frames(2)
	results.skip_printing()
	assert_bool(stub.is_playing()).is_false()
	assert_bool(stub.stub_rect().is_equal_approx(landed)).is_true()
	stub.play(false)
	results.menu_button().disabled = false
	results.menu_button().pressed.emit()
	assert_bool(stub.is_playing()).is_false()
	assert_bool(stub.stub_rect().is_equal_approx(landed)).is_true()


## Reduced motion: once the coins have printed it shows in place at once.
func test_reduced_motion_shows_it_at_once() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	_lost_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	var start: int = Time.get_ticks_msec()
	while results.is_printing() and Time.get_ticks_msec() - start < 10000:
		await get_tree().process_frame
	await _frames(2)
	assert_bool(results.best_stub().is_playing()).is_false()
	assert_bool(results.best_stub().is_showing()).is_true()


## Printed at once by a tap before the shutter is down: it waits for the shutter, then shows.
func test_it_waits_for_the_shutter() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	_lost_run(screen)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	results.skip_printing()
	await _frames(2)
	assert_float(results.store_closed().shutter()).is_less(1.0)
	assert_bool(results.best_stub().is_showing()).is_false()
	results.store_closed().close_store(true)
	await _frames(2)
	assert_bool(results.best_stub().is_showing()).is_true()


## A run with no BEST line (nothing recorded) shows no stub.
func test_a_run_without_a_moment_shows_no_stub() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = [ShiftRecord.new(1, 30, 40), ShiftRecord.new(2, 35, 10)]
	run.history = history
	run.shift_index = 1
	run.limits.quota = 35
	run.phase = RunState.Phase.LOST
	var results: ResultsPanel = await _settled(screen)
	assert_object(results.highlight()).is_null()
	assert_bool(results.best_stub().is_showing()).is_false()


## The stub inside the window less its edge, left of the receipt and clear of its text, below the
## CLOSED sign, behind the receipt in the draw order; its value's digits big.
func _assert_placed(results: ResultsPanel, window: Vector2i) -> void:
	var stub: BestStub = results.best_stub()
	var rect: Rect2 = stub.stub_rect()
	var screen_rect: Rect2 = results.store_closed().get_global_rect()
	var paper: Rect2 = results.get_global_rect()
	var sign_rect: Rect2 = results.store_closed().sign_rect()
	prints("BEST stub:", window, rect, "receipt", paper, "sign", sign_rect, stub.fit_scale())
	var message: String = "%s %s" % [window, rect]
	assert_bool(screen_rect.grow(-4.0).encloses(rect)).override_failure_message(message).is_true()
	assert_float(rect.end.x).override_failure_message(message).is_less_equal(paper.position.x)
	assert_bool(rect.intersects(sign_rect)).override_failure_message(message).is_false()
	assert_float(rect.position.y).is_greater_equal(sign_rect.end.y)
	for line: Label in results._lines:
		assert_bool(rect.intersects(line.get_global_rect())).is_false()
	assert_int(stub.get_index()).is_less(results.get_index())
	assert_int(stub.get_index()).is_greater(results.store_closed().get_index())
	assert_float(stub.value_rect().size.y).is_greater_equal(MIN_DIGITS)
	assert_float(stub.fit_scale()).is_greater_equal(BestStub.MIN_SCALE)


## Shows the run's results, printed at once with the shutter down (`pins` unlocked), popped in.
func _settled(screen: ShiftScreen, pins: Array[StringName] = []) -> ResultsPanel:
	var results: ResultsPanel = screen._results
	if not pins.is_empty():
		results.pin_news = _news(pins)
	screen._show_results(_last_result(screen))
	results.skip_printing()
	results.store_closed().close_store(true)
	# The receipt pops in (UiKit.pop_in): its rect, and the stub beside it, settle after.
	await get_tree().create_timer(UiKit.POP_IN_SECONDS + 0.1).timeout
	await _frames(2)
	return results


## receipt_highlight_ui_test's won 16-shift run: Golden milk pays 1800€ on shift 14.
func _won_run(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = []
	for shift: int in range(1, run.shift_count() + 1):
		var record: ShiftRecord = _record(shift, 923, 1234, "milk", 184)
		if shift == 14:
			record.best_card = load(MILK_GOLDEN)
			record.best_payout = 1800
		history.append(record)
	run.history = history
	run.shift_index = run.shift_count() - 1
	run.phase = RunState.Phase.WON


## Lost on shift 3, shift 1 passed by 1€ (Closest call).
func _lost_run(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = [
		_record(1, 30, 31, "milk", 6), _record(2, 35, 40, "eggs", 8), _record(3, 36, 20, "", 0)
	]
	run.history = history
	run.shift_index = 2
	run.limits.quota = 36
	run.phase = RunState.Phase.LOST


static func _record(
	shift: int, quota: int, total: int, card_id: String, payout: int
) -> ShiftRecord:
	var record: ShiftRecord = ShiftRecord.new(shift, quota, total)
	if not card_id.is_empty():
		record.best_card = load("res://data/cards/%s.tres" % card_id)
		record.best_payout = payout
		record.played.assign([record.best_card])
	return record


static func _moment(
	kind: RunHighlight.Kind, shift: int, total: int, quota: int
) -> RunHighlight.Moment:
	var moment: RunHighlight.Moment = RunHighlight.Moment.new()
	moment.kind = kind
	moment.shift = shift
	moment.total = total
	moment.quota = quota
	return moment


func _news(ids: Array[StringName]) -> PinUnlockNews:
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_pins.assign(ids)
	return PinUnlockNews.of(ids, profile, load(CATALOGUE) as CatalogueDefinition)


func _last_result(screen: ShiftScreen) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = screen.run.history[-1].total
	return result


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.changes_scene = false
	screen._week.skip()
	await _frames(2)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
