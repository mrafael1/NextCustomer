extends GdUnitTestSuite
## The receipt on the real shift screen (#75, decision 1A). In planning it is the stub: "NEXT
## CUSTOMER · REG 3", "SHIFT n/m · k ITEMS" (coupons counted), a dashed rule, PROJECTED €N and
## the fizzle count ("1 fizzle · see the item", "N fizzles · see the items", none without), then
## the tear; it follows every place and remove, stands on the printer's slot inside the register
## column and the 1280x720 screen (#80), every line on one row and in view, clear of the hand,
## the monitor and CHECKOUT. The click starts the
## count-up under the same header: at every frame the receipt is the header and the lines of the
## steps played so far, as show_result prints them, each combo line marked inside the scroll
## area. The real saves and logs are never touched: both go to a temporary folder.

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


## No fizzle, then one, then several: the stub's words follow every place and remove; the item
## count includes the coupon.
func test_the_planning_stub_counts_the_items_and_the_fizzles() -> void:
	var screen: ShiftScreen = await _screen()
	var shifts: int = screen.run.shift_count()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	assert_int(ReceiptView.fizzle_count(screen.run.preview())).is_equal(0)
	assert_array(_lines(screen)).is_equal(_stub(screen, "SHIFT 1/%d · 2 ITEMS" % shifts, ""))
	_place(screen, ["cheese", "coffee"])
	await _frames(2)
	assert_int(ReceiptView.fizzle_count(screen.run.preview())).is_equal(1)
	assert_array(_lines(screen)).is_equal(
		_stub(screen, "SHIFT 1/%d · 4 ITEMS" % shifts, "1 fizzle · see the item")
	)
	# Several fizzles, among them the Coupon engine's (the first coupon, Multipack, pays nothing)
	# and Coffee's (no Breakfast product after it).
	_clear_row(screen)
	screen._debug.give_upgrade("coupon_engine")
	_place(screen, ["multipack", "cheese", "coffee"])
	await _frames(2)
	assert_int(ReceiptView.fizzle_count(screen.run.preview())).is_equal(3)
	# Multipack is a coupon: it counts as an item.
	assert_array(_lines(screen)).is_equal(
		_stub(screen, "SHIFT 1/%d · 3 ITEMS" % shifts, "3 fizzles · see the items")
	)
	_assert_stub_on_screen(screen)


## The click starts the count-up under the stub's header (the stub's PROJECTED, fizzle line and
## tear go at once). At every frame of the count-up the receipt is the header, then the lines of
## the steps played so far, word for word as show_result prints them; each combo line printed has
## its diamond, and the newest line is in the scroll area once it has had a few frames to get
## there. The receipt ends as show_result prints it, every combo line marked.
func test_the_count_up_receipt_prints_the_steps_so_far() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	_place(screen, FULL_ROW)
	await _frames(2)
	var run: RunState = screen.run
	var header: PackedStringArray = screen.receipt_header()
	var expected: ReceiptView = auto_free(ReceiptView.new())
	expected.show_result(
		run.preview(),
		ShiftScreen._names(run.row),
		LoyaltyCard.names(run.upgrades),
		InspectionTag.names(run.inspections),
		header
	)
	var full: Array[String] = _receipt_lines(expected)
	var combos: int = 0
	for step: ScoreStep in run.preview().steps:
		combos += int(ReceiptView.is_combo(step))
	assert_int(combos).is_greater(1)
	screen._on_checkout_pressed()
	var count_up: CountUp = screen._count_up
	var receipt: ReceiptView = screen._receipt
	var most: int = 0
	var newest: Control = null
	var newest_frames: int = 0
	var failures: Array[String] = []
	while screen._counting and not count_up._verdict_shown:
		var shown: Array[String] = _receipt_lines(receipt)
		most = maxi(most, shown.size())
		if shown != full.slice(0, shown.size()):
			failures.append("%s is not a start of %s" % [shown, full])
		if shown.size() < header.size() or shown[1] != header[1] + " | ":
			failures.append("no header: %s" % [shown])
		var lines: Array[Node] = receipt._lines.get_children()
		var last: Control = lines[-1] as Control
		newest_frames = newest_frames + 1 if last == newest else 0
		newest = last
		var scroll: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
		if newest_frames >= 3 and not scroll.encloses(newest.get_global_rect()):
			failures.append("newest line %s outside %s" % [newest.get_global_rect(), scroll])
		if newest_frames >= 3:
			_check_combo_marks(receipt, scroll, failures)
		await get_tree().process_frame
	assert_array(failures).is_empty()
	# Steps printed one by one, past the header (the TOTAL line comes with the verdict).
	assert_int(most).is_greater(header.size() + 3)
	while screen._counting:
		await get_tree().process_frame
	var marked: int = 0
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer and line.get_child(0).has_node("ComboDiamond"):
			marked += 1
	assert_int(marked).is_equal(combos)


## The stub on screen: inside the screen and over the register column, standing on the printer's
## slot, as tall as its lines, every line on one row and in view, clear of the hand, the monitor
## and CHECKOUT.
func _assert_stub_on_screen(screen: ShiftScreen) -> void:
	var receipt: ReceiptView = screen._receipt
	var stage: Rect2 = screen._stage.get_global_rect()
	var rect: Rect2 = receipt.get_global_rect()
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
	var column: Rect2 = _on_stage(screen, ShiftStage.REGISTER_RECT)
	assert_float(rect.position.x).is_greater_equal(column.position.x)
	assert_float(rect.end.x).is_less_equal(column.end.x)
	assert_float(rect.end.y).is_equal(stage.position.y + ShiftStage.RECEIPT_BOTTOM)
	assert_float(receipt.size.y).is_equal(receipt.natural_height())
	for blocker: Rect2 in [
		_on_stage(screen, ShiftStage.HAND_AREA),
		_on_stage(screen, ShiftStage.MONITOR_RECT),
		screen._checkout_button.get_global_rect(),
	]:
		assert_bool(rect.intersects(blocker)).override_failure_message(str(blocker)).is_false()
	var scroll: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
	for line: Node in receipt._lines.get_children():
		var line_rect: Rect2 = (line as Control).get_global_rect()
		assert_bool(scroll.encloses(line_rect)).override_failure_message(str(line_rect)).is_true()
		if line is HBoxContainer:
			var left: Label = line.get_child(0) as Label
			assert_int(left.get_line_count()).override_failure_message(left.text).is_equal(1)


## Every combo line in the receipt has its diamond, which (on a line in view) is in the scroll
## area too.
static func _check_combo_marks(
	receipt: ReceiptView, scroll: Rect2, failures: Array[String]
) -> void:
	for line: Node in receipt._lines.get_children():
		if not line is HBoxContainer:
			continue
		var left: Label = line.get_child(0) as Label
		var diamond: Control = left.get_node_or_null("ComboDiamond") as Control
		if diamond == null:
			continue
		var line_rect: Rect2 = (line as Control).get_global_rect()
		if scroll.encloses(line_rect) and not scroll.encloses(diamond.get_global_rect()):
			failures.append("diamond outside the scroll area on %s" % left.text)
		if not line_rect.grow(0.5).encloses(diamond.get_global_rect()):
			failures.append("diamond outside its line %s" % left.text)


## The stub's lines for `shift_line` and `fizzle_line` (none when empty) on the screen's preview.
static func _stub(screen: ShiftScreen, shift_line: String, fizzle_line: String) -> Array[String]:
	var lines: Array[String] = [ReceiptView.HEADER_TEXT + " | ", shift_line + " | ", "---"]
	lines.append("PROJECTED | €%d" % screen.run.preview().total)
	if not fizzle_line.is_empty():
		lines.append(fizzle_line + " | ")
	lines.append(ReceiptView.TEAR_PATTERN.repeat(ReceiptView.TEAR_REPEAT) + " | ")
	return lines


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
		var text: String = left.text if marker == null else "%s %s" % [marker.text, left.text]
		lines.append("%s | %s" % [text, (line.get_child(1) as Label).text])
	return lines


## The screen past the impulse rack.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
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
