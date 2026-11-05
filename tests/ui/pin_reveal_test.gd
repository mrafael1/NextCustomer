extends GdUnitTestSuite
## The badge pins' unlock cards (PinUnlockNews, PinUnlockCard, PinReveal; the achievement unlock
## mock-up's look A and reveal R3, 2026-11-05): the news of a run's unlocks (the profile's count,
## the next milestone), the queue (the cards wait for the receipt, then come one at a time, each
## CARD_MS, GAP_MS apart, the newest on top of the stack, the pager turning it), the spotlight's
## geometry (the shade over the whole 1280x720 window, the card centred in it, the stack, its pager
## and next milestone inside it, right of the receipt), a click or a key showing every card at
## once, reduced motion, the glint on the settled top pin, the results screen showing them after
## its receipt (Return to menu first showing them, then leaving), a run ended through the real
## checkout showing its unlock, and the stack beside the real wide receipt. The reveal's
## clock is a test clock, so nothing waits on real time; the real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The receipt's rect for the stand-alone reveal: the mock-up's 476 px receipt, centred.
const RECEIPT_RECT := Rect2(402, 64, 476, 592)
const THREE: Array[StringName] = [&"recycle", &"repack", &"double_checkout"]
## When the receipt finished printing, on the test clock.
const PRINTED_MS := 1000

var _now: int = 0
var _printing: bool = false
var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_now = 0
	_printing = false
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## One pin: the profile owns 6 of 8 with it (5 from the start), and the next locked milestone is
## named. Three: 6, 7 then 8 of 8, in catalogue order, and no next milestone.
func test_the_news_counts_the_pins_and_names_the_next_milestone() -> void:
	var one: PinUnlockNews = _news([&"recycle"])
	assert_int(one.cards.size()).is_equal(1)
	assert_str(one.cards[0].pin.id).is_equal("recycle")
	assert_int(one.cards[0].owned).is_equal(6)
	assert_int(one.cards[0].total).is_equal(8)
	assert_str(one.cards[0].milestone()).is_equal("Finish a run")
	assert_str(one.next_text).is_equal("Next: Repack · Win a run")
	var three: PinUnlockNews = _news([&"double_checkout", &"recycle", &"repack"])
	var ids: Array[String] = []
	var owned: Array[int] = []
	for card: PinUnlockNews.Card in three.cards:
		ids.append(String(card.pin.id))
		owned.append(card.owned)
	assert_array(ids).is_equal(["recycle", "repack", "double_checkout"])
	assert_array(owned).is_equal([6, 7, 8])
	assert_str(three.next_text).is_empty()
	assert_bool(_news([]).is_empty()).is_true()


## The card shows its pin: the header, the name, the rule, the milestone and the count.
func test_the_card_shows_its_pin() -> void:
	var card: PinUnlockCard = auto_free(PinUnlockCard.new())
	card.show_unlock(_news([&"recycle"]).cards[0])
	var pin: PinDefinition = load("res://data/pins/recycle.tres")
	assert_array(Array(card.texts())).is_equal(
		["NEW BADGE PIN", "RECYCLE", pin.rule_text, "Finish a run", "6/8"]
	)
	assert_str(card.face().letters()).is_equal(pin.face_text)
	assert_vector(card.size).is_equal(PinUnlockCard.CARD_SIZE)


## The queue: nothing while the receipt prints; then each card GAP_MS after the last, one at a
## time, the shade under the one coming; landed cards stack with the newest on top; once all have
## landed the pager reads "3 / 3" and turning brings the first to the top.
func test_the_cards_wait_for_the_receipt_then_come_one_at_a_time() -> void:
	var reveal: PinReveal = _reveal(_news(THREE))
	var cards: Array[PinUnlockCard] = reveal.cards()
	_at(PRINTED_MS - 1, reveal)
	assert_array(_visible(cards)).is_equal([false, false, false])
	assert_float(reveal.shade_alpha()).is_equal(0.0)
	assert_int(reveal.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_printing = false
	_at(PRINTED_MS, reveal)
	var start: int = PRINTED_MS + PinReveal.GAP_MS
	var step: int = PinReveal.CARD_MS + PinReveal.GAP_MS
	_at(start - 1, reveal)
	assert_array(_visible(cards)).is_equal([false, false, false])
	for index: int in range(3):
		_at(start + index * step + 100, reveal)
		assert_bool(reveal.top_card() == cards[index]).is_true()
		assert_bool(cards[index].is_back()).is_true()
		assert_float(reveal.shade_alpha()).is_greater(0.0)
		assert_int(reveal.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
		assert_bool(reveal.is_revealing()).is_true()
		var expected: Array = [index >= 0, index >= 1, index >= 2]
		assert_array(_visible(cards)).is_equal(expected)
		# Landed, before the next one starts: in the stack's top place.
		_at(start + index * step + PinReveal.CARD_MS, reveal)
		assert_vector(cards[index].position).is_equal(reveal.slot_rect().position)
		assert_float(reveal.shade_alpha()).is_equal(0.0)
	assert_bool(reveal.is_revealing()).is_false()
	assert_bool(reveal.top_card() == cards[2]).is_true()
	assert_bool(reveal.pager().visible).is_true()
	assert_str(reveal.pager().text).is_equal("3 / 3")
	assert_int(reveal.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	reveal.turn(1)
	assert_bool(reveal.top_card() == cards[0]).is_true()
	assert_str(reveal.pager().text).is_equal("1 / 3")
	assert_vector(cards[0].position).is_equal(reveal.slot_rect().position)
	reveal.turn(-1)
	assert_str(reveal.pager().text).is_equal("3 / 3")


## Mid-reveal the card stands face up in the window's centre, inside it, its pin and stamp
## landed; the spotlight shade covers the whole window at its darkest.
func test_the_spotlight_centres_the_card_over_a_full_window_shade() -> void:
	var reveal: PinReveal = _reveal(_news([&"recycle"]))
	var start: int = _started(reveal)
	_at(start + 1600, reveal)
	var card: PinUnlockCard = reveal.cards()[0]
	var rect: Rect2 = Rect2(card.position, card.size * card.scale)
	assert_bool(card.is_back()).is_false()
	assert_vector(rect.get_center()).is_equal(SCREEN_RECT.get_center())
	assert_bool(SCREEN_RECT.encloses(rect)).is_true()
	assert_vector(reveal.get_rect().position).is_equal(SCREEN_RECT.position)
	assert_vector(reveal.get_rect().size).is_equal(SCREEN_RECT.size)
	assert_float(reveal.shade_alpha()).is_equal_approx(PinReveal.SHADE_ALPHA, 0.001)
	assert_bool(card.face().visible).is_true()
	assert_vector(card.face().scale).is_equal(Vector2.ONE)
	assert_bool(card.stamp().visible).is_true()
	assert_vector(card.stamp().scale).is_equal(Vector2.ONE)
	var stamp: Rect2 = Rect2(card.stamp().position, card.stamp().size)
	assert_bool(Rect2(Vector2.ZERO, card.size).encloses(stamp)).is_true()
	var face: Rect2 = Rect2(card.face().position, card.face().size)
	assert_bool(stamp.intersects(face)).is_false()


## Settled, the stack stands right of the receipt, inside the window by its gutter, the older
## cards peeking above the top one, the pager and the next milestone under it, nothing
## overlapping.
func test_the_settled_stack_fits_right_of_the_receipt() -> void:
	var news: PinUnlockNews = _news([&"recycle", &"repack"])
	var reveal: PinReveal = _reveal(news)
	_at(_started(reveal) + 60000, reveal)
	var slot: Rect2 = reveal.slot_rect()
	var inner: Rect2 = SCREEN_RECT.grow(-PinReveal.EDGE)
	assert_bool(inner.encloses(slot)).is_true()
	assert_float(slot.position.x).is_greater_equal(RECEIPT_RECT.end.x)
	var older: PinUnlockCard = reveal.cards()[0]
	assert_bool(older.visible).is_true()
	assert_float(older.position.y).is_equal(slot.position.y - PinReveal.PEEK_PX)
	assert_bool(inner.encloses(Rect2(older.position, older.size))).is_true()
	var pager: Rect2 = reveal.pager().get_rect()
	var next: Rect2 = reveal.next_line().get_rect()
	assert_str(reveal.next_line().text).is_equal(
		"Next: Double checkout · Score 100€ in one checkout"
	)
	for rect: Rect2 in [pager, next]:
		assert_bool(SCREEN_RECT.encloses(rect)).is_true()
		assert_bool(rect.intersects(slot)).is_false()
	assert_bool(pager.intersects(next)).is_false()


## A click on the shade, or Space, shows every card at once in its place: no shade, no card
## coming, each face up with its stamp landed.
func test_a_click_or_a_key_shows_every_card_at_once() -> void:
	for use_key: bool in [false, true]:
		var reveal: PinReveal = _reveal(_news(THREE))
		_at(_started(reveal) + 500, reveal)
		assert_bool(reveal.is_revealing()).is_true()
		if use_key:
			var key: InputEventKey = InputEventKey.new()
			key.keycode = KEY_SPACE
			key.pressed = true
			reveal._input(key)
		else:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			reveal._gui_input(click)
		assert_bool(reveal.is_revealing()).is_false()
		assert_float(reveal.shade_alpha()).is_equal(0.0)
		assert_bool(reveal.top_card() == reveal.cards()[2]).is_true()
		for card: PinUnlockCard in reveal.cards():
			assert_bool(card.is_back()).is_false()
			assert_vector(card.scale).is_equal(Vector2.ONE)
			assert_vector(card.stamp().scale).is_equal(Vector2.ONE)
		assert_str(reveal.pager().text).is_equal("3 / 3")


## Under reduced motion each card appears in its place GAP_MS after the last, with no shade, and
## the shade never takes a click.
func test_reduced_motion_lays_each_card_in_place() -> void:
	var reveal: PinReveal = _reveal(_news(THREE), true)
	var start: int = _started(reveal)
	for index: int in range(3):
		_at(start + index * PinReveal.GAP_MS, reveal)
		var card: PinUnlockCard = reveal.cards()[index]
		assert_bool(card.visible).is_true()
		assert_vector(card.position).is_equal(reveal.slot_rect().position)
		assert_bool(card.is_back()).is_false()
		assert_float(reveal.shade_alpha()).is_equal(0.0)
		assert_int(reveal.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(reveal.is_revealing()).is_false()


## On the real results screen: the cards stand in front of the receipt (over the whole window)
## and wait for its print; once it has printed they come; a first Return to menu shows them all
## and stays, a second one leaves.
func test_the_results_show_the_cards_after_the_receipt() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.changes_scene = false
	await get_tree().process_frame
	await get_tree().process_frame
	var run: RunState = screen.run
	var record: ShiftRecord = ShiftRecord.new(1, 34, 20)
	record.passed = false
	run.history.assign([record])
	run.phase = RunState.Phase.LOST
	var results: ResultsPanel = screen._results
	results.pin_news = _news([&"recycle"])
	results.show_results(run, ScoreResult.new(), -1)
	assert_object(results.pin_news).is_null()
	var reveal: PinReveal = results.pin_reveal()
	assert_object(reveal.get_parent()).is_same(screen)
	assert_int(reveal.get_index()).is_equal(results.get_index() + 1)
	assert_bool(reveal.visible).is_true()
	assert_bool(results.is_printing()).is_true()
	assert_bool(reveal.cards()[0].visible).is_false()
	results.skip_printing()
	await get_tree().process_frame
	assert_bool(reveal.is_revealing()).is_true()
	var asked: Array[bool] = []
	results.menu_requested.connect(func() -> void: asked.append(true))
	results.menu_button().disabled = false
	results.menu_button().pressed.emit()
	assert_bool(reveal.is_revealing()).is_false()
	assert_bool(reveal.cards()[0].visible).is_true()
	assert_array(asked).is_empty()
	assert_bool(SCREEN_RECT.encloses(reveal.slot_rect())).is_true()
	assert_float(reveal.slot_rect().position.x).is_greater_equal(results.get_rect().end.x)
	results.menu_button().pressed.emit()
	assert_array(asked).is_equal([true])


## Even pressed before the receipt has printed (Return to menu arms mid-print), the first press
## shows the cards; without cards it leaves at once, as before.
func test_return_to_menu_mid_print_still_shows_the_cards() -> void:
	var screen: ShiftScreen = await _results_screen()
	var results: ResultsPanel = screen._results
	var asked: Array[bool] = []
	results.menu_requested.connect(func() -> void: asked.append(true))
	results.pin_news = _news([&"recycle"])
	results.show_results(_lost_run(screen), ScoreResult.new(), -1)
	assert_bool(results.is_printing()).is_true()
	results.menu_button().disabled = false
	results.menu_button().pressed.emit()
	assert_bool(results.is_printing()).is_false()
	assert_array(asked).is_empty()
	assert_bool(results.pin_reveal().cards()[0].visible).is_true()
	results.show_results(_lost_run(screen), ScoreResult.new(), -1)
	assert_bool(results.pin_reveal().cards().is_empty()).is_true()
	results.menu_button().disabled = false
	results.menu_button().pressed.emit()
	assert_array(asked).is_equal([true])


## A run ended through the real checkout on a fresh profile: Recycle unlocks (Finish a run), the
## profile owns it, and the results show its one card, 6/8, once the receipt has printed.
func test_a_run_ended_through_the_checkout_shows_its_unlock() -> void:
	var screen: ShiftScreen = await _results_screen()
	screen.profile = ProfileState.new()
	Rush.no_write_ups(screen)  # The empty row misses: the run is lost at once.
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.LOST)
	var results: ResultsPanel = screen._results
	assert_bool(results.visible).is_true()
	assert_bool(screen.profile.unlocked_pins.has(&"recycle")).is_true()
	var reveal: PinReveal = results.pin_reveal()
	assert_int(reveal.cards().size()).is_equal(1)
	assert_array(Array(reveal.cards()[0].texts())).contains(["RECYCLE", "6/8"])
	results.skip_printing()
	results.menu_button().disabled = false
	results.menu_button().pressed.emit()
	assert_bool(reveal.is_revealing()).is_false()
	assert_bool(reveal.cards()[0].visible).is_true()


## Beside the real wide receipt (a won 16-shift run in week columns), the settled stack of three
## stands right of it, inside the window less its gutter: the cards, their peeks, the pager and
## the next line.
func test_the_stack_fits_beside_the_wide_receipt() -> void:
	var screen: ShiftScreen = await _results_screen()
	var run: RunState = screen.run
	var history: Array[ShiftRecord] = []
	for shift: int in range(1, run.shift_count() + 1):
		var record: ShiftRecord = ShiftRecord.new(shift, 923, 1234)
		record.passed = true
		history.append(record)
	run.history = history
	run.shift_index = run.shift_count() - 1
	run.phase = RunState.Phase.WON
	var results: ResultsPanel = screen._results
	results.pin_news = _news([&"recycle", &"repack"])
	results.show_results(run, ScoreResult.new(), -1)
	results.skip_printing()
	await get_tree().process_frame
	await get_tree().process_frame
	var reveal: PinReveal = results.pin_reveal()
	reveal.finish()
	assert_int(results.week_columns().size()).is_equal(2)
	var inner: Rect2 = SCREEN_RECT.grow(-PinReveal.EDGE)
	var slot: Rect2 = reveal.slot_rect()
	assert_float(slot.position.x).is_greater_equal(results.get_rect().end.x)
	var rects: Array[Rect2] = [slot, reveal.pager().get_rect(), reveal.next_line().get_rect()]
	for card: PinUnlockCard in reveal.cards():
		assert_bool(card.visible).is_true()
		rects.append(Rect2(card.position, card.size))
	for rect: Rect2 in rects:
		assert_bool(inner.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.position.x).is_greater_equal(results.get_rect().end.x)


## Settled, a glint crosses the top card's pin for GLINT_MS every GLINT_EVERY_MS, never the
## older card's; under reduced motion there is none.
func test_the_settled_top_pin_glints_every_few_seconds() -> void:
	for reduced: bool in [false, true]:
		var reveal: PinReveal = _reveal(_news([&"recycle", &"repack"]), reduced)
		var start: int = _started(reveal)
		var settled: int = start + 2 * (PinReveal.CARD_MS + PinReveal.GAP_MS)
		_at(settled, reveal)
		assert_bool(reveal.is_revealing()).is_false()
		var settled_at: int = reveal._settled_ms
		var top: PinUnlockCard = reveal.top_card()
		var under: PinUnlockCard = reveal.cards()[0]
		_at(settled_at + roundi(PinReveal.GLINT_MS * 0.5), reveal)
		if reduced:
			assert_float(top.glint_progress()).is_less(0.0)
		else:
			assert_float(top.glint_progress()).is_equal_approx(0.5, 0.001)
		assert_float(under.glint_progress()).is_less(0.0)
		_at(settled_at + PinReveal.GLINT_MS + 10, reveal)
		assert_float(top.glint_progress()).is_less(0.0)
		_at(settled_at + PinReveal.GLINT_EVERY_MS + 10, reveal)
		assert_bool(top.glint_progress() >= 0.0).is_equal(not reduced)


func _results_screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.changes_scene = false
	screen._week.skip()  # The time card stays out of the way.
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


## The screen's run, lost on shift 1.
static func _lost_run(screen: ShiftScreen) -> RunState:
	var run: RunState = screen.run
	var record: ShiftRecord = ShiftRecord.new(1, 34, 20)
	record.passed = false
	run.history.assign([record])
	run.phase = RunState.Phase.LOST
	return run


func _news(ids: Array[StringName]) -> PinUnlockNews:
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_pins.assign(ids)
	return PinUnlockNews.of(ids, profile, load(CATALOGUE) as CatalogueDefinition)


## A stand-alone reveal over a 1280x720 root, beside a receipt at RECEIPT_RECT, on the test clock.
func _reveal(news: PinUnlockNews, reduced_motion: bool = false) -> PinReveal:
	var root: Control = Control.new()
	root.size = SCREEN_RECT.size
	add_child(root)
	auto_free(root)
	var receipt: Control = Control.new()
	receipt.position = RECEIPT_RECT.position
	receipt.size = RECEIPT_RECT.size
	root.add_child(receipt)
	var reveal: PinReveal = PinReveal.new()
	reveal.size = SCREEN_RECT.size
	reveal.clock = func() -> int: return _now
	reveal.setup(receipt, func() -> bool: return _printing)
	root.add_child(reveal)
	_printing = true  # The receipt prints until _started.
	reveal.show_news(news, reduced_motion)
	return reveal


## The receipt has printed at PRINTED_MS: returns when the first card starts.
func _started(reveal: PinReveal) -> int:
	_printing = false
	_at(PRINTED_MS, reveal)
	return PRINTED_MS + PinReveal.GAP_MS


func _at(now_ms: int, reveal: PinReveal) -> void:
	_now = now_ms
	reveal.refresh()


static func _visible(cards: Array[PinUnlockCard]) -> Array:
	var shown: Array = []
	for card: PinUnlockCard in cards:
		shown.append(card.visible)
	return shown


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
