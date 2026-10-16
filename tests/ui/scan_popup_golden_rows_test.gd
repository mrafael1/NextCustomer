extends GdUnitTestSuite
## The scan popup on every golden row (#75, decision 1A): scored with its frozen fixture, the
## planning receipt printed for the row and the belt popups' footers, filled as ScanController
## fills them, hold the same step lines per slot, none folded (the receipt's BASE and PAYOUT lines
## aside). The reference row's check on the real shift screen is in item_scan_test. The real saves
## and logs are never touched.

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
## for the row and a popup filled as ScanController fills a belt item's popup hold the same lines
## per slot, none folded.
func test_the_popups_hold_every_line_of_each_golden_rows_receipt() -> void:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(276, 0)
	add_child(receipt)
	var popup: ScanPopup = auto_free(ScanPopup.new())
	add_child(popup)
	var rows: int = 0
	var failures: PackedStringArray = PackedStringArray()
	for fixture: String in GOLDEN_ROWS:
		for row_ids: String in GOLDEN_ROWS[fixture]:
			var row: Array[CardInstance] = _fixture_row(fixture, row_ids)
			var result: ScoreResult = Scoring.score(row)
			var names: PackedStringArray = ShiftScreen._names(row)
			receipt.show_result(result, names)
			(
				assert_int(ReceiptFooters.printed(receipt).size())
				. override_failure_message(row_ids)
				. is_equal(ReceiptFooters.printing_steps(result).size() + 1)
			)
			var expected: Dictionary[int, PackedStringArray] = ReceiptFooters.by_slot(
				receipt, result
			)
			var footers: Dictionary[int, PackedStringArray] = {}
			for slot: int in range(row.size()):
				var lines: PackedStringArray = PackedStringArray()
				var fizzles: Array[bool] = []
				for step: ScoreStep in ScanController.footer_steps(result, slot):
					lines.append(ReceiptView.step_line(step, names))
					fizzles.append(step.step_type == ScoreStep.StepType.WASTED)
				var definition: CardDefinition = row[slot].definition
				popup.show_card(
					definition, null, result.tags[slot], result.payouts[slot], lines, fizzles
				)
				footers[slot] = popup.footer_texts().slice(1)
			failures.append_array(ReceiptFooters.failures(expected, footers, row_ids))
			rows += 1
			# The lines the receipt and the popup let go of are freed at the frame's end.
			await get_tree().process_frame
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
