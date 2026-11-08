extends GdUnitTestSuite
## The single monitor screen's geometry (#105 piece 2, mock-up readability_v3.html, monitor b),
## read back from the drawn controls on a monitor at its stage place. The checkout column for
## totals of one to four digits, in planning, in the count (the number at rest and at a ×'s full
## punch, the gain box) and at a met end: every part inside the column and the paper, the number
## at rest clear of the divider (punched it runs into the column's clip at the paper's edge for a
## moment, as the mock-up's), the TOTAL caption 4 px clear of the digits at the full punch, and
## the caption, the number, the ladder, the SPEND line, the status line (or the gain box), the
## stamp and the tab apart. The item column's layout for every case of PR #138's brief
## (MonitorParts) and its overflow. The scans of every
## card are in monitor_view_test; the count's timing and sync in monitor_count_sync_test.

const MonitorParts := preload("res://tests/ui/monitor_parts.gd")
const CARDS := "res://data/cards"
## (quota, total) pairs: one to four digits, under and over the quota.
const CASES: Array[Vector2i] = [
	Vector2i(26, 8),
	Vector2i(26, 21),
	Vector2i(73, 80),
	Vector2i(73, 143),
	Vector2i(300, 999),
	Vector2i(1500, 1234),
	Vector2i(9000, 9999),
]
## The digits' clearance under the TOTAL caption at the full punch (the mock-up's 4 px).
const CAPTION_CLEAR := 4.0
## The item column's cases (PR #138 monitor brief): [name, card, payout (-1 in the hand), its
## lines as [line, fizzle, harmful]].
const ITEM_CASES: Array[Array] = [
	["plain", "bread", 3, []],
	["families", "stale_popcorn", 4, [["+2€ Crisps after it", false, false]]],
	["split", "breakfast_sticker", 0, []],
	["long", "lemon", 6, [["+3€ Banana before it", false, false]]],
	[
		"bonuses",
		"banana",
		14,
		[
			["+2€ Strawberries before it", false, false],
			["+3€ Banana's price", false, false],
			["× 2 for 1  ×2", false, false],
		]
	],
	[
		"large",
		"banana_golden",
		5180,
		[
			["+12€ Produce aisle run", false, false],
			["× Banana stand  ×5", false, false],
			["× Lemon squeezer  ×4", false, false],
		]
	],
	["coupon", "two_for_one", 0, [["× Banana after it  ×2", false, false]]],
	["zero", "milk", 0, [["Spot check: 0€", false, true]]],
	["penalty", "soup", 1, [["-2€ Frozen peas after it", false, true]]],
	["unused", "eggs", 2, [["+1€ No Batteries after it", true, false]]],
	[
		"paged",
		"milk",
		21,
		[
			["+1€ Eggs before it", false, false],
			["+2€ Bread before it", false, false],
			["× Multipack  ×3", false, false],
			["+1€ Milk before it", false, false],
			["+1€ Milk after it", false, false],
			["+1€ Milk two after it", false, false],
		]
	],
	["hand", "coffee", -1, []],
]
## A boosted payout's shadow may sit a cell right of the digits.
const ITEM_PAYOUT_SHADOW := MonitorPayout.CELL
## PR #138 round 2: the item column's frame at most FRAME_MARGIN px from the paper's top, right and
## bottom edges; a keyword chip's word at least CHIP_PADDING px inside its box each side and the
## chip at least CHIP_GAP px clear of the text after it; a common item's three rows on one page.
const FRAME_MARGIN := 2.0
const CHIP_PADDING := 5.0
const CHIP_GAP := 3.0
## How far (a hue turn, 15°) an untagged factor ink keeps from the harmful tomato's hue.
const HARM_HUE_APART := 15.0 / 360.0
## PR #138 round 6: the payout's digits (and shadow) at most PAYOUT_FOOT_MARGIN px over the
## frame's inside foot (low in the column, under the rows, not floating), and its zone at least
## PAYOUT_ROWS_GAP px under the rows' area.
const PAYOUT_FOOT_MARGIN := 8.0
const PAYOUT_ROWS_GAP := 2.0
## Each case's description as round 4 showed it: (pitch, lines) of its tier (MonitorItemColumn's
## EFFECT_TIERS; (-1, -1): no description).
const ROUND_4_BANDS: Dictionary[String, Vector2i] = {
	"plain": Vector2i(-1, -1),
	"families": Vector2i(17, 2),
	"split": Vector2i(17, 2),
	"long": Vector2i(15, 3),
	"bonuses": Vector2i(16, 2),
	"large": Vector2i(15, 2),
	"coupon": Vector2i(16, 3),
	"zero": Vector2i(17, 2),
	"penalty": Vector2i(17, 2),
	"unused": Vector2i(15, 2),
	"paged": Vector2i(15, 1),
	"hand": Vector2i(17, 2),
}

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_monitor_layout_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## For every case: planning's PLAN, the count short of the quota (the number at rest, then held at
## the ×'s punch, then the gain box), and the met end (the stamp and the tab).
func test_the_checkout_column_parts_stand_apart_for_every_total() -> void:
	var monitor: MonitorView = await _monitor()
	var count_up: CountUp = _follow(monitor)
	var tuning: CountTotalTuning = count_up.total_tuning()
	var column: CheckoutColumn = monitor.checkout()
	var failures: Array[String] = []
	for case: Vector2i in CASES:
		var quota: int = case.x
		var total: int = case.y
		var where: String = "quota %d, total %d" % [quota, total]
		# Planning.
		monitor.show_plan(total, quota)
		await _frames(1)
		failures.append_array(_column_failures(column, where + " plan", false))
		# The count, short of the quota (the status line shows): at rest, then at the full punch.
		monitor.led.start_count(quota)
		var shown: int = mini(total, quota - 1)
		monitor.led.show_subtotal(shown, false)
		await _frames(1)
		failures.append_array(_column_failures(column, where + " count", false))
		var number: TotalNumber = column.total_number()
		number.scale = Vector2.ONE * tuning.punch_mul
		failures.append_array(_column_failures(column, where + " punched", true))
		number.scale = Vector2.ONE
		# A × lands: its gain box takes the status line's place.
		var times: CountUpBeat = CountUpBeat.new()
		times.land = CountUpBeat.Land.MUL
		times.factor_text = "×3"
		times.gain = maxi(1, total - shown)
		times.lamp = 0
		column.land(times)
		# The punch eases out over punch_s; the gain box stays for gain_box_s.
		await get_tree().create_timer(tuning.punch_s + 0.05).timeout
		failures.append_array(_column_failures(column, where + " gain box", false))
		# The met end: the stamp and the tab.
		monitor.led.show_subtotal(maxi(total, quota), true)
		column.finish(true)
		await _frames(1)
		failures.append_array(_column_failures(column, where + " met", false))
		monitor.led.clear()
		await _frames(1)
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 16))).is_empty()


## The number's size steps down only as its digits need it: every total of one or two digits at
## the mock-up's 38 px (its 6€, 8€, 21€ and 28€), one size per digit count, and the group as drawn
## at rest always fits the room (a punch may run into the column's clip).
func test_the_number_keeps_the_mock_ups_size_for_its_totals() -> void:
	var tuning: CountTotalTuning = load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	var sizes: PackedInt32Array = tuning.number_sizes
	var room: float = CheckoutColumn.NUMBER_ROOM
	var gap: float = tuning.euro_gap
	for amount: int in [0, 6, 8, 11, 21, 28, 39, 80, 86, 99]:
		(
			assert_int(TotalNumber.fit_size(amount, sizes, room, gap))
			. override_failure_message(str(amount))
			. is_equal(sizes[0])
		)
	for pair: Vector2i in [Vector2i(100, 999), Vector2i(111, 888), Vector2i(1000, 9999)]:
		assert_int(TotalNumber.fit_size(pair.x, sizes, room, gap)).is_equal(
			TotalNumber.fit_size(pair.y, sizes, room, gap)
		)
	var last: int = sizes[0]
	for amount: int in [0, 9, 99, 143, 999, 1234, 9999]:
		var size_px: int = TotalNumber.fit_size(amount, sizes, room, gap)
		assert_int(size_px).override_failure_message(str(amount)).is_less_equal(last)
		last = size_px
		var group: float = TotalNumber.group_width("%d" % amount, size_px, gap)
		var drawn: float = group + 2.0 * TotalNumber.OUTLINE
		assert_float(drawn).override_failure_message(str(amount)).is_less_equal(room)


## In a count that ends past 99€ (or peaks past it before a fall) the number follows the value
## shown: its 2-digit values at the mock-up's 38 px, a 3-digit one at its own size inside the
## column, and back to 38 px when it falls under 100. A rolling digit's old glyph is centred in the
## new glyph's cell (no gap, no shift), and the roll's first frame is already moving.
func test_the_number_follows_the_digits_it_shows() -> void:
	var monitor: MonitorView = await _monitor()
	var count_up: CountUp = _follow(monitor)
	var tuning: CountTotalTuning = count_up.total_tuning()
	var column: CheckoutColumn = monitor.checkout()
	var number: TotalNumber = column.total_number()
	var room: Rect2 = MonitorView.CHECKOUT_RECT
	monitor.led.start_count(90)
	for reading: int in [16, 86, 103, 95, 143]:
		monitor.led.show_subtotal(reading, false)
		await _frames(1)
		var expected: int = TotalNumber.fit_size(
			reading, tuning.number_sizes, CheckoutColumn.NUMBER_ROOM, tuning.euro_gap
		)
		assert_int(number.font_size()).override_failure_message(str(reading)).is_equal(expected)
		if reading < 100:
			assert_int(number.font_size()).is_equal(tuning.number_sizes[0])
		var drawn: Rect2 = number.drawn_rect()
		(
			assert_bool(room.grow(0.5).encloses(drawn))
			. override_failure_message("%d: %s" % [reading, drawn])
			. is_true()
		)
	# A roll from 11 to 18: the old "1" centred in the "8"'s cell.
	monitor.led.show_subtotal(11, false)
	await get_tree().create_timer(tuning.digit_roll_s + 0.05).timeout
	monitor.led.show_subtotal(18, false)
	var cell: Control = number.cells()[1]
	var glyph: Label = cell.get_node("Glyph") as Label
	var old: Label = cell.get_node_or_null("Old") as Label
	assert_object(old).is_not_null()
	var old_middle: float = old.position.x + old.size.x / 2.0
	assert_float(old_middle).is_equal_approx(glyph.position.x + glyph.size.x / 2.0, 1.0)
	await get_tree().create_timer(tuning.digit_roll_s + 0.05).timeout
	assert_str(number.text()).is_equal("18")
	await _frames(2)


## The item column (PR #138 monitor, mock-up monitor_codex.png) for every case of the brief: its
## parts inside the frame and apart, in order (header, description, base line, rows and payout;
## the header's glyphs and pages' marker inside its band), no text cut
## silently (MonitorParts), the rows' amounts on one right-hand edge, the
## payout's zone at one place for every item and its digits right-aligned there, and the pages'
## marker when the rows overflow. The 1080p screen is this stage scaled (canvas_items stretch).
## PR #138 round 6: the payout under the rows, clear of them and of the frame's foot, every case.
func test_the_item_column_lays_out_every_case() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var failures: Array[String] = []
	var zones: Array[Rect2] = []
	var payout_edges: Array[float] = []
	for case: Array in ITEM_CASES:
		column.clear()
		var where: String = case[0]
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS, case[1]]) as CardDefinition
		monitor.show_next(definition, 6, 3, definition.tags, _lines(case))
		await _frames(2)
		for problem: String in MonitorParts.problems(column):
			failures.append("%s: %s" % [where, problem])
		var parts: Dictionary[String, Rect2] = column.part_rects()
		zones.append(column.payout_view().get_global_rect())
		if parts.has("payout_digits"):
			payout_edges.append(parts["payout_digits"].end.x)
		if case[0] == "paged" and not parts.has("pager"):
			failures.append("paged: no pages' marker")
		if case[0] == "plain" and parts.has("pager"):
			failures.append("plain: a pages' marker with nothing to page")
	for zone: Rect2 in zones:
		if not zone.is_equal_approx(zones[0]):
			failures.append("the payout's zone moved: %s and %s" % [zones[0], zone])
	for edge: float in payout_edges:
		if absf(edge - payout_edges[0]) > ITEM_PAYOUT_SHADOW + 0.5:
			failures.append("the payout's right edge moved: %s and %s" % [payout_edges[0], edge])
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 16))).is_empty()


## PR #138 round 2 (the user's "out of breath" monitor): the frame near the paper's edge, the
## description's keyword chips with room inside and round them, Banana's bonuses green and its
## factor in its strength's ink; round 5: the base line between the description and the rows
## (MonitorParts' order).
func test_the_item_column_gives_its_parts_room() -> void:
	var paper: Rect2 = MonitorView.PAPER_RECT
	var item: Rect2 = MonitorView.ITEM_RECT
	assert_bool(paper.encloses(item)).is_true()
	assert_float(item.position.y - paper.position.y).is_less_equal(FRAME_MARGIN)
	assert_float(paper.end.y - item.end.y).is_less_equal(FRAME_MARGIN)
	assert_float(paper.end.x - item.end.x).is_less_equal(FRAME_MARGIN)
	assert_that(Vector2(item.size)).is_equal(MonitorItemColumn.SIZE)
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var banana: CardDefinition = load("%s/banana.tres" % CARDS) as CardDefinition
	var case: Array = ITEM_CASES.filter(func(found: Array) -> bool: return found[0] == "bonuses")[0]
	monitor.show_next(banana, 6, 3, banana.tags, _lines(case))
	await _frames(2)
	assert_array(MonitorParts.problems(column)).is_empty()
	var parts: Dictionary[String, Rect2] = column.part_rects()
	assert_object(column.base_line()).is_not_null()
	assert_float(parts["base"].position.y).is_greater_equal(parts["effect"].end.y)
	assert_float(parts["base"].end.y).is_less_equal(parts["rows"].position.y)
	var effect: GlyphLabel = column.effect()
	assert_int(effect.keywords().size()).is_greater(0)
	for chip: KeywordChip in effect.keywords():
		var word: float = (
			KeywordChip
			. font()
			. get_string_size(chip.keyword, HORIZONTAL_ALIGNMENT_LEFT, -1, KeywordChip.text_size())
			. x
		)
		var padding: float = (chip.size.x - 2.0 * KeywordChip.BORDER - word) / 2.0
		assert_float(padding).is_greater_equal(CHIP_PADDING)
		assert_float(chip.position.x).is_greater_equal(CHIP_GAP)
	for line: Array in effect._lines:
		for index: int in range(line.size() - 1):
			var run: Dictionary = line[index]
			if not GlyphText.is_keyword(run):
				continue
			var chip_end: float = float(run["x"]) + effect._run_width(run) - CHIP_GAP
			var gap: float = float(line[index + 1]["x"]) - chip_end
			assert_float(gap).is_greater_equal(CHIP_GAP)
	var colours: Dictionary[String, Color] = {}
	for row: Control in column.pages.all_rows():
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount != null:
			colours[amount.text] = amount.get_theme_color("font_color")
	assert_that(colours["+3€"]).is_equal(MonitorStepRow.BONUS_COLOR)
	assert_that(colours["×2"]).is_equal(MonitorStepRow.factor_ink(1))
	assert_that(MonitorStepRow.BONUS_COLOR).is_equal(Palette.GREEN_DARK)


## PR #138 round 5 (the user's "base price is too big"): the base price is a slim line read like a
## row, exactly a row's pitch tall (never taller), the rows' width, first in the section: the tag,
## "Base price", a dotted leader and the base in ink in the rows' amount column, the rows right
## under it; for one row and for six (on pages), every part apart (MonitorParts).
func test_the_base_price_is_a_line_like_a_row() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	for count: int in [1, 6]:
		var lines: ScanController.ItemLines = ScanController.ItemLines.new()
		lines.payout = milk.base + count
		var fizzles: Array[bool] = []
		for index: int in range(count):
			lines.lines.append("+1€ Bonus number %d" % (index + 1))
			fizzles.append(false)
		lines.fizzles = fizzles
		monitor.show_next(milk, 6, 3, milk.tags, lines)
		await _frames(2)
		var where: String = "%d rows" % count
		var problems: PackedStringArray = MonitorParts.problems(column)
		(
			assert_array(problems)
			. override_failure_message(where + ": " + ", ".join(problems))
			. is_empty()
		)
		var line: Control = column.base_line()
		assert_object(line).override_failure_message(where).is_not_null()
		var parts: Dictionary[String, Rect2] = column.part_rects()
		assert_float(parts["base"].size.y).is_equal(MonitorStepRow.ROW_PITCH)
		assert_float(parts["base"].size.x).is_equal(MonitorItemColumn.ROWS_WIDTH)
		assert_float(parts["base"].end.y).is_equal_approx(parts["rows"].position.y, 0.5)
		assert_float(parts["base"].position.y).is_greater_equal(parts["effect"].end.y)
		var text: Label = line.get_node("Text") as Label
		var amount: Label = line.get_node("Amount") as Label
		assert_str(text.text).is_equal(MonitorBaseLine.CAPTION)
		assert_str(amount.text).is_equal(MonitorText.euros(milk.base))
		assert_that(amount.get_theme_color("font_color")).is_equal(Palette.INK)
		assert_int(amount.get_theme_font_size("font_size")).is_equal(MonitorStepRow.AMOUNT_SIZE)
		var leader: MonitorLeader = line.get_node_or_null("Leader") as MonitorLeader
		assert_object(leader).is_not_null()
		assert_float(leader.span().y).is_greater(leader.span().x)
		var row_amount: Control = column.step_rows()[0].get_node("Amount") as Control
		assert_float(amount.get_global_rect().end.x).is_equal_approx(
			row_amount.get_global_rect().end.x, 0.5
		)
		# Its caption in the rows' name column, its tag a row mark's size (round 5 review).
		var row_text: Control = column.step_rows()[0].get_node("Text") as Control
		assert_float(text.get_global_rect().position.x).is_equal_approx(
			row_text.get_global_rect().position.x, 0.5
		)
		var tag: Control = line.get_node("Mark") as Control
		assert_vector(tag.size).is_equal(MonitorStepRow.MARK_SIZE)
		if count == 1:
			assert_int(column.pages.count()).is_equal(1)


## The description band as round 4 laid it out (the user: "I like top section"): each case's
## description at its round-4 tier (pitch) and line count, the slim base line's freed room going
## to the rows, never to a larger, taller description (round 5 review).
func test_the_description_keeps_round_4s_band() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var failures: Array[String] = []
	for case: Array in ITEM_CASES:
		if not ROUND_4_BANDS.has(case[0]):
			continue
		column.clear()
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS, case[1]]) as CardDefinition
		monitor.show_next(definition, 6, 3, definition.tags, _lines(case))
		await _frames(1)
		var effect: GlyphLabel = column.effect()
		var shown: Vector2i = Vector2i(-1, -1)
		if effect != null:
			shown = Vector2i(roundi(effect.pitch()), effect.line_count())
		if shown != ROUND_4_BANDS[case[0]]:
			failures.append("%s: %s, round 4 %s" % [case[0], shown, ROUND_4_BANDS[case[0]]])
	assert_array(failures).is_empty()


## PR #138 round 4: BASE PRICE shows only over at least one effect row; a plain item, a hand item
## and the count's item before its first step show the header, the description and "= N€" alone
## (round 6: low in the frame), and the base line joins with the count's first step.
func test_the_base_line_needs_an_effect_row() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	for where: String in ["plain", "hand"]:
		var case: Array = ITEM_CASES.filter(func(found: Array) -> bool: return found[0] == where)[0]
		var definition: CardDefinition = load("%s/%s.tres" % [CARDS, case[1]]) as CardDefinition
		monitor.show_next(definition, 6, 3, definition.tags, _lines(case))
		await _frames(2)
		assert_object(column.base_line()).override_failure_message(where).is_null()
		assert_bool(column.part_rects().has("base")).override_failure_message(where).is_false()
		assert_bool(column.payout_view().visible).override_failure_message(where).is_true()
		var shown: Dictionary[String, Rect2] = column.part_rects()
		(
			assert_bool(shown["frame"].encloses(shown["payout"]))
			. override_failure_message(where)
			. is_true()
		)
		assert_array(MonitorParts.problems(column)).override_failure_message(where).is_empty()
	var bonuses: Array = ITEM_CASES.filter(func(found: Array) -> bool: return found[0] == "bonuses")[0]
	var banana: CardDefinition = load("%s/banana.tres" % CARDS) as CardDefinition
	monitor.show_next(banana, 6, 3, banana.tags, _lines(bonuses))
	await _frames(2)
	assert_object(column.base_line()).is_not_null()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	column.start_item(milk, milk.tags, false)
	await _frames(1)
	assert_object(column.base_line()).is_null()
	var rows_top: float = (
		column.part_rects()["rows"].position.y if column.part_rects().has("rows") else -1.0
	)
	column.show_step("+1€ Bonus", false)
	await _frames(1)
	assert_object(column.base_line()).is_not_null()
	var parts: Dictionary[String, Rect2] = column.part_rects()
	assert_float(parts["base"].end.y).is_less_equal(parts["rows"].position.y)
	assert_float(parts["rows"].position.y).is_greater(rows_top)
	assert_array(MonitorParts.problems(column)).is_empty()


## PR #138 round 4 (the user's "closed" description), round 5 ("final price should be in this
## section") and round 6 (the user's "remove dash around price section => gain space and allow
## final price to breathe"; round 7: no tint, the band on the paper): the description in its band,
## closed by its foot (none with no description); no box round the equation: the base line, the
## rows and the payout's zone under the band, across the content's width (the header's), the
## payout's zone the same for every item, under the rows' area and low in the frame, clear of its
## foot; a dotted leader on every row with an amount; no base line for a plain item, a hand item or
## a coupon. MonitorParts holds every
## case's parts in place.
func test_the_description_band_and_the_open_equation() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var shown: Dictionary[String, Dictionary] = {}
	for case_name: String in ["bonuses", "plain", "hand", "coupon"]:
		column.clear()
		var case: Array = ITEM_CASES.filter(func(found: Array) -> bool: return found[0] == case_name)[0]
		var card: CardDefinition = load("%s/%s.tres" % [CARDS, case[1]]) as CardDefinition
		monitor.show_next(card, 6, 3, card.tags, _lines(case))
		await _frames(2)
		var problems: PackedStringArray = MonitorParts.problems(column)
		assert_array(problems).override_failure_message(case_name).is_empty()
		_assert_band_on_paper(column, case_name)
		shown[case_name] = column.part_rects()
		assert_bool(shown[case_name].has("equation")).override_failure_message(case_name).is_false()
		if case_name == "bonuses":
			_assert_leaders(column)
	for case_name: String in shown:
		var parts: Dictionary[String, Rect2] = shown[case_name]
		var inside: float = parts["frame"].end.y - MonitorItemColumn.FRAME
		# v1.00: a coupon that adds nothing shows nothing in its zone (an empty rect).
		if not parts["payout"].has_area():
			continue
		var lowest: float = parts["payout"].end.y
		if parts.has("payout_shadow"):
			lowest = maxf(lowest, parts["payout_shadow"].end.y)
		assert_float(inside - lowest).override_failure_message(case_name).is_between(
			MonitorParts.FOOT_CLEARANCE, PAYOUT_FOOT_MARGIN
		)
		(
			assert_float(parts["footer"].position.y - parts["rows"].end.y)
			. override_failure_message(case_name)
			. is_greater_equal(PAYOUT_ROWS_GAP)
		)
		var over: float = parts["panel"].end.y if parts.has("panel") else parts["header"].end.y
		assert_float(parts["rows"].position.y).override_failure_message(case_name).is_greater_equal(
			over
		)
		var left: float = parts["frame"].position.x + MonitorItemColumn.INSET
		assert_float(parts["rows"].position.x).is_equal_approx(left, 0.5)
		assert_float(parts["rows"].size.x).is_equal(MonitorItemColumn.CONTENT_WIDTH)
		assert_float(parts["footer"].end.x).is_equal_approx(parts["rows"].end.x, 0.5)
	var bonuses: Dictionary[String, Rect2] = shown["bonuses"]
	var band: Rect2 = bonuses["panel"]
	assert_bool(band.grow(0.5).encloses(bonuses["effect"])).is_true()
	assert_bool(bonuses["frame"].encloses(band)).is_true()
	assert_float(bonuses["base"].position.y).is_greater_equal(band.end.y)
	assert_float(bonuses["payout"].position.y).is_greater_equal(bonuses["rows"].end.y)
	for case_name: String in ["plain", "hand", "coupon"]:
		assert_bool(shown[case_name].has("base")).override_failure_message(case_name).is_false()
	# No description: no band, the base line under the header.
	var potatoes: CardDefinition = load("%s/potatoes.tres" % CARDS) as CardDefinition
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = potatoes.base + 1
	lines.lines = PackedStringArray(["+1€ Bonus"])
	lines.fizzles = [false]
	column.clear()
	monitor.show_next(potatoes, 6, 3, potatoes.tags, lines)
	await _frames(2)
	var bare: Dictionary[String, Rect2] = column.part_rects()
	assert_bool(bare.has("panel")).is_false()
	assert_bool(bare.has("base")).is_true()
	assert_float(bare["base"].position.y).is_greater(bare["header"].end.y)
	assert_array(MonitorParts.problems(column)).is_empty()


## PR #138 round 6 (the user's "positive bonus should have their items names in green and
## negative in red" and "multiplier should be aligned with other number"): over a ladder of
## amounts (the base price, bonuses, factors from ×1 to ×5, a harmful factor, a minus amount, a
## 0€ denial and WASTED), a bonus's name green as its amount, a harmful row's and an unused one's
## tomato, a factor's over ×1 green too (v1.15, the user's "multiplier (if > 1.0) should also put
## text on green"; its amount keeps its strength's ink), a ×1 factor's and the base line's names
## their own (teal, ink); every euro amount's and
## WASTED's visible ink on one right edge, every factor's digits ending on the euro amounts' digits,
## all at one size on one baseline (MonitorParts.amounts_aligned); the same at 1080p's scale.
func test_row_names_take_their_amounts_colour_and_the_numbers_align() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var ladder: Array[Array] = [
		["+2€ Strawberries before it", false, false, MonitorStepRow.BONUS_COLOR],
		["+1032€ Banana chain", false, false, MonitorStepRow.BONUS_COLOR],
		["× Snack deal  ×1", false, false, MonitorStepRow.TEXT_COLOR],
		["× Stale popcorn  ×1.5", false, false, MonitorStepRow.BONUS_COLOR],
		["× 2 for 1  ×2", false, false, MonitorStepRow.BONUS_COLOR],
		["× Multipack  ×3", false, false, MonitorStepRow.BONUS_COLOR],
		["× Banana stand  ×5", false, false, MonitorStepRow.BONUS_COLOR],
		["× Markdown  ×0.5", false, false, MonitorStepRow.HARM_COLOR],
		["-2€ Frozen peas after it", false, true, MonitorStepRow.HARM_COLOR],
		["Spot check: 0€", false, true, MonitorStepRow.HARM_COLOR],
		["+1€ No Batteries after it", true, false, MonitorStepRow.HARM_COLOR],
	]
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var holder: Control = auto_free(Control.new())
	holder.position = Vector2(100.0, 50.0)
	get_tree().root.add_child(holder)
	var width: float = MonitorItemColumn.ROWS_WIDTH
	var aligned: Array[Control] = [MonitorBaseLine.make(milk.base, width)]
	holder.add_child(aligned[0])
	for entry: Array in ladder:
		column.clear()
		monitor.show_next(milk, 6, 3, milk.tags, _lines(["ladder", "milk", 9, [entry]]))
		await _frames(1)
		var row: Control = column.step_rows()[0]
		var text: Label = row.get_node("Text") as Label
		(
			assert_that(text.get_theme_color("font_color"))
			. override_failure_message(String(entry[0]))
			. is_equal(entry[3])
		)
		var tone: MonitorStepRow.Tone = MonitorStepRow.tone_of(bool(entry[1]), bool(entry[2]))
		var made: Control = MonitorStepRow.make(String(entry[0]), tone, false, null, 2, width)
		made.add_child(MonitorLeader.new(made.size))
		made.position = Vector2(0.0, aligned.size() * MonitorStepRow.ROW_PITCH)
		holder.add_child(made)
		aligned.append(made)
	assert_that(MonitorStepRow.BONUS_COLOR).is_equal(Palette.GREEN_DARK)
	var base: Label = column.base_line().get_node("Text") as Label
	assert_that(base.get_theme_color("font_color")).is_equal(MonitorBaseLine.INK)
	var found: PackedStringArray = MonitorParts.amounts_aligned(aligned)
	assert_array(found).override_failure_message(", ".join(found)).is_empty()
	# Every factor's box ends the euro sign's width inside the euro amounts' (its digits set where
	# theirs end), and its digits' ink on theirs, within DIGIT_TOLERANCE.
	var euro_amount: Label = aligned[0].get_node("Amount") as Label
	var euro: Vector3 = MonitorParts.amount_ink(euro_amount)
	var inset: float = MonitorStepRow.amount_inset("×2")
	assert_float(inset).is_greater(0.0)
	var factors: int = 0
	for row: Control in aligned:
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount != null and amount.text.begins_with(MonitorStepRow.FACTOR_SIGN):
			(
				assert_float(amount.get_global_rect().end.x)
				. override_failure_message(amount.text)
				. is_equal_approx(euro_amount.get_global_rect().end.x - inset, 0.01)
			)
			var ink: Vector3 = MonitorParts.amount_ink(amount)
			assert_float(absf(ink.y - euro.y)).override_failure_message(amount.text).is_less_equal(
				MonitorParts.DIGIT_TOLERANCE
			)
			factors += 1
	assert_int(factors).is_equal(6)
	# A "gives" row keeps its teal name; its amount (round 7, unbracketed; v1.11: the effect alone)
	# takes its effect's ink, a factor's or a bonus's green; its equation is a line of its own under
	# the name, indented, the row a line taller.
	var equations: Dictionary[String, String] = {
		"to Banana  ×2": "5€ × 2 = 10€", "to Milk  +3€": "4€ + 3€ = 7€"
	}
	for line: String in equations:
		var gives: Control = auto_free(
			MonitorStepRow.make(
				line, MonitorStepRow.Tone.PLAIN, true, null, 2, 264.0, equations[line]
			)
		)
		var gives_text: Label = gives.get_node("Text") as Label
		assert_that(gives_text.get_theme_color("font_color")).is_equal(MonitorStepRow.TEXT_COLOR)
		assert_str(gives_text.text).is_equal(line.get_slice("  ", 0))
		var gives_amount: Label = gives.get_node("Amount") as Label
		assert_str(gives_amount.text).is_equal(line.get_slice("  ", 1))
		var want: Color = MonitorStepRow.amount_colour_of(
			gives_amount.text, MonitorStepRow.Tone.PLAIN
		)
		assert_that(gives_amount.get_theme_color("font_color")).is_equal(want)
		var equation: Label = gives.get_node("Equation") as Label
		assert_str(equation.text).is_equal(equations[line])
		assert_float(equation.position.x).is_equal(
			gives_text.position.x + MonitorStepRow.EQUATION_INDENT
		)
		assert_float(equation.position.y).is_equal(MonitorStepRow.ROW_PITCH)
		assert_float(gives_amount.position.y).is_less(MonitorStepRow.ROW_PITCH)
		assert_float(gives.size.y).is_equal(2.0 * MonitorStepRow.ROW_PITCH)
		assert_that(equation.get_theme_color("font_color")).is_equal(MonitorStepRow.NOTE_COLOR)


## PR #138 round 3 and 4: a factor's ink follows its value, the higher the hotter (MonitorStepRow
## FACTOR_INKS: amber, orange, orange on a light shadow, velvet on a gold shadow), colour only,
## never a box behind it; each readable (4.5:1 on the monitor's paper, 3:1 on the cream), none the
## bonuses' green; a factor under ×1 is harmful (flat tomato, no shadow), and a strong one stays
## apart from it: by a shadow or HARM_HUE_APART from its hue.
func test_factor_inks_grow_with_the_factor() -> void:
	var factors: Array[String] = ["×1", "×1.5", "×2", "×3", "×4", "×5", "×10"]
	var steps: Array[int] = []
	for factor: String in factors:
		steps.append(MonitorStepRow.factor_step(factor))
	assert_array(steps).is_equal([0, 0, 1, 2, 2, 3, 3])
	var plain: MonitorStepRow.Tone = MonitorStepRow.Tone.PLAIN
	assert_that(MonitorStepRow.amount_colour_of("×0.5", plain)).is_equal(MonitorStepRow.HARM_COLOR)
	assert_that(MonitorStepRow.amount_colour_of("×0", plain)).is_equal(MonitorStepRow.HARM_COLOR)
	var weight: int = -1
	var hue: float = INF
	for step: int in range(MonitorStepRow.FACTOR_INKS.size()):
		var ink: Color = MonitorStepRow.factor_ink(step)
		var shadow: Color = MonitorStepRow.factor_shadow(step)
		assert_that(ink).is_not_equal(MonitorStepRow.BONUS_COLOR)
		assert_that(ink).is_not_equal(MonitorStepRow.HARM_COLOR)
		for ground: Color in [Palette.PAPER, Palette.CREAM]:
			var least: float = 3.0 if ground == Palette.CREAM else 4.5
			(
				assert_float(_contrast(ink, ground))
				. override_failure_message("step %d" % step)
				. is_greater_equal(least)
			)
		if shadow.a <= 0.0:
			var apart: float = absf(ink.h - MonitorStepRow.HARM_COLOR.h)
			apart = minf(apart, 1.0 - apart)
			assert_float(apart).override_failure_message("step %d hue" % step).is_greater_equal(
				HARM_HUE_APART
			)
		# Hotter: its hue from amber toward red (never back), and a shadow once one starts.
		var heat: float = ink.h if ink.h < 0.5 else ink.h - 1.0
		assert_float(heat).override_failure_message("step %d hue" % step).is_less_equal(hue)
		hue = heat
		var step_weight: int = 1 if shadow.a > 0.0 else 0
		assert_int(step_weight).is_greater_equal(weight)
		weight = step_weight
	assert_int(weight).is_equal(1)
	# On a row: the ink and the shadow, never a box behind the amount.
	var width: float = MonitorItemColumn.CONTENT_WIDTH
	for line: String in ["× Banana stand  ×5", "× Multipack  ×3", "× Bundle  ×2"]:
		var row: Control = auto_free(MonitorStepRow.make(line, plain, false, null, 2, width))
		var amount: Label = row.get_node("Amount") as Label
		var step: int = MonitorStepRow.factor_step(line.get_slice("  ", 1))
		assert_that(amount.get_theme_color("font_color")).is_equal(MonitorStepRow.factor_ink(step))
		for child: Node in row.get_children():
			assert_bool(child is ColorRect).override_failure_message(line).is_false()
	var five: Control = auto_free(
		MonitorStepRow.make("× Banana stand  ×5", plain, false, null, 2, width)
	)
	var five_amount: Label = five.get_node("Amount") as Label
	assert_that(five_amount.get_theme_color("font_shadow_color")).is_equal(Palette.GOLD)
	# A harmful factor: tomato text, no shadow.
	var half: Control = auto_free(
		MonitorStepRow.make("× Markdown  ×0.5", plain, false, null, 2, width)
	)
	var half_amount: Label = half.get_node("Amount") as Label
	assert_that(half_amount.get_theme_color("font_color")).is_equal(MonitorStepRow.HARM_COLOR)
	assert_bool(half_amount.has_theme_color_override("font_shadow_color")).is_false()


## Every row with an amount has a dotted leader that runs between its name and its amount, on the
## 2 px grid (PR #138 round 5: the one look).
func _assert_leaders(column: MonitorItemColumn) -> void:
	var led: int = 0
	for row: Control in column.step_rows():
		var leader: MonitorLeader = row.get_node_or_null("Leader") as MonitorLeader
		var amount: Label = row.get_node_or_null("Amount") as Label
		if amount == null:
			continue
		assert_object(leader).is_not_null()
		var span: Vector3 = leader.span()
		var text: Label = row.get_node("Text") as Label
		assert_float(span.x).is_greater(text.position.x + MonitorStepRow.text_width(text))
		var digits: float = amount.position.x + amount.size.x - MonitorStepRow.text_width(amount)
		assert_float(span.y).is_less(digits)
		assert_float(fmod(span.x, 2.0)).is_equal(0.0)
		led += 1
	assert_int(led).is_greater(0)


## Round 7 (the user's "remove bg color and keep same white as in operation section"): with a
## description, nothing `column` fills (MonitorItemColumn.fills) covers its band above the band's
## foot line inside the frame, so the band's ground is the paper the equation section is on; the
## foot is the family's colour, PANEL_LINE px.
func _assert_band_on_paper(column: MonitorItemColumn, case_name: String) -> void:
	var parts: Dictionary[String, Rect2] = column.part_rects()
	if not parts.has("panel"):
		return
	var origin: Vector2 = column.get_global_rect().position
	var band: Rect2 = Rect2(parts["panel"].position - origin, parts["panel"].size)
	var line: float = MonitorItemColumn.PANEL_LINE
	var ground: Rect2 = Rect2(band.position, Vector2(band.size.x, band.size.y - line))
	ground = ground.grow_individual(-MonitorItemColumn.FRAME, -0.5, -MonitorItemColumn.FRAME, 0.0)
	var feet: int = 0
	for fill: Array in column.fills():
		var rect: Rect2 = fill[0]
		(
			assert_bool(rect.intersects(ground))
			. override_failure_message("%s: %s over the band" % [case_name, rect])
			. is_false()
		)
		if is_equal_approx(rect.position.y, band.end.y - line) and rect.size.y == line:
			feet += 1
	assert_int(feet).override_failure_message(case_name).is_greater(0)


## v1.15 (the user's "multiplier (if > 1.0) should also put text on green"): a factor over ×1
## ("×1.25", "×1.5", "×2", "×5") names its row in the bonuses' green, legible on the monitor's
## paper (3:1 or more), its amount keeping its strength's ink; a ×1 factor's name stays teal, a
## factor under ×1 tomato, and a "gives" row's teal whatever its factor (its amount is another
## item's).
func test_a_factor_over_one_names_its_row_in_green() -> void:
	var plain: MonitorStepRow.Tone = MonitorStepRow.Tone.PLAIN
	for amount: String in ["×1.25", "×1.5", "×2", "×5"]:
		assert_bool(MonitorStepRow.raises(amount)).override_failure_message(amount).is_true()
		(
			assert_that(MonitorStepRow.name_colour_of(amount, plain, false))
			. override_failure_message(amount)
			. is_equal(MonitorStepRow.BONUS_COLOR)
		)
		(
			assert_that(MonitorStepRow.amount_colour_of(amount, plain))
			. override_failure_message(amount)
			. is_equal(MonitorStepRow.factor_ink(MonitorStepRow.factor_step(amount)))
		)
		(
			assert_that(MonitorStepRow.name_colour_of(amount, plain, true))
			. override_failure_message(amount)
			. is_equal(MonitorStepRow.TEXT_COLOR)
		)
	for amount: String in ["×1", "×1.0", "+2€", "4€", ""]:
		assert_bool(MonitorStepRow.raises(amount)).override_failure_message(amount).is_false()
	assert_that(MonitorStepRow.name_colour_of("×1", plain, false)).is_equal(
		MonitorStepRow.TEXT_COLOR
	)
	assert_that(MonitorStepRow.name_colour_of("×0.5", plain, false)).is_equal(
		MonitorStepRow.HARM_COLOR
	)
	assert_float(_contrast(MonitorStepRow.BONUS_COLOR, Palette.PAPER)).is_greater_equal(3.0)
	var row: Control = auto_free(
		MonitorStepRow.make("× Week bonus  ×1.25", plain, false, null, 2, 264.0)
	)
	var text: Label = row.get_node("Text") as Label
	assert_that(text.get_theme_color("font_color")).is_equal(MonitorStepRow.BONUS_COLOR)
	var amount_label: Label = row.get_node("Amount") as Label
	assert_str(amount_label.text).is_equal("×1.25")
	assert_float(text.position.x + text.size.x).is_less_equal(amount_label.position.x)


## The WCAG contrast of two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Rows past the room go on pages with their marker (never cut silently), and the payout shows "="
## and the amount only (no equation, no struck price, no check mark).
func test_the_item_column_shows_its_overflow_and_only_the_result() -> void:
	var monitor: MonitorView = await _monitor()
	var column: MonitorItemColumn = monitor.item_column()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = 18
	for index: int in range(7):
		lines.lines.append("+%d€ Bonus number %d" % [index + 1, index + 1])
	var fizzles: Array[bool] = []
	fizzles.resize(7)
	fizzles.fill(false)
	lines.fizzles = fizzles
	monitor.show_next(milk, 6, 3, milk.tags, lines)
	await _frames(2)
	var parts: Dictionary[String, Rect2] = column.part_rects()
	assert_bool(parts.has("pager")).is_true()
	assert_array(MonitorParts.problems(column)).is_empty()
	var payout: MonitorPayout = column.payout_view()
	assert_bool(payout.equals().visible).is_true()
	assert_str(payout.digit_words().text).is_equal(MonitorText.euros(18))
	var texts: Array[String] = []
	for label: Label in MonitorParts._labels(column):
		if label.is_visible_in_tree():
			texts.append(label.text)
	for text: String in texts:
		(
			assert_bool(text.contains("✓") or (text.contains(" + ") and text.contains(" = ")))
			. is_false()
		)


# --- Helpers ---------------------------------------------------------------------------------


## An ITEM_CASES case's lines as the scan gives them.
static func _lines(case: Array) -> ScanController.ItemLines:
	var lines: ScanController.ItemLines = ScanController.ItemLines.new()
	lines.payout = case[2]
	var fizzles: Array[bool] = []
	var harms: Array[bool] = []
	for line: Array in case[3]:
		lines.lines.append(line[0])
		fizzles.append(bool(line[1]))
		harms.append(bool(line[2]))
	lines.fizzles = fizzles
	lines.harms = harms
	return lines


## The checkout column's parts now, as failures (see the suite comment). `punched`: the number is
## held at the full punch, so only its clearances are read (the ladder may take its drop).
static func _column_failures(column: CheckoutColumn, where: String, punched: bool) -> Array[String]:
	var failures: Array[String] = []
	var room: Rect2 = MonitorView.CHECKOUT_RECT
	var paper: Rect2 = MonitorView.PAPER_RECT
	var number: TotalNumber = column.total_number()
	var drawn: Rect2 = number.drawn_rect()
	var ink: Rect2 = number.ink_rect()
	# At rest it stays clear of the divider and inside the paper; punched it may cover the divider
	# and run into the column's clip at the paper's edge for a moment (as in the mock-up).
	var left: float = room.position.x + CheckoutColumn.DIVIDER_RECT.end.x
	if not column.clip_contents or not paper.encloses(column.get_global_rect()):
		failures.append("%s: the column does not clip at the paper" % where)
	if not punched and (drawn.position.x < left - 0.5 or drawn.end.x > paper.end.x - 0.5):
		failures.append("%s: number %s left of %s or past the paper" % [where, drawn, left])
	var caption: Rect2 = column.caption().get_global_rect()
	if ink.position.y < caption.end.y + CAPTION_CLEAR - 0.5:
		failures.append(
			(
				"%s: digits' ink %s under %s px of the caption %s"
				% [where, ink, CAPTION_CLEAR, caption]
			)
		)
	var parts: Dictionary[String, Rect2] = {
		"caption": caption,
		"number": ink if punched else drawn,
		"ladder": column.ladder().get_global_rect(),
		"spend": column.spend_line().get_global_rect(),
	}
	if column.status_label().visible:
		parts["status"] = _text_rect(column.status_label())
	if column.gain_box().visible:
		parts["gain"] = MonitorKit.drawn_rect(column.gain_box(), MonitorKit.BOX_BORDER)
	if column.stamp().visible:
		parts["stamp"] = MonitorKit.drawn_rect(column.stamp())
	if column.tab().visible:
		parts["tab"] = MonitorKit.drawn_rect(column.tab(), MonitorKit.BOX_BORDER)
	var names: Array[String] = parts.keys()
	for index: int in range(names.size()):
		var rect: Rect2 = parts[names[index]]
		var clipped: bool = punched and names[index] == "number"
		if not clipped and (not room.grow(0.5).encloses(rect) or not paper.encloses(rect)):
			failures.append("%s: %s %s outside the column %s" % [where, names[index], rect, room])
		for other: int in range(index + 1, names.size()):
			# A tilted stamp's bounding box may graze its neighbour by a corner: a pixel's grace.
			if rect.grow(-1.0).intersects(parts[names[other]]):
				failures.append(
					(
						"%s: %s %s over %s %s"
						% [where, names[index], rect, names[other], parts[names[other]]]
					)
				)
	return failures


## A centred label's text as drawn (global): its text's width about its middle, its full height.
static func _text_rect(label: Label) -> Rect2:
	var rect: Rect2 = label.get_global_rect()
	var font: Font = label.get_theme_font("font")
	var size_px: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	width *= label.scale.x
	return Rect2(rect.get_center().x - width / 2.0, rect.position.y, width, rect.size.y)


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


## A count-up (not played, in the tree for its tweens) the monitor follows.
func _follow(monitor: MonitorView) -> CountUp:
	var count_up: CountUp = auto_free(CountUp.new())
	get_tree().root.add_child(count_up)
	monitor.follow(count_up)
	return count_up


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## PR #138 round 7 (the user's "are dots drawn? at 1920*1080, it feel like they have different
## sizes"): under 1080p's 1.5 scale, a window a few px short of it (1.468) and scale 1, from
## fractional origins, every leader dot lands on whole screen pixels, all the same size (3 px at
## 1.5), evenly spaced, inside the span; a real row's dots too.
func test_leader_dots_are_whole_screen_pixels() -> void:
	var span: Vector3 = Vector3(48.0, 130.0, 16.0)
	for zoom: float in [1.0, 1.5, 1468.0 / 1000.0]:
		for origin: Vector2 in [Vector2(615.0, 79.0), Vector2(615.25, 80.5), Vector2(13.0, 7.75)]:
			var screen: Transform2D = Transform2D(0.0, Vector2.ONE * zoom, 0.0, origin * zoom)
			var dots: Array[Rect2] = MonitorLeader.snapped_dots(span, screen)
			var where: String = "%s at %s" % [zoom, origin]
			assert_int(dots.size()).override_failure_message(where).is_greater(10)
			var side: Vector2 = Vector2.ONE * roundf(MonitorLeader.DOT * zoom)
			var gaps: Dictionary[int, bool] = {}
			for index: int in range(dots.size()):
				var shown: Rect2 = screen * dots[index]
				var message: String = "%s: %s" % [where, shown]
				assert_vector(shown.position).override_failure_message(message).is_equal_approx(
					shown.position.round(), Vector2.ONE * 0.001
				)
				assert_vector(shown.size).override_failure_message(message).is_equal_approx(
					side, Vector2.ONE * 0.001
				)
				assert_float(dots[index].end.x).is_less_equal(span.y + 0.01)
				if index > 0:
					gaps[roundi(shown.position.x - (screen * dots[index - 1]).position.x)] = true
			assert_int(gaps.size()).override_failure_message(where).is_equal(1)
	# A real row's leader under a 1.5 scale draws the same dots.
	var holder: Control = auto_free(Control.new())
	holder.position = Vector2(410.5, 52.25)
	holder.scale = Vector2.ONE * 1.5
	get_tree().root.add_child(holder)
	var row: Control = MonitorStepRow.make(
		"+2€ Eggs", MonitorStepRow.Tone.PLAIN, false, null, 2, 264.0
	)
	holder.add_child(row)
	var leader: MonitorLeader = MonitorLeader.new(row.size)
	row.add_child(leader)
	await _frames(1)
	var drawn: Array[Rect2] = leader.dots()
	assert_int(drawn.size()).is_greater(5)
	var to_screen: Transform2D = (
		leader.get_viewport().get_final_transform() * leader.get_global_transform_with_canvas()
	)
	var first: Vector2 = (to_screen * drawn[0]).size
	assert_float(first.x).is_equal_approx(roundf(first.x), 0.001)
	for dot: Rect2 in drawn:
		var shown: Rect2 = to_screen * dot
		assert_vector(shown.position).is_equal_approx(shown.position.round(), Vector2.ONE * 0.001)
		assert_vector(shown.size).is_equal_approx(first, Vector2.ONE * 0.001)
