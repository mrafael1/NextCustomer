class_name UnlockCheck
extends RefCounted
## Checks unlock conditions (full build plan section 7.3) when a run ends. Pure: it reads the
## run and the lifetime coupon uses from before this run (kept by the profile), and changes
## nothing.


## Whether `condition` is met by the run that just ended. `earlier_uses` maps a coupon id to
## how many times it was used in earlier runs (USE_COUPON_TIMES counts across runs).
static func is_met(
	condition: UnlockCondition, run: RunState, earlier_uses: Dictionary[StringName, int] = {}
) -> bool:
	match condition.kind:
		UnlockCondition.Kind.WIN_WITH_CARD:
			return run.phase == RunState.Phase.WON and _deck_has(run, condition.card)
		UnlockCondition.Kind.SCORE_IN_ONE_CHECKOUT:
			for record: ShiftRecord in run.history:
				if record.total >= condition.amount:
					return true
			return false
		UnlockCondition.Kind.USE_COUPON_TIMES:
			if condition.card == null:
				return false
			var id: StringName = condition.card.id
			var uses: int = earlier_uses.get(id, 0) + coupon_uses(run.history).get(id, 0)
			return uses >= condition.amount
	return false


## How many times each coupon was checked out in these shifts (every copy in a row counts
## once), by card id. Products are not counted.
static func coupon_uses(history: Array[ShiftRecord]) -> Dictionary[StringName, int]:
	var uses: Dictionary[StringName, int] = {}
	for record: ShiftRecord in history:
		for card: CardDefinition in record.played:
			if card.is_coupon():
				uses[card.id] = uses.get(card.id, 0) + 1
	return uses


static func _deck_has(run: RunState, card: CardDefinition) -> bool:
	if card == null:
		return false
	for instance: CardInstance in run.deck.cards:
		if instance.definition == card:
			return true
	return false
