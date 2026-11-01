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
	column.show_step("Banana chain  +€3", false, false, giver_icon, true)
	column.show_step("Produce regulars  +€2", false)
	column.show_step("Produce aisle run  ×3", false)
	column.show_step("Multipack  ×3", false)
	assert_int(column.step_texts().size()).is_equal(4)
	assert_bool(column.step_rows()[0].get_meta(&"from_bag")).is_true()
	# The note after the giver's words: smaller, teal, on the same line, after the text.
	var text: Label = column.step_rows()[0].get_node("Text") as Label
	var note: Label = column.step_rows()[0].get_node("FromBag") as Label
	assert_str(note.text).contains("from the bag")
	assert_that(note.get_theme_color("font_color")).is_equal(Palette.TEAL_DARK)
	assert_that(text.get_theme_color("font_color")).is_equal(Palette.TEAL_DARK)
	assert_float(note.get_global_rect().position.x).is_greater_equal(text.get_global_rect().end.x)
	var amount: Label = column.step_rows()[0].get_node("Amount") as Label
	assert_float(note.get_global_rect().end.x).is_less_equal(amount.get_global_rect().position.x)
	column.show_step("Slot engine  ×2", false)
	assert_int(column.step_texts().size()).is_equal(5)
	column.show_step("Pays  €126", false)
	assert_int(column.step_texts().size()).is_equal(5)
	assert_str(column.step_texts()[0]).is_equal("+2 earlier")
	assert_str(column.step_texts()[-1]).is_equal("Pays  €126")
	for row: Control in column.step_rows():
		(
			assert_bool(
				Rect2(Vector2.ZERO, column.size).encloses(
					Rect2(row.position + Vector2(0, MonitorItemColumn.COUNT_STEPS_TOP), row.size)
				)
			)
			. is_true()
		)

	await get_tree().process_frame
	await get_tree().process_frame


## The count's lines keep every maths symbol: a multiplier reads "× Multipack" with its amber
## "×3"; a + amount is ink; the giver's words are teal. At the payout the equation comes under
## them as one line, "€4 × 6 → €24": its factor amber, the rest ink, every part inside its row
## and the column, apart; a payment with none reads "Pays" in ink. Reduced motion or not.
func test_multipliers_keep_their_symbol_and_the_payout_shows_its_equation() -> void:
	for reduced: bool in [false, true]:
		var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
		add_child(column)
		column.reduced_motion = func() -> bool: return reduced
		column.start_item(MILK, PackedStringArray(["Dairy"]))
		column.show_step("+€2 Eggs", false)
		column.show_step("×3 Multipack", false)
		column.show_step("×2 Golden Strawberries aisle", false)
		var add: Control = column.step_rows()[0]
		assert_str((add.get_node("Text") as Label).text).is_equal("Eggs")
		assert_that(_colour(add, "Amount")).is_equal(Palette.INK)
		assert_that(_colour(add, "Text")).is_equal(Palette.TEAL_DARK)
		for row: Control in column.step_rows().slice(1):
			var text: Label = row.get_node("Text") as Label
			assert_str(text.text).starts_with("× ")
			assert_that(_colour(row, "Amount")).is_equal(Palette.MUSTARD_DARKEST)
			assert_int(text.get_line_count()).is_less_equal(text.max_lines_visible)
			assert_float(text.get_global_rect().end.x).is_less_equal(
				(row.get_node("Amount") as Label).get_global_rect().position.x
			)
		assert_str((column.step_rows()[1].get_node("Text") as Label).text).is_equal("× Multipack")
		column.show_paid("Pays  €24", PaymentEquation.new(4, 6, 24))
		var rows: Array[Control] = column.step_rows()
		assert_int(rows.size()).is_equal(4)
		var equation: Control = rows[-1]
		var arrow: String = MonitorItemColumn._arrow()
		assert_str(String(equation.get_meta(&"line"))).is_equal("€4 × 6 %s €24" % arrow)
		assert_str((equation.get_node("Factor") as Label).text).is_equal("× 6")
		assert_that(_colour(equation, "Factor")).is_equal(Palette.MUSTARD_DARKEST)
		assert_that(_colour(equation, "Text")).is_equal(Palette.INK)
		assert_that(_colour(equation, "Amount")).is_equal(Palette.INK)
		assert_str((equation.get_node("Amount") as Label).text).is_equal("€24")
		var area: Rect2 = column.get_global_rect()
		var rect: Rect2 = equation.get_global_rect()
		assert_bool(area.grow(0.5).encloses(rect)).is_true()
		assert_float(rect.size.y).is_equal(MonitorItemColumn.EQUATION_HEIGHT)
		assert_float(rows[-2].get_global_rect().end.y).is_less_equal(rect.position.y + 0.5)
		var right: float = rect.position.x
		for part_name: String in ["Text", "Factor", "Arrow", "Amount"]:
			var part: Rect2 = (equation.get_node(part_name) as Control).get_global_rect()
			assert_bool(rect.grow(0.5).encloses(part)).override_failure_message(part_name).is_true()
			assert_float(part.position.x).is_greater_equal(right)
			right = part.end.x
		column.start_item(MILK, PackedStringArray(["Dairy"]))
		column.show_step("+€2 Eggs", false)
		column.show_paid("Pays  €5")
		var pays: Control = column.step_rows()[-1]
		assert_bool(pays.has_meta(&"equation")).is_false()
		assert_that(_colour(pays, "Text")).is_equal(Palette.INK)
		assert_that(_colour(pays, "Amount")).is_equal(Palette.INK)
		remove_child(column)
	await get_tree().process_frame


## The register's display is a tally (v0.84): bonus lines, WASTED and items paid, never the total
## the gauge shows. It follows the reading's met (its gold frame) and clears for planning.
func test_the_register_tallies_and_clears_for_planning() -> void:
	var count: CountUp = auto_free(CountUp.new())
	var led: LedDisplay = auto_free(LedDisplay.new())
	var display: RegisterTotal = auto_free(RegisterTotal.new())
	add_child(count)
	add_child(display)
	display.follow(count, led)
	led.start_count(73)
	assert_bool(display.visible).is_true()
	assert_that(display.tally()).is_equal(Vector3i.ZERO)
	for slot: int in [0, 0, 1]:  # Two beats of item 0, then item 1.
		var beat: CountUpBeat = CountUpBeat.new()
		beat.scan_slot = slot
		count.beat_started.emit(beat, ScoreStep.new(), "", null, 2)
	assert_that(display.tally()).is_equal(Vector3i(0, 0, 2))
	assert_str(display.number_label().text).is_equal("2/2")
	led.show_subtotal(21, false)
	assert_int(display.amount()).is_equal(21)
	assert_bool(display.is_met()).is_false()
	led.show_subtotal(170, true)
	assert_bool(display.is_met()).is_true()
	for label: Node in display.find_children("*", "Label", true, false):
		assert_str((label as Label).text).not_contains("€")
	led.clear()
	assert_bool(display.visible).is_false()
	assert_that(display.tally()).is_equal(Vector3i.ZERO)


## The drawer throws one coin per €8 of a payout, at least one and at most five (v0.84).
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
