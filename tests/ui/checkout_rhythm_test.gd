extends GdUnitTestSuite
## V3's wider monitor retains the explanation and leaves the quota celebration on the register.

const MILK := preload("res://data/cards/milk.tres")

var _folder: String = ""


func before_test() -> void:
	# Nothing here saves or logs, but the event log and saves still point at a temporary folder.
	_folder = "user://test_checkout_rhythm_ui_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_monitor_keeps_bonus_lines_and_folds_only_the_earliest_overflow() -> void:
	var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
	add_child(column)
	column.reduced_motion = func() -> bool: return true
	column.start_item(load("res://data/cards/banana.tres"), PackedStringArray(["Produce"]))
	var giver_icon: Texture2D = load("res://art/minis/banana.png")
	column.show_step("Banana chain  +3€", false, false, giver_icon, false)
	var plain: Control = column.step_rows()[-1]
	var plain_text: Rect2 = (plain.get_node("Text") as Label).get_global_rect()
	assert_object(plain.get_node_or_null("FromBag")).is_null()
	column.show_step("Banana chain  +3€", false, false, giver_icon, true, false, "Banana")
	var newest: Control = column.step_rows()[-1]
	assert_bool(newest.get_meta(&"from_bag")).is_true()
	# v1.11: a small bag glyph beside the giver's icon, the words in its tip; the line stays the
	# name's and the amount's (a bonus's words green, PR #138 round 6), whole on one line.
	var text: Label = newest.get_node("Text") as Label
	var mark: Control = newest.get_node("Mark") as Control
	var bag: TipTarget = newest.get_node("FromBag") as TipTarget
	assert_object(bag.texture).is_equal(MonitorStepRow.BAG_ICON)
	assert_str(bag.tip_text).is_equal(MonitorStepRow.bag_tip_of("Banana"))
	assert_str(bag.tip_text).contains("already scanned").contains("Banana")
	assert_that(text.get_theme_color("font_color")).is_equal(MonitorStepRow.BONUS_COLOR)
	var bag_rect: Rect2 = bag.get_global_rect()
	var mark_rect: Rect2 = mark.get_global_rect()
	assert_float(bag_rect.position.x).is_greater_equal(mark_rect.end.x)
	assert_float(bag_rect.position.x - mark_rect.end.x).is_less_equal(MonitorStepRow.MARK_GAP)
	assert_float(absf(bag_rect.get_center().y - mark_rect.get_center().y)).is_less_equal(1.0)
	assert_float(text.get_global_rect().position.x).is_greater_equal(bag_rect.end.x)
	assert_str(text.text).is_equal("Banana chain")
	assert_float(newest.size.y).is_equal(MonitorStepRow.ROW_PITCH)
	assert_float(text.get_global_rect().end.x).is_equal(plain_text.end.x)
	var amount: Label = newest.get_node("Amount") as Label
	assert_str(amount.text).is_equal("+3€")
	assert_float(text.get_global_rect().position.x + MonitorStepRow.text_width(text)).is_less(
		amount.get_global_rect().position.x
	)
	var leader: MonitorLeader = newest.get_node("Leader") as MonitorLeader
	assert_float(leader.span().y).is_greater(leader.span().x)
	column.show_step("Produce regulars  +2€", false)
	column.show_step("Produce aisle run  ×3", false)
	column.show_step("Multipack  ×3", false)
	column.show_step("Slot engine  ×2", false)
	column.show_step("Lemon squeezer  ×2", false)
	# Seven lines in the rows' room (PR #138 monitor): the newest that fit, the earlier ones folded
	# into "+N earlier" (N the lines left out), every row inside the rows' area.
	var texts: PackedStringArray = column.step_texts()
	assert_str(texts[-1]).is_equal("Lemon squeezer  ×2")
	assert_int(texts.size()).is_less(7)
	assert_str(texts[0]).is_equal(MonitorCarry.fold_caption(7 - (texts.size() - 1)))
	var area: Rect2 = column.part_rects()["rows"]
	for row: Control in column.step_rows():
		assert_bool(area.grow(0.5).encloses(row.get_global_rect())).is_true()

	await get_tree().process_frame
	await get_tree().process_frame


## The count's lines keep every maths symbol: a multiplier reads "Multipack" with its "×3" as its
## amount, in its strength's ink (PR #138 round 3; the factor shows once); a + amount is green
## (PR #138 round 2) and so are its giver's words (round 6); a multiplier's words over ×1 are green
## too (v1.16, the user's "multiplier (if > 1.0) should also put text on green"; "×1.5" as well),
## a ×1 one's teal. The
## payout shows only its result at the foot (PR #138 monitor: "= 24€", no equation row, no "Pays"
## row).
## Reduced motion or not.
func test_multipliers_keep_their_symbol_and_the_payout_shows_only_its_result() -> void:
	for reduced: bool in [false, true]:
		var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
		add_child(column)
		column.reduced_motion = func() -> bool: return reduced
		column.start_item(MILK, PackedStringArray(["Dairy"]))
		# Each line is the newest row when it shows (earlier ones may fold in the rows' room).
		column.show_step("+2€ Eggs", false)
		var add: Control = column.step_rows()[-1]
		assert_str((add.get_node("Text") as Label).text).is_equal("Eggs")
		assert_that(_colour(add, "Amount")).is_equal(MonitorStepRow.BONUS_COLOR)
		assert_that(_colour(add, "Text")).is_equal(MonitorStepRow.BONUS_COLOR)
		for line: String in ["×3 Multipack", "×2 Golden Strawberries aisle", "×1.5 Stale popcorn"]:
			column.show_step(line, false)
			var row: Control = column.step_rows()[-1]
			var text: Label = row.get_node("Text") as Label
			var factor: Label = row.get_node("Amount") as Label
			assert_str(factor.text).is_equal(line.get_slice(" ", 0))
			assert_str(text.text).is_equal(line.substr(line.find(" ") + 1))
			var step: int = MonitorStepRow.factor_step(factor.text)
			assert_that(_colour(row, "Amount")).is_equal(MonitorStepRow.factor_ink(step))
			assert_that(_colour(row, "Text")).is_equal(MonitorStepRow.BONUS_COLOR)
			assert_int(text.get_line_count()).is_less_equal(text.max_lines_visible)
			assert_float(text.get_global_rect().end.x).is_less_equal(
				factor.get_global_rect().position.x
			)
		column.show_step("×1 Snack deal", false)
		var plain: Control = column.step_rows()[-1]
		assert_that(_colour(plain, "Text")).is_equal(MonitorStepRow.TEXT_COLOR)
		var shown_rows: int = column.step_rows().size()
		column.set_value(24)
		assert_int(column.step_rows().size()).is_equal(shown_rows)
		var payout: MonitorPayout = column.payout_view()
		assert_bool(payout.equals().visible).is_true()
		assert_str(payout.digit_words().text).is_equal(MonitorText.euros(24))
		assert_int(payout.pay_amount()).is_equal(24)
		var zone: Rect2 = MonitorItemColumn.PAYOUT_RECT
		zone.position += column.get_global_rect().position
		assert_bool(zone.grow(0.5).encloses(payout.shown_rect())).is_true()
		for text: String in column.step_texts():
			(
				assert_bool(text.begins_with("Pays") or text.contains("→"))
				. override_failure_message(text)
				. is_false()
			)
		remove_child(column)
	await get_tree().process_frame


## A harmful line (a day event's "−2€", an inspection's "= 0") prints in tomato, its text and its
## amount, with a tomato "!" mark, in the count and in planning (on one page or several); its amount
## keeps its sign. An override's "= 0" reads "0€", said once (#138 review): left out of the amount
## column when the text already says it ("pays 0€"). A good line has no mark (PR #138 monitor: no
## checkmarks), its words green for a bonus (PR #138 round 6), else teal.
func test_harmful_lines_are_tomato_and_good_lines_unmarked() -> void:
	var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
	add_child(column)
	column.reduced_motion = func() -> bool: return true
	column.start_item(MILK, PackedStringArray(["Dairy"]))
	# Each the newest row when it shows (earlier ones may fold in the rows' room).
	column.show_step("+2€ Eggs", false)
	_assert_good(column.step_rows()[-1])
	column.show_step("−2€ Dairy pays less", false, false, null, false, true)
	_assert_harmful(column.step_rows()[-1], column)
	assert_str((column.step_rows()[-1].get_node("Amount") as Label).text).is_equal("−2€")
	column.show_step("Spot check: the 3rd product pays 0€  = 0", false, false, null, false, true)
	_assert_harmful(column.step_rows()[-1], column)
	assert_object(column.step_rows()[-1].get_node_or_null("Amount")).is_null()
	column.show_step("Soup beside Frozen  = 0", false, false, null, false, true)
	_assert_harmful(column.step_rows()[-1], column)
	assert_str((column.step_rows()[-1].get_node("Amount") as Label).text).is_equal("0€")
	var lines: PackedStringArray = PackedStringArray(
		["+2€ Eggs", "−2€ Dairy pays less", "Spot check: the 3rd product pays 0€  = 0"]
	)
	var harms: Array[bool] = [false, true, true]
	for count: int in [3, 9]:
		var shown: PackedStringArray = PackedStringArray()
		var shown_harms: Array[bool] = []
		for index: int in range(count):
			shown.append(lines[index % 3])
			shown_harms.append(harms[index % 3])
		var scan: ScanController.ItemLines = ScanController.ItemLines.new()
		scan.payout = 0
		scan.lines = shown
		scan.harms = shown_harms
		column.show_item(MILK, PackedStringArray(["Dairy"]), scan)
		var rows: Array[Control] = (
			column.pages.all_rows() if column.pages != null else column.step_rows()
		)
		assert_int(rows.size()).is_equal(count)
		for index: int in range(count):
			if shown_harms[index]:
				_assert_harmful(rows[index], null)
			else:
				_assert_good(rows[index])
	remove_child(column)
	await get_tree().process_frame


func _assert_good(row: Control) -> void:
	var mark: Label = row.get_node("Mark") as Label
	assert_str(mark.text).is_empty()
	var amount: String = (row.get_node("Amount") as Label).text
	var green: bool = amount.begins_with("+") or MonitorStepRow.raises(amount)
	var words: Color = MonitorStepRow.BONUS_COLOR if green else Palette.TEAL_DARK
	assert_that(_colour(row, "Text")).is_equal(words)
	var good: Color = MonitorStepRow.BONUS_COLOR if amount.begins_with("+") else Palette.INK
	if amount.begins_with("×"):
		good = MonitorStepRow.factor_ink(MonitorStepRow.factor_step(amount))
	assert_that(_colour(row, "Amount")).is_equal(good)


## `row` is tomato with the "!" mark; inside `column` (when given), its mark left of its text and
## its text left of its amount.
func _assert_harmful(row: Control, column: Control) -> void:
	var line: String = String(row.get_meta(&"line"))
	var mark: Label = row.get_node("Mark") as Label
	assert_object(mark).override_failure_message(line).is_not_null()
	assert_str(mark.text).is_equal(MonitorItemColumn.HARM_MARK)
	assert_that(mark.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
	assert_that(mark.get_theme_color("font_color")).is_not_equal(Palette.GREEN_DARK)
	assert_that(_colour(row, "Text")).override_failure_message(line).is_equal(Palette.TOMATO_DARK)
	var has_amount: bool = row.get_node_or_null("Amount") != null
	if has_amount:
		assert_that(_colour(row, "Amount")).is_equal(Palette.TOMATO_DARK)
	if column == null:
		return
	var text: Rect2 = (row.get_node("Text") as Control).get_global_rect()
	assert_bool(column.get_global_rect().grow(0.5).encloses(row.get_global_rect())).is_true()
	assert_float(mark.get_global_rect().end.x).is_less_equal(text.position.x)
	if has_amount:
		var amount: Rect2 = (row.get_node("Amount") as Control).get_global_rect()
		assert_float(text.end.x).is_less_equal(amount.position.x)


## The register's follower keeps a tally (v0.84): bonus lines, WASTED and items paid, never the
## total the gauge shows. Its display is gone (2026-11-01): it shows nothing and has no labels.
## It follows the reading's met and clears for planning.
func test_the_register_tallies_and_clears_for_planning() -> void:
	var count: CountUp = auto_free(CountUp.new())
	var led: LedDisplay = auto_free(LedDisplay.new())
	var display: RegisterTotal = auto_free(RegisterTotal.new())
	add_child(count)
	add_child(display)
	display.follow(count, led)
	led.start_count(73)
	assert_bool(display.is_counting()).is_true()
	assert_bool(display.visible).is_false()
	assert_that(display.tally()).is_equal(Vector3i.ZERO)
	for slot: int in [0, 0, 1]:  # Two beats of item 0, then item 1.
		var beat: CountUpBeat = CountUpBeat.new()
		beat.scan_slot = slot
		count.beat_started.emit(beat, ScoreStep.new(), "", null, 2)
	assert_that(display.tally()).is_equal(Vector3i(0, 0, 2))
	led.show_subtotal(21, false)
	assert_int(display.amount()).is_equal(21)
	assert_bool(display.is_met()).is_false()
	led.show_subtotal(170, true)
	assert_bool(display.is_met()).is_true()
	assert_int(display.find_children("*", "Label", true, false).size()).is_equal(0)
	led.clear()
	assert_bool(display.is_counting()).is_false()
	assert_that(display.tally()).is_equal(Vector3i.ZERO)


## The drawer throws one coin per 8€ of a payout, at least one and at most five (v0.84).
func test_the_drawer_throws_one_to_five_coins() -> void:
	assert_int(CashDrawer.coins_for(1)).is_equal(1)
	assert_int(CashDrawer.coins_for(8)).is_equal(1)
	assert_int(CashDrawer.coins_for(9)).is_equal(2)
	assert_int(CashDrawer.coins_for(19)).is_equal(3)
	assert_int(CashDrawer.coins_for(40)).is_equal(5)
	assert_int(CashDrawer.coins_for(400)).is_equal(5)


static func _colour(row: Control, part: String) -> Color:
	return (row.get_node(part) as Label).get_theme_color("font_color")


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
