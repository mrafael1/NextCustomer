class_name ScoreCredits
extends RefCounted
## What the perks with no scoring rule earned in a row (#108 piece 2, the user's Q3 A: keep Extra
## redraw and Big basket, and print what they earned on the receipt). Scoring adds a CREDIT step
## after a credited slot's PAYOUT: a label naming the perk and the slot's payout, which the total
## already holds once. Big basket earns the payout of each card in a slot it added (the row's
## slots past `base_slots`, the shift's slots without the upgrades' extra ones); Extra redraw the
## payout of each card a redraw past the balance's base redraws brought into the hand
## (`redrawn_in`, RunState.redrawn_in). Built by the run (for_run); none for a bare score.

## The shift's slots without the upgrades' extra ones (-1: no slot credit).
var base_slots: int = -1
## The instance ids of the cards an extra redraw brought in this shift.
var redrawn_in: PackedInt32Array = PackedInt32Array()


## The credits of the run's current shift: its slots without any upgrade's (the balance's and
## the shift's inspections', as ShiftLimits counts them) and its extra redraws' cards.
static func for_run(run: RunState) -> ScoreCredits:
	var credits: ScoreCredits = ScoreCredits.new()
	var bare: Array[UpgradeDefinition] = []
	credits.base_slots = (
		ShiftLimits.for_shift(run.balance, bare, run.shift_index, run.inspections).slot_count
	)
	credits.redrawn_in = run.redrawn_in.duplicate()
	return credits


## The index in `upgrades` of the perk credited with the card in `slot` of `row` (a slot it added
## first, then a card its redraw brought in), and the credit's words; [-1, ""] for none.
func credit_for(row: Array[CardInstance], slot: int, upgrades: Array[UpgradeDefinition]) -> Array:
	if base_slots >= 0 and slot >= base_slots:
		var past: int = slot - base_slots
		for index: int in range(upgrades.size()):
			past -= upgrades[index].extra_slots
			if upgrades[index].extra_slots > 0 and past < 0:
				return [index, "slot %d" % (slot + 1)]
	if redrawn_in.has(row[slot].instance_id):
		for index: int in range(upgrades.size()):
			if upgrades[index].extra_redraws > 0:
				return [index, "redrawn in"]
	return [-1, ""]
