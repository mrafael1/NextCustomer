extends GdUnitTestSuite
## The count-up receipt's lines add up (#80): for every item of every golden row (each scored with
## its frozen fixture) and of a long row of live cards under every register upgrade and the Spot
## check, the amounts printed for the item (its line's base plus its bonus and copy lines, an
## override's "= €0.00" replacing them, or its closing "= €payout" line, which is then its last
## line and prints only when the others don't already add up) come to its payout, and all the
## items' to the TOTAL. Only the printed labels are read. The real saves and logs are never touched.

const GoldenRows := preload("res://tests/ui/scan_popup_golden_rows_test.gd")
## A long row of live cards: products of every aisle, multipliers, copies, coupons and fizzles.
const LONG_ROW := (
	"eggs,bread,multipack,croissant,coffee,banana,repeat,bundle,milk,cheese,"
	+ "clearance_tag,two_for_one,soup,frozen_peas,breakfast_sticker,final_markdown"
)
const UPGRADES_FOLDER := "res://data/upgrades"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"

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


func test_every_golden_rows_items_add_up_to_the_total() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 0)
	add_child(receipt)
	var failures: PackedStringArray = PackedStringArray()
	var rows: int = 0
	var closings: int = 0
	for fixture: String in GoldenRows.GOLDEN_ROWS:
		for row_ids: String in GoldenRows.GOLDEN_ROWS[fixture]:
			var row: Array[CardInstance] = _row(fixture, row_ids)
			var result: ScoreResult = Scoring.score(row)
			closings += _count_up(receipt, result, CardInstance.names(row))
			failures.append_array(_failures(receipt, result, row_ids))
			rows += 1
			await get_tree().process_frame
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(rows).is_equal(66)
	# Some golden rows multiply or override an item: their closing lines are checked too.
	assert_int(closings).is_greater(0)


func test_a_long_rows_items_add_up_to_the_total() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 0)
	add_child(receipt)
	var row: Array[CardInstance] = _row("res://data/cards", LONG_ROW)
	var upgrades: Array[UpgradeDefinition] = []
	for file_name: String in DirAccess.get_files_at(UPGRADES_FOLDER):
		if file_name.ends_with(".tres"):
			upgrades.append(load(UPGRADES_FOLDER.path_join(file_name)) as UpgradeDefinition)
	var inspections: Array[InspectionDefinition] = [load(SPOT_CHECK) as InspectionDefinition]
	var result: ScoreResult = Scoring.score(row, upgrades, inspections)
	var kinds: Dictionary[ScoreStep.StepType, bool] = {}
	for step: ScoreStep in result.steps:
		kinds[step.step_type] = true
	for kind: ScoreStep.StepType in [
		ScoreStep.StepType.FLAT,
		ScoreStep.StepType.MULTIPLIER,
		ScoreStep.StepType.COPY,
		ScoreStep.StepType.PAYOUT_OVERRIDE,
		ScoreStep.StepType.WASTED,
	]:
		assert_bool(kinds.has(kind)).override_failure_message(str(kind)).is_true()
	assert_int(_count_up(receipt, result, CardInstance.names(row))).is_greater(0)
	var failures: PackedStringArray = _failures(receipt, result, "long row")
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	await get_tree().process_frame


## Prints `result` as the count-up does (begin_count, each step, the total); returns how many
## closing lines it printed.
static func _count_up(receipt: ReceiptView, result: ScoreResult, names: PackedStringArray) -> int:
	receipt.begin_count(ReceiptView.header_lines(1, 8, names.size()), names)
	for step: ScoreStep in result.steps:
		receipt.add_step(step, names)
	receipt.add_total(result.total)
	var closings: int = 0
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer and _is_closing(line as HBoxContainer):
			closings += 1
	return closings


## Where the receipt's printed amounts don't add up: per item (to its payout; a closing line not
## last in its group, or under lines that already add up), then in all (to the TOTAL line's
## amount).
static func _failures(
	receipt: ReceiptView, result: ScoreResult, message: String
) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var sums: Dictionary[int, int] = {}
	var closed: Dictionary[int, bool] = {}
	var slot: int = -1
	for line: Node in receipt._lines.get_children():
		if line == receipt._total_line:
			break
		if not line is HBoxContainer:
			continue
		var box: HBoxContainer = line as HBoxContainer
		var right: String = (box.get_child(1) as Label).text
		if receipt._items.values().has(box):
			slot = receipt._items.find_key(box)
			sums[slot] = _euros(right)
			continue
		if slot < 0:
			continue
		if closed.has(slot):
			found.append("%s slot %d: a line under its closing line" % [message, slot])
		if _is_closing(box):
			if sums[slot] == result.payouts[slot]:
				found.append("%s slot %d: a closing line under lines that add up" % [message, slot])
			sums[slot] = _euros(right.trim_prefix(ReceiptView.CLOSING_TEXT))
			closed[slot] = true
		elif right.begins_with(ReceiptView.CLOSING_TEXT):
			# An override's line: its amount is the item's from then on.
			sums[slot] = _euros(right.trim_prefix(ReceiptView.CLOSING_TEXT))
		elif right.begins_with("+"):
			sums[slot] += _euros(right)
	var total: int = 0
	for index: int in range(result.payouts.size()):
		var printed: int = sums.get(index, -1)
		total += printed
		if printed != result.payouts[index]:
			found.append(
				"%s slot %d: prints %d, pays %d" % [message, index, printed, result.payouts[index]]
			)
	var total_text: String = (receipt._total_line.get_child(1) as Label).text
	if total != result.total or _euros(total_text) != result.total:
		found.append(
			"%s: items print %d, TOTAL %s, total %d" % [message, total, total_text, result.total]
		)
	return found


## A closing line: no left side, its right side "= €3.00".
static func _is_closing(line: HBoxContainer) -> bool:
	var left: String = (line.get_child(0) as Label).text
	var right: String = (line.get_child(1) as Label).text
	return left.is_empty() and right.begins_with(ReceiptView.CLOSING_TEXT)


## A printed amount ("€3.00", "+€15.00") in whole euros.
static func _euros(text: String) -> int:
	return int(text.trim_prefix("+").trim_prefix("€").trim_suffix(".00"))


static func _row(folder: String, ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [folder, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
