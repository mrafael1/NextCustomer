extends GdUnitTestSuite
## A prize's win sticker numbers (#108, mock-up machine_loyalty_108.html section 4a, PrizeWin):
## the real scorer rescores the run's checked-out rows with the prize taken, against the run as it
## is now: the last row's gain and the best row's.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS := "res://data/cards/"
const UPGRADES := "res://data/upgrades/"

var _balance: BalanceDefinition
var _starter: DeckDefinition


func before() -> void:
	_balance = load(BALANCE)
	_starter = load(STARTER)


## Dairy regulars (each Dairy product +1 for each Dairy product before it): three Milks gain
## 0 + 1 + 2, a row with no Dairy nothing; the last row is the one just checked out, the best the
## most over the run.
func test_a_perk_wins_on_the_last_row_and_the_best_row() -> void:
	var run: RunState = _run([["milk", "milk", "milk"], ["bread", "bread"]])
	var win: PrizeWin = PrizeWin.of(run, _perk_preview(_upgrade("dairy_regulars")))
	assert_object(win).is_not_null()
	assert_int(win.rows).is_equal(2)
	assert_int(win.last).is_equal(0)
	assert_int(win.best).is_equal(3)


## The gain is the real scorer's difference, row by row, with the run's own perks kept.
func test_the_win_is_the_scorers_difference_with_the_runs_perks() -> void:
	var run: RunState = _run([["bread", "milk", "cheese", "milk"]])
	run.upgrades.append(_upgrade("dairy_aisle_run"))
	var perk: UpgradeDefinition = _upgrade("dairy_regulars")
	var row: Array[CardInstance] = _instances(["bread", "milk", "cheese", "milk"])
	var with_perk: Array[UpgradeDefinition] = run.upgrades.duplicate()
	with_perk.append(perk)
	var gain: int = Scoring.total(row, with_perk) - Scoring.total(row, run.upgrades)
	var win: PrizeWin = PrizeWin.of(run, _perk_preview(perk))
	assert_int(win.last).is_equal(gain)
	assert_int(win.best).is_equal(gain)
	assert_int(gain).is_greater(0)


## A level-up replaces its owned level: the win is LV 2 over LV 1, not LV 2 on top of it.
func test_a_level_up_wins_its_step_over_the_owned_level() -> void:
	var run: RunState = _run([["milk", "milk", "milk"]])
	run.upgrades.append(_upgrade("dairy_regulars"))
	var level_two: UpgradeDefinition = _upgrade("dairy_regulars_lv2")
	var row: Array[CardInstance] = _instances(["milk", "milk", "milk"])
	var lone: Array[UpgradeDefinition] = [level_two]
	var stacked: int = Scoring.total(row, lone) - Scoring.total(row)
	var win: PrizeWin = PrizeWin.of(run, _perk_preview(level_two))
	assert_int(win.last).is_equal(stacked - 3)


## No sticker for a perk with no scoring rule (it changes the shift, not a row), a product, a
## preview-less ticket, or a run with no checked-out row.
func test_some_prizes_show_no_win() -> void:
	var run: RunState = _run([["milk"]])
	assert_object(PrizeWin.of(run, _perk_preview(_upgrade("extra_redraw")))).is_null()
	assert_object(PrizeWin.of(run, _perk_preview(_upgrade("big_basket")))).is_null()
	var product: MachinePreview = MachinePreview.new()
	product.prize = MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, _card("milk"))
	assert_object(PrizeWin.of(run, product)).is_null()
	assert_object(PrizeWin.of(run, null)).is_null()
	var fresh: RunState = _run([])
	assert_object(PrizeWin.of(fresh, _perk_preview(_upgrade("dairy_regulars")))).is_null()


## An item upgrade steps one copy at its best place in each row; a SHELF UPGRADE steps every copy.
## A row without the item gains nothing.
func test_an_item_upgrade_steps_one_copy_or_the_shelf() -> void:
	var run: RunState = _run([["bread"], ["milk", "bread", "milk"]])
	var milk: CardDefinition = _card("milk")
	var big: CardDefinition = _card("milk_big")
	var row: Array[CardInstance] = _instances(["milk", "bread", "milk"])
	var plain: int = Scoring.total(row)
	var one: int = 0
	for slot: int in [0, 2]:
		var stepped: Array[CardInstance] = _instances(["milk", "bread", "milk"])
		stepped[slot] = CardInstance.new(big, 99)
		one = maxi(one, Scoring.total(stepped) - plain)
	var both: Array[CardInstance] = _instances(["milk_big", "bread", "milk_big"])
	var shelf_gain: int = Scoring.total(both) - plain
	var common: PrizeWin = PrizeWin.of(run, _upgrade_preview(milk, big, 0))
	assert_int(common.last).is_equal(one)
	assert_int(common.best).is_equal(one)
	assert_int(one).is_greater(0)
	var shelf: PrizeWin = PrizeWin.of(run, _upgrade_preview(milk, big, 2))
	assert_int(shelf.last).is_equal(shelf_gain)
	assert_int(shelf_gain).is_greater(one)
	var lone: RunState = _run([["bread"]])
	assert_int(PrizeWin.of(lone, _upgrade_preview(milk, big, 0)).last).is_equal(0)


## A run whose history holds `rows` (card ids), each a checked-out shift.
func _run(rows: Array) -> RunState:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	for index: int in rows.size():
		var record: ShiftRecord = ShiftRecord.new(index + 1, 0, 0)
		for id: String in rows[index]:
			record.played.append(_card(id))
		run.history.append(record)
	return run


func _perk_preview(perk: UpgradeDefinition) -> MachinePreview:
	var preview: MachinePreview = MachinePreview.new()
	preview.prize = MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, perk)
	return preview


## An upgrade of `rarity` stepping a deck copy of `from` to `to` (one target, as a preview lists).
func _upgrade_preview(from: CardDefinition, to: CardDefinition, rarity: int) -> MachinePreview:
	var preview: MachinePreview = MachinePreview.new()
	preview.prize = MachinePrize.new(MachinePrize.Kind.UPGRADE, rarity, from)
	preview.targets.append(CardInstance.new(from, 1))
	preview.to_cards.append(to)
	preview.copies = 1
	return preview


func _instances(ids: Array[String]) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for index: int in ids.size():
		row.append(CardInstance.new(_card(ids[index]), index + 1))
	return row


func _card(id: String) -> CardDefinition:
	return load(CARDS + id + ".tres")


func _upgrade(id: String) -> UpgradeDefinition:
	return load(UPGRADES + id + ".tres")
