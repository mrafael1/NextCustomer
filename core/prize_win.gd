class_name PrizeWin
extends RefCounted
## What a LOYALTY or UPGRADES prize would have won (#108 piece 2, mock-up machine_loyalty_108.html
## section 4a): the real scorer rescores the run's checked-out rows (its history) with the prize
## taken, against the run as it is now. `last` is what it would have added to the row just checked
## out, `best` the most it would have added to any row this run. Pure and static: it reads the run
## and the machine's preview and changes neither.

## What it would have added to the last row, and the most to any row this run (euros, never below
## 0; 0 shows as WASTED).
var last: int = 0
var best: int = 0
## How many rows it was scored on (the run's checked-out shifts).
var rows: int = 0


## The prize's win on `run`'s rows, or null when it shows none: a product or coupon, a perk with no
## scoring rules (Extra redraw, Big basket: they change the shift, not a row's score), an upgrade
## with no copy to step, or a run with no checked-out row.
static func of(run: RunState, preview: MachinePreview) -> PrizeWin:
	if run == null or preview == null or run.history.is_empty():
		return null
	var prize: MachinePrize = preview.prize
	match prize.kind:
		MachinePrize.Kind.REGISTER:
			if prize.upgrade.rules.is_empty():
				return null
			return _perk_win(run, PerkLevels.with_pick(run.upgrades, prize.upgrade))
		MachinePrize.Kind.UPGRADE:
			if preview.targets.is_empty():
				return null
			return _upgrade_win(run, preview)
	return null


static func _perk_win(run: RunState, upgrades: Array[UpgradeDefinition]) -> PrizeWin:
	var found: PrizeWin = PrizeWin.new()
	for index: int in run.history.size():
		var record: ShiftRecord = run.history[index]
		var row: Array[CardInstance] = _row(record.played)
		var checks: Array[InspectionDefinition] = _checks(record)
		var gain: int = maxi(
			Scoring.total(row, upgrades, checks) - Scoring.total(row, run.upgrades, checks), 0
		)
		found._add(gain, index == run.history.size() - 1)
	return found


## An item upgrade: one copy (COMMON, RARE) steps at the row's best place for it; SHELF UPGRADE
## steps every copy in the row.
static func _upgrade_win(run: RunState, preview: MachinePreview) -> PrizeWin:
	var shelf: bool = preview.prize.rarity == MachinePrize.Rarity.LEGENDARY
	var steps: Dictionary[CardDefinition, CardDefinition] = {}
	for index: int in preview.targets.size():
		steps[preview.targets[index].definition] = preview.to_cards[index]
	var found: PrizeWin = PrizeWin.new()
	for index: int in run.history.size():
		var record: ShiftRecord = run.history[index]
		var checks: Array[InspectionDefinition] = _checks(record)
		var before: int = Scoring.total(_row(record.played), run.upgrades, checks)
		var gain: int = 0
		if shelf:
			var stepped: Array[CardDefinition] = []
			for card: CardDefinition in record.played:
				stepped.append(steps.get(card, card))
			gain = Scoring.total(_row(stepped), run.upgrades, checks) - before
		else:
			for slot: int in record.played.size():
				var card: CardDefinition = record.played[slot]
				if not steps.has(card):
					continue
				var stepped: Array[CardDefinition] = record.played.duplicate()
				stepped[slot] = steps[card]
				gain = maxi(gain, Scoring.total(_row(stepped), run.upgrades, checks) - before)
		found._add(maxi(gain, 0), index == run.history.size() - 1)
	return found


static func _row(cards: Array[CardDefinition]) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for slot: int in cards.size():
		row.append(CardInstance.new(cards[slot], slot + 1))
	return row


## Every inspection the record's shift was played under (a Manager's review's two, v0.65).
static func _checks(record: ShiftRecord) -> Array[InspectionDefinition]:
	return record.inspections.duplicate()


func _add(gain: int, is_last: bool) -> void:
	rows += 1
	best = maxi(best, gain)
	if is_last:
		last = gain
