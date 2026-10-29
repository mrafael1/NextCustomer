extends GdUnitTestSuite
## The receipt on the real shift screen (#75, #80). In planning it is itemised: "NEXT CUSTOMER ·
## REG 3", "SHIFT n/m · k ITEMS" (coupons counted), a dashed rule, each belt item's name and
## payout (cents, from the preview), "n ·····" for each open empty slot, a dashed rule,
## "PROJECTED €N.00" (green with the met mark at or over the shift's quota, red with "short
## €N.00" on its own row under it) and the fizzle footer ("1 WASTED · hover an item", none
## without); it follows every place and remove, stands on the printer's slot inside
## the register column and the 1280x720 screen, every line on one row and in view, every mark
## inside the paper, clear of the hand, the monitor and CHECKOUT. A belt item's scan frames its
## line, the frame around the line inside the paper; a hand item's frames none. The click starts
## the count-up: at every frame the receipt has the header, the footer "tap: skip · hold: fast"
## last until the TOTAL line, and the step lines printed so far in show_result's order; the
## counted line is framed and in view; it ends as show_result prints it, every combo marked. The
## real saves and logs are never touched: both go to a temporary folder.

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


## No fizzle, then one, then several: the itemised lines follow every place and remove; the item
## count includes the coupon.
func test_the_planning_receipt_lists_the_items_and_the_fizzles() -> void:
	var screen: ShiftScreen = await _screen()
	var shifts: int = screen.run.shift_count()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	assert_int(ReceiptView.fizzle_count(screen.run.preview())).is_equal(0)
	assert_array(_lines(screen)).is_equal(_planning(screen, "SHIFT 1/%d · 2 ITEMS" % shifts))
	# Coffee's (no Breakfast product after it) and Cheese's (no Bread just before it, #45).
	_place(screen, ["cheese", "coffee"])
	await _frames(2)
	assert_int(ReceiptView.fizzle_count(screen.run.preview())).is_equal(2)
	assert_array(_lines(screen)).is_equal(
		_planning(screen, "SHIFT 1/%d · 4 ITEMS" % shifts, "2 WASTED")
	)
	# Several fizzles, among them the Coupon engine's (the first coupon, Multipack, pays nothing),
	# Coffee's (no Breakfast product after it) and Cheese's (no Bread just before it, #45).
	_clear_row(screen)
	screen._debug.give_upgrade("coupon_engine")
	_place(screen, ["multipack", "cheese", "coffee"])
	await _frames(2)
	assert_int(ReceiptView.fizzle_count(screen.run.preview())).is_equal(4)
	# Multipack is a coupon: it counts as an item.
	assert_array(_lines(screen)).is_equal(
		_planning(screen, "SHIFT 1/%d · 3 ITEMS" % shifts, "4 WASTED")
	)
	_assert_planning_on_screen(screen)


## PROJECTED against the shift's quota on the real screen at 1280x720 (#71's play test): a short
## row's total is red with "short €N.00" on the row under it; a total exactly on the quota, and one
## over it, is green with the met mark and no shortfall; the colours are Palette's; the footer and
## the mark stay inside the paper, the footer on one line even with a long hover hint.
func test_the_projected_total_is_coloured_by_the_quota() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	var run: RunState = screen.run
	var result: ScoreResult = run.preview()
	assert_int(result.total).is_less(run.quota())
	var receipt: ReceiptView = screen._receipt
	assert_that(_projected_color(receipt)).is_equal(Palette.TOMATO)
	var short: String = ReceiptView.SHORT_TEXT % ReceiptView.money(run.quota() - result.total)
	assert_str(_lines(screen)[-1]).is_equal(short + " | ")
	screen._effects.pointer = func() -> Vector2: return Vector2(-500, -500)
	var milk: ItemView = screen._row_views[1] as ItemView
	milk.hovered.emit(milk)
	await _frames(2)
	_assert_planning_on_screen(screen, false)
	screen._effects.unfocus()
	# Exactly on the quota, then over it (the same preview against a lower quota).
	var slots: int = RowCapacity.card_limit(run.limits)
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in run.row:
		names.append(card.definition.display_name)
	for quota: int in [result.total, result.total - 1]:
		receipt.show_planning(screen.receipt_header(), result, names, slots, quota)
		await _frames(2)
		assert_that(_projected_color(receipt)).is_equal(Palette.GOOD)
		assert_str(_lines(screen)[-1]).is_equal("PROJECTED | " + ReceiptView.money(result.total))
		_assert_planning_on_screen(screen)


## The PROJECTED amount's colour.
static func _projected_color(receipt: ReceiptView) -> Color:
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer:
			if (line.get_child(0) as Label).text == ReceiptView.PROJECTED_TEXT:
				return (line.get_child(1) as Label).get_theme_color("font_color")
	return Color.TRANSPARENT


## A belt item's full scan frames its line (the frame around the line and its mark column,
## inside the paper); the scan's end clears it; a hand item's scan frames none.
func test_a_belt_items_scan_frames_its_line() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen, ["bread", "milk", "coffee"])
	await _frames(3)
	var receipt: ReceiptView = screen._receipt
	assert_object(receipt._framed_line()).is_null()
	assert_bool(screen.debug_scan(screen.run.row[1])).is_true()
	await _frames(2)
	var line: HBoxContainer = receipt._items[1]
	assert_object(receipt._framed_line()).is_same(line)
	var line_rect: Rect2 = line.get_global_rect()
	var inset: Rect2 = receipt._inset.get_global_rect()
	var frame: Rect2 = Rect2(
		inset.position.x,
		line_rect.position.y - ReceiptView.FRAME_GROW,
		inset.size.x,
		line_rect.size.y + 2.0 * ReceiptView.FRAME_GROW
	)
	assert_bool(frame.encloses(line_rect)).is_true()
	assert_float(frame.position.x).is_less(line_rect.position.x)
	# The frame runs past the line's mark column by B2's padding and frame.
	assert_float(frame.end.x).is_greater_equal(line_rect.end.x + ReceiptView.FRAME_PAD)
	var paper: Rect2 = receipt.get_global_rect()
	assert_bool(paper.encloses(frame)).override_failure_message(str(frame)).is_true()
	screen._scan.clear()
	assert_object(receipt._framed_line()).is_null()
	var hand: CardInstance = screen.run.hand()[0]
	assert_bool(screen.debug_scan(hand)).is_true()
	await _frames(2)
	assert_bool(screen._scan.is_full()).is_true()
	assert_object(receipt._framed_line()).is_null()
	screen._scan.clear()


## The click starts the count-up under the planning receipt's header, every item waiting. At
## every frame of the count-up the receipt has the header, the footer last, and its step lines
## (the lines but the items', the rules, TOTAL and the footer) in show_result's order; the framed
## line is in the scroll area once it has had a few frames to get there, every bonus beat frames
## its bonus line (not its item's), and every combo line printed has its diamond. The receipt
## ends as show_result prints it, every combo line marked.
func test_the_count_up_receipt_fills_in_as_it_counts() -> void:
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
		CardInstance.names(run.row),
		LoyaltyCard.names(run.upgrades),
		InspectionTag.names(run.inspections),
		header,
		ReceiptInk.cards_of(run.row)
	)
	var full: Array[String] = _step_lines(expected)
	var combos: int = 0
	for step: ScoreStep in run.preview().steps:
		combos += int(ReceiptView.is_combo(step))
	assert_int(combos).is_greater(1)
	screen._on_checkout_pressed()
	var count_up: CountUp = screen._count_up
	var receipt: ReceiptView = screen._receipt
	var most: int = 0
	var framed: Control = null
	var framed_frames: int = 0
	var failures: Array[String] = []
	# The bonus beats started since the last frame: their lines print as they start.
	var bonuses: Array[ScoreStep] = []
	var bonus_beats: Array[int] = [0]
	count_up.beat_started.connect(
		func(beat: CountUpBeat, step: ScoreStep, _l: String, _v: CardView, _n: int) -> void:
			if beat.kind == CountUpBeat.Kind.BONUS:
				bonuses.append(step)
	)
	while screen._counting and not count_up._verdict_shown:
		for bonus: ScoreStep in bonuses:
			bonus_beats[0] += 1
			_check_bonus_frame(receipt, bonus, failures)
		bonuses.clear()
		var shown: Array[String] = _step_lines(receipt)
		most = maxi(most, shown.size())
		if not _is_subsequence(shown, full):
			failures.append("%s is not in the order of %s" % [shown, full])
		var all: Array[String] = _receipt_lines(receipt)
		if all.size() < header.size() or all[1] != header[1] + " | ":
			failures.append("no header: %s" % [all])
		elif all[-1] != ReceiptView.COUNT_FOOTER_TEXT + " | ":
			failures.append("no footer: %s" % all[-1])
		var current: Control = receipt._framed_line()
		framed_frames = framed_frames + 1 if current == framed else 0
		framed = current
		var scroll: Rect2 = receipt._scroll.get_global_rect().grow(1.0)
		if framed != null and framed_frames >= 3 and not scroll.encloses(framed.get_global_rect()):
			failures.append("framed line %s outside %s" % [framed.get_global_rect(), scroll])
		if framed_frames >= 3:
			_check_combo_marks(receipt, scroll, failures)
		await get_tree().process_frame
	assert_array(failures).is_empty()
	assert_int(most).is_greater(3)
	assert_int(bonus_beats[0]).is_greater(0)
	while screen._counting:
		await get_tree().process_frame
	# Up to the TOTAL line, whose amount the dessert then turns into the verdict.
	var printed: Array[String] = _receipt_lines(expected).slice(0, -1)
	assert_array(_receipt_lines(receipt).slice(0, printed.size())).is_equal(printed)
	var marked: int = 0
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer and line.get_child(0).has_node("ComboDiamond"):
			marked += 1
	assert_int(marked).is_equal(combos)


## The planning receipt on screen: inside the screen and over the register column, standing on
## the printer's slot, as tall as its lines, every line on one row and in view and every mark
## inside the paper, clear of the hand, the monitor and CHECKOUT (with `marked`, some line has a
## mark).
func _assert_planning_on_screen(screen: ShiftScreen, marked: bool = true) -> void:
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
	var lines_end: float = receipt._lines.get_global_rect().end.x
	var marks: int = 0
	for line: Node in receipt._lines.get_children():
		var line_rect: Rect2 = (line as Control).get_global_rect()
		assert_bool(scroll.encloses(line_rect)).override_failure_message(str(line_rect)).is_true()
		assert_float(line_rect.end.x).is_less_equal(lines_end)
		if line is HBoxContainer:
			var left: Label = line.get_child(0) as Label
			assert_int(left.get_line_count()).override_failure_message(left.text).is_equal(1)
			for label: Node in line.get_children():
				var label_rect: Rect2 = (label as Control).get_global_rect()
				(
					assert_bool(rect.encloses(label_rect))
					. override_failure_message("%s %s" % [left.text, label_rect])
					. is_true()
				)
			var mark: Control = line.get_child(1).get_node_or_null("Mark") as Control
			if mark != null:
				marks += 1
				assert_bool(rect.encloses(mark.get_global_rect())).is_true()
				# In the line's mark column, B2's gap past its amount.
				var text_end: float = (
					(line.get_child(1) as Control).get_global_rect().end.x - ReceiptView.MARK_COLUMN
				)
				assert_float(mark.get_global_rect().position.x).is_greater_equal(text_end + 5.5)
				assert_float(mark.get_global_rect().end.x).is_less_equal(line_rect.end.x + 0.5)
	if marked:
		assert_int(marks).is_greater(0)


## A bonus beat's line is the framed one: a step line under its item (not an item's line) with
## the bonus's amount, and a combo's band left off while it is framed.
static func _check_bonus_frame(
	receipt: ReceiptView, step: ScoreStep, failures: Array[String]
) -> void:
	var framed: Control = receipt._framed_line()
	if framed == null or receipt._items.values().has(framed):
		failures.append("bonus %s: framed %s, not its line" % [step.text, framed])
		return
	var amount: String = (framed.get_child(1) as Label).text
	if amount != ReceiptView.money(step.value, true):
		failures.append("bonus %s: framed line reads %s" % [step.text, amount])
	if not framed.get_meta("framed", false):
		failures.append("bonus %s: framed line not marked framed" % step.text)


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


## The planning receipt's lines for `shift_line` on the screen's preview: each belt item's name and
## payout, then the open empty slots, PROJECTED, the shortfall's row under the quota, and the
## fizzle footer for `fizzles` (none when empty) with the hint.
static func _planning(
	screen: ShiftScreen, shift_line: String, fizzles: String = ""
) -> Array[String]:
	var run: RunState = screen.run
	var result: ScoreResult = run.preview()
	var lines: Array[String] = [ReceiptView.HEADER_TEXT + " | ", shift_line + " | ", "---"]
	for slot: int in range(run.row.size()):
		var payout: String = ReceiptView.money(result.payouts[slot])
		lines.append("%s | %s" % [run.row[slot].definition.display_name, payout])
	for slot: int in range(run.row.size(), RowCapacity.card_limit(run.limits)):
		lines.append("%d ····· | " % (slot + 1))
	lines.append("---")
	lines.append("PROJECTED | " + ReceiptView.money(result.total))
	if result.total < run.quota():
		var short: String = ReceiptView.money(run.quota() - result.total)
		lines.append((ReceiptView.SHORT_TEXT % short) + " | ")
	if not fizzles.is_empty():
		lines.append(fizzles + " |  · hover an item")
	return lines


## A receipt's step lines: every line but the header, the items', the rules, TOTAL and the
## footer.
static func _step_lines(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	var all: Array[String] = _receipt_lines(receipt)
	var children: Array[Node] = receipt._lines.get_children()
	var items: Array = receipt._items.values()
	for index: int in range(2, children.size()):
		var line: Node = children[index]
		if line is HSeparator or items.has(line) or line == receipt._total_line:
			continue
		if all[index] == ReceiptView.COUNT_FOOTER_TEXT + " | ":
			continue
		lines.append(all[index])
	return lines


## Whether `part`'s lines appear in `whole` in the same order.
static func _is_subsequence(part: Array[String], whole: Array[String]) -> bool:
	var at: int = 0
	for text: String in part:
		at = whole.find(text, at)
		if at < 0:
			return false
		at += 1
	return true


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
		if line is ReceiptStub:
			continue  # The BONUS stub (#77 machine v2), checked on its own.
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
