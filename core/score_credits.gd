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
## A Price gun's relabels this shift (#132, RunState.relabels): instance id to the family the
## item gains (ScoreState adds it to the item's tags).
var relabels: Dictionary[int, String] = {}
## The families the run's Family stickers were given (v1.28, FamilySticker.chosen_all: picks and
## a pack's preset): instance id to family. A sticker missing here is pre-filled from the row.
var sticker_families: Dictionary[int, String] = {}
## The row's open slots this shift (ShiftLimits.slot_count; 0: unknown): Express lane's last slot
## (EndSlotsMultiplierRule, #132).
var row_slots: int = 0
## The hand cards this shift's redraws replaced, every redraw's (#128 v3, the redraw tension:
## scoring context, ScoreState.cards_redrawn): each redraw is a basket of the balance's
## basket_size cards.
var cards_redrawn: int = 0
## The redraws this shift has left (#128 v3: Crisps, Stale popcorn): its allowed redraws, extra
## ones included, less the ones used.
var redraws_left: int = 0


## The credits of the run's current shift: its slots without any upgrade's (the balance's and
## the shift's events', as ShiftLimits counts them) and its extra redraws' cards.
static func for_run(run: RunState) -> ScoreCredits:
	var credits: ScoreCredits = ScoreCredits.new()
	var bare: Array[UpgradeDefinition] = []
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	var pin_slots: int = RunPins.base_slots(run)
	credits.base_slots = (
		ShiftLimits.for_shift(run.balance, bare, run.shift_index, events, pin_slots).slot_count
	)
	credits.redrawn_in = run.redrawn_in.duplicate()
	credits.relabels = run.relabels.duplicate()
	credits.sticker_families = FamilySticker.chosen_all(run)
	if run.limits != null:
		credits.row_slots = RowCapacity.card_limit(run.limits)
	credits.cards_redrawn = run.redraws_used * run.balance.basket_size
	credits.redraws_left = maxi(run.redraws_allowed - run.redraws_used, 0)
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
