extends GdUnitTestSuite
## Scoring.total() (the balance simulator's total-only score, #77 S1) gives exactly the total of
## Scoring.score() on any row, with any upgrades and inspections, and like score() never changes
## a definition.

const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
const CARDS_DIR := "res://data/cards"
const BALANCE_PATH := "res://data/balance/balance.tres"
## Random rows checked against score(), each from the live cards with random registers and
## inspections (a fixed seed, so a failure always repeats).
const RANDOM_ROWS := 3000
const MAX_ROW := 8


func test_empty_row_totals_zero() -> void:
	var none: Array[CardInstance] = []
	assert_int(Scoring.total(none)).is_equal(0)


func test_total_matches_score_on_the_golden_rows() -> void:
	for ids: String in [
		"eggs,bread,cheese,banana,banana,repeat",
		"banana,repeat,bread,eggs,banana,cheese",
		"breakfast_sticker,banana,multipack,coffee,bread",
		"coffee,breakfast_sticker,soup,frozen_peas",
		"banana,bundle,bundle,banana",
		"bread,final_markdown",
	]:
		var row: Array[CardInstance] = _fixture_row(ids)
		assert_int(Scoring.total(row)).override_failure_message(ids).is_equal(
			Scoring.score(row).total
		)


func test_total_matches_score_on_random_live_rows() -> void:
	var balance: BalanceDefinition = load(BALANCE_PATH) as BalanceDefinition
	var cards: Array[CardDefinition] = _live_cards()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for index: int in range(RANDOM_ROWS):
		var row: Array[CardInstance] = []
		for slot: int in range(rng.randi_range(1, MAX_ROW)):
			row.append(CardInstance.new(cards[rng.randi_range(0, cards.size() - 1)], slot + 1))
		var upgrades: Array[UpgradeDefinition] = []
		for _pick: int in range(rng.randi_range(0, 3)):
			upgrades.append(
				balance.upgrade_pool[rng.randi_range(0, balance.upgrade_pool.size() - 1)]
			)
		var inspections: Array[InspectionDefinition] = []
		if rng.randi_range(0, 2) == 0:
			var pool: Array[InspectionDefinition] = balance.inspection_pool
			inspections.append(pool[rng.randi_range(0, pool.size() - 1)])
		var expected: int = Scoring.score(row, upgrades, inspections).total
		(
			assert_int(Scoring.total(row, upgrades, inspections))
			. override_failure_message("row %d: %s" % [index, _ids(row, upgrades, inspections)])
			. is_equal(expected)
		)


func test_total_never_changes_definitions() -> void:
	var banana: CardDefinition = load("%s/banana.tres" % FIXTURE_DIR)
	var tags_before: PackedStringArray = banana.tags.duplicate()
	var row: Array[CardInstance] = _fixture_row("breakfast_sticker,banana,multipack,banana")
	Scoring.total(row)
	assert_array(Array(banana.tags)).is_equal(Array(tags_before))
	assert_int(row.size()).is_equal(4)


static func _live_cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	var files: PackedStringArray = DirAccess.get_files_at(CARDS_DIR)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			cards.append(load(CARDS_DIR.path_join(file)) as CardDefinition)
	return cards


static func _fixture_row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [FIXTURE_DIR, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


static func _ids(
	row: Array[CardInstance],
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition]
) -> String:
	var names: PackedStringArray = PackedStringArray()
	for card: CardInstance in row:
		names.append(String(card.definition.id))
	for upgrade: UpgradeDefinition in upgrades:
		names.append("+" + String(upgrade.id))
	for inspection: InspectionDefinition in inspections:
		names.append("!" + String(inspection.id))
	return ",".join(names)
