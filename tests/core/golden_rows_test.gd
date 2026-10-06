extends GdUnitTestSuite
## The required rows from docs/PROTOTYPE_PLAN.md section 3.7, scored with the frozen fixture
## tests/fixtures/cards_v0_4 (never the live data/). Each row checks every slot's payout and
## the total. If one fails, the change is wrong unless the user approved a rule change.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"


func test_golden_row(
	row: String,
	payouts: Array,
	total: int,
	_test_parameters := [
		["eggs,bread,cheese,banana,banana,repeat", [1, 6, 14, 2, 4, 4], 31],
		["banana,repeat,bread,eggs,banana,cheese", [2, 2, 3, 1, 4, 6], 18],
		["eggs,banana,banana", [1, 4, 8], 13],
		["banana,bundle,banana", [2, 0, 4], 6],
		["banana,repeat,banana", [2, 2, 2], 6],
		["bread,bundle,cheese", [3, 0, 7], 10],
		["eggs,bread,multipack,bread", [1, 6, 0, 12], 19],
		["milk,multipack,cheese", [3, 0, 6], 9],
		["coffee,coffee,bread", [2, 5, 6], 13],
		["breakfast_sticker,banana,milk", [0, 2, 5], 7],
		["eggs,eggs,bread,bread,bread", [1, 2, 6, 6, 3], 18],
		["repeat,repeat", [0, 0], 0],
		["soup,frozen_peas", [0, 3], 3],
		["bread,final_markdown", [3, 6], 9],
		["final_markdown,bread", [0, 3], 3],
		["eggs,bread,repeat,bread", [1, 6, 6, 6], 19],
		["bread,multipack,bread,repeat", [3, 0, 6, 6], 15],
		["multipack,bread,bread", [0, 3, 3], 6],
		["bread,repeat,multipack,bread", [3, 3, 0, 3], 9],
		["breakfast_sticker,repeat,banana,milk", [0, 0, 2, 3], 5],
		["frozen_peas,frozen_peas", [6, 6], 12],
		["soup,bundle,frozen_peas", [0, 0, 3], 3],
		["soup,repeat,frozen_peas", [5, 5, 3], 13],
		["eggs,coffee,bread,bread", [1, 2, 12, 6], 21],
		["coffee,banana,bread", [2, 2, 6], 10],
		["coffee,bread,milk", [2, 6, 7], 15],
		["coffee,repeat,bread", [2, 2, 6], 10],
		["coffee,multipack,banana,bread", [2, 0, 2, 12], 16],
		["bread,multipack,bread,multipack,bread", [3, 0, 6, 0, 12], 21],
		["breakfast_sticker,banana,multipack,coffee,bread", [0, 2, 0, 4, 12], 18],
		["banana,bundle,bundle,banana", [2, 0, 0, 4], 6],
		["bread,bundle,repeat", [3, 0, 0], 3],
		# Decisions recorded in plan v0.5.
		["coffee,breakfast_sticker,soup,frozen_peas,bread", [2, 0, 0, 3, 3], 8],
		["eggs,soup,frozen_peas,bread", [1, 0, 6, 3], 10],
		["banana,bundle,multipack,banana", [2, 0, 0, 2], 4],
		["bundle,banana,banana,bundle", [0, 2, 4, 0], 6],
		["bread,coffee", [3, 2], 5],
		["breakfast_sticker,bread,milk", [0, 3, 5], 8],
		# Found by mutation testing (plan v0.5).
		["bread,repeat,repeat", [3, 3, 0], 6],
		["coffee,breakfast_sticker,banana", [2, 0, 5], 7],
		["coffee,multipack,breakfast_sticker,banana", [2, 0, 0, 10], 12],
	]
) -> void:
	var result: ScoreResult = Scoring.score(_row(row))
	(
		assert_array(Array(result.payouts))
		. override_failure_message("%s: payouts %s, expected %s" % [row, result.payouts, payouts])
		. is_equal(payouts)
	)
	(
		assert_int(result.total)
		. override_failure_message("%s: total %d, expected %d" % [row, result.total, total])
		. is_equal(total)
	)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row
