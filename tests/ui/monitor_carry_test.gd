extends GdUnitTestSuite
## v1.15, the user's request of 2026-11-07: "Fix the missing subtotal across pages. Page 2/2 shows a
## 6€ base, then ×2, ×4 and ×5, ending at 1160€. Those visible steps read like 240€. If this page
## starts from the earlier subtotal, show 29€ carried forward instead of repeating base price
## there, assuming the scoring steps confirm that subtotal. Make the page affordance discoverable
## enough that 2/2 isn't the only clue." A later page of the item column's rows starts with the
## carried line, its amount the score's running value before the page (ScoreStep.value_after,
## ScanController.ItemLines.runs), so every page's visible math reproduces the next page's start
## and the payout; the page cue (MonitorPager) sits on the total's line, inside the monitor and
## clear of everything, at 1280x720's scale and 1920x1080's; the count's fold ("Carried forward
## (N steps)") carries the same value. Saves and logs go to a temporary folder.

const MonitorParts := preload("res://tests/ui/monitor_parts.gd")
const CARDS := "res://data/cards/%s.tres"
const UPGRADES := "res://data/upgrades/%s.tres"
const INSPECTIONS := "res://data/inspections/%s.tres"
## The user's case (capture case "carry"): Golden Milk 6€ +8 +12 +3 = 29€, then ×2 ×4 ×5 = 1160€.
const USERS_ROW: Array[String] = [
	"eggs", "milk", "milk", "milk_golden", "two_for_one", "milk_golden"
]
const USERS_UPGRADES: Array[String] = [
	"category_engine_lv2", "dairy_regulars", "dairy_aisle_run_lv2", "breakfast_aisle_run_lv3"
]
## Paged items of the capture's cases: [row, upgrades, inspection ("" none), slot scanned].
const PAGED_CASES: Array[Array] = [
	[USERS_ROW, USERS_UPGRADES, "", 5],
	[
		["strawberries", "banana", "two_for_one", "banana"],
		["coupon_engine", "slot_engine", "category_engine"],
		"",
		3
	],
	[
		[
			"banana_golden",
			"lemon_golden",
			"banana_golden",
			"lemon_golden",
			"banana_golden",
			"lemon_golden",
			"banana_golden"
		],
		["produce_aisle_run_lv3", "lemon_squeezer", "banana_stand"],
		"",
		6
	],
]
## The windows (the stage stretched 1x and 1.5x).
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_monitor_carry_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().root.size = WINDOWS[0]
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The user's case: page 1 shows the base price and the bonuses (6 +8 +12 +3), page 2 starts
## "Carried forward 29€" (the score's value_after of Dairy regulars, the step before 2 for 1),
## never the base price, and its ×2 ×4 ×5 reproduce the payout, 1160€.
func test_the_users_page_two_starts_from_the_carried_subtotal() -> void:
	var scored: Array = _scored(USERS_ROW, USERS_UPGRADES, "", 5)
	var result: ScoreResult = scored[0]
	var lines: ScanController.ItemLines = scored[1]
	assert_int(result.payouts[5]).is_equal(1160)
	# Each line's run is its step's value_after (moving steps only).
	var steps: Array[ScoreStep] = ScanController.footer_steps(result, 5)
	assert_int(lines.runs.size()).is_equal(lines.lines.size())
	for index: int in range(steps.size()):
		assert_int(lines.runs[lines.gives + index]).is_equal(
			ScanController.running_value(steps[index])
		)
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var definition: CardDefinition = _card("milk_golden")
	monitor.show_scan(definition, result.tags[5], lines)
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	assert_int(pages.count()).is_equal(2)
	assert_str(String(pages.head().get_meta(&"line"))).is_equal("Base price 6€")
	pages.turn(1)
	await _frames(1)
	var head: Control = pages.head()
	assert_str(String(head.name)).is_equal("CarryLine")
	assert_int(int(head.get_meta(&"carried"))).is_equal(29)
	assert_str(String(head.get_meta(&"line"))).is_equal("Carried forward 29€")
	assert_str((head.get_node("Amount") as Label).text).is_equal("29€")
	assert_bool(head.is_visible_in_tree()).is_true()
	# The score's own running value before page 2's first step (2 for 1): the step before it.
	var first: int = result.steps.find(steps[3])
	assert_str(result.steps[first].text).contains("2 for 1")
	assert_int(_value_before(result, first)).is_equal(29)
	# Page 2's visible steps reproduce the total from the carried value; no base price there.
	assert_int(_visible_end(29, column.step_rows())).is_equal(1160)
	assert_object(column.base_line()).is_not_null()
	assert_bool(column.base_line().is_visible_in_tree()).is_false()
	for row: Control in column.step_rows():
		assert_str(String(row.get_meta(&"line"))).not_contains(MonitorBaseLine.CAPTION)
	assert_array(MonitorParts.problems(column)).is_empty()


## Every paged item of the capture's cases: each page's head shows the value the pages before it
## reached (the base price on the first page, or on a page before which nothing moved), and the
## visible amounts of every page, applied from its head, give the next page's head and, on the last
## page, the score's payout. The head's amount is the score's value before the page's first
## moving step.
func test_every_page_starts_where_the_page_before_ended() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	for case: Array in PAGED_CASES:
		var slot: int = case[3]
		var scored: Array = _scored(case[0], case[1], case[2], slot)
		var result: ScoreResult = scored[0]
		var definition: CardDefinition = _card(case[0][slot])
		monitor.show_scan(definition, result.tags[slot], scored[1])
		await _frames(1)
		var pages: MonitorStepPages = column.pages
		var where: String = "%s slot %d" % [case[0], slot]
		assert_int(pages.count()).override_failure_message(where).is_greater(1)
		var moving: Array[ScoreStep] = []
		for step: ScoreStep in ScanController.footer_steps(result, slot):
			if ScanController.running_value(step) >= 0:
				moving.append(step)
		var shown: int = 0
		var reached: int = -1
		for page: int in range(pages.count()):
			while pages.page() != page:
				pages.turn(1)
			await _frames(1)
			var message: String = "%s page %d" % [where, page + 1]
			var head: Control = pages.head()
			assert_object(head).override_failure_message(message).is_not_null()
			var start: int = _amount_of(head)
			if page == 0 or shown == 0:
				assert_str(String(head.name)).override_failure_message(message).is_equal("BaseLine")
				assert_int(start).override_failure_message(message).is_equal(definition.base)
			else:
				assert_str(String(head.name)).override_failure_message(message).is_equal(
					"CarryLine"
				)
				assert_int(start).override_failure_message(message).is_equal(reached)
				# The score's own value before the page's first moving step.
				if shown < moving.size():
					var score_before: int = _value_before(result, result.steps.find(moving[shown]))
					assert_int(start).override_failure_message(message).is_equal(score_before)
			reached = _visible_end(start, column.step_rows())
			# The cue's subtotal: where this page's visible maths ends, before the last page.
			var subtotal: Label = pages.pager().subtotal()
			if page < pages.count() - 1 and subtotal.visible:
				assert_str(subtotal.text).override_failure_message(message).is_equal(
					MonitorText.euros(reached)
				)
			assert_bool(column.payout_view().equals_muted()).is_equal(page < pages.count() - 1)
			for row: Control in column.step_rows():
				if int(row.get_meta(MonitorCarry.RUN, -1)) >= 0:
					shown += 1
			assert_array(MonitorParts.problems(column)).override_failure_message(message).is_empty()
		assert_int(reached).override_failure_message(where).is_equal(result.payouts[slot])


## A page before which no row moved the item's amount starts at the base price legitimately (its
## own math starts there): a "gives" row on page 1 carries nothing.
func test_a_page_with_nothing_moved_before_it_keeps_the_base_price() -> void:
	var paged: Array[Array] = [[_row_with_run(-1), _row_with_run(-1)], [_row_with_run(12)]]
	assert_int(MonitorCarry.carried_before(paged, 1)).is_equal(-1)
	var base: Control = auto_free(MonitorBaseLine.make(4, 264.0))
	var heads: Array[Control] = MonitorCarry.heads(paged, base, 4, 264.0)
	assert_str(String(heads[1].name)).is_equal("BaseLine")
	heads[1].free()
	paged.append([_row_with_run(-1)])
	heads = MonitorCarry.heads(paged, base, 4, 264.0)
	assert_str(String(heads[2].name)).is_equal("CarryLine")
	assert_int(int(heads[2].get_meta(&"carried"))).is_equal(12)
	for head: Control in heads.slice(1):
		head.free()
	for page: Array in paged:
		for row: Variant in page:
			(row as Control).free()


## Page 1's cue ends its visible maths on the score's subtotal ("29€ · MORE", 6 +8 +12 +3), its
## "=" muted so the total does not read as the result of those rows; the last page's cue reads
## FIRST with no subtotal and its "=" in ink.
func test_the_cue_shows_the_pages_subtotal_before_the_total() -> void:
	var scored: Array = _scored(USERS_ROW, USERS_UPGRADES, "", 5)
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	monitor.show_scan(_card("milk_golden"), scored[0].tags[5], scored[1])
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	var cue: MonitorPager = pages.pager()
	assert_bool(cue.subtotal().is_visible_in_tree()).is_true()
	assert_str(cue.subtotal().text).is_equal("29€")
	assert_int(_visible_end(6, column.step_rows())).is_equal(29)
	assert_str(cue.word().text).is_equal(MonitorPager.WORD_MORE)
	assert_bool(column.payout_view().equals_muted()).is_true()
	var equals: Label = column.payout_view().equals()
	assert_object(equals.get_theme_color("font_color")).is_equal(MonitorPayout.EQUALS_MUTED)
	pages.turn(1)
	await _frames(1)
	assert_bool(cue.subtotal().visible).is_false()
	assert_str(cue.word().text).is_equal(MonitorPager.WORD_FIRST)
	assert_bool(column.payout_view().equals_muted()).is_false()
	assert_object(equals.get_theme_color("font_color")).is_equal(Palette.INK)
	# A one-page item's "=" stays in ink.
	monitor.show_scan(_card("milk"), _card("milk").tags, _bonus_lines(4, 2))
	await _frames(1)
	assert_object(column.pages.pager()).is_null()
	assert_bool(column.payout_view().equals_muted()).is_false()


## A coupon (Repeat: its own payout moves step by step, COPY then factors) has no base line, so a
## later page carries inline: its first row the carried line, the rows under it, inside the rows'
## area, the value the rows before it reached.
func test_a_coupons_later_page_carries_inline() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var repeat: CardDefinition = _card("repeat")
	monitor.show_scan(repeat, repeat.tags, _bonus_lines(4, 9))
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	assert_int(pages.count()).is_greater(1)
	assert_object(column.base_line()).is_null()
	assert_object(pages.head()).is_null()
	var reached: int = _visible_end(4, column.step_rows())
	for page: int in range(1, pages.count()):
		pages.turn(1)
		await _frames(1)
		var message: String = "Repeat page %d" % (page + 1)
		var head: Control = pages.head()
		assert_object(head).override_failure_message(message).is_not_null()
		assert_str(String(head.name)).is_equal("CarryLine")
		assert_bool(bool(head.get_meta(MonitorCarry.INLINE, false))).is_true()
		assert_int(_amount_of(head)).override_failure_message(message).is_equal(reached)
		assert_float(head.position.y).is_equal(0.0)
		for row: Control in column.step_rows():
			assert_float(row.position.y).is_greater_equal(MonitorStepRow.ROW_PITCH - 0.5)
		assert_array(MonitorParts.problems(column)).override_failure_message(message).is_empty()
		reached = _visible_end(reached, column.step_rows())
	# 4 +1 +2 ... +9.
	assert_int(reached).is_equal(49)


## A later page of "gives" rows only (rows that change other items) has no head: a carried value
## over them would read as adding to them.
func test_a_page_of_gives_rows_only_has_no_head() -> void:
	var gives: Control = _row_with_run(-1)
	gives.set_meta(MonitorCarry.GIVES, true)
	var paged: Array[Array] = [[_row_with_run(9)], [gives]]
	var base: Control = auto_free(MonitorBaseLine.make(4, 264.0))
	var heads: Array[Control] = MonitorCarry.heads(paged, base, 4, 264.0)
	assert_int(heads.size()).is_equal(2)
	assert_object(heads[1]).is_null()
	assert_int(MonitorCarry.subtotals(paged)[0]).is_equal(9)
	for page: Array in paged:
		for row: Variant in page:
			(row as Control).free()


## A huge payout on 4 pages or more at both resolutions: the total keeps clear of the cue (its
## shorter forms, the cue compact when it must), nothing overlaps.
func test_a_huge_payout_keeps_clear_of_the_cue() -> void:
	for window: Vector2i in WINDOWS:
		get_tree().root.size = window
		var monitor: MonitorView = await _monitor()
		var column: MonitorItemColumn = monitor.item_column()
		for payout: int in [1234567, 12345678, 99999999]:
			var lines: ScanController.ItemLines = _bonus_lines(4, 14)
			lines.payout = payout
			monitor.show_scan(_card("milk"), _card("milk").tags, lines)
			await _frames(1)
			var pages: MonitorStepPages = column.pages
			var message: String = "%s %d€" % [window, payout]
			assert_int(pages.count()).override_failure_message(message).is_greater_equal(4)
			for page: int in range(pages.count()):
				while pages.page() != page:
					pages.turn(1)
				await _frames(1)
				var parts: Dictionary[String, Rect2] = column.part_rects()
				var cue: Rect2 = parts["page_cue"]
				for part: String in ["payout_equals", "payout_digits", "payout_shadow"]:
					if parts.has(part):
						var said: String = "%s p%d: %s over %s" % [message, page + 1, cue, part]
						assert_float(cue.end.x).override_failure_message(said).is_less(
							parts[part].position.x
						)
				(
					assert_array(MonitorParts.problems(column))
					. override_failure_message(message)
					. is_empty()
				)


## The page cue at 1280x720's scale and 1920x1080's: on every page of a paged item, visible on the
## total's line at the payout zone's left, inside the column's frame and the monitor, clear of the
## rows' area, the total and every other part; one pip a page, the page shown filled; MORE while a
## page follows, BACK on the last. A one-page item shows no cue.
func test_the_page_cue_fits_beside_the_total_at_both_resolutions() -> void:
	var scored: Array = _scored(USERS_ROW, USERS_UPGRADES, "", 5)
	var result: ScoreResult = scored[0]
	for window: Vector2i in WINDOWS:
		get_tree().root.size = window
		var monitor: MonitorView = await _monitor()
		var stretch: float = get_tree().root.get_final_transform().get_scale().y
		assert_float(stretch).is_equal_approx(window.y / 720.0, 0.001)
		var column: MonitorItemColumn = monitor.item_column()
		monitor.show_scan(_card("milk_golden"), result.tags[5], scored[1])
		await _frames(2)
		var pages: MonitorStepPages = column.pages
		var cue: MonitorPager = pages.pager()
		for page: int in range(pages.count()):
			while pages.page() != page:
				pages.turn(1)
			await _frames(1)
			var message: String = "%s page %d" % [window, page + 1]
			assert_bool(cue.is_visible_in_tree()).override_failure_message(message).is_true()
			assert_int(cue.count()).is_equal(pages.count())
			assert_int(cue.page()).is_equal(page)
			var word: String = MonitorPager.WORD_FIRST if page == 1 else MonitorPager.WORD_MORE
			assert_str(cue.word().text).override_failure_message(message).is_equal(word)
			var parts: Dictionary[String, Rect2] = column.part_rects()
			var rect: Rect2 = parts["page_cue"]
			assert_float(rect.size.y).is_equal_approx(MonitorPager.HEIGHT, 0.01)
			# On the screen: whole pixels tall at 1x, 1.5x of its height at 1080p, on the screen.
			var on_screen: Rect2 = get_tree().root.get_final_transform() * rect
			assert_float(on_screen.size.y).is_equal_approx(MonitorPager.HEIGHT * stretch, 0.01)
			assert_bool(Rect2(Vector2.ZERO, Vector2(window)).encloses(on_screen)).is_true()
			(
				assert_bool(parts["footer"].grow(0.5).encloses(rect))
				. override_failure_message("%s: %s outside %s" % [message, rect, parts["footer"]])
				. is_true()
			)
			assert_bool(monitor.get_global_rect().encloses(rect)).is_true()
			assert_bool(rect.intersects(parts["rows"])).override_failure_message(message).is_false()
			for part: String in ["payout", "payout_equals", "payout_digits", "payout_shadow"]:
				if parts.has(part):
					assert_float(rect.end.x).override_failure_message(message).is_less(
						parts[part].position.x
					)
			# Its foot on the total's digits' foot.
			assert_float(rect.end.y).is_equal_approx(parts["payout_digits"].end.y, 0.5)
			assert_array(MonitorParts.problems(column)).override_failure_message(message).is_empty()
		var one: ScanController.ItemLines = ScanController.ItemLines.new()
		one.payout = 9
		one.lines = PackedStringArray(["+3€ Eggs before it"])
		one.fizzles = [false]
		one.runs = PackedInt32Array([9])
		monitor.show_scan(_card("milk"), _card("milk").tags, one)
		await _frames(1)
		assert_int(column.pages.count()).is_equal(1)
		assert_object(column.pages.pager()).is_null()
		assert_bool(column.part_rects().has("page_cue")).is_false()
		assert_bool(column.part_rects().has("carry")).is_false()
		assert_object(column.pages.head()).is_null()


## The cue is a button: the pointing hand over it, a click turns to the next page (wrapping) and
## goes no further; it lights while the pointer is on the monitor (the pages held), brighter under
## the pointer. The wheel still turns the pages over it.
func test_the_cue_turns_the_page_on_a_click_and_lights_while_held() -> void:
	var scored: Array = _scored(USERS_ROW, USERS_UPGRADES, "", 5)
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	monitor.show_scan(_card("milk_golden"), scored[0].tags[5], scored[1])
	await _frames(2)
	var pages: MonitorStepPages = column.pages
	var cue: MonitorPager = pages.pager()
	assert_int(cue.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	assert_bool(cue.lit).is_false()
	var at: Vector2 = cue.get_global_rect().get_center()
	_move(at)
	await _frames(2)
	assert_bool(pages.is_held()).is_true()
	assert_bool(cue.lit).is_true()
	assert_bool(cue.is_hot()).is_true()
	_click(at)
	await _frames(1)
	assert_int(pages.page()).is_equal(1)
	assert_str(cue.word().text).is_equal(MonitorPager.WORD_FIRST)
	_click(at)
	await _frames(1)
	assert_int(pages.page()).is_equal(0)
	_wheel(at, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(1)
	assert_int(pages.page()).is_equal(1)
	_move(Vector2(4, 4))
	await _frames(2)
	assert_bool(cue.lit).is_false()


## Under reduced motion a turn shows the page at once, in place (no slide, no fade) and the cue's
## chevron rests (no nudge); otherwise the page slides in from SLIDE px inside the frame.
func test_reduced_motion_turns_in_place() -> void:
	var scored: Array = _scored(USERS_ROW, USERS_UPGRADES, "", 5)
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	monitor.show_scan(_card("milk_golden"), scored[0].tags[5], scored[1])
	await _frames(1)
	var pages: MonitorStepPages = column.pages
	pages.turn(1)
	var shown: Control = pages.head().get_parent() as Control
	assert_vector(shown.position).is_equal(Vector2.ZERO)
	assert_float(shown.modulate.a).is_equal(1.0)
	assert_float(pages.pager().nudge).is_equal(0.0)
	monitor.reduced_motion = Callable()
	monitor.show_scan(_card("milk"), _card("milk").tags, ScanController.ItemLines.new())
	await _frames(1)
	monitor.show_scan(_card("milk_golden"), scored[0].tags[5], scored[1])
	await _frames(1)
	pages = column.pages
	pages.turn(1)
	shown = pages.head().get_parent() as Control
	assert_float(shown.position.x).is_equal(MonitorStepPages.SLIDE)
	await _seconds(0.5)
	assert_vector(shown.position).is_equal(Vector2.ZERO)


## A copied item's quiet note moves right of the cue on the total's line, clear of it and of the
## total.
func test_the_copied_note_sits_right_of_the_cue() -> void:
	get_tree().root.size = WINDOWS[1]
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = 40
	lines.copied_by = MonitorText.copied_by("Repeat")
	var value: int = 4
	for index: int in range(8):
		value += index + 1
		lines.lines.append("+%d€ Bonus %d" % [index + 1, index])
		lines.fizzles.append(false)
		lines.runs.append(value)
	lines.payout = value
	monitor.show_scan(_card("milk"), _card("milk").tags, lines)
	await _frames(2)
	var parts: Dictionary[String, Rect2] = column.part_rects()
	assert_bool(parts.has("payout_note")).is_true()
	assert_bool(parts["page_cue"].intersects(parts["payout_note"])).is_false()
	assert_float(parts["payout_note"].position.x).is_greater(parts["page_cue"].end.x)
	assert_array(MonitorParts.problems(column)).is_empty()


## The count's "Carried forward (N steps)" fold carries the running value after the rows it folds
## (the score's value_after, passed with each line), in the amount column; with none moved, its
## caption alone.
func test_the_counts_fold_carries_the_running_value() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	column.start_item(_card("milk_golden"), _card("milk_golden").tags, false)
	var runs: Array[int] = [14, 26, 29, 58, 232, 1160]
	for index: int in range(runs.size()):
		column.show_step("+1€ Step %d" % index, false, false, null, false, false, "", runs[index])
	await _frames(1)
	var folded: Control = column.step_rows()[0]
	assert_str(String(folded.name)).is_equal("Folded")
	var count: int = runs.size() - (column.step_rows().size() - 1)
	assert_str(String(folded.get_meta(&"line"))).is_equal(MonitorCarry.fold_caption(count))
	assert_int(int(folded.get_meta(&"carried"))).is_equal(runs[count - 1])
	assert_str((folded.get_node("Amount") as Label).text).is_equal(
		MonitorText.euros(runs[count - 1])
	)
	column.start_item(_card("milk_golden"), _card("milk_golden").tags, false)
	for index: int in range(runs.size()):
		column.show_step("Wasted %d  WASTED" % index, true)
	await _frames(1)
	folded = column.step_rows()[0]
	assert_object(folded.get_node_or_null("Amount")).is_null()


## `row` scored with `upgrade_ids` under `inspection` ("" none): [its ScoreResult, the scan's lines
## of `slot` (ScanController.item_lines)].
func _scored(row_ids: Array, upgrade_ids: Array, inspection: String, slot: int) -> Array:
	var row: Array[CardInstance] = []
	for index: int in range(row_ids.size()):
		row.append(CardInstance.new(_card(row_ids[index]), index + 1))
	var upgrades: Array[UpgradeDefinition] = []
	var upgrade_names: PackedStringArray = PackedStringArray()
	for upgrade_id: String in upgrade_ids:
		var upgrade: UpgradeDefinition = load(UPGRADES % upgrade_id) as UpgradeDefinition
		upgrades.append(upgrade)
		upgrade_names.append(upgrade.display_name)
	var events: Array[InspectionDefinition] = []
	var event_names: PackedStringArray = PackedStringArray()
	if not inspection.is_empty():
		var event: InspectionDefinition = load(INSPECTIONS % inspection) as InspectionDefinition
		events.append(event)
		event_names.append(event.display_name)
	var result: ScoreResult = Scoring.score(row, upgrades, events)
	var scan: ScanController = auto_free(ScanController.new())
	scan.set_result(result, CardInstance.names(row), upgrade_names, event_names)
	return [result, scan.item_lines(slot)]


## The running value of `index`'s slot before that step: the value_after of the slot's last
## value step (BASE or a moving one) before it, as the score wrote it.
static func _value_before(result: ScoreResult, index: int) -> int:
	var slot: int = result.steps[index].slot
	for earlier: int in range(index - 1, -1, -1):
		var step: ScoreStep = result.steps[earlier]
		if step.slot != slot:
			continue
		if step.step_type == ScoreStep.StepType.BASE or ScanController.running_value(step) >= 0:
			return step.value_after
	return -1


## `start` with the visible amounts of `rows` applied in order (the rows that move the item's own
## amount: "+N€", "−N€", "×N"; others left out), as a player reads them.
static func _visible_end(start: int, rows: Array[Control]) -> int:
	var value: int = start
	for row: Control in rows:
		if int(row.get_meta(MonitorCarry.RUN, -1)) < 0:
			continue
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount == null:
			# An override row ("slot 3 pays 0€ = 0") prints its result in its text.
			var said: String = String(row.get_meta(&"line", ""))
			value = said.get_slice("=", said.get_slice_count("=") - 1).strip_edges().to_int()
			continue
		var text: String = amount.text.strip_edges()
		if text.begins_with(MonitorStepRow.FACTOR_SIGN):
			var factor: float = text.substr(MonitorStepRow.FACTOR_SIGN.length()).to_float()
			value = ScoreStep.times_percent(value, roundi(factor * 100.0))
		elif text.begins_with("="):
			value = text.substr(1).trim_suffix(MonitorStepRow.EURO).to_int()
		else:
			var direction: int = -1 if text.begins_with("−") or text.begins_with("-") else 1
			value += direction * text.substr(1).trim_suffix(MonitorStepRow.EURO).to_int()
	return value


## A head's amount ("29€" → 29).
static func _amount_of(head: Control) -> int:
	var amount: Label = head.get_node("Amount") as Label
	return amount.text.trim_suffix(MonitorStepRow.EURO).to_int()


## `count` bonus lines "+N€" (N from 1) from `base`, each with its running value; the payout the
## last one.
static func _bonus_lines(base: int, count: int) -> ScanController.ItemLines:
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	var value: int = base
	for index: int in range(count):
		value += index + 1
		lines.lines.append("+%d€ Bonus %d" % [index + 1, index])
		lines.fizzles.append(false)
		lines.runs.append(value)
	lines.payout = value
	return lines


static func _row_with_run(run: int) -> Control:
	var row: Control = Control.new()
	row.set_meta(MonitorCarry.RUN, run)
	return row


static func _card(card_id: String) -> CardDefinition:
	return load(CARDS % card_id) as CardDefinition


## A monitor alone at its stage place, over a control as big as the screen, under reduced motion.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	holder.size = get_tree().root.get_visible_rect().size
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	# The pages turn at once (no slide, no fade), so a check reads the page shown at rest.
	monitor.reduced_motion = func() -> bool: return true
	holder.add_child(monitor)
	_move(Vector2(4, 4))
	await _frames(1)
	return monitor


func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_tree().root.push_input(motion, true)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_tree().root.push_input(event, true)


func _wheel(at: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.factor = 1.0
		event.position = at
		event.global_position = at
		get_tree().root.push_input(event, true)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
