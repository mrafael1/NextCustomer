extends GdUnitTestSuite
## The receipt's v3.1 inks (ReceiptInk, approved mock-up checkout_rhythm_v3_1.html), on a receipt
## at the shift screen's width: each item line holds its card's mini (its giver-badge plate, else
## its item sprite) in a two-character slot inside the line, without making the line or the
## receipt taller; × amounts print in dark amber and + amounts in ink; each item's final payout
## figure prints bold; a loyalty perk's line has the pale teal band; an armed effect prints its
## "arms" sub line (its card's sticker words, the × amount amber inside them, no amount) after its
## item's payout. Planning, the count (step by step) and show_result print the same. The real
## saves and logs are never touched.

const RECEIPT_SIZE := Vector2(ShiftStage.RECEIPT_WIDTH, 0)
## Long names, a plate, a GOLDEN plate, a coupon without a plate (its sprite) and Bundle (no art).
const PLANNING_ROW := (
	"banana,birthday_candles,flickering_bulb,multipack,bundle,strawberries_golden,"
	+ "birthday_candles_big,birthday_candles_golden,stale_doughnut"
)
const CARDS := "res://data/cards/%s.tres"
const Footers := preload("res://tests/ui/receipt_footers.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Planning: every item's mini sits inside its line and the receipt, left of its name's first
## character, centred on its first row; no item line is taller than its name would be without
## the slot, and the receipt is as tall with the minis as without them. Every payout is bold.
func test_planning_minis_sit_inside_their_lines_and_keep_the_height() -> void:
	var row: Array[CardInstance] = _row(PLANNING_ROW)
	var result: ScoreResult = Scoring.score(row)
	var names: PackedStringArray = CardInstance.names(row)
	var plain: ReceiptView = await _receipt()
	plain.show_planning(PackedStringArray(), result, names, row.size())
	var receipt: ReceiptView = await _receipt()
	receipt.show_planning(PackedStringArray(), result, names, row.size(), -1, _cards(row))
	await _frames(3)
	assert_float(receipt.natural_height()).is_equal(plain.natural_height())
	var paper: Rect2 = receipt.get_global_rect()
	for slot: int in range(row.size()):
		var line: HBoxContainer = receipt._items[slot]
		var left: Label = line.get_child(0) as Label
		var what: String = names[slot]
		(
			assert_bool(ReceiptInk.is_bold(line.get_child(1) as Label))
			. override_failure_message(what)
			. is_true()
		)
		assert_float(line.size.y).override_failure_message(what).is_less_equal(_unslotted(left))
		var icon: TextureRect = ReceiptInk.item_mini(line)
		if row[slot].definition.id == &"bundle":
			assert_object(icon).is_null()
			continue
		assert_object(icon).override_failure_message(what).is_not_null()
		var rect: Rect2 = icon.get_global_rect()
		assert_vector(rect.size).is_equal(ReceiptInk.ICON_SIZE)
		(
			assert_bool(line.get_global_rect().encloses(rect))
			. override_failure_message("%s: %s outside %s" % [what, rect, line.get_global_rect()])
			. is_true()
		)
		assert_bool(paper.encloses(rect)).override_failure_message(what).is_true()
		var first: Rect2 = left.get_character_bounds(0)
		assert_float(left.global_position.x + first.position.x).is_greater_equal(rect.end.x)
		var row_height: float = left.get_theme_font("font").get_height(
			left.get_theme_font_size("font_size")
		)
		assert_float(absf(rect.get_center().y - left.global_position.y - row_height / 2.0)).is_less(
			1.01
		)
	# A plate, a GOLDEN plate, the coupon's sprite.
	assert_str(ReceiptInk.item_mini(receipt._items[0]).texture.resource_path).is_equal(
		"res://art/giver_badges/banana.png"
	)
	assert_str(ReceiptInk.item_mini(receipt._items[5]).texture.resource_path).ends_with(
		"_golden.png"
	)
	assert_str(ReceiptInk.item_mini(receipt._items[3]).texture.resource_path).is_equal(
		row[3].definition.art_ref
	)
	_assert_lines_apart(receipt)


## The count: step by step (as the count-up prints) and at once (show_result) the same lines,
## inks and minis. Eggs (plain) pays bold on its line and then prints its arm line; Bread's ×2
## (from Eggs) is amber, its own +€2 ink, its closing payout bold; Milk's perk +€1 adds up to its
## payout, so that last + amount is the bold figure (no line added), and its line has the perk
## band. Every line sits inside the receipt, none
## overlapping, the arm line no taller than a step line.
func test_the_count_prints_inks_and_the_arm_line() -> void:
	var cards: Array[CardDefinition] = []
	for card_id: String in ["eggs", "bread", "milk"]:
		cards.append(load(CARDS % card_id) as CardDefinition)
	var names: PackedStringArray = PackedStringArray(["Eggs", "Bread", "Milk"])
	var upgrades: PackedStringArray = PackedStringArray(["Dairy regulars"])
	var result: ScoreResult = _count_result()
	var counted: ReceiptView = await _receipt()
	counted.begin_count(PackedStringArray(), names, true, cards)
	for step: ScoreStep in result.steps:
		counted.add_step(step, names, upgrades)
	counted.add_total(result.total)
	var at_once: ReceiptView = await _receipt()
	at_once.show_result(result, names, upgrades, PackedStringArray(), PackedStringArray(), cards)
	await _frames(3)
	for receipt: ReceiptView in [counted, at_once]:
		var lines: Array[HBoxContainer] = _boxes(receipt)
		var texts: Array[String] = []
		for line: HBoxContainer in lines:
			texts.append(Footers.line_text(line))
		var arm: String = "arms " + CardText.sticker_summary(cards[0])
		(
			assert_array(texts)
			. is_equal(
				[
					"Eggs  €1.00",
					arm,
					"Bread  €3.00",
					"+ Bread bonus  +€2.00",
					"Eggs  ×2",
					"  = €10.00",
					"Milk  €2.00",
					"Dairy regulars  +€1.00",
					"TOTAL  €14.00",
				]
			)
		)
		assert_str(arm).contains("×2")
		# Inks: × amber, + ink; the payout figures bold.
		assert_that(_color(lines[4])).is_equal(Palette.MUSTARD_DARKEST)
		assert_that(_color(lines[3])).is_equal(Palette.INK)
		assert_that(_color(lines[7])).is_equal(Palette.INK)
		var bold: Array[bool] = []
		for line: HBoxContainer in lines.slice(0, 8):
			bold.append(ReceiptInk.is_bold(line.get_child(1) as Label))
		assert_array(bold).is_equal([true, false, false, false, false, true, false, true])
		# The perk's pale teal band; another card's combo keeps the gold one.
		assert_bool(lines[7].get_meta(ReceiptDecor.PERK_META, false)).is_true()
		assert_bool(lines[4].get_meta(ReceiptDecor.PERK_META, false)).is_false()
		# The arm line: one row, no amount, its "×2" amber over the blank in its words.
		var arm_line: HBoxContainer = lines[1]
		assert_bool(ReceiptInk.is_arm(arm_line)).is_true()
		assert_str((arm_line.get_child(1) as Label).text).is_empty()
		var left: Label = arm_line.get_child(0) as Label
		assert_int(left.get_line_count()).is_equal(1)
		var amber: Label = left.get_node(ReceiptInk.AMBER_NAME) as Label
		assert_str(amber.text).is_equal("×2")
		assert_that(amber.get_theme_color("font_color")).is_equal(Palette.MUSTARD_DARKEST)
		var at: int = arm.find("×2")
		assert_str(left.text.substr(at, 2)).is_equal("  ")
		var blank_x: float = left.global_position.x + left.get_character_bounds(at).position.x
		assert_float(amber.global_position.x).is_equal_approx(blank_x, 1.0)
		assert_bool(arm_line.get_global_rect().encloses(amber.get_global_rect())).is_true()
		assert_float(arm_line.size.y).is_less_equal(lines[3].size.y)
		for slot: int in range(3):
			var icon: TextureRect = ReceiptInk.item_mini(receipt._items[slot])
			assert_object(icon).is_not_null()
			(
				assert_bool(receipt._items[slot].get_global_rect().encloses(icon.get_global_rect()))
				. override_failure_message(names[slot])
				. is_true()
			)
		_assert_lines_apart(receipt)
	assert_float(counted.natural_height()).is_equal(at_once.natural_height())


## Multipack's words ("arms ×3 later with prior's tag") don't fit on one row even at
## ARM_MIN_FONT_SIZE: they wrap at the step lines' fizzle size, hung, never cut, the "×3" amber
## on the first row, the line inside the receipt.
func test_a_long_arm_line_wraps_whole() -> void:
	var receipt: ReceiptView = await _receipt()
	var cards: Array[CardDefinition] = [load(CARDS % "multipack") as CardDefinition]
	var result: ScoreResult = ScoreResult.new()
	for type: ScoreStep.StepType in [
		ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT, ScoreStep.StepType.EFFECT_ARMED
	]:
		var step: ScoreStep = ScoreStep.new()
		step.step_type = type
		step.value = 3 if type == ScoreStep.StepType.EFFECT_ARMED else 0
		step.text = "Multipack ×3"
		result.steps.append(step)
	result.payouts = PackedInt32Array([0])
	receipt.show_result(
		result,
		PackedStringArray(["Multipack"]),
		PackedStringArray(),
		PackedStringArray(),
		PackedStringArray(),
		cards
	)
	await _frames(3)
	var line: HBoxContainer = _boxes(receipt)[1]
	var left: Label = line.get_child(0) as Label
	var words: String = "arms " + CardText.sticker_summary(cards[0])
	assert_str(left.get_meta(ReceiptInk.WORDS_META)).is_equal(words)
	assert_int(left.get_theme_font_size("font_size")).is_equal(ReceiptView.FOOTER_FONT_SIZE)
	assert_int(left.get_line_count()).is_greater(1)
	assert_int(left.get_visible_line_count()).is_equal(left.get_line_count())
	var amber: Label = left.get_node(ReceiptInk.AMBER_NAME) as Label
	var at: int = words.find("×3")
	var blank_x: float = left.global_position.x + left.get_character_bounds(at).position.x
	assert_float(amber.global_position.x).is_equal_approx(blank_x, 1.0)
	assert_float(amber.global_position.y).is_equal_approx(left.global_position.y, 0.5)
	_assert_lines_apart(receipt)


## A count without its cards still prints the arm line, from its rule's text.
func test_an_arm_line_without_a_card_reads_its_rule() -> void:
	var receipt: ReceiptView = await _receipt()
	var result: ScoreResult = _count_result()
	receipt.show_result(result, PackedStringArray(["Eggs", "Bread", "Milk"]))
	await _frames(2)
	var texts: Array[String] = []
	for line: HBoxContainer in _boxes(receipt):
		texts.append(Footers.line_text(line))
	assert_str(texts[1]).is_equal("arms Eggs ×2")
	var left: Label = _boxes(receipt)[1].get_child(0) as Label
	assert_str((left.get_node(ReceiptInk.AMBER_NAME) as Label).text).is_equal("×2")


## Eggs pays €1 and arms ×2; Bread pays (3 + 2) × 2 = 10; Milk 2 + 1 (a perk) = 3.
static func _count_result() -> ScoreResult:
	var result: ScoreResult = ScoreResult.new()
	var rows: Array[Array] = [
		[0, ScoreStep.StepType.BASE, 1, ""],
		[0, ScoreStep.StepType.PAYOUT, 1, ""],
		[0, ScoreStep.StepType.EFFECT_ARMED, 2, "Eggs ×2"],
		[1, ScoreStep.StepType.BASE, 3, ""],
		[1, ScoreStep.StepType.FLAT, 2, "Bread bonus"],
		[1, ScoreStep.StepType.MULTIPLIER, 2, "Eggs ×2"],
		[1, ScoreStep.StepType.PAYOUT, 10, ""],
		[2, ScoreStep.StepType.BASE, 2, ""],
		[2, ScoreStep.StepType.FLAT, 1, "Dairy regulars"],
		[2, ScoreStep.StepType.PAYOUT, 3, ""],
	]
	for row: Array in rows:
		var step: ScoreStep = ScoreStep.new()
		step.step_type = row[1] as ScoreStep.StepType
		step.slot = row[0] as int
		step.source_slot = step.slot
		step.value = row[2] as int
		step.text = row[3] as String
		result.steps.append(step)
	result.steps[5].source_slot = 0
	result.steps[8].source_kind = ScoreStep.SourceKind.UPGRADE
	result.steps[8].source_index = 0
	result.payouts = PackedInt32Array([1, 10, 3])
	result.total = 14
	return result


func _receipt() -> ReceiptView:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	add_child(receipt)
	receipt.size = RECEIPT_SIZE
	receipt.fit_up(2000.0, 0.0)
	await get_tree().process_frame
	return receipt


## Consecutive lines never overlap, and each sits inside the receipt.
func _assert_lines_apart(receipt: ReceiptView) -> void:
	var paper: Rect2 = receipt.get_global_rect()
	var bottom: float = -INF
	for line: HBoxContainer in _boxes(receipt):
		var rect: Rect2 = line.get_global_rect()
		(
			assert_bool(paper.encloses(rect))
			. override_failure_message("%s outside %s" % [rect, paper])
			. is_true()
		)
		assert_float(rect.position.y).is_greater_equal(bottom - 0.01)
		bottom = rect.end.y


static func _boxes(receipt: ReceiptView) -> Array[HBoxContainer]:
	var found: Array[HBoxContainer] = []
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer:
			found.append(line as HBoxContainer)
	return found


static func _color(line: HBoxContainer) -> Color:
	return (line.get_child(1) as Label).get_theme_color("font_color")


## How tall `left`'s name would be at the line's size across the whole label (no mini slot).
static func _unslotted(left: Label) -> float:
	var font: Font = left.get_theme_font("font")
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(left.text, font, ReceiptView.LINE_FONT_SIZE)
	paragraph.width = left.size.x
	paragraph.break_flags = (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	return paragraph.get_line_count() * font.get_height(ReceiptView.LINE_FONT_SIZE) + 4.0


static func _cards(row: Array[CardInstance]) -> Array[CardDefinition]:
	return ReceiptInk.cards_of(row)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % card_id) as CardDefinition, row.size() + 1))
	return row


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
