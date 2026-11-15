extends GdUnitTestSuite
## Polish audit batch 2, the keep and results group (2026-11-14), at 1280x720 and 1920x1080: the
## Golden basket's keep screen (its title and hint on the teal sign plate, the KEPT counter at the
## pin's keep count, the steel tray's mini cards with name and price, DONE full size centred under
## the tray, the pop-in; Enter or Space press DONE, Esc only when it loses no choice, else the pause
## opens as before); the results' dim lines (DETAIL_ALPHA ink, at least DETAIL_MIN_SIZE px, the day
## events as chips on their shift lines) for a won and a lost run, the receipt clear of the unlock
## cards; the unlock card (no 7 px foot words, the count centred, the hang slot clear of the stamp)
## and its next milestone on a paper strip; Enter on the results. The real saves and logs are never
## touched.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const GOLDEN := "res://data/pins/golden_basket.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
## The longest names of each kind, for the widest lines (as results_panel_test's).
const LONG_CARD := "res://data/cards/breakfast_sticker.tres"
const LONG_UPGRADE := "res://data/upgrades/category_engine.tres"
const LONG_INSPECTION := "res://data/inspections/short_belt.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const BOON := "res://data/inspections/quiet_morning.tres"

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


## The keep screen pops in, then lays out top to bottom inside the window: the sign plate holding
## the title and the hint (which says cards and ends with a full stop), the basket under it, the
## tray's header row (LAST CHECKOUT, the counter at 0 of the pin's keep count), the steel tray
## holding one mini card per item (its art, name and price or COUPON inside it) and DONE, full
## size, centred under the tray. A kept card moves the counter on, and it turns green once full.
func test_the_keep_screen_lays_out_its_sign_counter_tray_and_done() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		var placed: Array[CardInstance] = _place(screen, 3)
		var keep: KeepScreen = await _open_keep(screen)
		# The pop-in (UiKit.pop_in) is under way when the screen appears.
		assert_float(keep.content().scale.x).is_less(1.0)
		await get_tree().create_timer(UiKit.POP_IN_SECONDS + 0.1).timeout
		await _frames(2)
		assert_float(keep.content().scale.x).is_equal_approx(1.0, 0.001)
		var where: String = "at %s" % window
		var view: Rect2 = screen.get_viewport_rect()
		var plate: Rect2 = keep.sign_plate().get_global_rect()
		assert_bool(view.encloses(plate)).override_failure_message(where).is_true()
		assert_float(plate.get_center().x).is_equal_approx(view.get_center().x, 1.0)
		for part: String in ["Title", "HintHolder"]:
			var label: Control = keep.sign_plate().find_child(part, true, false) as Control
			(
				assert_bool(plate.encloses(label.get_global_rect()))
				. override_failure_message(part)
				. is_true()
			)
		assert_str(KeepScreen.HINT).contains("cards").ends_with(".")
		var basket: Rect2 = keep.basket().get_global_rect()
		assert_float(basket.position.y).is_greater_equal(plate.end.y - 0.5)
		var room: int = PinPlay.keep_count(screen.run)
		assert_int(room).is_greater(0)
		assert_str(keep.counter_text()).is_equal("0/%d" % room)
		var counter: Rect2 = keep.counter().get_global_rect()
		var tray: Rect2 = keep.tray().get_global_rect()
		assert_float(counter.position.y).is_greater_equal(basket.end.y - 0.5)
		assert_float(counter.end.y).is_less_equal(tray.position.y + 0.5)
		assert_float(counter.end.x).is_less_equal(tray.end.x + 0.5)
		assert_bool(view.encloses(tray)).override_failure_message(where).is_true()
		var cells: Array[Control] = keep.list_cells()
		assert_int(cells.size()).is_equal(placed.size())
		for index: int in cells.size():
			var cell: Control = cells[index]
			var rect: Rect2 = cell.get_global_rect()
			assert_bool(tray.encloses(rect)).override_failure_message(where).is_true()
			var face: Control = cell.get_node("Card") as Control
			assert_bool(rect.grow(0.5).encloses(face.get_global_rect())).is_true()
			var name_label: Label = face.get_node("Name") as Label
			var price: Label = face.get_node("Price") as Label
			var definition: CardDefinition = _card_of(cell, placed).definition
			assert_str(name_label.text).is_equal(definition.display_name)
			var priced: String = (
				KeepScreen.COUPON_TEXT
				if definition.is_coupon()
				else PriceSticker.price_text(definition.base)
			)
			assert_str(price.text).is_equal(priced)
			for label: Label in [name_label, price]:
				var inside: String = (
					"%s %s in %s" % [label.text, label.get_global_rect(), face.get_global_rect()]
				)
				(
					assert_bool(face.get_global_rect().encloses(label.get_global_rect()))
					. override_failure_message(inside)
					. is_true()
				)
		var done: Rect2 = keep.done_button().get_global_rect()
		assert_bool(view.encloses(done)).override_failure_message(where).is_true()
		assert_float(done.position.y).is_greater_equal(tray.end.y)
		assert_float(done.get_center().x).is_equal_approx(tray.get_center().x, 1.0)
		assert_float(done.size.x).is_greater_equal(KeepScreen.DONE_WIDTH)
		# Keeping fills the counter; full, it turns green.
		assert_bool(keep.keep(placed[0])).is_true()
		assert_str(keep.counter_text()).is_equal("1/%d" % room)
		for card: CardInstance in placed.slice(1, room):
			keep.keep(card)
		var box: StyleBoxFlat = keep.counter().get_theme_stylebox("panel") as StyleBoxFlat
		assert_object(box.bg_color).is_equal(Palette.GREEN_LIGHT)
		keep.done_button().pressed.emit()
		await _frames(2)


## Esc on the keep screen: while a card could still be kept it passes on (the pause opens over it,
## as before) and closes nothing; with the basket full it presses DONE, before the pause sees it.
func test_esc_on_the_keep_screen_never_loses_a_choice() -> void:
	var screen: ShiftScreen = await _screen()
	var placed: Array[CardInstance] = _place(screen, 3)
	var keep: KeepScreen = await _open_keep(screen)
	await _frames(2)
	keep._armed_ms = 0
	assert_bool(keep.choice_left()).is_true()
	get_tree().root.push_input(_key(KEY_ESCAPE))
	await _frames(2)
	assert_object(screen._pins.keep_panel()).is_same(keep)
	assert_bool(screen._pause.is_open()).is_true()
	screen._pause.close()
	await _frames(2)
	assert_bool(screen._pause.is_open()).is_false()
	for card: CardInstance in placed.slice(0, PinPlay.keep_count(screen.run)):
		keep.keep(card)
	assert_bool(keep.choice_left()).is_false()
	get_tree().root.push_input(_key(KEY_ESCAPE))
	await _frames(2)
	assert_object(screen._pins.keep_panel()).is_null()
	assert_bool(screen._pause.is_open()).is_false()
	var kept: Array = _last_event("golden_basket")["kept"]
	assert_int(kept.size()).is_equal(PinPlay.keep_count(screen.run))


## Enter presses DONE, even with the basket empty, before the pause sees it; but not in the screen's
## first ARM_MS (a Space or Enter tap left over from skipping the count-up never skips the choice).
func test_enter_on_the_keep_screen_presses_done() -> void:
	var next: ShiftScreen = await _screen()
	_place(next, 3)
	var again: KeepScreen = await _open_keep(next)
	await _frames(2)
	assert_bool(again.choice_left()).is_true()
	for early: Key in [KEY_SPACE, KEY_ENTER]:
		get_tree().root.push_input(_key(early))
		await _frames(2)
	assert_object(next._pins.keep_panel()).is_same(again)
	again._armed_ms = 0
	get_tree().root.push_input(_key(KEY_ENTER))
	await _frames(2)
	assert_object(next._pins.keep_panel()).is_null()
	assert_bool(next._pause.is_open()).is_false()
	assert_array(_last_event("golden_basket")["kept"]).is_empty()


## The results' dim lines, for a won 16-shift run and one lost in week 3, at both sizes: their ink
## is DETAIL_ALPHA, their size at least DETAIL_MIN_SIZE; no dim line names a day event (each is a
## chip on its shift line instead, right of the line's text, inside its column and the paper);
## the BEST line, the coins and the buttons fit the paper, inside the window.
func test_the_results_detail_lines_stay_readable() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		for won: bool in [true, false]:
			var where: String = "%s %s" % ["won" if won else "lost", window]
			var screen: ShiftScreen = await _screen()
			_full_run(screen, won)
			var results: ResultsPanel = screen._results
			screen._show_results(_last_result(screen))
			results.skip_printing()
			await get_tree().create_timer(UiKit.POP_IN_SECONDS + 0.1).timeout  # The pop-in's scale.
			await _frames(2)
			var view: Rect2 = screen.get_viewport_rect()
			var paper: Rect2 = results.get_global_rect()
			assert_bool(view.encloses(paper)).override_failure_message(where).is_true()
			var details: int = 0
			var chips: int = 0
			for line: Label in results._lines:
				var text: String = line.text.strip_edges()
				var day_line: bool = text.begins_with("inspection ") or text.begins_with("today ")
				assert_bool(day_line).override_failure_message(where).is_false()
				assert_bool(paper.encloses(line.get_global_rect())).override_failure_message(
					"%s: %s" % [where, text]
				)
				var color: Color = line.get_theme_color("font_color")
				if line.get_theme_font_size("font_size") < results._fit.x:
					details += 1
					assert_int(line.get_theme_font_size("font_size")).is_greater_equal(
						ResultsPanel.DETAIL_MIN_SIZE
					)
					assert_float(color.a).is_equal_approx(ResultsPanel.DETAIL_ALPHA, 0.001)
				var row: Control = line.get_node_or_null("DayChips") as Control
				if row == null:
					continue
				var column: Rect2 = (line.get_parent() as Control).get_global_rect()
				for chip: Control in row.get_children():
					chips += 1
					var rect: Rect2 = chip.get_global_rect()
					# Inside its column's width (it may stand a px over a column's last line).
					assert_float(rect.end.x).is_less_equal(column.end.x + 0.5)
					assert_bool(paper.encloses(rect)).is_true()
					var drawn: float = (
						line
						. get_theme_font("font")
						. get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, results._fit.x)
						. x
					)
					assert_float(rect.position.x).is_greater(line.global_position.x + drawn)
					assert_float(rect.get_center().y).is_equal_approx(
						line.get_global_rect().get_center().y, 2.0
					)
			assert_int(details).is_greater(0)
			assert_int(chips).is_greater(0)
			if results.highlight() != null:
				assert_bool(paper.encloses(results.highlight().get_global_rect())).is_true()
			for button: FramedButton in [results.menu_button(), results.export_button()]:
				if button.visible:
					assert_bool(paper.encloses(button.get_global_rect())).is_true()
			screen._results.visible = false


## A won run with a pin to unlock at 1280x720: the receipt leaves the card stack its room on the
## right; the card has no foot words, its count and unit sit on the foot line, centred, and its
## hang slot stays clear of the UNLOCKED stamp; the next milestone sits on a paper strip in ink.
func test_the_unlock_card_and_its_next_strip() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	_full_run(screen, true)
	var profile: ProfileState = ProfileState.new()
	profile.unlocked_pins.assign([&"recycle"])
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	screen._results.pin_news = PinUnlockNews.of([&"recycle"], profile, catalogue)
	var results: ResultsPanel = screen._results
	screen._show_results(_last_result(screen))
	results.skip_printing()
	await get_tree().create_timer(UiKit.POP_IN_SECONDS + 0.1).timeout
	var reveal: PinReveal = results.pin_reveal()
	reveal.finish()
	await _frames(4)
	var cards: Array[PinUnlockCard] = reveal.cards()
	assert_int(cards.size()).is_equal(1)
	var card: PinUnlockCard = cards[0]
	var card_rect: Rect2 = card.get_global_rect()
	assert_bool(results.get_global_rect().intersects(card_rect)).is_false()
	assert_bool(screen.get_viewport_rect().encloses(card_rect)).is_true()
	for child: Node in card.get_children():
		if child is Label:
			assert_str((child as Label).text).not_contains("WEAR IT")
	var foot: Rect2 = PinUnlockCard.COUNT_RECT.merge(PinUnlockCard.UNIT_RECT)
	assert_float(foot.get_center().x).is_equal_approx(PinUnlockCard.CARD_SIZE.x / 2.0, 6.0)
	var widest: int = PinUnlockCard.SLOT_ROWS.max()
	var slot: Rect2 = Rect2(
		PinUnlockCard.SLOT_CENTRE - Vector2(widest + 1, PinUnlockCard.SLOT_ROWS.size()) * 2.0,
		Vector2(widest + 1, PinUnlockCard.SLOT_ROWS.size()) * 4.0
	)
	var stamp: Label = card.stamp()
	assert_bool(slot.intersects(Rect2(stamp.position, stamp.size))).is_false()
	assert_float(slot.end.y).is_less_equal(28.0)  # In the cream top, above the header band.
	var next: Label = reveal.next_line()
	assert_bool(next.visible).is_true()
	var strip: StyleBoxFlat = next.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(strip).is_not_null()
	assert_object(strip.bg_color).is_equal(Palette.PAPER)
	assert_object(next.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_bool(screen.get_viewport_rect().encloses(next.get_global_rect())).is_true()
	assert_bool(next.get_global_rect().intersects(card_rect)).is_false()


## Enter on the results: while printing it prints the rest; once printed and armed it is Return
## to menu.
func test_enter_on_the_results() -> void:
	get_tree().root.size = SIZES[0]
	var screen: ShiftScreen = await _screen()
	_full_run(screen, false)
	var results: ResultsPanel = screen._results
	var asked: Array[bool] = []
	results.menu_requested.connect(func() -> void: asked.append(true))
	screen._show_results(_last_result(screen))
	assert_bool(results.is_printing()).is_true()
	get_tree().root.push_input(_key(KEY_ENTER))
	await _frames(1)
	assert_bool(results.is_printing()).is_false()
	assert_array(asked).is_empty()
	await get_tree().create_timer(ResultsPanel.ARM_MS / 1000.0 + 0.1).timeout
	await _frames(2)
	assert_bool(results.menu_button().disabled).is_false()
	results._unhandled_key_input(_key(KEY_ENTER))
	assert_array(asked).is_equal([true])


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	var worn: Array[PinDefinition] = [load(GOLDEN)]
	RunPins.wear(screen.run, worn)
	screen.run.start_shift()
	screen._week.skip()  # The week's time card would take the first Esc.
	screen._refresh()
	await _frames(2)
	return screen


## Puts `count` hand items on the belt; returns them.
func _place(screen: ShiftScreen, count: int) -> Array[CardInstance]:
	var placed: Array[CardInstance] = []
	for card: CardInstance in screen.run.hand():
		if placed.size() == count:
			break
		if screen.run.place(card, screen.run.row.size()):
			placed.append(card)
	screen._refresh()
	return placed


## Checks the belt out (rushed) and waits for the keep screen.
func _open_keep(screen: ShiftScreen) -> KeepScreen:
	await _frames(2)
	var count_up: CountUp = screen._count_up
	(func() -> void: Rush.rush(count_up)).call_deferred()
	screen._on_checkout_pressed()
	var start: int = Time.get_ticks_msec()
	while screen._pins.keep_panel() == null and Time.get_ticks_msec() - start < Rush.MAX_WAIT_MS:
		await _frames(1)
	var keep: KeepScreen = screen._pins.keep_panel()
	assert_object(keep).is_not_null()
	return keep


static func _card_of(cell: Control, cards: Array[CardInstance]) -> CardInstance:
	for card: CardInstance in cards:
		if cell.name == "Keep%d" % card.instance_id:
			return card
	return null


## A played 16-shift run (won), or one lost on shift 11: a ticket after every shift with the
## longest card name, a payday's PREMIUM perk, an inspection, a review's two and a boon on their
## days by the live schedule (results_panel_test's _full_run).
func _full_run(screen: ShiftScreen, won: bool) -> void:
	var run: RunState = screen.run
	var balance: BalanceDefinition = run.balance
	var history: Array[ShiftRecord] = []
	var last: int = run.shift_count() if won else 11
	for shift: int in range(1, last + 1):
		var record: ShiftRecord = ShiftRecord.new(shift, 923, 1234)
		record.passed = won or shift < last
		if record.passed and shift < run.shift_count():
			var ticket: MachineVisit = MachineVisit.new()
			ticket.chute = RewardMachine.Chute.NEW_ITEMS
			var card: MachinePrize = MachinePrize.new(
				MachinePrize.Kind.PRODUCT, MachinePrize.Rarity.COMMON, load(LONG_CARD)
			)
			var cards: Array[MachinePrize] = [card]
			ticket.set_drawn(cards)
			ticket.picked = 0
			record.visits.append(ticket)
		if balance.machine.is_payday_shift(shift) and record.passed and shift < run.shift_count():
			var bonus: MachineVisit = MachineVisit.new(MachineVisit.Kind.BONUS, "payday")
			bonus.premium = true
			bonus.chute = RewardMachine.Chute.UPGRADE
			var register: MachinePrize = MachinePrize.new(
				MachinePrize.Kind.REGISTER, MachinePrize.Rarity.RARE, null, load(LONG_UPGRADE)
			)
			var registers: Array[MachinePrize] = [register]
			bonus.set_drawn(registers)
			bonus.picked = 0
			record.visits.append(bonus)
		var events: Array[InspectionDefinition] = []
		if balance.inspection_shifts.has(shift):
			events.append(load(LONG_INSPECTION))
		if balance.review_shifts.has(shift):
			events.append_array([load(LONG_INSPECTION), load(SPOT_CHECK)])
		if balance.boon_shifts.has(shift):
			events.append(load(BOON))
		record.inspections = events
		history.append(record)
	if not won:
		history[-1].total = history[-1].quota - 5
	run.history = history
	run.shift_index = last - 1
	run.limits.quota = history[-1].quota
	run.phase = RunState.Phase.WON if won else RunState.Phase.LOST


func _last_result(screen: ShiftScreen) -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	result.total = screen.run.history[-1].total
	return result


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	return key


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
