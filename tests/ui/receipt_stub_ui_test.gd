extends GdUnitTestSuite
## The receipt on the real shift screen (#75, #80; main scene v2's H2 of 2026-11-08). In planning
## it prints nothing under its header (2026-11-08 feedback: no band), whatever is placed or
## removed; the header (ReceiptTarget) shows PROJECTED with the preview's total in ink (rolling to
## it) and the line against the quota ("N€ short" in tomato dark, "on target" or "+N€ over" in
## green dark); the paper stands on the printer's slot inside the register column and the 1280x720
## screen as short as its header, every line in view, clear of the hand, the monitor and CHECKOUT. A
## scan frames no line (there is none). The click starts the count-up: rows print in slot order
## as the count reaches them, a printed row never moves, and the receipt ends with every item's
## payout on its row and TOTAL over the hero. The real saves and logs are never touched: both go
## to a temporary folder.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set: several fizzles and combos.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	# The game's window, not the headless default (1280x1280).
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## No fizzle, then one, then several: nothing prints under the header on any place or remove, the
## hero rolls to the preview's total.
func test_the_planning_receipt_lists_the_items_and_the_fizzles() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	assert_int(_wasted(screen.run.preview())).is_equal(0)
	await _assert_header_only(screen)
	_place(screen, ["cheese", "cream"])
	await _frames(2)
	assert_int(_wasted(screen.run.preview())).is_equal(2)
	await _assert_header_only(screen)
	_clear_row(screen)
	screen._debug.give_upgrade("coupon_engine")
	_place(screen, ["multipack", "cheese", "cream"])
	await _frames(2)
	assert_int(_wasted(screen.run.preview())).is_equal(4)
	await _assert_header_only(screen)
	_assert_planning_on_screen(screen)


## Planning's receipt for the screen's belt: no lines, no rows, the hero (once rolled) at the
## preview's total.
func _assert_header_only(screen: ShiftScreen) -> void:
	var receipt: ReceiptView = screen._receipt
	await _rolled(receipt)
	assert_array(_lines(screen)).is_empty()
	assert_bool(receipt._items.is_empty()).is_true()
	var total: int = screen.run.preview().total
	assert_str(receipt.target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % total)
	assert_str(receipt.target.total_caption.text).is_equal(ReceiptTarget.PROJECTED_TEXT)


## PROJECTED against the shift's quota on the real screen at 1280x720: the hero prints in ink; a
## short row has "N€ short" in tomato dark; a total exactly on the quota, and one over it, "on
## target" or "+N€ over" in green dark; the header stays inside the paper, even on a hover.
func test_the_projected_total_is_coloured_by_the_quota() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	await _rolled(screen._receipt)
	var run: RunState = screen.run
	var result: ScoreResult = run.preview()
	assert_int(result.total).is_less(run.quota())
	var receipt: ReceiptView = screen._receipt
	var target: ReceiptTarget = receipt.target
	assert_that(target.hero.color).is_equal(Palette.INK)
	assert_that(_against_color(receipt)).is_equal(Palette.TOMATO_DARK)
	var short: String = ReceiptTarget.against_text(result.total, run.quota())
	assert_str(short).is_equal(ReceiptView.money(run.quota() - result.total) + " short")
	assert_str(target.over.text).is_equal(short)
	screen._effects.pointer = func() -> Vector2: return Vector2(-500, -500)
	var milk: ItemView = screen._row_views[1] as ItemView
	milk.hovered.emit(milk)
	await _frames(2)
	_assert_planning_on_screen(screen)
	screen._effects.unfocus()
	# Exactly on the quota, then over it (the same preview against a lower quota).
	var slots: int = RowCapacity.card_limit(run.limits)
	var names: PackedStringArray = CardInstance.names(run.row)
	for quota: int in [result.total, result.total - 1]:
		receipt.show_planning(screen.receipt_header(), result, names, slots, quota)
		await _frames(2)
		assert_that(target.hero.color).is_equal(Palette.INK)
		assert_that(_against_color(receipt)).is_equal(Palette.GREEN_DARK)
		assert_str(target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % result.total)
		assert_str(target.over.text).is_equal(ReceiptTarget.against_text(result.total, quota))
		assert_bool(target.check.visible).is_false()
		_assert_planning_on_screen(screen)


## Waits for the projected number's roll to land (ReceiptRoll), a few seconds at most.
func _rolled(receipt: ReceiptView) -> void:
	for _frame: int in range(600):
		if not receipt.target.roll.rolling():
			return
		await get_tree().process_frame


## The colour of the line against the target.
static func _against_color(receipt: ReceiptView) -> Color:
	return receipt.target.over.get_theme_color("font_color")


## A scan frames no receipt line (planning prints none: main scene v2), belt item or hand item.
func test_a_belt_items_scan_frames_its_line() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk", "coffee"])
	await _frames(3)
	var receipt: ReceiptView = screen._receipt
	var shown: Array[String] = _lines(screen)
	assert_bool(screen.debug_scan(screen.run.row[1])).is_true()
	await _frames(2)
	assert_object(receipt._framed_line()).is_null()
	assert_array(_lines(screen)).is_equal(shown)
	screen._scan.clear()
	var hand: CardInstance = screen.run.hand()[0]
	assert_bool(screen.debug_scan(hand)).is_true()
	await _frames(2)
	assert_bool(screen._scan.is_full()).is_true()
	assert_object(receipt._framed_line()).is_null()
	screen._scan.clear()


## The click prints the rows (main scene v2): each item's row prints as the count
## reaches it, in slot order under the header, and a printed row never moves; the receipt ends
## with every item's payout on its row and TOTAL over the hero, the count's total.
func test_the_count_up_receipt_fills_in_as_it_counts() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	_place(screen, FULL_ROW)
	await _frames(2)
	var run: RunState = screen.run
	var preview: ScoreResult = run.preview()
	var receipt: ReceiptView = screen._receipt
	screen._on_checkout_pressed()
	var count_up: CountUp = screen._count_up
	var failures: Array[String] = []
	var at: Dictionary[Control, Vector2] = {}
	var printed: int = 0
	while screen._counting and not count_up._verdict_shown:
		await get_tree().process_frame
		var now: Array[Control] = receipt.printed_rows()
		if now.size() < printed:
			failures.append("a row went: %d after %d" % [now.size(), printed])
		printed = now.size()
		var last_y: float = -INF
		for row: Control in now:
			var y: float = row.global_position.y
			if y < last_y:
				failures.append("%s above the row before it" % row.name)
			last_y = y
			if at.has(row) and at[row] != row.global_position and not count_up._verdict_shown:
				failures.append("%s moved" % (row.get_child(0) as Label).text)
			at[row] = row.global_position
	assert_array(failures).is_empty()
	while screen._counting:
		await get_tree().process_frame
	var rows: Array[Control] = receipt.printed_rows()
	assert_int(rows.size()).is_equal(run.row.size())
	for slot: int in range(run.row.size()):
		assert_str((rows[slot].get_child(1) as Label).text).is_equal(
			ReceiptView.money(run.last_result.payouts[slot])
		)
	assert_array(Array(run.last_result.payouts)).is_equal(Array(preview.payouts))
	assert_str(receipt.target.total_caption.text).is_equal(ReceiptTarget.TOTAL_TEXT)
	assert_str(receipt.target.hero.text).is_equal(ReceiptTarget.AMOUNT_TEXT % run.last_result.total)


## The planning receipt on screen: inside the screen and over the register column, standing on
## the printer's slot as short as its header, every line in view, the header inside the paper, clear
## of the hand, the monitor and CHECKOUT.
func _assert_planning_on_screen(screen: ShiftScreen) -> void:
	var receipt: ReceiptView = screen._receipt
	var stage: Rect2 = screen._stage.get_global_rect()
	var rect: Rect2 = receipt.get_global_rect()
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
	var column: Rect2 = _on_stage(screen, ShiftStage.REGISTER_RECT)
	assert_float(rect.position.x).is_greater_equal(column.position.x)
	assert_float(rect.end.x).is_less_equal(column.end.x)
	assert_float(rect.end.y).is_less(stage.position.y + ShiftStage.RECEIPT_BOTTOM)
	# As short as its header (2026-11-08 feedback: no empty band), its lines never longer than the
	# paper, under RECEIPT_TOP.
	assert_float(rect.position.y).is_equal(stage.position.y + ShiftStage.RECEIPT_TOP)
	assert_float(receipt.size.y).is_equal(receipt.natural_height())
	for blocker: Rect2 in [
		_on_stage(screen, ShiftStage.HAND_AREA),
		_on_stage(screen, ShiftStage.MONITOR_RECT),
		screen._checkout_button.get_global_rect(),
	]:
		assert_bool(rect.intersects(blocker)).override_failure_message(str(blocker)).is_false()
	assert_bool(rect.grow(1.0).encloses(receipt.target.get_global_rect())).is_true()
	var scroll: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
	for line: Node in receipt._lines.get_children():
		var line_rect: Rect2 = (line as Control).get_global_rect()
		assert_bool(scroll.encloses(line_rect)).override_failure_message(str(line_rect)).is_true()


## How many of `result`'s steps fizzle (WASTED), the upgrades' too.
static func _wasted(result: ScoreResult) -> int:
	var count: int = 0
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED:
			count += 1
	return count


static func _lines(screen: ShiftScreen) -> Array[String]:
	return _receipt_lines(screen._receipt)


## A receipt's lines as text ("left | right", a hung line's marker before its text; "---" for a
## rule).
static func _receipt_lines(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HSeparator:
			lines.append("---")
			continue
		var left: Label = line.get_child(0) as Label
		var marker: Label = left.get_node_or_null("Marker") as Label
		var words: String = left.get_meta(ReceiptInk.WORDS_META, left.text)
		var text: String = words if marker == null else "%s %s" % [marker.text, words]
		lines.append("%s | %s" % [text, (line.get_child(1) as Label).text])
	return lines


## The screen on shift 1.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(3)
	return screen


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % card_id))
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()


func _clear_row(screen: ShiftScreen) -> void:
	for card: CardInstance in screen.run.row.duplicate():
		screen.run.remove(card)
	screen._refresh()


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return screen._stage.get_global_transform() * rect


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
