extends GdUnitTestSuite
## A belt item's scan on every golden row (#75, decision 1A; on the hung monitor since #80, in its
## item column since #105 piece 2): scored with its frozen fixture, the planning receipt printed for
## the row and the item column's step lines, filled as ScanController fills them for each belt item,
## hold the same step lines per slot (the receipt's BASE and PAYOUT lines aside), in order; the
## lines that don't fit fold into "+N more", counted. The reference row's check on the real shift
## screen is in item_scan_test. The real saves and logs are never touched.

const ReceiptFooters := preload("res://tests/ui/receipt_footers.gd")
## The golden rows (docs/PROTOTYPE_PLAN.md section 3.7, tests/core/golden_rows_test.gd), each
## scored with its frozen fixture.
const GOLDEN_ROWS: Dictionary[String, Array] = {
	"res://tests/fixtures/cards_v0_4":
	[
		"eggs,bread,cheese,banana,banana,repeat",
		"banana,repeat,bread,eggs,banana,cheese",
		"eggs,banana,banana",
		"banana,bundle,banana",
		"banana,repeat,banana",
		"bread,bundle,cheese",
		"eggs,bread,multipack,bread",
		"milk,multipack,cheese",
		"coffee,coffee,bread",
		"breakfast_sticker,banana,milk",
		"eggs,eggs,bread,bread,bread",
		"repeat,repeat",
		"soup,frozen_peas",
		"bread,final_markdown",
		"final_markdown,bread",
		"eggs,bread,repeat,bread",
		"bread,multipack,bread,repeat",
		"multipack,bread,bread",
		"bread,repeat,multipack,bread",
		"breakfast_sticker,repeat,banana,milk",
		"frozen_peas,frozen_peas",
		"soup,bundle,frozen_peas",
		"soup,repeat,frozen_peas",
		"eggs,coffee,bread,bread",
		"coffee,banana,bread",
		"coffee,bread,milk",
		"coffee,repeat,bread",
		"coffee,multipack,banana,bread",
		"bread,multipack,bread,multipack,bread",
		"breakfast_sticker,banana,multipack,coffee,bread",
		"banana,bundle,bundle,banana",
		"bread,bundle,repeat",
		"coffee,breakfast_sticker,soup,frozen_peas,bread",
		"eggs,soup,frozen_peas,bread",
		"banana,bundle,multipack,banana",
		"bundle,banana,banana,bundle",
		"bread,coffee",
		"breakfast_sticker,bread,milk",
		"bread,repeat,repeat",
		"coffee,breakfast_sticker,banana",
		"coffee,multipack,breakfast_sticker,banana",
	],
	"res://tests/fixtures/cards_v0_5":
	[
		"banana,two_for_one,banana",
		"bread,two_for_one,cheese",
		"banana,two_for_one,two_for_one,banana",
		"frozen_peas,two_for_one,frozen_peas",
		"eggs,banana,two_for_one,banana,repeat",
		"bread,banana,shelf_swap,cheese",
		"soup,bread,shelf_swap,frozen_peas",
		"frozen_peas,bread,shelf_swap,frozen_peas",
		"banana,two_for_one,banana,shelf_swap,banana",
	],
	"res://tests/fixtures/cards_v0_6":
	[
		"clearance_tag,bread,day_old_buns",
		"clearance_tag,day_old_buns,day_old_buns",
		"bread,clearance_tag",
		"flickering_bulb,clearance_tag,bread",
		"clearance_tag,bread,dented_can,dented_can",
		"clearance_tag,bread,reduced_yogurt",
		"opening_deal,soup,bread",
		"bread,opening_deal,soup",
		"opening_deal,repeat",
		"opening_deal,soup,repeat",
		"opening_deal,soup,eggs,bread,milk",
		"opening_deal,breakfast_sticker,banana,milk",
		"opening_deal,frozen_peas,bread,shelf_swap,frozen_peas",
		"opening_deal,soup,frozen_peas",
		"opening_deal,clearance_tag,bread,day_old_buns",
		"clearance_tag,opening_deal,bread",
	],
}

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


## The exact test on every golden row, each scored with its frozen fixture: the receipt printed
## for the row and the monitor filled as ScanController fills it for a belt item hold the same
## lines per slot (the folded ones counted by "+N more").
func test_the_scans_hold_every_line_of_each_golden_rows_receipt() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(276, 0)
	add_child(receipt)
	var monitor: MonitorView = auto_free(MonitorView.new())
	add_child(monitor)
	var folded: int = 0
	var rows: int = 0
	var failures: PackedStringArray = PackedStringArray()
	for fixture: String in GOLDEN_ROWS:
		for row_ids: String in GOLDEN_ROWS[fixture]:
			var row: Array[CardInstance] = _fixture_row(fixture, row_ids)
			var result: ScoreResult = Scoring.score(row)
			var names: PackedStringArray = CardInstance.names(row)
			receipt.show_result(result, names)
			(
				assert_int(ReceiptFooters.printed(receipt).size())
				. override_failure_message(row_ids)
				. is_equal(ReceiptFooters.printing_steps(result).size() + 1)
			)
			var expected: Dictionary[int, PackedStringArray] = ReceiptFooters.by_slot(
				receipt, result, names
			)
			var footers: Dictionary[int, PackedStringArray] = {}
			for slot: int in range(row.size()):
				var shown: ScanController.ItemLines = ScanController.ItemLines.new()
				shown.payout = result.payouts[slot]
				for step: ScoreStep in ScanController.footer_steps(result, slot):
					shown.lines.append(ReceiptView.step_line(step, names))
					shown.fizzles.append(step.step_type == ScoreStep.StepType.WASTED)
				monitor.show_scan(row[slot].definition, result.tags[slot], shown)
				var column: MonitorItemColumn = monitor.item_column()
				var texts: PackedStringArray = column.step_texts()
				var rows_shown: Array[Control] = column.step_rows()
				if not rows_shown.is_empty() and rows_shown[-1].name == "More":
					# "+N more" folds the last N lines: the lines shown are the first ones.
					var more: int = texts[-1].get_slice(" ", 0).to_int()
					texts.resize(texts.size() - 1)
					assert_int(texts.size() + more).is_equal(shown.lines.size())
					var full: PackedStringArray = expected.get(slot, PackedStringArray())
					expected[slot] = full.slice(0, texts.size())
					folded += 1
				footers[slot] = texts
			failures.append_array(ReceiptFooters.failures(expected, footers, row_ids))
			rows += 1
			# The lines the receipt and the monitor let go of are freed at the frame's end.
			await get_tree().process_frame
	prints('#105 golden rows\' scans folding lines into "+N more":', folded)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(rows).is_equal(66)


static func _fixture_row(fixture: String, ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [fixture, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
